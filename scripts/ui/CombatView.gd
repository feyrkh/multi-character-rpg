# CombatView.gd
# UI for turn-based combat
extends Control

signal combat_finished(report: CombatReport)

const CharacterPanel = preload("res://scenes/ui/character_panel.tscn")
const TurnOrderItem = preload("res://scenes/ui/turn_order_item.tscn")

# Track panels by combatant_id
var _character_panels: Dictionary = {}  # Party panels
var _enemy_panels: Dictionary = {}  # Enemy panels
var _selected_combatant_id: String = ""

@onready var turn_order_queue: HBoxContainer = $MarginContainer/VBoxContainer/TurnOrderPanel/VBoxContainer/TurnOrderQueue
@onready var enemy_panel: PanelContainer = $MarginContainer/VBoxContainer/BattleArea/EnemyPanel
@onready var enemies_container: VBoxContainer = $MarginContainer/VBoxContainer/BattleArea/EnemyPanel/VBoxContainer/EnemiesContainer

@onready var party_panel: PanelContainer = $MarginContainer/VBoxContainer/BattleArea/PartyPanel
@onready var characters_container: VBoxContainer = $MarginContainer/VBoxContainer/BattleArea/PartyPanel/VBoxContainer/CharactersContainer

@onready var combat_log: RichTextLabel = $MarginContainer/VBoxContainer/BattleArea/CombatLogPanel/CombatLog

@onready var command_bar: HBoxContainer = $MarginContainer/VBoxContainer/CommandBar
@onready var form_selector: OptionButton = $MarginContainer/VBoxContainer/CommandBar/FormSelector
@onready var attack_button: Button = $MarginContainer/VBoxContainer/CommandBar/AttackButton
@onready var flee_button: Button = $MarginContainer/VBoxContainer/CommandBar/FleeButton
@onready var turn_label: Label = $MarginContainer/VBoxContainer/CommandBar/TurnLabel

# Speed control UI (optional - add to scene if available)
@onready var speed_selector: OptionButton = $MarginContainer/VBoxContainer/CommandBar/SpeedControls/SpeedSelector if has_node("MarginContainer/VBoxContainer/CommandBar/SpeedControls/SpeedSelector") else null
@onready var next_step_button: Button = $MarginContainer/VBoxContainer/CommandBar/SpeedControls/NextStepButton if has_node("MarginContainer/VBoxContainer/CommandBar/SpeedControls/NextStepButton") else null

var _current_enemy: Enemy = null

func _ready() -> void:
	attack_button.pressed.connect(_on_attack_pressed)
	flee_button.pressed.connect(_on_flee_pressed)
	form_selector.item_selected.connect(_on_form_selected)

	CombatMgr.combat_started.connect(_on_combat_started)
	CombatMgr.action_executed.connect(_on_action_executed)
	CombatMgr.turn_started.connect(_on_turn_started)
	CombatMgr.combat_ended.connect(_on_combat_ended)

	# Connect lifecycle signals for enhanced logging and turn order updates
	CombatMgr.character_move_finished.connect(_on_character_move_finished)
	CombatMgr.status_effect_applied.connect(_on_status_effect_applied)
	CombatMgr.damage_dealt.connect(_on_damage_dealt)
	CombatMgr.healing_applied.connect(_on_healing_applied)

	# Setup speed controls if available
	if speed_selector:
		speed_selector.item_selected.connect(_on_speed_selected)
		speed_selector.add_item("Manual", CombatMgr.CombatSpeed.MANUAL)
		speed_selector.add_item("Slow", CombatMgr.CombatSpeed.SLOW)
		speed_selector.add_item("Normal", CombatMgr.CombatSpeed.NORMAL)
		speed_selector.add_item("Fast", CombatMgr.CombatSpeed.FAST)
		speed_selector.add_item("Very Fast", CombatMgr.CombatSpeed.VERY_FAST)
		speed_selector.select(2)  # Default to Normal

	if next_step_button:
		next_step_button.pressed.connect(_on_next_step_pressed)
		next_step_button.hide()

	hide()

func start_combat(party: Party, enemies) -> void:
	# Normalize to array
	var enemy_array = []
	if enemies is Enemy:
		enemy_array = [enemies]
	elif enemies is Array:
		enemy_array = enemies
	else:
		push_error("Invalid enemies parameter")
		return

	# Store first enemy for legacy compatibility
	_current_enemy = enemy_array[0] if enemy_array.size() > 0 else null

	combat_log.clear()

	# Create combat log message
	if enemy_array.size() == 1:
		_log_message("Combat begins against " + enemy_array[0].enemy_name + "!")
	else:
		var names = []
		for e in enemy_array:
			names.append(e.enemy_name)
		_log_message("Combat begins against " + ", ".join(names) + "!")

	# Convert enemies to combat data array
	var enemy_data_array = []
	for e in enemy_array:
		enemy_data_array.append(e.to_combat_data())

	# Start combat in CombatMgr
	CombatMgr.start_combat(party, enemy_data_array)
	CombatMgr.set_enemy_object(enemy_array[0])  # Set first enemy as primary for form selection

	# Form selector will be populated when first character is auto-selected in _on_combat_started()

	show()

func _populate_forms() -> void:
	# Legacy method - kept for backward compatibility
	# For per-character selection, use _populate_forms_for_character() instead
	form_selector.clear()
	var forms = CombatMgr.get_available_forms()
	for i in range(forms.size()):
		form_selector.add_item(forms[i].form_name, i)

func _populate_forms_for_character(combatant_id: String) -> void:
	form_selector.clear()
	# Pass combatant_id to filter forms for this character only
	var forms = CombatMgr.get_available_forms(combatant_id)

	# Get the combatant to check current selected form
	var combatant = CombatMgr.get_combatant_by_id(combatant_id)
	var current_form_index = -1

	for i in range(forms.size()):
		form_selector.add_item(forms[i].form_name, i)
		if combatant and combatant.selected_form and combatant.selected_form.form_name == forms[i].form_name:
			current_form_index = i

	# Select the character's current form if they have one
	if current_form_index >= 0:
		form_selector.select(current_form_index)
	elif forms.size() > 0:
		form_selector.select(0)

func _update_form_displays() -> void:
	# Update all character panels to show their selected forms
	for combatant in CombatMgr.party_combatants:
		if _character_panels.has(combatant.combatant_id):
			var panel = _character_panels[combatant.combatant_id]
			panel.update_display(combatant)

func _update_execute_button_state() -> void:
	# Enable execute button only if all characters have selected forms
	attack_button.disabled = not CombatMgr.are_all_forms_selected()

func _update_turn_order_display() -> void:
	# Clear existing turn order items
	for child in turn_order_queue.get_children():
		child.queue_free()

	# Get turn order from CombatMgr
	var turn_order = CombatMgr.get_turn_order()

	# Limit display to first 8 actions to avoid overflow
	var display_limit = min(8, turn_order.size())

	for i in range(display_limit):
		var entry = turn_order[i]
		var item = TurnOrderItem.instantiate()
		turn_order_queue.add_child(item)
		item.set_combatant(entry.combatant, entry.action_number)

		# Highlight the first action (next to execute)
		if i == 0:
			item.set_current(true)

func _on_combat_started(_party: Party, _enemy_data) -> void:
	_create_character_panels()
	_create_enemy_panels()
	_update_hp_displays()
	_update_execute_button_state()
	_update_turn_order_display()
	turn_label.text = "Turn 1"

func _on_character_selected(combatant_id: String) -> void:
	_select_character(combatant_id)

func _select_character(combatant_id: String) -> void:
	_selected_combatant_id = combatant_id

	# Update all panels to show selection state
	for id in _character_panels:
		var panel = _character_panels[id]
		panel.set_selected(id == combatant_id)

	# Update form selector to show current character's available forms
	_populate_forms_for_character(combatant_id)

	# Auto-select first form if character has no form selected yet
	var combatant = CombatMgr.get_combatant_by_id(combatant_id)
	if combatant and not combatant.selected_form:
		var forms = CombatMgr.get_available_forms(combatant_id)
		if forms.size() > 0:
			CombatMgr.select_form_for_combatant(combatant_id, forms[0])
			_update_form_displays()
			_update_execute_button_state()
			_update_turn_order_display()

func _on_form_selected(index: int) -> void:
	if _selected_combatant_id.is_empty():
		return

	# Get forms filtered for this specific character
	var forms = CombatMgr.get_available_forms(_selected_combatant_id)
	if index >= 0 and index < forms.size():
		# Assign form to selected character only
		CombatMgr.select_form_for_combatant(_selected_combatant_id, forms[index])
		_update_form_displays()
		_update_execute_button_state()
		_update_turn_order_display()

func _on_attack_pressed() -> void:
	if CombatMgr.state == CombatMgr.CombatState.SELECTING_FORM:
		CombatMgr.execute_turn()
		_update_hp_displays()

		# After turn execution, re-select the first character for next round
		if CombatMgr.state == CombatMgr.CombatState.SELECTING_FORM:
			# Clear all form selections for new round
			_update_form_displays()
			_update_execute_button_state()

			# Re-select first character
			if CombatMgr.party_combatants.size() > 0:
				_select_character(CombatMgr.party_combatants[0].combatant_id)

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
	_update_turn_order_display()

func _on_character_move_finished(_combatant_id: String, _action, _results: Dictionary) -> void:
	# Update turn order display after each action completes
	_update_turn_order_display()

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

func _create_panels(combatants: Array, container: Node, panel_dict: Dictionary, is_enemy: bool) -> String:
	"""Generic panel creation for combatants. Returns first combatant_id for party."""
	# Clear existing panels
	for child in container.get_children():
		child.queue_free()
	panel_dict.clear()

	var first_combatant_id = ""
	for combatant in combatants:
		var panel = CharacterPanel.instantiate()
		container.add_child(panel)
		panel.set_combatant(combatant)

		if is_enemy:
			# Enemies don't need select buttons, hide them
			if panel.has_node("VBoxContainer/HBoxContainer/SelectButton"):
				panel.get_node("VBoxContainer/HBoxContainer/SelectButton").hide()
		else:
			# Party panels connect selection signal
			panel.character_selected.connect(_on_character_selected)
			if first_combatant_id.is_empty():
				first_combatant_id = combatant.combatant_id

		panel_dict[combatant.combatant_id] = panel

	return first_combatant_id

func _create_character_panels() -> void:
	var first_id = _create_panels(CombatMgr.party_combatants, characters_container, _character_panels, false)
	# Auto-select first character
	if not first_id.is_empty():
		_select_character(first_id)

func _create_enemy_panels() -> void:
	_create_panels(CombatMgr.enemy_combatants, enemies_container, _enemy_panels, true)

func _update_hp_displays() -> void:
	# Update each character panel
	for combatant in CombatMgr.party_combatants:
		if _character_panels.has(combatant.combatant_id):
			var panel = _character_panels[combatant.combatant_id]
			panel.update_display(combatant)

	# Update each enemy panel
	for combatant in CombatMgr.enemy_combatants:
		if _enemy_panels.has(combatant.combatant_id):
			var panel = _enemy_panels[combatant.combatant_id]
			panel.update_display(combatant)

func _log_message(text: String) -> void:
	combat_log.append_text(text + "\n")

# Speed control handlers
func _on_speed_selected(index: int) -> void:
	if speed_selector:
		var speed = speed_selector.get_item_id(index)
		CombatMgr.set_combat_speed(speed)
		if next_step_button:
			next_step_button.visible = (speed == CombatMgr.CombatSpeed.MANUAL)

func _on_next_step_pressed() -> void:
	CombatMgr.advance_manual_step()

# Enhanced lifecycle signal handlers
func _on_status_effect_applied(combatant_id: String, effect: StatusEffect) -> void:
	var target_name = _get_combatant_name(combatant_id)
	_log_message("%s gained %s (x%d stacks)" % [target_name, effect.effect_name, effect.stacks])
	_update_hp_displays()

func _on_damage_dealt(source_id: String, target_id: String, damage: int, actual_damage: int) -> void:
	var source_name = _get_combatant_name(source_id)
	var target_name = _get_combatant_name(target_id)

	if actual_damage < damage:
		var reduction = damage - actual_damage
		_log_message("%s attacks %s for %d damage (%d reduced)" % [source_name, target_name, actual_damage, reduction])
	else:
		_log_message("%s attacks %s for %d damage" % [source_name, target_name, actual_damage])
	_update_hp_displays()

func _on_healing_applied(target_id: String, amount: int, actual_healing: int) -> void:
	var target_name = _get_combatant_name(target_id)
	_log_message("%s healed for %d HP" % [target_name, actual_healing])
	_update_hp_displays()

func _get_combatant_name(combatant_id: String) -> String:
	# Legacy support
	if combatant_id == "party":
		return "Party"
	elif combatant_id == "enemy":
		return _current_enemy.enemy_name if _current_enemy else "Enemy"
	elif combatant_id == "status":
		return "Status Effect"

	# Look up individual combatants
	for combatant in CombatMgr.party_combatants:
		if combatant.combatant_id == combatant_id:
			return combatant.display_name

	for combatant in CombatMgr.enemy_combatants:
		if combatant.combatant_id == combatant_id:
			return combatant.display_name

	# Fallback to ID
	return combatant_id
