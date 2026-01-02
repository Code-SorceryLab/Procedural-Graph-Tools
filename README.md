
---

# Godot Procedural Graph Generator

A modular, node-based procedural generation tool built in Godot 4. It uses the **Strategy Pattern** to layer different algorithms (Walkers, DLA, MST) to generate, filter, and analyze graph structures for game development (dungeons, maps, skill trees).

## 🎮 Controls & Interaction

### Camera Controls

* **Pan:** Hold `Middle Mouse Button` and drag.
* **Zoom:** `Mouse Wheel Up/Down`.
* **Focus:** Press `F` to instantly center the camera on the entire graph.


### Editor Interactions

* **Add Node:** `Left Click` on empty space to create a node.
* **Delete:** `Right Click` on a node to remove it.
* **Drag Node:** `Left Click + Drag` to connect nodes manually.
* **Grid Snap:** Hold `Shift` while placing nodes to snap to the grid.
* **Mark Node:** `Left Click + Shift` to mark up to 2 nodes for a pathfinder to traverse. 
* **Pathfind:** `Space` to begin pathfinding. Must have 2 orange nodes reachable to start. The shortest path between them will automatically draw in **Green**.
* This uses the A* algorithm, accounting for distance/edge weights.




---

## 🛠️ Generation Strategies

Select an algorithm from the dropdown in the **Generation** tab.

### 1. Grid

Generates a standard rectangular grid of connected nodes.

* **Parameters:** `Width`, `Height` (Columns/Rows).
* **Use Case:** Base layer for mazes, tactical maps, or cellular automata tests.

### 2. Random Walker

A "Drunkard's Walk" algorithm that moves randomly to create organic paths.

* **Parameters:** `Steps` (Length of walk).
* **Toggle: "Random Branching"**
* **ON:** Picks a random existing node to start each step (creates tree-like branches).
* **OFF:** Continues from the last placed node (creates long, snake-like paths).



### 3. Diffusion Limited Aggregation (DLA)

Simulates crystal growth or coral reef formation. Particles spawn randomly and stick when they touch an existing node.

* **Parameters:** `Particles` (Number of nodes to add).
* **Toggle: "Use Box Spawning"**
* **ON:** Spawns particles at the edges of the bounding box (inward growth).
* **OFF:** Spawns particles in a circle around the center (radial growth).



### 4. Prune to MST (Filter)

Applies **Kruskal’s Algorithm** (Minimum Spanning Tree) to the *existing* graph.

* **Function:** Removes cycles/loops, turning any messy graph into a perfect maze/tree structure.
* **Requirement:** Must use **Grow (+)** button (requires existing nodes to work).
* **Use Case:** Turn a Grid into a Maze, or clean up a tangled Random Walker path.

### 5. Analyze Rooms

A semantic pass that calculates data rather than placing nodes.

* **Function:**
* Calculates **Depth** (distance from spawn) for every node.
* Identifies **Topology** (Dead Ends, Corridors, 3-Way, 4-Way).


* **Toggle: "Auto-Assign Types"**
* **ON:** Automatically assigns `RoomType` (Spawn, Boss, Treasure, Enemy) based on depth and topology.
* **Visuals:** Updates node colors (Green=Spawn, Red=Boss, Gold=Treasure).


* **Debug:** Toggle "Show Depth Numbers" in the sidebar to see the distance values rendered on nodes.

---

## ⚙️ Features & Workflow

### The "Grow" System

* **Generate Button:** Clears the current graph and runs the selected strategy from scratch.
* **Grow (+) Button:** Appends the new strategy to the *existing* graph.
* *Example:* Generate a "Grid", then use "Grow" with "Random Walker" to attach a cave tunnel to the grid.



### Save & Load System (Persistence)

Located in the **"File"** tab.

* **Save:** Serializes the entire graph (Nodes, Edges, Positions, Biomes) to a `.tres` Resource file.
* **Load:** Loads a graph from disk (bypassing cache to ensure data integrity).
* **Stability:** Uses a custom `NodeData` resource to ensure custom properties (`biome`, `depth`, etc.) are saved correctly.

### Visual Feedback

* **White (Default):** Standard nodes ("Plains" or "Empty").
* **Blue:** Newly generated nodes (from the most recent operation).
* **Orange:** Currently selected nodes.
* **Room Colors:**
* 🟢 **Green:** Spawn
* 🔴 **Dark Red:** Boss
* 🟡 **Gold:** Treasure
* 🛑 **Red:** Enemy
* 🟣 **Purple:** Shop



---

## 💻 Technical Architecture

* **Pattern:** Model-View-Controller (MVC).
* **Model:** `Graph.gd` (Data structure), `NodeData.gd` (Individual node properties).
* **View:** `GraphRenderer.gd` (Draws circles/lines/text).
* **Controller:** `GamePlayer.gd` (UI handling), `GraphEditor.gd` (State management).


* **Extensibility:** Uses `GraphStrategy` class. New algorithms can be added by creating a script that extends `GraphStrategy` and adding it to the list in `GamePlayer`.

---
