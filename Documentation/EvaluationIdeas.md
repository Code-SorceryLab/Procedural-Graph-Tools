# Evaluation Ideas

Candidate ways to evaluate Procedural Graph Tools for publication. See [RelatedWork.md](RelatedWork.md) for the prior art each one positions against.

## 1. Technical evaluation (no participants)
- **Expressive range analysis.** Run batches over seeds × pipeline presets. Plot graph metrics (density vs. betweenness, cycles vs. branching) and raster metrics (linearity/leniency-style). Compare presets.
- **Generative-space coverage and diversity.** Measure pairwise distances between outputs: graph edit distance or a Weisfeiler-Lehman kernel on graphs, and tile-level distance on rasters.
- **Solvability and correctness.** Report the share of solvable outputs per preset according to the validator. Measure dead-lock and soft-lock rates with temporally aware progression on vs. off (ablation).
- **Regeneration locality and stability.** After a trigger fires, measure how much changes outside the selected region (target: zero) vs. inside it, and whether the player's reachable set and inventory remain valid.
- **Performance and scalability.** Time per pipeline step, per raster pass, and per regeneration as graph size grows (100 → 10k nodes). The key result is whether runtime regeneration fits a frame or loading budget.
- **Determinism and reproducibility.** The same seed must produce identical output across runs and machines.
- **Validator agreement.** Compare validator verdicts with an exhaustive state-space search, or with a reference agent (BFS/A* over (position, inventory)).

## 2. Reproduction / expressiveness case studies
- Re-create known dungeons with the editor and pipeline: Zelda dungeons (VGLC), Metroid-style maps, examples from Dormans or Smith et al. Report the number of steps or modifiers each one needs.
- Re-implement published generators as pipeline recipes (Dormans mission/space, cyclic dungeons, DLA caves) to show the modifier stack is general.
- Feature-coverage comparison against Edgar, Dungeon Architect, Ludoscope, EDD, and Sturgeon. Weak as evidence on its own, but useful framing.

## 3. Use-case demos
- **Designer:** author a dungeon with biomes, custom rooms, and lock-and-key, then export it to a playable Godot scene.
- **Researcher:** use a parameter sweep plus the metrics dashboard to answer a question, e.g. how braiding affects betweenness and path length.
- **Runtime dynamic dungeon:** a small playable game where triggers reshape the level and progression adapts. This is the distinctive feature and should be the flagship demo.
- **Educator:** teaching graph theory or PCG algorithms.
- **Playtesting / ML:** use the tool as a level source for RL or automated-playtesting agents.

## 4. Studies with people
- Expert interviews or think-aloud with 5–10 designers or PCG researchers: task set, semi-structured interviews, thematic analysis.
- Usability study: SUS, NASA-TLX, Creativity Support Index (CSI).
- Comparative task study: build a dungeon from a specification with PGT vs. Edgar/Tiled vs. manually. Measure time, errors, and solvability.
- Player study of dynamic regeneration: static vs. regenerating dungeons, measured with PENS/GEQ/PXI, plus checks for confusion or frustration.
- Course deployment: students use the tool in a PCG or game-AI assignment; collect artifacts and surveys.

## 5. Longitudinal / ecological
- Open-source release adoption (downloads, issues, forks), or a game jam built with the tool. Supplementary evidence only.

## Recommended package for a first tool paper (FDG / IEEE CoG)
1. Technical evaluation: expressive range + solvability + regeneration ablation + performance.
2. 2–3 reproduction case studies.
3. A small expert study (about 8 participants, think-aloud + CSI).

Leave the player study of dynamic regeneration for a follow-up paper focused on that feature.
