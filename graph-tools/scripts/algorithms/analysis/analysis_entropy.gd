class_name AnalysisEntropy
extends RefCounted

# Calculates the Shannon Entropy (Information Theory) of the graph's degree distribution.
# Returns the entropy score, where 0.0 is perfectly uniform and higher numbers indicate structural chaos.
static func calculate(graph: Graph) -> Dictionary:
	var nodes = graph.nodes.keys()
	var total_nodes = nodes.size()
	
	if total_nodes <= 1:
		return { "shannon_entropy": 0.0 }
		
	# 1. Calculate the Degree Distribution
	# Count how many nodes have exactly 'k' connections
	var degree_counts = {}
	for id in nodes:
		var deg = graph.get_neighbors(id).size()
		if degree_counts.has(deg):
			degree_counts[deg] += 1
		else:
			degree_counts[deg] = 1
			
	# 2. Apply Shannon Entropy Formula: H = - sum( p(k) * log2(p(k)) )
	var entropy = 0.0
	
	for deg in degree_counts:
		var count = degree_counts[deg]
		var probability = float(count) / float(total_nodes)
		
		# GDScript's log() is Natural Log (Base e). 
		# We divide by log(2.0) to convert it to Base 2 (Bits of information).
		var log2_p = log(probability) / log(2.0)
		entropy -= probability * log2_p
		
	return {
		"shannon_entropy": snapped(entropy, 0.001)
	}
