extends Node
## Local prerecorded calls and original scores. No TTS/network at runtime.
const TRACKS = ["asphalt-groove", "fast-break", "neon-court"]
const CALLS = {"score":3,"three":2,"layup":2,"dunk":2,"cross":2,"spin":2,"twostep":2,"behind":2,"hesi":2,"block":2,"rebound":2,"steal":2,"win":2}
const SKILLS = ["cross","spin","twostep","behind","hesi"]
const LINES = {
	"score":["Nothing but net!","Oh, what a bucket!","That is money!"],
	"three":["From downtown!","Three points! Let it fly!"],
	"layup":["What a finish!","Soft touch, right at the rim!"],
	"dunk":["Oh! Throw it down!","Up high! Bring it home!"],
	"cross":["What a crossover!","Quick hands, quick feet!"],
	"spin":["Spin move!","Around and away!"],
	"twostep":["One, two! There you go!","Change of pace!"],
	"behind":["Behind the back!","Smooth handles!"],
	"hesi":["Hesitate, and go!","Look at that handle!"],
	"block":["Get that out of here!","Denied at the rim!"],
	"rebound":["Up high! Got the rebound!","Big rebound!"],
	"steal":["Quick hands! What a steal!","Picked it clean!"],
	"win":["That is game! What a performance!","Big win on the court!"]
}
var voices: Dictionary = {}
var music: Array = []
var decks: Array = []
var voice: AudioStreamPlayer
var rotation: Dictionary = {}
var enabled = true
var voice_enabled = true
var music_enabled = true
var active = false
var selection = -1
var track_index = -1
var deck_index = 0
var transition = 1.0
var duck_db = 0.0
var music_gain = -12.0
var voice_gain = -1.0
var sfx_gain = 0.0
var elapsed = 20.0
var last_skill = -20.0
var last_call = -20.0
var last_next = 0
var advance_pending = false
var pending = ""
var pending_until = 0.0
var current_priority = 0
var event_serial = 0
var calls_played = 0
var last_call_key = ""
var last_line = ""

func _ready() -> void:
	for bus in ["Court", "CourtMusic", "CourtVoice", "CourtSFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var index = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, "Master" if bus == "Court" else "Court")
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Court"), -3)
	for key in CALLS:
		voices[key] = []
		for i in range(CALLS[key]):
			voices[key].append(load("res://assets/audio/voice/%s-%d.wav" % [key,i+1]))
	for name in TRACKS:
		var stream = load("res://assets/audio/music/%s.ogg" % name)
		stream.loop = false
		music.append(stream)
	for i in range(2):
		var deck = AudioStreamPlayer.new()
		# Stream playback keeps the Godot mixer, pause and bus fades consistent
		# on web as well as Android. Web Sample nodes have different lifetimes.
		deck.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		deck.bus = "CourtMusic"
		add_child(deck)
		decks.append(deck)
	voice = AudioStreamPlayer.new()
	voice.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	voice.bus = "CourtVoice"
	add_child(voice)
	apply_mix()

func configure(master: bool, audible: bool, settings: Dictionary = {}) -> void:
	enabled = master
	active = audible
	voice_enabled = bool(settings.get("voice",true))
	music_enabled = bool(settings.get("music",true))
	music_gain = clampf(float(settings.get("musicDb",-12)), -36, 0)
	voice_gain = clampf(float(settings.get("voiceDb",-1)), -36, 0)
	sfx_gain = clampf(float(settings.get("sfxDb",0)), -36, 0)
	var next_selection = clampi(int(settings.get("track",-1)), -1, TRACKS.size()-1)
	var next_command = int(settings.get("next",0))
	selection = next_selection
	if next_command != last_next:
		last_next = next_command
		advance_pending = true
	if active and enabled and music_enabled:
		if advance_pending:
			switch_track((track_index+1)%music.size())
			advance_pending = false
		elif selection >= 0 and track_index >= 0 and track_index != selection:
			switch_track(selection)
	if not active or not enabled or not voice_enabled:
		if voice.playing: voice.stop()
		pending = ""
	for deck in decks:
		var should_pause = not active or not enabled or not music_enabled
		if deck.stream_paused != should_pause: deck.stream_paused = should_pause
	if active and enabled and music_enabled and track_index < 0:
		switch_track(maxi(selection,0))
	apply_mix()

func apply_mix() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Court"),not enabled or not active)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("CourtMusic"),music_gain+duck_db)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("CourtVoice"),voice_gain)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("CourtSFX"),sfx_gain)

func switch_track(index: int) -> void:
	if music.is_empty(): return
	if track_index < 0:
		track_index = index
		decks[deck_index].stream = music[index]
		decks[deck_index].volume_db = 0
		decks[deck_index].play()
		return
	# Rapid Next presses keep only the current pair of decks, never spawn players.
	if decks[1-deck_index].playing: decks[1-deck_index].stop()
	deck_index = 1-deck_index
	track_index = index
	decks[deck_index].stream = music[index]
	decks[deck_index].volume_db = -60
	decks[deck_index].play()
	transition = 0

func priority(key: String) -> int:
	return 1 if key in SKILLS else (4 if key == "win" else 3)

func cue(key: String) -> bool:
	if not voices.has(key): return false
	event_serial += 1
	if not active or not enabled or not voice_enabled: return false
	if key in SKILLS and (elapsed-last_skill < 4.2 or elapsed-last_call < 2.2): return false
	if voice.playing:
		if priority(key) > current_priority and (pending.is_empty() or priority(key) >= priority(pending)):
			pending = key
			pending_until = elapsed+1.8
		return false
	if elapsed-last_call < .8: return false
	play_call(key)
	return true

func play_call(key: String) -> void:
	var index = int(rotation.get(key,0)) % voices[key].size()
	rotation[key] = index+1
	voice.stream = voices[key][index]
	voice.pitch_scale = 1.0
	voice.play()
	last_call = elapsed
	last_call_key = key
	last_line = LINES[key][index]
	calls_played += 1
	current_priority = priority(key)
	if key in SKILLS: last_skill = elapsed

func _process(delta: float) -> void:
	# Real audio time: slow motion practice must not stretch the voices or score.
	if not active or not enabled: return
	elapsed += delta
	if not pending.is_empty() and not voice.playing:
		var key = pending
		pending = ""
		if elapsed <= pending_until and voice_enabled: play_call(key)
	duck_db = move_toward(duck_db, -9.0 if voice.playing else 0.0,delta*(95 if voice.playing else 18))
	if music_enabled and track_index >= 0:
		transition = minf(1, transition+delta/1.2)
		decks[deck_index].volume_db = linear_to_db(maxf(.001,sin(transition*PI*.5)))
		decks[1-deck_index].volume_db = linear_to_db(maxf(.001,cos(transition*PI*.5)))
		if transition >= 1:
			if decks[1-deck_index].playing: decks[1-deck_index].stop()
			var current = decks[deck_index]
			if not current.playing or current.get_playback_position() >= music[track_index].get_length()-1.2:
				switch_track(selection if selection >= 0 else (track_index+1)%music.size())
	apply_mix()
