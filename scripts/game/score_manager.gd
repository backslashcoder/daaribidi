class_name ScoreManager
extends Node
## SCORE = distance travelled + coffee bonuses. Also owns the saved best score
## (a small local file; no backend).

signal score_changed(score: int)
signal coffee_changed(count: int)

const SAVE_PATH: String = "user://daari_bidi_save.cfg"
const OLD_SAVE_PATH: String = "user://traffic_exe_save.cfg"  ## Game was called Traffic.exe before.

@export var player: PlayerController
@export var points_per_meter: float = 1.0
@export var coffee_bonus: int = 50

var score: int = 0
var coffee_count: int = 0
var best_score: int = 0

var _running: bool = false
var _start_z: float = 0.0
var _bonus_points: int = 0


func _ready() -> void:
	_load_best()
	player.collected.connect(_on_player_collected)


func _process(_delta: float) -> void:
	if not _running:
		return
	var distance: float = maxf(0.0, _start_z - player.global_position.z)
	var new_score: int = int(distance * points_per_meter) + _bonus_points
	if new_score != score:
		score = new_score
		score_changed.emit(score)


func start_run() -> void:
	_running = true
	_start_z = player.global_position.z
	score_changed.emit(score)
	coffee_changed.emit(coffee_count)


## Ends scoring. Returns true if this run beat the previous best.
func stop_run() -> bool:
	_process(0.0)
	_running = false
	var is_new_best: bool = score > best_score
	if is_new_best:
		best_score = score
		_save_best()
	return is_new_best


func _on_player_collected(collectible: Collectible) -> void:
	if not _running:
		return
	coffee_count += 1
	_bonus_points += collectible.score_value
	collectible.collect()
	coffee_changed.emit(coffee_count)


func _load_best() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		config.load(OLD_SAVE_PATH)  # Keep a best score earned under the old name.
	best_score = int(config.get_value("scores", "best", 0))


func _save_best() -> void:
	var config := ConfigFile.new()
	config.set_value("scores", "best", best_score)
	config.save(SAVE_PATH)
