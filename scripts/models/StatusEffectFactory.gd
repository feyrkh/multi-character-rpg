# StatusEffectFactory.gd
# Factory for creating predefined status effects
class_name StatusEffectFactory
extends RefCounted

# Fighter's defense: 15% reduction per stack, all stacks decay at round end
static func create_fighter_defense() -> StatusEffect:
	var effect = StatusEffect.new("fighter_defense", "Defensive Stance")
	effect.description = "15% damage reduction per stack, resets at round end"
	effect.effect_type = StatusEffect.EffectType.DEFENSE
	effect.defense_type = StatusEffect.DefenseType.PERCENT_REDUCTION_STACKING
	effect.strength = 15.0  # 15% per stack
	effect.decay_type = StatusEffect.DecayType.STACKS_AT_ROUND_END
	effect.max_stacks = 10
	effect.trigger_events = [StatusEffect.TriggerEvent.CONTINUOUS]
	effect.cleansable = false  # Can't be cleansed, strategic defense
	return effect

# Cleric's defense: Flat 20% reduction regardless of stacks, loses 1 stack per round
static func create_cleric_defense() -> StatusEffect:
	var effect = StatusEffect.new("cleric_defense", "Protective Aura")
	effect.description = "Flat 20% damage reduction, decreases by 1 stack per round"
	effect.effect_type = StatusEffect.EffectType.DEFENSE
	effect.defense_type = StatusEffect.DefenseType.PERCENT_REDUCTION_NONSTACKING
	effect.strength = 20.0  # Flat 20%
	effect.decay_type = StatusEffect.DecayType.ONE_AT_ROUND_END
	effect.max_stacks = 10
	effect.trigger_events = [StatusEffect.TriggerEvent.CONTINUOUS]
	effect.cleansable = false  # Can't be cleansed, divine protection
	return effect

# Regeneration: Heal HP at round start
static func create_regeneration(heal_amount: int = 5) -> StatusEffect:
	var effect = StatusEffect.new("regeneration", "Regeneration")
	effect.description = "Restores %d HP at the start of each round" % heal_amount
	effect.effect_type = StatusEffect.EffectType.HEAL_OVER_TIME
	effect.heal_type = StatusEffect.HealType.FIXED_AMOUNT
	effect.strength = float(heal_amount)
	effect.decay_type = StatusEffect.DecayType.DURATION_ROUNDS
	effect.duration_rounds = 3
	effect.trigger_events = [StatusEffect.TriggerEvent.ROUND_START]
	effect.cleansable = true
	return effect

# Poison: Take damage at round start
static func create_poison(damage_amount: int = 3) -> StatusEffect:
	var effect = StatusEffect.new("poison", "Poison")
	effect.description = "Takes %d damage at the start of each round" % damage_amount
	effect.effect_type = StatusEffect.EffectType.DAMAGE_OVER_TIME
	effect.damage_type = StatusEffect.DamageType.FIXED_AMOUNT
	effect.strength = float(damage_amount)
	effect.decay_type = StatusEffect.DecayType.DURATION_ROUNDS
	effect.duration_rounds = 3
	effect.trigger_events = [StatusEffect.TriggerEvent.ROUND_START]
	effect.cleansable = true
	return effect

# Shield: Absorb flat amount of damage
static func create_shield(flat_reduction: int = 100) -> StatusEffect:
	var effect = StatusEffect.new("shield", "Shield")
	effect.description = "Absorbs %d damage before breaking" % flat_reduction
	effect.effect_type = StatusEffect.EffectType.DEFENSE
	effect.defense_type = StatusEffect.DefenseType.FLAT_REDUCTION
	effect.strength = float(flat_reduction)
	effect.decay_type = StatusEffect.DecayType.NONE
	effect.max_stacks = 1
	effect.trigger_events = [StatusEffect.TriggerEvent.CONTINUOUS]
	effect.cleansable = true
	return effect

# Burn: Take damage at round end (fire damage over time)
static func create_burn(damage_amount: int = 5) -> StatusEffect:
	var effect = StatusEffect.new("burn", "Burn")
	effect.description = "Takes %d damage at the end of each round" % damage_amount
	effect.effect_type = StatusEffect.EffectType.DAMAGE_OVER_TIME
	effect.damage_type = StatusEffect.DamageType.FIXED_AMOUNT
	effect.strength = float(damage_amount)
	effect.decay_type = StatusEffect.DecayType.DURATION_ROUNDS
	effect.duration_rounds = 3
	effect.trigger_events = [StatusEffect.TriggerEvent.ROUND_END]
	effect.cleansable = true
	return effect

# Factory method for dynamic creation
static func create_from_id(effect_id: String, params: Dictionary = {}) -> StatusEffect:
	match effect_id:
		"fighter_defense":
			return create_fighter_defense()
		"cleric_defense":
			return create_cleric_defense()
		"regeneration":
			var amount = params.get("amount", 5)
			return create_regeneration(amount)
		"poison":
			var amount = params.get("amount", 3)
			return create_poison(amount)
		"shield":
			var amount = params.get("amount", 100)
			return create_shield(amount)
		"burn":
			var amount = params.get("amount", 5)
			return create_burn(amount)
		_:
			push_error("Unknown status effect ID: " + effect_id)
			return null
