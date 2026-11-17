extends SceneTree

const SessionScript = preload("res://scripts/box_session.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	ProjectSettings.set_setting("makipura/demo/enabled", false)
	ProjectSettings.set_setting("makipura/server/url", OS.get_environment("MAKIPURA_TEST_WS_URL"))
	var app: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	if not await _wait_for_state(app, SessionScript.Screen.MURAL):
		push_error("No START_SESSION received")
		quit(1)
		return
	var picker := _find_button(app, "Juego")
	if picker == null:
		push_error("Game navigation missing")
		quit(1)
		return
	picker.pressed.emit()
	var card := _find_card(app)
	if card == null:
		push_error("Game card missing")
		quit(1)
		return
	card.pressed.emit()
	if not await _wait_for_ack(app):
		push_error("Event was not acknowledged")
		quit(1)
		return
	if not await _wait_for_state(app, SessionScript.Screen.CLOSED):
		push_error("No END_SESSION received")
		quit(1)
		return
	app.queue_free()
	await process_frame
	print("MAKIPURA socket check passed")
	quit(0)


func _wait_for_state(app: Control, wanted: int) -> bool:
	for attempt: int in 100:
		if app.session.screen == wanted:
			return true
		await create_timer(0.05).timeout
	return false


func _wait_for_ack(app: Control) -> bool:
	for attempt: int in 100:
		if app.client.pending_count() == 0:
			return true
		await create_timer(0.05).timeout
	return false


func _find_card(node: Node) -> Button:
	if node is Button and (node as Button).accessibility_name == "Juego":
		return node as Button
	for child: Node in node.get_children():
		var found := _find_card(child)
		if found != null:
			return found
	return null


func _find_button(node: Node, title: String) -> Button:
	if node is Button and ((node as Button).text == title or (node as Button).accessibility_name == title):
		return node as Button
	for child: Node in node.get_children():
		var found := _find_button(child, title)
		if found != null:
			return found
	return null
