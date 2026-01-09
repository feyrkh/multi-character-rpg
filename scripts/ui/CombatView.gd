# CombatView.gd
# UI for turn-based combat
extends Control

signal combat_finished(report: CombatReport)

@onready var enemy_panel: PanelContainer = $MarginContainer/VBoxContainer/BattleArea/EnemyPanel
@onready var enemy_name_label: Label = $MarginContainer/VBoxContainer/BattleArea/EnemyPanel/VBoxContainer/EnemyNameLabel
@onready var enemy_hp_bar: ProgressBar = $MarginContainer/VBoxContainer/BattleArea/EnemyPanel/VBoxContainer/EnemyHPBar
@onready var enemy_hp_label: Label = $MarginContainer/VBoxContainer/BattleArea/EnemyPanel/VBoxContainer/EnemyHPLabel

@onready var party_panel: PanelContainer = $MarginContainer/VBoxContainer/BattleArea/PartyPanel
@onready var party_hp_bar: ProgressBar = $MarginContainer/VBoxContainer/BattleArea/PartyPanel/VBoxContainer/PartyHPBar
@onready var party_hp_label: Label = $MarginContainer/VBoxContainer/BattleArea/PartyPanel/VBoxContainer/PartyHPLabel

@onready var combat_log: RichTextLabel = $MarginContainer/VBoxContainer/BattleArea/CombatLogPanel/CombatLog

@onready var command_bar: HBoxContainer = $MarginContainer/VBoxContainer/CommandBar
@onready var form_selector: OptionButton = $MarginContainer/VBoxContainer/CommandBar/FormSelector
@onready var attack_button: Button = $MarginContainer/VBoxContainer/CommandBar/AttackButton
@onready var flee_button: Button = $MarginContainer/VBoxContainer/CommandBar/FleeButton
@onready var turn_label: Label = $MarginContainer/VBoxContainer/CommandBar/TurnLabel

var _current_enemy: Enemy = null

func _ready() -> void:
	attack_button.pressed.connect(_on_attack_pressed)
	flee_button.pressed.connect(_on_flee_pressed)
	form_selector.item_selected.connect(_on_form_selected)

	CombatMgr.combat_started.connect(_on_combat_started)
	CombatMgr.action_executed.connect(_on_action_executed)
	CombatMgr.turn_started.connect(_on_turn_started)
	CombatMgr.combat_ended.connect(_on_combat_ended)

	hide()

func start_combat(party: Party, enemy: Enemy) -> void:
	_current_enemy = enemy
	combat_log.clear()
	_log_message("Combat begins against " + enemy.enemy_name + "!")

	# Start combat in CombatMgr
	CombatMgr.start_combat(party, enemy.to_combat_data())
	CombatMgr.set_enemy_object(enemy)

	# Populate form selector
	_populate_forms()

	show()

func _populate_forms() -> void:
	form_selector.clear()
	var forms = CombatMgr.get_available_forms()
	for i in range(forms.size()):
		form_selector.add_item(forms[i].form_name, i)

	if forms.size() > 0:
		form_selector.select(0)
		CombatMgr.select_form(forms[0])

func _on_combat_started(_party: Party, enemy_data: Dictionary) -> void:
	enemy_name_label.text = enemy_data.get("name", "Enemy")
	_update_hp_displays()
	turn_label.text = "Turn 1"

func _on_form_selected(index: int) -> void:
	var forms = CombatMgr.get_available_forms()
	if index >= 0 and index < forms.size():
		CombatMgr.select_form(forms[index])

func _on_attack_pressed() -> void:
	if CombatMgr.state == CombatMgr.CombatState.SELECTING_FORM:
		CombatMgr.execute_turn()
		_update_hp_displays()

		# Re-select the form for the next turn (execute_turn resets selected_form)
		if CombatMgr.state == CombatMgr.CombatState.SELECTING_FORM:
			var index = form_selector.selected
			if index >= 0:
				var forms = CombatMgr.get_available_forms()
				if index < forms.size():
					CombatMgr.select_form(forms[index])

func _on_flee_pressed() -> void:
	var report = CombatMgr.flee()
	if report:
		_log_message("You fled from battle!")

func _on_action_executed(action: CombatAction, source: String, _target: String, damage: int) -> void:
	var source_name = _current_enemy.enemy_name if source == "enemy" else "Party"
	var action_name = action.get_action_name()

	if damage > 0:
		_log_message(source_name + " uses " + action_name + " for " + str(damage) + " damage!")
	else:
		_log_message(source_name + " uses " + action_name + "!")

	_update_hp_displays()

func _on_turn_started(turn_number: int) -> void:
	turn_label.text = "Turn " + str(turn_number)
	_log_message("--- Turn " + str(turn_number) + " ---")

func _on_combat_ended(report: CombatReport) -> void:
	match report.outcome:
		CombatReport.Outcome.WIN:
			_log_message("Victory! You defeated " + report.enemy_name + "!")
		CombatReport.Outcome.LOSS:
			_log_message("Defeat! Your party was defeated...")
		CombatReport.Outcome.FLED:
			_log_message("You escaped from battle.")

	# Wait a moment before closing
	await get_tree().create_timer(1.5).timeout
	hide()
	combat_finished.emit(report)

func _update_hp_displays() -> void:
	# Enemy HP
	var enemy_hp_percent = CombatMgr.get_enemy_hp_percent()
	enemy_hp_bar.value = enemy_hp_percent * 100
	enemy_hp_label.text = "HP: " + str(CombatMgr.enemy_hp) + "/" + str(CombatMgr.enemy_max_hp)

	# Party HP
	var party_hp_percent = CombatMgr.get_party_hp_percent()
	party_hp_bar.value = party_hp_percent * 100
	party_hp_label.text = "HP: " + str(CombatMgr.party_hp) + "/" + str(CombatMgr.party_max_hp)

func _log_message(text: String) -> void:
	combat_log.append_text(text + "\n")
