```markdown
# Graph Editor – Codebase Map (v1.6)

## Project Structure


/scripts
├── algorithms/
│ ├── analysis/ # Heavy graph-metric calculators
│ │ ├── analysis_chromatic.gd
│ │ ├── analysis_entropy.gd
│ │ ├── analysis_eulerian.gd
│ │ ├── analysis_longest_path.gd
│ │ ├── analysis_louvain.gd
│ │ ├── analysis_markov.gd
│ │ ├── analysis_planarity.gd
│ │ ├── analysis_spectral.gd
│ │ └── analysis_tangles.gd
│ ├── pathfinding/ # Pathfinding algorithm implementations
│ │ ├── pathfinder_strategy.gd
│ │ ├── pathfinder_a_star.gd
│ │ ├── pathfinder_bfs.gd
│ │ ├── pathfinder_dfs.gd
│ │ ├── pathfinder_dijkstra.gd
│ │ └── pathfinder_random.gd
│ ├── procedural_generation/ # [LEGACY] Old strategy-based generation
│ │ ├── graph_strategy.gd
│ │ ├── strategy_biome_filler.gd
│ │ ├── strategy_ca.gd
│ │ ├── strategy_dag.gd
│ │ ├── strategy_dla.gd
│ │ ├── strategy_grammar.gd
│ │ ├── strategy_grid.gd
│ │ ├── strategy_mst.gd
│ │ ├── strategy_polar.gd
│ │ └── strategy_walker.gd
│ └── transformations/ # Pipeline modifiers (current generation system)
│ ├── graph_modifier.gd
│ ├── trans_generate_dag.gd
│ ├── trans_generate_grid.gd
│ ├── trans_generate_polar.gd
│ ├── trans_generate_scale_free.gd
│ ├── trans_geo_jitter.gd
│ ├── trans_geo_relax_buoyancy.gd
│ ├── trans_mutate_braid.gd
│ ├── trans_mutate_ca.gd
│ ├── trans_mutate_connect_components.gd
│ ├── trans_mutate_dla.gd
│ ├── trans_mutate_edge_subdivide.gd
│ ├── trans_mutate_flow_direct.gd
│ ├── trans_mutate_fuse_nodes.gd
│ ├── trans_mutate_grammar.gd
│ ├── trans_mutate_mst.gd
│ ├── trans_mutate_prune_leaves.gd
│ ├── trans_mutate_walker.gd
│ ├── trans_semantic_biome_fill.gd
│ ├── trans_semantic_dag_locks.gd
│ ├── trans_semantic_distance_to_edge_weights.gd
│ └── trans_semantic_logic_gates.gd
├── autoloads/ # Global singletons
│ └── signal_manager.gd
├── commands/ # Undoable command objects
│ ├── graph_command.gd
│ ├── cmd_add_agent.gd
│ ├── cmd_add_node.gd
│ ├── cmd_add_zone.gd
│ ├── cmd_batch.gd
│ ├── cmd_connect.gd
│ ├── cmd_delete_node.gd
│ ├── cmd_disconnect.gd
│ ├── cmd_move_node.gd
│ ├── cmd_remove_agent.gd
│ ├── cmd_remove_zone.gd
│ ├── cmd_set_property.gd
│ ├── cmd_update_agent.gd
│ └── cmd_zone_edit.gd
├── controllers/ # MVC controllers for panels/tabs
│ ├── inspector/ # Inspector sub-panels
│ │ ├── inspector_strategy.gd
│ │ ├── inspector_agent.gd
│ │ ├── inspector_edge.gd
│ │ ├── inspector_node.gd
│ │ └── inspector_zone.gd
│ ├── agent_controller.gd
│ ├── analysis_controller.gd
│ ├── experiment_controller.gd
│ ├── file_controller.gd
│ ├── inspector_controller.gd
│ ├── pipeline_controller.gd # Current generation pipeline controller
│ ├── realizer_controller.gd # Rasterization controller
│ ├── strategy_controller.gd # [LEGACY] Old strategy controller
│ ├── toolbar_controller.gd
│ ├── topbar_controller.gd
│ ├── ui_layout_controller.gd
│ └── zone_controller.gd
├── core/ # Core systems
│ ├── agent_simulation/ # Agent-based simulation
│ │ ├── agent_walker.gd
│ │ ├── simulation.gd
│ │ ├── agent_navigator.gd
│ │ ├── agent_capability.gd
│ │ ├── Behaviours/ # Agent “brain” scripts
│ │ │ ├── agent_behaviour.gd
│ │ │ ├── behaviours_standard.gd
│ │ │ ├── behaviour_grow.gd
│ │ │ ├── behaviour_manual.gd
│ │ │ ├── behaviour_maze_gen.gd
│ │ │ └── behaviour_solver.gd
│ │ └── capabilities/ # Agent action abilities
│ │ ├── cap_builder.gd
│ │ ├── cap_inventory.gd
│ │ ├── cap_motor.gd
│ │ └── cap_painter.gd
│ ├── editor/ # Editor-specific utilities
│ │ ├── graph_history.gd
│ │ ├── graph_tool_manager.gd
│ │ └── strategy_executor.gd # [LEGACY] Used by old strategy system
│ ├── physics_simulation/ # Physics-based layout
│ │ └── buoyancy_engine.gd
│ ├── game_player.gd
│ ├── graph.gd
│ ├── graph_editor.gd
│ ├── graph_renderer.gd
│ ├── graph_settings.gd
│ ├── graph_zone.gd
│ ├── node_data.gd
│ └── semantic_registry.gd
├── graph_tools/ # Interactive editing tools
│ ├── components/
│ │ └── graph_drag_handler.gd
│ ├── graph_tool.gd
│ ├── graph_tool_add_node.gd
│ ├── graph_tool_connect.gd
│ ├── graph_tool_control.gd
│ ├── graph_tool_cut.gd
│ ├── graph_tool_delete.gd
│ ├── graph_tool_paint.gd
│ ├── graph_tool_property_paint.gd
│ ├── graph_tool_select.gd
│ ├── graph_tool_spawner.gd
│ ├── graph_tool_stamp.gd
│ └── graph_tool_zone_brush.gd
├── realizer/ # Rasterization pipeline
│ ├── cellular_smoother.gd
│ ├── distance_mapper.gd
│ ├── distribution_engine.gd
│ ├── edge_router.gd
│ ├── entity_scatterer.gd
│ ├── generation_validator.gd
│ ├── graph_realizer.gd
│ ├── grid_data.gd
│ ├── path_eroder.gd
│ ├── progression_solver.gd
│ ├── room_allocator.gd
│ ├── structure_placer.gd
│ ├── textural_wfc_pass.gd
│ ├── tile_palette.gd
│ ├── tilemap_adapter.gd
│ ├── wall_generator.gd
│ ├── wfc_pattern_extractor.gd
│ ├── wfc_solver.gd
│ └── zone_decorator.gd
├── ui/ # Reusable UI elements
│ ├── rasterizer_views/ # Tab views for RealizerController
│ │ ├── generator_tab_view.gd
│ │ ├── report_tab_view.gd
│ │ ├── timeline_tab_view.gd
│ │ └── validation_tab_view.gd
│ ├── algorithm_settings_popup.gd
│ ├── biome_designer_popup.gd
│ ├── biome_interaction_popup.gd
│ ├── cosine_palette_editor.gd
│ ├── custom_room_designer_popup.gd
│ ├── grid_canvas_painter.gd
│ ├── scatter_designer_popup.gd
│ ├── semantic_data_editor.gd
│ ├── settings_window.gd
│ ├── sidebar.gd
│ ├── structure_designer_popup.gd
│ ├── tile_wfc_designer_popup.gd
│ ├── tilemap_popup.gd
│ ├── tool_button.gd
│ ├── toolbar.gd
│ └── wfcModuleDesignerPopup.gd
└── utils/ # Miscellaneous helpers
├── config_manager.gd
├── documentation_tools.gd
├── experiment_builder.gd
├── experiment_runner.gd
├── graph_camera.gd
├── graph_clipboard.gd
├── graph_icon_library.gd
├── graph_input_handler.gd
├── graph_metrics.gd
├── graph_recorder.gd
├── graph_serializer.gd
├── graph_validator.gd
├── grid_renderer.gd
├── priority_queue.gd
├── seed_utils.gd
├── settings_ui_builder.gd
└── spatial_grid.gd
```

---

## Detailed Script Index

### Algorithms / Analysis

| Script | Description | Key Dependencies | Integrations |
|--------|-------------|------------------|--------------|
| `analysis_chromatic.gd` | Chromatic number / graph coloring (async). | Graph, RefCounted | `GraphMetrics._calculate_chromatic` |
| `analysis_entropy.gd` | Shannon entropy of node degrees. | Graph | `GraphMetrics._calculate_topology` |
| `analysis_eulerian.gd` | Eulerian path / circuit detection (async). | Graph | `GraphMetrics._calculate_eulerian` |
| `analysis_longest_path.gd` | Longest simple path (async). | Graph | `GraphMetrics._calculate_longest_path` |
| `analysis_louvain.gd` | Community detection via Louvain method (async). | Graph | `GraphMetrics._calculate_louvain` |
| `analysis_markov.gd` | Markov chain flow / stationary distribution. | Graph | `GraphMetrics._calculate_markov` |
| `analysis_planarity.gd` | Planarity testing (K5, K3,3). | Graph | `GraphMetrics._calculate_topology` |
| `analysis_spectral.gd` | Fiedler vector / algebraic connectivity. | Graph | `GraphMetrics._calculate_topology` |
| `analysis_tangles.gd` | Treewidth / tangle analysis (async). | Graph | `GraphMetrics._calculate_tangles` |

### Algorithms / Pathfinding

| Script | Description | Key Dependencies | Integrations |
|--------|-------------|------------------|--------------|
| `pathfinder_strategy.gd` | Base class for pathfinding algorithms. | RefCounted, Graph | All pathfinders inherit from it |
| `pathfinder_a_star.gd` | A* search (heuristic). | `pathfinder_strategy` | `AgentNavigator._get_strategy` |
| `pathfinder_bfs.gd` | Breadth-first search. | `pathfinder_strategy` | `AgentNavigator._get_strategy` |
| `pathfinder_dfs.gd` | Depth-first search. | `pathfinder_strategy` | `AgentNavigator._get_strategy` |
| `pathfinder_dijkstra.gd` | Dijkstra’s algorithm. | `pathfinder_strategy` | `AgentNavigator._get_strategy` |
| `pathfinder_random.gd` | Random neighbour selection. | `pathfinder_strategy` | `AgentNavigator._get_strategy` |

### Algorithms / Procedural Generation (LEGACY)

> These scripts are retained for compatibility but are superseded by the pipeline modifier system (`algorithms/transformations/`).

| Script | Description | Key Dependencies | Integrations |
|--------|-------------|------------------|--------------|
| `graph_strategy.gd` | Base class for legacy generation strategies. | Resource | `StrategyController` |
| `strategy_biome_filler.gd` | Legacy biome flood fill. | `graph_strategy` | `StrategyController` |
| `strategy_ca.gd` | Cellular automata generation. | `graph_strategy` | `StrategyController` |
| `strategy_dag.gd` | DAG generation. | `graph_strategy` | `StrategyController` |
| `strategy_dla.gd` | Diffusion-limited aggregation. | `graph_strategy` | `StrategyController` |
| `strategy_grammar.gd` | Shape grammar generation. | `graph_strategy` | `StrategyController` |
| `strategy_grid.gd` | Regular grid generation. | `graph_strategy` | `StrategyController` |
| `strategy_mst.gd` | Minimum spanning tree generation. | `graph_strategy` | `StrategyController` |
| `strategy_polar.gd` | Polar generation. | `graph_strategy` | `StrategyController` |
| `strategy_walker.gd` | Walker agent generation. | `graph_strategy`, `AgentWalker` | `StrategyController`, `GraphToolSpawner` |

### Algorithms / Transformations (Pipeline System)

| Script | Description | Key Dependencies | Integrations |
|--------|-------------|------------------|--------------|
| `graph_modifier.gd` | Base class for pipeline modifiers; provides RNG, settings, context, semantic pre-registration. | Resource | `PipelineController`, `ExperimentRunner` |
| `trans_generate_dag.gd` | Generates directed acyclic graph. | `GraphModifier` | Pipeline |
| `trans_generate_grid.gd` | Generates grid graph. | `GraphModifier` | Pipeline |
| `trans_generate_polar.gd` | Generates polar graph. | `GraphModifier` | Pipeline |
| `trans_generate_scale_free.gd` | Generates scale-free graph. | `GraphModifier` | Pipeline |
| `trans_geo_jitter.gd` | Adds random positional jitter. | `GraphModifier` | Pipeline |
| `trans_geo_relax_buoyancy.gd` | Runs buoyancy physics. | `GraphModifier`, `BuoyancyEngine` | Pipeline |
| `trans_mutate_braid.gd` | Adds extra edges to dead ends. | `GraphModifier` | Pipeline |
| `trans_mutate_ca.gd` | Cellular automata node deletion. | `GraphModifier` | Pipeline |
| `trans_mutate_connect_components.gd` | Connects disconnected components. | `GraphModifier` | Pipeline |
| `trans_mutate_dla.gd` | Diffusion-limited aggregation. | `GraphModifier` | Pipeline |
| `trans_mutate_edge_subdivide.gd` | Subdivides edges. | `GraphModifier` | Pipeline |
| `trans_mutate_flow_direct.gd` | Directs edge flow. | `GraphModifier` | Pipeline |
| `trans_mutate_fuse_nodes.gd` | Fuses two nodes into one. | `GraphModifier` | Pipeline |
| `trans_mutate_grammar.gd` | Grammar-based graph rewriting. | `GraphModifier` | Pipeline |
| `trans_mutate_mst.gd` | MST pruning. | `GraphModifier` | Pipeline |
| `trans_mutate_prune_leaves.gd` | Prunes leaf nodes. | `GraphModifier` | Pipeline |
| `trans_mutate_walker.gd` | Walker agent mutation. | `GraphModifier` | Pipeline |
| `trans_semantic_biome_fill.gd` | Flood-fills biome types. | `GraphModifier` | Pipeline |
| `trans_semantic_dag_locks.gd` | Distributes locks/keys on DAG. | `GraphModifier` | Pipeline |
| `trans_semantic_distance_to_edge_weights.gd` | Sets edge weights from distance. | `GraphModifier` | Pipeline |
| `trans_semantic_logic_gates.gd` | Adds logic gates. | `GraphModifier` | Pipeline |

### Autoloads

| Script | Description | Key Dependencies | Integrations |
|--------|-------------|------------------|--------------|
| `signal_manager.gd` | Global event bus singleton. | – | Every controller, tool, and UI element |

### Commands

| Script | Description | Key Dependencies | Integrations |
|--------|-------------|------------------|--------------|
| `graph_command.gd` | Abstract base class for all undoable commands. | RefCounted, Graph | All cmd_* classes |
| `cmd_add_agent.gd` | Adds an agent. | `graph_command` | `GraphEditor.add_agent`, `StrategyWalker` |
| `cmd_add_node.gd` | Adds a node. | `graph_command` | `GraphEditor.create_node`, `GraphRecorder` |
| `cmd_add_zone.gd` | Adds a zone. | `graph_command` | `GraphEditor.add_zone` |
| `cmd_batch.gd` | Composite command; groups multiple commands into one undo step. | `graph_command` | `GraphHistory`, `GraphEditor` |
| `cmd_connect.gd` | Creates an edge. | `graph_command` | `GraphEditor.connect_nodes`, `GraphToolConnect` |
| `cmd_delete_node.gd` | Deletes a node and incident edges. | `graph_command` | `GraphEditor.delete_node` |
| `cmd_disconnect.gd` | Removes an edge. | `graph_command` | `GraphEditor.disconnect_nodes` |
| `cmd_move_node.gd` | Moves a node. | `graph_command` | `GraphEditor.set_node_position` |
| `cmd_remove_agent.gd` | Removes an agent. | `graph_command` | `GraphEditor.remove_agent` |
| `cmd_remove_zone.gd` | Removes a zone. | `graph_command` | `GraphEditor.remove_zone` |
| `cmd_set_property.gd` | Generic property setter; refreshes brain on behavior changes. | `graph_command`, `SemanticRegistry` | `GraphEditor.set_*_property`, inspectors, controllers |
| `cmd_update_agent.gd` | Restores agent state. | `graph_command` | `Simulation`, `StrategyWalker` |
| `cmd_zone_edit.gd` | Modifies zone cells. | `graph_command` | `GraphEditor.modify_zone_cells` |

### Controllers

| Script | Description | Key Dependencies | Integrations |
|--------|-------------|------------------|--------------|
| `inspector_strategy.gd` | Base class for inspector sub-panels. | Node | `InspectorController` |
| `inspector_agent.gd` | Inspector for agent properties. | `inspector_strategy`, `GraphEditor` | `InspectorController` |
| `inspector_edge.gd` | Inspector for edge properties. | `inspector_strategy`, `GraphEditor` | `InspectorController` |
| `inspector_node.gd` | Inspector for node properties. | `inspector_strategy`, `GraphEditor` | `InspectorController` |
| `inspector_zone.gd` | Inspector for zone properties. | `inspector_strategy`, `GraphEditor` | `InspectorController` |
| `agent_controller.gd` | Agent roster and behavior panel. | `GraphEditor`, `AgentWalker` | Roster UI, `SignalManager` |
| `analysis_controller.gd` | Triggers metric computation. | `GraphEditor`, `GraphMetrics` | Analysis tab UI |
| `experiment_controller.gd` | Loads pipeline and runs batch experiments. | `ExperimentRunner`, `GraphModifier` | Experiment UI |
| `file_controller.gd` | Save/load/new graph. | `GraphEditor`, `GraphSerializer` | File tab UI |
| `inspector_controller.gd` | Routes selection to inspectors; manages wizard. | `GraphEditor`, inspector strategies | Inspector panel |
| `pipeline_controller.gd` | Primary generation pipeline manager; executes modifier stack. | `GraphModifier`, `GraphEditor` | Pipeline UI |
| `realizer_controller.gd` | Rasterization controller; manages threads, timeline, validation, and tooltips. | `GraphRealizer`, `TileMapLayer`, tab views | Realizer UI |
| `strategy_controller.gd` | [LEGACY] Old strategy selection and application. | `GraphEditor`, legacy strategies | Legacy Strategy tab |
| `toolbar_controller.gd` | Tool bar UI. | `GraphEditor`, `GraphToolManager` | Main editor UI |
| `topbar_controller.gd` | Top bar logic (menus, simulation controls). | `GraphEditor`, `GraphHistory` | Main editor UI |
| `ui_layout_controller.gd` | Toggles visibility of left/right/top panels; Zen mode. | `GraphSettings`, `ConfigManager` | Main editor UI |
| `zone_controller.gd` | Zone list management. | `GraphEditor`, `GraphZone` | Zone tab UI |

### Core – Agent Simulation

| Script | Description | Key Dependencies | Integrations |
|--------|-------------|------------------|--------------|
| `agent_walker.gd` | Core agent class. | `AgentCapability`, `AgentBehavior`, `AgentNavigator` | `Simulation`, `StrategyWalker`, `AgentController`, inspectors |
| `simulation.gd` | Tick loop for agents. | `Graph`, `GraphRecorder`, `CmdUpdateAgent` | `GraphEditor` |
| `agent_navigator.gd` | Static dispatcher for pathfinding. | `pathfinder_strategy` subclasses | `AgentWalker`, behaviours |
| `agent_capability.gd` | Base class for agent capabilities. | RefCounted | `CapMotor`, `CapPainter`, etc. |
| `agent_behaviour.gd` | Base class for agent brains. | RefCounted | All behaviours |
| `behaviours_standard.gd` | Hold, Wander, Seek, Diagnostic. | `agent_behaviour` | `AgentWalker._refresh_brain` |
| `behaviour_grow.gd` | Expansion behaviour. | `agent_behaviour`, `CapBuilder`, `CapMotor` | `AgentWalker` |
| `behaviour_manual.gd` | Manual player control. | `agent_behaviour` | `AgentWalker` |
| `behaviour_maze_gen.gd` | Maze generation. | `agent_behaviour`, `CapBuilder`, `CapMotor`, `CapPainter` | `AgentWalker` |
| `behaviour_solver.gd` | Solver behaviour (questline). | `agent_behaviour`, `CapMotor`, `CapInventory` | `AgentWalker` |
| `cap_builder.gd` | Node/edge building. | `agent_capability` | `BehaviourGrow`, `BehaviourMazeGen` |
| `cap_inventory.gd` | Lock-and-key inventory. | `agent_capability`, `Graph` | `BehaviourSolver`, `GraphToolControl` |
| `cap_motor.gd` | Movement. | `agent_capability`, `Graph` | All behaviours |
| `cap_painter.gd` | Data painting. | `agent_capability`, `Graph` | `BehaviourMazeGen`, `BehaviourGrow` |

### Core – Editor

| Script | Description | Key Dependencies | Integrations |
|--------|-------------|------------------|--------------|
| `graph_history.gd` | Undo/redo stack. | `GraphCommand`, `CmdBatch` | `GraphEditor` |
| `graph_tool_manager.gd` | Tool factory and input routing. | `GraphTool` subclasses | `GraphEditor`, `toolbar_controller` |
| `strategy_executor.gd` | [LEGACY] Runs legacy strategies. | `GraphStrategy`, `GraphRecorder` | `StrategyController` |

### Core – Physics

| Script | Description | Key Dependencies | Integrations |
|--------|-------------|------------------|--------------|
| `buoyancy_engine.gd` | Force-based layout, crystallization, snapping. | `Graph`, `NodeData` | `GraphEditor`, `trans_geo_relax_buoyancy` |

### Core – Other

| Script | Description | Key Dependencies | Integrations |
|--------|-------------|------------------|--------------|
| `game_player.gd` | Top-level scene script. | – | Main scene |
| `graph.gd` | Core data model. | `NodeData`, `GraphZone`, `SpatialGrid`, `PriorityQueue` | Almost everything |
| `graph_editor.gd` | Central editor node. | `Graph`, `GraphHistory`, `GraphRenderer`, etc. | All controllers, tools |
| `graph_renderer.gd` | Draws nodes, edges, agents, zones. | `Graph`, `GraphSettings`, `SemanticRegistry` | `GraphEditor` |
| `graph_settings.gd` | Configuration constants. | – | Every script |
| `graph_zone.gd` | Zone resource. | Resource | `Graph`, controllers |
| `node_data.gd` | Node resource. | Resource | `Graph`, inspectors |
| `semantic_registry.gd` | Registry for categories/properties. | – | `CmdSetProperty`, inspectors |

### Graph Tools

| Script | Description | Key Dependencies | Integrations |
|--------|-------------|------------------|--------------|
| `graph_drag_handler.gd` | Reusable drag-select component. | `GraphEditor` | `GraphToolSelect`, `GraphToolSpawner` |
| `graph_tool.gd` | Base tool class. | RefCounted, `GraphEditor` | All tools |
| `graph_tool_add_node.gd` | Click to add node. | `graph_tool` | `GraphToolManager` |
| `graph_tool_connect.gd` | Drag to connect nodes. | `graph_tool` | `GraphToolManager` |
| `graph_tool_control.gd` | Player control of agent. | `graph_tool`, `AgentWalker` | `GraphToolManager` |
| `graph_tool_cut.gd` | Drag to cut edges. | `graph_tool` | `GraphToolManager` |
| `graph_tool_delete.gd` | Click to delete. | `graph_tool` | `GraphToolManager` |
| `graph_tool_paint.gd` | Brush for painting. | `graph_tool` | `GraphToolManager` |
| `graph_tool_property_paint.gd` | Paint properties. | `graph_tool` | `GraphToolManager` |
| `graph_tool_select.gd` | Select/move nodes. | `graph_tool`, `GraphDragHandler` | `GraphToolManager` |
| `graph_tool_spawner.gd` | Spawn/select/delete agents. | `graph_tool`, `StrategyWalker` | `GraphToolManager` |
| `graph_tool_stamp.gd` | Paste prefab. | `graph_tool`, `GraphClipboard` | `GraphToolManager` |
| `graph_tool_zone_brush.gd` | Paint zone cells. | `graph_tool` | `GraphToolManager` |

### Realizer (Rasterization Pipeline)

| Script | Description | Key Dependencies | Integrations |
|--------|-------------|------------------|--------------|
| `graph_realizer.gd` | Main rasterization orchestrator. | `GridData`, `TilePalette`, all passes | `RealizerController` |
| `cellular_smoother.gd` | CA smoothing pass. | `GraphRealizer`, `GridData` | Pipeline |
| `distance_mapper.gd` | Distance field computation. | `GraphRealizer` | Pipeline |
| `distribution_engine.gd` | Declarative spawn list generation. | `Graph`, overrides | `EntityScatterer`, `StructurePlacer` |
| `edge_router.gd` | Corridor carving between nodes. | `GraphRealizer`, `AStarGrid2D` | Pipeline |
| `entity_scatterer.gd` | Scatters entities. | `GraphRealizer`, `DistributionEngine` | Pipeline |
| `generation_validator.gd` | Flood-fill reachability checker. | `GridData` | `RealizerController` |
| `grid_data.gd` | 2D cell grid container. | `TilePalette` | All realizer passes |
| `path_eroder.gd` | Erosion of corridor edges. | `GraphRealizer` | Pipeline |
| `progression_solver.gd` | Lock/key and region analysis. | `GraphRealizer`, `GridData` | Pipeline |
| `room_allocator.gd` | Room stamping. | `GraphRealizer` | Pipeline |
| `structure_placer.gd` | Places custom structures. | `GraphRealizer` | Pipeline |
| `textural_wfc_pass.gd` | Overlapping WFC tile stamping. | `GraphRealizer`, `WFC` | Pipeline |
| `tile_palette.gd` | Tile ID registry. | – | `GridData` |
| `tilemap_adapter.gd` | Paints grid to TileMapLayer. | `GridData`, `TileMapLayer` | `RealizerController` |
| `wall_generator.gd` | Places walls. | `GraphRealizer` | Pipeline |
| `wfc_pattern_extractor.gd` | Extracts patterns for overlapping WFC. | – | `TileWfcDesignerPopup`, `TexturalWFCPass` |
| `wfc_solver.gd` | WFC solver. | – | `TexturalWFCPass`, `TileWfcDesignerPopup` |
| `zone_decorator.gd` | Biome interaction rules. | `GraphRealizer` | Pipeline |

### UI

| Script | Description | Key Dependencies | Integrations |
|--------|-------------|------------------|--------------|
| `algorithm_settings_popup.gd` | Generic popup for settings. | `SettingsUIBuilder` | `InspectorAgent`, `RealizerController` |
| `biome_designer_popup.gd` | Biome override editor. | `ConfigManager`, `SettingsUIBuilder` | `RealizerController` |
| `biome_interaction_popup.gd` | Biome edge matrix editor. | `ConfigManager` | `RealizerController` |
| `cosine_palette_editor.gd` | Cosine gradient editor. | – | `TileMappingPopup` |
| `custom_room_designer_popup.gd` | Custom room editor. | `GridCanvasPainter` | `RealizerController` |
| `grid_canvas_painter.gd` | Reusable canvas painter. | Control | Multiple designer popups |
| `rasterizer_views/generator_tab_view.gd` | Realizer settings tab. | `SettingsUIBuilder` | `RealizerController` |
| `rasterizer_views/report_tab_view.gd` | Progression report tab. | – | `RealizerController` |
| `rasterizer_views/timeline_tab_view.gd` | Timeline scrubber. | – | `RealizerController` |
| `rasterizer_views/validation_tab_view.gd` | Validation controls. | – | `RealizerController` |
| `scatter_designer_popup.gd` | Scatter set editor. | `GridCanvasPainter` | `RealizerController` |
| `semantic_data_editor.gd` | Wizard for custom properties. | – | `InspectorController` |
| `settings_window.gd` | Application settings. | – | `FileController` |
| `sidebar.gd` | Panel that blocks mouse wheel. | – | Main editor layout |
| `structure_designer_popup.gd` | Custom structure designer. | `GridCanvasPainter` | `RealizerController` |
| `tile_wfc_designer_popup.gd` | Overlapping WFC sample editor. | `GridCanvasPainter` | `RealizerController` |
| `tilemap_popup.gd` | Tile mapping editor. | – | `RealizerController` |
| `tool_button.gd` | Toolbar button. | – | `toolbar.gd` |
| `toolbar.gd` | Toolbar container. | – | `GraphToolManager` |
| `wfcModuleDesignerPopup.gd` | Chunk WFC module designer. | `GridCanvasPainter` | `RealizerController` |

### Utils

| Script | Description | Key Dependencies | Integrations |
|--------|-------------|------------------|--------------|
| `config_manager.gd` | Persistent user configuration. | – | Settings, Realizer |
| `documentation_tools.gd` | Scans project for `.gd` files. | – | Editor tooling |
| `experiment_builder.gd` | Cartesian product generator. | – | `ExperimentController` |
| `experiment_runner.gd` | Threaded batch executor. | `GraphModifier`, `GraphMetrics` | `ExperimentController` |
| `graph_camera.gd` | Camera2D with zoom/pan. | Camera2D | `GraphEditor` |
| `graph_clipboard.gd` | Copy/paste. | `GraphEditor` | `GraphInputHandler`, `GraphToolStamp` |
| `graph_icon_library.gd` | Provides icons. | – | `GraphRenderer` |
| `graph_input_handler.gd` | Keyboard shortcuts. | `GraphEditor`, `GraphClipboard` | `GraphEditor` |
| `graph_metrics.gd` | Generates analysis report. | `Graph`, analysis scripts | `AnalysisController` |
| `graph_recorder.gd` | Sandbox clone recording commands. | `Graph`, `Cmd*` | Pipeline, Simulation |
| `graph_serializer.gd` | JSON/GraphML/GEXF serialization. | `Graph`, `AgentWalker` | `FileController` |
| `graph_validator.gd` | Integrity checker. | `Graph` | On load / manual |
| `grid_renderer.gd` | Background grid. | – | `GraphEditor` |
| `priority_queue.gd` | Priority queue. | RefCounted | Pathfinders |
| `seed_utils.gd` | Seed hashing and random pick. | – | Every generator |
| `settings_ui_builder.gd` | Dynamic UI from schema. | Control | All inspectors, designers |
| `spatial_grid.gd` | Spatial hash grid. | RefCounted | `Graph` |
```