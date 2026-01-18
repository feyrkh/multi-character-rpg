# DiscoveryEvent.gd
# Unlocks one or more locations
class_name DiscoveryEvent
extends ExplorationEvent

var location_ids: Array[String] = []  # Location IDs to discover
var show_message: bool = true  # Show discovery message
var message_text: String = ""  # Custom message (optional)

func _init() -> void:
	event_type = EventType.DISCOVERY

func execute(context: Dictionary) -> void:
	event_started.emit()

	var discovered = []
	for loc_id in location_ids:
		if LocationMgr.discover_location(loc_id):
			discovered.append(loc_id)

	context["discovered_locations"] = discovered
	context["show_message"] = show_message
	context["message_text"] = message_text

	event_completed.emit(true, context)

static func from_dict(data: Dictionary) -> DiscoveryEvent:
	var event = DiscoveryEvent.new()
	event.event_id = data.get("event_id", "")

	var locations = data.get("locations", [])
	for loc_id in locations:
		event.location_ids.append(loc_id)

	event.show_message = data.get("show_message", true)
	event.message_text = data.get("message_text", "")

	return event

func to_dict() -> Dictionary:
	var base = super.to_dict()
	base["locations"] = location_ids
	base["show_message"] = show_message
	if message_text != "":
		base["message_text"] = message_text
	return base
