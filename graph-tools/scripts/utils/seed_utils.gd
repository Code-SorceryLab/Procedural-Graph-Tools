class_name SeedUtils
extends RefCounted

# Generates a valid integer seed from any input (String, Int, etc.)
static func hash_seed(input: Variant) -> int:
	if typeof(input) == TYPE_STRING:
		return input.hash()
	elif typeof(input) == TYPE_INT:
		return input
	return hash(str(input))

# Creates a new, isolated RNG based on a parent RNG's state.
# This is how a Strategy safely spawns an Agent without sharing state!
static func create_child_rng(parent_rng: RandomNumberGenerator) -> RandomNumberGenerator:
	var child = RandomNumberGenerator.new()
	# Pull ONE number from the parent to seed the child
	child.seed = parent_rng.randi() 
	return child

# Replaces Godot's built-in array.pick_random() which uses the global seed
static func pick_random(array: Array, rng: RandomNumberGenerator) -> Variant:
	if array.is_empty(): 
		return null
	var idx = rng.randi_range(0, array.size() - 1)
	return array[idx]

# Shuffles an array in-place using a specific, isolated RNG
static func shuffle(array: Array, rng: RandomNumberGenerator) -> void:
	if array.size() < 2: return
	for i in range(array.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var temp = array[i]
		array[i] = array[j]
		array[j] = temp
