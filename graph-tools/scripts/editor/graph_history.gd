class_name GraphHistory
extends RefCounted

# --- DATA ---
var _undo_stack: Array[GraphCommand] = []
var _redo_stack: Array[GraphCommand] = []
var _active_transaction: CmdBatch = null

# --- REFERENCES ---
# We need the graph to create new Batches
var _graph: Graph 

func _init(graph: Graph) -> void:
	_graph = graph

# ==============================================================================
# 1. TRANSACTION MANAGEMENT
# ==============================================================================

func start_transaction(name: String, refocus_camera: bool = true) -> void:
	# Respect the Atomic User Setting
	if GraphSettings.USE_ATOMIC_UNDO:
		return

	if _active_transaction != null:
		push_warning("GraphHistory: Transaction overlap. Ignoring start request for '%s'." % name)
		return
		
	_active_transaction = CmdBatch.new(_graph, name, refocus_camera)
	print("Transaction Started: ", name)

func commit_transaction() -> GraphCommand:
	# If atomic mode was on, or no transaction started, do nothing.
	if _active_transaction == null:
		return null
		
	var result_batch = null
	
	# Only push if we actually did something
	if not _active_transaction._commands.is_empty():
		_push_to_stack(_active_transaction)
		result_batch = _active_transaction
		print("Transaction Committed: %s" % result_batch.get_name())
	
	_active_transaction = null
	return result_batch

# ==============================================================================
# 2. COMMAND EXECUTION
# ==============================================================================

func add_command(cmd: GraphCommand) -> void:
	# 1. Execute immediately (Visual feedback)
	cmd.execute()
	
	# 2. DECIDE: Transaction or Stack?
	if _active_transaction != null:
		# We are in a transaction -> Add to the batch
		_active_transaction.add_command(cmd)
	else:
		# Standard atomic behavior -> Add to stack
		_push_to_stack(cmd)

func _push_to_stack(cmd: GraphCommand) -> void:
	_undo_stack.append(cmd)
	_redo_stack.clear()
	
	if _undo_stack.size() > GraphSettings.MAX_HISTORY_STEPS:
		_undo_stack.pop_front()

# ==============================================================================
# 3. UNDO / REDO OPERATIONS
# ==============================================================================

# Returns the command that was just undone (so the Editor can update UI/Camera)
func undo() -> GraphCommand:
	if _undo_stack.is_empty():
		return null
		
	var cmd = _undo_stack.pop_back()
	cmd.undo()
	_redo_stack.append(cmd)
	return cmd

# Returns the command that was just redone
func redo() -> GraphCommand:
	if _redo_stack.is_empty():
		return null
		
	var cmd = _redo_stack.pop_back()
	cmd.execute()
	_undo_stack.append(cmd)
	return cmd

# ==============================================================================
# 4. UTILITY
# ==============================================================================

func clear() -> void:
	_undo_stack.clear()
	_redo_stack.clear()
	_active_transaction = null
