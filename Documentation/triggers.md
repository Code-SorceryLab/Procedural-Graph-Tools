# Triggers & Temporal Progression

The Rasterizer supports **Dynamic Regeneration** during gameplay. Instead of generating a static dungeon once, you can place invisible **Temporal Triggers** on the map. When the player steps on a trigger, a specific subset of the dungeon recalculates and regenerates in real-time.

There are two distinct types of triggers: **Local Triggers** and **Progression Triggers**.

---

## 1. Local Triggers (The Trigger Placer)

Local triggers are used for environmental shifts, secrets, or traps that do not block the critical path of the dungeon. They are managed by the `TriggerPlacer`.

### How to Create a Local Trigger
1.  Open the **Triggers** tab in the main UI.
2.  Click **+ Create New Trigger**.
3.  Set the placement mode to **📍 Local**.
4.  Click **Mask** to select exactly which nodes and edges in the abstract Graph Editor will be targeted for regeneration when this trigger is hit.
5.  Click **Rules & Constraints** to define *how* those targeted nodes will regenerate (e.g., forcing them to become a "Boss Room" instead of an "Empty Corridor").

### How They Spawn
The `TriggerPlacer` acts almost exactly like the `EntityScatterer`. It searches the dungeon for a valid room that meets the trigger's requirements (e.g., "Must spawn in a Leaf node in the Forest biome") and drops the invisible trigger onto a floor tile.

When the player steps on it, the targeted nodes are wiped via the Dirty Rect system, their new rules are applied, and they are re-rasterized into the map.

---

## 2. Progression Triggers (The Withheld Key)

Progression triggers are managed exclusively by the `ProgressionLocker` and are used to create Metroidvania-style sequence locks that require temporal shifts to solve.

### How to Create a Progression Trigger
1.  Open the **Triggers** tab.
2.  Create a trigger and set the placement mode to **🗝️ Prog.**.
3.  Define the targeted nodes and regeneration rules.

### How They Spawn (The Withholding Mechanic)
When the `ProgressionSolver` decides to lock a door on the critical path, it normally hides a physical key somewhere else in the dungeon. 

If Progression Triggers are available in the pool, the engine will **withhold the key**. Instead of dropping a key, it drops your Progression Trigger. 
*   **The Trap:** The player reaches the locked door and cannot open it. They explore the dungeon and step on your trigger.
*   **The Shift:** The trigger fires, regenerating its masked nodes.
*   **The Payoff:** The `ProgressionSolver` detects the regeneration and mathematically *guarantees* that the withheld key is immediately spawned inside the newly regenerated rooms, allowing the player to collect it and open the door.

---

## 3. Trigger Constraints and Memory

In the **Rules & Constraints** menu for any trigger, you can dictate exactly what happens during the regeneration:
*   **Pipeline Overrides:** Selectively disable specific generation layers during the shift. (e.g., Disable "Rebuild Base Geometry" but leave "Rebuild Entities" enabled. The room's walls won't move, but all the loot and enemies inside will reroll).
*   **Max Uses:** Dictates how many times a trigger can fire before it exhausts itself.
*   **Memory (Temporal State):** Triggers respect the player's history. When a trigger fires, the engine references the `temporal_state` dictionary to ensure any locked doors the player previously opened remain open, and any keys they already collected are not regenerated.