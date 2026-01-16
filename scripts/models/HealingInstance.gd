# HealingInstance.gd
# Rich healing tracking with modifiers
class_name HealingInstance
extends RefCounted

enum HealingType {
	DIRECT,         # Standard healing
	REGENERATION,   # Over-time healing
	LIFESTEAL       # Healing from damage dealt
}

# Alias for CombatModifier.Stage for backward compatibility
const ModifierStage = CombatModifier.Stage

# Core healing properties
var base_healing: int = 0
var healing_type: HealingType = HealingType.DIRECT
var source_id: String = ""
var target_id: String = ""

# Modifier tracking by stage
var modifiers: Array[CombatModifier] = []

# Cached calculation result
var _final_healing: int = -1
var _is_calculated: bool = false

# Actual healing applied (may be less due to max HP cap)
var actual_healing: int = 0

func _init(p_base_healing: int = 0, p_healing_type: HealingType = HealingType.DIRECT):
	base_healing = p_base_healing
	healing_type = p_healing_type

# Add flat healing modifier
func add_flat_bonus(source: String, amount: int, stage: ModifierStage = ModifierStage.FLAT_PRE) -> void:
	if stage != ModifierStage.FLAT_PRE and stage != ModifierStage.FLAT_POST:
		push_warning("add_flat_bonus called with non-flat stage: %s" % CombatModifier.Stage.keys()[stage])
	modifiers.append(CombatModifier.new(source, float(amount), stage))
	_is_calculated = false

# Add percent healing modifier (as decimal, e.g., 0.25 for +25%)
func add_percent_bonus(source: String, percent: float, stage: ModifierStage = ModifierStage.PERCENT_PRE) -> void:
	if stage != ModifierStage.PERCENT_PRE and stage != ModifierStage.PERCENT_POST:
		push_warning("add_percent_bonus called with non-percent stage: %s" % CombatModifier.Stage.keys()[stage])
	modifiers.append(CombatModifier.new(source, percent, stage))
	_is_calculated = false

# Calculate final healing with staged modifiers
func calculate_final_healing() -> int:
	if _is_calculated:
		return _final_healing

	var healing: float = float(base_healing)

	# Stage 1: FLAT_PRE - Add flat bonuses before percent
	for mod in modifiers:
		if mod.stage == ModifierStage.FLAT_PRE:
			healing += mod.amount

	# Stage 2: PERCENT_PRE - Apply early percent bonuses
	var percent_pre_total: float = 0.0
	for mod in modifiers:
		if mod.stage == ModifierStage.PERCENT_PRE:
			percent_pre_total += mod.amount
	if percent_pre_total != 0.0:
		healing *= (1.0 + percent_pre_total)

	# Stage 3: FLAT_POST - Add flat bonuses after percent
	for mod in modifiers:
		if mod.stage == ModifierStage.FLAT_POST:
			healing += mod.amount

	# Stage 4: PERCENT_POST - Apply late percent bonuses
	var percent_post_total: float = 0.0
	for mod in modifiers:
		if mod.stage == ModifierStage.PERCENT_POST:
			percent_post_total += mod.amount
	if percent_post_total != 0.0:
		healing *= (1.0 + percent_post_total)

	# Final healing is at least 0
	_final_healing = max(0, int(healing))
	_is_calculated = true
	return _final_healing

# Get the actual healing to apply (alias for calculate_final_healing)
func calculate_actual_healing() -> int:
	return calculate_final_healing()

# Get human-readable breakdown of healing calculation
func get_breakdown() -> String:
	var lines: Array[String] = []

	lines.append("Healing Breakdown (%s):" % HealingType.keys()[healing_type])
	lines.append("  Base: %d" % base_healing)

	# Show modifiers by stage
	var stages_order = [
		ModifierStage.FLAT_PRE,
		ModifierStage.PERCENT_PRE,
		ModifierStage.FLAT_POST,
		ModifierStage.PERCENT_POST
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

	var final = calculate_final_healing()
	lines.append("  Calculated: %d" % final)
	if actual_healing > 0 and actual_healing != final:
		lines.append("  Actual: %d (capped by max HP)" % actual_healing)

	return "\n".join(lines)

# Get compact single-line summary
func get_summary() -> String:
	var final = calculate_final_healing()
	if modifiers.size() == 0:
		return "%d %s healing" % [final, HealingType.keys()[healing_type]]
	else:
		return "%d %s healing (%d base, %d modifiers)" % [
			final,
			HealingType.keys()[healing_type],
			base_healing,
			modifiers.size()
		]

# Serialization support
func to_dict() -> Dictionary:
	return {
		"base_healing": base_healing,
		"healing_type": healing_type,
		"source_id": source_id,
		"target_id": target_id,
		"final_healing": calculate_final_healing(),
		"actual_healing": actual_healing,
		"modifiers": modifiers.map(func(m): return {
			"source": m.source,
			"amount": m.amount,
			"stage": m.stage
		})
	}
