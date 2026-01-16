# ActionSlot.gd
# A slot in the action sequence that can receive dropped actions
extends PanelContainer

signal action_dropped(known_action: KnownCombatAction)
signal slot_cleared()

@onready var icon_rect: TextureRect = $VBoxContainer/IconRect
@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var power_label: Label = $VBoxContainer/PowerLabel
@onready var slot_number: Label = $SlotNumber

var _slot_index: int = 0
var _current_action: CombatAction = null

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func setup(index: int) -> void:
	_slot_index = index
	slot_number.text = str(index + 1)
	clear_action()

func set_action(action: CombatAction) -> void:
	_current_action = action
	if action:
		name_label.text = action.get_action_name()
		power_label.text = "Power: %d" % action.power
		power_label.show()
		if action.icon_path != "" and ResourceLoader.exists(action.icon_path):
			icon_rect.texture = load(action.icon_path)
		else:
			icon_rect.texture = null
		_update_visual_state(true)
	else:
		clear_action()

func clear_action() -> void:
	_current_action = null
	name_label.text = "Empty"
	power_label.text = ""
	power_label.hide()
	icon_rect.texture = null
	_update_visual_state(false)

func _update_visual_state(filled: bool) -> void:
	if filled:
		modulate = Color.WHITE
	else:
		modulate = Color(0.7, 0.7, 0.7)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is KnownCombatAction

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is KnownCombatAction:
		action_dropped.emit(data)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if _current_action:
				slot_cleared.emit()
				accept_event()

func get_action() -> CombatAction:
	return _current_action
