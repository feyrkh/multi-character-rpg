# thorns.gd
# Example custom effect: Reflect damage back to attacker
extends EffectBehavior

# Store array of reflections to handle multiple attacks in one round
var _reflections: Array = []  # Array of {attacker_id: String, damage: int}

# Called when the target is attacked
func on_attacked(target: CombatantState, attacker: CombatantState, damage_instance: DamageInstance) -> void:
	# Calculate reflection based on stacks
	var reflect_percent = (get_strength() / 100.0) * get_stacks()
	var final_damage = damage_instance.calculate_final_damage()
	var reflect_damage = int(final_damage * reflect_percent)

	if reflect_damage > 0:
		# Store reflection data for processing at round end
		_reflections.append({
			"attacker_id": attacker.combatant_id,
			"damage": reflect_damage
		})

# Called after the target is attacked (at round end, we'll reflect)
func on_round_end(target: CombatantState) -> Dictionary:
	var result = {"healing": 0, "damage": 0, "messages": [], "reflected_damage": []}

	# Return all accumulated reflections
	if _reflections.size() > 0:
		result.reflected_damage = _reflections.duplicate()

		# Create summary message
		var total_reflected = 0
		for refl in _reflections:
			total_reflected += refl.damage

		if total_reflected > 0:
			result.messages.append("%s reflects %d damage back from Thorns!" % [target.display_name, total_reflected])

	# Reset for next round
	_reflections.clear()

	return result

# Custom tooltip
func get_tooltip_text(target: CombatantState) -> String:
	var percent = get_strength() * get_stacks()
	return "Reflects %d%% of incoming damage back to attacker" % int(percent)

# Save stateful data for serialization
func save_custom_data() -> Dictionary:
	return {
		"reflections": _reflections.duplicate()
	}

# Restore stateful data from serialization
func load_custom_data(data: Dictionary) -> void:
	_reflections = data.get("reflections", [])
