# EventDialogueBalloon.gd
# Custom dialogue balloon with portrait and background support
class_name EventDialogueBalloon
extends DialogueManagerExampleBalloon

@onready var background_image: TextureRect = %BackgroundImage
@onready var left_portrait: TextureRect = %LeftPortrait
@onready var right_portrait: TextureRect = %RightPortrait
@onready var central_overlay: TextureRect = %CentralOverlay

var current_left_portrait: String = ""
var current_right_portrait: String = ""
var current_background: String = ""
var current_overlay: String = ""

# Choice capture for branching
var _capture_choice: bool = false
var _choice_variable: String = ""
var _selected_response: DialogueResponse = null

signal choice_captured(choice_id: String, choice_text: String, choice_variable: String)

func setup_visuals(left: String, right: String, background: String, overlay: String) -> void:
	"""Setup portraits, background, and overlay images"""
	current_left_portrait = left
	current_right_portrait = right
	current_background = background
	current_overlay = overlay

	# Ensure the node is ready before accessing @onready variables
	if not is_node_ready():
		await ready

	_update_image(background_image, background)
	_update_image(left_portrait, left)
	_update_image(right_portrait, right)
	_update_image(central_overlay, overlay)

func _update_image(container: TextureRect, path: String) -> void:
	"""Load texture and show/hide container"""
	if container == null:
		return

	if path == "" or not FileAccess.file_exists(path):
		container.hide()
		return

	var texture = load(path)
	if texture:
		container.texture = texture
		container.show()
	else:
		push_warning("Failed to load image: " + path)
		container.hide()

func enable_choice_capture(variable_name: String = "") -> void:
	"""Enable capturing the player's dialogue choice"""
	_capture_choice = true
	_choice_variable = variable_name

func get_selected_choice() -> Dictionary:
	"""Get the selected dialogue choice data"""
	if _selected_response == null:
		return {}
	return {
		"choice_id": _selected_response.id,
		"choice_text": _selected_response.text,
		"next_id": _selected_response.next_id
	}

func _on_responses_menu_response_selected(response: DialogueResponse) -> void:
	"""Override to capture dialogue choices for branching"""
	# Capture the response if enabled
	if _capture_choice:
		_selected_response = response
		choice_captured.emit(response.id, response.text, _choice_variable)

	# Call parent implementation to continue dialogue
	super._on_responses_menu_response_selected(response)
