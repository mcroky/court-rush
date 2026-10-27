extends SceneTree
const Simulation=preload("res://scripts/online/duel_simulation.gd")
const Controls=preload("res://scripts/online/duel_control.gd")
var listener=TCPServer.new()
var peer: StreamPeerTCP
var incoming=""
var match_node
var room_id=""
var pending: Array=[[],[]]
var inputs: Array=[Controls.neutral(),Controls.neutral()]
var acks: Array=[-1,-1]
var received: Array=[0,0]
var running=false
var accumulator=0.0
var last_health=0
var tick_times: Array=[]

func _initialize() -> void:
	Engine.max_fps=60 # Headless polling must not spend the Free CPU quota on an uncapped idle loop.
	var port=int(OS.get_environment("CR_WORKER_PORT"))
	if port<=0: port=32091
	if listener.listen(port,"127.0.0.1")!=OK:
		push_error("ONLINE_WORKER_BIND_FAILED"); quit(1)

func send_message(value: Dictionary) -> void:
	if peer!=null and peer.get_status()==StreamPeerTCP.STATUS_CONNECTED:
		if peer.put_data((JSON.stringify(value)+"\n").to_utf8_buffer())!=OK: peer.disconnect_from_host()

func handle(message: Dictionary) -> void:
	match str(message.get("type","")):
		"create":
			if match_node!=null: send_message({"type":"error","code":"occupied"}); return
			room_id=str(message.get("roomId",""))
			match_node=Simulation.new(); root.add_child(match_node)
			var appearances=message.get("appearances",[{},{}])
			for i in 2:
				if appearances is Array and appearances.size()==2 and appearances[i] is Dictionary: match_node.players[i].apply_appearance(appearances[i])
			pending=[[],[]]; inputs=[Controls.neutral(),Controls.neutral()]; acks=[-1,-1]
			received=[Time.get_ticks_msec(),Time.get_ticks_msec()]
			running=false
			send_message({"type":"created","roomId":room_id,"state":match_node.snapshot(acks)})
		"start":
			if match_node!=null and message.get("roomId","")==room_id: running=true
		"input":
			if match_node==null or message.get("roomId","")!=room_id: return
			var slot=int(message.get("slot",-1))
			if slot not in [0,1] or not message.get("input",null) is Dictionary: return
			message.input["_received"]=Time.get_ticks_msec()
			if pending[slot].size()<32: pending[slot].append(message.input)
			received[slot]=Time.get_ticks_msec()
		"reset_input":
			var slot=int(message.get("slot",-1))
			if match_node!=null and message.get("roomId","")==room_id and slot in [0,1]:
				pending[slot]=[]; inputs[slot]=Controls.neutral(); acks[slot]=-1
				match_node.controllers[slot].edges={}
		"end":
			if match_node!=null and message.get("roomId","")==room_id:
				match_node.outcome=str(message.get("reason","aborted"))
				match_node.finish_match(); running=false
				send_message({"type":"snapshot","roomId":room_id,"state":match_node.snapshot(acks)})
		"destroy":
			if message.get("roomId","")!=room_id: return
			if match_node!=null: match_node.queue_free(); match_node=null
			room_id=""; running=false
		"ping": send_message({"type":"health","roomId":room_id,"tick":match_node.tick_id if match_node!=null else 0})

func _process(delta: float) -> bool:
	if listener.is_connection_available():
		var connection=listener.take_connection()
		if peer!=null and peer.get_status()==StreamPeerTCP.STATUS_CONNECTED: connection.disconnect_from_host()
		else:
			peer=connection; peer.set_no_delay(true); incoming=""
			send_message({"type":"ready","protocolVersion":1})
	if peer!=null:
		peer.poll()
		if peer.get_status()!=StreamPeerTCP.STATUS_CONNECTED:
			if match_node!=null: match_node.queue_free(); match_node=null
			running=false; room_id=""; peer=null
		else:
			var available=peer.get_available_bytes()
			if available>0:
				var data=peer.get_data(mini(available,262144))
				if data[0]==OK: incoming+=data[1].get_string_from_utf8()
			if incoming.length()>1048576: peer.disconnect_from_host()
			var count=0
			while incoming.contains("\n") and count<128:
				var end=incoming.find("\n"); var line=incoming.substr(0,end); incoming=incoming.substr(end+1)
				var message=JSON.parse_string(line)
				if message is Dictionary: handle(message)
				count+=1
	if running and delta>.25:
		send_message({"type":"overload"}); running=false
	accumulator+=minf(delta,.25)
	var steps=0
	while accumulator>=1.0/60.0 and steps<8:
		accumulator-=1.0/60.0; steps+=1
		if not running or match_node==null: continue
		for slot in 2:
			inputs[slot].shoot_pressed=false
			while not pending[slot].is_empty() and Time.get_ticks_msec()-int(pending[slot][0].get("_received",0))>250: pending[slot].pop_front()
			if not pending[slot].is_empty():
				var command: Dictionary=pending[slot].pop_front()
				var next=Controls.neutral()
				for key in next:
					if command.has(key): next[key]=command[key]
				inputs[slot]=next; acks[slot]=int(command.get("seq",acks[slot]))
			if Time.get_ticks_msec()-int(received[slot])>250:
				inputs[slot]=Controls.neutral()
				if match_node.players[slot].action in ["square","gather"]: match_node.fake_shot(slot)
		var tick_start=Time.get_ticks_usec()
		match_node.step(1.0/60.0,inputs)
		tick_times.append(Time.get_ticks_usec()-tick_start)
		if match_node.tick_id%3==0 or match_node.phase=="ended":
			send_message({"type":"snapshot","roomId":room_id,"state":match_node.snapshot(acks)})
		if match_node.phase=="ended": running=false
	if accumulator>.25:
		send_message({"type":"overload"}); accumulator=0.0
	var now=Time.get_ticks_msec()
	if now-last_health>1000:
		last_health=now
		tick_times.sort()
		send_message({"type":"health","roomId":room_id,"tick":match_node.tick_id if match_node!=null else 0,"memoryBytes":OS.get_static_memory_usage(),"tickP95us":tick_times[mini(tick_times.size()-1,int(tick_times.size()*.95))] if not tick_times.is_empty() else 0,"tickP99us":tick_times[-1] if not tick_times.is_empty() else 0})
		tick_times.clear()
	return false
