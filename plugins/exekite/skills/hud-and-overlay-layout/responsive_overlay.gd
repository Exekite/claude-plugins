extends CanvasLayer
## Authored UI example, not a platform autoload. Adapt its actions and content.
signal action_requested(action: String)

var ui_root := Control.new()
var _screen := "title"
var _muted := false
var _content: Control
var _rebuild_pending := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ui_root.name = "ResponsiveRoot"
	ui_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ui_theme := Theme.new()
	ui_theme.default_font_size = 16
	ui_root.theme = ui_theme
	add_child(ui_root)
	get_viewport().size_changed.connect(_layout)
	_layout()

func _screen_pixel_ratio() -> float:
	return maxf(1.0, DisplayServer.screen_get_scale())

func _layout() -> void:
	var stretch := get_viewport().get_screen_transform().get_scale().abs()
	var css_scale := minf(stretch.x, stretch.y) / _screen_pixel_ratio()
	var ui_scale := maxf(1.0, 1.0 / maxf(0.001, css_scale))
	ui_root.scale = Vector2.ONE * ui_scale
	ui_root.size = get_viewport().get_visible_rect().size / ui_scale
	_queue_rebuild()

func show_screen(screen: String, muted: bool = false) -> void:
	_screen = screen
	_muted = muted
	_queue_rebuild()

func _label(text: String, font_size: int = 16) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#f5f1e8"))
	return label

func _button(text: String, action: String) -> Button:
	var button := Button.new()
	button.name = "Button_" + action
	button.text = text
	button.custom_minimum_size = Vector2(72, 44)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_color_override("font_color", Color("#151522"))
	button.add_theme_color_override("font_hover_color", Color("#151522"))
	button.add_theme_color_override("font_pressed_color", Color("#151522"))
	button.add_theme_color_override("font_focus_color", Color("#151522"))
	button.add_theme_color_override("font_hover_pressed_color", Color("#151522"))
	for state in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#f9c846") if state == "normal" else Color("#ffe09a")
		style.set_corner_radius_all(8)
		style.content_margin_left = 12
		style.content_margin_right = 12
		button.add_theme_stylebox_override(state, style)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color.WHITE
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(8)
	button.add_theme_stylebox_override("focus", focus)
	button.pressed.connect(func() -> void: action_requested.emit(action))
	return button

func _queue_rebuild() -> void:
	if _rebuild_pending:
		return
	_rebuild_pending = true
	_rebuild.call_deferred()

func _rebuild() -> void:
	_rebuild_pending = false
	if not is_instance_valid(ui_root) or not ui_root.is_inside_tree():
		return
	var focus_name := ""
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and ui_root.is_ancestor_of(focused):
		focus_name = str(focused.name)
		focused.release_focus()
	if is_instance_valid(_content):
		ui_root.remove_child(_content)
		_content.queue_free()
	if _screen == "hud":
		var row := HBoxContainer.new()
		_content = row
		row.name = "Hud"
		row.set_anchors_preset(Control.PRESET_TOP_WIDE)
		row.offset_left = 12
		row.offset_top = 8
		row.offset_right = -12
		row.offset_bottom = 52
		row.add_theme_constant_override("separation", 8)
		ui_root.add_child(row)
		var counters := _label("HP 3  0/6")
		counters.name = "Counters"
		counters.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(counters)
		for action in ["pause", "mute"]:
			var text := "Pause" if action == "pause" else ("Unmute" if _muted else "Mute")
			var button := _button(text, action)
			button.focus_mode = Control.FOCUS_NONE
			row.add_child(button)
		return

	var center := CenterContainer.new()
	_content = center
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size.x = minf(520.0, ui_root.size.x - 24.0)
	var background := StyleBoxFlat.new()
	background.bg_color = Color("#17152d")
	background.set_corner_radius_all(12)
	card.add_theme_stylebox_override("panel", background)
	center.add_child(card)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	card.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	if _screen == "pause":
		column.add_child(_label("Paused", 24))
		column.add_child(_button("Resume", "resume"))
		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation", 8)
		column.add_child(actions)
		actions.add_child(_button("Unmute" if _muted else "Mute", "mute"))
		actions.add_child(_button("Retry", "retry"))
	else:
		var title := "Lantern Orchard" if _screen == "title" else ("Orchard awakened" if _screen == "win" else "Out of hearts")
		column.add_child(_label(title, 24))
		var goal := _label("Collect 6 seeds; return to the shrine." if _screen == "title" else "Try another round.")
		goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(goal)
		column.add_child(_button("Start" if _screen == "title" else "Retry", "start" if _screen == "title" else "retry"))
	_restore_focus.call_deferred(focus_name)

func _restore_focus(previous: String) -> void:
	if _screen == "hud":
		return
	var target := ui_root.find_child(previous, true, false) if previous != "" else null
	if target == null:
		var primary := "start" if _screen == "title" else ("resume" if _screen == "pause" else "retry")
		target = ui_root.find_child("Button_" + primary, true, false)
	if target is Button:
		target.grab_focus()

## Call after containers settle; native geometry cannot prove rendered contrast.
func physical_rect(control: Control) -> Rect2:
	var transform := get_viewport().get_screen_transform() * control.get_global_transform_with_canvas()
	var rect := transform * Rect2(Vector2.ZERO, control.size)
	return Rect2(rect.position / _screen_pixel_ratio(), rect.size / _screen_pixel_ratio())
