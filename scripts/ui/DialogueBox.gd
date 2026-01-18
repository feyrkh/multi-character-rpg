# DialogueBox.gd
# RPG-style dialogue display with click-to-continue and auto-advance modes
extends Control

signal dialogue_finished()

@onready var background_image: TextureRect = $BackgroundImage
@onready var left_portrait: TextureRect = $Portraits/LeftPortrait
@onready var right_portrait: TextureRect = $Portraits/RightPortrait
@onready var central_overlay: TextureRect = $CentralOverlay
@onready var dialogue_panel: Panel = $DialoguePanel
@onready var character_name_label: Label = $DialoguePanel/VBoxContainer/CharacterName
@onready var dialogue_text_label: Label = $DialoguePanel/VBoxContainer/DialogueText
@onready var continue_indicator: Label = $DialoguePanel/VBoxContainer/ContinueIndicator
@onready var auto_toggle_button: Button = $DialoguePanel/VBoxContainer/HBoxContainer/AutoToggleButton
@onready var close_button: Button = $DialoguePanel/VBoxContainer/HBoxContainer/CloseButton

var dialogue_lines: Array = []
var current_line_index: int = 0
var auto_advance_enabled: bool = false
var auto_advance_delay: float = 2.0  # seconds
var auto_advance_timer: float = 0.0

func _ready() -> void:
	auto_toggle_button.pressed.connect(_on_auto_toggle_pressed)
	close_button.pressed.connect(_on_close_pressed)
	continue_indicator.text = "▼ Click to continue"

	# Make the dialogue panel clickable
	dialogue_panel.gui_input.connect(_on_dialogue_panel_input)

	# Hide continue indicator initially
	continue_indicator.hide()
	close_button.hide()

func _process(delta: float) -> void:
	if auto_advance_enabled and current_line_index < dialogue_lines.size():
		auto_advance_timer += delta
		if auto_advance_timer >= auto_advance_delay:
			_advance_dialogue()

func setup_visuals(left_port: String, right_port: String, background: String, overlay: String) -> void:
	"""Setup visual elements (portraits, backgrounds, overlays)"""
	_load_image(left_portrait, left_port)
	_load_image(right_portrait, right_port)
	_load_image(background_image, background)
	_load_image(central_overlay, overlay)

func _load_image(texture_rect: TextureRect, path: String) -> void:
	"""Load an image from path and set it to a TextureRect"""
	if path.is_empty() or not FileAccess.file_exists(path):
		texture_rect.hide()
		return

	var texture = load(path)
	if texture:
		texture_rect.texture = texture
		texture_rect.show()
	else:
		texture_rect.hide()

func start_dialogue(lines: Array) -> void:
	"""Start displaying dialogue lines"""
	dialogue_lines = lines
	current_line_index = 0
	auto_advance_timer = 0.0

	if dialogue_lines.is_empty():
		push_error("No dialogue lines provided")
		dialogue_finished.emit()
		return

	_show_current_line()

func _show_current_line() -> void:
	"""Display the current dialogue line"""
	if current_line_index >= dialogue_lines.size():
		_finish_dialogue()
		return

	var line = dialogue_lines[current_line_index]
	var character = line.get("character", "")
	var text = line.get("text", "")

	character_name_label.text = character
	dialogue_text_label.text = text

	# Show continue indicator if not on last line
	if current_line_index < dialogue_lines.size() - 1:
		continue_indicator.show()
		close_button.hide()
	else:
		continue_indicator.hide()
		close_button.show()

	auto_advance_timer = 0.0

func _advance_dialogue() -> void:
	"""Advance to next dialogue line"""
	current_line_index += 1
	_show_current_line()

func _finish_dialogue() -> void:
	"""End the dialogue sequence"""
	dialogue_finished.emit()
	queue_free()

func _on_dialogue_panel_input(event: InputEvent) -> void:
	"""Handle clicks on the dialogue panel"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if current_line_index < dialogue_lines.size() - 1:
			_advance_dialogue()

func _on_auto_toggle_pressed() -> void:
	"""Toggle auto-advance mode"""
	auto_advance_enabled = !auto_advance_enabled
	if auto_advance_enabled:
		auto_toggle_button.text = "Auto: ON"
		continue_indicator.text = "▼ Auto-advancing..."
	else:
		auto_toggle_button.text = "Auto: OFF"
		continue_indicator.text = "▼ Click to continue"
	auto_advance_timer = 0.0

func _on_close_pressed() -> void:
	"""Close the dialogue box"""
	_finish_dialogue()

func _input(event: InputEvent) -> void:
	"""Handle keyboard input for advancing dialogue"""
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select"):
		if current_line_index < dialogue_lines.size() - 1:
			_advance_dialogue()
			get_viewport().set_input_as_handled()
		else:
			_finish_dialogue()
			get_viewport().set_input_as_handled()
