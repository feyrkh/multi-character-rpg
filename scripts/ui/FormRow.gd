# FormRow.gd
# A single row in the combat forms list, showing form name and action preview
extends PanelContainer

signal edit_requested()
signal delete_requested()
signal reorder_requested(from_index: int, to_index: int)

@onready var drag_handle: Label = $MarginContainer/HBoxContainer/DragHandle
@onready var form_name_label: Label = $MarginContainer/HBoxContainer/FormNameLabel
@onready var actions_preview: HBoxContainer = $MarginContainer/HBoxContainer/ActionsPreview
@onready var edit_button: Button = $MarginContainer/HBoxContainer/EditButton
@onready var delete_button: Button = $MarginContainer/HBoxContainer/DeleteButton

var _form: CombatForm = null
var _index: int = 0

func _ready() -> void:
	edit_button.pressed.connect(func(): edit_requested.emit())
	delete_button.pressed.connect(func(): delete_requested.emit())

func setup(form: CombatForm, index: int) -> void:
	_form = form
	_index = index
	form_name_label.text = form.form_name
	_populate_preview()

func _populate_preview() -> void:
	# Clear existing preview
	for child in actions_preview.get_children():
		child.queue_free()

	if _form == null:
		return

	for i in range(_form.actions.size()):
		var action = _form.actions[i]

		# Action name label
		var label = Label.new()
		label.text = action.get_action_name()
		label.add_theme_font_size_override("font_size", 12)
		actions_preview.add_child(label)

		# Add arrow separator between actions
		if i < _form.actions.size() - 1:
			var arrow = Label.new()
			arrow.text = " -> "
			arrow.add_theme_font_size_override("font_size", 12)
			arrow.modulate = Color(0.6, 0.6, 0.6)
			actions_preview.add_child(arrow)

	# If no actions, show placeholder
	if _form.actions.is_empty():
		var placeholder = Label.new()
		placeholder.text = "(no actions)"
		placeholder.add_theme_font_size_override("font_size", 12)
		placeholder.modulate = Color(0.5, 0.5, 0.5)
		actions_preview.add_child(placeholder)

# --- Drag and drop for reordering ---

func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview = Label.new()
	preview.text = _form.form_name if _form else "Form"
	preview.add_theme_font_size_override("font_size", 14)
	set_drag_preview(preview)
	return {"type": "form_row", "index": _index}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	if data.get("type") != "form_row":
		return false
	return data.get("index") != _index

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Dictionary and data.get("type") == "form_row":
		reorder_requested.emit(data.get("index"), _index)
