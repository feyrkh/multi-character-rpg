# ActionSequenceEditor.gd
# Modal editor for a single combat form's action sequence
extends Control

signal editor_closed(saved: bool)

const ActionSlotScene = preload("res://scenes/ui/combat_forms/action_slot.tscn")
const KnownActionItemScene = preload("res://scenes/ui/combat_forms/known_action_item.tscn")

@onready var form_name_edit: LineEdit = $CenterContainer/Panel/VBoxContainer/ContentMargin/VBoxContainer/HeaderRow/FormNameEdit
@onready var slots_container: HBoxContainer = $CenterContainer/Panel/VBoxContainer/ContentMargin/VBoxContainer/SlotsSection/SlotsContainer
@onready var available_grid: GridContainer = $CenterContainer/Panel/VBoxContainer/ContentMargin/VBoxContainer/AvailableScroll/AvailableGrid
@onready var save_button: Button = $CenterContainer/Panel/VBoxContainer/ButtonBar/HBoxContainer/SaveButton
@onready var cancel_button: Button = $CenterContainer/Panel/VBoxContainer/ButtonBar/HBoxContainer/CancelButton
@onready var close_button: Button = $CenterContainer/Panel/VBoxContainer/ContentMargin/VBoxContainer/HeaderRow/CloseButton
@onready var unsaved_dialog: ConfirmationDialog = $UnsavedDialog

var _character: PlayableCharacter = null
var _form_index: int = -1
var _original_form: CombatForm = null
var _working_actions: Array = []  # Current slot contents (CombatAction or null)
var _has_changes: bool = false
var _original_name: String = ""

func _ready() -> void:
	save_button.pressed.connect(_on_save_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	close_button.pressed.connect(_on_cancel_pressed)
	form_name_edit.text_changed.connect(_on_name_changed)
	unsaved_dialog.confirmed.connect(_on_unsaved_save)
	unsaved_dialog.canceled.connect(_on_unsaved_discard)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_prompt_save_if_needed()
		get_viewport().set_input_as_handled()

func setup(character: PlayableCharacter, form_index: int) -> void:
	_character = character
	_form_index = form_index
	_original_form = character.combat_forms[form_index]
	_original_name = _original_form.form_name

	# Copy actions for editing
	_working_actions.clear()
	for i in range(character.max_action_sequence_length):
		if i < _original_form.actions.size():
			_working_actions.append(_original_form.actions[i])
		else:
			_working_actions.append(null)

	form_name_edit.text = _original_form.form_name
	_has_changes = false

	_create_slots()
	_populate_available_actions()
	_update_slot_displays()

func _create_slots() -> void:
	# Clear existing slots
	for child in slots_container.get_children():
		child.queue_free()

	var max_slots = _character.max_action_sequence_length
	for i in range(max_slots):
		var slot = ActionSlotScene.instantiate()
		slots_container.add_child(slot)
		slot.setup(i)
		slot.action_dropped.connect(_on_action_dropped.bind(i))
		slot.slot_cleared.connect(_on_slot_cleared.bind(i))

func _populate_available_actions() -> void:
	# Clear existing items
	for child in available_grid.get_children():
		child.queue_free()

	# Add items for each known action the character has
	for known_action in _character.known_actions:
		var item = KnownActionItemScene.instantiate()
		available_grid.add_child(item)
		item.setup(known_action)

func _update_slot_displays() -> void:
	var slots = slots_container.get_children()
	for i in range(slots.size()):
		if i < _working_actions.size() and _working_actions[i] != null:
			slots[i].set_action(_working_actions[i])
		else:
			slots[i].clear_action()

func _on_action_dropped(known_action: KnownCombatAction, slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _working_actions.size():
		return

	var combat_action = known_action.to_combat_action()
	_working_actions[slot_index] = combat_action
	_has_changes = true
	_update_slot_displays()

func _on_slot_cleared(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _working_actions.size():
		return

	_working_actions[slot_index] = null
	_has_changes = true
	_update_slot_displays()

func _on_name_changed(_new_text: String) -> void:
	_has_changes = true

func _on_save_pressed() -> void:
	_save_form()
	editor_closed.emit(true)

func _on_cancel_pressed() -> void:
	_prompt_save_if_needed()

func _prompt_save_if_needed() -> void:
	if _has_changes:
		unsaved_dialog.popup_centered()
	else:
		editor_closed.emit(false)

func _on_unsaved_save() -> void:
	_save_form()
	editor_closed.emit(true)

func _on_unsaved_discard() -> void:
	editor_closed.emit(false)

func _save_form() -> void:
	_original_form.form_name = form_name_edit.text
	_original_form.actions.clear()

	# Only add non-null actions
	for action in _working_actions:
		if action != null:
			_original_form.actions.append(action)
