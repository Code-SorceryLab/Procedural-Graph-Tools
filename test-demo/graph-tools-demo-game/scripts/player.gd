class_name Player
extends CharacterBody2D

@export var speed: float = 200.0

# --- INVENTORY ---
var colored_keys: Array[String] = []
var max_tier_key: int = 0

func _physics_process(_delta: float) -> void:
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = input_dir.normalized() * speed
	move_and_slide()

# Called by Key.gd when touched
func collect_key(key_type: String) -> void:
	if key_type.begins_with("Tier "):
		var tier = key_type.trim_prefix("Tier ").to_int()
		max_tier_key = max(max_tier_key, tier)
		print("Collected Tier %d Key! (Max Tier is now %d)" % [tier, max_tier_key])
	else:
		if not colored_keys.has(key_type):
			colored_keys.append(key_type)
		print("Collected %s Key!" % key_type)

# Called by Door.gd when bumped
func can_open_door(lock_type: String) -> bool:
	if lock_type.begins_with("Tier "):
		var req_tier = lock_type.trim_prefix("Tier ").to_int()
		return max_tier_key >= req_tier
	else:
		return colored_keys.has(lock_type)
