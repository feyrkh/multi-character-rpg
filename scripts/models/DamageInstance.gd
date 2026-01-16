# DamageInstance.gd
# Rich damage tracking with staged modifiers
class_name DamageInstance
extends RefCounted

enum DamageType {
	PHYSICAL,   # Standard physical damage
	MAGICAL,    # Magical damage
	TRUE,       # Ignores all defenses/mitigation
	PIERCING    # Ignores armor but not percent reduction
}

# Alias for CombatModifier.Stage for backward compatibility
const ModifierStage = CombatModifier.Stage

# Core damage properties
var base_damage: int = 0
var damage_type: DamageType = DamageType.PHYSICAL
var source_id: String = ""
var target_id: String = ""

# Modifier tracking by stage
var modifiers: Array[CombatModifier] = []

# Cached calculation result
var _final_damage: int = -1
var _is_calculated: bool = false

func _init(p_base_damage: int = 0, p_damage_type: DamageType = DamageType.PHYSICAL):
	base_damage = p_base_damage
	damage_type = p_damage_type

# Add flat damage modifier
func add_flat_bonus(source: String, amount: int, stage: ModifierStage = ModifierStage.FLAT_PRE) -> void:
	if stage != ModifierStage.FLAT_PRE and stage != ModifierStage.FLAT_POST:
		push_warning("add_flat_bonus called with non-flat stage: %s" % CombatModifier.Stage.keys()[stage])
	modifiers.append(CombatModifier.new(source, float(amount), stage))
	_is_calculated = false

# Add percent damage modifier (as decimal, e.g., 0.2 for +20%)
func add_percent_bonus(source: String, percent: float, stage: ModifierStage = ModifierStage.PERCENT_PRE) -> void:
	if stage != ModifierStage.PERCENT_PRE and stage != ModifierStage.PERCENT_POST and stage != ModifierStage.MITIGATION:
		push_warning("add_percent_bonus called with non-percent stage: %s" % CombatModifier.Stage.keys()[stage])
	modifiers.append(CombatModifier.new(source, percent, stage))
	_is_calculated = false

# Add mitigation (negative percent, e.g., -0.3 for -30% damage)
func add_mitigation(source: String, percent: float) -> void:
	modifiers.append(CombatModifier.new(source, -abs(percent), ModifierStage.MITIGATION))
	_is_calculated = false

# Calculate final damage with staged modifiers
func calculate_final_damage() -> int:
	if _is_calculated:
		return _final_damage

	# TRUE damage ignores all modifiers
	if damage_type == DamageType.TRUE:
		_final_damage = base_damage
		_is_calculated = true
		return _final_damage

	var damage: float = float(base_damage)

	# Stage 1: FLAT_PRE - Add flat bonuses before percent
	for mod in modifiers:
		if mod.stage == ModifierStage.FLAT_PRE:
			damage += mod.amount

	# Stage 2: PERCENT_PRE - Apply early percent bonuses
	var percent_pre_total: float = 0.0
	for mod in modifiers:
		if mod.stage == ModifierStage.PERCENT_PRE:
			percent_pre_total += mod.amount
	if percent_pre_total != 0.0:
		damage *= (1.0 + percent_pre_total)

	# Stage 3: FLAT_POST - Add flat bonuses after percent
	for mod in modifiers:
		if mod.stage == ModifierStage.FLAT_POST:
			damage += mod.amount

	# Stage 4: PERCENT_POST - Apply late percent bonuses
	var percent_post_total: float = 0.0
	for mod in modifiers:
		if mod.stage == ModifierStage.PERCENT_POST:
			percent_post_total += mod.amount
	if percent_post_total != 0.0:
		damage *= (1.0 + percent_post_total)

	# Stage 5: MITIGATION - Apply damage reduction (unless PIERCING)
	if damage_type != DamageType.PIERCING:
		var mitigation_total: float = 0.0
		for mod in modifiers:
			if mod.stage == ModifierStage.MITIGATION:
				mitigation_total += mod.amount

		# Cap mitigation at -99% (can't reduce below 1% of original)
		mitigation_total = max(mitigation_total, -0.99)

		if mitigation_total != 0.0:
			damage *= (1.0 + mitigation_total)

	# Final damage is at least 0
	_final_damage = max(0, int(damage))
	_is_calculated = true
	return _final_damage

# Get the actual damage to apply (alias for calculate_final_damage)
func calculate_actual_damage() -> int:
	return calculate_final_damage()

# Get human-readable breakdown of damage calculation
func get_breakdown() -> String:
	var lines: Array[String] = []

	lines.append("Damage Breakdown (%s):" % DamageType.keys()[damage_type])
	lines.append("  Base: %d" % base_damage)

	if damage_type == DamageType.TRUE:
		lines.append("  TRUE damage - ignores all modifiers")
		lines.append("  Final: %d" % base_damage)
		return "\n".join(lines)

	# Show modifiers by stage
	var stages_order = [
		ModifierStage.FLAT_PRE,
		ModifierStage.PERCENT_PRE,
		ModifierStage.FLAT_POST,
		ModifierStage.PERCENT_POST,
		ModifierStage.MITIGATION
	]

	for stage in stages_order:
		var stage_mods = modifiers.filter(func(m): return m.stage == stage)
		if stage_mods.size() > 0:
			lines.append("  %s:" % CombatModifier.Stage.keys()[stage])
			for mod in stage_mods:
				if stage == ModifierStage.FLAT_PRE or stage == ModifierStage.FLAT_POST:
					lines.append("    %s: %+d" % [mod.source, int(mod.amount)])
				else:
					lines.append("    %s: %+.1f%%" % [mod.source, mod.amount * 100.0])

	lines.append("  Final: %d" % calculate_final_damage())
	return "\n".join(lines)

# Get compact single-line summary
func get_summary() -> String:
	var final = calculate_final_damage()
	if modifiers.size() == 0:
		return "%d %s damage" % [final, DamageType.keys()[damage_type]]
	else:
		return "%d %s damage (%d base, %d modifiers)" % [
			final,
			DamageType.keys()[damage_type],
			base_damage,
			modifiers.size()
		]

# Serialization support
func to_dict() -> Dictionary:
	return {
		"base_damage": base_damage,
		"damage_type": damage_type,
		"source_id": source_id,
		"target_id": target_id,
		"final_damage": calculate_final_damage(),
		"modifiers": modifiers.map(func(m): return {
			"source": m.source,
			"amount": m.amount,
			"stage": m.stage
		})
	}
