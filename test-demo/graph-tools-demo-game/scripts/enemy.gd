class_name Enemy
extends CharacterBody2D

@export var move_speed: float = 50.0
var wander_dir: Vector2 = Vector2.ZERO
var is_on_screen: bool = false

func _ready() -> void:
	$Timer.timeout.connect(_on_timer_timeout)
	$VisibleOnScreenNotifier2D.screen_entered.connect(func(): is_on_screen = true)
	$VisibleOnScreenNotifier2D.screen_exited.connect(func(): is_on_screen = false)

func _on_timer_timeout() -> void:
	if is_on_screen:
		# Pick a random direction
		wander_dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	else:
		# Stop moving if off-screen
		wander_dir = Vector2.ZERO

func _physics_process(_delta: float) -> void:
	if is_on_screen:
		velocity = wander_dir * move_speed
		move_and_slide()
