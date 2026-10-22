# User Interface Overview

A map of the editor. Every control you'll interact with lives in one of four regions: the **topbar**, the **left toolbar**, the **main canvas**, and the **right sidebar**. Each region can be collapsed and expanded via its own toggle button, and pressing **Tab** hides or shows all of them at once.

This page tells you what lives where. For deeper detail, each section links to its dedicated page.

---

## 1. The Four Regions

- **Topbar** — menus, simulation controls, and occasionally status text or tool-specific controls that appear only when relevant.
- **Left toolbar** — the interactive tools for editing the canvas.
- **Main canvas** — the graph itself.
- **Right sidebar** — eight tabs, each a dedicated controller for one concern.

Press **Tab** at any time to hide or show all panels simultaneously and give the canvas the full window.

---

## 2. Right Sidebar

The right sidebar carries the most functional weight in the editor. It contains eight tabs in the following order:

1. **Pipeline** — assembles graph transformations into an ordered list, and runs, saves, and loads pipelines. This is the primary tool for generating graphs. See [Pipeline Overview](pipeline.md).
2. **File** — new graph, save, save as, and load. See [File Formats](file-formats.md).
3. **Agent** — roster of spawned agents with quick behaviour controls. See [Agent Simulation](agents.md).
4. **Zone** — list of zones and their traversal rules. See [Zones](zones.md).
5. **Analysis** — dashboard of graph metrics. See [Analysis & Metrics](analysis.md).
6. **Experiment** — batch parameter sweeps across pipelines. See [Batch Experiments](experiments.md).
7. **Realizer** — rasterizes a graph into a playable tilemap. See [Rasterizer Overview](rasterizer.md).
8. **Inspector** — displays and edits the properties of the current selection. See below.

The Agent and Zone tabs are available if you use those systems, but they are not required for the core graph‑to‑environment workflow.

### The Inspector tab

Selecting any node, edge, agent, or zone switches the Inspector to that object's properties. Selected nodes and edges can also have **custom data** added or modified here—the **Add Custom Data...** button opens the custom data editor popup for that object type. Custom data is how you attach your own semantic labels to any element of the graph, from a simple tag like `biome: cave` to a compound data structure used by your own generators.

<!-- SCREENSHOT: custom-data-editor.png — Custom data editor popup with a selected node and a few custom properties -->

The full system, including categories and display modes, is covered in [Semantic System](semantic-system.md).

---

## 3. Topbar

### Menus

- **File** — New Graph, Save, Save As..., Load.
- **Edit** — Undo, Redo, Clear Graph, and **Settings**. Settings opens a dialog to configure keyboard bindings, the maximum number of undo history steps, and whether the background grid is visible.
- **Graph** — toggles for **buoyancy mode**, auto‑crystallize, edge tension snapping, node collision fusing, a single force‑directed layout step, and the topological depth overlay. Buoyancy mode is a physics‑based layout option that nudges nodes apart with springs and repulsion; details are in the pipeline documentation for the corresponding transformation.
- **Agents** — Clear All Agents, plus toggles for solver debug overlays (ghost webs, key badges, agent breadcrumbs).

<!-- SCREENSHOT: settings-popup.png — Settings dialog showing keybindings, undo limit, and grid visibility -->

### Simulation Controls

The middle of the topbar holds the agent simulation controls:

- **Step** — advance the simulation by one tick.
- **Play** / **Pause** — start or stop automatic stepping.
- **Reset** — return all agents to their starting state.
- **Speed** — steps per second.

These controls are always visible and drive the simulation loop described in [Agent Simulation](agents.md).

### Status Text and Tool Controls

Depending on the active tool, the topbar may also display **status messages** ("Ready", "Selection cleared", and similar hints) or **tool‑specific options** such as the Select tool's Rectangle / Lasso mode dropdown. These appear only when needed and don't persist on a fresh launch.

---

## 4. Left Toolbar

The left toolbar contains the interactive tools for editing the canvas: **Add Node**, **Connect**, **Cut**, **Delete**, **Paint**, **Property Paint**, **Select**, **Agent Spawner**, **Zone Brush**, **Control**, and **Stamp**.

Each tool, its options, and its keyboard shortcut are documented in [Graph Tools Reference](graph-tools.md).

---

## 5. Main Canvas

The main canvas is where the graph is drawn and edited. Interaction basics—placing nodes, connecting edges, selecting and transforming, camera controls—are covered in [Getting Started](getting-started.md).

---

## 6. Where to go next

- New here? Start with [Getting Started](getting-started.md).
- Prefer to learn by task? Try [Your First Pipeline](tutorials/first-pipeline.md) or [Your First Rasterization](tutorials/first-rasterization.md).
- Looking for a specific feature? The full index lives on the [documentation home](README.md).