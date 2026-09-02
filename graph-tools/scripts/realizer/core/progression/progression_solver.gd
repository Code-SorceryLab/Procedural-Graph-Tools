class_name ProgressionSolver
extends RefCounted

static func analyze(realizer: GraphRealizer, params: Dictionary, emit: Callable = Callable()) -> void:
	print("[ProgressionSolver] analyze called. is_regen? ", params.has("regen_dirty_rect"))
	print("[ProgressionSolver] regen_layer_progression = ", params.get("regen_layer_progression", true))
	print("[ProgressionSolver] regen_triggers size = ", params.get("regen_triggers", {}).size())
	
	var master_seed = SeedUtils.hash_seed(str(params.get("realizer_seed", "default")) + "_progression")
	var rng = RandomNumberGenerator.new()
	rng.seed = master_seed
	
	# 1. The Cartographer: Map the Physical Grid into an Abstract Graph
	var map_data = ProgressionRegionMapper.map_regions(realizer, emit)
	if map_data.is_empty() or map_data["regions"].is_empty(): 
		return
	
	print("[ProgressionSolver] map_data empty? ", map_data.is_empty())
	print("[ProgressionSolver] regions count: ", map_data.get("regions", {}).size())
	
	# 2. The Auditor: Analyze Topology, Components, and Pathing
	var path_data = ProgressionPathingAnalyst.analyze_paths(realizer, params, map_data, rng, emit)

	# 3. The Reconciler: Distribute Locks, Keys, and Vaults (The Metroidvania Engine)
	var locker_data = ProgressionLocker.distribute_locks(realizer, params, map_data, path_data, rng, emit)

	# 4. The Archivist: Export Metadata & JSON Report
	ProgressionReportBuilder.build_and_export(realizer, params, map_data, path_data, locker_data)
	
	
	
