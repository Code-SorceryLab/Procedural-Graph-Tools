```markdown
# Graph Editor – Codebase Map (v1.6)

## Project Structure


/scripts
├── algorithms/
│   ├── analysis/                      # Heavy graph‑metric calculators
│   │   ├── analysis_chromatic.gd
│   │   ├── analysis_entropy.gd
│   │   ├── analysis_eulerian.gd
│   │   ├── analysis_longest_path.gd
│   │   ├── analysis_louvain.gd
│   │   ├── analysis_markov.gd
│   │   ├── analysis_planarity.gd
│   │   ├── analysis_spectral.gd
│   │   └── analysis_tangles.gd
│   ├── pathfinding/                   # Pathfinding algorithm implementations
│   │   ├── pathfinder_strategy.gd
│   │   ├── pathfinder_a_star.gd
│   │   ├── pathfinder_bfs.gd
│   │   ├── pathfinder_dfs.gd
│   │   ├── pathfinder_dijkstra.gd
│   │   └── pathfinder_random.gd
│   └── procedural_generation/         # Graph generation strategies
│       ├── graph_strategy.gd
│       ├── strategy_analyze.gd
│       ├── strategy_ca.gd
│       ├── strategy_dag.gd
│       ├── strategy_dla.gd
│       ├── strategy_grammar.gd
│       ├── strategy_grid.gd
│       ├── strategy_mst.gd
│       ├── strategy_polar.gd
│       └── strategy_walker.gd
├── autoloads/                         # Global singletons
│   └── signal_manager.gd
├── commands/                          # Undo‑able command objects
│   ├── graph_command.gd
│   ├── cmd_add_agent.gd
│   ├── cmd_add_node.gd
│   ├── cmd_add_zone.gd
│   ├── cmd_batch.gd
│   ├── cmd_connect.gd
│   ├── cmd_delete_node.gd
│   ├── cmd_disconnect.gd
│   ├── cmd_move_node.gd
│   ├── cmd_remove_agent.gd
│   ├── cmd_remove_zone.gd
│   ├── cmd_set_property.gd
│   ├── cmd_update_agent.gd
│   └── cmd_zone_edit.gd
├── controllers/                       # MVC controllers for panels/tabs
│   ├── inspector/                     # Inspector sub‑panels
│   │   ├── inspector_strategy.gd
│   │   ├── inspector_agent.gd
│   │   ├── inspector_edge.gd
│   │   ├── inspector_node.gd
│   │   └── inspector_zone.gd
│   ├── agent_controller.gd
│   ├── analysis_controller.gd
│   ├── file_controller.gd
│   ├── inspector_controller.gd
│   ├── strategy_controller.gd
│   ├── toolbar_controller.gd
│   ├── topbar_controller.gd
│   └── zone_controller.gd
├── core/                              # Core systems
│   ├── agent_simulation/              # Agent‑based simulation
│   │   ├── agent_walker.gd
│   │   ├── simulation.gd
│   │   ├── agent_navigator.gd
│   │   ├── agent_capability.gd
│   │   ├── behaviours/                # Agent “brain” scripts
│   │   │   ├── agent_behaviour.gd
│   │   │   ├── behaviours_standard.gd
│   │   │   ├── behaviour_grow.gd
│   │   │   ├── behaviour_manual.gd
│   │   │   ├── behaviour_maze_gen.gd
│   │   │   └── behaviour_solver.gd
│   │   └── capabilities/              # Agent action abilities
│   │       ├── cap_builder.gd
│   │       ├── cap_inventory.gd
│   │       ├── cap_motor.gd
│   │       └── cap_painter.gd
│   ├── editor/                        # Editor‑specific utilities
│   │   ├── graph_history.gd
│   │   ├── graph_tool_manager.gd
│   │   └── strategy_executor.gd
│   ├── physics_simulation/            # Physics‑based layout
│   │   └── buoyancy_engine.gd
│   ├── game_player.gd
│   ├── graph.gd
│   ├── graph_editor.gd
│   ├── graph_renderer.gd
│   ├── graph_settings.gd
│   ├── graph_zone.gd
│   ├── node_data.gd
│   └── semantic_registry.gd
├── graph_tools/                       # Interactive editing tools
│   ├── components/
│   │   └── graph_drag_handler.gd
│   ├── graph_tool.gd
│   ├── graph_tool_add_node.gd
│   ├── graph_tool_connect.gd
│   ├── graph_tool_control.gd
│   ├── graph_tool_cut.gd
│   ├── graph_tool_delete.gd
│   ├── graph_tool_paint.gd
│   ├── graph_tool_property_paint.gd
│   ├── graph_tool_select.gd
│   ├── graph_tool_spawner.gd
│   ├── graph_tool_stamp.gd
│   └── graph_tool_zone_brush.gd
├── ui/                                # Reusable UI elements
│   ├── algorithm_settings_popup.gd
│   ├── semantic_data_editor.gd
│   ├── settings_window.gd
│   ├── toolbar.gd
│   └── tool_button.gd
└── utils/                             # Miscellaneous helpers
    ├── config_manager.gd
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
| `pathfinder_bfs.gd` | Breadth‑first search. | `pathfinder_strategy` | `AgentNavigator._get_strategy` |
| `pathfinder_dfs.gd` | Depth‑first search. | `pathfinder_strategy` | `AgentNavigator._get_strategy` |
| `pathfinder_dijkstra.gd` | Dijkstra’s algorithm. | `pathfinder_strategy` | `AgentNavigator._get_strategy` |
| `pathfinder_random.gd` | Random neighbour selection. | `pathfinder_strategy` | `AgentNavigator._get_strategy` |

### Algorithms / Procedural Generation

| Script | Description | Key Dependencies | Integrations |
|--------|-------------|------------------|--------------|
| `graph_strategy.gd` | Base class for generation strategies (RNG, UI schema). | Resource | All strategies inherit from it |
| `strategy_analyze.gd` | Labels nodes/edges with semantic data. | `graph_strategy` | `StrategyController` |
| `strategy_ca.gd` | Cellular automata generation. | `graph_strategy` | `StrategyController` |
| `strategy_dag.gd` | DAG generation with lock & key integration. | `graph_strategy`, `AgentWalker`? | `StrategyController` |
| `strategy_dla.gd` | Diffusion‑limited aggregation. | `graph_strategy` | `StrategyController` |
| `strategy_grammar.gd` | Shape grammar / L‑system generation. | `graph_strategy` | `StrategyController` |
| `strategy_grid.gd` | Regular grid generation. | `graph_strategy` | `StrategyController` |
| `strategy_mst.gd` | Minimum spanning tree generation. | `graph_strategy` | `StrategyController` |
| `strategy_polar.gd` | Polar / circular generation. | `graph_strategy` | `StrategyController` |
| `strategy_walker.gd` | Agent‑based growth (creates and simulates walkers). | `graph_strategy`, `AgentWalker`, `AgentNavigator` | `StrategyController`, `GraphToolSpawner` |

### Autoloads

| Script | Description | Key Dependencies | Integrations |
|--------|-------------|------------------|--------------|
| `signal_manager.gd` | Global event bus singleton. | – | Every controller, tool, and UI element |

### Commands

| Script | Description | Key Dependencies | Integrations |
|--------|-------------|------------------|--------------|
| `graph_command.gd` | Abstract base class for all undoable commands. | RefCounted, Graph | All cmd_* classes |
| `cmd_add_agent.gd` | Adds an agent to the graph. | `graph_command` | `GraphEditor.add_agent`, `StrategyWalker` |
| `cmd_add_node.gd` | Adds a node at a position. | `graph_command` | `GraphEditor.create_node`, `GraphRecorder` |
| `cmd_add_zone.gd` | Adds a zone to the graph. | `graph_command` | `GraphEditor.add_zone` |
| `cmd_batch.gd` | Composite command – groups multiple commands into one undo step. | `graph_command` | `GraphHistory`, `GraphEditor` (various batch operations) |
| `cmd_connect.gd` | Creates a directed or undirected edge. | `graph_command` | `GraphEditor.connect_nodes`, `GraphToolConnect` |
| `cmd_delete_node.gd` | Deletes a node and all its incident edges. | `graph_command` | `GraphEditor.delete_node` |
| `cmd_disconnect.gd` | Removes an edge (with snapshot for undo). | `graph_command` | `GraphEditor.disconnect_nodes` |
| `cmd_move_node.gd` | Moves a node to a new position (old/new snapshot). | `graph_command` | `GraphEditor.set_node_position`, drag tools |
| `cmd_remove_agent.gd` | Removes an agent. | `graph_command` | `GraphEditor.remove_agent` |
| `cmd_remove_zone.gd` | Removes a zone. | `graph_command` | `GraphEditor.remove_zone` |
| `cmd_set_property.gd` | Generic property setter for node/edge/agent/zone. Refreshes brain on `behavior_mode`. | `graph_command`, `SemanticRegistry` | `GraphEditor.set_*_property`, all inspectors, controllers |
| `cmd_update_agent.gd` | Saves/restores agent movement state (pos, history, etc.). | `graph_command` | `Simulation`, `StrategyWalker` |
| `cmd_zone_edit.gd` | Modifies zone cells (add/remove). | `graph_command` | `GraphEditor.modify_zone_cells` |

### Controllers

| Script | Description | Key Dependencies | Integrations |
|--------|-------------|------------------|--------------|
| `inspector_strategy.gd` | Base class for inspector sub‑panels. | Node | `InspectorController` |
| `inspector_agent.gd` | Inspector UI for agent properties (behaviour, algorithm, paint, etc.). | `inspector_strategy`, `GraphEditor`, `AlgorithmSettingsPopup` | `InspectorController` |
| `inspector_edge.gd` | Inspector UI for edge weight, direction, type, physics, custom data. | `inspector_strategy`, `GraphEditor` | `InspectorController` |
| `inspector_node.gd` | Inspector UI for node position, type, physics, custom data. | `inspector_strategy`, `GraphEditor` | `InspectorController` |
| `inspector_zone.gd` | Inspector UI for zone name, colour, rules, custom data. | `inspector_strategy`, `GraphEditor` | `InspectorController` |
| `agent_controller.gd` | Agent roster panel, quick‑behaviour editor, simulation step hooks. | `GraphEditor`, `AgentWalker`, `SettingsUIBuilder` | Roster UI, `SignalManager` |
| `analysis_controller.gd` | Triggers metric computation and displays results (read‑only). | `GraphEditor`, `GraphMetrics` | Analysis tab UI |
| `file_controller.gd` | Save / load / new graph, dirty‑state gatekeeper. | `GraphEditor`, `GraphSerializer` | File tab UI |
| `inspector_controller.gd` | Routes selection to correct inspector(s) and manages the property wizard. | `GraphEditor`, all inspector strategies, `SignalManager` | Inspector panel |
| `strategy_controller.gd` | Selects and applies generation strategies (grow, generate, spawn agents). | `GraphEditor`, all strategies, `StrategyExecutor` | Strategy tab UI |
| `toolbar_controller.gd` | Manages the tool bar UI (tool switching). | `GraphEditor`, `GraphToolManager` | Main editor UI |
| `topbar_controller.gd` | Top bar logic (undo/redo, status messages). | `GraphEditor`, `GraphHistory` | Main editor UI |
| `zone_controller.gd` | Zone list management (add, delete, select, type/lock toggles). | `GraphEditor`, `GraphZone` | Zone tab UI |

### Core – Agent Simulation

| Script | Description | Key Dependencies | Integrations |
|--------|-------------|------------------|--------------|
| `agent_walker.gd` | Core agent: state, brain, capabilities, movement, serialization. | `AgentCapability`, `AgentBehavior`, `AgentNavigator` | `Simulation`, `StrategyWalker`, `AgentController`, `InspectorAgent` |
| `simulation.gd` | Tick loop – steps all agents, records movement changes, returns undo batch. | `Graph`, `GraphRecorder`, `CmdUpdateAgent` | `GraphEditor` (simulation panel), `SignalManager` |
| `agent_navigator.gd` | Static dispatcher for pathfinding algorithms; provides zone/cost helpers. | `pathfinder_strategy` subclasses | `AgentWalker`, behaviours |
| `agent_capability.gd` | Base class for agent abilities (setup, tick). | RefCounted | `CapMotor`, `CapPainter`, etc. |
| `agent_behaviour.gd` | Base class for agent brains (enter, step, exit). | RefCounted | All behaviours |
| `behaviours_standard.gd` | Hold, Wander, Seek, Diagnostic behaviours. | `agent_behaviour`, `CapMotor`, `AgentWalker` | `AgentWalker._refresh_brain` |
| `behaviour_grow.gd` | Expansion behaviour – builds new nodes. | `agent_behaviour`, `CapBuilder`, `CapMotor` | `AgentWalker` |
| `behaviour_manual.gd` | Manual control (player‑issued intents). | `agent_behaviour` | `AgentWalker` |
| `behaviour_maze_gen.gd` | Maze generator (DFS with backtracking). | `agent_behaviour`, `CapBuilder`, `CapMotor`, `CapPainter` | `AgentWalker` |
| `behaviour_solver.gd` | Solver behaviour (questline / DAG navigation). | `agent_behaviour`, `CapMotor`, `CapInventory` | `AgentWalker` |
| `cap_builder.gd` | Node/edge building capability (build_and_link). | `agent_capability` | `BehaviourGrow`, `BehaviourMazeGen` |
| `cap_inventory.gd` | Lock‑and‑key inventory capability. | `agent_capability`, `Graph` | `BehaviourSolver`, `GraphToolControl` |
| `cap_motor.gd` | Movement capability (move_to_node, warp). | `agent_capability`, `Graph` | All behaviours |
| `cap_painter.gd` | Data painting on nodes/edges. | `agent_capability`, `Graph` | `BehaviourMazeGen`, `BehaviourGrow` |

### Core – Editor

| Script | Description | Key Dependencies | Integrations |
|--------|-------------|------------------|--------------|
| `graph_history.gd` | Undo/redo stack with transaction support. | `GraphCommand`, `CmdBatch` | `GraphEditor` |
| `graph_tool_manager.gd` | Tool factory, lifecycle, and input routing. | `GraphTool` subclasses, `GraphEditor` | `GraphEditor`, `toolbar_controller` |
| `strategy_executor.gd` | Runs a strategy in a sandbox, returns a `CmdBatch`, handles visual highlights. | `GraphStrategy`, `GraphRecorder` | `StrategyController`, `GraphEditor` |

### Core – Physics

| Script | Description | Key Dependencies | Integrations |
|--------|-------------|------------------|--------------|
| `buoyancy_engine.gd` | Force‑based layout (springs + repulsion), crystallization, edge snapping, node fusing. | `Graph`, `NodeData` | `GraphEditor` (buoyancy controls) |

### Core – Other

| Script | Description | Key Dependencies | Integrations |
|--------|-------------|------------------|--------------|
| `game_player.gd` | Top‑level game scene script (not heavily used). | – | Main scene |
| `graph.gd` | Core data model: nodes, canonical edge store, adjacency cache, zones, agents, spatial grid. | `NodeData`, `GraphZone`, `SpatialGrid`, `PriorityQueue` | Almost everything |
| `graph_editor.gd` | Central editor node – owns graph, selection, tools, command execution, public mutation API. | `Graph`, `GraphHistory`, `GraphRenderer`, `GraphCamera`, `GraphToolManager`, `Simulation`, `BuoyancyEngine`, `Cmd*` | All controllers, tools, inspectors |
| `graph_renderer.gd` | Draws nodes, edges, agents, zones, overlays. | `Graph`, `GraphSettings`, `SemanticRegistry` | `GraphEditor`, many tools |
| `graph_settings.gd` | Configuration constants (colours, sizes, tool IDs). | – | Every visual and tool script |
| `graph_zone.gd` | Zone resource (cells, type, rules, registration). | Resource | `Graph`, `GraphEditor`, `ZoneController`, `InspectorZone` |
| `node_data.gd` | Node resource (position, type, custom_data, shape). | Resource | `Graph`, `GraphEditor`, `InspectorNode`, many tools |
| `semantic_registry.gd` | Registry of node/edge/agent/zone types and their UI schemas. | – | `CmdSetProperty`, all inspectors, `SettingsUIBuilder` |

### Graph Tools

| Script | Description | Key Dependencies | Integrations |
|--------|-------------|------------------|--------------|
| `graph_drag_handler.gd` | Reusable drag‑to‑select component. | `GraphEditor` | `GraphToolSelect`, `GraphToolSpawner` |
| `graph_tool.gd` | Base class for all editing tools. | RefCounted, `GraphEditor` | All graph_tool_* scripts |
| `graph_tool_add_node.gd` | Click to add a node. | `graph_tool` | `GraphToolManager` |
| `graph_tool_connect.gd` | Drag between nodes to create an edge. | `graph_tool` | `GraphToolManager` |
| `graph_tool_control.gd` | Direct player control of an agent (click to move). | `graph_tool`, `AgentWalker`, `Simulation` | `GraphToolManager` |
| `graph_tool_cut.gd` | Drag across edges to sever them. | `graph_tool` | `GraphToolManager` |
| `graph_tool_delete.gd` | Click to delete nodes/edges. | `graph_tool` | `GraphToolManager` |
| `graph_tool_paint.gd` | Brush tool for painting zones or data. | `graph_tool` | `GraphToolManager` |
| `graph_tool_property_paint.gd` | Paint node/edge properties (type, weight, custom). | `graph_tool` | `GraphToolManager` |
| `graph_tool_select.gd` | Select, move, and drag nodes. | `graph_tool`, `GraphDragHandler` | `GraphToolManager` |
| `graph_tool_spawner.gd` | Spawn, select, and delete agents interactively. | `graph_tool`, `StrategyWalker`, `GraphDragHandler` | `GraphToolManager` |
| `graph_tool_stamp.gd` | Paste clipboard data as a “stamp” (pre‑fab). | `graph_tool`, `GraphClipboard` | `GraphToolManager` |
| `graph_tool_zone_brush.gd` | Paint zone cells directly. | `graph_tool` | `GraphToolManager` |

### UI

| Script | Description | Key Dependencies | Integrations |
|--------|-------------|------------------|--------------|
| `algorithm_settings_popup.gd` | Popup for configuring pathfinding algorithm parameters. | Popup, `SettingsUIBuilder`? | `InspectorAgent`, `AgentController` |
| `semantic_data_editor.gd` | Wizard for adding/removing custom properties. | – | `InspectorController` |
| `settings_window.gd` | Application settings window (themes, defaults). | – | `FileController` |
| `toolbar.gd` | Toolbar UI container. | – | `GraphToolManager` |
| `tool_button.gd` | Individual tool button with icon and highlight. | – | `toolbar.gd` |

### Utils

| Script | Description | Key Dependencies | Integrations |
|--------|-------------|------------------|--------------|
| `config_manager.gd` | Persistent user configuration (not heavily used). | – | Settings window |
| `graph_camera.gd` | Camera2D with zoom‑to‑mouse and pan. | Camera2D | `GraphEditor` |
| `graph_clipboard.gd` | Copy/paste/cut logic for nodes and edges. | `GraphEditor`, `GraphCommand` | `GraphInputHandler`, `GraphToolStamp` |
| `graph_icon_library.gd` | Provides icons for node types / tools. | – | `GraphRenderer`, tool buttons |
| `graph_input_handler.gd` | Keyboard shortcuts (undo, redo, copy, paste, delete, tools). | `GraphEditor`, `GraphClipboard` | `GraphEditor` |
| `graph_metrics.gd` | Generates the analysis report dictionary (async for heavy metrics). | `Graph`, all analysis_* scripts | `AnalysisController` |
| `graph_recorder.gd` | Sandbox clone of Graph that records commands for undo. | `Graph`, `Cmd*` | `Simulation`, `StrategyWalker`, `StrategyExecutor` |
| `graph_serializer.gd` | Serializes/deserializes graph to/from JSON, GraphML, GEXF. | `Graph`, `AgentWalker`, `GraphZone` | `FileController` |
| `graph_validator.gd` | Integrity checker – repairs orphaned edges, agent state, adjacency cache. | `Graph`, `GraphHistory` | Called on load / manually |
| `grid_renderer.gd` | Draws the background grid (adaptive to zoom). | Node2D, `GraphSettings` | `GraphEditor` |
| `priority_queue.gd` | Priority queue data structure (used by pathfinding). | RefCounted | A*, Dijkstra pathfinders |
| `seed_utils.gd` | Seed hashing and deterministic random picking. | – | `StrategyWalker`, `AgentWalker`, other generators |
| `settings_ui_builder.gd` | Generates inspector controls from a schema array. | Control | All inspectors, agent controller, strategy controller |
| `spatial_grid.gd` | Spatial hash grid for fast proximity queries. | RefCounted | `Graph` (node picking, rect selection) |
```