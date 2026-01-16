# CombatFormsView.gd
# Main screen for viewing and editing combat forms for party members
extends Control

signal forms_updated(character: PlayableCharacter)

const FormRowScene = preload("res://scenes/ui/combat_forms/form_row.tscn")
const ActionSequenceEditorScene = preload("res://scenes/ui/combat_forms/action_sequence_editor.tscn")

@onready var character_selector: OptionButton = $CenterContainer/Panel/MarginContainer/VBoxContainer/HeaderRow/CharacterSelector
@onready var forms_container: VBoxContainer = $CenterContainer/Panel/MarginContainer/VBoxContainer/FormsList/FormsContainer
@onready var close_button: Button = $CenterContainer/Panel/MarginContainer/VBoxContainer/HeaderRow/CloseButton
@onready var add_form_button: Button = $CenterContainer/Panel/MarginContainer/VBoxContainer/BottomRow/AddFormButton
@onready var delete_confirm_dialog: ConfirmationDialog = $DeleteConfirmDialog

var _characters: Array[PlayableCharacter] = []
var _current_character: PlayableCharacter = null
var _editor_instance: Control = null
var _pending_delete_index: int = -1

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	add_form_button.pressed.connect(_on_add_form_pressed)
	character_selector.item_selected.connect(_on_character_selected)
	delete_confirm_dialog.confirmed.connect(_on_delete_confirmed)
	hide()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _editor_instance != null and _editor_instance.visible:
		return  # Let the editor handle input
	if event.is_action_pressed("ui_cancel"):
		_save_and_close()
		get_viewport().set_input_as_handled()

func open(party: Party) -> void:
	_characters.clear()
	var members = GameManager.get_party_members(party)
	for member in members:
		_characters.append(member)

	_populate_character_selector()
	if _characters.size() > 0:
		character_selector.select(0)
		_select_character(_characters[0])
	show()

func _populate_character_selector() -> void:
	character_selector.clear()
	for i in range(_characters.size()):
		character_selector.add_item(_characters[i].char_name, i)

func _on_character_selected(index: int) -> void:
	if index >= 0 and index < _characters.size():
		_select_character(_characters[index])

func _select_character(character: PlayableCharacter) -> void:
	_current_character = character
	_refresh_forms_list()

func _refresh_forms_list() -> void:
	# Clear existing rows
	for child in forms_container.get_children():
		child.queue_free()

	if _current_character == null:
		return

	# Create rows for each form
	for i in range(_current_character.combat_forms.size()):
		var form = _current_character.combat_forms[i]
		var row = FormRowScene.instantiate()
		forms_container.add_child(row)
		row.setup(form, i)
		row.edit_requested.connect(_on_edit_form.bind(i))
		row.delete_requested.connect(_on_delete_form.bind(i))
		row.reorder_requested.connect(_on_reorder_form)

func _on_add_form_pressed() -> void:
	if _current_character == null:
		return
	var new_form = CombatForm.new("New Form")
	_current_character.combat_forms.append(new_form)
	_refresh_forms_list()
	# Open editor for the new form
	_open_editor(_current_character.combat_forms.size() - 1)

func _on_edit_form(form_index: int) -> void:
	_open_editor(form_index)

func _on_delete_form(form_index: int) -> void:
	if _current_character == null:
		return
	if form_index >= 0 and form_index < _current_character.combat_forms.size():
		_pending_delete_index = form_index
		var form_name = _current_character.combat_forms[form_index].form_name
		delete_confirm_dialog.dialog_text = "Delete combat form \"%s\"?" % form_name
		delete_confirm_dialog.popup_centered()

func _on_delete_confirmed() -> void:
	if _current_character == null or _pending_delete_index < 0:
		return
	if _pending_delete_index < _current_character.combat_forms.size():
		_current_character.combat_forms.remove_at(_pending_delete_index)
		_refresh_forms_list()
	_pending_delete_index = -1

func _on_reorder_form(from_index: int, to_index: int) -> void:
	if _current_character == null:
		return
	if from_index < 0 or from_index >= _current_character.combat_forms.size():
		return
	if to_index < 0 or to_index >= _current_character.combat_forms.size():
		return

	var form = _current_character.combat_forms[from_index]
	_current_character.combat_forms.remove_at(from_index)
	_current_character.combat_forms.insert(to_index, form)
	_refresh_forms_list()

func _open_editor(form_index: int) -> void:
	if _editor_instance != null:
		_editor_instance.queue_free()

	_editor_instance = ActionSequenceEditorScene.instantiate()
	add_child(_editor_instance)
	_editor_instance.setup(_current_character, form_index)
	_editor_instance.editor_closed.connect(_on_editor_closed)

func _on_editor_closed(saved: bool) -> void:
	if saved:
		_refresh_forms_list()
	if _editor_instance:
		_editor_instance.queue_free()
		_editor_instance = null

func _on_close_pressed() -> void:
	_save_and_close()

func _save_and_close() -> void:
	# Forms are already stored in character, just emit signal and close
	if _current_character:
		forms_updated.emit(_current_character)
	hide()
