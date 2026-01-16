# CombatantState.gd
# Tracks a combatant's state during combat (HP, status effects, etc.)
class_name CombatantState
extends RefCounted

var combatant_id: String = ""        # "party" or "enemy" or character ID
var display_name: String = ""
var current_hp: int = 100
var max_hp: int = 100
var status_effects: Array[StatusEffect] = []

func _init(p_id: String = "", p_name: String = "", p_hp: int = 100, p_max_hp: int = 100) -> void:
	combatant_id = p_id
	display_name = p_name
	current_hp = p_hp
	max_hp = p_max_hp

# Status effect management
func apply_status_effect(effect: StatusEffect, source: CombatantState = null) -> void:
	# Check if effect already exists
	var existing = find_status_effect(effect.effect_id)
	if existing:
		# Call custom behavior on stack added
		if existing.has_meta("behavior"):
			var behavior: EffectBehavior = existing.get_meta("behavior")
			behavior.on_stack_added(self, effect.stacks)

		# Add stacks for most effects
		existing.add_stacks(effect.stacks)

		# Refresh duration if the new effect has longer duration
		if effect.duration_rounds > existing.duration_rounds:
			existing.duration_rounds = effect.duration_rounds
	else:
		# Call custom behavior on apply
		if effect.has_meta("behavior"):
			var behavior: EffectBehavior = effect.get_meta("behavior")
			behavior.on_apply(self, source)

		# New effect - add to list
		status_effects.append(effect)

func find_status_effect(effect_id: String) -> StatusEffect:
	for effect in status_effects:
		if effect.effect_id == effect_id:
			return effect
	return null

func remove_status_effect(effect_id: String) -> void:
	for i in range(status_effects.size() - 1, -1, -1):
		if status_effects[i].effect_id == effect_id:
			var effect = status_effects[i]
			# Call custom behavior on remove
			if effect.has_meta("behavior"):
				var behavior: EffectBehavior = effect.get_meta("behavior")
				behavior.on_remove(self)
			status_effects.remove_at(i)

func clear_cleansable_effects() -> void:
	for i in range(status_effects.size() - 1, -1, -1):
		if status_effects[i].cleansable:
			status_effects.remove_at(i)

# Process effects that trigger on a specific event
func process_effects_for_event(event: StatusEffect.TriggerEvent) -> Dictionary:
	# Returns { "healing": int, "damage": int, "messages": Array[String] }
	var result = { "healing": 0, "damage": 0, "messages": [] }

	for effect in status_effects:
		if effect.trigger_events.has(event):
			# Check for custom behavior handling
			if effect.has_meta("behavior"):
				var behavior: EffectBehavior = effect.get_meta("behavior")
				var custom_result = null

				# Call appropriate behavior method based on event
				match event:
					StatusEffect.TriggerEvent.ROUND_START:
						custom_result = behavior.on_round_start(self)
					StatusEffect.TriggerEvent.ROUND_END:
						custom_result = behavior.on_round_end(self)

				# Merge custom results
				if custom_result:
					result.healing += custom_result.get("healing", 0)
					result.damage += custom_result.get("damage", 0)
					result.messages.append_array(custom_result.get("messages", []))
					continue  # Skip standard processing if custom behavior handled it

			# Standard processing for non-custom effects
			# Healing effects
			if effect.effect_type == StatusEffect.EffectType.HEAL_OVER_TIME:
				var heal = effect.calculate_healing(self)
				if heal > 0:
					result.healing += heal
					result.messages.append("%s heals %d HP from %s" % [display_name, heal, effect.effect_name])

			# Damage effects
			if effect.effect_type == StatusEffect.EffectType.DAMAGE_OVER_TIME:
				var dmg = effect.calculate_damage(self)
				if dmg > 0:
					result.damage += dmg
					result.messages.append("%s takes %d damage from %s" % [display_name, dmg, effect.effect_name])

	return result

# Apply decay to all effects at round end
func apply_round_end_decay() -> void:
	for effect in status_effects:
		# Call custom decay callback if available
		if effect.has_meta("behavior"):
			var behavior: EffectBehavior = effect.get_meta("behavior")
			behavior.on_decay(self)

			# Check custom removal logic
			var custom_remove = behavior.should_remove_custom(self)
			if custom_remove != null:
				if custom_remove:
					effect.stacks = 0  # Mark for removal
				continue  # Skip standard decay if custom handled it

		effect.apply_decay()

	# Remove expired effects
	for i in range(status_effects.size() - 1, -1, -1):
		var effect = status_effects[i]
		if effect.should_remove():
			# Call on_remove callback
			if effect.has_meta("behavior"):
				var behavior: EffectBehavior = effect.get_meta("behavior")
				behavior.on_remove(self)
			status_effects.remove_at(i)

# Calculate total damage reduction from all DEFENSE type effects
func get_total_damage_reduction() -> Dictionary:
	var total_percent = 0.0
	var total_flat = 0

	for effect in status_effects:
		if effect.effect_type == StatusEffect.EffectType.DEFENSE:
			if effect.trigger_events.has(StatusEffect.TriggerEvent.CONTINUOUS):
				var reduction = effect.get_damage_reduction(self)
				total_percent += reduction.get("percent", 0.0)
				total_flat += reduction.get("flat", 0)

	# Cap percentage reduction at 99%
	total_percent = min(total_percent, 0.99)

	return {"percent": total_percent, "flat": total_flat}

# Apply damage (already calculated with modifiers)
# NOTE: Damage reduction is applied in DamageInstance.calculate_final_damage()
# This method receives the final damage amount after all modifiers
func take_damage(damage: int) -> int:
	if damage <= 0:
		return 0

	var actual_damage = max(0, damage)
	current_hp = max(0, current_hp - actual_damage)
	return actual_damage

# Heal HP, capped at max_hp
func heal(amount: int) -> int:
	if amount <= 0:
		return 0

	var old_hp = current_hp
	current_hp = min(max_hp, current_hp + amount)
	return current_hp - old_hp

# Get HP as percentage
func get_hp_percent() -> float:
	if max_hp <= 0:
		return 0.0
	return float(current_hp) / float(max_hp)

# Check if combatant is defeated
func is_defeated() -> bool:
	return current_hp <= 0
