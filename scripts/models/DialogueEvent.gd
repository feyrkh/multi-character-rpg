# DialogueEvent.gd
# Shows dialogue using dialogue_manager
class_name DialogueEvent
extends ExplorationEvent

# Can be inline dialogue or reference to .dialogue file
var dialogue_mode: String = "inline"  # "inline" or "file"
var dialogue_text: String = ""  # For inline mode
var dialogue_file: String = ""  # For file mode (res://path/to/file.dialogue)
var dialogue_title: String = "start"  # Title/label to start at

# Visual customization
var left_portrait: String = ""  # res://path/to/portrait.png
var right_portrait: String = ""  # res://path/to/portrait.png
var background_image: String = ""  # res://path/to/background.png
var central_overlay: String = ""  # res://path/to/overlay.png

# Choice capture for branching
var capture_choice: bool = false  # Whether to capture player's dialogue choice
var choice_variable: String = ""  # Variable name for the choice (optional)

func _init() -> void:
	event_type = EventType.DIALOGUE

func execute(context: Dictionary) -> void:
	event_started.emit()

	# Pass dialogue data to context for GameView to handle
	var data = {
		"dialogue_mode": dialogue_mode,
		"dialogue_text": dialogue_text,
		"dialogue_file": dialogue_file,
		"dialogue_title": dialogue_title,
		"left_portrait": left_portrait,
		"right_portrait": right_portrait,
		"background_image": background_image,
		"central_overlay": central_overlay,
		"capture_choice": capture_choice,
		"choice_variable": choice_variable
	}

	event_completed.emit(true, data)

static func from_dict(data: Dictionary) -> DialogueEvent:
	var event = DialogueEvent.new()
	event.event_id = data.get("event_id", "")

	if data.has("dialogue_text"):
		event.dialogue_mode = "inline"
		event.dialogue_text = data.get("dialogue_text", "")
	elif data.has("dialogue_file"):
		event.dialogue_mode = "file"
		event.dialogue_file = data.get("dialogue_file", "")
		event.dialogue_title = data.get("dialogue_title", "start")

	event.left_portrait = data.get("left_portrait", "")
	event.right_portrait = data.get("right_portrait", "")
	event.background_image = data.get("background_image", "")
	event.central_overlay = data.get("central_overlay", "")

	event.capture_choice = data.get("capture_choice", false)
	event.choice_variable = data.get("choice_variable", "")

	return event

func to_dict() -> Dictionary:
	var base = super.to_dict()
	base["dialogue_mode"] = dialogue_mode
	if dialogue_mode == "inline":
		base["dialogue_text"] = dialogue_text
	else:
		base["dialogue_file"] = dialogue_file
		base["dialogue_title"] = dialogue_title

	if left_portrait != "":
		base["left_portrait"] = left_portrait
	if right_portrait != "":
		base["right_portrait"] = right_portrait
	if background_image != "":
		base["background_image"] = background_image
	if central_overlay != "":
		base["central_overlay"] = central_overlay

	if capture_choice:
		base["capture_choice"] = capture_choice
	if choice_variable != "":
		base["choice_variable"] = choice_variable

	return base
