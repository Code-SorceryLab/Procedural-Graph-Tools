# Lock-and-Key Progression

The `ProgressionSolver` mathematically guarantees that your procedurally generated dungeons are solvable. It analyzes the physical layout of the grid, divides it into distinct "Regions" (rooms connected by single-tile doors), and distributes locks and keys to create a structured, Metroidvania-style experience.

---

## 1. Topography & The Critical Path

Before placing any locks, the **Pathing Analyst** reads the map to determine the physical shape of the dungeon.
1.  **Endpoints:** It finds the Start (Spawn) and End (Exit) regions. If you did not explicitly assign these via the Generator UI, the engine automatically selects two valid rooms at opposite ends of the graph.
2.  **The Spine:** It calculates the "Critical Path"—the most direct line of rooms connecting the Start to the End. 
3.  **Depth Map:** It assigns a "Depth" integer to every room based on how many doors away it is from the Start region.

---

## 2. Placing Locks and Keys

The **Locker** traverses the depth map outward from the Start point, converting open doorways into locked doors based on your configured probabilities.

### Critical Locks
Locks placed directly on the Critical Path (the Spine). The engine enforces a strict **Anti-Cycle Rule**: A key is mathematically guaranteed to drop in a room with a Depth *lower* than the lock it opens. It is physically impossible to drop a key behind its own door.

### Optional Vaults
If the engine finds a Dead-End room (a "Leaf" node) that is *not* on the Critical Path, it can convert it into an Optional Vault. The lock to the Vault will require a unique key that is hidden somewhere else in the dungeon, encouraging exploration.
*   **Force Main Path Detours:** If enabled, the engine will aggressively hide Critical Keys inside Dead-Ends, forcing the player to detour off the main path to progress.

### Shortcuts (Sequence Breaks)
You can configure the engine to deliberately drop "Shortcut" keys early in the dungeon. These keys open doors located deep inside the map, allowing players to sequence-break or skip entire progression tiers if they find them.

---

## 3. Configuration & Styles

You can configure the behavior of the Progression Solver in the **Generator** tab under the **TileMap Realizer** section.

*   **Lock Chance:** (0.0 - 1.0) The probability that any doorway transitioning into a deeper depth tier will be locked.
*   **Max Critical Locks:** A hard cap on how many doors can block the main path to the exit.
*   **Max Optional Vaults:** A hard cap on how many Dead-Ends can be sealed behind bonus doors.
*   **Key Style Ratio:** Determines the naming convention of the locks and keys.
    *   `0.0`: Uses strict linear tiers (Tier 1 Key unlocks Tier 1 Door, Tier 2 unlocks both Tier 1 and 2).
    *   `1.0`: Uses randomized color names (Red Key unlocks only Red Doors).
    *   `0.5`: Organically mixes both locking conventions.

---

## 4. The Validation Report

Because the Progression Solver is highly stochastic (randomized), you can view a detailed breakdown of what it built by checking the **Report** tab after generation.

*   **Topography:** Lists exactly how many Hubs (3+ doors), Corridors (2 doors), and Leaves (1 door) were generated.
*   **Critical Path:** Displays a textual flowchart of the exact rooms on the Spine, from Start to Finish.
*   **Locks & Keys Map:** Displays exactly which key opens which door, and which room each key is currently hiding in.

*Note: The actual physical reachability of these keys is tested separately by the Validator.*