class_name ProgressionSolver
extends RefCounted

static func analyze(realizer: GraphRealizer, params: Dictionary, emit: Callable = Callable()) -> void:
	var master_seed = SeedUtils.hash_seed(str(params.get("realizer_seed", "default")) + "_progression")
	var rng = RandomNumberGenerator.new()
	rng.seed = master_seed
	
	# 1. The Cartographer: Map the Physical Grid into an Abstract Graph
	var map_data = ProgressionRegionMapper.map_regions(realizer, emit)
	if map_data.is_empty() or map_data["regions"].is_empty(): 
		return

	# 2. The Auditor: Analyze Topology, Components, and Pathing
	var path_data = ProgressionPathingAnalyst.analyze_paths(realizer, params, map_data, rng, emit)

	# 3. The Reconciler: Distribute Locks, Keys, and Vaults (The Metroidvania Engine)
	var locker_data = ProgressionLocker.distribute_locks(realizer, params, map_data, path_data, rng, emit)

	# 4. The Archivist: Export Metadata & JSON Report
	ProgressionReportBuilder.build_and_export(realizer, params, map_data, path_data, locker_data)
	
	
	
