# StatusEffectMgr.gd
# Manager for loading and creating status effects dynamically
# Autoload singleton that loads effects from data files and behavior scripts
extends Node

const EFFECT_DATA_PATH = "res://data/status_effects/"
const EFFECT_BEHAVIORS_PATH = "res://scripts/effects/"

# Cache of loaded effect definitions
var _effect_definitions: Dictionary = {}  # effect_id -> Dictionary (JSON data)
var _behavior_scripts: Dictionary = {}    # effect_id -> Script (GDScript class)

func _ready() -> void:
	_load_all_effects()

# Load all effect definitions and behavior scripts
func _load_all_effects() -> void:
	print("[StatusEffectMgr] Loading status effects...")

	# Load effect data files (JSON)
	_load_effect_data()

	# Load behavior scripts (GDScript)
	_load_behavior_scripts()

	print("[StatusEffectMgr] Loaded ", _effect_definitions.size(), " effect definitions")
	print("[StatusEffectMgr] Loaded ", _behavior_scripts.size(), " behavior scripts")

# Load effect data from JSON files
func _load_effect_data() -> void:
	var dir = DirAccess.open(EFFECT_DATA_PATH)
	if not dir:
		print("[StatusEffectMgr] Effect data directory not found: ", EFFECT_DATA_PATH)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var effect_id = file_name.get_basename()
			var file_path = EFFECT_DATA_PATH + file_name

			var file = FileAccess.open(file_path, FileAccess.READ)
			if file:
				var json_string = file.get_as_text()
				file.close()

				var json = JSON.new()
				var error = json.parse(json_string)
				if error == OK:
					var data = json.data
					data["__id__"] = effect_id
					_effect_definitions[effect_id] = data
					print("  Loaded effect data: ", effect_id)
				else:
					push_error("Failed to parse JSON for effect: " + file_path)

		file_name = dir.get_next()

	dir.list_dir_end()

# Load behavior scripts from GDScript files
func _load_behavior_scripts() -> void:
	var dir = DirAccess.open(EFFECT_BEHAVIORS_PATH)
	if not dir:
		print("[StatusEffectMgr] Behavior scripts directory not found: ", EFFECT_BEHAVIORS_PATH)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".gd"):
			# Check if it's an effect behavior (not EffectBehavior.gd itself)
			if file_name != "EffectBehavior.gd":
				var effect_id = file_name.get_basename()
				var file_path = EFFECT_BEHAVIORS_PATH + file_name

				var script = load(file_path)
				if script:
					_behavior_scripts[effect_id] = script
					print("  Loaded behavior script: ", effect_id)
				else:
					push_error("Failed to load behavior script: " + file_path)

		file_name = dir.get_next()

	dir.list_dir_end()

# Create a status effect by ID
func create_effect(effect_id: String, params: Dictionary = {}):
	# Check if we have a definition for this effect
	var definition = _effect_definitions.get(effect_id)

	# Fallback to factory for built-in effects
	if not definition:
		return _create_builtin_effect(effect_id, params)

	# Create effect from definition
	var effect = StatusEffect.new(effect_id, definition.get("name", effect_id))

	# Load properties from definition
	effect.description = definition.get("description", "")
	effect.effect_type = definition.get("effect_type", StatusEffect.EffectType.DEFENSE)
	effect.defense_type = definition.get("defense_type", StatusEffect.DefenseType.PERCENT_REDUCTION_STACKING)
	effect.heal_type = definition.get("heal_type", StatusEffect.HealType.FIXED_AMOUNT)
	effect.damage_type = definition.get("damage_type", StatusEffect.DamageType.FIXED_AMOUNT)
	effect.strength = definition.get("strength", 0.0)
	effect.stacks = definition.get("stacks", 1)
	effect.max_stacks = definition.get("max_stacks", 99)
	effect.decay_type = definition.get("decay_type", StatusEffect.DecayType.NONE)
	effect.duration_rounds = definition.get("duration_rounds", -1)
	effect.cleansable = definition.get("cleansable", true)

	# Parse trigger events
	var triggers = definition.get("triggers", [])
	for trigger_name in triggers:
		var trigger_value = _parse_trigger_event(trigger_name)
		if trigger_value != null:
			effect.trigger_events.append(trigger_value)

	# Apply parameter overrides
	if params.has("strength"):
		effect.strength = params.strength
	if params.has("duration"):
		effect.duration_rounds = params.duration
	if params.has("stacks"):
		effect.stacks = params.stacks

	# Attach custom behavior script if available
	if _behavior_scripts.has(effect_id):
		var behavior_script = _behavior_scripts[effect_id]
		var behavior = behavior_script.new()
		behavior.effect_data = effect
		effect.set_meta("behavior", behavior)

	return effect

# Parse trigger event name to enum value
func _parse_trigger_event(trigger_name: String):
	match trigger_name.to_upper():
		"ROUND_START":
			return StatusEffect.TriggerEvent.ROUND_START
		"ROUND_END":
			return StatusEffect.TriggerEvent.ROUND_END
		"BEFORE_MOVE":
			return StatusEffect.TriggerEvent.BEFORE_MOVE
		"AFTER_MOVE":
			return StatusEffect.TriggerEvent.AFTER_MOVE
		"WHEN_ATTACKED":
			return StatusEffect.TriggerEvent.WHEN_ATTACKED
		"WHEN_ATTACKING":
			return StatusEffect.TriggerEvent.WHEN_ATTACKING
		"CONTINUOUS":
			return StatusEffect.TriggerEvent.CONTINUOUS

	push_error("Unknown trigger event: " + trigger_name)
	return StatusEffect.TriggerEvent.CONTINUOUS

# Create built-in effects using factory (backward compatibility)
func _create_builtin_effect(effect_id: String, params: Dictionary):
	match effect_id:
		"fighter_defense":
			return StatusEffectFactory.create_fighter_defense()
		"cleric_defense":
			return StatusEffectFactory.create_cleric_defense()
		"regeneration":
			var amount = params.get("amount", 5)
			return StatusEffectFactory.create_regeneration(amount)
		"poison":
			var amount = params.get("amount", 3)
			return StatusEffectFactory.create_poison(amount)
		"shield":
			var amount = params.get("amount", 100)
			return StatusEffectFactory.create_shield(amount)
		"burn":
			var amount = params.get("amount", 5)
			return StatusEffectFactory.create_burn(amount)
		_:
			push_error("Unknown status effect ID: " + effect_id)
			return null

# Get all available effect IDs
func get_available_effects():
	var result = []
	result.append_array(_effect_definitions.keys())
	return result

# Check if an effect has custom behavior
func has_custom_behavior(effect_id: String) -> bool:
	return _behavior_scripts.has(effect_id)

# Reload all effects (useful for development)
func reload_effects() -> void:
	_effect_definitions.clear()
	_behavior_scripts.clear()
	_load_all_effects()

# Get effect definition data (for editor/debugging)
func get_effect_definition(effect_id: String) -> Dictionary:
	return _effect_definitions.get(effect_id, {})
