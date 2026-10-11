extends Node
## Relógio do jogo. Um dia vai de day_start até day_end (passa da meia-noite).
## O tempo para quando a árvore é pausada (menus).

signal minute_passed(minutes: int)

var day: int = 1
var minute: float = 360.0
var running: bool = false

var _sec_per_min: float = 0.7
var _day_end: int = 1560
var _day_start: int = 360
var _last_whole: int = 360
var _exhaustion_fired := false


func _ready() -> void:
	var t: Dictionary = DataManager.game.get("time", {})
	_sec_per_min = float(t.get("real_seconds_per_game_minute", 0.7))
	_day_end = int(t.get("day_end_minute", 1560))
	_day_start = int(t.get("day_start_minute", 360))


func reset() -> void:
	day = 1
	minute = _day_start
	_last_whole = int(minute)
	_exhaustion_fired = false


func _process(delta: float) -> void:
	if not running:
		return
	minute += delta / _sec_per_min
	var whole := int(minute)
	if whole != _last_whole:
		var passed := whole - _last_whole
		_last_whole = whole
		minute_passed.emit(passed)
		if (GameState.location == "mine" or is_night()) and GameState.lantern_on:
			HealthSystem.drain_battery(passed)
		EventBus.time_changed.emit(day, whole)
	if minute >= day_end() and not _exhaustion_fired:
		_exhaustion_fired = true
		EventBus.player_passed_out.emit("time")


## Avança para a manhã seguinte. Retorna quantos minutos foram pulados.
func sleep() -> int:
	var wake := int(DataManager.game.get("time", {}).get("sleep_wake_minute", 360))
	var skipped := int(1440.0 + wake - minute)
	day += 1
	minute = wake
	_last_whole = wake
	_exhaustion_fired = false
	minute_passed.emit(skipped)
	EventBus.day_started.emit(day)
	EventBus.time_changed.emit(day, wake)
	return skipped


func day_end() -> float:
	return _day_end + float(UpgradeSystem.get_stat("late_minutes", 0))


func clock_minute() -> int:
	return int(minute) % 1440


func time_string() -> String:
	var m := clock_minute()
	return "%02d:%02d" % [m / 60, m % 60]


const MONTHS := ["JAN", "FEV", "MAR", "ABR", "MAI", "JUN", "JUL", "AGO", "SET", "OUT", "NOV", "DEZ"]
const START_UNIX := 515030400  # 28/04/1986 00:00 UTC — dia 1 do jogo


## Data no calendário de 1986 (dia 1 = 28 de abril de 1986).
func date_dict() -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(START_UNIX + (day - 1) * 86400)


func date_string() -> String:
	var d := date_dict()
	return "%02d %s %d" % [d.day, MONTHS[d.month - 1], d.year]


## Minuto absoluto desde o início do jogo (para efeitos com duração).
func absolute_minute() -> float:
	return day * 1440.0 + minute


func is_night() -> bool:
	var m := clock_minute()
	return m >= 1200 or m < 330


func minutes_left_in_day() -> int:
	return int(day_end() - minute)


func get_save_data() -> Dictionary:
	return {"day": day, "minute": minute}


func load_save_data(d: Dictionary) -> void:
	day = int(d.get("day", 1))
	minute = float(d.get("minute", _day_start))
	_last_whole = int(minute)
	_exhaustion_fired = minute >= day_end()
