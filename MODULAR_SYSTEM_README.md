# Modular Status Effects System - Quick Reference

## Overview

The combat system now supports **dynamically loaded status effects** through JSON definitions and optional GDScript behavior scripts. This allows you to add new effects without modifying core code.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    StatusEffectMgr                          │
│                   (Autoload Singleton)                      │
│                                                             │
│  • Scans data/status_effects/*.json                        │
│  • Scans scripts/effects/*.gd                              │
│  • Creates effects with attached behaviors                 │
│  • Caches loaded effects                                   │
└─────────────────────────────────────────────────────────────┘
							│
							▼
		┌───────────────────────────────────────┐
		│         StatusEffect (Data)           │
		│  • effect_type, strength, stacks      │
		│  • decay_type, triggers               │
		│  • Has optional "behavior" meta       │
		└───────────────────────────────────────┘
							│
							▼
		┌───────────────────────────────────────┐
		│   EffectBehavior (Custom Logic)       │
		│  • on_apply(), on_remove()            │
		│  • on_attacking(), on_attacked()      │
		│  • on_round_start(), on_round_end()   │
		│  • calculate_damage_reduction()       │
		└───────────────────────────────────────┘
```

## Two Ways to Create Effects

### 1. JSON Only (Standard Effects)

For simple effects using existing types:

```json
// data/status_effects/poison.json
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

**Usage:**
```gdscript
var poison = StatusEffectMgr.create_effect("poison")
target.apply_status_effect(poison)
```

### 2. JSON + Behavior Script (Complex Effects)

For effects needing custom logic:

**JSON:** `data/status_effects/vampire_aura.json`
```json
{
	"name": "Vampire Aura",
	"description": "Heal for 25% of damage dealt",
	"effect_type": 3,
	"strength": 25.0,
	"triggers": ["WHEN_ATTACKING"]
}
```

**Behavior:** `scripts/effects/vampire_aura.gd`
```gdscript
extends EffectBehavior

func on_attacking(target: CombatantState, victim: CombatantState, damage: int) -> int:
	var heal = int(damage * (get_strength() / 100.0))
	target.heal(heal)
	return damage
```

**Usage:** (Same - behavior auto-attached)
```gdscript
var vampire = StatusEffectMgr.create_effect("vampire_aura")
fighter.apply_status_effect(vampire)
```

## File Locations

| Type | Location | Example |
|------|----------|---------|
| Effect Definitions | `data/status_effects/*.json` | `poison.json`, `regeneration.json` |
| Effect Behaviors | `scripts/effects/*.gd` | `vampire_aura.gd`, `thorns.gd` |
| Effect Manager | `scripts/autoload/StatusEffectMgr.gd` | (Autoload) |
| Base Behavior | `scripts/models/EffectBehavior.gd` | (Base class) |

## Enum Reference

### Effect Types
```
0 = DEFENSE           - Reduces damage
1 = DAMAGE_OVER_TIME  - Deals damage (poison, burn)
2 = HEAL_OVER_TIME    - Heals (regeneration)
3 = STAT_MODIFIER     - Custom (use with behavior)
```

### Defense Types (for DEFENSE)
```
0 = PERCENT_REDUCTION_STACKING     - 15% × 3 stacks = 45%
1 = PERCENT_REDUCTION_NONSTACKING  - Flat 20% always
2 = FLAT_REDUCTION                 - Absorb X damage
```

### Decay Types
```
0 = NONE                  - Never decays
1 = STACKS_AT_ROUND_END   - All stacks removed
2 = ONE_AT_ROUND_END      - -1 stack per round
3 = DURATION_ROUNDS       - Countdown duration
```

### Trigger Events
```
ROUND_START       ROUND_END
BEFORE_MOVE       AFTER_MOVE
WHEN_ATTACKED     WHEN_ATTACKING
CONTINUOUS        (always active)
```

## API Quick Reference

### Creating Effects
```gdscript
# Basic creation
var effect = StatusEffectMgr.create_effect("poison")

# With parameters
var strong = StatusEffectMgr.create_effect("poison", {"strength": 10, "duration": 5})

# Check available effects
var all = StatusEffectMgr.get_available_effects()

# Check if has custom behavior
var has_script = StatusEffectMgr.has_custom_behavior("vampire_aura")
```

### Applying Effects
```gdscript
# Apply to target
target.apply_status_effect(effect, source)

# Find existing effect
var poison = target.find_status_effect("poison")

# Remove effect
target.remove_status_effect("poison")

# Clear all cleansable
target.clear_cleansable_effects()
```

### Custom Behavior Methods

Override these in `scripts/effects/your_effect.gd`:

```gdscript
extends EffectBehavior

# Lifecycle
func on_apply(target, source) -> void
func on_remove(target) -> void
func on_stack_added(target, stacks) -> void

# Combat Events
func on_attacking(target, victim, damage) -> int  # Return modified damage
func on_attacked(target, attacker, damage) -> int  # Return modified damage

# Round Events
func on_round_start(target) -> Dictionary  # {"healing": 0, "damage": 0, "messages": []}
func on_round_end(target) -> Dictionary

# Move Events
func on_before_move(target, action) -> void
func on_after_move(target, action) -> void

# Custom Calculations
func calculate_damage_reduction(target) -> Dictionary  # {"percent": 0.0, "flat": 0}
func calculate_healing(target) -> int
func calculate_damage(target) -> int

# Custom Decay
func should_remove_custom(target) -> bool
func on_decay(target) -> void

# Helpers
func get_stacks() -> int
func get_strength() -> float
func get_duration() -> int
```

## Examples Included

### JSON-Only Effects
- `fighter_defense.json` - Stacking % reduction
- `cleric_defense.json` - Non-stacking % reduction
- `poison.json` - Damage over time
- `regeneration.json` - Healing over time

### Scripted Effects
- `vampire_aura.gd` - Life steal on attack
- `thorns.gd` - Reflect damage when attacked

## Benefits

✅ **Modular** - Each effect is self-contained
✅ **No Core Edits** - Add effects without touching CombatMgr
✅ **Hot-Reloadable** - Call `StatusEffectMgr.reload_effects()`
✅ **Type-Safe** - Strongly-typed API with autocomplete
✅ **Extensible** - Simple effects use JSON, complex use scripts
✅ **Debuggable** - Override methods with print statements

## Documentation

- **[MODULAR_EFFECTS_GUIDE.md](MODULAR_EFFECTS_GUIDE.md)** - Full guide with examples
- **[CONTRIBUTING_SKILLS.md](CONTRIBUTING_SKILLS.md)** - General combat system guide
- **Source Code** - `scripts/models/EffectBehavior.gd`, `scripts/autoload/StatusEffectMgr.gd`

## Quick Start Checklist

1. ✅ **StatusEffectMgr** loaded as autoload
2. ✅ **Example JSON files** in `data/status_effects/`
3. ✅ **Example behaviors** in `scripts/effects/`
4. ✅ **EffectBehavior** base class available
5. ✅ **CombatMgr** integrated with new system
6. ✅ **Documentation** complete

## Testing Your Effect

```gdscript
# 1. Create test target
var dummy = CombatantState.new("test", "Dummy", 100, 100)

# 2. Load your effect
var effect = StatusEffectMgr.create_effect("your_effect_id")
assert(effect != null, "Effect should load")

# 3. Apply and test
dummy.apply_status_effect(effect)
var found = dummy.find_status_effect("your_effect_id")
assert(found != null, "Effect should be applied")

# 4. Test behavior (if applicable)
if effect.has_meta("behavior"):
	print("Custom behavior attached!")
```

---

**Ready to create your first effect?** See [MODULAR_EFFECTS_GUIDE.md](MODULAR_EFFECTS_GUIDE.md) for step-by-step instructions!
