extends Node

# --- SIMULATION SIGNALS ---
# Fired whenever the simulation advances by one tick
@warning_ignore("unused_signal")
signal simulation_stepped(tick: int)

# Fired when the simulation is reset to tick 0
@warning_ignore("unused_signal")
signal simulation_reset

# --- UI / SELECTION SIGNALS ---
# Fired when the user selects different agents (Optional migration later)
# signal agent_selection_changed(agents: Array)

# --- UI / TOOL SIGNALS (Added) ---
@warning_ignore("unused_signal")
signal active_tool_changed(tool_id: int)
@warning_ignore("unused_signal")
signal status_message_changed(message: String)
@warning_ignore("unused_signal")
signal agent_selection_changed(agents: Array) # Moving towards global selection
