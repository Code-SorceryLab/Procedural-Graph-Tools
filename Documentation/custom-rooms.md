# Custom Room Designer

By default, the `RoomAllocator` stamps graph nodes as standard geometric presets (circles, squares, triangles) or cellular blobs. The **Custom Room Designer** allows you to override this by hand-crafting exact layouts, forcing the procedural generator to seamlessly stitch your hand-made rooms into the randomized dungeon.

---

## 1. The Designer Canvas

The designer provides a pixel-art grid canvas where you define the exact layout of your room.

### Paint Brushes
*   **Generic Biome Floor / Wall:** Paints structural layouts. The actual graphics applied to these tiles will be dynamically determined by the Biome of the node this room is stamped onto.
*   **Exact Floor / Wall Tile:** Hardcodes a specific pixel-art tile from the loaded Atlas. This tile will *never* change, regardless of the biome.
*   **WFC Socket Zone (3x3):** Reserves a 3x3 grid area where the Wave Function Collapse engine is allowed to inject organic textural decorations (e.g., a randomized pond or patch of grass) inside your otherwise rigid room.
*   **Place Structure / Entity:** Stamps multi-tile structures (altars, tables) or 1x1 entities (chests, enemies) directly into the room's blueprint.
*   **Center Anchor (Yellow Circle):** Determines the exact pivot point the generator uses when placing the room on the global map coordinates.

---

## 2. Doorways and The "Reserved" Mask

If you build a custom room, the procedural engine does not know how to safely navigate it. You must explicitly teach the pathfinding algorithm how to walk through your room using two special brushes.

### Doorway Markers (Red)
You must place Doorway markers on the perimeter of your room. The `RoomAllocator` will use these exact coordinates to attach connecting corridors. 
*   *Rule of Thumb:* If a graph node has 4 edges connected to it, but your Custom Room only has 3 Doorway markers, the Allocator will **reject** the custom room and fallback to a default square to prevent breaking the map.

### The "Reserved" Mask (Pink Line)
The Reserved mask defines the "Critical Path" through your room. You must paint a contiguous line of Reserved tiles connecting every single Doorway marker together.
*   **Validation:** When you click Save, a Breadth-First Search (BFS) runs over the Reserved tiles. If any Doorway is unreachable from the others, the room is rejected.
*   **Protection:** The WFC engine and Scatter engines are mathematically forbidden from spawning overlapping objects on Reserved tiles, guaranteeing your doorways are never blocked by a randomly generated rock.

---

## 3. Allocation and The Firewall

When the generator attempts to place your custom room on the map, it executes a rigorous scoring and protection phase.

### Rotation Scoring
The Allocator evaluates all four 90-degree rotations of your room. It calculates the direction of the neighboring graph nodes and attempts to match your room's Doorways to those neighbors. If a doorway points in the complete opposite direction of its intended neighbor, it applies a massive penalty. The rotation with the best score is stamped.

### The Custom Room Firewall
Once stamped, the room's exact coordinate footprint is logged into the engine's `custom_room_cells` dictionary. This acts as a mathematical **Firewall**.
*   *Smoothing Immunity:* The Cellular Smoother and Path Eroder cannot touch these tiles.
*   *Collision Defense:* Standard rooms cannot merge into or overwrite custom room tiles.

### The Skeleton Key (Edge Routing)
When the `EdgeRouter` calculates corridors between nodes, it treats the Custom Room Firewall as an infinitely solid object. Corridors cannot smash through your custom walls. 
To let the corridor in, the engine uses a "Skeleton Key"—it dynamically temporarily unlocks *only* the specific tiles you painted as Doorways. The A* pathfinder is forced to snake the corridor directly into your Doorway frame, leaving the rest of the room's exterior walls perfectly intact.

---

## 4. Distributing Rooms (The Spawn Decks)

Creating a room in the Designer **does not** automatically add it to your game. You must configure the `DistributionEngine` to shuffle it into the deck.

1.  Open the **Biome & Generation Designer**.
2.  Navigate to the **Shape & Rooms** tab.
3.  In the hierarchical tree on the left, click `+ Custom Room` to add your room to the pool.
4.  You can assign the room a specific Quota (e.g., "Spawn exactly 1 of these per biome") or a relative Weight if placing it in an organic randomized pool.

*Note: You can bypass the Distribution Engine by explicitly forcing a specific Custom Room onto a specific node via the `exact_node_id` parameter in the Editor via the inspector tab underneath a selected node's "Force Custom Room" property.*