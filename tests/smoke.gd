extends SceneTree

const SessionScript = preload("res://scripts/box_session.gd")

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var model: RefCounted = SessionScript.new()
	var events: Array[Dictionary] = []
	model.event_created.connect(func(payload: Dictionary) -> void: events.append(payload))
	_check(not model.start_session({"session_id": "", "activities": []}), "invalid session rejected")
	_check(model.start_session({"session_id": "test-1", "activities": [
		{"id": "juego", "type": "game", "title": "Juego"},
		{"id": "movimiento", "type": "movement", "title": "Movimiento"}
	]}), "session started")
	_check(model.screen == SessionScript.Screen.MURAL, "mural shown")
	_check(not model.choose_activity("unknown"), "unauthorized activity rejected")
	_check(model.enter_picker(), "activity picker opened")
	_check(model.choose_activity("juego"), "activity selected")
	_check(model.screen == SessionScript.Screen.ACTIVITY, "activity shown")
	_check(events.size() == 1 and events[0]["action"] == "activity_selected", "selection event")
	_check(model.pause(), "child can pause")
	_check(model.screen == SessionScript.Screen.PAUSED, "pause shown")
	_check(model.request_help(), "help requested during pause")
	_check(events.size() == 3 and events[2]["action"] == "help_requested", "help event")
	_check(model.resume_from_therapist(), "therapist resumes")
	_check(model.screen == SessionScript.Screen.ACTIVITY, "activity restored")
	_check(model.complete_activity(), "activity completed")
	_check(model.screen == SessionScript.Screen.MURAL, "mural restored")
	_check(model.end_from_therapist(), "therapist ends session")
	_check(model.screen == SessionScript.Screen.CLOSED, "closed shown")
	_check(not model.request_help(), "no input after close")
	_check(events[0]["event_id"] != events[1]["event_id"], "event ids unique")
	var guided: RefCounted = SessionScript.new()
	var guided_events: Array[Dictionary] = []
	guided.event_created.connect(func(payload: Dictionary) -> void: guided_events.append(payload))
	_check(guided.start_session({"session_id": "guided-1", "activities": [], "routine": [
		{"id": "inicio", "title": "Comenzar"}, {"id": "cierre", "title": "Cerrar"}
	], "communication": [{"id": "pausa", "label": "Quiero una pausa"}], "sensory": {
		"audio_enabled": false, "reduced_motion": true, "breath_pace": "slow"
	}}), "guided session started")
	_check(not guided.audio_enabled and guided.reduced_motion and guided.breath_pace == "slow", "sensory preferences loaded")
	_check(guided.enter_routine(), "routine opened")
	_check(guided.request_next_step(), "routine step requested")
	_check(guided_events[0].get("step_id") == "inicio", "step event contains id")
	_check(guided.set_routine_index_from_therapist(1), "therapist sets next step")
	_check(guided.pause() and guided.resume_from_therapist(), "routine survives pause")
	_check(guided.return_home() and guided.enter_communication(), "communication opened")
	_check(guided.choose_communication("pausa"), "communication choice accepted")
	_check(guided_events[-1].get("choice_id") == "pausa", "communication event contains id")
	_check(not guided.choose_communication("unknown"), "unknown communication rejected")
	_check(guided.enter_mural(), "return to mural")
	_check(guided.select_emotion("triste"), "emotion chosen")
	_check(guided_events[-1].get("emotion_id") == "triste", "emotion event contains id")
	_check(guided.begin_guided_action("respirar"), "guided breathing opened")
	_check(guided.complete_guided_action(), "guided breathing completed")
	_check(guided_events[-1].get("guided_action_id") == "respirar", "guided action event contains id")
	_check(guided.begin_guided_action("moverme"), "frog movement opened")
	_check(guided.register_frog_action("saltar"), "frog touch accepted")
	_check(guided.frog_count == 1 and guided_events[-1].get("gesture") == "saltar", "frog count and gesture event")
	_check(guided.complete_guided_action(), "frog movement completed")
	var app: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.sound_enabled = false
	await process_frame
	_check(app.session.screen == SessionScript.Screen.MURAL, "demo opens on mural")
	var mood_button := _find_button(app, "Bien")
	_check(mood_button != null, "emotion card exists")
	if mood_button != null:
		mood_button.pressed.emit()
		_check(app.session.selected_emotion_id == "bien", "emotion selected in UI")
	var picker_button := _find_button(app, "Juego")
	_check(picker_button != null, "game navigation exists")
	if picker_button != null:
		picker_button.pressed.emit()
	_check(app.session.screen == SessionScript.Screen.HOME, "UI opens activity picker")
	var game_button := _find_button(app, "Juego")
	_check(game_button != null, "activity card exists")
	if game_button == null:
		quit(1)
		return
	game_button.pressed.emit()
	_check(app.session.screen == SessionScript.Screen.ACTIVITY, "UI opens game")
	for symbol: String in ["●", "▲", "■"]:
		var shape_button := _find_button(app, symbol)
		_check(shape_button != null, "game shape exists")
		if shape_button == null:
			quit(1)
			return
		shape_button.pressed.emit()
	var back_button := _find_button(app, "Volver a elegir")
	_check(back_button != null, "game completion action exists")
	if back_button == null:
		quit(1)
		return
	back_button.pressed.emit()
	_check(app.session.screen == SessionScript.Screen.MURAL, "UI returns mural")
	var pause_button := _find_button(app, "Pausa")
	_check(pause_button != null, "pause button exists")
	if pause_button == null:
		quit(1)
		return
	pause_button.pressed.emit()
	_check(app.session.screen == SessionScript.Screen.PAUSED, "UI pause action")
	var resume_button := _find_button(app, "Continuar")
	_check(resume_button != null, "demo resume button exists")
	if resume_button == null:
		quit(1)
		return
	resume_button.pressed.emit()
	_check(app.session.screen == SessionScript.Screen.MURAL, "UI resumes mural")
	var routine_button := _find_button(app, "Mi rutina")
	_check(routine_button != null, "routine navigation exists")
	if routine_button != null:
		routine_button.pressed.emit()
		_check(app.session.screen == SessionScript.Screen.ROUTINE, "UI opens routine")
		var next_button := _find_button(app, "Estoy listo para seguir")
		_check(next_button != null, "routine action exists")
		if next_button != null:
			next_button.pressed.emit()
			_check(app.session.routine_index == 1, "demo advances routine")
		var routine_back := _find_button(app, "←  Volver a elegir")
		if routine_back != null:
			routine_back.pressed.emit()
	var communication_button := _find_button(app, "Quiero decir")
	_check(communication_button != null, "communication navigation exists")
	if communication_button != null:
		communication_button.pressed.emit()
		_check(app.session.screen == SessionScript.Screen.COMMUNICATION, "UI opens communication")
		var choice_button := _find_button(app, "Quiero una pausa")
		_check(choice_button != null, "communication choice exists")
		if choice_button != null:
			choice_button.pressed.emit()
			_check(app._toast == "Dijiste: Quiero una pausa", "choice feedback shown")
		var communication_back := _find_button(app, "←  Volver a elegir")
		if communication_back != null:
			communication_back.pressed.emit()
	var breathing_button := _find_button(app, "Respirar")
	_check(breathing_button != null, "breathing card exists")
	if breathing_button != null:
		breathing_button.pressed.emit()
		_check(app.session.screen == SessionScript.Screen.BREATH, "UI opens breathing")
		var pace_button := _find_button(app, "Pausado 5-3-5")
		_check(pace_button != null, "breathing pace control exists")
		if pace_button != null:
			pace_button.pressed.emit()
			_check(app._breath_pace == 1, "breathing pace changes")
		var breath_done := _find_button(app, "Terminé")
		if breath_done != null:
			breath_done.pressed.emit()
			_check(app.session.screen == SessionScript.Screen.MURAL, "UI completes breathing")
	var frog_button := _find_button(app, "Moverme")
	_check(frog_button != null, "frog navigation exists")
	if frog_button != null:
		frog_button.pressed.emit()
		_check(app.session.screen == SessionScript.Screen.FROG, "UI opens frog movement")
		var touch_frog := _find_button(app, "Tocar a la ranita")
		_check(touch_frog != null, "frog touch target exists")
		if touch_frog != null:
			touch_frog.pressed.emit()
			_check(app.session.frog_count == 1, "frog touch counted")
	app.queue_free()
	await process_frame
	await process_frame
	await process_frame
	if not _failed:
		print("MAKIPURA smoke checks passed")
	quit(1 if _failed else 0)


func _find_button(node: Node, title: String) -> Button:
	if node is Button and ((node as Button).text == title or (node as Button).accessibility_name == title):
		return node as Button
	for child: Node in node.get_children():
		var found := _find_button(child, title)
		if found != null:
			return found
	return null


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failed = true
		push_error("Smoke check failed: " + description)
