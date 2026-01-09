# Manages the calendar system and time spending for characters
extends Node

signal day_changed(month: int, day: int)
signal month_changed(month: int)
signal time_spent(party: Party, days: int)

const MONTHS_PER_YEAR: int = 12
const DAYS_PER_MONTH: int = 30

var current_month: int = 1  # 1-12
var current_day: int = 1    # 1-30

func _ready() -> void:
	pass

# --- Time Spending ---

func can_spend_time(party: Party, days: int) -> bool:
	var members = GameManager.get_party_members(party)
	for member in members:
		if not member.can_spend_days(days):
			return false
	return true

func spend_time(party: Party, days: int) -> bool:
	if not can_spend_time(party, days):
		return false

	var members = GameManager.get_party_members(party)
	for member in members:
		member.spend_days(days)
	
	time_spent.emit(party, days)
	return true

func get_party_available_time(party: Party) -> int:
	# Returns the minimum available days among party members
	var members = GameManager.get_party_members(party)
	if members.is_empty():
		return 0

	var min_days = DAYS_PER_MONTH
	for member in members:
		min_days = mini(min_days, member.days_remaining)
	return min_days

func get_character_remaining_time(character: PlayableCharacter) -> int:
	return character.days_remaining

# --- Month Management ---

func advance_month() -> void:
	current_day = 1
	current_month += 1

	if current_month > MONTHS_PER_YEAR:
		current_month = 1  # Wrap to next year

	_reset_all_character_time()
	month_changed.emit(current_month)
	day_changed.emit(current_month, current_day)

func advance_day(days: int = 1) -> void:
	for i in range(days):
		current_day += 1
		if current_day > DAYS_PER_MONTH:
			advance_month()
			return
		day_changed.emit(current_month, current_day)

func _reset_all_character_time() -> void:
	var characters = GameManager.get_all_characters()
	for character in characters:
		character.reset_days()

# --- Save/Load State ---

func get_state() -> Dictionary:
	return {
		"current_month": current_month,
		"current_day": current_day
	}

func load_state(state: Dictionary) -> void:
	current_month = state.get("current_month", 1)
	current_day = state.get("current_day", 1)

func reset() -> void:
	current_month = 1
	current_day = 1
	day_changed.emit(current_month, current_day)
