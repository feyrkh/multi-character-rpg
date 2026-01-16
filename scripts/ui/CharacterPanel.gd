# CharacterPanel.gd
# Displays individual character information in combat
extends PanelContainer

signal character_selected(combatant_id: String)

@onready var name_label: Label = $VBoxContainer/HBoxContainer/NameLabel
@onready var select_button: Button = $VBoxContainer/HBoxContainer/SelectButton
@onready var hp_bar: ProgressBar = $VBoxContainer/HPBar
@onready var hp_label: Label = $VBoxContainer/HPLabel
@onready var status_effects_label: Label = $VBoxContainer/StatusEffectsContainer/StatusEffects
@onready var form_label: Label = $VBoxContainer/FormLabel

var combatant_id: String = ""
var is_selected: bool = false

func _ready() -> void:
	select_button.pressed.connect(_on_select_pressed)

func _on_select_pressed() -> void:
	character_selected.emit(combatant_id)

func set_combatant(combatant: CharacterCombatant) -> void:
	combatant_id = combatant.combatant_id
	name_label.text = combatant.display_name
	update_display(combatant)

func set_selected(selected: bool) -> void:
	is_selected = selected
	if selected:
		select_button.text = "Selected"
		select_button.disabled = true
		# Highlight the panel
		modulate = Color(1.2, 1.2, 1.0, 1.0)
	else:
		select_button.text = "Select"
		select_button.disabled = false
		modulate = Color(1.0, 1.0, 1.0, 1.0)

func update_display(combatant: CharacterCombatant) -> void:
	# Update HP
	var current_hp = combatant.combatant_state.current_hp
	var max_hp = combatant.combatant_state.max_hp

	if max_hp > 0:
		hp_bar.value = (float(current_hp) / float(max_hp)) * 100.0
	else:
		hp_bar.value = 0.0

	hp_label.text = "HP: %d/%d" % [current_hp, max_hp]

	# Mark defeated characters
	if combatant.is_defeated():
		name_label.text = combatant.display_name + " (Defeated)"
		if not is_selected:
			modulate = Color(0.5, 0.5, 0.5, 1.0)
		select_button.disabled = true
	else:
		if not is_selected:
			modulate = Color(1.0, 1.0, 1.0, 1.0)
		select_button.disabled = is_selected

	# Update status effects
	var effects = combatant.combatant_state.status_effects
	if effects.is_empty():
		status_effects_label.text = "None"
	else:
		var effect_strings = []
		for effect in effects:
			var effect_str = effect.effect_name
			if effect.stacks > 1:
				effect_str += " x%d" % effect.stacks
			effect_strings.append(effect_str)
		status_effects_label.text = ", ".join(effect_strings)

	# Update form selection status
	if combatant.selected_form:
		form_label.text = "Form: %s" % combatant.selected_form.form_name
	else:
		form_label.text = "Form: Not Selected"
