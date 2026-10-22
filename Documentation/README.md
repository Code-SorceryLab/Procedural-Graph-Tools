# Graph Editor & Procedural Environment Generator

Welcome to the documentation for the Graph Editor—a unified environment for **graph authoring**, **procedural generation**, **agent simulation**, **rasterization**, and **analytical research**. This tool bridges the gap between abstract graph theory and playable, explorable environments, serving both game developers prototyping level generation and researchers studying graph topology and PCG.

---

## New here? Pick your track

The documentation is designed to be useful from two angles. Choose the path that fits you—both share the same reference pages, but the order is tailored.

### For developers
Start with the practical workflow: author a graph, generate a dungeon, see it in a tilemap.

1. **[Getting Started](getting-started.md)** – your first session, from an empty graph to a saved environment.
2. **[User Interface Overview](ui-overview.md)** – a tour of the editor layout and where everything lives.
3. **[Pipeline Overview](pipeline.md)** – compose procedural generation recipes.
4. **[Rasterizer Overview](rasterizer.md)** – turn graphs into playable tilemaps.
5. **[Validator & Player Simulation](validator.md)** – confirm your environments are solvable.

### For researchers
Start with the analytical capabilities: measure graphs, run experiments, reproduce results.

1. **[Getting Started](getting-started.md)** – launch the tool and produce your first graph.
2. **[Pipeline Overview](pipeline.md)** – understand how generation is composed.
3. **[Analysis & Metrics](analysis.md)** – measure the graphs you generate.
4. **[Batch Experiments](experiments.md)** – sweep parameters and collect data.


Not sure which track? Read **[Getting Started](getting-started.md)** first—everything else branches from there.

---

## What you can do with this tool

- **Author graphs interactively** — place, connect, cut, paint, and transform nodes and edges with full undo/redo.
- **Compose procedural generation pipelines** — chain modular transformations (grids, DAGs, scale‑free graphs, diffusion, MST, cellular automata, grammar, jitter, and more) into reusable, deterministic recipes.
- **Simulate agents** — spawn walkers with behaviours, capabilities, and inventories that traverse your graph, solve questlines, or expand it dynamically.
- **Rasterize graphs into tilemaps** — turn abstract topology into playable environments with biomes, custom rooms, structures, entity scatter, WFC texturing, and lock‑and‑key progression.
- **Analyze and validate** — measure graphs with topological, spatial, and agent metrics; verify solvability with a headless flood‑fill validator; and export reports.
- **Run batch experiments** — sweep pipeline parameters across many seeds and collect metrics for comparison.
- **Define your own semantics** — register custom node/edge/agent/zone categories and properties to shape the generator and the UI around your own terminology.

Everything is deterministic and seed‑driven, so results are reproducible across sessions.

---

## Tutorials

The tutorials are self‑contained, task‑oriented pages. Each stands alone, but they build on each other if read in order. Feature pages link to the relevant tutorial at the top for readers who prefer to learn by doing.

1. **[Tutorial: Your First Graph](tutorials/first-graph.md)** — open the editor, place nodes, connect them, cut an edge, and save your work.
2. **[Tutorial: Your First Pipeline](tutorials/first-pipeline.md)** — load or build a simple modifier chain (`Grid → DLA → Jitter`), execute it, and inspect the result.
3. **[Tutorial: Your First Rasterization](tutorials/first-rasterization.md)** — load a starter tileset, assign tiles to biome floors and walls, and generate a playable tilemap from your graph.
4. **[Tutorial: Your First Report](tutorials/first-report.md)** — run the analysis suite on a graph and export a metrics report.
5. **[Tutorial: Your First Dungeon Run](tutorials/first-dungeon-run.md)** — run a player simulation to verify solvability and explore the graph in real time.

Additional tutorials are planned for triggers, WFC, custom rooms, and batch experiments.

---

## Documentation map

### First steps
- [Getting Started](getting-started.md)
- [User Interface Overview](ui-overview.md)
- [Glossary](glossary.md)

### The graph
- [Graph Tools Reference](graph-tools.md)
- [Zones](zones.md)
- [Semantic System](semantic-system.md)

### Procedural generation
- [Pipeline Overview](pipeline.md)
- [Modifier Reference](pipeline-modifiers.md)

### Agents
- [Agent Simulation](agents.md)

### Rasterization
- [Rasterizer Overview](rasterizer.md)
- [Custom Room Designer](custom-rooms.md)
- [Structure & Scatter Sets](structures-scatter.md)
- [WFC Texturing](wfc.md)
- [Tile Mapping](tile-mapping.md)

### Progression & regeneration
- [Lock‑and‑Key Progression](progression.md)
- [Triggers & Temporal Progression](triggers.md)

### Validation & analysis
- [Validator & Player Simulation](validator.md)
- [Analysis & Metrics](analysis.md)
- [Batch Experiments](experiments.md)


---

## Where to find help

- **[Troubleshooting](troubleshooting.md)** collects solutions to known issues, performance tips, and where to look in the console for diagnostic output.
- **[Architecture & Development](architecture.md)** explains the internals if you want to extend the tool.
- If you find something unclear or missing, please open an issue on the repository.