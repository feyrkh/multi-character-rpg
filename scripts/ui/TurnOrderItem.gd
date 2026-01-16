# TurnOrderItem.gd
# Displays a single combatant in the turn order queue
extends PanelContainer

@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var action_label: Label = $VBoxContainer/ActionLabel
@onready var speed_label: Label = $VBoxContainer/SpeedLabel

func set_combatant(combatant: CharacterCombatant, action_number: int) -> void:
	name_label.text = combatant.display_name
	speed_label.text = "Speed: %d" % combatant.speed

	# Get the actual action name from the combatant's form
	var action_name = "No Action"
	if combatant.selected_form and action_number > 0 and action_number <= combatant.get_action_count():
		var action_index = action_number - 1  # Convert to 0-based index
		var action = combatant.selected_form.actions[action_index]
		action_name = action.get_action_name()

	action_label.text = action_name

	# Color-code by team
	if combatant.is_enemy:
		modulate = Color(1.0, 0.7, 0.7, 1.0)  # Reddish tint for enemies
	else:
		modulate = Color(0.7, 0.7, 1.0, 1.0)  # Bluish tint for party

func set_current(is_current: bool) -> void:
	if is_current:
		# Highlight the currently acting combatant
		modulate = Color(1.2, 1.2, 0.8, 1.0)  # Yellow highlight
