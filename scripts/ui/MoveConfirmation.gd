# MoveConfirmation.gd
# Dialog for confirming travel between locations
extends Control

@onready var message_label: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/MessageLabel
@onready var days_label: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/DaysLabel
@onready var confirm_button: Button = $CenterContainer/Panel/MarginContainer/VBoxContainer/ButtonContainer/ConfirmButton
@onready var cancel_button: Button = $CenterContainer/Panel/MarginContainer/VBoxContainer/ButtonContainer/CancelButton

func _ready() -> void:
	confirm_button.pressed.connect(_on_confirm_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	LocationMgr.move_requested.connect(_on_move_requested)
	hide()

func _on_move_requested(party: Party, path_points: Array, total_distance: int, target_location_id: String) -> void:
	var target_location = LocationMgr.get_location(target_location_id)
	if target_location:
		message_label.text = "Travel to %s?" % target_location.display_name
	else:
		message_label.text = "Travel to this location?"

	if total_distance == 1:
		days_label.text = "This will take 1 day."
	else:
		days_label.text = "This will take %d days." % total_distance

	show()

func _on_confirm_pressed() -> void:
	LocationMgr.confirm_move()
	hide()

func _on_cancel_pressed() -> void:
	LocationMgr.cancel_move()
	hide()
