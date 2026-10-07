class_name PauseMenu
extends CanvasLayer

signal resume_requested
signal restart_requested
signal menu_requested

@onready var _resume_button: Button = $Root/Center/VBox/ResumeButton
@onready var _restart_button: Button = $Root/Center/VBox/RestartButton
@onready var _menu_button: Button = $Root/Center/VBox/MenuButton


func _ready() -> void:
	_resume_button.pressed.connect(resume_requested.emit)
	_restart_button.pressed.connect(restart_requested.emit)
	_menu_button.pressed.connect(menu_requested.emit)
	visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed() -> void:
	if visible:
		_resume_button.grab_focus()
