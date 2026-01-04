# priority_queue.gd
class_name PriorityQueue
extends RefCounted

# Min-heap implementation for A* pathfinding
var _heap: Array = []
var _size: int = 0

func is_empty() -> bool:
	return _size == 0

func size() -> int:
	return _size

func push(item: Variant, priority: float) -> void:
	# Add to end of heap
	_heap.append({"item": item, "priority": priority})
	_size += 1
	# Bubble up
	_bubble_up(_size - 1)

func pop() -> Variant:
	if _size == 0:
		return null
	
	var result = _heap[0]["item"]
	
	# Move last element to root
	_heap[0] = _heap[_size - 1]
	_heap.pop_back()
	_size -= 1
	
	if _size > 0:
		# Bubble down
		_bubble_down(0)
	
	return result

func peek() -> Variant:
	if _size == 0:
		return null
	return _heap[0]["item"]

func peek_priority() -> float:
	if _size == 0:
		return INF
	return _heap[0]["priority"]

func update_priority(item: Variant, new_priority: float) -> bool:
	# Find the item in the heap
	for i in range(_size):
		if _heap[i]["item"] == item:
			var old_priority = _heap[i]["priority"]
			_heap[i]["priority"] = new_priority
			
			if new_priority < old_priority:
				_bubble_up(i)
			else:
				_bubble_down(i)
			return true
	return false

func contains(item: Variant) -> bool:
	for i in range(_size):
		if _heap[i]["item"] == item:
			return true
	return false

func clear() -> void:
	_heap.clear()
	_size = 0

func to_string_representation() -> String:
	var result = "PriorityQueue (size: %d): " % _size
	for i in range(min(_size, 10)):  # Show first 10 items
		result += "%s(%.2f) " % [_heap[i]["item"], _heap[i]["priority"]]
	if _size > 10:
		result += "..."
	return result

func _bubble_up(index: int) -> void:
	var current = index
	while current > 0:
		var parent = (current - 1) >> 1  # floor((current-1)/2)
		if _heap[parent]["priority"] <= _heap[current]["priority"]:
			break
		_swap(parent, current)
		current = parent

func _bubble_down(index: int) -> void:
	var current = index
	while true:
		var left = (current << 1) + 1  # 2*current + 1
		var right = (current << 1) + 2 # 2*current + 2
		var smallest = current
		
		if left < _size and _heap[left]["priority"] < _heap[smallest]["priority"]:
			smallest = left
		if right < _size and _heap[right]["priority"] < _heap[smallest]["priority"]:
			smallest = right
		
		if smallest == current:
			break
		
		_swap(current, smallest)
		current = smallest

func _swap(i: int, j: int) -> void:
	var temp = _heap[i]
	_heap[i] = _heap[j]
	_heap[j] = temp
