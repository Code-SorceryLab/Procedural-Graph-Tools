# Tile Mapping & Procedural Palettes

The abstract graph relies on Semantic Tags (e.g., `boss_room`, `water_corridor`). To actually draw these on the screen, the `TileMapAdapter` must know what those tags look like. This is handled in the **Visual Tile Mapper**.

---

## 1. Visual Sprite Mapping

If you have a traditional pixel-art tileset (a `.png` file), you map it here.

1.  Click **Load Image...** to import your spritesheet.
2.  Set the exact **Tile W** and **H** to match your asset (e.g., 16x16 or 32x32).
3.  Select a Semantic Category from the left panel (e.g., `Forest (Floor)`).
4.  Ensure the dropdown is set to **Mode: Map Semantics**.
5.  Click anywhere on your loaded image. A colored outline will snap to that grid cell, binding that semantic tag to that specific pixel graphic.

When the `GraphRealizer` builds the map, the `TileMapAdapter` translates your semantic tags into precise atlas coordinates and writes them directly to the active Godot `TileMapLayer`.

### The Internal Painter
If your spritesheet is missing a specific transition tile or you just want to sketch a quick prototype:
*   Switch the dropdown to **Mode: Paint Tiles**.
*   Select **Use Semantic Color** to paint using the exact hex code associated with the active tag, or use the **Color Picker** to select a custom hex code.
*   Click and drag on the canvas to permanently alter the image. Click **Save PNG** to export your edits back to your hard drive.

---

## 2. Procedural Palettes (The IQ Cosine Formula)

If you check the **Use Procedural Color** box for a specific biome, you unlock the **Procedural Palette** mode. 

**Important:** This mode does *not* create new tiles from scratch. It mathematically generates a continuous color gradient, creates a series of Godot `alternative_tiles` (tints), and applies those tints over top of whatever Atlas Tile you mapped in Step 1. (It works best if you map a pure white or grayscale pixel as your base tile).

### How it Works
The engine uses the Inigo Quilez Cosine Gradient formula to generate infinitely smooth, mathematically harmonious color palettes. It calculates color using four Vector3 variables:
*   **Base Color (Bias):** The average, foundational color of the palette.
*   **Amplitude (Contrast):** How aggressively the colors shift away from the base color.
*   **Frequency (Oscillations):** How rapidly the colors cycle through the spectrum.
*   **Phase (Color Shift):** Shifts the starting point of the wave, effectively rotating the hue.

By tweaking these sliders (or clicking the **Randomize Palette** button), you can discover beautiful, mathematically perfect gradients.

### Wall Phase Shift
Because procedural palettes generate a continuous gradient, walls and floors drawn from the same mathematical curve can blend together and become hard to distinguish.
*   The **Wall Phase Shift (t + offset)** slider artificially forces the Wall tiles to sample from slightly further down the mathematical curve than the Floor tiles, ensuring high contrast between walkable and non-walkable space.