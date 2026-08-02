class_name BuoyancyEngine
extends RefCounted

# Physics Settings
var damping: float = 0.85       # Friction (1.0 = ice, 0.0 = glue)
var max_velocity: float = 20.0  # Speed limit per frame to prevent explosions
var repulsion_multiplier: float = 1500.0 # Global scale for the repulsion math

# Internal State: Tracks velocity vectors for each node between frames
var _velocities: Dictionary = {}

func clear_velocities() -> void:
	_velocities.clear()

# Steps the physics simulation forward by one frame.
# This should be called inside a _process(delta) loop when Buoyancy Mode is active.
func step(graph: Graph, delta: float) -> void:
	if not graph or graph.nodes.is_empty(): 
		return
		
	var forces: Dictionary = {}
	var node_ids = graph.nodes.keys()
	
	# Initialize internal tracking arrays
	for id in node_ids:
		forces[id] = Vector2.ZERO
		if not _velocities.has(id):
			_velocities[id] = Vector2.ZERO

	# --- 1. REPULSION (Coulomb's Law) ---
	# Every node pushes every other node away.
	for i in range(node_ids.size()):
		var id_u = node_ids[i]
		var node_u = graph.nodes[id_u]
		var rep_u = node_u.get("physics_repulsion") if "physics_repulsion" in node_u else 100.0
		
		for j in range(i + 1, node_ids.size()):
			var id_v = node_ids[j]
			var node_v = graph.nodes[id_v]
			var rep_v = node_v.get("physics_repulsion") if "physics_repulsion" in node_v else 100.0
			
			var diff = node_u.position - node_v.position
			var dist_sq = diff.length_squared()
			
			# Prevent division by zero if nodes are exactly stacked
			if dist_sq < 1.0:
				diff = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
				dist_sq = 1.0
				
			var dist = sqrt(dist_sq)
			
			# Force is inversely proportional to distance squared
			var force_mag = ((rep_u + rep_v) * repulsion_multiplier) / dist_sq
			var force_vec = (diff / dist) * force_mag
			
			forces[id_u] += force_vec
			forces[id_v] -= force_vec

	# --- 2. ATTRACTION (Hooke's Law) ---
	# Connected nodes pull each other like springs toward their ideal length.
	var processed_edges = {}
	
	for u in graph.edge_data:
		for v in graph.edge_data[u]:
			# Ensure we only calculate each edge once (even if bidirectional)
			var pair = [u, v]
			pair.sort()
			if processed_edges.has(pair): continue
			processed_edges[pair] = true
			
			if not graph.nodes.has(u) or not graph.nodes.has(v): continue
			
			var node_u = graph.nodes[u]
			var node_v = graph.nodes[v]
			var edge_dict = graph.edge_data[u][v]
			
			var ideal_len = float(edge_dict.get("physics_spring_length", 150.0))
			var stiffness = float(edge_dict.get("physics_stiffness", 0.5))
			
			var diff = node_v.position - node_u.position
			var dist = diff.length()
			
			if dist > 0.1:
				# Hooke's Law: Force = stiffness * displacement from rest
				var displacement = dist - ideal_len
				var force_mag = displacement * stiffness
				var force_vec = (diff / dist) * force_mag
				
				forces[u] += force_vec
				forces[v] -= force_vec

	# --- 3. INTEGRATION (Apply Velocity) ---
	for id in node_ids:
		var node = graph.nodes[id]
		
		# Add new forces to velocity (scaled by time)
		var current_vel = _velocities[id]
		current_vel += forces[id] * delta
		
		# Apply Damping (Friction)
		current_vel *= damping
		
		# Clamp to Maximum Speed limit (prevents the simulation from exploding outward)
		if current_vel.length() > max_velocity:
			current_vel = current_vel.normalized() * max_velocity
			
		_velocities[id] = current_vel
		
		# Only update if there is meaningful movement to save on spatial grid recalculations
		if current_vel.length_squared() > 0.01:
			var new_pos = node.position + current_vel
			# Use the Graph's API so it updates the Spatial Grid!
			graph.set_node_position(id, new_pos)
