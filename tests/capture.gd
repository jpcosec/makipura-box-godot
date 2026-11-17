extends SceneTree


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var screen := OS.get_environment("MAKIPURA_CAPTURE_SCREEN")
	if screen == "pause":
		_find_button(scene, "Pausa").pressed.emit()
	elif screen == "routine":
		_find_button(scene, "Mi rutina").pressed.emit()
	elif screen == "communication":
		_find_button(scene, "Quiero decir").pressed.emit()
	elif screen == "breath":
		_find_button(scene, "Respirar").pressed.emit()
	elif screen == "dance":
		_find_button(scene, "Baile").pressed.emit()
	elif screen == "frog":
		_find_button(scene, "Moverme").pressed.emit()
	elif screen == "game" or screen == "movement":
		_find_button(scene, "Juego").pressed.emit()
		_find_button(scene, "Juego" if screen == "game" else "Movimiento").pressed.emit()
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var output := OS.get_environment("MAKIPURA_CAPTURE_PATH")
	if output.is_empty():
		output = "user://tablet-home.png"
	var result := image.save_png(output)
	print("Capture result: ", result, " path: ", output)
	quit(0 if result == OK else 1)


func _find_button(node: Node, title: String) -> Button:
	if node is Button and ((node as Button).text == title or (node as Button).accessibility_name == title):
		return node as Button
	for child: Node in node.get_children():
		var found := _find_button(child, title)
		if found != null:
			return found
	return null


func _collect_cards(node: Node, cards: Array[Button]) -> void:
	if node is Button and (node as Button).text.is_empty():
		cards.append(node as Button)
	for child: Node in node.get_children():
		_collect_cards(child, cards)
