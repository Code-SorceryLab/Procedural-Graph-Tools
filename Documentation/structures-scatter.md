# Structures & Scatter Sets

While Rooms and Corridors define the walkable floorplan, **Structures** and **Scatter Sets** populate that floorplan with obstacles, interactables, and decorations.

---

## 1. Scatter Sets (1x1 Entities)

The **Scatter Designer** allows you to define 1x1 entities like barrels, torches, treasure chests, or enemies. 

*   **Visual Sprite Mapping:** You can assign a specific sprite from an imported Atlas, along with offset and scale adjustments to make it fit perfectly within a 1x1 grid cell.
*   **Editor Color:** Assign a distinct color to the entity so it is easily identifiable in the abstract 2D map view.

### Placement Rules
When distributed onto the map, scatter entities obey specific constraints to ensure organic placement:
*   **Wall Distance (Min/Max):** Determines where the entity is allowed to spawn. Setting Min=0 and Max=0 forces it to spawn exactly against a wall (like a torch). Setting a Min=2 forces it to spawn in the open center of a room (like a trap).
*   **Symmetry:** You can force entities to spawn in mirrored pairs (e.g., placing two statues symmetrically along the X-axis of a room).
*   **Clumping:** Allows a single scatter entity to mathematically "grow" into an organic clump. (e.g., A 50% clump chance with a Max Size of 4 means a single mushroom spawn might bloom into a dense patch of 4 mushrooms).

---

## 2. Custom Structures (Multi-Tile Objects)

The **Structure Designer** allows you to build multi-tile, rigid objects like a 2x3 altar, a 4x4 boss platform, or a giant statue.

*   **Collision Footprint:** You manually paint the exact physical footprint of the structure. The engine guarantees that nothing else (not even a scatter entity) can ever spawn inside this footprint.
*   **Solid Collision:** If enabled, the A* pathfinder treats the structure as an impenetrable wall, ensuring the critical path routes *around* it rather than through it.
*   **Allow 90° Rotations:** If enabled, the generator is allowed to rotate the structure to fit better within a given room.
*   **Face Critical Path:** If enabled, the engine calculates the location of the room's main entrance/corridor and rotates the structure so its "Front" (indicated by the red arrow in the designer) physically faces the player as they enter.

---

## 3. The Distribution Engine (Spawning Rules)

Creating an Entity or Structure does **not** automatically place it in the dungeon. You must deal them into the deck via the **Biome & Generation Designer**.

Open the **Spawn Decks** tab to manage how often items appear.

### The Hierarchical Quota System
The Distribution Engine uses a tree structure. You create **Pools** (folders) and place concrete items (Structures or Scatters) inside them.

*   **Root Mode:**
    *   *Fixed Quota:* Guarantees an exact number of spawns. (e.g., Quota Min 1, Max 1 guarantees exactly one Boss Chest).
    *   *Organic Density:* Spawns items based on available floor space. (e.g., Density 0.15 will attempt to cover 15% of all valid floor tiles with this item).
*   **Quota Scope:**
    *   *Per Room:* The quota is calculated independently for every single room in the biome.
    *   *Per Biome:* The quota is calculated once globally, and the resulting items are randomly distributed across the entire biome.
*   **Ratio Weights:** If a Pool has a quota of 10, and it contains "Red Mushrooms" (Weight 80) and "Blue Mushrooms" (Weight 20), the engine will mathematically resolve the pool to spawn exactly 8 Red and 2 Blue mushrooms.

### Placement Execution
During Rasterization, the `StructurePlacer` runs *before* progression analysis, meaning solid structures can actively shape how the critical path is drawn. The `EntityScatterer` runs near the very end, filling the remaining empty space around the path and structures.