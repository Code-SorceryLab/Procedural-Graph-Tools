# Pipeline Modifiers Reference

Modifiers are the building blocks of the procedural generation pipeline. Each modifier performs a single, specific mathematical or structural operation on the graph. By stacking them, you can build complex, reproducible environments.

All modifiers execute deterministically. Every modifier possesses an optional **Deterministic Seed** setting. If left blank, the pipeline's master seed is used. If populated, that specific modifier will lock to that exact sequence, allowing you to iterate on later parts of the pipeline without changing earlier random distributions.

---

## [GEN] Generators
*Generators are destructive. When a generator executes, it completely wipes the canvas of all existing nodes, edges, and zones before building its structural pattern.*

### Generate Grid
Creates a perfect orthogonal grid of nodes and edges, spanning outward from the origin.
*   **width:** (1-50) Number of nodes on the X-axis.
*   **height:** (1-50) Number of nodes on the Y-axis.
*   **spacing_x:** (10-500) The horizontal pixel distance between nodes. Updates the global `GRID_SPACING` variable.
*   **spacing_y:** (10-500) The vertical pixel distance between nodes. Updates the global `GRID_SPACING` variable.
*   **Group into Zone:** If enabled, encapsulates the entire generated grid inside a single distinct Zone.

### Generate Polar
Creates a radial/spiderweb grid extending outward from a central hub.
*   **wedges:** (3-32) Number of directional slices or spokes around the circle.
*   **radius:** (2-50) Number of concentric rings radiating from the center.
*   **Group into Zone:** If enabled, encapsulates the entire polar graph inside a single distinct Zone.

### Generate DAG (Directed Acyclic Graph)
Generates a layered, directional graph where all edges flow forward from a starting root layer to a final sink layer. Excellent for progression trees, dialogue trees, or strictly linear dungeons.
*   **Total Nodes:** (3-100) The exact number of nodes to generate.
*   **Topological Depth:** (2-20) The number of vertical columns (layers) the nodes are distributed across.
*   **Interconnectivity:** (0-50) Number of extra forward-flowing edges to inject between random layers.
*   **Layer Spacing (X) / Sibling Spacing (Y):** Controls the geometric distance between columns and nodes within the same column.
*   **Root Type / Sink Type:** Semantic category tags automatically applied to the very first node (default `start`) and the very last node (default `boss`).
*   **Depth Data Key:** The property key automatically injected into each node's custom data tracking its layer depth (default `dag_depth`).

### Generate Scale-Free Graph
Generates a network using preferential attachment (the Barabási–Albert model), where new nodes prefer to connect to existing nodes that already have many connections. Creates highly organic "hub and spoke" topologies.
*   **Node Count:** (3-1000) Total number of nodes to generate.
*   **Initial Hub Size:** (1-20) Number of fully interconnected nodes used to seed the core of the graph.
*   **Edges per New Node:** (1-20) How many existing nodes each incoming node must attach to.
*   **Preferential Power:** (0.0-3.0) Controls the "rich get richer" scaling effect. `1.0` is classic Barabási–Albert. Higher values aggressively force new connections to the biggest central hubs.
*   **Layout Mode:** Determines initial physical node placement (`Phyllotaxis Circle` for organized geometric spirals, or `Random Cloud`).
*   **Hub Type:** Semantic category tag applied to the most highly connected nodes (default `hub`).
*   **Mark Hub Count:** (0-100) How many of the top highest-degree nodes receive the Hub Type label.
---

## [TOP] Topology
*Topology modifiers alter connections (edges) and create or delete nodes, but do not manipulate the existing physical layout of the graph.*

### Diffusion Aggregation (DLA)
Simulates organic, crystal-like growth by spawning random walkers that wander until they collide with the existing graph, at which point they lock into place as a new node and edge. If the graph is empty, it seeds a starting node at the center. Excellent for cavern or moss-like generation.
*   **particles:** (10-2000) How many new nodes to aggregate onto the structure.
*   **Spawn from Box:** If enabled, walkers spawn from a rectangular perimeter. If disabled, they spawn from a circular perimeter.
*   **gravity_bias:** (0.0-0.8) How strongly walkers are pulled toward the center. `0.0` is pure random wandering (very sparse, stringy growth). Higher values create dense, clumped structures.

### Prune to MST (Minimum Spanning Tree)
Removes all topological loops and redundant edges, leaving a "perfect maze" or branching tree structure where every node is connected by exactly one unique path.
*   **Use Kruskal (Fast):** If enabled, uses Kruskal's algorithm (prioritizes the absolute shortest edges globally). If disabled, uses Prim's algorithm (grows radially outward from a starting point).
*   **Spatial Range Multiplier:** (1.5-10.0) How far the algorithm will search for neighboring nodes to connect, relative to the global grid spacing.
*   **Target Nodes:** Choose whether to prune the entire graph, or only the nodes affected by the previous pipeline step.

### Braid Nodes
The opposite of an MST—injects loops and cycles back into a branching graph to create interconnectivity. Crucial for level design to ensure the player has multiple routes and isn't forced to backtrack endlessly.
*   **Target Nodes:** Choose whether to evaluate `All Nodes`, or `Dead-Ends Only` (nodes with 1 or 0 connections).
*   **Pipeline Mask:** Restrict braiding to all nodes or only those affected by the previous step.
*   **Braid Chance (%):** (0-100) The probability that a targeted node will successfully form a new connection.
*   **Connection Type:** If `Nearest Valid`, connects to the absolute closest physical neighbor. If `Random in Range`, picks any valid neighbor within the search radius.
*   **Max Connections:** (1-8) How many new edges a successfully braided node is allowed to cast out.
*   **Search Radius Multiplier:** (1.0-10.0) How far a node is allowed to reach to find a partner.

### Connect Components
Analyzes the graph to find completely disconnected "islands" (components) and automatically bridges them together, ensuring the entire map is accessible.
*   **Target Nodes:** Apply globally, or restrict bridge consideration to nodes touched by the previous step.
*   **Connection Strategy:** 
    *   *Nearest Pair:* Finds the two nodes across the gap that are physically closest.
    *   *Random Pair:* Bridges two random nodes from each island.
    *   *Centroid Pair:* Finds the node closest to the physical center of Island A, and bridges it to the center of Island B.
*   **Edge Direction:** Defines whether the generated bridge is `Undirected`, or one-way `Directed`.
*   **Max Components to Connect:** (-1 to 100) Stop bridging after this many islands have been merged. Set to `-1` to guarantee a 100% unified graph.

### Cellular Automata
Uses grid-based Conway-style rules to organically erode, smooth, or grow the graph. Excellent for hollowing out dense grids to create natural-looking cave systems, or smoothing jagged edges.
*   **Target Nodes:** Apply globally, or restrict simulation to nodes touched by the previous step.
*   **Initial Fill (%):** (10-100) The probability that a node survives the initial random "noise" pass before smoothing begins. (100% means starting with a solid block).
*   **Smoothing Passes:** (0-10) How many generations of the cellular automata rule to run. More passes result in smoother, more blob-like clusters.
*   **Carve Only (No Births):** If enabled, the algorithm can only destroy existing nodes, never spawn new ones. This is crucial for preserving the outer silhouette/boundaries of a graph while hollowing out its interior.

### Flow Direct (Assessor)
Calculates the topological depth (distance) from a starting root node, enforces one-way directed edges flowing outward, and automatically identifies the "deepest" dead-ends as sinks.
*   **Target Nodes:** Apply globally, or restrict to nodes touched by the previous step.
*   **Root Type Check:** The semantic type the algorithm searches for to use as the origin point (default `start`).
*   **Sink Type Target:** The semantic type automatically applied to nodes with an out-degree of 0 (default `boss`).
*   **Depth Data Key:** The property key injected into every evaluated node's custom data, storing its exact distance from the root (default `dag_depth`).

### Walker Agents
Spawns autonomous "drunkard's walk" agents that physically traverse the canvas, carving new nodes and edges as they move. Excellent for generating winding corridors or erratic, twisting mine shafts.
*   **Spawn Count:** (1-10) How many agents to spawn simultaneously.
*   **Simulated Steps:** (1-500) The lifespan of the agents.
*   **Clear Agents After:** If enabled, the agents are deleted from the simulation immediately after carving the geometry, leaving only the generated graph behind.
*   **Agent Template Overrides:** This modifier dynamically exposes the behavior parameters of the `AgentWalker` class (e.g., Movement Algorithm, Target Node ID, Forward Checking). These dictate how intelligently the agent carves its path.

### Graph Rewrite (Grammar)
An advanced L-System generator. Uses Subgraph Isomorphism to scan the graph for specific structural patterns (like triangles, dead-ends, or long corridors) and physically rewrites them based on stochastic rules. 
*   **Grammar Rule:** Select the structural rewrite rule to apply. Standard rules include:
    *   *Edge Splitter:* Finds an edge and inserts a new node perfectly in the middle.
    *   *Boss Lock:* Finds a corridor leading to a dead-end, upgrades the dead-end to a Boss room, and tags the connecting edge as a locked door.
    *   *Triangle to Hub:* Finds a loop of 3 nodes, deletes their connecting edges, and inserts a central Hub node connecting all three.
    *   *Organic Sprawl:* Finds a dead-end and grows it outward by adding a new corridor node.
*   **Generations:** (1-100) How many iterative passes to run the rule. *(e.g., Running 'Organic Sprawl' for 15 generations will watch a single node branch into a massive, sprawling dungeon).*

### Subdivide Edges
Finds existing long edges and chops them into smaller segments by inserting new nodes evenly along their length. Ideal for turning a sparse skeleton into a dense path, or adding "stepping stones" along a massive connection.
*   **Target Nodes:** Apply to all edges, or restrict only to edges that were touched by the previous pipeline step.
*   **Subdivide Chance (%):** (0-100) Probability that an evaluated edge will be subdivided.
*   **Cuts per Edge:** (1-10) How many new nodes to insert. (e.g., 1 cut turns 1 long edge into 2 shorter segments).
*   **Edge Direction:** Dictates how the new sub-edges behave topologically:
    *   *Match Original:* Perfectly inherits the directionality and custom data of the original long edge.
    *   *Force Bi-Directional / Forward / Reverse:* Overrides the original edge direction.
*   **New Node Type:** The semantic category automatically applied to the newly spawned nodes.

### Prune Leaves
A cleanup modifier that iteratively strips away "dead-ends" (leaf nodes). Useful for turning a messy, sprawling organic cavern into a clean, focused central path by removing all the useless tiny branches.
*   **Target Nodes:** Apply globally, or restrict to nodes touched by the previous step.
*   **Prune Iterations:** (1-10) How many layers deep to prune. (e.g., 1 iteration removes the immediate dead-ends. 2 iterations removes the dead-ends, and then removes the *new* dead-ends that were created by the first cut).
*   **Protect Special Rooms:** If enabled, nodes with special semantic types (like `spawn`, `boss`, `treasure`) are immune to pruning, even if they are dead-ends. Only `empty` and `corridor` nodes are deleted.

### Fuse Nodes
Contracts the graph by merging two distinct nodes into a single, unified node. Useful for turning a dense cluster of tiny rooms into one massive "hub" room, or simplifying a complex mesh.
*   **Fusion Source:** How the algorithm picks which nodes to fuse together:
    *   *Random Edge:* Picks a random existing edge and fuses the two nodes it connects.
    *   *All Edges (Nearest):* Evaluates all existing edges and fuses the pair that are physically closest to each other first.
    *   *Spatial Clusters:* Ignores topology completely. Merges *any* two nodes that are physically closer than the **Spatial Radius Multiplier**, even if they didn't have an edge between them.
*   **Max Fusions:** (1-1000) The maximum number of fusions to allow per execution. Set to `-1` to fuse everything possible.
*   **Result Position:** When Node A and Node B fuse into Node C, where does Node C go? (Midpoint, Keep A's position, or Keep B's position).
*   **Merge Properties:** How to resolve conflicting semantic Types and Custom Data. (Prefer A's data, Prefer B's data, or intelligently Combine them).
*   **Duplicate Edges:** If A and B both connected to Node Z, the new fused node will have two edges going to Node Z. You can *Keep First*, or *Average Weight* of the two.

---

## [GEO] Geometry
*Geometry modifiers physically move nodes across the 2D canvas, but do not add, delete, or alter any topological connections.*

### Position Jitter
Applies a random spatial offset to nodes. Crucial for turning rigid, artificial grids into organic, natural-looking layouts.
*   **Target Nodes:** Apply globally, or restrict only to nodes touched by the previous step.
*   **Max X / Y Offset:** (0.0-200.0) The maximum pixel distance a node can be pushed on either axis.
*   **Gaussian Distribution:** If enabled, offsets follow a bell curve, meaning most nodes will only move a little bit, and very few will move the maximum distance. If disabled, uses pure uniform randomness.

### Relax (Buoyancy / Spring)
A powerful physics solver that forces the graph to untangle itself. It treats all edges as springs trying to reach an ideal length (Attraction), while treating all nodes as magnets pushing away from each other (Repulsion). 
*   **Target Nodes:** If restricted via pipeline mask, the unmasked nodes are frozen in place and act as solid anchors, while the masked nodes pull against them.
*   **Solver Iterations:** (1-500) How many physics ticks to simulate.
*   **Spring Strength (Attraction):** (0.01-0.5) How aggressively connected nodes pull toward each other.
*   **Repulsion Force:** (100-5000) How aggressively all nodes push away from each other to prevent overlapping.
*   **Ideal Spring Length:** (10-500) The target pixel length every edge is trying to achieve.

#### Buoyancy Relax (Advanced Engine)
An alternative integration of the physics engine that includes destructive collision rules. 
*   **Enable Node Fusing:** If true, nodes that physically crash into each other during the simulation are merged into a single node.
*   **Enable Edge Snapping:** If true, edges that are stretched too far by the physics engine will snap (delete themselves).
*   **Auto-Crystallize:** If true, nodes that reach equilibrium will "freeze" in place, dramatically speeding up performance on massive graphs.

---

## [SEM] Semantic
*Semantic modifiers do not alter topology or geometry. They assign data, types, labels, weights, or zones to the graph, heavily influencing how the graph is later interpreted by the Rasterizer and Agent Simulator.*

### Biome Flood Fill
Organically paints semantic Categories (Types) across the graph using a seeded flood-fill algorithm. 
*   **Use Spatial Fill (XY):** If true, biomes expand radially based on physical pixel distance. If false, biomes expand topologically by traveling along connected edges (corridors).
*   **Flow Mode:** Determines if the fill respects one-way directed edges or treats all edges as bidirectional corridors.
*   **Max Expansion Steps:** (0-50) Limits how far a biome can grow from its seed. `0` allows infinite growth until the graph is filled.
*   **Evenly Space Seeds:** If enabled, the algorithm mathematically distributes the starting points so biomes have roughly equal room to grow.
*   **Biome Palette (UI Popup):** Allows you to configure exactly how many seed points to drop, which biomes are allowed to spawn, and their relative **Growth Speeds** (e.g., setting a 'corruption' biome to Speed 3 will cause it to engulf the map three times faster than a 'forest' biome at Speed 1).

### Edge Weights from Distance
Automatically calculates the physical pixel distance of an edge on the canvas and assigns that value to the edge's `weight` property. This is critical if you want algorithms like the Minimum Spanning Tree (MST) or Pathfinding A* to respect actual geometric distance rather than just counting "hops."
*   **Scale Factor:** (0.01-10.0) Multiplies the raw pixel distance to produce the final weight.
*   **Minimum / Maximum Weight:** Clamps the resulting calculation to ensure no weights fall outside your gameplay or pathfinding limits. Set max to `-1` for no ceiling.

### Distribute DAG Locks
Scans a Directed Acyclic Graph (DAG) using topological depth to intelligently distribute locked doors and required keys. Guarantees that a key is always placed in a layer *preceding* its corresponding lock, ensuring the dungeon is 100% solvable.
*   **Number of Locks:** (1-20) How many colored lock-and-key pairs to distribute across the graph.
*   **Depth Data Key:** The custom data key containing the node's topological depth (usually generated by the *Flow Direct* modifier).
*   **Lock Prop Key / Item Prop Key:** The semantic property names injected into the graph to track the lock and the required key (default `requires` and `items`).

### Distribute Logic Gates
Turns the graph into a functional dependency or circuit board. Scans the graph for any node that has multiple incoming paths (an in-degree > 1) and assigns it a logic gate property.
*   **AND Gate Probability:** (0.0-1.0) The chance that a converging node becomes an `AND` gate (meaning the player must complete ALL incoming paths to proceed) versus an `OR` gate (meaning the player only needs to complete ONE incoming path).