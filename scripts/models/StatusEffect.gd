# StatusEffect.gd
# Represents a temporary effect applied to a combatant
class_name StatusEffect
extends RefCounted

# How the effect decays over time
enum DecayType {
	NONE,                   # Never decays
	STACKS_AT_ROUND_END,    # Loses all stacks at round end
	ONE_AT_ROUND_END,       # Loses 1 stack at round end
	DURATION_ROUNDS         # Decrements duration counter each round
}

# When the effect's logic triggers
enum TriggerEvent {
	ROUND_START,
	ROUND_END,
	BEFORE_MOVE,
	AFTER_MOVE,
	WHEN_ATTACKED,
	WHEN_ATTACKING,
	CONTINUOUS  # Passive effect, no trigger
}

# Category of effect
enum EffectType {
	DEFENSE,
	DAMAGE_OVER_TIME,
	HEAL_OVER_TIME,
	STAT_MODIFIER
}

# How defense effects calculate damage reduction
enum DefenseType {
	PERCENT_REDUCTION_STACKING,      # strength% per stack (15% × 3 stacks = 45%)
	PERCENT_REDUCTION_NONSTACKING,   # flat strength% if any stacks (20% always)
	FLAT_REDUCTION                   # absorb strength damage before percentages
}

# How healing effects calculate HP restoration
enum HealType {
	FIXED_AMOUNT,          # strength HP per trigger
	PERCENT_MAX_HP,        # strength% of max_hp per trigger
	SCALING_WITH_STACKS    # strength × stacks HP per trigger
}

# How damage effects calculate HP loss
enum DamageType {
	FIXED_AMOUNT,          # strength HP per trigger
	PERCENT_CURRENT_HP,    # strength% of current_hp per trigger
	SCALING_WITH_STACKS    # strength × stacks HP per trigger
}

# Core properties
var effect_id: String = ""           # Unique identifier (e.g., "fighter_defense")
var effect_name: String = ""         # Display name
var description: String = ""
var stacks: int = 1                  # Number of stacks
var max_stacks: int = 99             # Stack limit
var decay_type: DecayType = DecayType.NONE
var duration_rounds: int = -1        # -1 = infinite, 0+ = limited
var source_character_id: String = "" # Who applied this effect
var cleansable: bool = true          # Can be removed by cleanse effects

# Behavior properties
var effect_type: EffectType = EffectType.DEFENSE
var defense_type: DefenseType = DefenseType.PERCENT_REDUCTION_STACKING
var heal_type: HealType = HealType.FIXED_AMOUNT
var damage_type: DamageType = DamageType.FIXED_AMOUNT
var strength: float = 0.0            # Multipurpose parameter - meaning depends on type

# Which events trigger this effect's logic
var trigger_events: Array[TriggerEvent] = []

func _init(p_id: String = "", p_name: String = "") -> void:
	effect_id = p_id
	effect_name = p_name

func add_stacks(amount: int) -> void:
	stacks = min(stacks + amount, max_stacks)

func remove_stacks(amount: int) -> void:
	stacks = max(0, stacks - amount)

func should_remove() -> bool:
	return stacks <= 0 or (duration_rounds == 0)

func apply_decay() -> void:
	match decay_type:
		DecayType.STACKS_AT_ROUND_END:
			stacks = 0
		DecayType.ONE_AT_ROUND_END:
			remove_stacks(1)
		DecayType.DURATION_ROUNDS:
			if duration_rounds > 0:
				duration_rounds -= 1

# Calculate damage reduction for DEFENSE type effects
func get_damage_reduction(target: CombatantState = null) -> Dictionary:
	# Check for custom behavior
	if has_meta("behavior") and target:
		var behavior: EffectBehavior = get_meta("behavior")
		var custom_result = behavior.calculate_damage_reduction(target)
		if custom_result != null:
			return custom_result

	if effect_type != EffectType.DEFENSE:
		return {"percent": 0.0, "flat": 0}

	var result = {"percent": 0.0, "flat": 0}

	match defense_type:
		DefenseType.PERCENT_REDUCTION_STACKING:
			# strength% per stack
			result.percent = (strength / 100.0) * stacks
		DefenseType.PERCENT_REDUCTION_NONSTACKING:
			# flat strength% if any stacks
			if stacks > 0:
				result.percent = strength / 100.0
		DefenseType.FLAT_REDUCTION:
			# absorb strength damage per stack
			result.flat = int(strength) * stacks

	return result

# Calculate healing for HEAL_OVER_TIME type effects
func calculate_healing(target: CombatantState = null) -> int:
	# Check for custom behavior
	if has_meta("behavior") and target:
		var behavior: EffectBehavior = get_meta("behavior")
		var custom_result = behavior.calculate_healing(target)
		if custom_result >= 0:
			return custom_result

	if effect_type != EffectType.HEAL_OVER_TIME:
		return 0

	var max_hp = target.max_hp if target else 100

	match heal_type:
		HealType.FIXED_AMOUNT:
			return int(strength)
		HealType.PERCENT_MAX_HP:
			return int(max_hp * (strength / 100.0))
		HealType.SCALING_WITH_STACKS:
			return int(strength) * stacks

	return 0

# Calculate damage for DAMAGE_OVER_TIME type effects
func calculate_damage(target: CombatantState = null) -> int:
	# Check for custom behavior
	if has_meta("behavior") and target:
		var behavior: EffectBehavior = get_meta("behavior")
		var custom_result = behavior.calculate_damage(target)
		if custom_result >= 0:
			return custom_result

	if effect_type != EffectType.DAMAGE_OVER_TIME:
		return 0

	var current_hp = target.current_hp if target else 100

	match damage_type:
		DamageType.FIXED_AMOUNT:
			return int(strength)
		DamageType.PERCENT_CURRENT_HP:
			return int(current_hp * (strength / 100.0))
		DamageType.SCALING_WITH_STACKS:
			return int(strength) * stacks

	return 0

func to_dict() -> Dictionary:
	var dict = {
		"effect_id": effect_id,
		"effect_name": effect_name,
		"description": description,
		"stacks": stacks,
		"max_stacks": max_stacks,
		"decay_type": decay_type,
		"duration_rounds": duration_rounds,
		"source_character_id": source_character_id,
		"cleansable": cleansable,
		"effect_type": effect_type,
		"defense_type": defense_type,
		"heal_type": heal_type,
		"damage_type": damage_type,
		"strength": strength,
		"trigger_events": trigger_events
	}

	# Save behavior custom data if available
	if has_meta("behavior"):
		var behavior: EffectBehavior = get_meta("behavior")
		dict["behavior_data"] = behavior.save_custom_data()

	return dict

static func from_dict(dict: Dictionary, effect_mgr = null) -> StatusEffect:
	var effect = StatusEffect.new()
	effect.effect_id = dict.get("effect_id", "")
	effect.effect_name = dict.get("effect_name", "")
	effect.description = dict.get("description", "")
	effect.stacks = dict.get("stacks", 1)
	effect.max_stacks = dict.get("max_stacks", 99)
	effect.decay_type = dict.get("decay_type", DecayType.NONE)
	effect.duration_rounds = dict.get("duration_rounds", -1)
	effect.source_character_id = dict.get("source_character_id", "")
	effect.cleansable = dict.get("cleansable", true)
	effect.effect_type = dict.get("effect_type", EffectType.DEFENSE)
	effect.defense_type = dict.get("defense_type", DefenseType.PERCENT_REDUCTION_STACKING)
	effect.heal_type = dict.get("heal_type", HealType.FIXED_AMOUNT)
	effect.damage_type = dict.get("damage_type", DamageType.FIXED_AMOUNT)
	effect.strength = dict.get("strength", 0.0)
	effect.trigger_events = dict.get("trigger_events", [])

	# Restore behavior if this effect has custom behavior
	# Use provided effect_mgr or fall back to StatusEffectMgr autoload
	if dict.has("behavior_data"):
		var mgr = effect_mgr if effect_mgr else StatusEffectMgr
		if mgr:
			var template_effect = mgr.create_effect(effect.effect_id)
			if template_effect and template_effect.has_meta("behavior"):
				# Attach fresh behavior instance
				var behavior = template_effect.get_meta("behavior")
				effect.set_meta("behavior", behavior)
				# Restore custom state
				if dict["behavior_data"]:
					behavior.load_custom_data(dict["behavior_data"])
		else:
			push_warning("StatusEffectMgr not available, effect behaviors won't be restored for: %s" % effect.effect_id)

	return effect

# Create a deep copy of this status effect, preserving behavior metadata
func duplicate(deep: bool = true) -> StatusEffect:
	var copy = StatusEffect.new(effect_id, effect_name)
	copy.description = description
	copy.stacks = stacks
	copy.max_stacks = max_stacks
	copy.decay_type = decay_type
	copy.duration_rounds = duration_rounds
	copy.source_character_id = source_character_id
	copy.cleansable = cleansable
	copy.effect_type = effect_type
	copy.defense_type = defense_type
	copy.heal_type = heal_type
	copy.damage_type = damage_type
	copy.strength = strength
	copy.trigger_events = trigger_events.duplicate()

	# CRITICAL: Preserve behavior metadata
	if has_meta("behavior"):
		copy.set_meta("behavior", get_meta("behavior"))

	return copy
