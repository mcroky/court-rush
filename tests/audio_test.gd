extends SceneTree
const CourtAudio = preload("res://scripts/court_audio.gd")
var failures = 0
var checks = 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var audio = CourtAudio.new()
	root.add_child(audio)
	audio.set_process(false)
	check(audio.voices.size()==13 and audio.music.size()==3,"All commentary categories and music tracks load")
	for key in audio.voices:
		for clip in audio.voices[key]: check(clip != null and clip.get_length()>.3 and clip.get_length()<2.5,"Valid voice clip: "+key)
	for clip in audio.music: check(clip.get_length()>30 and clip.get_length()<42,"Music has a complete 16-bar arrangement")
	check(not audio.cue("cross"),"Menu is silent")
	audio.configure(true,true)
	check(audio.track_index==0 and audio.decks[0].playing,"Start from the first track after play")
	check(audio.cue("cross"),"Accepted skill receives a call")
	var count = audio.calls_played
	check(not audio.cue("cross") and audio.calls_played==count,"Skill spam does not overlap or repeat")
	audio.cue("dunk")
	check(audio.pending=="dunk","Scoring call waits for the skill voice to finish")
	audio._process(.12)
	check(audio.duck_db < -8,"Music ducks under voice")
	audio.configure(true,false)
	check(not audio.voice.playing and audio.pending.is_empty() and audio.decks[audio.deck_index].stream_paused,"Pause stops voice and freezes music")
	audio.configure(true,true)
	check(not audio.decks[audio.deck_index].stream_paused and audio.pending.is_empty(),"Resume does not replay an old call")
	audio.configure(true,true,{"track":1})
	check(audio.track_index==1,"Manual music selection")
	audio.configure(true,true,{"track":-1,"next":1})
	check(audio.track_index==2,"Next exits repeat mode and advances exactly one track")
	audio.configure(true,false,{"track":0,"next":1})
	check(audio.track_index==2,"Changing a song while paused stays silent")
	audio.configure(true,true,{"track":0,"next":1})
	check(audio.track_index==0,"Paused music selection applies on resume")
	audio.configure(false,true)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Court")) and not audio.voice.playing,"Master mute covers music, voices and effects")
	audio.configure(true,true,{"voice":false,"music":false,"musicDb":-25,"sfxDb":-8})
	check(not audio.cue("score") and audio.decks[audio.deck_index].stream_paused,"Separate voice and music switches")
	check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("CourtSFX")),-8),"Effects volume uses its bus")
	check(audio.get_child_count()==3,"Two music decks and one voice player stay bounded")
	# Exercise the actual mixer rather than only checking player flags.
	var capture = AudioEffectRecord.new()
	var court_bus = AudioServer.get_bus_index("Court")
	AudioServer.add_bus_effect(court_bus,capture)
	audio.configure(true,true)
	audio.elapsed += 10
	audio.cue("three")
	capture.set_recording_active(true)
	await create_timer(.65).timeout
	capture.set_recording_active(false)
	var recording = capture.get_recording()
	check(recording != null and recording.data.size()>1000,"Mixer emits actual PCM audio")
	if recording != null:
		var peak = 0
		for i in range(0,recording.data.size()-1,2):
			var sample = int(recording.data[i])+int(recording.data[i+1])*256
			if sample>32767: sample-=65536
			peak=maxi(peak,absi(sample))
		check(peak>100 and peak<32767,"Mixed voice and music have signal without full-scale clipping")
		recording.save_to_wav("res://artifacts/audio-mixer-check.wav")
	AudioServer.remove_bus_effect(court_bus,0)
	for deck in audio.decks:
		deck.stop()
		deck.stream=null
	audio.voice.stop()
	audio.voice.stream=null
	audio.voices.clear()
	audio.music.clear()
	audio.free()
	await create_timer(.2).timeout
	print("COURT_AUDIO: ",checks," checks; failures=",failures)
	call_deferred("finish")
func finish() -> void:
	quit(1 if failures else 0)
