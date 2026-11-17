extends SceneTree

const RealtimeClient = preload("res://scripts/realtime_client.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var path := "user://pending-test-%s.json" % Crypto.new().generate_random_bytes(8).hex_encode()
	var first: Node = RealtimeClient.new()
	first.outbox_path = path
	root.add_child(first)
	first.queue_event({"event_id": "test-1", "event": "CHILD_INPUT"})
	if first.pending_count() != 1 or not FileAccess.file_exists(path):
		push_error("La cola no se guardó")
		quit(1)
		return
	first.queue_free()
	await process_frame
	var restored: Node = RealtimeClient.new()
	restored.outbox_path = path
	root.add_child(restored)
	if restored.pending_count() != 1:
		push_error("La cola no se restauró")
		quit(1)
		return
	restored._acknowledge("test-1")
	if restored.pending_count() != 0:
		push_error("El evento confirmado sigue pendiente")
		quit(1)
		return
	restored.queue_free()
	await process_frame
	var empty: Node = RealtimeClient.new()
	empty.outbox_path = path
	root.add_child(empty)
	if empty.pending_count() != 0:
		push_error("El evento confirmado reapareció")
		quit(1)
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	empty.queue_free()
	print("MAKIPURA durable outbox check passed")
	quit(0)
