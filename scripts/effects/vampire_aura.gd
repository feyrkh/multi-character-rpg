# vampire_aura.gd
# Example custom effect: Life steal on attack
extends EffectBehavior

var _accumulated_healing: int = 0

# Called when the target attacks
func on_attacking(target: CombatantState, victim: CombatantState, damage_instance: DamageInstance) -> void:
	# Life steal: heal for percentage of damage dealt
	var lifesteal_percent = get_strength() / 100.0  # strength as percentage
	var final_damage = damage_instance.calculate_final_damage()
	var heal_amount = int(final_damage * lifesteal_percent)

	if heal_amount > 0:
		# Accumulate healing to apply at round end through proper pipeline
		_accumulated_healing += heal_amount

# Apply accumulated healing at round end through proper pipeline
func on_round_end(target: CombatantState) -> Dictionary:
	var result = {"healing": _accumulated_healing, "damage": 0, "messages": []}

	if _accumulated_healing > 0:
		result.messages.append("%s heals %d HP from Vampire Aura" % [target.display_name, _accumulated_healing])

	# Reset for next round
	_accumulated_healing = 0

	return result

# Save stateful data for serialization
func save_custom_data() -> Dictionary:
	return {
		"accumulated_healing": _accumulated_healing
	}

# Restore stateful data from serialization
func load_custom_data(data: Dictionary) -> void:
	_accumulated_healing = data.get("accumulated_healing", 0)
