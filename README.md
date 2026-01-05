# Godot Procedural Graph Generator

A modular, node-based procedural generation research platform built in Godot 4. This tool utilizes a **Controller-Component Architecture** and the **Strategy Pattern** to layer various algorithms (Random Walkers, Diffusion Limited Aggregation, Minimum Spanning Trees) for the generation, filtering, and analysis of graph structures.

It is designed for determinism and traceability, allowing developers to inspect the provenance of every node and experiment with layering destructive and non-destructive algorithms.

## AI Usage Disclaimer
This project, including the codebase and this documentation, was developed with the assistance of an AI thought partner (Google Gemini). All architectural decisions, logic verification, and implementation details were reviewed and refined by the human developer, Charon.

---

## ⚙️ Workflow Features

### The "Grow" Workflow
* **Generate Button:** Executes the strategy logic. If the strategy is a **Generator**, it clears the graph first. If it is a **Decorator**, it applies to the current graph.
* **Grow (+) Button:** Forces an additive execution. It instructs the strategy to append to the current graph regardless of its default behavior (useful for attaching a Walker path to a Grid).

### Pathfinding
Located in the **Pathfinding** tab.
1.  Select a single node and click **"Set Start"**.
2.  Select a different node and click **"Set End"**.
3.  Click **"Run Path"** to visualize the A* route in green.

### Persistence
Located in the **File** tab.
* **Save/Load:** Serializes the full graph state, including custom NodeData resources and visual coordinates, to a standard `.tres` file format.

---

## 🏗️ Technical Architecture

### Controller-Component Pattern
The application has been refactored from a monolithic manager into distinct, modular controllers. Each subsystem is an independent Node within the scene tree, allowing for easy enabling or disabling of features without code changes.

* **StrategyController:** Manages the execution of generation algorithms, parameter collection, and the "Smart Reset" logic.
* **ToolbarController:** Bridges the UI toolbar inputs to the active Editor tool state.
* **InspectorController:** Handles the real-time observation of node data, supporting both single-node detail and multi-node group analysis.
* **FileController:** Manages serialization and deserialization of the graph state to disk.
* **PathfindingController:** Manages A* navigation queries and visual debugging of paths.

### Namespaced ID System (Traceability)
To ensure research-grade determinism, nodes are no longer identified by simple auto-incrementing integers. IDs are structured strings that indicate the algorithm of origin and the generation logic.

* **Grid Strategy:** `grid:x:y` (e.g., `grid:5:10`)
* **Walker Strategy:** `walk:agent_id:step_index` (e.g., `walk:0:42`)
* **DLA Strategy:** `dla:x:y` (e.g., `dla:15:-3`)
* **Manual Placement:** `man:sequence_id` (e.g., `man:5`)

This ensures that running a deterministic seed produces the exact same ID structure every time, preventing "ID drift" during debugging or save/load cycles.

### Intelligent Reset & Collision Policies
The system distinguishes between **Generators** (which require a blank canvas) and **Decorators** (which require existing geometry).

* **Generators (Grid, Walker, DLA):** By default, these clear the graph when "Generate" is clicked.
* **Decorators (MST, Analyze):** These operate additively, modifying existing nodes without deletion.
* **Collision Policy:** Strategies include a **"Merge Overlaps"** toggle.
    * **Merge (True):** Algorithms connect to existing nodes if they land on the same coordinate.
    * **Layer (False):** Algorithms generate new nodes on top of existing ones, allowing for complex overlapping structures (e.g., bridges over rivers).

---

## 🎮 Interaction & Controls

### Camera & Navigation
* **Pan:** Hold Middle Mouse Button and drag.
* **Zoom:** Mouse Wheel Up or Down.
* **Focus Graph:** Press `F` to center the camera on all existing nodes.

### Unified Editor Tools
Tools are selected via the top Toolbar.

* **Select Tool:**
    * **Click Node:** Selects a single node.
    * **Drag Node:** Moves the selected node (IDs remain immutable; only position changes).
    * **Click Empty Space + Drag:** Creates a Box Selection.
    * **Hold Shift:** Adds to the current selection.
    * **Hold Ctrl:** Removes from the current selection.
* **Add Node Tool:** Left Click to place a manual node (`man:ID`).
* **Connect Tool:** Click and drag between two nodes to create an edge.
* **Delete Tool:** Click a node to remove it.

### Inspector & Analysis
The right-hand sidebar features a context-aware Inspector tab.

* **No Selection:** Displays placeholder status.
* **Single Selection:** Displays Node ID (Provenance), Position, Type, and a list of connected neighbors.
* **Multi-Selection:** Displays Group Statistics:
    * **Count:** Total selected nodes.
    * **Center:** Geometric center of the selection.
    * **Bounds:** Width and Height of the selection area.
    * **Density:** Number of internal edges (connections between selected nodes).

---

## 🛠️ Generation Strategies

Strategies are selected via the **Generation** tab.

### 1. Grid Layout (Generator)
Creates a Cartesian grid of nodes.
* **Parameters:** Width, Height.
* **Collision:** Implicitly merges based on coordinates.
* **ID Schema:** `grid:col:row`

### 2. Random Walker (Generator)
Simulates an autonomous agent moving across the canvas.
* **Parameters:** Steps (Duration of walk).
* **Merge Overlaps (Toggle):** Determines if the walker connects to existing nodes or layers on top of them.
* **ID Schema:** `walk:agent:step`

### 3. Diffusion Limited Aggregation (Generator)
Simulates organic growth by spawning particles that stick to existing clusters.
* **Parameters:** Particles (Target count).
* **Use Box Spawning (Toggle):** Spawns from the bounding box edges (inward) vs. radial spawning (outward).
* **ID Schema:** `dla:x:y`

### 4. Minimum Spanning Tree (Decorator)
Applies Kruskal's or Prim's algorithm to the existing graph structure.
* **Function:** Removes redundant edges to eliminate cycles, producing a "perfect maze" or tree structure.
* **Reset Behavior:** Non-destructive. Requires an existing graph.

### 5. Analyze Rooms (Analyzer)
A semantic pass that calculates graph topology.
* **Function:** Performs a Breadth-First Search (BFS) to calculate node depth from the center.
* **Topology Detection:** Identifies Dead Ends, Corridors, and Junctions based on neighbor count.
* **Auto-Assign Types (Toggle):** Heuristically assigns `RoomType` (Spawn, Boss, Treasure, Enemy) based on depth and isolation.

---

## 🧪 Testing & Verification

This project includes a dedicated **Test Runner** (`tests/TestRunner.tscn`) to validate core architectural pillars and prevent regression during refactoring.

While not an exhaustive coverage of every possible user interaction, the test suite verifies the critical logic paths required for a stable research platform.

### How to Run Tests
1. Open the project in Godot.
2. Navigate to `tests/TestRunner.tscn`.
3. Press **F6** (Run Current Scene).
4. Results will be printed to the Output Console.

### Coverage Matrix
The test suite currently verifies the following layers:

* **Layer 1: Data Integrity (Critical)**
    * **ID State Reconstruction:** Verifies that the Editor correctly scans a loaded graph (e.g., containing `man:5`) and restores the internal counters to prevent Duplicate ID collisions.
    * **CRUD Operations:** Validates node creation and deletion logic.
* **Layer 2: Strategy Logic**
    * **Smart Reset:** Proves that **Generators** (Grid) clear the board, while **Append Mode** (Walker) correctly layers new nodes on top.
    * **MST Regression:** Specifically verifies that the Minimum Spanning Tree algorithm effectively removes cycles without crashing (regression test for `clear_edges` bug).
    * **DLA Simulation:** Verifies that random simulation algorithms respect particle limits and bounds.
* **Layer 3: Analysis Logic**
    * **BFS Accuracy:** Manually verifies that the "Analyze Rooms" algorithm correctly calculates depth from a known center and assigns Semantic Types (Spawn/Boss) correctly.

> **Note on Stability:** While these tests ensure the logic and math are sound, complex permutations of cross-strategy layering followed by serialization cycles may still yield edge cases. Always save your work before attempting complex "stress tests" of the generator.