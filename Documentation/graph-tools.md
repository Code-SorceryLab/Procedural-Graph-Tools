# Graph Tools Reference

The left toolbar provides the interactive tools for sketching, editing, and annotating your graph. Select a tool by clicking its icon or using its associated keyboard shortcut.

---

## Core Editing Tools

### Select 
The primary tool for interacting with the canvas. It handles selection, movement, and transformations.

**Selecting**
*   **Click:** Select a node, edge, agent, or zone.
*   **Shift + Click:** Add to the current selection.
*   **Ctrl + Click:** Remove/toggle from the current selection.
*   **Right-Click:** Instantly clear the entire selection.
*   **Drag on empty space:** Region selection. By default, this draws a **Rectangle**. You can change the mode to **Lasso** in the tool options.

**Moving Nodes**
*   **Drag a node:** Moves the node. If multiple nodes are selected, the entire group moves together.
*   **Shift + Drag:** Snaps movement to the background grid.

### Add Node
Places new nodes onto the canvas.
*   **Click empty space:** Spawns a new node.
*   **Shift + Hover/Click:** Displays a preview ghost and snaps the new node perfectly to the grid.

### Connect
Draws topological edges between nodes.
*   **Drag from Node A to Node B:** Creates an edge. A rubber-band line previews the connection while dragging.

### Knife Cut
Severs existing edges without deleting the connected nodes.
*   **Drag across edges:** Draws a slash line. Any edge intersecting this line highlights red and is instantly severed upon releasing the mouse.

### Delete
Removes elements from the graph.
*   **Click a node:** Deletes the node and any connecting edges.
*   **Batch Delete:** If you click a node that is currently part of a multi-selection, the tool will instantly delete **all** currently selected nodes.

---

## Transform Mechanics

When **two or more nodes** are selected, a bounding box with transform handles automatically appears around the group.

### Scaling
Drag the handles on the edges or corners of the transform box to scale the topological footprint of the selected nodes.
*   **Shift:** Constrains the scale to a uniform aspect ratio.
*   **Ctrl:** Scales outward from the center pivot rather than the opposite edge.
*   **Alt:** Snaps the scaled node positions to the grid.

### Rotating
Hover just outside any of the four corners until the cursor becomes a pointing hand, then drag to rotate the selected nodes around their collective center.
*   **Shift:** Snaps the rotation to rigid 15-degree increments.
*   **Alt:** Snaps the final rotated node positions to the grid.

---

## Rapid Painting & Annotation

### Paint
Quickly sketches connected pathways. Dragging creates a continuous chain of nodes and edges in a single stroke.
*   **Options:** Configure Brush Size (1-10) and Shape (Circle, Square) in the tool options.
*   **Shift + Drag:** Snaps the painted nodes strictly to the grid.
*   **Freehand Drag:** Paints fluidly based on minimum distance spacing.

### Property Paint (Universal Brush)
Paints semantic labels or custom properties directly onto objects.
*   **Setup:** Use the tool options to select a Target (Node, Edge, Agent, Zone) and a Property (Type, or any custom data field).
*   **Click / Drag:** Applies the selected value to the target.
*   **Right-Click:** Cycles through the available values (e.g., swapping between "enemy" and "treasure", or toggling a boolean).
*   **Alt + Click:** Picks (samples) the value currently under the mouse cursor, acting like an eyedropper tool.

### Stamp
Drops pre-configured graph configurations, custom room footprints, or macro-structures directly onto the canvas from your clipboard (JSON).
*   **Click:** Stamps the prefab geometry.
*   **Alt + Hover/Click:** Snaps the prefab preview and placement to the grid.
*   **Right-Click:** Cancels the stamp tool and reverts to the Select tool.

---

## Simulation & Zone Tools

These tools interact with the specialized simulation layers built on top of the base graph.

### Agent Spawner
Manages the placement and removal of simulation agents. 
*   **Right-Click:** Cycles the tool mode between **Create**, **Select**, and **Delete**.
*   **Create Mode:** Click a node to instantly spawn a new agent.
*   **Select / Delete Mode:** Click or box-drag to select/delete agents. Supports **Shift** (Add) and **Ctrl** (Subtract) modifiers.

### Agent Controller (Play Mode)
Allows you to manually pilot an agent through the graph, obeying all lock-and-key rules.
*   **Left-Click an Agent:** Takes manual control of the agent (sets it to Player Controlled).
*   **Hover a Neighbor Node:** Previews valid moves (green), locked doors (red), and invalid unidirectional edges. 
*   **Left-Click a Neighbor Node:** Moves the agent and automatically ticks the simulation forward.

### Zone Brush
Paints contiguous grid cells to define abstract Zones, which can enforce distinct traversal rules or biome settings.
*   **Setup:** You must have a Zone selected in the right sidebar's Zone tab. Configure Brush Size in the tool options.
*   **Left-Click / Drag:** Paints cells into the active Zone.
*   **Right-Click / Drag:** Erases cells from the active Zone.