# Textural WFC (Wave Function Collapse)

While the Base Geometry layer generates the structural layout (walls, floors, corridors), the **Textural WFC** layer is responsible for organically painting the floor with complex graphics. Note that this step can often demand a lot of processing time, and ultimately is purely a cosmetic one for the purposes of the rasterizer.

Instead of writing manual `if/else` rules for every possible corner, edge, or transition of a dirt path or a pond, you **teach** the engine by painting a small "Sample Grid." The WFC algorithm scans your sample, extracts the visual rules, and creates an infinitely scalable version of it onto your dungeon floor.

---

## 1. The WFC Pattern Designer

Open the **Textural WFC (Overlapping Sample Editor)** to define your biome's texture palette.

### The Sample Canvas (Left Panel)
You do not build the map here. Instead, you paint a small "ideal" example of what your biome *should* look like (usually a 10x10 grid). 
*   **Exact Atlas Tile:** Hardcode specific pixel-art tiles (e.g., grass, water, sand).
*   **Generic Biome Floor:** Represents any "open" walkable space.
*   **Generic Biome Wall:** Represents a physical collision boundary.

*Example:* If you want water to only exist if it's surrounded by sand, you would paint a pool of water tiles on the canvas, completely ringed by sand tiles, with grass on the outside.

### Extraction Rules
When the engine reads your sample canvas, it breaks it down into overlapping chunks to learn the rules.
*   **Pattern Size (N):** The size of the chunks it scans. `N=3` means it learns rules by looking at 3x3 grids. Larger N values create more structured, rigid output. Smaller N values (like 2) create chaotic, noisy output. Higher N values are also slower.
*   **Rotations & Reflections:** If enabled, the engine automatically mathematically rotates and flips your painted sample to learn all 4-way and mirrored permutations, saving you from having to paint every single corner manually.
*   **Wall-Aware:** If true, the algorithm pays attention to the physical walls of the dungeon, allowing you to create textures that organically react to the room boundaries (e.g., moss that only grows against walls).
*   **Seamless:** If enabled, the extractor treats your sample canvas as a wrap-around torus (the right edge connects to the left edge).

---

## 2. The Live Previewer

Because WFC relies on strict probability and constraints, it is very easy to accidentally create a rule-set that is mathematically impossible to solve (a contradiction). The **Live Previewer** (Right Panel) allows you to test your sample canvas instantly without running the full dungeon generator.

### Test Shapes & Constraints
You can force the previewer to generate inside specific geometric constraints to ensure your textures don't break in weird architectural spaces.
*   **Preview Shape:** Test how your textures look inside a *Square Room*, a *Narrow Corridor*, or a sharp *L-Shape (Inner Corner)*.
*   **Preview Brushes:** You can manually paint **Fixed Exact Tiles** or **Fixed Walls** onto the preview canvas. These act as "anchors." The live WFC solver is forced to build the rest of the generated texture around the anchors you placed.

### Contradictions and Fallbacks
If the solver encounters a scenario it doesn't know how to resolve based on your sample image (e.g., a "water" tile was placed next to a "wall" tile, but your sample canvas never showed water touching a wall), it triggers a **Contradiction**.

When a contradiction happens, the previewer highlights the failed tiles in bright **Red**. 
You can handle this in production via the **Contradiction Fallback** setting:
*   *Revert to Generic Biome Floor:* Silently replaces the broken tile with the default solid color for that biome.
*   *Fill with Exact Tile:* Forces a specific "error" or "transition" tile into the broken gap to patch the hole.

---

## 3. Integration with Custom Rooms (WFC Sockets)

If you are hand-crafting a layout in the **Custom Room Designer**, you can use the **WFC Socket Zone (3x3)** brush.

By stamping these sockets into your rigid custom room, you tell the Rasterizer: *"Leave this 3x3 space blank, and let the WFC engine organically fill it with whatever biome textures are active."* This is incredibly useful for creating structured boss rooms that still have randomized, organic patches of grass, rubble, or water inside them.