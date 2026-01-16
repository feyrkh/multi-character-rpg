# KnownActionItem.gd
# A draggable item representing a known action in the available actions list
extends PanelContainer

@onready var icon_rect: TextureRect = $VBoxContainer/IconRect
@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var power_label: Label = $VBoxContainer/PowerLabel

var _known_action: KnownCombatAction = null

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func setup(known_action: KnownCombatAction) -> void:
	_known_action = known_action
	name_label.text = known_action.get_display_name()
	power_label.text = "Pow: %d" % known_action.get_effective_power()

	var icon_path = known_action.get_icon_path()
	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon_rect.texture = load(icon_path)
	else:
		icon_rect.texture = null

func _get_drag_data(_at_position: Vector2) -> Variant:
	if _known_action == null:
		return null

	# Create a visual preview for dragging
	var preview = PanelContainer.new()
	preview.custom_minimum_size = Vector2(80, 60)
	preview.modulate = Color(1, 1, 1, 0.8)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	preview.add_child(vbox)

	var label = Label.new()
	label.text = _known_action.get_display_name()
	label.add_theme_font_size_override("font_size", 12)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)

	set_drag_preview(preview)
	return _known_action

func get_known_action() -> KnownCombatAction:
	return _known_action
