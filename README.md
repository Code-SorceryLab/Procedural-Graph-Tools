# Godot Procedural Graph Generator

A modular, node-based procedural generation research platform built in Godot 4. This tool utilizes a **Controller-Component Architecture**, the **Strategy Pattern**, and the **Command Pattern** to layer various algorithms (Behavior-Based Walkers, Cellular Automata, Minimum Spanning Trees) for the generation, filtering, and analysis of graph structures.

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

### Persistence (Serialization v1.3)
Located in the **File** tab.
* **Database-Style Saving:** The system serializes the graph as a comprehensive database, preserving **Meta-Data**, **Agent History**, and **Semantic Data**.
* **Property Schema:** The save file includes a `schema` header that defines custom data fields created by the user (e.g., "is_magma": bool). This allows the Inspector to reconstruct the UI for custom properties automatically upon loading.
* **Smart Edge Saving:** Automatically detects symmetry. Identical `A->B` and `B->A` edges are saved as single "Bi-Directional" connections, while asymmetric weights/data are saved as distinct "Directed" edges.
* **Dynamic Legends:** The save file includes a metadata header defining the specific **Room Types** (IDs, Names, and Colors) used in that specific dungeon.

---

## 🏗️ Technical Architecture

### Controller-Component Pattern
The application is composed of distinct, modular controllers. Each subsystem is an independent Node within the scene tree.

* **StrategyController:** Manages the execution of generation algorithms using the **SettingsUIBuilder** to dynamically generate parameter interfaces.
* **AgentController:** Handles the lifecycle, simulation ticks, and visual synchronization of autonomous `AgentWalker` entities.
* **InspectorController:** Handles the real-time observation of node/edge/agent data, supporting **Multi-Selection** and **Mixed Value** editing.
* **FileController:** Manages the Gatekeeper logic (unsaved changes protection) and JSON serialization.
* **GraphEditor:** The central facade that coordinates the visual renderer, data model, and Command history.

### Core Data Model: "Semantic Graph"
The graph utilizes a **Hybrid Storage Model** to support advanced navigation features and arbitrary game logic.
* **Adjacency Lists:** Used for high-speed traversals (A*, BFS) and connectivity checks.
* **Semantic Dictionary (Custom Data):** * **Nodes:** Support arbitrary tags (e.g., `is_magma`, `loot_tier`) via a `custom_data` dictionary.
    * **Edges:** Store rich data dictionaries allowing for Logic Properties (e.g., `lock_level`, `type="Door"`) alongside standard Weights.

### Command Pattern & Simulation
To support safe Undo/Redo alongside complex algorithms, the system uses a dual-layer approach:
* **GraphRecorder:** A wrapper that intercepts algorithm operations. It runs the simulation logic instantly (so Walkers can "see" the grid) but captures the *intent* as `GraphCommand` objects.
* **Buffered Reality:** Strategies like "Walker Batch" utilize a virtual buffer to pre-calculate IDs, ensuring deterministic generation even when spawning hundreds of agents simultaneously.

### Namespaced ID System (Traceability)
Nodes are identified by structured strings indicating their origin, ensuring research-grade determinism.

* **Grid Strategy:** `grid:x:y` (e.g., `grid:5:10`)
* **Walker Strategy:** `walk:ticket_id:step_index` (e.g., `walk:5:42`). Uses a persistent "Ticket Counter" to ensure Agent IDs never duplicate or reset, even after reloading from disk.
* **Manual Placement:** `man:sequence_id` (e.g., `man:5`)

---

## 🎮 Interaction & Controls

### Camera & Navigation
* **Pan:** Hold Middle Mouse Button and drag.
* **Zoom:** Mouse Wheel Up or Down.
* **Focus Graph:** Press `F` to center the camera on all existing nodes.

### Unified Editor Tools
Tools are selected via the top Toolbar. All tools are integrated with the Undo system.

* **Select Tool:** Click to select, drag to move. Supports **Node, Edge, and Agent Selection**. Use Shift/Ctrl modifiers for Box Selection or Multi-Select.
* **Add Node Tool:** Left Click to place a manual node.
* **Connect Tool:** Click and drag between two nodes to create an edge.
* **Delete Tool:** Click a node/agent to remove it.
* **Paint Tool:** Click and drag to rapidly draw nodes (Snake style). Auto-connects to the previous node in the stroke.
* **Knife Cut:** Click and drag a line to sever all edges it crosses.
* **Type Brush:** Paint semantic data (e.g., "Enemy", "Spawn") onto existing nodes. Right-click to cycle through the Legend.
* **Agent Spawner:** Click to Place down Agents, select them, or delete them. Right-click to cycle through modes.

### Inspector & Analysis
The right-hand sidebar features a context-aware Inspector tab generated by the `SettingsUIBuilder`.

* **Dynamic Property System (No-Code):** Users can define new custom data fields (e.g., "Health", "TeamID") via the **Property Wizard**. These definitions are saved to a global registry, and the Inspector automatically generates UI inputs (Checkboxes, Color Pickers, SpinBoxes) for them.
* **Schema Management:** Includes a management tab to list, delete, and **Purge** (deep clean) custom definitions from the graph data.
* **Multi-Selection:** Supports selecting 50+ items at once. The Inspector intelligently detects **Mixed Values** (e.g., different weights) and allows for bulk unification.
* **Walker Live-Edit:** * Modify Agent configurations (Goal, Speed, Pathfinding Algo) in real-time.
    * View Read-Only statistics like **Steps Taken** vs **Step Limit**.
    * Toggle **Endless Mode** (Step Limit: -1) for continuous simulation.

---

## 🛠️ Generation Strategies

Strategies are selected via the **Generation** tab.

### 1. Grid Layout (Generator)
Creates a Cartesian grid of nodes. Parameters: Width, Height.

### 2. Autonomous Agents (Walker Simulation)
Spawns persistent agents driven by a **Modular Brain System**.
* **Behaviors:** Agents use specific logic modules: `BehaviorSeek` (A* pathing), `BehaviorGrow` (Expansion), `BehaviorWander` (Random).
* **Decorators:** Logic can be wrapped, e.g., `BehaviorDecoratorPaint` allows an agent to change tile types as it walks.
* **Persistence:** Agents retain full history and state between ticks, allowing for "Pause and Resume" workflows.

### 3. Diffusion Limited Aggregation (Generator)
Simulates organic growth by spawning particles that stick to existing clusters. Parameters: Particles, Box Spawning Toggle.

### 4. Polar Wedges (Generator)
Generates a radial structure divided into angular sectors. Useful for creating hub-and-spoke layouts or circular arenas.

### 5. Cellular Automata (Generator/Decorator)
Applies simulation rules (e.g., Game of Life, Cave Growth) to smooth out noise or create organic clusters within a grid.

### 6. Minimum Spanning Tree (Decorator)
Applies Kruskal's or Prim's algorithm to the existing graph structure to remove cycles.

### 7. Analyze Rooms (Analyzer)
Performs a Breadth-First Search (BFS) to calculate node depth and topology (Dead Ends, Corridors, Junctions).

---

## 🧪 Testing & Verification

This project includes a dedicated **Test Runner** (`tests/TestRunner.tscn`) to validate core architectural pillars.

### Coverage Matrix
* **Data Integrity:** Verifies ID state reconstruction and "Hybrid ID" persistence after loading `.json` files.
* **Strategy Logic:** Proves that Generators clear the board while Decorators append correctly.
* **Algorithm Safety:** Regression tests for edge cases (e.g., MST clearing edges, DLA bounds).
* **Undo/Redo:** (Implicit) The architecture is verified by the GraphRecorder's ability to accurately reconstruct simulation states.