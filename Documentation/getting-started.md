# Getting Started

A short orientation to the **Graph Editor & Procedural Environment Generator**. By the end, you'll have launched the tool, sketched a small graph, and know the essential interactions.

For deeper tasks, see the [Tutorials](#tutorials) at the bottom of this page.

> **Prerequisites:** the project opened in Godot 4.

---

## 1. Launch

Run the project (F5). The editor opens with an empty graph and four regions:

- **Topbar** — menus, simulation controls, status.
- **Left toolbar** — interactive tools.
- **Main canvas** — the graph itself.
- **Right sidebar** — tabbed panels for pipelines, rasterization, the inspector, agents, zones, and more.

![Application on launch with UI labelled.](images/GettingStartedLaunch.png?raw=true "Application on launch with UI labelled.")

For a guided tour of the sidebar and menus, see [User Interface Overview](ui-overview.md).

---

## 2. Sketch a graph

Pick a tool from the left toolbar and click or drag on the canvas.

- **Add Node** — click to place a node. Click several times to place several.
- **Paint** — drag to lay a connected line of nodes and edges.
- **Connect** — drag from one node to another to create an edge.
- **Cut** — drag across an edge to sever it.
- **Delete** — click a node or edge to remove it.
- **Property Paint** — paint a **type** (a semantic label) onto a node or edge. Node type determines the node's colour.

<!-- SCREENSHOT: A small graph sketched with Add Node, Connect, and Paint -->

The toolbar also contains **Select**, **Agent Spawner**, **Zone Brush**, **Control**, and **Stamp**—each covered in [Graph Tools Reference](graph-tools.md).

---

## 3. Select and transform

The **Select** tool is the one you'll use most. Its mode dropdown lives in the top‑left options bar (**Rectangle** or **Lasso**).

**Selecting**
- **Click** a node or edge — replace selection.
- **Shift + Click** — add to selection.
- **Ctrl + Click** — remove from selection.
- **Ctrl + A** — select all.
- **Ctrl + D** — deselect all.
- **Click and drag on empty space** — rectangle or lasso selection.

**Transforming**
- **Drag a selected node** — move the whole selection.
- **Select two or more nodes** — a transform box appears; drag its handles to scale, or drag just outside a corner to rotate.

<!-- SCREENSHOT: Rectangle selection with transform handles visible -->

Selected nodes and edges can be inspected and edited from the **Inspector tab** in the right sidebar.

---

## 4. Clipboard and history

- **Ctrl + C / Ctrl + X / Ctrl + V** — copy, cut, paste at the mouse position.
- **Ctrl + Z** — undo. **Ctrl + Y** — redo.
- **Backspace** — delete the current selection.

Every mutation is undoable, including node moves and transforms.

---

## 5. Camera

- **Middle mouse drag** — pan.
- **Scroll wheel** — zoom in / out.
- **F** — focus the camera on the entire graph. Use whenever you feel lost.

<!-- SCREENSHOT: Camera focused on a graph after pressing F -->

---

## 6. Starting over

- **File → New Graph** in the topbar.
- **Clear Graph** in the pipeline controller (right sidebar).

Both reset to an empty graph.

---

## 7. A note on node types

A node's colour is its **type**, drawn from the semantic registry (*empty*, *spawn*, *enemy*, *treasure*, *boss*, *shop*, and custom entries you define). Types influence how pipelines interpret nodes and how the rasterizer renders them. The full system is covered in [Semantic System](semantic-system.md).

---

## Tutorials

Each tutorial focuses on a single task and stands alone.

1. **[Your First Pipeline](tutorials/first-pipeline.md)** — load a preset (`Grid → DLA → Jitter`), run it, inspect the result.
2. **[Your First Rasterization](tutorials/first-rasterization.md)** — turn a graph into a playable tilemap using the starter tileset.
3. **[Your First Report](tutorials/first-report.md)** — run analysis and export metrics.
4. **[Your First Dungeon Run](tutorials/first-dungeon-run.md)** — verify solvability with the validator.

### Useful alongside

- [User Interface Overview](ui-overview.md)
- [Graph Tools Reference](graph-tools.md)
- [Semantic System](semantic-system.md)
- [Glossary](glossary.md)