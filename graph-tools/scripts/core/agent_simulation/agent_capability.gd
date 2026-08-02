class_name AgentCapability
extends RefCounted

# The agent that owns this tool
var agent: AgentWalker

func _init(p_agent: AgentWalker) -> void:
	agent = p_agent

# --- VIRTUAL METHODS ---

# Called when the capability is added or the agent is reset
func setup(_graph: Graph) -> void:
	pass

# Called every simulation tick (for cooldowns, passive scanning, etc.)
func tick(_delta: float) -> void:
	pass
