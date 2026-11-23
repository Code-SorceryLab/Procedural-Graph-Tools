class_name GamePlayer
extends Node

@onready var level_builder: LevelImporter = $LevelBuilder
@onready var title_screen: Control = $UILayer/TitleScreen
@onready var win_screen: Control = $UILayer/WinScreen

@onready var btn_start: Button = $UILayer/TitleScreen/VBoxContainer/BtnStart
@onready var btn_exit: Button = $UILayer/TitleScreen/VBoxContainer/BtnExit
@onready var btn_restart: Button = $UILayer/WinScreen/VBoxContainer/BtnRestart

# (Optional) Expose the path here so you can easily change which map to load
@export_file("*.json") var map_to_load: String = "res://level_export.json"

func _ready() -> void:
	# Wire up the UI buttons
	btn_start.pressed.connect(_on_start_pressed)
	btn_exit.pressed.connect(_on_exit_pressed)
	btn_restart.pressed.connect(_on_restart_pressed)
	
	# --- Listen for the exit tile ---
	level_builder.level_completed.connect(win_game)
	
	# Start in the Title State
	_show_title_screen()

# --- STATE MANAGEMENT ---

func _show_title_screen() -> void:
	title_screen.show()
	win_screen.hide()
	
	# Ensure the level is empty while on the title screen
	level_builder.clear_level()

func start_game() -> void:
	title_screen.hide()
	win_screen.hide()
	
	# Trigger the importer to build the map and spawn the player
	if map_to_load != "":
		level_builder.load_and_build(map_to_load)
	else:
		push_warning("GamePlayer: No map assigned to load!")

func win_game() -> void:
	# This will be called later when the player steps on the End Point
	win_screen.show()
	
	# Optional: Pause the game when they win
	get_tree().paused = true 

# --- BUTTON HANDLERS ---

func _on_start_pressed() -> void:
	start_game()

func _on_restart_pressed() -> void:
	# Unpause if we paused upon winning
	get_tree().paused = false 
	_show_title_screen()

func _on_exit_pressed() -> void:
	get_tree().quit()
