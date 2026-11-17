extends RefCounted

signal changed
signal event_created(payload: Dictionary)

enum Screen { WAITING, HOME, ROUTINE, COMMUNICATION, ACTIVITY, PAUSED, CLOSED, MURAL, BREATH, DANCE, FROG }

var screen: Screen = Screen.WAITING
var session_id: String = ""
var activities: Array[Dictionary] = []
var routine: Array[Dictionary] = []
var communication_options: Array[Dictionary] = []
var routine_index: int = 0
var selected_emotion_id: String = ""
var frog_count: int = 0
var selected_activity_id: String = ""
var audio_enabled: bool = true
var reduced_motion: bool = false
var breath_pace: String = "normal"
var paused_from: Screen = Screen.HOME
var _event_sequence: int = 0


func start_session(data: Dictionary) -> bool:
	var proposed_id := str(data.get("session_id", "")).strip_edges()
	var proposed_activities: Variant = data.get("activities", [])
	var proposed_routine: Variant = data.get("routine", [])
	var proposed_communication: Variant = data.get("communication", [])
	if proposed_id.is_empty() or typeof(proposed_activities) != TYPE_ARRAY or typeof(proposed_routine) != TYPE_ARRAY or typeof(proposed_communication) != TYPE_ARRAY:
		return false
	var accepted: Array[Dictionary] = []
	for raw: Variant in proposed_activities:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var activity: Dictionary = raw
		var activity_id := str(activity.get("id", "")).strip_edges()
		var kind := str(activity.get("type", "")).strip_edges()
		if activity_id.is_empty() or not kind in ["game", "movement", "calm"]:
			continue
		if accepted.any(func(item: Dictionary) -> bool: return item["id"] == activity_id):
			continue
		accepted.append({
			"id": activity_id,
			"type": kind,
			"title": str(activity.get("title", "Actividad")).substr(0, 32),
			"description": str(activity.get("description", "")).substr(0, 110),
			"instruction": str(activity.get("instruction", "")).substr(0, 100)
		})
		if accepted.size() == 2:
			break
	var accepted_routine: Array[Dictionary] = []
	for raw: Variant in proposed_routine:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var step: Dictionary = raw
		var step_id := str(step.get("id", "")).strip_edges()
		var step_title := str(step.get("title", "")).strip_edges()
		if step_id.is_empty() or step_title.is_empty():
			continue
		accepted_routine.append({"id": step_id.substr(0, 48), "title": step_title.substr(0, 42)})
		if accepted_routine.size() == 6:
			break
	var accepted_communication: Array[Dictionary] = []
	for raw: Variant in proposed_communication:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var option: Dictionary = raw
		var option_id := str(option.get("id", "")).strip_edges()
		var option_label := str(option.get("label", "")).strip_edges()
		if option_id.is_empty() or option_label.is_empty():
			continue
		accepted_communication.append({"id": option_id.substr(0, 48), "label": option_label.substr(0, 42)})
		if accepted_communication.size() == 6:
			break
	if accepted.is_empty() and accepted_routine.is_empty() and accepted_communication.is_empty():
		return false
	session_id = proposed_id
	activities = accepted
	routine = accepted_routine
	communication_options = accepted_communication
	routine_index = 0
	selected_emotion_id = ""
	frog_count = 0
	selected_activity_id = ""
	var sensory: Dictionary = data.get("sensory", {}) if typeof(data.get("sensory", {})) == TYPE_DICTIONARY else {}
	audio_enabled = sensory.get("audio_enabled", true) != false
	reduced_motion = sensory.get("reduced_motion", false) == true
	breath_pace = "slow" if sensory.get("breath_pace", "normal") == "slow" else "normal"
	_event_sequence = 0
	screen = Screen.MURAL
	changed.emit()
	return true


func current_activity() -> Dictionary:
	for activity: Dictionary in activities:
		if activity["id"] == selected_activity_id:
			return activity
	return {}


func current_step() -> Dictionary:
	if routine_index >= 0 and routine_index < routine.size():
		return routine[routine_index]
	return {}


func enter_picker() -> bool:
	if screen != Screen.MURAL:
		return false
	screen = Screen.HOME
	changed.emit()
	return true


func enter_mural() -> bool:
	if screen in [Screen.WAITING, Screen.CLOSED, Screen.PAUSED]:
		return false
	screen = Screen.MURAL
	changed.emit()
	return true


func select_emotion(emotion_id: String) -> bool:
	if screen != Screen.MURAL or emotion_id not in ["bien", "tranquilo", "triste", "enojado"]:
		return false
	selected_emotion_id = emotion_id
	_create_event("emotion_selected", "", {"emotion_id": emotion_id})
	changed.emit()
	return true


func begin_guided_action(action_id: String) -> bool:
	if screen != Screen.MURAL or action_id not in ["respirar", "baile", "moverme"]:
		return false
	screen = Screen.BREATH if action_id == "respirar" else (Screen.FROG if action_id == "moverme" else Screen.DANCE)
	frog_count = 0
	_create_event("guided_action_started", "", {"guided_action_id": action_id})
	changed.emit()
	return true


func complete_guided_action() -> bool:
	if screen not in [Screen.BREATH, Screen.DANCE, Screen.FROG]:
		return false
	var action_id := "respirar" if screen == Screen.BREATH else ("moverme" if screen == Screen.FROG else "baile")
	_create_event("guided_action_completed", "", {"guided_action_id": action_id})
	screen = Screen.MURAL
	changed.emit()
	return true


func register_frog_action(mode: String) -> bool:
	if screen != Screen.FROG or mode not in ["saltar", "estirar", "sacudir"]:
		return false
	frog_count += 1
	_create_event("guided_action_input", "", {"guided_action_id": "moverme", "gesture": mode, "count": frog_count})
	changed.emit()
	return true


func enter_routine() -> bool:
	if screen not in [Screen.HOME, Screen.MURAL] or routine.is_empty():
		return false
	screen = Screen.ROUTINE
	changed.emit()
	return true


func enter_communication() -> bool:
	if screen not in [Screen.HOME, Screen.MURAL] or communication_options.is_empty():
		return false
	screen = Screen.COMMUNICATION
	changed.emit()
	return true


func return_home() -> bool:
	if screen not in [Screen.ROUTINE, Screen.COMMUNICATION, Screen.HOME]:
		return false
	screen = Screen.MURAL
	changed.emit()
	return true


func choose_communication(option_id: String) -> bool:
	if screen != Screen.COMMUNICATION:
		return false
	for option: Dictionary in communication_options:
		if option["id"] == option_id:
			_create_event("communication_selected", "", {"choice_id": option_id})
			return true
	return false


func request_next_step() -> bool:
	if screen != Screen.ROUTINE or current_step().is_empty():
		return false
	_create_event("step_ready", "", {"step_id": current_step()["id"]})
	return true


func set_routine_index_from_therapist(index: int) -> bool:
	if index < 0 or index >= routine.size() or screen in [Screen.WAITING, Screen.CLOSED]:
		return false
	routine_index = index
	changed.emit()
	return true


func advance_routine_demo() -> bool:
	if screen != Screen.ROUTINE or routine_index + 1 >= routine.size():
		return false
	routine_index += 1
	changed.emit()
	return true


func choose_activity(activity_id: String) -> bool:
	if screen != Screen.HOME:
		return false
	for activity: Dictionary in activities:
		if activity["id"] == activity_id:
			selected_activity_id = activity_id
			screen = Screen.ACTIVITY
			_create_event("activity_selected", activity_id)
			changed.emit()
			return true
	return false


func complete_activity() -> bool:
	if screen != Screen.ACTIVITY:
		return false
	_create_event("activity_completed", selected_activity_id)
	selected_activity_id = ""
	screen = Screen.MURAL
	changed.emit()
	return true


func request_help() -> bool:
	if screen not in [Screen.HOME, Screen.MURAL, Screen.ROUTINE, Screen.COMMUNICATION, Screen.ACTIVITY, Screen.BREATH, Screen.DANCE, Screen.FROG, Screen.PAUSED]:
		return false
	_create_event("help_requested", selected_activity_id)
	return true


func pause() -> bool:
	if screen not in [Screen.HOME, Screen.MURAL, Screen.ROUTINE, Screen.COMMUNICATION, Screen.ACTIVITY, Screen.BREATH, Screen.DANCE, Screen.FROG]:
		return false
	paused_from = screen
	screen = Screen.PAUSED
	_create_event("pause_requested", selected_activity_id)
	changed.emit()
	return true


func resume_from_therapist() -> bool:
	if screen != Screen.PAUSED:
		return false
	screen = paused_from
	changed.emit()
	return true


func pause_from_therapist() -> bool:
	if screen not in [Screen.HOME, Screen.MURAL, Screen.ROUTINE, Screen.COMMUNICATION, Screen.ACTIVITY, Screen.BREATH, Screen.DANCE, Screen.FROG]:
		return false
	paused_from = screen
	screen = Screen.PAUSED
	changed.emit()
	return true


func end_from_therapist() -> bool:
	if screen in [Screen.WAITING, Screen.CLOSED]:
		return false
	screen = Screen.CLOSED
	changed.emit()
	return true


func _create_event(action: String, activity_id: String, details: Dictionary = {}) -> void:
	_event_sequence += 1
	var payload := {
		"event": "CHILD_INPUT",
		"schema_version": 1,
		"event_id": "%s-%s" % [session_id, Crypto.new().generate_random_bytes(16).hex_encode()],
		"session_id": session_id,
		"timestamp_ms": int(Time.get_unix_time_from_system() * 1000.0),
		"action": action
	}
	if not activity_id.is_empty():
		payload["activity_id"] = activity_id
	for key: Variant in details:
		payload[key] = details[key]
	event_created.emit(payload)
