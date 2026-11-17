extends Node

signal message_received(message: Dictionary)
signal connection_changed(connected: bool)
signal event_acknowledged(event_id: String)

const RETRY_SECONDS := 3.0

var outbox_path: String = "user://pending-events.json"
var server_url: String = ""
var connected: bool = false
var _socket: WebSocketPeer
var _retry_after: float = 0.0
var _outbox: Array[Dictionary] = []
var _sent_in_connection: Dictionary = {}


func _ready() -> void:
	_load_outbox()


func configure(url: String) -> void:
	server_url = url.strip_edges()
	if not server_url.is_empty():
		_attempt_connect()


func queue_event(payload: Dictionary) -> void:
	_outbox.append(payload.duplicate(true))
	_save_outbox()
	_flush_outbox()


func pending_count() -> int:
	return _outbox.size()


func _process(delta: float) -> void:
	if server_url.is_empty():
		return
	if _socket == null:
		_retry_after -= delta
		if _retry_after <= 0.0:
			_attempt_connect()
		return
	_socket.poll()
	var state := _socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not connected:
			connected = true
			connection_changed.emit(true)
			_flush_outbox()
		while _socket.get_available_packet_count() > 0:
			var parsed: Variant = JSON.parse_string(_socket.get_packet().get_string_from_utf8())
			if typeof(parsed) != TYPE_DICTIONARY:
				continue
			var message: Dictionary = parsed
			if message.get("event") == "EVENT_ACK":
				_acknowledge(str(message.get("event_id", "")))
			else:
				message_received.emit(message)
	elif state == WebSocketPeer.STATE_CLOSED:
		_socket = null
		_sent_in_connection.clear()
		_retry_after = RETRY_SECONDS
		if connected:
			connected = false
			connection_changed.emit(false)


func _attempt_connect() -> void:
	_socket = WebSocketPeer.new()
	var result := _socket.connect_to_url(server_url)
	if result != OK:
		_socket = null
		_retry_after = RETRY_SECONDS


func _flush_outbox() -> void:
	if not connected or _socket == null:
		return
	for payload: Dictionary in _outbox:
		var event_id := str(payload.get("event_id", ""))
		if _sent_in_connection.has(event_id):
			continue
		if _socket.send_text(JSON.stringify(payload)) == OK:
			_sent_in_connection[event_id] = true


func _acknowledge(event_id: String) -> void:
	if event_id.is_empty():
		return
	for index: int in range(_outbox.size() - 1, -1, -1):
		if _outbox[index].get("event_id") == event_id:
			_outbox.remove_at(index)
			_sent_in_connection.erase(event_id)
			_save_outbox()
			event_acknowledged.emit(event_id)
			break


func _load_outbox() -> void:
	if not FileAccess.file_exists(outbox_path):
		return
	var file := FileAccess.open(outbox_path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		push_warning("No se pudo leer la cola de eventos pendiente")
		return
	for item: Variant in parsed:
		if typeof(item) == TYPE_DICTIONARY and not str(item.get("event_id", "")).is_empty():
			_outbox.append(item)


func _save_outbox() -> void:
	var temporary := outbox_path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		push_error("No se pudo guardar la cola de eventos")
		return
	file.store_string(JSON.stringify(_outbox))
	file.flush()
	file.close()
	var result := DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(outbox_path))
	if result != OK:
		push_error("No se pudo confirmar la cola de eventos")
