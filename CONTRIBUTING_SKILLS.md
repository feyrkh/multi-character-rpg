# Contributing Skills and Status Effects

This guide explains how to create new skills, status effects, and extend the combat system.

## Table of Contents

- [Overview](#overview)
- [Creating New Combat Actions](#creating-new-combat-actions)
- [Creating New Status Effects](#creating-new-status-effects)
- [Adding New Effect Behaviors](#adding-new-effect-behaviors)
- [Creating New Character Forms](#creating-new-character-forms)
- [Extending the Lifecycle System](#extending-the-lifecycle-system)
- [Examples](#examples)

---

## Overview

The combat system is built around three key concepts:

1. **Combat Actions** - What characters do during combat (attack, defend, heal, etc.)
2. **Status Effects** - Temporary buffs/debuffs that modify combat behavior
3. **Combat Forms** - Sequences of actions that characters can execute

The system is designed to be **data-driven** and **extensible** through parameterized enums and factory methods.

---

## Creating New Combat Actions

Combat actions are defined in JSON files located in `data/combat/actions/`.

### Step 1: Create the JSON File

Create a new file in `data/combat/actions/` (e.g., `fireball.json`):

```json
{
	"action_type": 2,
	"target_type": 3,
	"power": 25,
	"skill_id": "fireball",
	"description": "Hurl a blazing fireball at all enemies",
	"icon_path": "res://assets/icons/fireball.png"
}
```

### Action Type Values

- `0` = ATTACK - Physical damage
- `1` = DEFEND - Apply defense status effects
- `2` = SKILL - Special abilities (healing, damage, buffs)
- `3` = ITEM - Consumable items

### Target Type Values

- `0` = ENEMY - Single enemy
- `1` = SELF - Self-target
- `2` = ALLY - Single ally
- `3` = ALL_ENEMIES - All enemies
- `4` = ALL_ALLIES - All allies

### Step 2: Add Action Logic (if needed)

For skills with special behavior, modify `CombatMgr._execute_action_with_effects()`:

```gdscript
elif action.skill_id == "fireball":
	var damage = action.power
	var targets = _get_targets_for_action(action, source, target)
	for t in targets:
		var actual = t.take_damage(damage)
		results.damage_dealt += damage
		results.actual_damage += actual
		damage_dealt.emit(source.combatant_id, t.combatant_id, damage, actual)
```

### Step 3: Add to Character's Known Actions

In `Main.gd` or when creating a character:

```gdscript
character.known_actions.append(KnownCombatAction.new("fireball"))
```

---

## Creating New Status Effects

Status effects are created through `StatusEffectFactory.gd` using parameterized types.

### Understanding Effect Types

Status effects use enum-based behaviors:

```gdscript
# Main category
enum EffectType { DEFENSE, DAMAGE_OVER_TIME, HEAL_OVER_TIME, STAT_MODIFIER }

# Defense calculation modes
enum DefenseType {
    PERCENT_REDUCTION_STACKING,     # strength% per stack (15% × 3 = 45%)
    PERCENT_REDUCTION_NONSTACKING,  # flat strength% if any stacks (20% always)
    FLAT_REDUCTION                  # absorb strength damage
}

# Healing calculation modes
enum HealType {
    FIXED_AMOUNT,          # strength HP per trigger
    PERCENT_MAX_HP,        # strength% of max_hp
    SCALING_WITH_STACKS    # strength × stacks HP
}

# Damage calculation modes
enum DamageType {
    FIXED_AMOUNT,          # strength HP per trigger
    PERCENT_CURRENT_HP,    # strength% of current_hp
    SCALING_WITH_STACKS    # strength × stacks HP
}
```

### Example: Creating a New Defense Effect

Add to `StatusEffectFactory.gd`:

```gdscript
# Tank's defense: 10% flat reduction + 5 flat damage absorption per stack
static func create_tank_defense() -> StatusEffect:
	var effect = StatusEffect.new("tank_defense", "Iron Wall")
	effect.description = "10% damage reduction plus 5 damage absorbed per stack"
	effect.effect_type = StatusEffect.EffectType.DEFENSE
	effect.defense_type = StatusEffect.DefenseType.FLAT_REDUCTION
	effect.strength = 5.0  # 5 damage absorbed per stack
	effect.decay_type = StatusEffect.DecayType.ONE_AT_ROUND_END
	effect.max_stacks = 20
	effect.trigger_events = [StatusEffect.TriggerEvent.CONTINUOUS]
	effect.cleansable = false
	return effect
```

### Example: Creating a Damage Over Time Effect

```gdscript
# Bleed: 5% of current HP per round
static func create_bleed() -> StatusEffect:
	var effect = StatusEffect.new("bleed", "Bleed")
	effect.description = "Loses 5% of current HP each round"
	effect.effect_type = StatusEffect.EffectType.DAMAGE_OVER_TIME
	effect.damage_type = StatusEffect.DamageType.PERCENT_CURRENT_HP
	effect.strength = 5.0  # 5% of current HP
	effect.decay_type = StatusEffect.DecayType.DURATION_ROUNDS
	effect.duration_rounds = 5
	effect.trigger_events = [StatusEffect.TriggerEvent.ROUND_START]
	effect.cleansable = true
	return effect
```

### Example: Creating a Heal Over Time Effect

```gdscript
# Regeneration: 10% of max HP per round
static func create_strong_regen() -> StatusEffect:
	var effect = StatusEffect.new("strong_regen", "Vigorous Regeneration")
	effect.description = "Restores 10% of max HP each round"
	effect.effect_type = StatusEffect.EffectType.HEAL_OVER_TIME
	effect.heal_type = StatusEffect.HealType.PERCENT_MAX_HP
	effect.strength = 10.0  # 10% of max HP
	effect.decay_type = StatusEffect.DecayType.DURATION_ROUNDS
	effect.duration_rounds = 3
	effect.trigger_events = [StatusEffect.TriggerEvent.ROUND_START]
	effect.cleansable = true
	return effect
```

### Registering Effects in the Factory

Add to `create_from_id()`:

```gdscript
static func create_from_id(effect_id: String, params: Dictionary = {}) -> StatusEffect:
	match effect_id:
		# ... existing effects ...
		"tank_defense":
			return create_tank_defense()
		"bleed":
			var duration = params.get("duration", 5)
			var effect = create_bleed()
			effect.duration_rounds = duration
			return effect
		"strong_regen":
			return create_strong_regen()
		_:
			push_error("Unknown status effect ID: " + effect_id)
			return null
```

---

## Adding New Effect Behaviors

To add entirely new effect calculation modes:

### Step 1: Add Enum Values

In `StatusEffect.gd`:

```gdscript
enum DefenseType {
	PERCENT_REDUCTION_STACKING,
	PERCENT_REDUCTION_NONSTACKING,
	FLAT_REDUCTION,
	ABSORB_AND_REFLECT  # New type: absorb damage and deal half back
}
```

### Step 2: Implement Calculation Logic

In `StatusEffect.gd`, modify `get_damage_reduction()`:

```gdscript
func get_damage_reduction() -> Dictionary:
	if effect_type != EffectType.DEFENSE:
		return {"percent": 0.0, "flat": 0, "reflect": 0}

	var result = {"percent": 0.0, "flat": 0, "reflect": 0}

	match defense_type:
		# ... existing types ...
		DefenseType.ABSORB_AND_REFLECT:
			result.flat = int(strength) * stacks
			result.reflect = result.flat / 2  # Reflect half of absorbed damage

	return result
```

### Step 3: Handle in Damage Calculation

In `CombatantState.gd`, modify `take_damage()`:

```gdscript
func take_damage(damage: int) -> Dictionary:
	if damage <= 0:
		return {"actual_damage": 0, "reflected": 0}

	var reduction = get_total_damage_reduction()
	var remaining_damage = max(0, damage - reduction.flat)
	var actual_damage = int(remaining_damage * (1.0 - reduction.percent))

	current_hp = max(0, current_hp - actual_damage)

	return {
		"actual_damage": actual_damage,
		"reflected": reduction.get("reflect", 0)
	}
```

---

## Creating New Character Forms

Forms are sequences of actions that characters execute during combat.

### Method 1: In Character Creation (Main.gd)

```gdscript
# Create a new Mage character
var mage = GameManager.create_character("Mage")
mage.stats.hp = 80
mage.stats.mp = 150
mage.stats.attack = 6
mage.stats.defense = 5

# Add known actions
mage.known_actions.append(KnownCombatAction.new("fireball"))
mage.known_actions.append(KnownCombatAction.new("ice_shard"))
mage.known_actions.append(KnownCombatAction.new("heal"))

# Form: Elemental Barrage
var elemental_barrage = CombatForm.new("Elemental Barrage")
elemental_barrage.description = "Alternate fire and ice attacks"
var fireball = GameManager.get_combat_action("fireball")
var ice_shard = GameManager.get_combat_action("ice_shard")
if fireball and ice_shard:
	elemental_barrage.add_action(fireball)
	elemental_barrage.add_action(ice_shard)
	elemental_barrage.add_action(fireball)
mage.combat_forms.append(elemental_barrage)

# Form: Support Caster
var support_caster = CombatForm.new("Support Caster")
support_caster.description = "Heal allies and shield from damage"
var heal = GameManager.get_combat_action("heal")
var defend_all = GameManager.get_combat_action("defend_all")
if heal and defend_all:
	support_caster.add_action(heal)
	support_caster.add_action(defend_all)
	support_caster.add_action(heal)
mage.combat_forms.append(support_caster)
```

### Method 2: Using the In-Game Form Editor

The game includes a drag-and-drop form editor (accessible via the "Forms" button):

1. Select a character from the dropdown
2. Click "New Form" to create a form
3. Drag actions from the "Available Actions" list into action slots
4. Rearrange actions by dragging
5. Right-click to clear a slot
6. Save when done

---

## Extending the Lifecycle System

The combat system emits signals at key lifecycle events:

### Available Lifecycle Events

```gdscript
# In CombatMgr.gd
signal round_started(round_number: int)
signal round_ended(round_number: int)
signal character_move_started(combatant_id: String, action: CombatAction)
signal character_move_executing(combatant_id: String, action: CombatAction)
signal character_move_finished(combatant_id: String, action: CombatAction, results: Dictionary)
signal status_effect_applied(combatant_id: String, effect: StatusEffect)
signal damage_dealt(source_id: String, target_id: String, damage: int, actual_damage: int)
signal healing_applied(target_id: String, amount: int, actual_healing: int)
```

### Adding New Trigger Events

To add a new trigger event for status effects:

#### Step 1: Add Enum Value

In `StatusEffect.gd`:

```gdscript
enum TriggerEvent {
	ROUND_START,
	ROUND_END,
	BEFORE_MOVE,
	AFTER_MOVE,
	WHEN_ATTACKED,
	WHEN_ATTACKING,
	CONTINUOUS,
	WHEN_BELOW_HALF_HP  # New trigger
}
```

#### Step 2: Emit at the Right Time

In `CombatMgr.gd`, check HP after damage and emit lifecycle event:

```gdscript
func _execute_action_with_effects(...) -> Dictionary:
	# ... execute action ...

	# Check if target fell below 50% HP
	if target.get_hp_percent() < 0.5:
		_process_lifecycle_event(StatusEffect.TriggerEvent.WHEN_BELOW_HALF_HP)
```

#### Step 3: Create Effects That Use It

In `StatusEffectFactory.gd`:

```gdscript
static func create_desperation() -> StatusEffect:
	var effect = StatusEffect.new("desperation", "Desperation")
	effect.description = "Gain 20% damage boost when below 50% HP"
	effect.effect_type = StatusEffect.EffectType.STAT_MODIFIER
	effect.strength = 20.0
	effect.trigger_events = [StatusEffect.TriggerEvent.WHEN_BELOW_HALF_HP]
	return effect
```

---

## Examples

### Example 1: Vampire Life Steal

Create an attack that heals the attacker:

```json
// data/combat/actions/vampire_strike.json
{
	"action_type": 2,
	"target_type": 0,
	"power": 15,
	"skill_id": "vampire_strike",
	"description": "Attack and heal for 50% of damage dealt",
	"icon_path": ""
}
```

In `CombatMgr._execute_action_with_effects()`:

```gdscript
elif action.skill_id == "vampire_strike":
	var damage = action.power
	var actual = target.take_damage(damage)
	results.damage_dealt = damage
	results.actual_damage = actual
	total_damage_dealt += actual

	# Life steal: heal for 50% of damage dealt
	var lifesteal = int(actual * 0.5)
	var healed = source.heal(lifesteal)
	healing_applied.emit(source.combatant_id, lifesteal, healed)

	damage_dealt.emit(source.combatant_id, target.combatant_id, damage, actual)
	action_executed.emit(action, source.combatant_id, target.combatant_id, actual)
```

### Example 2: Counter Attack Status

Create a status that reflects damage:

```gdscript
static func create_counter_stance() -> StatusEffect:
	var effect = StatusEffect.new("counter_stance", "Counter Stance")
	effect.description = "Reflect 30% of incoming damage back to attacker"
	effect.effect_type = StatusEffect.EffectType.DEFENSE
	effect.defense_type = StatusEffect.DefenseType.PERCENT_REDUCTION_NONSTACKING
	effect.strength = 10.0  # 10% reduction
	effect.decay_type = StatusEffect.DecayType.ONE_AT_ROUND_END
	effect.max_stacks = 3
	effect.trigger_events = [StatusEffect.TriggerEvent.WHEN_ATTACKED]
	# Custom property for reflection
	effect.set_meta("reflect_percent", 30.0)
	return effect
```

Then in `CombatantState`, check for counter effects when attacked:

```gdscript
func take_damage(damage: int, attacker: CombatantState = null) -> Dictionary:
	# ... normal damage calculation ...

	# Check for counter effects
	var reflected = 0
	for effect in status_effects:
		if effect.has_meta("reflect_percent"):
			reflected += int(actual_damage * (effect.get_meta("reflect_percent") / 100.0))

	if reflected > 0 and attacker:
		attacker.take_damage(reflected)

	return {"actual_damage": actual_damage, "reflected": reflected}
```

### Example 3: Combo System

Track consecutive hits with a status effect:

```gdscript
static func create_combo() -> StatusEffect:
	var effect = StatusEffect.new("combo", "Combo")
	effect.description = "Each hit increases damage by 5%"
	effect.effect_type = StatusEffect.EffectType.STAT_MODIFIER
	effect.strength = 5.0  # 5% per stack
	effect.decay_type = StatusEffect.DecayType.STACKS_AT_ROUND_END
	effect.max_stacks = 10
	effect.trigger_events = [StatusEffect.TriggerEvent.CONTINUOUS]
	return effect
```

Then apply a combo stack after each successful attack in `_execute_action_with_effects()`.

---

## Best Practices

1. **Use Descriptive IDs**: Effect IDs should be unique and descriptive (e.g., "fire_resistance", "poison", "haste")

2. **Keep Effects Focused**: Each effect should do one thing well (single responsibility)

3. **Leverage Existing Types**: Before creating new enum values, see if existing types can be parameterized

4. **Test Edge Cases**: Test with 0 stacks, max stacks, expired effects, and multiple effects

5. **Document Custom Behaviors**: Add comments for any non-standard effect behavior

6. **Use Factory Methods**: Always create effects through `StatusEffectFactory` for consistency

7. **Balance Carefully**: Test damage/healing values in actual combat before finalizing

---

## Debugging Tips

### View Active Status Effects

In `CombatView.gd`, add logging:

```gdscript
func _on_status_effect_applied(combatant_id: String, effect: StatusEffect) -> void:
	print("Effect applied: ", effect.effect_name, " (", effect.stacks, " stacks)")
	print("  Type: ", effect.effect_type)
	print("  Strength: ", effect.strength)
```

### Monitor Damage Calculations

```gdscript
func _on_damage_dealt(source_id: String, target_id: String, damage: int, actual_damage: int) -> void:
	print("Damage: ", damage, " → ", actual_damage, " (", damage - actual_damage, " reduced)")
	if CombatMgr.party_state:
		print("Party defense: ", CombatMgr.party_state.get_total_damage_reduction())
```

### Test Status Effect Decay

```gdscript
# In CombatMgr.gd, after round_ended
print("Party effects: ", party_state.status_effects.size())
for effect in party_state.status_effects:
	print("  - ", effect.effect_name, ": ", effect.stacks, " stacks, ", effect.duration_rounds, " rounds left")
```

---

## Additional Resources

- `scripts/models/StatusEffect.gd` - Status effect data model
- `scripts/models/StatusEffectFactory.gd` - Predefined effects
- `scripts/models/CombatantState.gd` - Combat state and effect processing
- `scripts/autoload/CombatMgr.gd` - Combat lifecycle and action execution
- `data/combat/actions/` - Action JSON files

For questions or contributions, please see the main `README.md` and `CLAUDE.md` files.
