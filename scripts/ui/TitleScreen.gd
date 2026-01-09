# TitleScreen.gd
# Title menu with New Game, Continue, and Exit options
extends Control

signal new_game_requested()
signal continue_game_requested()
signal exit_requested()

@onready var new_game_button: Button = $CenterContainer/VBoxContainer/NewGameButton
@onready var continue_button: Button = $CenterContainer/VBoxContainer/ContinueButton
@onready var exit_button: Button = $CenterContainer/VBoxContainer/ExitButton

func _ready() -> void:
	new_game_button.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	_update_continue_button()

func _update_continue_button() -> void:
	# Disable continue if no save exists
	continue_button.disabled = not _has_save_file()

func _has_save_file() -> bool:
	return FileAccess.file_exists("user://savegame.json")

func _on_new_game_pressed() -> void:
	new_game_requested.emit()

func _on_continue_pressed() -> void:
	continue_game_requested.emit()

func _on_exit_pressed() -> void:
	exit_requested.emit()
