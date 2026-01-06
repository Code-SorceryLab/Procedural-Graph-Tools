# Godot Procedural Graph Generator

A modular, node-based procedural generation research platform built in Godot 4. This tool utilizes a **Controller-Component Architecture**, the **Strategy Pattern**, and the **Command Pattern** to layer various algorithms (Random Walkers, Diffusion Limited Aggregation, Minimum Spanning Trees) for the generation, filtering, and analysis of graph structures.

It is designed for determinism and traceability, allowing developers to inspect the provenance of every node, experiment with layering destructive and non-destructive algorithms, and safely undo/redo complex operations.

## AI Usage Disclaimer
This project, including the codebase and this documentation, was developed with the assistance of an AI thought partner (Google Gemini). All architectural decisions, logic verification, and implementation details were reviewed and refined by the human developer, Charon.

---

## ⚙️ Workflow Features

### The "Grow" Workflow
* **Generate Button:** Executes the strategy logic. If the strategy is a **Generator**, it clears the graph first. If it is a **Decorator**, it applies to the current graph.
* **Grow (+) Button:** Forces an additive execution. It instructs the strategy to append to the current graph regardless of its default behavior (useful for attaching a Walker path to a Grid).

### Robust Undo/Redo
* **Transaction-Based History:** Supports robust undo/redo for complex actions. A single "Undo" step can revert an entire brush stroke, a generated algorithm, or a bulk edit.
* **Atomic Toggle:** Users can switch to "Atomic Mode" in settings to undo actions one-by-one (e.g., undoing a single pixel of a brush stroke) for granular control.
* **Smart Camera:** The system intelligently decides when to refocus the camera (e.g., after generating a new dungeon) versus when to keep it static (e.g., undoing a minor paint action).

### Persistence
Located in the **File** tab.
* **JSON Serialization:** Serializes the full graph state to a human-readable `.json` format.
* **Dynamic Legends:** The save file includes a metadata header defining the specific **Room Types** (IDs, Names, and Colors) used in that specific dungeon. This allows Custom Room Types (e.g., "Magma", "Ice") to persist across sessions without code changes.

---

## 🏗️ Technical Architecture

### Controller-Component Pattern
The application is composed of distinct, modular controllers. Each subsystem is an independent Node within the scene tree.

* **StrategyController:** Manages the execution of generation algorithms and the "Smart Reset" logic.
* **ToolbarController:** Bridges the UI toolbar inputs to the active Editor tool state.
* **InspectorController:** Handles the real-time observation of node data and synchronizes UI inputs with the Undo history.
* **FileController:** Manages the Gatekeeper logic (unsaved changes protection) and JSON serialization.
* **GraphEditor:** The central facade that coordinates the visual renderer, data model, and Command history.

### Command Pattern & Simulation
To support safe Undo/Redo alongside complex algorithms, the system uses a dual-layer approach:
* **GraphRecorder:** A wrapper that intercepts algorithm operations. It runs the simulation logic instantly (so Walkers can "see" the grid) but captures the *intent* as `GraphCommand` objects.
* **CmdBatch:** Groups these commands into transactions.
* **Execution:** Commands are executed only if the simulation succeeds, preventing "ghost data" in the Undo stack.

### Namespaced ID System (Traceability)
Nodes are identified by structured strings indicating their origin, ensuring research-grade determinism.

* **Grid Strategy:** `grid:x:y` (e.g., `grid:5:10`)
* **Walker Strategy:** `walk:agent_id:step_index` (e.g., `walk:0:42`)
* **Manual Placement:** `man:sequence_id` (e.g., `man:5`)

---

## 🎮 Interaction & Controls

### Camera & Navigation
* **Pan:** Hold Middle Mouse Button and drag.
* **Zoom:** Mouse Wheel Up or Down.
* **Focus Graph:** Press `F` to center the camera on all existing nodes.

### Unified Editor Tools
Tools are selected via the top Toolbar. All tools are integrated with the Undo system.

* **Select Tool:** Click to select, drag to move. Supports Box Select and Shift/Ctrl modifiers.
* **Add Node Tool:** Left Click to place a manual node.
* **Connect Tool:** Click and drag between two nodes to create an edge.
* **Delete Tool:** Click a node to remove it.
* **Paint Tool:** Click and drag to rapidly draw nodes (Snake style). Auto-connects to the previous node in the stroke.
* **Knife Cut:** Click and drag a line to sever all edges it crosses.
* **Type Brush:** Paint semantic data (e.g., "Enemy", "Spawn") onto existing nodes. Right-click to cycle through the Legend.

### Inspector & Analysis
The right-hand sidebar features a context-aware Inspector tab.

* **Single Selection:** Displays Node ID, Position, and Neighbors. Features a **Dynamic Dropdown** populated by the current Legend.
* **Multi-Selection:** Displays Group Statistics (Center, Bounds, Density) and allows for **Bulk Type Editing** (changing 50 nodes to "Lava" in one click).

---

## 🛠️ Generation Strategies

Strategies are selected via the **Generation** tab.

### 1. Grid Layout (Generator)
Creates a Cartesian grid of nodes. Parameters: Width, Height.

### 2. Random Walker (Generator)
Simulates an autonomous agent moving across the canvas. Parameters: Steps, Merge Toggle.

### 3. Diffusion Limited Aggregation (Generator)
Simulates organic growth by spawning particles that stick to existing clusters. Parameters: Particles, Box Spawning Toggle.

### 4. Polar Wedges (Generator)
Generates a radial structure divided into angular sectors. Useful for creating hub-and-spoke layouts or circular arenas.

### 5. Minimum Spanning Tree (Decorator)
Applies Kruskal's or Prim's algorithm to the existing graph structure to remove cycles.

### 6. Analyze Rooms (Analyzer)
Performs a Breadth-First Search (BFS) to calculate node depth and topology (Dead Ends, Corridors, Junctions).

---

## 🧪 Testing & Verification

This project includes a dedicated **Test Runner** (`tests/TestRunner.tscn`) to validate core architectural pillars.

### Coverage Matrix
* **Data Integrity:** Verifies ID state reconstruction after loading `.json` files.
* **Strategy Logic:** Proves that Generators clear the board while Decorators append correctly.
* **Algorithm Safety:** Regression tests for edge cases (e.g., MST clearing edges, DLA bounds).
* **Undo/Redo:** (Implicit) The architecture is verified by the GraphRecorder's ability to accurately reconstruct simulation states.