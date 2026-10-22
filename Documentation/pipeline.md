# Pipeline Overview & Presets

The Pipeline is the heart of the procedural generation engine. Rather than writing monolithic generation scripts, you compose environments by chaining together small, single-purpose **Modifiers** (e.g., "Spawn a Grid," then "Erode Edges," then "Jitter Positions"). 

Because the pipeline is completely deterministic, running the same stack of modifiers with the same seed will always produce the exact same graph.

---

## 1. The Modifier Stack

The Pipeline tab in the right sidebar contains your active **Modifier Stack**. Modifiers are executed top-to-bottom. 

### Adding and Managing Modifiers
*   **Add:** Select a modifier from the dropdown and click **Add**. It will appear at the bottom of the stack.
*   **Reorder:** Select an item in the list and use the **Up (▲)** and **Down (▼)** buttons to change its execution order.
*   **Delete (✖):** Removes the selected modifier from the stack.

### Modifier Categories
When added to the stack, modifiers are prefixed with a tag indicating their primary role:
*   `[GEN]` **Generator:** Creates raw nodes and edges from scratch. *Note: Generators are destructive. Running a Generator wipes the existing graph.*
*   `[TOP]` **Topology:** Alters the connections (edges) between existing nodes without moving them physically.
*   `[GEO]` **Geometry:** Moves existing nodes in 2D space without changing their topological connections.
*   `[SEM]` **Semantic:** Applies data, types, labels, or zones to existing nodes and edges.

### Configuring Modifiers
Clicking any modifier in the stack opens its **Settings** below the list. These settings dynamically expose the algorithm's variables (e.g., Grid Width, Erosion Chance, Jitter Distance). Changing a setting here immediately updates the underlying data.

---

## 2. Execution Modes

The pipeline offers two distinct workflows: full generation, and granular step-by-step testing.

### Macro Execution
*   **▶ RUN PIPELINE:** Executes the entire stack from top to bottom. This runs on a background CPU thread, keeping the editor responsive even when generating massive graphs (10,000+ nodes). 
*   **Clear Graph:** Instantly deletes all nodes, edges, and zones from the canvas.

### Live Actions (Step-by-Step)
When you select a specific modifier in the stack, the **Live Action** panel appears. This allows you to test individual algorithms without running the whole pipeline.
*   **Generate (Wipe & Apply):** Wipes the canvas clean, then runs *only* the selected modifier. (Best for testing `[GEN]` modifiers).
*   **Apply (Additive):** Runs the selected modifier on top of whatever is currently on the canvas. (Best for testing `[TOP]`, `[GEO]`, or `[SEM]` modifiers).

*Tip: The Live Actions system shares a memory context. If you "Live Generate" a grid, then select the next modifier and "Live Apply" a jitter, the jitter modifier knows exactly which nodes the grid just created!*

---

## 3. Pipeline Presets (Recipes)

Once you find a stack of modifiers and settings that produces great results, you can save the entire pipeline as a JSON recipe.

*   **💾 Save Recipe:** Serializes the current modifier stack and all custom settings into a `.json` file.
*   **📂 Load Recipe:** Wipes the current stack and replaces it with the modifiers defined in the chosen `.json` file.

