# CombatMgr.gd
# Manages turn-based combat encounters
extends Node

signal combat_started(party: Party, enemy_data: Dictionary)
signal form_selected(form: CombatForm)
signal turn_started(turn_number: int)
signal action_executed(action: CombatAction, source: String, target: String, damage: int)
signal combat_ended(report: CombatReport)

enum CombatState { INACTIVE, SELECTING_FORM, EXECUTING, ENEMY_TURN, RESOLVED }

var state: CombatState = CombatState.INACTIVE
var current_party: Party = null
var current_enemy: Dictionary = {}
var current_enemy_obj: Enemy = null  # The actual Enemy object with forms
var selected_form: CombatForm = null
var current_turn: int = 0

# Combat stats for the current battle
var party_hp: int = 0
var party_max_hp: int = 0
var enemy_hp: int = 0
var enemy_max_hp: int = 0
var total_damage_dealt: int = 0
var total_damage_received: int = 0

func _ready() -> void:
	pass

func is_in_combat() -> bool:
	return state != CombatState.INACTIVE

# --- Combat Initialization ---

func start_combat(party: Party, enemy_data: Dictionary) -> void:
	if state != CombatState.INACTIVE:
		push_warning("Combat already in progress")
		return

	current_party = party
	current_enemy = enemy_data
	current_enemy_obj = null  # Reset enemy object
	current_turn = 0

	# Initialize party HP from members
	party_hp = 0
	party_max_hp = 0
	var members = GameManager.get_party_members(party)
	for member in members:
		party_hp += member.stats.get("hp", 100)
		party_max_hp += member.stats.get("max_hp", 100)

	# Initialize enemy HP
	enemy_hp = enemy_data.get("hp", 100)
	enemy_max_hp = enemy_data.get("max_hp", enemy_hp)

	# Reset stats
	total_damage_dealt = 0
	total_damage_received = 0
	selected_form = null

	state = CombatState.SELECTING_FORM
	combat_started.emit(party, enemy_data)

func set_enemy_object(enemy: Enemy) -> void:
	# Set the Enemy object for form-based combat
	current_enemy_obj = enemy

# --- Form Selection ---

func get_available_forms() -> Array[CombatForm]:
	if not current_party:
		return []

	var result: Array[CombatForm] = []
	var members = GameManager.get_party_members(current_party)

	for member in members:
		for form_id in member.combat_form_ids:
			# TODO: Load forms from a form registry
			pass

	# Return a default form if none available
	if result.is_empty():
		var default_form = CombatForm.new("Basic Attack")
		default_form.description = "A simple attack"
		var attack = CombatAction.new(CombatAction.ActionType.ATTACK, 10)
		default_form.add_action(attack)
		result.append(default_form)

	return result

func select_form(form: CombatForm) -> void:
	if state != CombatState.SELECTING_FORM:
		push_error("Cannot select form in current state")
		return

	selected_form = form
	form_selected.emit(form)

func execute_turn() -> void:
	if state != CombatState.SELECTING_FORM or selected_form == null:
		push_error("Cannot execute turn: no form selected")
		return

	current_turn += 1
	turn_started.emit(current_turn)
	state = CombatState.EXECUTING

	# Execute player actions
	for action in selected_form.actions:
		var damage = _execute_action(action, "party", "enemy")
		if damage > 0:
			enemy_hp -= damage
			total_damage_dealt += damage
			action_executed.emit(action, "party", "enemy", damage)

		if enemy_hp <= 0:
			_end_combat(CombatReport.Outcome.WIN)
			return

	# Enemy turn
	state = CombatState.ENEMY_TURN
	var enemy_damage = _execute_enemy_turn()
	if enemy_damage > 0:
		party_hp -= enemy_damage
		total_damage_received += enemy_damage

		if party_hp <= 0:
			_end_combat(CombatReport.Outcome.LOSS)
			return

	# Continue combat
	selected_form = null
	state = CombatState.SELECTING_FORM

func _execute_action(action: CombatAction, source: String, target: String) -> int:
	var damage = 0
	match action.action_type:
		CombatAction.ActionType.ATTACK:
			damage = action.power
		CombatAction.ActionType.DEFEND:
			# Reduce incoming damage (handled elsewhere)
			damage = 0
		CombatAction.ActionType.SKILL:
			damage = action.power
		CombatAction.ActionType.ITEM:
			# Items might heal instead of damage
			damage = 0
	return damage

func _execute_enemy_turn() -> int:
	var total_damage = 0

	# Use enemy's combat form if available
	if current_enemy_obj != null and not current_enemy_obj.combat_forms.is_empty():
		var enemy_form = current_enemy_obj.get_random_form()
		for action in enemy_form.actions:
			var damage = _execute_action(action, "enemy", "party")
			if damage > 0:
				total_damage += damage
			action_executed.emit(action, "enemy", "party", damage)
	else:
		# Fallback: Simple enemy AI with base power
		var enemy_attack = current_enemy.get("attack", 10)
		var enemy_action = CombatAction.new(CombatAction.ActionType.ATTACK, enemy_attack)
		action_executed.emit(enemy_action, "enemy", "party", enemy_attack)
		total_damage = enemy_attack

	return total_damage

# --- Flee ---

func flee() -> CombatReport:
	if state == CombatState.INACTIVE:
		return null

	return _end_combat(CombatReport.Outcome.FLED)

# --- Combat Resolution ---

func _end_combat(outcome: CombatReport.Outcome) -> CombatReport:
	var report = CombatReport.new()
	report.outcome = outcome
	report.damage_dealt = total_damage_dealt
	report.damage_received = total_damage_received
	report.turns_taken = current_turn
	report.enemy_name = current_enemy.get("name", "Enemy")

	# Add to action log for party members
	if current_party:
		var log_description = report.get_summary()
		var members = GameManager.get_party_members(current_party)
		for member in members:
			member.add_log_entry(TimeMgr.current_month, TimeMgr.current_day, log_description)

	# Reset state
	state = CombatState.RESOLVED
	combat_ended.emit(report)

	# Clean up
	current_party = null
	current_enemy = {}
	current_enemy_obj = null
	selected_form = null
	state = CombatState.INACTIVE

	return report

# --- State Queries ---

func get_party_hp_percent() -> float:
	if party_max_hp <= 0:
		return 0.0
	return float(party_hp) / float(party_max_hp)

func get_enemy_hp_percent() -> float:
	if enemy_max_hp <= 0:
		return 0.0
	return float(enemy_hp) / float(enemy_max_hp)

func get_current_turn() -> int:
	return current_turn

func get_enemy_name() -> String:
	return current_enemy.get("name", "Enemy")
