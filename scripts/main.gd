extends Control

const BoxSessionModel = preload("res://scripts/box_session.gd")
const RealtimeClient = preload("res://scripts/realtime_client.gd")
const FOX = preload("res://assets/zorro.jpg")
const FROG = preload("res://assets/ranita.svg")
const KOALA = preload("res://assets/koala.svg")
const LEXEND = preload("res://assets/Lexend.ttf")
const RABBIT_ICON = preload("res://assets/icon-rabbit.svg")
const PUZZLE_ICON = preload("res://assets/icon-puzzle.svg")
const MOVEMENT_ICON = preload("res://assets/icon-movement.svg")
const AIR_ICON = preload("res://assets/icon-air.svg")
const PAUSE_ICON = preload("res://assets/icon-pause.svg")
const HELP_ICON = preload("res://assets/icon-help.svg")
const MURAL_HILLS = preload("res://assets/mural-hills.svg")
const MOOD_BIEN = preload("res://assets/mood-bien.svg")
const MOOD_TRANQUILO = preload("res://assets/mood-tranquilo.svg")
const MOOD_TRISTE = preload("res://assets/mood-triste.svg")
const MOOD_ENOJADO = preload("res://assets/mood-enojado.svg")

const INK := Color("#1A2624")
const TEAL := Color("#1E4E4B")
const MINT := Color("#ECFBF4")
const SAND := Color("#FFFAED")
const PAPER := Color("#f8f7f3")
const WHITE := Color("#ffffff")
const LINE := Color("#DDD8CE")
const MUTED := Color("#566360")
const CORAL := Color("#FFF1F3")
const AMBER := Color("#A94C06")
const AMBER_LINE := Color("#F3D487")
const GREEN := Color("#007D5A")
const GREEN_LINE := Color("#AAF0D4")

var session: RefCounted
var client: Node
var demo_enabled: bool = true
var sound_enabled: bool = true
var reduced_motion: bool = false
var _screen_root: Control
var _feedback_player: AudioStreamPlayer
var _chime_player: AudioStreamPlayer
var _beat_player: AudioStreamPlayer
var _toast: String = ""
var _help_event_id: String = ""
var _game_taps: Array[String] = []
var _breath_phase: int = 0
var _breath_elapsed: float = 0.0
var _breath_pace: int = 0
var _breath_title: Label
var _breath_hint: Label
var _breath_countdown: Label
var _breath_progress: ProgressBar
var _breath_picture: TextureRect
var _dance_rhythm_on: bool = false
var _dance_elapsed: float = 0.0
var _frog_mode: String = "saltar"
var _frog_pad: Button


func _ready() -> void:
	var app_theme := Theme.new()
	app_theme.default_font = LEXEND
	app_theme.default_font_size = 22
	theme = app_theme
	_feedback_player = AudioStreamPlayer.new()
	_feedback_player.stream = _make_tone()
	add_child(_feedback_player)
	_chime_player = AudioStreamPlayer.new()
	_chime_player.stream = _make_tone(659.25, 0.3)
	_chime_player.volume_db = -10.0
	add_child(_chime_player)
	_beat_player = AudioStreamPlayer.new()
	_beat_player.stream = _make_tone(330.0, 0.12)
	_beat_player.volume_db = -15.0
	add_child(_beat_player)
	session = BoxSessionModel.new()
	session.changed.connect(_render)
	session.event_created.connect(_on_event_created)
	client = RealtimeClient.new()
	add_child(client)
	client.message_received.connect(_on_server_message)
	client.event_acknowledged.connect(_on_event_acknowledged)
	var environment_url := OS.get_environment("MAKIPURA_BOX_URL").strip_edges()
	demo_enabled = bool(ProjectSettings.get_setting("makipura/demo/enabled", true)) and environment_url.is_empty()
	client.configure(environment_url if not environment_url.is_empty() else str(ProjectSettings.get_setting("makipura/server/url", "")))
	if demo_enabled:
		session.start_session({
			"session_id": "demo-local",
			"activities": [
				{"id": "juego", "type": "game", "title": "Juego", "instruction": "Toca las figuras"},
				{"id": "movimiento", "type": "movement", "title": "Movimiento", "instruction": "Muévete a tu ritmo con tu terapeuta"}
			],
			"routine": [
				{"id": "elegir", "title": "Elegir qué hacer"},
				{"id": "actividad", "title": "Jugar o moverme"},
				{"id": "calma", "title": "Descansar y respirar"}
			],
			"communication": [
				{"id": "ayuda", "label": "Necesito ayuda"},
				{"id": "pausa", "label": "Quiero una pausa"},
				{"id": "bien", "label": "Estoy bien"},
				{"id": "otro", "label": "Quiero otra cosa"}
			]
		})
	else:
		_render()


func _process(delta: float) -> void:
	if session == null:
		return
	if session.screen == BoxSessionModel.Screen.BREATH:
		var durations: Array[int] = [4, 2, 4]
		if _breath_pace == 1:
			durations = [5, 3, 5]
		_breath_elapsed += delta
		if _breath_elapsed >= float(durations[_breath_phase]):
			_breath_elapsed -= float(durations[_breath_phase])
			_breath_phase = (_breath_phase + 1) % 3
			if sound_enabled:
				_chime_player.play()
		_refresh_breath_ui()
	elif session.screen == BoxSessionModel.Screen.DANCE and _dance_rhythm_on and sound_enabled:
		_dance_elapsed += delta
		if _dance_elapsed >= 0.8:
			_dance_elapsed = 0.0
			_beat_player.play()


func _render() -> void:
	if _screen_root != null:
		remove_child(_screen_root)
		_screen_root.queue_free()
	_screen_root = Control.new()
	_screen_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_screen_root)
	if session.screen == BoxSessionModel.Screen.MURAL:
		_build_mural(_screen_root)
		return
	if session.screen in [BoxSessionModel.Screen.BREATH, BoxSessionModel.Screen.DANCE, BoxSessionModel.Screen.FROG]:
		_build_guided_action(_screen_root)
		return
	var background := ColorRect.new()
	background.color = PAPER
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen_root.add_child(background)
	var layout := VBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 0)
	_screen_root.add_child(layout)
	_build_header(layout)
	var content_margins := MarginContainer.new()
	content_margins.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margins.add_theme_constant_override("margin_left", 124)
	content_margins.add_theme_constant_override("margin_right", 124)
	content_margins.add_theme_constant_override("margin_top", 24)
	content_margins.add_theme_constant_override("margin_bottom", 22)
	layout.add_child(content_margins)
	var content := VBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	content_margins.add_child(content)
	match session.screen:
		BoxSessionModel.Screen.HOME:
			_build_home(content)
		BoxSessionModel.Screen.ROUTINE:
			_build_routine(content)
		BoxSessionModel.Screen.COMMUNICATION:
			_build_communication(content)
		BoxSessionModel.Screen.ACTIVITY:
			_build_activity(content)
		BoxSessionModel.Screen.PAUSED:
			_build_pause(content)
		BoxSessionModel.Screen.CLOSED:
			_build_closed(content)
		_:
			_build_waiting(content)
	_build_footer(layout)


func _mural_background(parent: Control) -> void:
	var backdrop := TextureRect.new()
	backdrop.texture = MURAL_HILLS
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(backdrop)


func _build_mural(parent: Control) -> void:
	_mural_background(parent)
	var margins := MarginContainer.new()
	margins.set_anchors_preset(Control.PRESET_FULL_RECT)
	margins.add_theme_constant_override("margin_left", 42)
	margins.add_theme_constant_override("margin_right", 42)
	margins.add_theme_constant_override("margin_top", 25)
	margins.add_theme_constant_override("margin_bottom", 22)
	parent.add_child(margins)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margins.add_child(layout)
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 100
	header.add_theme_constant_override("separation", 13)
	layout.add_child(header)
	var sound := _button("Sonido" if sound_enabled else "Silencio", WHITE, TEAL, WHITE)
	sound.custom_minimum_size = Vector2(150, 66)
	sound.add_theme_font_size_override("font_size", 18)
	sound.pressed.connect(_toggle_sound)
	header.add_child(sound)
	var zen := _button("Modo Zen", Color("#D8FAEA"), TEAL, GREEN_LINE)
	zen.custom_minimum_size = Vector2(155, 66)
	zen.add_theme_font_size_override("font_size", 18)
	zen.pressed.connect(_start_breath)
	header.add_child(zen)
	var movement := _button("Moverme", Color("#DDFDF7"), TEAL, GREEN_LINE)
	movement.custom_minimum_size = Vector2(145, 66)
	movement.add_theme_font_size_override("font_size", 18)
	movement.pressed.connect(_start_movement)
	header.add_child(movement)
	var heading_group := VBoxContainer.new()
	heading_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_group.add_theme_constant_override("separation", 0)
	header.add_child(heading_group)
	var heading := _label("¿Cómo te sientes hoy?", 41, Color("#123B36"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading_group.add_child(heading)
	var subtitle := _label("Toca una tarjeta para compartir cómo estás", 15, TEAL)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading_group.add_child(subtitle)
	var home := _button("⌂", TEAL, WHITE, GREEN)
	home.accessibility_name = "Elegir actividad"
	home.custom_minimum_size = Vector2(70, 70)
	home.add_theme_font_size_override("font_size", 42)
	home.disabled = session.activities.is_empty()
	home.pressed.connect(_open_picker)
	header.add_child(home)
	var moods := HBoxContainer.new()
	moods.size_flags_vertical = Control.SIZE_EXPAND_FILL
	moods.add_theme_constant_override("separation", 22)
	layout.add_child(moods)
	var mood_data: Array[Dictionary] = [
		{"id": "bien", "label": "Bien", "subtitle": "Alegre y en paz", "icon": MOOD_BIEN},
		{"id": "tranquilo", "label": "Tranquilo", "subtitle": "Calmado y relajado", "icon": MOOD_TRANQUILO},
		{"id": "triste", "label": "Triste", "subtitle": "Necesito un abrazo", "icon": MOOD_TRISTE},
		{"id": "enojado", "label": "Enojado", "subtitle": "Siento mucha molestia", "icon": MOOD_ENOJADO}
	]
	for mood: Dictionary in mood_data:
		var card := _mural_card(str(mood["label"]), str(mood["subtitle"]), mood["icon"], str(mood["id"]) == session.selected_emotion_id)
		card.pressed.connect(_select_emotion.bind(str(mood["id"]), card))
		moods.add_child(card)
	var actions := HBoxContainer.new()
	actions.size_flags_vertical = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation", 22)
	layout.add_child(actions)
	var action_data: Array[Dictionary] = [
		{"id": "respirar", "label": "Respirar", "subtitle": "Inhala y exhala", "icon": AIR_ICON},
		{"id": "baile", "label": "Baile", "subtitle": "Música y ritmo", "icon": null},
		{"id": "moverme", "label": "Moverme", "subtitle": "Saltar y estirar", "icon": MOVEMENT_ICON},
		{"id": "pausa", "label": "Pausa", "subtitle": "Silencio y calma", "icon": PAUSE_ICON}
	]
	for action: Dictionary in action_data:
		var card := _mural_card(str(action["label"]), str(action["subtitle"]), action["icon"], false)
		card.pressed.connect(_choose_mural_action.bind(str(action["id"])))
		actions.add_child(card)
	var footer := HBoxContainer.new()
	footer.custom_minimum_size.y = 60
	footer.add_theme_constant_override("separation", 12)
	layout.add_child(footer)
	var status := _label(_toast if not _toast.is_empty() else "●  Makipura Box: listo para acompañarte", 17, TEAL)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(status)
	if not session.activities.is_empty():
		footer.add_child(_mural_small_button("Juego", _open_picker))
	if not session.routine.is_empty():
		footer.add_child(_mural_small_button("Mi rutina", _show_routine))
	if not session.communication_options.is_empty():
		footer.add_child(_mural_small_button("Quiero decir", _show_communication))
	footer.add_child(_mural_small_button("Ayuda", _request_help))


func _mural_card(title: String, subtitle: String, icon: Texture2D, selected: bool) -> Button:
	var card := _button("", WHITE, INK, GREEN if selected else WHITE)
	card.accessibility_name = title
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 250)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 10)
	card.add_child(content)
	if icon == null:
		var music := _label("♫", 110, Color("#F07B2E"))
		music.mouse_filter = Control.MOUSE_FILTER_IGNORE
		music.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(music)
	else:
		var picture := _image(icon, Vector2(122, 122))
		picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		content.add_child(picture)
	var label := _label(title, 28, INK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(label)
	var detail := _label(subtitle, 16, MUTED)
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(detail)
	return card


func _mural_small_button(title: String, callback: Callable) -> Button:
	var button := _button(title, WHITE, TEAL, LINE)
	button.custom_minimum_size = Vector2(132, 58)
	button.add_theme_font_size_override("font_size", 17)
	button.pressed.connect(callback)
	return button


func _build_guided_action(parent: Control) -> void:
	if session.screen == BoxSessionModel.Screen.FROG:
		_build_frog_action(parent)
		return
	_mural_background(parent)
	var margins := MarginContainer.new()
	margins.set_anchors_preset(Control.PRESET_FULL_RECT)
	margins.add_theme_constant_override("margin_left", 140)
	margins.add_theme_constant_override("margin_right", 140)
	margins.add_theme_constant_override("margin_top", 45)
	margins.add_theme_constant_override("margin_bottom", 45)
	parent.add_child(margins)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margins.add_child(layout)
	var top_controls := HBoxContainer.new()
	top_controls.add_theme_constant_override("separation", 12)
	layout.add_child(top_controls)
	var back := _button("←  Volver", WHITE, TEAL, LINE)
	back.custom_minimum_size = Vector2(180, 62)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(_back_mural)
	top_controls.add_child(back)
	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_controls.add_child(top_spacer)
	var pause := _button("Pausa", SAND, AMBER, AMBER_LINE)
	pause.custom_minimum_size = Vector2(150, 62)
	pause.pressed.connect(_pause)
	top_controls.add_child(pause)
	var is_breath: bool = session.screen == BoxSessionModel.Screen.BREATH
	var heading := _label("Respiremos juntos" if is_breath else "¡Vamos a movernos!", 48, INK)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(heading)
	var subtitle := _label("Inhala cuando crece, exhala cuando baja" if is_breath else "Baila y muévete a tu ritmo con tu terapeuta", 24, TEAL)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(subtitle)
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(center)
	var picture := _image(KOALA if is_breath else FROG, Vector2(270, 270))
	center.add_child(picture)
	if is_breath:
		picture.pivot_offset = Vector2(135, 135)
		_breath_picture = picture
		_breath_title = _label("Inhala profundo…", 34, TEAL)
		_breath_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		layout.add_child(_breath_title)
		_breath_hint = _label("Llena tu pancita de aire suave", 19, MUTED)
		_breath_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		layout.add_child(_breath_hint)
		_breath_progress = ProgressBar.new()
		_breath_progress.custom_minimum_size.y = 18
		_breath_progress.show_percentage = false
		_breath_progress.add_theme_stylebox_override("background", _style(WHITE, GREEN_LINE, 1))
		_breath_progress.add_theme_stylebox_override("fill", _style(Color("#5EB1A6"), Color("#5EB1A6"), 0))
		layout.add_child(_breath_progress)
		_breath_countdown = _label("4 segundos", 17, TEAL)
		_breath_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		layout.add_child(_breath_countdown)
		var pace_row := HBoxContainer.new()
		pace_row.add_theme_constant_override("separation", 12)
		layout.add_child(pace_row)
		for pace: int in 2:
			var pace_button := _button("Suave 4-2-4" if pace == 0 else "Pausado 5-3-5", TEAL if pace == _breath_pace else WHITE, WHITE if pace == _breath_pace else TEAL, LINE)
			pace_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pace_button.custom_minimum_size.y = 60
			pace_button.add_theme_font_size_override("font_size", 18)
			pace_button.pressed.connect(_set_breath_pace.bind(pace))
			pace_row.add_child(pace_button)
		var chime := _button("Campana Zen", WHITE, TEAL, GREEN_LINE)
		chime.custom_minimum_size.y = 60
		chime.pressed.connect(_play_chime)
		layout.add_child(chime)
		_refresh_breath_ui()
	else:
		var rhythm := _button("Detener ritmo" if _dance_rhythm_on else "Activar ritmo suave", WHITE, TEAL, GREEN_LINE)
		rhythm.custom_minimum_size.y = 66
		rhythm.pressed.connect(_toggle_dance_rhythm)
		layout.add_child(rhythm)
	var done := _button("Terminé", TEAL, WHITE, TEAL)
	done.custom_minimum_size.y = 86
	done.pressed.connect(_complete_guided_action)
	layout.add_child(done)


func _build_frog_action(parent: Control) -> void:
	_mural_background(parent)
	var margins := MarginContainer.new()
	margins.set_anchors_preset(Control.PRESET_FULL_RECT)
	margins.add_theme_constant_override("margin_left", 110)
	margins.add_theme_constant_override("margin_right", 110)
	margins.add_theme_constant_override("margin_top", 32)
	margins.add_theme_constant_override("margin_bottom", 32)
	parent.add_child(margins)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margins.add_child(layout)
	var back := _button("←  Volver al Box", WHITE, TEAL, LINE)
	back.custom_minimum_size = Vector2(230, 58)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(_back_mural)
	layout.add_child(back)
	var heading := _label("¡Salta con la Ranita!", 43, INK)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(heading)
	var subtitle := _label("Toca a la ranita y muévete a tu ritmo", 20, TEAL)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(subtitle)
	var pad_center := CenterContainer.new()
	pad_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(pad_center)
	_frog_pad = _button("", MINT, TEAL, GREEN_LINE)
	_frog_pad.accessibility_name = "Tocar a la ranita"
	_frog_pad.custom_minimum_size = Vector2(310, 310)
	_frog_pad.pressed.connect(_touch_frog)
	pad_center.add_child(_frog_pad)
	var frog_image := _image(FROG, Vector2(270, 270))
	frog_image.set_anchors_preset(Control.PRESET_FULL_RECT)
	frog_image.offset_left = 20
	frog_image.offset_top = 20
	frog_image.offset_right = -20
	frog_image.offset_bottom = -20
	_frog_pad.add_child(frog_image)
	var instructions := {"saltar": "¡Salta alto como la ranita!", "estirar": "Estira tus brazos suavemente", "sacudir": "Sacude el cuerpo a tu ritmo"}
	var action_title := _label(instructions[_frog_mode], 29, INK)
	action_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(action_title)
	var stars := _label("Saltos de energía: %d   %s" % [session.frog_count, "★".repeat(min(session.frog_count, 5))], 20, GREEN)
	stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(stars)
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 12)
	layout.add_child(modes)
	for mode: String in ["saltar", "estirar", "sacudir"]:
		var mode_button := _button(mode.capitalize(), TEAL if mode == _frog_mode else WHITE, WHITE if mode == _frog_mode else TEAL, GREEN_LINE)
		mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mode_button.custom_minimum_size.y = 70
		mode_button.pressed.connect(_set_frog_mode.bind(mode))
		modes.add_child(mode_button)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 12)
	layout.add_child(controls)
	for control: String in ["Sonido boing", "Pausa", "Terminé"]:
		var button := _button(control, TEAL if control == "Terminé" else WHITE, WHITE if control == "Terminé" else TEAL, LINE)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 70
		if control == "Sonido boing":
			button.pressed.connect(_play_chime)
		elif control == "Pausa":
			button.pressed.connect(_pause)
		else:
			button.pressed.connect(_complete_guided_action)
		controls.add_child(button)


func _build_header(parent: VBoxContainer) -> void:
	var header := PanelContainer.new()
	header.custom_minimum_size.y = 112
	var header_style := _style(WHITE, LINE, 0)
	header_style.border_width_bottom = 2
	header_style.set_corner_radius_all(0)
	header.add_theme_stylebox_override("panel", header_style)
	parent.add_child(header)
	var margins := MarginContainer.new()
	margins.add_theme_constant_override("margin_left", 32)
	margins.add_theme_constant_override("margin_right", 32)
	margins.add_theme_constant_override("margin_top", 16)
	margins.add_theme_constant_override("margin_bottom", 16)
	header.add_child(margins)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	margins.add_child(row)
	var brand := HBoxContainer.new()
	brand.custom_minimum_size.x = 290
	brand.add_theme_constant_override("separation", 12)
	row.add_child(brand)
	var icon_tile := PanelContainer.new()
	icon_tile.custom_minimum_size = Vector2(64, 64)
	icon_tile.add_theme_stylebox_override("panel", _style(Color("#F1EEE7"), LINE, 2))
	brand.add_child(icon_tile)
	var rabbit := _image(RABBIT_ICON, Vector2(46, 46))
	icon_tile.add_child(rabbit)
	var brand_text := VBoxContainer.new()
	brand_text.alignment = BoxContainer.ALIGNMENT_CENTER
	brand_text.add_theme_constant_override("separation", 0)
	brand.add_child(brand_text)
	brand_text.add_child(_label("Makipura", 29, TEAL))
	brand_text.add_child(_label("●  Espacio Seguro · Sala de Terapia", 12, MUTED))
	var progress := PanelContainer.new()
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress.custom_minimum_size.y = 62
	progress.add_theme_stylebox_override("panel", _style(Color("#F1EEE7"), LINE, 1))
	row.add_child(progress)
	var steps := HBoxContainer.new()
	steps.alignment = BoxContainer.ALIGNMENT_CENTER
	steps.add_theme_constant_override("separation", 11)
	progress.add_child(steps)
	var active_step := 1
	if session.screen == BoxSessionModel.Screen.ACTIVITY:
		active_step = 2
	elif session.screen == BoxSessionModel.Screen.PAUSED:
		active_step = 3
	for index: int in 3:
		if index > 0:
			steps.add_child(_label("›", 20, MUTED))
		var step_text: String = ["Elegir", "Jugar o Mover", "Calma"][index]
		var step := _label("%d  %s" % [index + 1, step_text], 16, TEAL if active_step == index + 1 else MUTED)
		steps.add_child(step)
	if session.screen not in [BoxSessionModel.Screen.WAITING, BoxSessionModel.Screen.CLOSED]:
		var sound_button := _button("Escuchar" if sound_enabled else "Silencio", Color("#F1EEE7"), INK, LINE)
		sound_button.custom_minimum_size = Vector2(150, 62)
		sound_button.add_theme_font_size_override("font_size", 17)
		sound_button.pressed.connect(_toggle_sound)
		row.add_child(sound_button)


func _build_home(parent: VBoxContainer) -> void:
	var pill := PanelContainer.new()
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pill.add_theme_stylebox_override("panel", _style(Color("#E4EEEB"), Color("#B8CECA"), 1))
	parent.add_child(pill)
	var pill_text := _label("Momento de elección individual", 17, TEAL)
	pill_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pill.add_child(pill_text)
	var title := _label("¡Hola! ¿Qué quieres hacer hoy?", 43, INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(title)
	var instruction := _label("Toca una de las tarjetas grandes para comenzar con tu terapeuta.", 18, MUTED)
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(instruction)
	if not session.routine.is_empty() or not session.communication_options.is_empty():
		var navigation := HBoxContainer.new()
		navigation.add_theme_constant_override("separation", 18)
		parent.add_child(navigation)
		if not session.routine.is_empty():
			var routine_button := _button("Mi rutina  →", WHITE, TEAL, LINE)
			routine_button.custom_minimum_size.y = 62
			routine_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			routine_button.add_theme_font_size_override("font_size", 19)
			routine_button.pressed.connect(_show_routine)
			navigation.add_child(routine_button)
		if not session.communication_options.is_empty():
			var communication_button := _button("Quiero decir  →", WHITE, TEAL, LINE)
			communication_button.custom_minimum_size.y = 62
			communication_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			communication_button.add_theme_font_size_override("font_size", 19)
			communication_button.pressed.connect(_show_communication)
			navigation.add_child(communication_button)
	var cards := HBoxContainer.new()
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation", 30)
	parent.add_child(cards)
	for activity: Dictionary in session.activities:
		var card := _activity_card(activity)
		card.pressed.connect(_choose_activity.bind(str(activity["id"])))
		cards.add_child(card)
	var rest := _rest_card()
	rest.pressed.connect(_pause)
	parent.add_child(rest)


func _build_routine(parent: VBoxContainer) -> void:
	var back := _button("←  Volver a elegir", WHITE, TEAL, LINE)
	back.custom_minimum_size = Vector2(250, 60)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.add_theme_font_size_override("font_size", 18)
	back.pressed.connect(_back_home)
	parent.add_child(back)
	var heading := _label("Mi rutina de hoy", 42, INK)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(heading)
	var hint := _label("Vamos paso a paso. Tu terapeuta te acompaña.", 19, MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(hint)
	var list := VBoxContainer.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 16)
	parent.add_child(list)
	for index: int in session.routine.size():
		var step: Dictionary = session.routine[index]
		var active: bool = index == session.routine_index
		var completed: bool = index < session.routine_index
		var tile := PanelContainer.new()
		tile.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tile.add_theme_stylebox_override("panel", _style(MINT if active else WHITE, GREEN_LINE if active else LINE, 3 if active else 1))
		list.add_child(tile)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 22)
		tile.add_child(row)
		var number := _label("✓" if completed else str(index + 1), 28, GREEN if active or completed else MUTED)
		number.custom_minimum_size.x = 54
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(number)
		var title := _label(str(step["title"]), 26, INK if active else MUTED)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(title)
		var state := _label("Ahora" if active else ("Listo" if completed else "Después"), 17, GREEN if active or completed else MUTED)
		state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(state)
	var next := _button("Estoy listo para seguir", TEAL, WHITE, TEAL)
	next.custom_minimum_size.y = 78
	next.pressed.connect(_request_next_step)
	parent.add_child(next)


func _build_communication(parent: VBoxContainer) -> void:
	var back := _button("←  Volver a elegir", WHITE, TEAL, LINE)
	back.custom_minimum_size = Vector2(250, 60)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.add_theme_font_size_override("font_size", 18)
	back.pressed.connect(_back_home)
	parent.add_child(back)
	var heading := _label("¿Qué quieres decir?", 42, INK)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(heading)
	var hint := _label("Toca una tarjeta para contarle a tu terapeuta.", 19, MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(hint)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 22)
	parent.add_child(grid)
	for index: int in session.communication_options.size():
		var option: Dictionary = session.communication_options[index]
		var color := SAND if index % 2 == 0 else MINT
		var border := AMBER_LINE if index % 2 == 0 else GREEN_LINE
		var button := _button(str(option["label"]), color, TEAL, border)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(430, 150)
		button.add_theme_font_size_override("font_size", 25)
		button.pressed.connect(_choose_communication.bind(str(option["id"])))
		grid.add_child(button)


func _build_activity(parent: VBoxContainer) -> void:
	var activity: Dictionary = session.current_activity()
	var kind := str(activity.get("type", "game"))
	var title := _label(str(activity.get("title", "Actividad")), 48, INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(title)
	if kind == "game":
		_build_game(parent)
	elif kind == "calm":
		_build_calm(parent, activity)
	else:
		_build_movement(parent, activity)


func _build_game(parent: VBoxContainer) -> void:
	var prompt := _label("Toca las figuras", 28, MUTED)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(prompt)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(spacer)
	var shapes := HBoxContainer.new()
	shapes.alignment = BoxContainer.ALIGNMENT_CENTER
	shapes.add_theme_constant_override("separation", 32)
	parent.add_child(shapes)
	for symbol: String in ["●", "▲", "■"]:
		var touched := symbol in _game_taps
		var shape := _button(symbol, LINE if touched else MINT, TEAL, LINE)
		shape.accessibility_name = {"●": "Círculo", "▲": "Triángulo", "■": "Cuadrado"}[symbol]
		shape.custom_minimum_size = Vector2(210, 210)
		shape.add_theme_font_size_override("font_size", 90)
		shape.disabled = touched
		shape.pressed.connect(_touch_shape.bind(symbol))
		shapes.add_child(shape)
	var lower := Control.new()
	lower.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(lower)
	if _game_taps.size() == 3:
		var done := _button("Volver a elegir", TEAL, WHITE, TEAL)
		done.custom_minimum_size.y = 82
		done.pressed.connect(_complete_activity)
		parent.add_child(done)


func _build_movement(parent: VBoxContainer, activity: Dictionary) -> void:
	var image := _image(FROG, Vector2(280, 280))
	image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(image)
	var words := str(activity.get("instruction", "")).strip_edges()
	if words.is_empty():
		words = "Muévete a tu ritmo"
	var prompt := _label(words, 32, TEAL)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(prompt)
	var done := _button("Terminé", TEAL, WHITE, TEAL)
	done.custom_minimum_size.y = 88
	done.pressed.connect(_complete_activity)
	parent.add_child(done)


func _build_calm(parent: VBoxContainer, activity: Dictionary) -> void:
	var image := _image(AIR_ICON, Vector2(240, 240))
	image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(image)
	var words := str(activity.get("instruction", "Respira a tu ritmo con tu terapeuta")).strip_edges()
	var prompt := _label(words, 31, TEAL)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(prompt)
	var done := _button("Terminé", TEAL, WHITE, TEAL)
	done.custom_minimum_size.y = 88
	done.pressed.connect(_complete_activity)
	parent.add_child(done)


func _build_pause(parent: VBoxContainer) -> void:
	_add_centered_message(parent, KOALA, "Hagamos una pausa", "Tómate tu tiempo")
	if demo_enabled:
		var resume := _button("Continuar", TEAL, WHITE, TEAL)
		resume.custom_minimum_size.y = 86
		resume.pressed.connect(_resume_demo)
		parent.add_child(resume)


func _build_closed(parent: VBoxContainer) -> void:
	_add_centered_message(parent, KOALA, "Terminamos por hoy", "Gracias por participar")


func _build_waiting(parent: VBoxContainer) -> void:
	_add_centered_message(parent, FROG, "Estamos preparando todo", "Tu terapeuta iniciará la sesión")


func _add_centered_message(parent: VBoxContainer, texture: Texture2D, title: String, subtitle: String) -> void:
	var top := Control.new()
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(top)
	var picture := _image(texture, Vector2(230, 230))
	picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(picture)
	var heading := _label(title, 48, INK)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(heading)
	var subheading := _label(subtitle, 26, MUTED)
	subheading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(subheading)
	var bottom := Control.new()
	bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(bottom)


func _build_footer(parent: VBoxContainer) -> void:
	var footer := PanelContainer.new()
	footer.custom_minimum_size.y = 116
	var footer_style := _style(WHITE, LINE, 0)
	footer_style.border_width_top = 2
	footer_style.set_corner_radius_all(0)
	footer.add_theme_stylebox_override("panel", footer_style)
	parent.add_child(footer)
	var margins := MarginContainer.new()
	margins.add_theme_constant_override("margin_left", 124)
	margins.add_theme_constant_override("margin_right", 124)
	margins.add_theme_constant_override("margin_top", 12)
	margins.add_theme_constant_override("margin_bottom", 12)
	footer.add_child(margins)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	margins.add_child(row)
	if session.screen in [BoxSessionModel.Screen.HOME, BoxSessionModel.Screen.ROUTINE, BoxSessionModel.Screen.COMMUNICATION, BoxSessionModel.Screen.ACTIVITY]:
		var pause_button := _footer_action("Pausa", "Tomar un momento", PAUSE_ICON, SAND, AMBER, Color("#C78D38"))
		pause_button.custom_minimum_size = Vector2(238, 80)
		pause_button.pressed.connect(_pause)
		row.add_child(pause_button)
	var center_text := _toast if not _toast.is_empty() else "Tu terapeuta acompaña cada paso contigo"
	var message := _label(center_text, 15, MUTED)
	message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(message)
	if session.screen in [BoxSessionModel.Screen.HOME, BoxSessionModel.Screen.ROUTINE, BoxSessionModel.Screen.COMMUNICATION, BoxSessionModel.Screen.ACTIVITY, BoxSessionModel.Screen.PAUSED]:
		var help_button := _footer_action("Necesito ayuda", "Avisar a mi terapeuta", HELP_ICON, CORAL, Color("#8A2446"), Color("#F5A9B8"))
		help_button.custom_minimum_size = Vector2(270, 80)
		help_button.pressed.connect(_request_help)
		row.add_child(help_button)


func _activity_card(activity: Dictionary) -> Button:
	var kind := str(activity.get("type", "game"))
	var is_game := kind == "game"
	var is_calm := kind == "calm"
	var card_color := SAND if is_game else MINT
	var border := AMBER_LINE if is_game else GREEN_LINE
	var accent := AMBER if is_game else GREEN
	var texture: Texture2D = PUZZLE_ICON if is_game else (AIR_ICON if is_calm else MOVEMENT_ICON)
	var title := str(activity.get("title", "Actividad"))
	var description := str(activity.get("description", "")).strip_edges()
	if description.is_empty():
		description = "Bloques de encaje, memoria, rompecabezas o retos sensoriales." if is_game else ("Un momento tranquilo para respirar con tu terapeuta." if is_calm else "Equilibrio, circuitos y movimientos guiados con tu terapeuta.")
	var badge_text := "TRANQUILO Y DIVERTIDO" if is_game else ("PAUSA Y REGULACIÓN" if is_calm else "ACTIVO Y COORDINADO")
	var cta_text := "Tocar para jugar" if is_game else ("Tocar para descansar" if is_calm else "Tocar para moverme")
	var card := _button("", card_color, INK, border)
	card.accessibility_name = title
	card.custom_minimum_size = Vector2(0, 360)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 24
	content.offset_right = -24
	content.offset_top = 20
	content.offset_bottom = -20
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 10)
	card.add_child(content)
	var badge := _label(badge_text, 12, accent)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(badge)
	var icon_tile := PanelContainer.new()
	icon_tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_tile.custom_minimum_size = Vector2(112, 112)
	icon_tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_tile.add_theme_stylebox_override("panel", _style(Color("#FFF3CC") if is_game else Color("#D7F8E9"), border, 1))
	content.add_child(icon_tile)
	var picture := _image(texture, Vector2(74, 74))
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_tile.add_child(picture)
	var caption := _label(title, 34, INK)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(caption)
	var details := _label(description, 16, accent)
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.custom_minimum_size.y = 52
	content.add_child(details)
	var cta := PanelContainer.new()
	cta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cta.custom_minimum_size.y = 62
	cta.add_theme_stylebox_override("panel", _style(accent, accent, 1))
	content.add_child(cta)
	var cta_label := _label(cta_text, 20, WHITE)
	cta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cta_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cta.add_child(cta_label)
	return card


func _rest_card() -> Button:
	var rest := _button("", WHITE, INK, LINE)
	rest.accessibility_name = "Prefiero descansar o respirar tranquilo"
	rest.custom_minimum_size.y = 88
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 18
	row.offset_right = -18
	row.add_theme_constant_override("separation", 16)
	rest.add_child(row)
	var icon := _image(AIR_ICON, Vector2(50, 50))
	row.add_child(icon)
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 1)
	row.add_child(words)
	var heading := _label("Prefiero descansar o respirar tranquilo", 19, INK)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(heading)
	var subtitle := _label("Tomar una pausa con mi terapeuta", 13, MUTED)
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(subtitle)
	var arrow := _label("Descansar  →", 15, TEAL)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(arrow)
	return rest


func _footer_action(title: String, subtitle: String, texture: Texture2D, background: Color, foreground: Color, border: Color) -> Button:
	var button := _button("", background, foreground, border)
	button.accessibility_name = title
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 15
	row.offset_right = -15
	row.add_theme_constant_override("separation", 10)
	button.add_child(row)
	row.add_child(_image(texture, Vector2(42, 42)))
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 0)
	row.add_child(words)
	var heading := _label(title, 19, foreground)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(heading)
	var subheading := _label(subtitle, 12, foreground)
	subheading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(subheading)
	return button


func _image(texture: Texture2D, minimum: Vector2) -> TextureRect:
	var image := TextureRect.new()
	image.texture = texture
	image.custom_minimum_size = minimum
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String, background: Color, foreground: Color, border: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.accessibility_name = text
	button.add_theme_font_size_override("font_size", 25)
	button.add_theme_color_override("font_color", foreground)
	button.add_theme_color_override("font_hover_color", foreground)
	button.add_theme_color_override("font_pressed_color", foreground)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_stylebox_override("normal", _style(background, border, 2))
	button.add_theme_stylebox_override("hover", _style(background.lightened(0.04), TEAL, 3))
	button.add_theme_stylebox_override("pressed", _style(background.darkened(0.04), TEAL, 4))
	button.add_theme_stylebox_override("disabled", _style(LINE, LINE, 2))
	button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, TEAL, 4))
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button


func _style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(24)
	style.set_content_margin_all(12)
	return style


func _choose_activity(activity_id: String) -> void:
	_game_taps.clear()
	_toast = ""
	_sound_feedback()
	session.choose_activity(activity_id)


func _open_picker() -> void:
	_sound_feedback()
	_toast = ""
	session.enter_picker()


func _back_mural() -> void:
	_sound_feedback()
	_toast = ""
	session.enter_mural()


func _select_emotion(emotion_id: String, card: Button) -> void:
	_sound_feedback()
	var center := card.get_global_rect().get_center()
	if session.select_emotion(emotion_id):
		_toast = "Gracias por contar cómo te sientes"
		_render()
		_spawn_sparkles(center, GREEN)


func _choose_mural_action(action_id: String) -> void:
	match action_id:
		"respirar":
			_start_breath()
		"baile":
			_sound_feedback()
			_dance_rhythm_on = false
			session.begin_guided_action("baile")
		"moverme":
			_start_movement()
		"pausa":
			_pause()


func _start_breath() -> void:
	_sound_feedback()
	_breath_phase = 0
	_breath_elapsed = 0.0
	session.begin_guided_action("respirar")


func _start_movement() -> void:
	_sound_feedback()
	_frog_mode = "saltar"
	session.begin_guided_action("moverme")


func _set_breath_pace(pace: int) -> void:
	_breath_pace = pace
	_breath_phase = 0
	_breath_elapsed = 0.0
	_sound_feedback()
	_render()


func _refresh_breath_ui() -> void:
	if not is_instance_valid(_breath_title) or not is_instance_valid(_breath_progress):
		return
	var durations: Array[int] = [4, 2, 4]
	if _breath_pace == 1:
		durations = [5, 3, 5]
	var phase_titles := ["Inhala profundo…", "Sostén un momento…", "Exhala suave…"]
	var phase_hints := ["Llena tu pancita de aire suave", "Guarda la calma un instante", "Suelta el aire como una brisa"]
	var progress := clampf(_breath_elapsed / float(durations[_breath_phase]), 0.0, 1.0)
	_breath_title.text = phase_titles[_breath_phase]
	_breath_hint.text = phase_hints[_breath_phase]
	_breath_countdown.text = "%d segundos" % max(1, ceili(float(durations[_breath_phase]) - _breath_elapsed))
	_breath_progress.value = progress * 100.0
	if is_instance_valid(_breath_picture):
		var scale_value := 0.9 + 0.3 * progress if _breath_phase == 0 else (1.2 if _breath_phase == 1 else 1.2 - 0.3 * progress)
		_breath_picture.scale = Vector2.ONE if reduced_motion else Vector2.ONE * scale_value


func _play_chime() -> void:
	if sound_enabled:
		_chime_player.play()


func _toggle_dance_rhythm() -> void:
	_dance_rhythm_on = not _dance_rhythm_on
	_dance_elapsed = 0.0
	if _dance_rhythm_on and sound_enabled:
		_beat_player.play()
	_render()


func _set_frog_mode(mode: String) -> void:
	_frog_mode = mode
	_sound_feedback()
	_render()


func _touch_frog() -> void:
	var center := _frog_pad.get_global_rect().get_center()
	if session.register_frog_action(_frog_mode):
		_sound_feedback()
		_spawn_sparkles(center, GREEN)
		if is_instance_valid(_frog_pad) and not reduced_motion:
			_frog_pad.pivot_offset = _frog_pad.size / 2.0
			var bounce := create_tween()
			bounce.tween_property(_frog_pad, "scale", Vector2(0.9, 0.9), 0.08)
			bounce.tween_property(_frog_pad, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_ELASTIC)


func _spawn_sparkles(center: Vector2, color: Color) -> void:
	if reduced_motion:
		return
	for index: int in 7:
		var sparkle := PanelContainer.new()
		sparkle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sparkle.add_theme_stylebox_override("panel", _style(color, color, 0))
		sparkle.size = Vector2(12, 12)
		sparkle.position = center - Vector2(6, 6)
		_screen_root.add_child(sparkle)
		var angle := TAU * float(index) / 7.0
		var destination := sparkle.position + Vector2(cos(angle), sin(angle)) * 78.0
		var tween := create_tween().set_parallel(true)
		tween.tween_property(sparkle, "position", destination, 0.45).set_trans(Tween.TRANS_SINE)
		tween.tween_property(sparkle, "modulate:a", 0.0, 0.45)
		tween.chain().tween_callback(sparkle.queue_free)


func _complete_guided_action() -> void:
	_sound_feedback()
	session.complete_guided_action()


func _show_routine() -> void:
	_sound_feedback()
	_toast = ""
	session.enter_routine()


func _show_communication() -> void:
	_sound_feedback()
	_toast = ""
	session.enter_communication()


func _back_home() -> void:
	_sound_feedback()
	_toast = ""
	session.return_home()


func _request_next_step() -> void:
	_sound_feedback()
	if session.request_next_step():
		if demo_enabled:
			if not session.advance_routine_demo():
				_toast = "Terminaste tu rutina"
				_render()
		else:
			_toast = "Avisé a tu terapeuta"
			_render()


func _choose_communication(option_id: String) -> void:
	_sound_feedback()
	if session.choose_communication(option_id):
		for option: Dictionary in session.communication_options:
			if option["id"] == option_id:
				_toast = "Dijiste: %s" % option["label"]
				break
		_render()


func _touch_shape(symbol: String) -> void:
	if symbol in _game_taps:
		return
	_game_taps.append(symbol)
	_sound_feedback()
	_render()


func _complete_activity() -> void:
	_sound_feedback()
	session.complete_activity()


func _pause() -> void:
	_sound_feedback()
	_toast = ""
	session.pause()


func _resume_demo() -> void:
	_sound_feedback()
	session.resume_from_therapist()


func _request_help() -> void:
	_sound_feedback()
	if demo_enabled:
		_toast = "Solicitud de prueba"
	session.request_help()
	_render()


func _toggle_sound() -> void:
	sound_enabled = not sound_enabled
	_render()


func _on_event_created(payload: Dictionary) -> void:
	if demo_enabled and client.server_url.is_empty():
		print("DEMO_EVENT ", JSON.stringify(payload))
		return
	client.queue_event(payload)
	if payload.get("action") == "help_requested":
		_help_event_id = str(payload.get("event_id", ""))
		_toast = "Aviso pendiente"
		_render()


func _on_event_acknowledged(event_id: String) -> void:
	if event_id == _help_event_id:
		_toast = "Avisé a tu terapeuta"
		_help_event_id = ""
		_render()


func _on_server_message(message: Dictionary) -> void:
	match str(message.get("event", "")):
		"START_SESSION":
			if session.start_session(message):
				sound_enabled = session.audio_enabled
				reduced_motion = session.reduced_motion
				_breath_pace = 1 if session.breath_pace == "slow" else 0
				_game_taps.clear()
				_toast = ""
				_breath_phase = 0
				_breath_elapsed = 0.0
		"PAUSE_SESSION":
			session.pause_from_therapist()
		"RESUME_SESSION":
			session.resume_from_therapist()
		"SET_STEP":
			session.set_routine_index_from_therapist(int(message.get("index", -1)))
		"SHOW_HOME":
			session.enter_mural()
		"END_SESSION":
			session.end_from_therapist()


func _sound_feedback() -> void:
	if sound_enabled:
		_feedback_player.play()


func _make_tone(frequency: float = 480.0, duration: float = 0.07) -> AudioStreamWAV:
	var sample_rate := 22050
	var sample_count := int(float(sample_rate) * duration)
	var audio := PackedByteArray()
	audio.resize(sample_count * 2)
	for index: int in sample_count:
		var envelope := 1.0 - float(index) / float(sample_count)
		var sample := int(sin(TAU * frequency * float(index) / float(sample_rate)) * envelope * 4500.0)
		audio.encode_s16(index * 2, sample)
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = sample_rate
	wave.stereo = false
	wave.data = audio
	return wave
