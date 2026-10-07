class_name GameFlow
extends Node
## The whole game state machine in one small readable file:
##   MAIN_MENU -> PLAYING <-> PAUSED, PLAYING -> GAME_OVER -> (restart | menu)
## Everything else just reacts to what this tells it.

enum State { MAIN_MENU, PLAYING, PAUSED, GAME_OVER }

## Restarting reloads the scene, which forgets everything, so this one flag
## survives the reload to say "skip the menu this time".
static var skip_menu_on_load: bool = false

@export var player: PlayerController
@export var camera: CameraController
@export var score_manager: ScoreManager
@export var difficulty: Difficulty
@export var traffic_spawner: TrafficSpawner
@export var animal_spawner: AnimalSpawner
@export var audio: AudioManager
@export var hud: HUD
@export var main_menu: MainMenu
@export var pause_menu: PauseMenu
@export var game_over: GameOver
@export var game_over_delay: float = 0.6  ## Lets the impact effect play first.

var state: State = State.MAIN_MENU


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Must keep listening while paused.
	main_menu.start_requested.connect(_on_start_requested)
	hud.pause_requested.connect(_pause)
	pause_menu.resume_requested.connect(_resume)
	pause_menu.restart_requested.connect(_restart)
	pause_menu.menu_requested.connect(_go_to_menu)
	game_over.restart_requested.connect(_restart)
	game_over.menu_requested.connect(_go_to_menu)
	player.crashed.connect(_on_player_crashed)

	main_menu.set_best_score(score_manager.best_score)
	if skip_menu_on_load:
		skip_menu_on_load = false
		_start_run()
	else:
		camera.set_menu_mode(true, 0.0)
		_show_only(main_menu)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if state == State.PLAYING:
			_pause()
		elif state == State.PAUSED:
			_resume()


func _start_run() -> void:
	state = State.PLAYING
	camera.set_menu_mode(false, 1.2)
	_show_only(hud)
	player.set_running(true)
	score_manager.start_run()
	difficulty.start_run()
	traffic_spawner.enabled = true
	animal_spawner.enabled = true
	audio.start_ambience()


func _pause() -> void:
	if state != State.PLAYING:
		return
	audio.play("click")
	state = State.PAUSED
	get_tree().paused = true
	pause_menu.show()


func _resume() -> void:
	audio.play("click")
	state = State.PLAYING
	get_tree().paused = false
	pause_menu.hide()


func _on_player_crashed(obstacle: Node) -> void:
	state = State.GAME_OVER
	traffic_spawner.enabled = false
	animal_spawner.enabled = false
	difficulty.enabled = false
	audio.stop_ambience()
	var is_new_best: bool = score_manager.stop_run()
	await get_tree().create_timer(game_over_delay).timeout
	hud.hide()
	game_over.show_result(str(obstacle.get("display_name")), score_manager.score,
			score_manager.best_score, score_manager.coffee_count, is_new_best)


func _on_start_requested() -> void:
	audio.play("click")
	_start_run()


func _restart() -> void:
	audio.play("click")
	skip_menu_on_load = true
	_reload()


func _go_to_menu() -> void:
	audio.play("click")
	skip_menu_on_load = false
	_reload()


func _reload() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


## Shows one UI layer and hides the others.
func _show_only(layer: CanvasLayer) -> void:
	for ui: CanvasLayer in [main_menu, hud, pause_menu, game_over]:
		ui.visible = ui == layer
