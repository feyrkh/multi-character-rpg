# CombatReport.gd
# Records the outcome and statistics of a combat encounter
class_name CombatReport
extends RefCounted

enum Outcome { WIN, LOSS, FLED }

var outcome: Outcome = Outcome.WIN
var damage_dealt: int = 0
var damage_received: int = 0
var turns_taken: int = 0
var enemy_name: String = ""

func get_outcome_string() -> String:
	match outcome:
		Outcome.WIN:
			return "Victory"
		Outcome.LOSS:
			return "Defeat"
		Outcome.FLED:
			return "Fled"
	return "Unknown"

func get_summary() -> String:
	return "%s against %s after %d turns. Dealt %d damage, received %d damage." % [
		get_outcome_string(),
		enemy_name,
		turns_taken,
		damage_dealt,
		damage_received
	]

func to_dict() -> Dictionary:
	return {
		"outcome": outcome,
		"damage_dealt": damage_dealt,
		"damage_received": damage_received,
		"turns_taken": turns_taken,
		"enemy_name": enemy_name
	}

static func from_dict(dict: Dictionary) -> CombatReport:
	var report = CombatReport.new()
	report.outcome = dict.get("outcome", Outcome.WIN)
	report.damage_dealt = dict.get("damage_dealt", 0)
	report.damage_received = dict.get("damage_received", 0)
	report.turns_taken = dict.get("turns_taken", 0)
	report.enemy_name = dict.get("enemy_name", "")
	return report
