# Graph Editor & Procedural Dungeon Laboratory

A unified environment for **graph authoring**, **procedural generation**, **agent simulation**, **rasterization**, and **analytical research**. Designed for both game developers and academic researchers, this tool bridges the gap between abstract graph theory and playable dungeon layouts.

---

## Overview

This application lets you:

- **Edit graphs** with a full suite of interactive tools and undoable commands.
- **Compose procedural generation pipelines** from modular, deterministic transformations.
- **Simulate agents** with behaviors, inventories, and lock‑and‑key mechanics.
- **Rasterize graphs into tilemaps** with custom rooms, biomes, structures, and progression systems.
- **Analyze graphs** using both lightweight and heavy mathematical metrics.
- **Batch experiment** across parameter sweeps with reproducible seeds.

All data is stored in a custom canonical graph model and serialized to JSON, GraphML, or GEXF.

---

## Core Features

### 1. Graph Editing & Interaction

- Full graph authoring with tools for nodes, edges, zones, and agents.
- Advanced selection: rectangle, lasso, multi‑select, zone‑based, and agent selection.
- Transform nodes with move, scale, and rotate handles.
- **Undo/redo for every mutation** via a command pipeline.
- Clipboard operations and prefab stamping.
- Zone system for geographic and logical grouping with traversal rules.
- Contextual hover tooltips for nodes, edges, agents, and zones.

![A portion of a radially shaped graph is selected and dragged.](Documentation/images/BasicGraphEditing.png?raw=true "Graph Editing")
A portion of a radially shaped graph is selected and dragged.

### 2. Procedural Generation Pipeline

- Stack‑based modifier system for building complex generation recipes.
- Built‑in modifiers:
  - **Generators**: Grid, Polar, DAG, Scale‑Free
  - **Topology**: Braid, CA, Connect Components, DLA, Edge Subdivide, Flow Direct, Fuse Nodes, Grammar, MST, Prune Leaves, Walker Agents
  - **Geometry**: Jitter, Buoyancy Relax
  - **Semantic**: Biome Flood Fill, DAG Locks, Distance‑to‑Edge Weights, Logic Gates
- Save and load pipeline presets as JSON.
- Threaded background execution with live progress.
- Deterministic seeds for every step.

![The pipeline in effect. Note how the jitter step only affects nodes produced by the diffusion aggregation step, resulting in targeted transformation control.](Documentation/images/PipelineExample.png?raw=true "Pipeline Example")
The pipeline in effect. Note how the jitter step only affects nodes produced by the diffusion aggregation step, resulting in targeted transformation control.

### 3. Agent Simulation & Behavior

- **AgentWalker** core: identity, state, history, inventory, and local RNG.
- Behavior modes: Hold, Wander, Grow, Seek, Maze Generation, Solver, Manual.
- Capabilities: Motor, Painter, Builder, Inventory.
- Simulation loop with speed control and undoable state changes.
- Lock‑and‑key logic using edge `requires` and node `items`.
- Agent spawner tool with direct manipulation and manual control.

### 4. Rasterizer & Tilemap Generation

- Full pipeline from rooms to walls, including:
  - Room allocation and merging
  - Corridor routing (organic or orthogonal)
  - Cellular smoothing and erosion
  - Zone decoration and distance mapping
  - Structure placement and entity scattering
  - Progression solving (lock & key distribution)
  - Textural WFC overlays
- **Custom room designer** with exact tiles, doorways, reserved paths, and embedded structures.
- **Structure & scatter sets** with weighted distribution.
- **Biome overrides** for shapes, routing, CA, spawn decks, and WFC palettes.
- **Progression solver** that ensures solvability, with optional vaults and shortcuts.
- **Dynamic regeneration** of selected nodes/edges while preserving surrounding context.
- **Timeline & VCR** to step through each rasterization pass.
- **Headless validation** with flood‑fill reachability and lock simulation.
- **Trigger‑Based Regeneration** – Placeable world triggers that cause targeted regeneration of selected nodes/edges, preserving the surrounding topology while dynamically altering the dungeon.
- **Temporally Aware Progression** – Locks and keys that adapt to the player’s current location and inventory across regenerations; some locks require trigger activation before their key is even placed, creating evolving, replayable progression puzzles.

![Rasterization example using a base graph for topology. Note that different colour nodes can house different biome settings, allowing for diverse generations.](Documentation/images/RasterExample.png?raw=true "Rasterization Example")
Rasterization example using a base graph for topology. Note that different colour nodes can house different biome settings, allowing for diverse generations.


### 5. Analysis & Metrics

- Topological metrics: density, components, planarity, articulation points, bridges, betweenness, k‑core, spectral, entropy.
- Spatial metrics: bounds, area, cell usage.
- Agent metrics: spawn/completion, steps, rates.
- Markov flow analysis.
- Zone metrics.
- Heavy algorithms: chromatic number, longest path, Eulerian, Louvain, treewidth.
- Formatted report dashboard with export to TXT/CSV.

### 6. Semantic System & Customization

- SemanticRegistry for categories and properties with display modes (hidden, label, badge).
- Custom data editor with protection for core items.
- Property painting tools for nodes and edges.
- Persistent storage for all user definitions and overrides.

### 7. File Management & Interchange

- Save/load graphs in JSON, GraphML, and GEXF.
- Prefab workflow for reusing subgraphs.
- Pipeline recipe import/export.
- Experiment CSV export.

### 8. UI/UX & Editor Environment

- Customizable panels with Zen mode and persistent layout.
- Toolbar and topbar with menus and simulation controls.
- Context‑sensitive inspectors for nodes, edges, agents, and zones.
- Dedicated rasterizer tabs: Generator, Timeline, Report, Validator.

### 9. Research & Reproducibility

- Deterministic seeds across all systems.
- Batch experiment runner with multi‑threaded execution.
- Headless validation for automatic solvability checks.
- Dynamic validation – The validator acts as a persistent player simulation that survives world regenerations, re‑exploring from the trigger location and maintaining inventory/explored state.
---


## Getting Started

<!-- TODO: Add basic instructions for running the project, loading a sample graph, and generating a raster dungeon. -->

---

## License

<!-- TODO: Add license information. -->