# ExplorationEvent.gd
# Base class for all exploration events
class_name ExplorationEvent
extends RefCounted

enum EventType { COMBAT, DIALOGUE, DISCOVERY, COMPOSITE }

signal event_started()
signal event_completed(success: bool, data: Dictionary)
signal event_failed(error: String)

var event_type: EventType
var event_id: String = ""  # Unique identifier for this event

# Override in subclasses
func execute(context: Dictionary) -> void:
	push_error("ExplorationEvent.execute() must be overridden")
	event_failed.emit("Not implemented")

# Load event from JSON file
static func load_from_file(file_path: String) -> ExplorationEvent:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("Cannot open event file: " + file_path)
		return null

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_string) != OK:
		push_error("Failed to parse event JSON: " + file_path)
		return null

	var data = json.data

	# Detect event type from path structure: res://data/events/[TYPE]/...
	var type_string = _extract_event_type_from_path(file_path)
	if type_string == "":
		push_error("Could not determine event type from path: " + file_path)
		return null

	match type_string:
		"combat":
			return CombatEvent.from_dict(data)
		"dialogue":
			return DialogueEvent.from_dict(data)
		"discovery":
			return DiscoveryEvent.from_dict(data)
		"composite":
			return CompositeEvent.from_dict(data)
		_:
			push_error("Unknown event type: " + type_string)
			return null

static func _extract_event_type_from_path(file_path: String) -> String:
	# Extract event type from path: res://data/events/[TYPE]/filename.json
	# Find the "events/" part and extract the next directory name
	var events_index = file_path.find("events/")
	if events_index == -1:
		return ""

	# Move past "events/"
	var start_index = events_index + 7  # len("events/")

	# Find the next "/" after the type directory
	var end_index = file_path.find("/", start_index)
	if end_index == -1:
		return ""

	# Extract the type directory name
	var type_string = file_path.substr(start_index, end_index - start_index)
	return type_string

func to_dict() -> Dictionary:
	return {
		"event_type": _event_type_to_string(event_type),
		"event_id": event_id
	}

static func _event_type_to_string(type: EventType) -> String:
	match type:
		EventType.COMBAT: return "combat"
		EventType.DIALOGUE: return "dialogue"
		EventType.DISCOVERY: return "discovery"
		EventType.COMPOSITE: return "composite"
	return "unknown"
