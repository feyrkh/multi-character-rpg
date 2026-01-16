# Modular Status Effects Guide

This guide explains how to create status effects using the modular, file-based system that allows you to define effects in JSON and extend them with custom GDScript behavior.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Creating JSON Effect Definitions](#creating-json-effect-definitions)
- [Creating Custom Effect Behaviors](#creating-custom-effect-behaviors)
- [Effect Manager API](#effect-manager-api)
- [Examples](#examples)
- [Best Practices](#best-practices)

---

## Overview

The status effect system has two components:

1. **JSON Definitions** (`data/status_effects/`) - Define basic effect parameters
2. **Behavior Scripts** (`scripts/effects/`) - Optional custom logic for complex effects

### When to Use Each:

| Approach | Use When | Example |
|----------|----------|---------|
| **JSON Only** | Standard effect using existing types | Poison, Regeneration, Basic Defense |
| **JSON + Behavior** | Complex logic, dynamic calculations | Vampire Aura, Thorns, Combo System |

---

## Quick Start

### Example 1: Simple Poison Effect (JSON Only)

Create `data/status_effects/poison.json`:

```json
{
	"name": "Poison",
	"description": "Takes 3 damage at the start of each round",
	"effect_type": 1,
	"damage_type": 0,
	"strength": 3.0,
	"stacks": 1,
	"max_stacks": 5,
	"decay_type": 3,
	"duration_rounds": 3,
	"cleansable": true,
	"triggers": ["ROUND_START"]
}
```

**That's it!** The effect is automatically loaded and ready to use:

```gdscript
var poison = StatusEffectMgr.create_effect("poison")
target.apply_status_effect(poison)
```

### Example 2: Vampire Aura (JSON + Behavior)

Create `data/status_effects/vampire_aura.json`:

```json
{
	"name": "Vampire Aura",
	"description": "Heal for 25% of damage dealt",
	"effect_type": 3,
	"strength": 25.0,
	"stacks": 1,
	"max_stacks": 1,
	"decay_type": 2,
	"duration_rounds": -1,
	"cleansable": true,
	"triggers": ["WHEN_ATTACKING"]
}
```

Create `scripts/effects/vampire_aura.gd`:

```gdscript
extends EffectBehavior

func on_attacking(target: CombatantState, victim: CombatantState, damage: int) -> int:
	var lifesteal_percent = get_strength() / 100.0
	var heal_amount = int(damage * lifesteal_percent)

	if heal_amount > 0:
		var actual_heal = target.heal(heal_amount)
		print("%s heals %d HP from Vampire Aura" % [target.display_name, actual_heal])

	return damage
```

**Done!** The behavior script is automatically attached:

```gdscript
var vampire = StatusEffectMgr.create_effect("vampire_aura")
fighter.apply_status_effect(vampire)
```

---

## Creating JSON Effect Definitions

### File Structure

Place JSON files in `data/status_effects/`. Filename = effect ID.

### JSON Schema

```json
{
	"name": "Display Name",
	"description": "What this effect does",
	"effect_type": 0,       // 0=DEFENSE, 1=DAMAGE_OVER_TIME, 2=HEAL_OVER_TIME, 3=STAT_MODIFIER
	"defense_type": 0,      // For DEFENSE: 0=STACKING, 1=NONSTACKING, 2=FLAT
	"heal_type": 0,         // For HEAL_OVER_TIME: 0=FIXED, 1=PERCENT_MAX_HP, 2=SCALING
	"damage_type": 0,       // For DAMAGE_OVER_TIME: 0=FIXED, 1=PERCENT_CURRENT_HP, 2=SCALING
	"strength": 10.0,       // Main parameter (damage, healing, %, etc.)
	"stacks": 1,            // Initial stack count
	"max_stacks": 10,       // Maximum stacks allowed
	"decay_type": 0,        // 0=NONE, 1=STACKS_AT_ROUND_END, 2=ONE_AT_ROUND_END, 3=DURATION_ROUNDS
	"duration_rounds": -1,  // -1 = infinite, 0+ = limited duration
	"cleansable": true,     // Can be removed by cleanse effects
	"triggers": ["ROUND_START", "CONTINUOUS"]  // When effect activates
}
```

### Effect Types (effect_type)

```json
0 = DEFENSE           // Reduces incoming damage
1 = DAMAGE_OVER_TIME  // Deals damage over time (poison, burn)
2 = HEAL_OVER_TIME    // Heals over time (regeneration)
3 = STAT_MODIFIER     // Custom stat modifications (use with behavior script)
```

### Defense Types (defense_type)

For `effect_type: 0` (DEFENSE):

```json
0 = PERCENT_REDUCTION_STACKING      // strength% per stack (15 × 3 = 45%)
1 = PERCENT_REDUCTION_NONSTACKING   // flat strength% if any stacks (20% always)
2 = FLAT_REDUCTION                  // absorb strength damage per stack
```

### Decay Types (decay_type)

```json
0 = NONE                  // Never decays
1 = STACKS_AT_ROUND_END   // All stacks removed at round end
2 = ONE_AT_ROUND_END      // Loses 1 stack per round
3 = DURATION_ROUNDS       // Decrements duration counter each round
```

### Trigger Events (triggers array)

```json
"ROUND_START"      // Beginning of combat round
"ROUND_END"        // End of combat round
"BEFORE_MOVE"      // Before character acts
"AFTER_MOVE"       // After character acts
"WHEN_ATTACKED"    // When receiving damage
"WHEN_ATTACKING"   // When dealing damage
"CONTINUOUS"       // Always active (for passive effects)
```

---

## Creating Custom Effect Behaviors

### File Structure

Place `.gd` files in `scripts/effects/`. Filename must match effect ID.

### Base Class: EffectBehavior

All custom behaviors extend `EffectBehavior` and override relevant methods:

```gdscript
extends EffectBehavior

# Called when effect is first applied
func on_apply(target: CombatantState, source: CombatantState) -> void:
	pass

# Called when effect is removed
func on_remove(target: CombatantState) -> void:
	pass

# Called when stacks are added
func on_stack_added(target: CombatantState, stacks_added: int) -> void:
	pass

# Called at round start
func on_round_start(target: CombatantState) -> Dictionary:
	return {"healing": 0, "damage": 0, "messages": []}

# Called at round end
func on_round_end(target: CombatantState) -> Dictionary:
	return {"healing": 0, "damage": 0, "messages": []}

# Called before target executes a move
func on_before_move(target: CombatantState, action: CombatAction) -> void:
	pass

# Called after target executes a move
func on_after_move(target: CombatantState, action: CombatAction) -> void:
	pass

# Called when target is attacked (can modify incoming damage)
func on_attacked(target: CombatantState, attacker: CombatantState, damage: int) -> int:
	return damage  # Return modified damage

# Called when target attacks (can modify outgoing damage)
func on_attacking(target: CombatantState, victim: CombatantState, damage: int) -> int:
	return damage  # Return modified damage

# Custom damage reduction calculation
func calculate_damage_reduction(target: CombatantState) -> Dictionary:
	return null  # Return null to use standard calculation

# Custom healing calculation
func calculate_healing(target: CombatantState) -> int:
	return -1  # Return -1 to use standard calculation

# Custom damage calculation
func calculate_damage(target: CombatantState) -> int:
	return -1  # Return -1 to use standard calculation

# Custom decay logic
func should_remove_custom(target: CombatantState) -> bool:
	return null  # Return null to use standard decay

# Called when decay is applied
func on_decay(target: CombatantState) -> void:
	pass
```

### Helper Methods

Access effect data from your behavior:

```gdscript
func get_stacks() -> int
func get_strength() -> float
func get_duration() -> int
```

---

## Effect Manager API

### StatusEffectMgr (Autoload Singleton)

```gdscript
# Create an effect by ID
var effect = StatusEffectMgr.create_effect("poison")

# Create with parameters override
var strong_poison = StatusEffectMgr.create_effect("poison", {"strength": 10, "duration": 5})

# Get all available effects
var all_effects = StatusEffectMgr.get_available_effects()

# Check if effect has custom behavior
var has_script = StatusEffectMgr.has_custom_behavior("vampire_aura")

# Reload all effects (development only)
StatusEffectMgr.reload_effects()

# Get effect definition (for debugging)
var def = StatusEffectMgr.get_effect_definition("poison")
```

### CombatantState API

```gdscript
# Apply effect to a target
target.apply_status_effect(effect, source)

# Find effect on target
var poison = target.find_status_effect("poison")

# Remove effect
target.remove_status_effect("poison")

# Clear all cleansable effects
target.clear_cleansable_effects()
```

---

## Examples

### Example 1: Thorns (Damage Reflection)

`data/status_effects/thorns.json`:
```json
{
	"name": "Thorns",
	"description": "Reflects 15% of incoming damage per stack",
	"effect_type": 3,
	"strength": 15.0,
	"stacks": 1,
	"max_stacks": 5,
	"decay_type": 2,
	"duration_rounds": -1,
	"cleansable": true,
	"triggers": ["WHEN_ATTACKED", "ROUND_END"]
}
```

`scripts/effects/thorns.gd`:
```gdscript
extends EffectBehavior

var _attacker_ref: WeakRef = null
var _damage_to_reflect: int = 0

func on_attacked(target: CombatantState, attacker: CombatantState, damage: int) -> int:
	var reflect_percent = (get_strength() / 100.0) * get_stacks()
	_damage_to_reflect = int(damage * reflect_percent)
	_attacker_ref = weakref(attacker)
	return damage

func on_round_end(target: CombatantState) -> Dictionary:
	var result = {"healing": 0, "damage": 0, "messages": []}

	if _damage_to_reflect > 0 and _attacker_ref:
		var attacker = _attacker_ref.get_ref()
		if attacker:
			attacker.take_damage(_damage_to_reflect)
			result.messages.append("%s reflects %d damage!" % [target.display_name, _damage_to_reflect])

	_damage_to_reflect = 0
	_attacker_ref = null
	return result
```

### Example 2: Berserker Rage (Damage Boost When Low HP)

`data/status_effects/berserker_rage.json`:
```json
{
	"name": "Berserker Rage",
	"description": "Deal more damage when below 50% HP",
	"effect_type": 3,
	"strength": 50.0,
	"stacks": 1,
	"max_stacks": 1,
	"decay_type": 0,
	"duration_rounds": -1,
	"cleansable": false,
	"triggers": ["WHEN_ATTACKING"]
}
```

`scripts/effects/berserker_rage.gd`:
```gdscript
extends EffectBehavior

func on_attacking(target: CombatantState, victim: CombatantState, damage: int) -> int:
	# Only apply if below 50% HP
	if target.get_hp_percent() < 0.5:
		var bonus_percent = get_strength() / 100.0
		var bonus_damage = int(damage * bonus_percent)
		return damage + bonus_damage

	return damage
```

### Example 3: Shield Bash Counter

`data/status_effects/shield_bash.json`:
```json
{
	"name": "Shield Bash",
	"description": "Next attack deals bonus damage equal to defense stacks",
	"effect_type": 3,
	"strength": 5.0,
	"stacks": 1,
	"max_stacks": 10,
	"decay_type": 0,
	"duration_rounds": -1,
	"cleansable": false,
	"triggers": ["WHEN_ATTACKING"]
}
```

`scripts/effects/shield_bash.gd`:
```gdscript
extends EffectBehavior

func on_attacking(target: CombatantState, victim: CombatantState, damage: int) -> int:
	# Add bonus damage based on stacks
	var bonus = get_stacks() * int(get_strength())

	# Remove effect after one use
	effect_data.stacks = 0

	return damage + bonus
```

### Example 4: Combo Counter

`data/status_effects/combo.json`:
```json
{
	"name": "Combo",
	"description": "Each consecutive hit increases damage",
	"effect_type": 3,
	"strength": 5.0,
	"stacks": 0,
	"max_stacks": 20,
	"decay_type": 1,
	"duration_rounds": -1,
	"cleansable": false,
	"triggers": ["WHEN_ATTACKING", "CONTINUOUS"]
}
```

`scripts/effects/combo.gd`:
```gdscript
extends EffectBehavior

func on_attacking(target: CombatantState, victim: CombatantState, damage: int) -> int:
	# Apply current combo damage
	var combo_bonus_percent = (get_stacks() * get_strength()) / 100.0
	var bonus_damage = int(damage * combo_bonus_percent)

	# Increment combo
	effect_data.add_stacks(1)

	return damage + bonus_damage

func on_round_end(target: CombatantState) -> Dictionary:
	# Show combo count
	if get_stacks() > 0:
		var msg = "%s's combo: %dx (%.0f%% damage)" % [
			target.display_name,
			get_stacks(),
			get_stacks() * get_strength()
		]
		return {"healing": 0, "damage": 0, "messages": [msg]}

	return {"healing": 0, "damage": 0, "messages": []}
```

---

## Best Practices

### 1. Naming Conventions

- **Effect IDs**: lowercase_snake_case (e.g., `vampire_aura`, `fire_resistance`)
- **File names**: Match effect ID exactly
- **Display names**: Title Case (e.g., "Vampire Aura", "Fire Resistance")

### 2. When to Use Custom Behaviors

✅ **Use Custom Behavior When:**
- Effect needs dynamic calculations based on game state
- Multiple conditions must be checked
- Effect modifies damage in complex ways
- Effect interacts with other systems
- Effect has state that persists between triggers

❌ **Don't Use Custom Behavior When:**
- Standard enum types cover your needs
- Effect is simple damage/healing/defense
- No special logic required

### 3. Performance Tips

- Avoid heavy calculations in frequently-called methods (`on_attacking`, `on_attacked`)
- Cache computed values when possible
- Use `get_strength()` helpers instead of accessing `effect_data` directly
- Clean up references in `on_remove()` to prevent memory leaks

### 4. Debugging Custom Behaviors

Add print statements to behavior methods:

```gdscript
func on_attacking(target: CombatantState, victim: CombatantState, damage: int) -> int:
	print("[%s] on_attacking: %d damage, %d stacks" % [effect_data.effect_name, damage, get_stacks()])
	# ... your logic ...
	return modified_damage
```

Enable effect logging in CombatView:

```gdscript
CombatMgr.status_effect_applied.connect(func(id, effect):
	print("Applied: ", effect.effect_name, " to ", id)
)
```

### 5. Testing New Effects

```gdscript
# Test effect creation
var effect = StatusEffectMgr.create_effect("your_effect_id")
assert(effect != null, "Effect should load")
assert(effect.effect_name == "Your Effect Name")

# Test application
var dummy = CombatantState.new("test", "Test", 100, 100)
dummy.apply_status_effect(effect)
assert(dummy.find_status_effect("your_effect_id") != null)

# Test behavior (if applicable)
if effect.has_meta("behavior"):
	var behavior = effect.get_meta("behavior")
	# Test behavior methods...
```

---

## File Locations

- Effect definitions: `data/status_effects/*.json`
- Effect behaviors: `scripts/effects/*.gd`
- Effect manager: `scripts/autoload/StatusEffectMgr.gd`
- Base behavior class: `scripts/models/EffectBehavior.gd`

---

## Additional Resources

- [CONTRIBUTING_SKILLS.md](CONTRIBUTING_SKILLS.md) - General skills guide
- `scripts/models/StatusEffect.gd` - Effect data model
- `scripts/models/CombatantState.gd` - How effects are processed
- `scripts/autoload/CombatMgr.gd` - Combat lifecycle

For questions, see the main README.md.
