# CombatEvent.gd
# Triggers combat with one or more enemies
class_name CombatEvent
extends ExplorationEvent

var enemy_paths: Array[String] = []  # Paths to enemy JSON files

func _init() -> void:
	event_type = EventType.COMBAT

func execute(context: Dictionary) -> void:
	event_started.emit()

	# Load enemies
	var enemies = []
	for path in enemy_paths:
		var enemy = Enemy.load_from_file(path)
		if enemy == null:
			event_failed.emit("Failed to load enemy: " + path)
			return
		enemies.append(enemy)

	# Store enemies in context for GameView to use
	context["enemies"] = enemies
	event_completed.emit(true, {"enemies": enemies})

static func from_dict(data: Dictionary) -> CombatEvent:
	var event = CombatEvent.new()
	event.event_id = data.get("event_id", "")

	var enemies = data.get("enemies", [])
	for enemy_path in enemies:
		event.enemy_paths.append(enemy_path)

	return event

func to_dict() -> Dictionary:
	var base = super.to_dict()
	base["enemies"] = enemy_paths
	return base
