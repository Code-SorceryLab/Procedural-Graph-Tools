# Related Work: Tools and Papers Similar to Procedural Graph Tools (PGT)

*Literature and tool scan, compiled 2026-10-22. Sources: Semantic Scholar, arXiv, Crossref, GitHub, publisher pages, and the Zotero library. Entries come with a DOI or URL. Fields that could not be confirmed are marked "?". Items already in Zotero are tagged [Zotero].*

*Updated 2026-11-19: added Themes E–G (adversarial novelty check, gap scan of 2026 work and tools, pattern-extraction prior art). The executive summary below reflects the update.*

The scan is split into seven themes, and some papers appear in more than one (e.g., Dormans 2010, Smith et al. 2018, Sturgeon). Deduplicate them when you build the .bib file.

| Theme | Entries |
|---|---|
| A. Graph grammars, mission/space, lock-and-key, constraint-based solvability | 80 papers + 7 repos |
| B. Graph→layout, rasterization, CA, WFC, plus a tool survey | 65 papers + 31 tools |
| C. Online/dynamic PCG, partial regeneration, agent-based PCG and validators | 50 papers + ludography |
| D. Mixed-initiative tools, PCG pipelines, level analysis/metrics, surveys, LLM-based generation | 77 papers |
| E. Adversarial novelty check of claims (a)–(c): experience management, narrative mediation, VR impossible spaces, incremental replanning | 25 papers + ludography |
| F. Gap scan: 2026 venues/arXiv, PCG workbenches, graph realization, agent tools | 38 papers + 14 tools/repos |
| G. Example-based motif mining → graph grammar (Pattern Extractor feature) | 21 papers |

---

## Executive summary

### Closest prior art (cross-theme)

| # | Work | Why it is close | How PGT differs |
|---|---|---|---|
| 1 | **Edgar** (DotNet/Unity) and **Edgar.Godot**; Nepožitek & Gemrot 2018; Ma et al., CGF 2014 | Turns a room graph plus room templates into a tilemap layout; a Godot version exists | Layout only: no modifier pipeline, no raster passes (CA, WFC, scatter), no agents, metrics, timeline, or runtime regeneration |
| 2 | **Ludoscope** (Dormans 2010/2011); Protsenko, Dormans & van Rozen, "Lessons from Ludoscope," FDG 2025, 10.1145/3723498.3723784 | A staged transformation pipeline over graphs and tilemaps; the conceptual twin of PGT's modifier stack | PGT adds a graph editor, agents, a metrics dashboard, batch experiments, and runtime regeneration |
| 3 | **Dungeon Architect** (commercial, Unity/UE), DunGen | Flow-graph-driven layout, snap modules with doors, lock-and-key | Commercial and closed; not a research workbench (no metrics or experiments) |
| 4 | **Cooper & Bazzaz**: Sturgeon-MKIV, AIIDE 2024, 10.1609/aiide.v20i1.31862; constraint-based graph grammar unifying level and playthrough, EXAG 2025; "Stuck in the Middle," FDG 2025 | Graph levels with game mechanics as rewrites, generated together with a playthrough that guarantees solvability | Offline, whole-level, solver-based. PGT re-plans at runtime and validates with a stateful agent |
| 5 | **Venco & Lanzi**, CoG 2021, 10.1109/CoG52621.2021.9619005 | Agents add locks, keys, and switches to graph maps with no dead-ends | Generation time only; no persistent validator or regeneration |
| 6 | **Johnson et al.**, IEEE Access 2021, 10.1109/ACCESS.2021.3069114 | Key-item placement on an item-gated world graph with reachability guarantees | Static, from the start state. PGT re-places keys based on the current player state |
| 7 | **Mao & Cooper**, CoG 2023, 10.1109/CoG57401.2023.10333222 | Segment-wise extension that keeps earlier content and the solution path | Append-only. PGT rewrites selected interior nodes/edges |
| 8 | **Kar**, "Momentum," arXiv:2605.01783, 2026 | Runtime generation plus autonomous validator agents inside the gameplay loop | Endless runner, append-only, no locks or keys, no agent state across changes |
| 9 | **Evolutionary Dungeon Designer** family (Baldwin et al., CIG/FDG 2017; Alvarez et al., FDG 2018, ToG 2022) | Mixed-initiative dungeon design with a room graph, locks, and MAP-Elites | Grid-based and evolutionary; no graph pipeline or runtime features |
| 10 | **Danesh** (Cook et al., IEEE ToG 2022, 10.1109/TG.2021.3078323) | Generator analysis, expressive range, parameter exploration | No graph editor or graph metrics; analysis-only plugin |
| 11 | **Bao et al.**, PLoS ONE 2026, 10.1371/journal.pone.0354705 | Betweenness, closeness, and k-hop reachability on Metroidvania map graphs | Static analysis of commercial maps, not an integrated tool |
| 12 | **Voisard, Politowski, Petrillo & Guéhéneuc**, "CG-WFC," GAS@ICSE 2026, 10.1145/3786171.3788381 | **Our own prior work**: cyclic graph grammar plus WFC | PGT generalizes it into a full editor/pipeline/runtime system. Position PGT explicitly against it |
| 13 | **Robertson & Young**, General Mediation Engine / "Perceptual experience management," AIIDE 2014/2015; IEEE ToG 2019, 10.1109/TG.2018.2817162 (Theme E) | Experience manager that generates and revises the game world during play, changing what the player has not observed | Revises symbolic world state; no spatial triggers, node/edge mask, or re-rasterization (spatial-layout rewriting unverified) |
| 14 | **Ashmore & Nitsche**, "The quest in a generated world" (*Charbitat*), DiGRA 2007 (Theme E) | Places keys and locks at runtime from the current player status | Append-only world, heuristic placement, no solvability guarantee, no re-planning after regeneration |
| 15 | **Xu & Verbrugge**, "From experience to 3D platformer levels via topological graphs," AIIDE 2026, 10.1609/aiide.v22i1.43601 (Theme F) | Progression/gating graph realized as a level, with a topological validator in the loop | One algorithm, 3D platformers; no workbench, metrics, agents, or runtime features |
| 16 | **Atrium** (Godot 4 addon, 2026) and **Level Building Sidekick** tutorial, FDG 2026, 10.1145/3815598.3815711 (Theme F) | Godot editor-first seeded dungeon tool with edit locks and validation; LBS repositioned as a PCG research platform | Atrium: no graph model, metrics, agents, or sweeps. LBS: grid/Unity, no graph pipeline or graph metrics |
| 17 | **Londoño & Missura**, PCG Workshop 2015; **Nishida et al.**, CGF 2016, 10.1111/cgf.12728 (Theme G) | Learn graph grammars from example levels (SubdueGL); grow graphs from example patches attached at the frontier | Same algorithmic idea as the Pattern Extractor; PGT adds only the designer-curated, engine-integrated workflow |

Reproducibility citations: Withington, Cook & Tokarchuk, FDG 2024, 10.1145/3649921.3650016; Khalifa et al., "PCG Benchmark," FDG 2025, 10.1145/3723498.3723794.

### Novelty assessment

- **(a) Trigger-based partial regeneration at runtime, preserving surrounding topology.**
  - No work found does this on a live level.
  - Online PCG (Polymorph, infinite caves, EDRL, Momentum) only appends content ahead of the player.
  - Partial regeneration and repair (Tanagra pinning, Sturgeon infill, level repair, inpainting) happens offline at design time.
  - Runtime "impossible spaces" in VR and games like *P.T.* or *Layers of Fear* are scripted or perceptual and have no generation pipeline.
  - Closest conceptually: Dormans & Bakkes 2011; Lopes, Eisemann & Bidarra 2018.
  - **2026-11-19 verdict: weakened (slightly).** Experience managers (Robertson & Young's GME) revise the world during play, and VR systems hide layout changes (VRoamer, Suma 2011). Reword as: "brings mask-scoped constrained regeneration from design time into play." See Theme E.
- **(b) Temporally aware lock-and-key progression.**
  - All lock-and-key feasibility work found (Dormans, ASP, randomizers, Sturgeon) guarantees solvability once, from the start state.
  - No work found re-plans keys after a mid-play change or uses trigger-gated key placement.
  - **2026-11-19 verdict: weakened (moderately).** *Charbitat* (DiGRA 2007) places keys from the current player status, and narrative mediation/late commitment replans from the current state. Drop "first to place keys from player state"; claim re-planning after in-place regeneration plus trigger-gated key commitment. See Theme E.
- **(c) Persistent validator agent that survives regenerations.**
  - Only Momentum (Kar 2026) validates at runtime, and it is stateless and append-only.
  - No incremental validator found that keeps state (inventory, explored set) across content mutations.
  - **2026-11-19 verdict: holds.** Frame it as applying incremental replanning (D* Lite, LPA*) to PCG validation, not as a new algorithm. See Theme E.
- **(e) Pattern extraction and growth (new feature on `main`).**
  - The algorithm is not novel: Londoño & Missura 2015, Sturgeon-GRAPH 2023, Merrell 2023, Nishida et al. 2016, SubdueGL. See Theme G.
  - Fix before publishing: the topological signature (degree sequence + edge count) is not canonical, and semantic mode ignores `depth`.
- **(d) Agents that both generate and test.**
  - Established idea: Doran & Parberry 2010; Kerssemakers et al. 2012; PCGRL; ARLPCG.
  - Frame PGT's unified capability model as an engineering contribution, not a new idea.
- **Integration claim.**
  - No single tool found combines graph authoring, a serializable modifier stack, multi-pass rasterization with a step-through timeline, agent simulation, a graph-metric dashboard, and batch experiments.
  - LLM-based generation of dungeon graphs with lock-and-key semantics: no peer-reviewed work found for 2023–2026.

"Not found" means not found in this scan, not proven absent. Run a final check before submission.

### Entries to verify before citing (marked "?" in the sections below)
- **Missing DOIs:**
  - Nepožitek & Gemrot 2018 (venue also unknown)
  - Cooper & Bazzaz, "Stuck in the Middle," FDG 2025
  - Lopes, Eisemann & Bidarra 2018
  - Cooper & Sarkar 2020 (EXAG)
  - Liu et al. 2021
- **Venue or year unclear:**
  - Thompson & Lavender 2017
  - Ruslanova et al.
  - Jara Gonzalez inpainting paper
  - Cicero
  - Martin 2011 (Splinter Cell space syntax)
  - Nepožitek thesis (year)
- **Other metadata:**
  - Short & Adams book (ISBN or DOI)
  - Mao et al. (author list differs between versions)
  - PCGRLLM (volume and pages)
  - Dormans, "Cyclic Generation" chapter (pages)
  - Lopes et al. 2010, "constrained growth"
- **Low-tier venues, flagged:** Rengaraj 2026; Xu & Morris 2023.

---

## Theme A — Graph grammars, mission/space, lock-and-key, constraint-based solvability

Scope: related work for "Procedural Graph Tools" (Godot). Metadata verified via Semantic Scholar API (titles/authors/venues/DOIs), publisher/OJS pages, or author pages. Fields marked "?" were not verified. "PGT" = our tool.

Search log (summary): ~35 queries (Semantic Scholar keyword search, arXiv, web), plus forward citation chasing on Dormans 2010 (161 citers scanned), Dormans & Bakkes 2011 (95 citers), Smith/Padget/Vidler 2018, Sturgeon-MKIII and Sturgeon-MKIV. Zotero library checked ("Dormans": only the PCG-book chapter and *Game Mechanics* book).

---

### A1. Mission/space framework and graph-grammar level generation (Dormans lineage)

1. J. Dormans, "Adventures in level design: Generating missions and spaces for action adventure games," in *Proc. PCG Workshop @ FDG*, 2010. DOI: 10.1145/1814256.1814257
   — Founding work: graph grammar generates a mission graph (locks/keys), then shape grammar builds space. PGT's grammar rewriting + DAG-locks modifiers are in this lineage. Dormans' pipeline is offline and one-shot; PGT stacks grammars with other modifiers and can regenerate parts at runtime.

2. J. Dormans, "Level design as model transformation: A strategy for automated content generation," in *Proc. PCG Workshop @ FDG*, 2011. DOI: 10.1145/2000919.2000921
   — Frames generation as a chain of model transformations (graph→graph→tilemap). Closest conceptual match to PGT's modifier stack and graph→tilemap rasterization.

3. J. Dormans and S. Bakkes, "Generating missions and spaces for adaptable play experiences," *IEEE Trans. Comput. Intell. AI Games*, vol. 3, no. 3, 2011. DOI: 10.1109/TCIAIG.2011.2149523
   — Mission/space generation adapted to player experience. Relates to PGT's adaptive lock-and-key; their adaptation happens between levels, while PGT adapts during play to player location and inventory.

4. S. Bakkes and J. Dormans, "Involving player experience in dynamically generated missions and game spaces," in *Proc. GAME-ON*, 2010 (venue ?). URL: https://www.semanticscholar.org/paper/3d3e491723cd652e9b51bea06919797fbd553141
   — Early statement of player-experience-driven mission/space generation; a precursor to item 3.

5. J. Dormans, "Cyclic generation," ch. in T. X. Short and T. Adams, Eds., *Procedural Generation in Game Design*. Boca Raton, FL, USA: CRC Press, 2017. ISBN 978-1-4987-9919-5 (chapter pages ?)
   — Cyclic dungeon generation used in *Unexplored*: levels are built from cycles (lock-key cycles, valves, shortcuts) rather than trees. Relevant to PGT's braid/cycle modifiers and lock placement. A practitioner analysis is at https://www.boristhebrave.com/2021/04/10/dungeon-generation-in-unexplored/

6. D. Protsenko, J. Dormans, and R. van Rozen, "Maintenance in procedural level design: Lessons from Ludoscope," in *Proc. FDG*, 2025. DOI: 10.1145/3723498.3723784
   — Studies how Ludoscope, the grammar-based generator behind *Unexplored 1/2* (over 20K rewrite rules), evolved. Motivates PGT's modular, inspectable modifier stack as a maintainability argument.

7. R. van Rozen and Q. Heijn, "Measuring quality of grammars for procedural level generation," in *Proc. FDG*, 2018. DOI: 10.1145/3235765.3235821
   — Metrics and tooling (Ludoscope Lite) for grammar quality. Relates to PGT's graph analysis metrics and batch experiments.

8. B. Endrovski, J. Dormans, and R. Bidarra, "What game developers actually want from procedural level generation tools," in *Proc. FDG*, 2026. DOI: 10.1145/3815598.3815682
   — Practitioner requirements for PCG level tools. Useful for motivating PGT's unified authoring + pipeline + simulation environment.

9. R. Corstjens, A. Bouwer, J. Dormans, and R. van Rozen, "Wonderful design: Applying appraisal theory to procedural level generation," in *Proc. EXAG @ AIIDE*, 2018. URL: https://www.semanticscholar.org/paper/1474ec23109da160a248205b3262eeffc72eaf39
   — Grammar-based level generation driven by an emotion/appraisal model. Shows a semantic layer added on top of mission grammars.

10. D. Karavolos, A. Bouwer, and R. Bidarra, "Mixed-initiative design of game levels: Integrating mission and space into level generation," in *Proc. FDG*, 2015. URL: https://www.semanticscholar.org/paper/8953b1aa9b6a1708fe54038e18ab0cf1391ddc33
   — Mixed-initiative tool built on Ludoscope that combines mission and space grammars. A close tool-level comparator to PGT's graph authoring + grammar modifiers.

11. D. Karavolos, A. Liapis, and G. N. Yannakakis, "Evolving missions to create game spaces," in *Proc. IEEE CIG*, 2016. DOI: 10.1109/CIG.2016.7860396
    — Evolves mission graphs (action sequences) and then derives space from them with grammars. Search over graph topology resembles PGT's topology modifiers but is offline optimization.

12. D. Karavolos, A. Liapis, and G. N. Yannakakis, "Evolving missions for Dwarf Quest dungeons," in *Proc. IEEE CIG*, 2016. DOI: 10.1109/CIG.2016.7860391
    — Same approach applied to a commercial game via a layout solver.

13. R. van der Linden, R. Lopes, and R. Bidarra, "Procedural generation of dungeons," *IEEE Trans. Comput. Intell. AI Games*, vol. 6, no. 1, 2014. DOI: 10.1109/TCIAIG.2013.2290371
    — Survey of dungeon PCG that highlights gameplay-grammar control. Background for PGT's dungeon/lock-and-key features.

14. M. Trăichioiu, S. Bakkes, and D. Roijers, "Grammar-based procedural content generation from designer-provided difficulty curves," in *Proc. FDG*, 2015. URL: https://www.semanticscholar.org/paper/be7aa7aa5a5639e8b234bcfb758cb71788037ca2
    — Grammar-driven mission generation steered by a difficulty curve.

15. A. Madkour, S. Marsella, C. Harteveld, M. S. El-Nasr, and J.-W. van de Meent, "Guiding generative graph grammars of dungeon mission graphs via examples," in *Proc. EXAG @ AIIDE*, 2021. URL: https://www.semanticscholar.org/paper/98e4d7a51264e5506029a95763384a3f3291585b
    — Learns rule probabilities of a mission-graph grammar from example graphs.

16. A. Madkour, S. Marsella, and C. Harteveld, "Towards non-technical designer control over PCG systems: Investigating an example-based mechanism for controlling graph grammars," in *Proc. FDG*, 2022. DOI: 10.1145/3555858.3555895
    — Designers pick a region of an expressive-range plot to steer a probabilistic graph grammar. Relates to PGT's batch experiments and metrics feeding back into generation.

17. A. Harisa and W.-K. Tai, "Pacing-based procedural dungeon level generation: Alternating level creation to meet designer's expectations," *Int. J. Comput. Digit. Syst.*, vol. 12, no. 1, 2022. DOI: 10.12785/ijcds/120132
    — Mission/space framework combined with pacing patterns and a GA in a mixed-initiative tool.

18. A. Vatresia, F. P. Utama, and A. Yulianto, "Designing a 3D roguelike game with procedural content generation using the graph grammars method," *J. Teknik Informatika (JUTIF)*, 2023. URL: https://jutif.if.unsoed.ac.id/index.php/jurnal/article/download/546/404
    — Applied Unity implementation of mission graph grammars, showing practitioner uptake of the technique.

19. M. Anshar, R. Sumiharto, and M. E. Wibowo, "Progressive content generation based on cyclic graph for generate dungeon," *IJCCS*, 2023. DOI: 10.22146/ijccs.81178
    — Graph-grammar cyclic dungeon timelines plus fitness-based selection. Relates to PGT's cyclic/braid topology.

20. L. Voisard, C. Politowski, F. Petrillo, and Y.-G. Guéhéneuc, "CG-WFC: A hybrid cyclic-graph & WFC method for designer-guided and replayable procedural content generation," in *Proc. GAS @ ICSE*, 2026. DOI: 10.1145/3786171.3788381
    — The authors' own prior work: cyclic graph grammars set global mission flow and WFC fills local content. Direct predecessor of PGT's graph→tilemap pipeline.

21. J. Vijayakumar and L. Mathew, "On graph grammars and games," arXiv:2403.07607, 2024. DOI: 10.48550/arXiv.2403.07607
    — Formal treatment of graph grammars applied to games.

### A2. Zelda-like / action-adventure dungeon grammars

22. T. Thompson and B. Lavender, "Adventures in Hyrule: Generating missions & maps for action adventure games," in *Proc. FDG*, 2015 (short/poster ?). URL: https://www.semanticscholar.org/paper/99fc188614dc924238d871467ead5ec2562ca960
    — Applies Dormans' grammars to Zelda dungeons. A related report, "A generative grammar approach for action-adventure map generation in The Legend of Zelda" (2017, venue ?), and R. Lavender's thesis "The Zelda dungeon generator" (2016) also exist.

23. J. Gutierrez and J. Schrum, "Generative adversarial network rooms in generative graph grammar dungeons for The Legend of Zelda," in *Proc. IEEE CEC*, 2020. DOI: 10.1109/CEC48606.2020.9185631
    — A graph grammar gives dungeon topology with locks and keys; GAN-generated rooms fill the nodes. A hybrid like PGT's graph pipeline plus rasterizer.

24. N. Heijne and S. Bakkes, "Procedural Zelda: A PCG environment for player experience research," in *Proc. FDG*, 2017. DOI: 10.1145/3102071.3102091
    — Research environment for Zelda-like PCG and player studies. Comparable "research tool" framing to PGT.

25. A. Summerville, M. Behrooz, M. Mateas, and A. Jhala, "The learning of Zelda: Data-driven level generation for action role playing games," in *Proc. FDG*, 2015. URL: https://www.semanticscholar.org/paper/0e6378e0e3215e2aa37ae410144597a59bfb9f94
    — Learns room-graph structure of Zelda dungeons (Bayes net).

26. C. Durham and C. Alvin, "Shortest walk in a dungeon graph," in *Proc. FLAIRS*, 2024. DOI: 10.32473/flairs.37.1.135299
    — Formalizes dungeon graphs with locked edges and key nodes and proves the shortest-walk problem NP-complete. Directly relevant to PGT's solver agent and lock-and-key inventories.

### A3. Lock-and-key / barrier / progression generation (search-based and agent-based)

27. F. Venco and P. L. Lanzi, "An agent-based approach for procedural puzzle generation in graph-based maps," in *Proc. IEEE CoG*, 2021. DOI: 10.1109/CoG52621.2021.9619005
    — Specialized agents add locks, keys and switches to a graph map while guaranteeing no dead-ends. The closest prior work to PGT's semantic modifiers; it is generation-time only, with no runtime regeneration or persistent validator.

28. L. T. Pereira, P. V. S. Prado, and C. Toledo, "Evolving dungeon maps with locked door missions," in *Proc. IEEE CEC*, 2018. DOI: 10.1109/CEC.2018.8477718
    — Tree-encoded GA that guarantees locked-door feasibility.

29. L. T. Pereira, P. V. S. Prado, R. M. Lopes, and C. Toledo, "Procedural generation of dungeons' maps and locked-door missions through an evolutionary algorithm validated with players," *Expert Syst. Appl.*, 2021. DOI: 10.1016/j.eswa.2021.115009
    — Extended version with a 70-player evaluation.

30. B. M. F. Viana, L. T. Pereira, C. Toledo, S. R. dos Santos, and S. M. D. M. Maia, "Feasible-infeasible two-population genetic algorithm to evolve dungeon levels with dependencies in barrier mechanics," *Appl. Soft Comput.*, 2022. DOI: 10.1016/j.asoc.2022.108586
    — FI-2Pop GA for barrier dependencies (keys/locks).

31. B. M. F. Viana, L. T. Pereira, and C. Toledo, "Illuminating the space of dungeon maps, locked-door missions and enemy placement through MAP-Elites," arXiv:2202.09301, 2022. DOI: 10.48550/arXiv.2202.09301
    — Quality-diversity over lock-and-key dungeons. Relates to PGT's batch experiments and expressive-range metrics.

32. L. T. Pereira, B. M. F. Viana, and C. Toledo, "A system for orchestrating multiple procedurally generated content for different player profiles," *IEEE Trans. Games*, vol. 16, no. 1, pp. 64–74, 2024. DOI: 10.1109/TG.2022.3213781
    — A quest grammar frames lock-and-key level generation and enemy generation per player profile. A multi-facet pipeline similar to PGT's stack, but offline.

33. F. Dumont and M.-C. Riff, "2-step evolutionary algorithm for the generation of dungeons with lock door missions using horizontal symmetry," in *Proc. GECCO*, 2024. DOI: 10.1145/3638529.3654153
    — Recent EA for lock-door dungeons.

34. A. S. Ruela and K. V. Delgado, "Scale-free evolutionary level generation," in *Proc. IEEE CIG*, 2018. DOI: 10.1109/CIG.2018.8490366
    — Evolves scale-free graphs for lock-and-key progression with mixed-initiative node/edge editing. PGT ships a scale-free generator and locks as separate composable modifiers.

35. B. M. F. Viana and S. R. dos Santos, "Procedural dungeon generation: A survey," *J. Interactive Systems*, vol. 12, no. 1, 2021. DOI: 10.5753/jis.2021.999
    — Survey that finds barriers/locks and mixed-initiative work under-explored, which supports PGT's motivation. (Earlier SBGames 2019 version: "A survey of procedural dungeon generation.")

36. M. Weeks and J. Davis, "Procedural dungeon generation for a 2D top-down game," in *Proc. ACM SE*, 2022. DOI: 10.1145/3476883.3520214
    — Iterated A* solver that checks solvability of key/lock dungeons. Comparable to PGT's solver agent.

37. A. Baldwin, S. Dahlskog, J. M. Font, and J. Holmberg, "Towards pattern-based mixed-initiative dungeon generation," in *Proc. FDG*, 2017. DOI: 10.1145/3102071.3110572
    — Evolutionary Dungeon Designer with design patterns.

### A4. Key-item randomizers / progression reachability

38. C. H. Johnson, J. L. Trahan, T. Lu, and L. Peng, "Evaluation of algorithms for randomizing key item locations in game worlds," *IEEE Access*, vol. 9, pp. 48286–48302, 2021. DOI: 10.1109/ACCESS.2021.3069114
    — World graph with item-gated edges; compares Random/Forward/Assumed Fill for completable placement. Closely related to PGT's lock-and-key placement and its reachability checks. Code: github.com/cjohnson57/RandomizerAlgorithms

39. M. Rengaraj, "Graph-guided item randomizers: Formal models, search strategies, and metrics for procedural game worlds," *Int. J. Intell. Syst. Data Sci.*, 2026. DOI: 10.67231/g4jy1309
    — Formalizes key-item placement as reachability on rule-constrained digraphs, with metrics. A recent, lower-tier venue.

40. M. Cook and A. Raad, "Hyperstate space graphs," *IEEE Trans. Games*, 2022. DOI: 10.1109/TG.2021.3095393 (CoG 2019 version: 10.1109/CIG.2019.8848026)
    — State graphs that include inventory/progress for automated game analysis. Related to PGT's inventory-aware solver agents and validator.

41. I. Ruslanova, R. Mawhorter, and P. Mawhorter, "Representing exploration in Metroidvania games," (venue/year ?). URL: https://cs.wellesley.edu/~pmwh/mvmap/papers/reimg/reimg.html
    — Sequence-of-graphs representation of Metroidvania exploration, with an open-source Python `exploration` library. Relevant to PGT's temporally-aware progression (state changing over time).

42. J. Xu and J. Morris, "Procedural generation in 2D Metroidvania game with answer set programming," in *Computer Science & Information Technology (CS & IT)*, 2023. DOI: 10.5121/csit.2023.130511
    — ASP prevents softlocks (keys behind gates) in Unity Metroidvania levels. Low-tier venue, but on topic.

### A5. Constraint-based generation with solvability guarantees (ASP / SAT / SMT / CP)

43. A. M. Smith and M. Mateas, "Answer set programming for procedural content generation: A design space approach," *IEEE Trans. Comput. Intell. AI Games*, vol. 3, no. 3, 2011. DOI: 10.1109/TCIAIG.2011.2158545
    — Foundational ASP-for-PCG paper.

44. A. M. Smith, E. Andersen, M. Mateas, and Z. Popović, "A case study of expressively constrainable level design automation tools for a puzzle game," in *Proc. FDG*, 2012. DOI: 10.1145/2282338.2282370
    — ASP-based generation and progression design for *Refraction*.

45. T. Smith, J. Padget, and A. Vidler, "Graph-based generation of action-adventure dungeon levels using answer set programming," in *Proc. FDG*, 2018. DOI: 10.1145/3235765.3235817
    — ASP generates acyclic lock-and-key dungeon graphs under hard constraints. PGT instead uses constructive modifiers with simulation-based validation and supports cycles.

46. I. Horswill and L. Foged, "Fast procedural level population with playability constraints," in *Proc. AIIDE*, 2012, pp. 20–25. URL: https://ojs.aaai.org/index.php/AIIDE/article/view/12511
    — Interval constraint propagation over paths, which ensures keys are not behind their own doors. Fast enough for runtime use.

47. I. Horswill, "CatSAT: A practical, embedded, SAT language for runtime PCG," in *Proc. AIIDE*, 2018. DOI: 10.1609/aiide.v14i1.13026
    — Runtime-embedded solver that adapts solutions as gameplay changes. Related to PGT's runtime regeneration.

48. S. Bayless, N. Bayless, H. H. Hoos, and A. J. Hu, "SAT modulo monotonic theories," in *Proc. AAAI*, 2015. DOI: 10.1609/aaai.v29i1.9755
    — Graph reachability theories for SAT, applied to PCG.

49. A. M. Abuzuraiq, A. Ferguson, and P. Pasquier, "Taksim: A constrained graph partitioning framework for procedural content generation," in *Proc. IEEE CoG*, 2019. DOI: 10.1109/CIG.2019.8848065
    — ASP graph partitioning that maps a mission graph onto space. Related earlier work: A. M. Abuzuraiq, FDG 2017, DOI 10.1145/3102071.3110575.

50. J. Whitehead, "Spatial layout of procedural dungeons using linear constraints and SMT solvers," in *Proc. FDG (PCG Workshop)*, 2020. DOI: 10.1145/3402942.3409603
    — SMT-based room placement.

51. G. Glorian, A. Debesson, S. Yvon-Paliot, and L. Simon, "The dungeon variations problem using constraint programming," in *Proc. CP*, LIPIcs vol. 210, 2021. DOI: 10.4230/LIPIcs.CP.2021.27
    — CP generation of dungeon variants (industrial collaboration).

52. R. Mawhorter and A. M. Smith, "Analytic procgen with composable design space expressions," in *Proc. FDG*, 2025. DOI: 10.1145/3723498.3723795
    — Composable generators with analyzable design spaces. Conceptually close to PGT's stack of composable modifiers.

### A6. Sturgeon series and level+playthrough co-generation (Cooper et al.)

53. S. Cooper, "Sturgeon: Tile-based procedural level generation via learned and designed constraints," in *Proc. AIIDE*, 2022. DOI: 10.1609/aiide.v18i1.21944
    — Base constraint-solver system. Code: github.com/crowdgames/sturgeon-pub

54. S. Cooper, "Sturgeon-GRAPH: Constrained graph generation from examples," in *Proc. FDG (PCG Workshop)*, 2023. DOI: 10.1145/3582437.3582465
    — Constraint-based generation of graphs, such as dungeon room graphs, learned from examples. A graph-level counterpart to PGT's generators.

55. S. Cooper, "Sturgeon-MKIII: Simultaneous level and example playthrough generation via constraint satisfaction with tile rewrite rules," in *Proc. FDG*, 2023. DOI: 10.1145/3582437.3587205
    — Generates the level and its solution together, including lock-and-key dungeons. PGT validates with agents after generation instead of by construction.

56. S. Cooper and M. Bazzaz, "Sturgeon-MKIV: Constraint-based level and playthrough generation with graph label rewrite rules," in *Proc. AIIDE*, 2024. DOI: 10.1609/aiide.v20i1.31862
    — Graph-based levels with mechanics as label rewrites. The closest constraint-based analogue to PGT's graph + agent simulation.

57. S. Cooper and M. Bazzaz, "A constraint-based graph grammar approach unifying level and playthrough generation," in *Proc. EXAG @ AIIDE*, CEUR-WS vol. 4090, 2025. URL: https://ceur-ws.org/Vol-4090/short5.pdf
    — One graph grammar produces both level and playthrough, preventing keys behind locks. Very close to PGT's grammar + lock-and-key; it is offline and holistic, while PGT does local runtime regeneration.

58. S. Cooper and M. Bazzaz, "Literally unplayable: On constraint-based generation of uncompletable levels," in *Proc. FDG*, 2024. DOI: 10.1145/3649921.3659844
    — Generates uncompletable levels to test validators and classifiers. Relevant to testing PGT's validator agent.

59. S. Cooper and M. Bazzaz, "Stuck in the middle: Generating levels without (or with) softlocks," in *Proc. FDG*, 2025. DOI: ?  URL: https://pcgworkshop.com/archive/cooper2025softlocks.pdf
    — Constraint-based avoidance or repair of softlocks. Directly related to PGT's persistent validator and its no-softlock guarantees across regenerations.

60. H. Mao and S. Cooper, "Segment-wise level generation using iterative constrained extension," in *Proc. IEEE CoG*, 2023. DOI: 10.1109/CoG57401.2023.10333222
    — Extends levels segment by segment while keeping prior tiles and solution path fixed. The closest prior work to PGT's partial regeneration that preserves surrounding topology.

61. K. Facey and S. Cooper, "Toward space-time WaveFunctionCollapse for level and solution generation," in *Proc. AIIDE*, 2024. DOI: 10.1609/aiide.v20i1.31863
    — Learns solvability by applying WFC to space-time blocks.

62. A. Vandara and S. Cooper, "Spacetime constraints for continuous gameplay," in *Proc. FDG*, 2026. DOI: 10.1145/3815598.3815715
    — SMT spacetime level+path generation for continuous physics gameplay.

63. K. Xu and C. Verbrugge, "High dimensional procedural content generation," in *Proc. FDG*, 2026. arXiv:2602.18943
    — Time-expanded graphs and layer dimensions for reachability validation. Relates to PGT's temporally-aware progression. (See also K. Xu and C. Verbrugge, "A database-driven framework for 3D level generation with LLMs," AIIDE 2025, arXiv:2508.18533, on progression-based mechanic placement.)

### A7. Mission graph → space layout (graph realization)

64. C. Ma, N. Vining, S. Lefebvre, and A. Sheffer, "Game level layout from design specification," *Comput. Graph. Forum*, vol. 33, no. 2, 2014. DOI: 10.1111/cgf.12314
    — Lays out a level from a connectivity graph plus room templates via configuration spaces. Relates to PGT's graph→tilemap rasterizer.

65. O. Nepožitek and J. Gemrot, "Fast configurable tile-based dungeon level generator," (Charles University tech. paper, 2018; venue ?). URL: https://artemis.ms.mff.cuni.cz/main/papers/Fast_Configurable_Tile_Based_Dungeon_Level_Generator.pdf
    — Extends Ma et al. for 2D tile maps; basis of the Edgar generator. A practical comparator for PGT's rasterization.

66. M. Eger, "Infinite dungeon generation constrained by sketches using growing graph wave function collapse," in *Proc. I3D Companion*, 2026. DOI: 10.1145/3807895.3807922
    — Sketched room-type graphs become constraints maintained while an infinite dungeon grows. Related to PGT's incremental, topology-preserving runtime generation.

67. S. Cooper and E. Balema, "Learning constrained graph layout for content generation," in *Proc. EXAG @ AIIDE*, 2023. URL: https://www.semanticscholar.org/paper/3c1c35a10f577584b71e5f48607dc184fe888f42
    — Learned layout of generated graphs into space.

### A8. Quest / narrative graphs linked to space; puzzle-dependency generation

68. C. Ashmore and M. Nitsche, "The quest in a generated world," in *Proc. DiGRA*, 2007. DOI: 10.26503/dl.v2007i1.312
    — Key-lock quest generator that treats quests as spatial progression. Pre-2008 but foundational.

69. K. Hartsook, A. Zook, S. Das, and M. O. Riedl, "Toward supporting stories with procedurally generated game worlds," in *Proc. IEEE CIG*, 2011, pp. 297–304. URL: https://faculty.cc.gatech.edu/~riedl/pubs/cig11.pdf
    — GAME FORGE searches for a world layout that supports a sequence of plot points.

70. J. Valls-Vargas, S. Ontañón, and J. Zhu, "Towards story-based content generation: From plot-points to maps," in *Proc. IEEE CIG*, 2013. DOI: 10.1109/CIG.2013.6633654
    — Maps plot-point graphs to spatial maps.

71. A. Zook, S. Lee-Urban, M. R. Drinkwater, and M. O. Riedl, "Skill-based mission generation: A data-driven temporal player modeling approach," in *Proc. PCG Workshop @ FDG*, 2012. DOI: 10.1145/2538528.2538534
    — Mission generation that adapts to modeled player skill over time.

72. C. Fernández-Vara and A. Thomson, "Procedural generation of narrative puzzles in adventure games: The puzzle-dice system," in *Proc. PCG Workshop @ FDG*, 2012. DOI: 10.1145/2538528.2538538
    — Puzzle-dependency generation from composable puzzle templates. Relates to PGT's logic-gate and lock semantics.

73. I. Dart and M. J. Nelson, "Smart terrain causality chains for adventure-game puzzle generation," in *Proc. IEEE CIG*, 2012. DOI: 10.1109/CIG.2012.6374173
    — Generates item-causality dependency chains for puzzles.

74. R. Alexander and C. Martens, "Deriving quests from open world mechanics," in *Proc. FDG*, 2017. DOI: 10.1145/3102071.3102098
    — Derives quests by planning over world mechanics.

75. A. Stocker and C. Alvin, "Non-linear quest generation," in *Proc. FLAIRS*, 2018. URL: https://www.semanticscholar.org/paper/ea810a73343c33c69fbf029924c07be9f50bf491
    — Generates non-linear quest graphs.

76. A. Alvarez, E. Grevillius, E. Olsson, and J. Font, "Questgram [Qg]: Toward a mixed-initiative quest generation tool," in *Proc. FDG*, 2021. DOI: 10.1145/3472538.3472544
    — Mixed-initiative quest grammar tool linked to dungeon spaces in EDD.

77. J. Valls-Vargas, J. Zhu, and S. Ontañón, "Graph grammar-based controllable generation of puzzles for a learning game about parallel programming," in *Proc. FDG*, 2017. DOI: 10.1145/3102071.3102079
    — Controllable graph-grammar puzzle generation.

78. D. Priemer, T. George, M. Hahn, L. Raesch, and A. Zündorf, "Using graph transformation for puzzle game level generation and validation," in *Proc. ICGT*, LNCS, 2016. DOI: 10.1007/978-3-319-40530-8_14
    — Graph transformation for both generation and validation. A formal-methods counterpart to PGT's grammar + validator.

79. B. De Kegel and M. Haahr, "Procedural puzzle generation: A survey," *IEEE Trans. Games*, vol. 12, no. 1, 2020. DOI: 10.1109/TG.2019.2917792
    — Survey that covers dependency-graph puzzle generation.

### A9. Runtime / adaptive generation (closest to PGT's runtime regeneration)

80. R. Lopes, E. Eisemann, and R. Bidarra, "Authoring adaptive game world generation," *IEEE Trans. Games*, vol. 10, no. 1, pp. 42–55, 2018. DOI: ? (TU Delft repository)
    — Adaptation rules over gameplay semantics steer online content generation. Related to PGT's adaptive runtime regeneration, but uses semantic world generation rather than graph topology with lock constraints.

---

### Open-source tools / repositories in this theme

- **Edgar-DotNet** (graph-based 2D dungeon/platformer generator from room graph + templates; Ma et al. lineage): https://github.com/OndrejNepozitek/Edgar-DotNet
- **Edgar-Unity** (Unity plugin): https://github.com/OndrejNepozitek/Edgar-Unity
- **Edgar.Godot** (Godot port/integration, MIT): https://github.com/RickyYCheng/Edgar.Godot (the existing Godot comparator for PGT)
- **Sturgeon** (Cooper's constraint-based level/playthrough generator, incl. MKIII/MKIV): https://github.com/crowdgames/sturgeon-pub
- **RandomizerAlgorithms** (Random/Forward/Assumed Fill key-item placement): https://github.com/cjohnson57/RandomizerAlgorithms
- **exploration** (Python/networkx library for Metroidvania exploration graphs; Mawhorter et al.): https://cs.wellesley.edu/~pmwh/mvmap/
- **Ludoscope / Ludoscope Lite** (Dormans' grammar-transformation tool; used in *Unexplored*): described in items 6–7 and 10 (public availability not verified)
- Grey literature: Boris the Brave, "Dungeon generation in Unexplored" (2021), https://www.boristhebrave.com/2021/04/10/dungeon-generation-in-unexplored/

### Notes on positioning (for the paper)

- Nearly all prior lock-and-key generators (items 27–37, 45, 55–57) guarantee solvability **at generation time** and are **offline**. Only items 60 (segment-wise constrained extension), 66 (growing graph WFC), 47 (CatSAT runtime) and 80 (adaptive online generation) touch runtime/incremental generation. None combine (a) trigger-based partial regeneration that preserves surrounding topology, (b) lock-and-key re-planning conditioned on the player's current location and inventory, and (c) a persistent validator agent across regenerations.
- Items 57, 59, 40 and 26 provide formal framing (playthrough co-generation, softlocks, hyperstate graphs, NP-hardness of dungeon walks) that PGT's temporal lock-and-key and validator can be positioned against.

---

## Theme B — Graph-to-layout methods and PCG tools (related work for "Procedural Graph Tools")

Search log (2026-10-22): Semantic Scholar keyword search plus forward citation chasing on Ma et al. 2014 (46 citing papers) and Karth & Smith 2017 (~100 citing); Crossref metadata/DOI verification for each paper; GitHub API for repo metadata (license, stars, last push); web search for commercial tools. Zotero was not queried in this pass. Every DOI below resolved via Crossref, except where marked. "?" = could not verify.

Relation codes: **[G2L]** graph→spatial layout, **[RAS]** raster/tile passes (CA, corridors, decoration), **[WFC]**, **[PIPE]** multi-stage/stacked pipeline, **[MI]** mixed-initiative/editor.

---

### Part 1 — Papers

#### 1.1 Graph → room layout (game levels)

[1] C. Ma, N. Vining, S. Lefebvre, and A. Sheffer, "Game level layout from design specification," *Computer Graphics Forum*, vol. 33, no. 2, pp. 95–104, 2014. doi: 10.1111/cgf.12314.
— Takes a level connectivity graph and a set of room polygons and places rooms so adjacent nodes share doors, using configuration spaces and incremental chain decomposition. **[G2L]** The basic reference for our graph→room step. Their method stops at room placement and does not rasterize, route corridors or decorate.

[2] O. Nepožitek and J. Gemrot, "Fast configurable tile-based dungeon level generator," in *Proc. GAME-ON* (EUROSIS), 2018 (venue ?). URL: https://artemis.ms.mff.cuni.cz/main/papers/Fast_Configurable_Tile_Based_Dungeon_Level_Generator.pdf
— Reimplements Ma et al. on 2D tilemaps with simulated annealing, adds features, and reports up to 100× speedup, fast enough for runtime use. **[G2L]** This is the algorithm inside Edgar. It is the closest prior tile-based graph→layout method.

[3] O. Nepožitek, "Procedural level generator with Unity integration," M.S. thesis, Charles University, Prague, 2020 (year ?). URL: https://dspace.cuni.cz/handle/20.500.11956/120962
— Extends [2] with corridor rooms and platformer support, integrates it with Unity, and compares output with *Enter the Gungeon* and *Dead Cells* levels. **[G2L][RAS]** Corridors are template rooms here, whereas we route corridors (organic or orthogonal).

[4] J. Whitehead, "Spatial layout of procedural dungeons using linear constraints and SMT solvers," in *Proc. FDG*, 2020. doi: 10.1145/3402942.3409603.
— Encodes graph-to-room layout as linear constraints solved by an SMT solver. **[G2L]** An alternative to stochastic placement. Useful for contrasting with our deterministic modifier stack.

[5] T. Smith, J. Padget, and A. Vidler, "Graph-based generation of action-adventure dungeon levels using answer set programming," in *Proc. FDG*, 2018. doi: 10.1145/3235765.3235817.
— Uses ASP to generate graph-based dungeons with lock-and-key structure and evaluates them by expressive range. **[G2L]** Shows graph-level constraints carried into space.

[6] G. Glorian, A. Debesson, S. Yvon-Paliot, and L. Simon, "The dungeon variations problem using constraint programming," in *Proc. CP 2021*, LIPIcs vol. 210, 2021. doi: 10.4230/LIPIcs.CP.2021.27.
— Generates dungeon variants from a graph abstraction with constraint programming, adding a propagator for cyclic directed graphs (industry collaboration with Ubisoft, per affiliations ?). **[G2L]**

[7] K. Sfikas, A. Liapis, and G. N. Yannakakis, "A general-purpose expressive algorithm for room-based environments," in *Proc. FDG*, 2022. doi: 10.1145/3555858.3563262.
— Generates room-based environments that are not tied to a genre, using an expressive constructive algorithm. **[G2L]** A comparable generalist room-layout generator. A cited follow-up of Ma et al.

[8] R. van der Linden, R. Lopes, and R. Bidarra, "Procedural generation of dungeons," *IEEE Trans. Comput. Intell. AI Games*, vol. 6, no. 1, pp. 78–89, 2014. doi: 10.1109/TCIAIG.2013.2290371.
— Survey of dungeon generation: cellular automata, grammars, genetic algorithms and constraint methods. Argues for gameplay-based control. **[G2L][RAS]** Standard survey to cite when positioning our raster passes.

[9] N. Shaker, A. Liapis, J. Togelius, R. Lopes, and R. Bidarra, "Constructive generation methods for dungeons and levels," in *Procedural Content Generation in Games*, Springer, 2016, ch. 3. doi: 10.1007/978-3-319-42716-4_3.
— Textbook chapter on BSP, agent-based diggers, cellular automata and grammar dungeon methods. **[RAS]** Canonical citation for the constructive passes our rasterizer uses.

[10] M. C. Green, A. Khalifa, A. Alsoughayer, D. Surana, A. Liapis, and J. Togelius, "Two-step constructive approaches for dungeon generation," in *Proc. FDG*, 2019. doi: 10.1145/3337722.3341847.
— Splits dungeon generation into a layout step and a content-placement step. **[PIPE][RAS]** Mirrors our split between room layout and entity scattering/decoration.

[11] V. Valtchanov and J. A. Brown, "Evolving dungeon crawler levels with relative placement," in *Proc. C3S2E*, 2012. doi: 10.1145/2347583.2347587.
— Evolves room-placement trees, where rooms are placed relative to their parents. **[G2L]** Search-based tree→layout.

[12] D. Ashlock, C. Lee, and C. McGuinness, "Search-based procedural generation of maze-like levels," *IEEE Trans. Comput. Intell. AI Games*, vol. 3, no. 3, pp. 260–273, 2011. doi: 10.1109/TCIAIG.2011.2138707.
— Search-based maze and cave level generation with several representations and fitness functions. **[RAS]**

[13] S. Snodgrass, "Levels from sketches with example-driven binary space partition," in *Proc. AIIDE*, 2019. doi: 10.1609/aiide.v15i1.5227.
— Turns designer sketches into levels using BSP driven by examples. **[RAS][MI]** Related to our BSP/room allocation and to designer-sketched input. Cites Ma et al.

[14] M. Rinaldi and C.-G. Chiru, "Two-scale controllability of a parameterized BSP dungeon generator for player flow optimization," *IEEE Trans. Games*, 2026. doi: 10.1109/TG.2026.3702534.
— Recent work on controlling a parameterized BSP dungeon generator at two scales. **[RAS]** Recent ToG evidence that BSP parameter control is still an active topic.

[15] S. Monteiro and R. Nóbrega, "Procedural floor plan generation for simulations: Rooms and corridors on demand," in *Proc. ICGI*, 2025. doi: 10.1109/ICGI68463.2025.11302622.
— Generates room and corridor floor plans for simulation use. **[G2L][RAS]** Shares our "layout for agent simulation" use case.

[16] H. Liu, Z. Wang, A. Mazumdar, and C. Mousas, "Virtual reality game level layout design for real environment constraints," *Graphics and Visual Computing*, vol. 4, 2021. (Elsevier, open access; DOI ?) URL: https://www.sciencedirect.com/science/article/pii/S2666629421000036
— Assembles game-level chunks under real-room constraints by cost optimization. **[G2L]** Chunk assembly. Builds on Ma et al.

[17] H. Liu, M. Choi, D. Kao, and C. Mousas, "Synthesizing game levels for collaborative gameplay in a shared virtual environment," *ACM Trans. Interact. Intell. Syst.*, vol. 13, no. 1, 2023. doi: 10.1145/3558773.
— Optimization-based synthesis of level layouts for collaborative VR play. **[G2L]**

[18] P. Merrell, "Example-based procedural modeling using graph grammars," *ACM Trans. Graph.*, vol. 42, no. 4, 2023. doi: 10.1145/3592119.
— Infers graph grammars from example shapes and generates new shapes from them. **[G2L]** Bridges graph grammars and spatial output.

#### 1.2 Mission/space graphs, grammars and cyclic generation

[19] J. Dormans, "Adventures in level design: Generating missions and spaces for action adventure games," in *Proc. PCG Workshop (FDG)*, 2010. doi: 10.1145/1814256.1814257.
— Generates mission graphs with graph grammars, then transforms them into space. **[G2L][PIPE]** Origin of the mission→space split that our authoring→raster pipeline follows.

[20] J. Dormans and S. Bakkes, "Generating missions and spaces for adaptable play experiences," *IEEE Trans. Comput. Intell. AI Games*, vol. 3, no. 3, pp. 216–228, 2011. doi: 10.1109/TCIAIG.2011.2149523.
— Journal version: mission and space grammars for adaptable play. **[G2L]**

[21] J. Dormans, "Level design as model transformation: A strategy for automated content generation," in *Proc. PCG Workshop*, 2011. doi: 10.1145/2000919.2000921.
— Frames generation as a chain of model transformations, which became Ludoscope. **[PIPE]** The closest conceptual predecessor of our stack of modifiers over graphs and grids.

[22] D. Protsenko, J. Dormans, and R. van Rozen, "Maintenance in procedural level design: Lessons from Ludoscope," in *Proc. FDG*, 2025. doi: 10.1145/3723498.3723784.
— Reports on maintaining Ludoscope grammar pipelines at production scale (*Unexplored 2*: more than 20K rewrite rules). **[PIPE][MI]** Highly relevant to our argument for tooling and inspectability (timeline, step-through).

[23] J. Dormans, "Cyclic generation," in T. X. Short and T. Adams, Eds., *Procedural Generation in Game Design*. CRC Press, 2017. doi: 10.1201/9781315156378-11.
— Cyclic dungeon generation as used in *Unexplored*. **[G2L]** Supports graphs with cycles as first-class level structure.

[24] T. X. Short and T. Adams, Eds., *Procedural Generation in Game Design*. Boca Raton, FL: CRC Press, 2017. doi: 10.1201/9781315156378.
— Practitioner-oriented edited volume on PCG in shipped games. Use it as the general citation for industry practice.

[25] J. Gutierrez and J. Schrum, "Generative adversarial network rooms in generative graph grammar dungeons for *The Legend of Zelda*," in *Proc. IEEE CEC*, 2020. doi: 10.1109/CEC48606.2020.9185631.
— A graph grammar produces dungeon topology and a GAN fills in each room. **[G2L][PIPE]** A hybrid of graph structure and per-room content, comparable to our custom rooms and zone decoration.

[26] S. Cooper and M. Bazzaz, "Sturgeon-MKIV: Constraint-based level and playthrough generation with graph label rewrite rules," in *Proc. AIIDE*, 2024. doi: 10.1609/aiide.v20i1.31862.
— Constraint-based generation over graphs using node/edge label rewrite rules. **[G2L][PIPE]**

[27] S. Cooper, "Sturgeon-GRAPH: Constrained graph generation from examples," in *Proc. FDG*, 2023. doi: 10.1145/3582437.3582465.
— Learns graph constraints from examples and generates new graphs. Relevant to our graph-authoring and modifier stage.

#### 1.3 Cellular automata, caves and raster post-processing

[28] L. Johnson, G. N. Yannakakis, and J. Togelius, "Cellular automata for real-time generation of infinite cave levels," in *Proc. PCG Workshop (FDG)*, 2010. doi: 10.1145/1814256.1814266.
— Classic cellular-automaton cave generation at runtime, chunked so it can extend indefinitely. **[RAS]** The base reference for our CA smoothing/erosion passes and runtime partial regeneration.

[29] A. Pech, M. Masek, C.-P. Lam, and P. Hingston, "Game level layout generation using evolved cellular automata," *Connection Science*, vol. 28, no. 1, 2016. doi: 10.1080/09540091.2015.1130020.
— Evolves cellular-automaton rules to produce level layouts. **[RAS]**

[30] S. Snodgrass and S. Ontañón, "Procedural level generation using multi-layer level representations with MdMCs," in *Proc. IEEE CIG*, 2017. doi: 10.1109/CIG.2017.8080447.
— Generates levels as multiple stacked layers with multi-dimensional Markov chains. **[PIPE]** Related to our layered raster (biome, zone and structure layers).

[31] E. Sayyad, T. Rothman, and Z. Zhai, "Zenith: Procedural and diffusion-driven generation of multi-layered top-down maps," in *SIGGRAPH Asia Posters*, 2025. doi: 10.1145/3757374.3771776.
— Combines procedural and diffusion stages to produce top-down maps with several layers. **[PIPE]**

#### 1.4 WaveFunctionCollapse and constraint-based tile synthesis

[32] P. Merrell and D. Manocha, "Model synthesis: A general procedural modeling algorithm," *IEEE Trans. Vis. Comput. Graphics*, vol. 17, no. 6, 2011. doi: 10.1109/TVCG.2010.112.
— Model synthesis, the precursor of WFC: adjacency-constrained tile synthesis.

[33] I. Karth and A. M. Smith, "WaveFunctionCollapse is constraint solving in the wild," in *Proc. FDG*, 2017. doi: 10.1145/3102071.3110566.
— Shows that Gumin's WFC is a constraint solver and surveys how games used it. **[WFC]** Core citation for our textural WFC overlay.

[34] I. Karth and A. M. Smith, "WaveFunctionCollapse: Content generation via constraint solving and machine learning," *IEEE Trans. Games*, vol. 14, no. 3, pp. 364–376, 2022. doi: 10.1109/TG.2021.3076368.
— Journal treatment of WFC that adds learned constraints and design control. **[WFC]**

[35] H. Kim, S. Lee, H. Lee, T. Hahn, and S. Kang, "Automatic generation of game content using a graph-based wave function collapse algorithm," in *Proc. IEEE CoG*, 2019. doi: 10.1109/CIG.2019.8848019.
— Runs WFC on arbitrary graphs instead of grids. **[WFC][G2L]** Directly relevant: WFC over graph structure.

[36] M. Eger, "Infinite dungeon generation constrained by sketches using growing graph wave function collapse," in *Companion Proc. I3D*, 2026. doi: 10.1145/3807895.3807922.
— A designer sketches a room-type graph, and growing-graph WFC generates unbounded dungeons that keep its constraints. **[WFC][G2L][MI]** Very close in spirit: a designer graph constrains spatial generation.

[37] A. Sandhu, Z. Chen, and J. McCoy, "Enhancing wave function collapse with design-level constraints," in *Proc. FDG*, 2019. doi: 10.1145/3337722.3337752.
— Adds designer-level constraints to WFC. **[WFC][MI]**

[38] T. Langendam and R. Bidarra, "miWFC – Designer empowerment through mixed-initiative wave function collapse," in *Proc. FDG*, 2022. doi: 10.1145/3555858.3563266.
— A mixed-initiative WFC tool in which designers paint and lock tiles. **[WFC][MI]**

[39] S. Alaka and R. Bidarra, "Hierarchical semantic wave function collapse," in *Proc. FDG*, 2023. doi: 10.1145/3582437.3587209.
— Adds semantic tile hierarchies (meta-tiles) to WFC. **[WFC][PIPE]** Comparable to our zone/biome→texture layering.

[40] S. Alaka and R. Bidarra, "Mixed-initiative generation of virtual worlds — A comparative study on the cognitive load of WFC and HSWFC," in *Proc. FDG*, 2024. doi: 10.1145/3649921.3659852.
— User study measuring designer cognitive load with WFC and HSWFC tools. **[MI]** A model for how we could evaluate our tool with users.

[41] A. Newgas, "Tessera: A practical system for extended WaveFunctionCollapse," in *Proc. FDG*, 2021. doi: 10.1145/3472538.3472605.
— The system paper behind the Tessera Unity asset (big tiles, constraints). **[WFC]** Also listed in the tools table.

[42] I. Karth, B. Aytemiz, R. Mawhorter, and A. M. Smith, "Neurosymbolic map generation with VQ-VAE and WFC," in *Proc. FDG*, 2021. doi: 10.1145/3472538.3472584.
— Combines a learned latent tile vocabulary with WFC. **[WFC]**

[43] M. Babin and M. Katchabaw, "Leveraging reinforcement learning and WaveFunctionCollapse for improved procedural level generation," in *Proc. FDG*, 2021. doi: 10.1145/3472538.3472541.
— Combines reinforcement learning with WFC for level generation. **[WFC]**

[44] R. Bailly and G. Levieux, "Genetic-WFC: Extending wave function collapse with genetic search," *IEEE Trans. Games*, vol. 15, no. 1, 2023. doi: 10.1109/TG.2022.3192930.
— Adds genetic search on top of WFC to optimize global properties. **[WFC]**

[45] R. Piepenbrink and R. Bidarra, "Non-uniform tile wave function collapse," in *Proc. IEEE CoG*, 2025. doi: 10.1109/CoG64752.2025.11114084; and "Meaningful content diversity through nonuniform tile WFC," *IEEE Trans. Games*, 2026. doi: 10.1109/TG.2026.3696210.
— WFC with tiles of varying size, closer to rooms or chunks of different footprints. **[WFC][G2L]** Relevant to placing variable-size custom rooms.

[46] R. Christie, B. Kitchen, W. Tumilowicz, S. Hooper, and B. C. Wünsche, "Procedurally generating large synthetic worlds: Chunked hierarchical wave function collapse," in *Proc. IVCNZ*, 2024. doi: 10.1109/IVCNZ64857.2024.10794452.
— Chunked, hierarchical WFC that scales to large worlds. **[WFC][PIPE]** Relates to our partial and chunked regeneration.

[47] O. Montoya, F. Srb, D. Grbic, and S. Risi, "CPPN2WFC: Extending wave function collapse to generate globally coherent content," in *Proc. GECCO*, 2025. doi: 10.1145/3712256.3726401.
— Uses a CPPN as a global guide to fix WFC's lack of global structure. **[WFC][PIPE]** Same principle as ours: a global structure (for us, the graph) guides local WFC.

[48] S. Cooper, "Sturgeon: Tile-based procedural level generation via learned and designed constraints," in *Proc. AIIDE*, 2022. doi: 10.1609/aiide.v18i1.21944.
— Constraint-based tile-level generation with a solver-independent API. **[WFC]** Also listed in the tools table.

[49] K. Facey and S. Cooper, "Toward space-time WaveFunctionCollapse for level and solution generation," in *Proc. AIIDE*, 2024. doi: 10.1609/aiide.v20i1.31863.
— Extends WFC over time so a level and its solution are generated together. **[WFC]**

#### 1.5 Floorplans and buildings from graphs (architecture/graphics; selected)

[50] P. Merrell, E. Schkufza, and V. Koltun, "Computer-generated residential building layouts," *ACM Trans. Graph.*, vol. 29, no. 6, 2010. doi: 10.1145/1882262.1866203.
— Learns an architectural program (a Bayesian network) and turns it into floor plans by optimization. **[G2L]**

[51] F. Marson and S. R. Musse, "Automatic real-time generation of floor plans based on squarified treemaps algorithm," *Int. J. Comput. Games Technol.*, 2010. doi: 10.1155/2010/624817.
— Real-time floor plans for games built from treemap subdivision, with corridors inserted afterwards. **[G2L][RAS]** A precedent for corridor insertion after room allocation.

[52] R. Lopes, T. Tutenel, R. M. Smelik, K. J. de Kraker, and R. Bidarra, "A constrained growth method for procedural floor plan generation," in *Proc. GAME-ON*, 2010 (DOI ?; authors list ? — not Crossref-verified).
— Grid-based room growth from seeds. **[RAS]** Similar to our room allocation and merging on a grid. *Verify before citing.*

[53] N. Nauata, K.-H. Chang, C.-Y. Cheng, G. Mori, and Y. Furukawa, "House-GAN: Relational generative adversarial networks for graph-constrained house layout generation," in *Proc. ECCV*, LNCS, 2020. doi: 10.1007/978-3-030-58452-8_10.
— A GAN generates room boxes from a bubble (adjacency) graph. **[G2L]** The learned counterpart of graph→layout.

[54] R. Hu, Z. Huang, Y. Tang, O. van Kaick, H. Zhang, and H. Huang, "Graph2Plan: Learning floorplan generation from layout graphs," *ACM Trans. Graph.*, vol. 39, no. 4, 2020. doi: 10.1145/3386569.3392391.
— Generates floor plans from a user-edited layout graph and a building boundary. **[G2L][MI]**

[55] M. A. Shabani, S. Hosseini, and Y. Furukawa, "HouseDiffusion: Vector floorplan generation via a diffusion model with discrete and continuous denoising," in *Proc. CVPR*, 2023. doi: 10.1109/CVPR52729.2023.00529.
— Diffusion model that turns a graph into a vector floor plan. **[G2L]**

[56] W. Wu, X.-M. Fu, R. Tang, Y. Wang, Y.-H. Qi, and L. Liu, "Data-driven interior plan generation for residential buildings," *ACM Trans. Graph.*, vol. 38, no. 6, 2019. doi: 10.1145/3355089.3356556.
— Learns to generate floor plans (RPLAN dataset). **[G2L]**

#### 1.6 Mixed-initiative editors and PCG infrastructure (selected, layout-relevant)

[57] G. Smith, J. Whitehead, and M. Mateas, "Tanagra: Reactive planning and constraint solving for mixed-initiative level design," *IEEE Trans. Comput. Intell. AI Games*, vol. 3, no. 3, 2011. doi: 10.1109/TCIAIG.2011.2159716. **[MI]**

[58] A. Alvarez, S. Dahlskog, J. Font, J. Holmberg, C. Nolasco, and A. Österman, "Fostering creativity in the mixed-initiative evolutionary dungeon designer," in *Proc. FDG*, 2018. doi: 10.1145/3235765.3235815. — A room-based dungeon editor in which rooms are graph nodes. **[MI][G2L]**

[59] A. Alvarez, S. Dahlskog, J. Font, and J. Togelius, "Empowering quality diversity in dungeon design with interactive constrained MAP-Elites," in *Proc. IEEE CoG*, 2019. doi: 10.1109/CIG.2019.8848022. **[MI]**

[60] C. Aliaga *et al.*, "Level Building Sidekick: An AI-assisted level editor package for Unity," in *Proc. AIIDE*, 2023. doi: 10.1609/aiide.v19i1.27535. — An open-source research level editor inside a game engine. **[MI]** The closest research-tool analogue to ours in packaging (engine plugin).

[61] A. M. Smith and M. Mateas, "Answer set programming for procedural content generation: A design space approach," *IEEE Trans. Comput. Intell. AI Games*, vol. 3, no. 3, 2011. doi: 10.1109/TCIAIG.2011.2158545.

[62] A. Khalifa *et al.*, "The procedural content generation benchmark: An open-source testbed for generative challenges in games," in *Proc. FDG*, 2025. doi: 10.1145/3723498.3723794. — Related to our batch experiments and metrics.

[63] G. Smith and J. Whitehead, "Analyzing the expressive range of a level generator," in *Proc. PCG Workshop*, 2010. doi: 10.1145/1814256.1814260. — The basis for evaluating our batch experiments.

[64] N. Shaker, J. Togelius, and M. J. Nelson, *Procedural Content Generation in Games*. Springer, 2016. doi: 10.1007/978-3-319-42716-4.

[65] C. Pitt, *Procedural Generation in Godot*. Apress, 2023. doi: 10.1007/978-1-4842-8795-8. — Practitioner book on procedural generation in Godot (same engine as ours).

---

### Part 2 — Tools

Last activity is the GitHub `pushed_at` date (checked 2026-10-22). Stars are approximate.

| Name | Type | Engine / platform | License | URL | Graph-based? | Key overlap with our tool |
|---|---|---|---|---|---|---|
| **Edgar-DotNet** (Nepožitek) | Library (graph→room layout) | .NET / C# | MIT | https://github.com/OndrejNepozitek/Edgar-DotNet (pushed 2026-07, ~361★) | Yes: level graph + room templates | Graph→rooms with doors, corridors, Ma-style configuration spaces. Has no raster passes (CA, WFC, decoration), agents or metrics |
| **Edgar for Unity** (free + Edgar Pro, commercial) | Engine plugin | Unity | MIT (free); Pro proprietary | https://github.com/OndrejNepozitek/Edgar-Unity (pushed 2026-08, ~912★) | Yes | Graph editor, room templates with doors, tilemap output. Closest commercial/OSS analogue to our graph→rooms→tilemap path |
| **Edgar.Godot** (RickyYCheng) | Godot addon (WIP) | Godot 4 (.NET / GDExtension) | MIT | https://github.com/RickyYCheng/Edgar.Godot (pushed 2026-06, ~23★) | Yes: `.edgar-graph` + visual graph editor | Same engine as ours. Room templates from scenes/Tiled, TileMapLayer renderer. Only a layout kernel, with no pipeline stack, CA or WFC |
| **Gaea** | Godot addon | Godot 4.4+ | MIT | https://github.com/gaea-godot/gaea (pushed 2026-10, ~1.7k★) | Node graph of *operations* (dataflow), not level topology | Godot tilemap PCG with node-based passes (noise, CA, scatter). Overlaps our raster/scatter passes but has no level/room graph |
| **godot-constraint-solving** | Godot addon (WFC / CSP) | Godot 4 | MIT | https://github.com/AlexeyBond/godot-constraint-solving (pushed 2025-05, ~465★) | No | WFC on Godot TileMaps. Comparable to our textural WFC overlay |
| Godot WFC ports (Godot-WFC-Csharp; Godot_Fast_WFC; infinite_worlds) | Godot addons | Godot | MIT | https://github.com/Mehdi-Saleh/Godot-WFC-Csharp ; https://github.com/AliasFactory/Godot_Fast_WFC ; https://github.com/Lommix/infinite_worlds | No | WFC tilemap generation in Godot. infinite_worlds does chunked/infinite WFC |
| **FloorArchitect** | Godot plugin | Godot | MIT | https://github.com/Drejzer/FloorArchitect (pushed 2023-12) | Implicit (room grid) | Isaac/Moonlighter-style floor layout of rooms |
| GDQuest Godot procedural generation demos | Demo collection | Godot 4 | ? (NOASSERTION) | https://github.com/gdquest-demos/godot-4-procedural-generation (pushed 2026-06, ~1.9k★) | No | Reference implementations of walkers, CA and BSP in Godot |
| Godot dungeon generators (ollelogdahl/DungeonGenerator; Godot-Gungeon-Generator) | Sample projects | Godot | Unlicense; GPL-3.0 | https://github.com/ollelogdahl/DungeonGenerator ; https://github.com/Lukas311202/Godot-Gungeon-Generator | Partly (Delaunay/MST) | Room scatter, room graph and corridor routing in Godot |
| **mxgmn/WaveFunctionCollapse** (Gumin) | Reference implementation | C# (CLI) | MIT (license file present; GitHub reports NOASSERTION) | https://github.com/mxgmn/WaveFunctionCollapse (pushed 2026-10, ~25k★) | No | The original WFC (overlapping and simple-tiled models) |
| **MarkovJunior** (Gumin) | Probabilistic rewrite language | C# | MIT | https://github.com/mxgmn/MarkovJunior (pushed 2026-03, ~8.4k★) | No (grid rewrite rules) | Sequenced rewrite passes plus constraint propagation, the closest analogue to our stacked raster passes. Includes dungeon and cave examples |
| **DeBroglie** (Boris the Brave) | WFC library | C# / .NET | MIT | https://github.com/BorisTheBrave/DeBroglie (pushed 2025-12, ~527★) | Supports graph topologies (?) | WFC with non-local constraints (path connectivity, counts), which suits overlays on routed layouts |
| **Tessera** (Boris the Brave) | Unity asset (WFC) | Unity | Proprietary (Pro includes source) | https://www.boristhebrave.com/docs/tessera/6/ | No | 3D tile WFC with big tiles and constraints. Paper [41] |
| **wfc_2019f** (Karth) | Research WFC implementation | Python | MIT | https://github.com/ikarth/wfc_2019f (pushed 2023-08) | No | Research reimplementation used in the Karth & Smith papers |
| **Sturgeon** (Cooper) | Research constraint-based generator | Python | MIT | https://github.com/crowdgames/sturgeon-pub (pushed 2026-09) | MKIV: yes (graph label rewrites) | Constraint-based tile and graph level generation. Papers [26],[27],[48] |
| **Ludoscope** / LudoscopeLite (Dormans; van Rozen) | Grammar-pipeline tool | Standalone (Ludoscope proprietary/internal); LudoscopeLite in Rascal | Ludoscope ?; LudoscopeLite BSD-3 | https://github.com/visknut/LudoscopeLite (pushed 2018-08); papers [21],[22] | Yes: graph *and* tilemap grammars | Pipeline of transformation modules over graphs and grids. The closest conceptual match to our modifier stack and raster passes |
| **Unexplored / Unexplored 2** (Ludomotion) | Commercial games (Ludoscope-based) | Unity (?) | Proprietary | https://gamedeveloper.com/design/unexplored-s-secret-cyclic-dungeon-generation- ; https://www.boristhebrave.com/2021/04/10/dungeon-generation-in-unexplored/ | Yes (cyclic graphs) | Cyclic graph → grid dungeon, the production example of graph→tilemap |
| **Dungeon Architect** (Code Respawn) | Commercial plugin | Unreal Engine, Unity | Proprietary (~$300/seat on Unity store) | https://assetstore-fallback.unity.com/packages/tools/utilities/dungeon-architect-53895 ; docs https://docs.dungeonarchitect.dev | Yes: Grid Flow / Snap Grid Flow graph editors, graph grammars | Flow graph → layout, snap modules (custom rooms with doors), theming/decoration. Strongest commercial analogue |
| **DunGen** (Aegon Games) | Commercial plugin | Unity | Proprietary | https://dungen-docs.aegongames.com/latest/ | Yes: Dungeon Flow graph (main path, branches) | Prefab rooms ("Tiles") with doorways, i.e. our custom rooms with doorways |
| **Unreal PCG Framework** (Epic) | Engine framework (node graphs) | Unreal Engine 5 | Proprietary (UE EULA) | https://dev.epicgames.com/documentation/en-us/unreal-engine/pcg-development-guides | Dataflow graph, not topology | Node-based scatter, filter and spawn pipeline. Overlaps our structure placement and weighted scattering |
| **PCGEx** (PCG Extended Toolkit) | UE plugin | Unreal Engine 5 | MIT | https://github.com/PCGEx/PCGExtendedToolkit (pushed 2026-10, ~706★) | Yes: spatial graph theory, clusters, pathfinding | Graph construction, pathfinding and edge refinement inside PCG, comparable to our graph modifiers and corridor routing |
| **Houdini / SideFX Labs WFC + PDG** | Commercial DCC + toolset | Houdini → Unreal/Unity | Proprietary (Labs tools free) | https://www.sidefx.com/tutorials/wfc-dungeon-generator/ | No (procedural networks) | Shows a WFC dungeon pipeline with a second WFC pass for decoration, close to our layered WFC overlay |
| **Tiled** | Map editor | Standalone (exports to engines) | GPL-2.0 (editor); libtiled BSD (?) | https://github.com/mapeditor/tiled (pushed 2026-10, ~13k★) | No | Hand-authored tile rooms. Edgar.Godot imports Tiled maps as room templates. Includes rule-based "automapping" |
| **rot.js** | Roguelike toolkit | JavaScript | BSD-3-Clause | https://github.com/ondras/rot.js (pushed 2024-11, ~2.7k★) | No | Map generators (Digger, Uniform, Rogue, Cellular) and pathfinding, the standard roguelike raster methods |
| **libtcod** | Roguelike toolkit | C/C++ (+ Python) | BSD-3-Clause | https://github.com/libtcod/libtcod (pushed 2026-10, ~1.2k★) | No | BSP dungeon splitting, pathfinding, field of view |
| **Brogue: CE** | Open-source roguelike | C | AGPL-3.0 | https://github.com/tmewett/BrogueCE (pushed 2026-10, ~1.5k★) | Implicit | Well-known room accretion, cave CA, loops, and "machines" (structure placement). Practitioner reference for our structure and decoration passes |
| **GraphDungeonGenerator** (Khalifa) | Research/demo | C# | MIT | https://github.com/amidos2006/GraphDungeonGenerator (pushed 2020-02) | Yes: Dormans mission graph + layout grammar | Zelda-like mission graph → grid layout |
| **vazgriz/DungeonGenerator** | Sample project | Unity | MIT | https://github.com/vazgriz/DungeonGenerator (pushed 2023-07, ~834★) | Yes (Delaunay + MST + A* hallways) | Room scatter, graph and A* corridor routing, our "organic vs orthogonal corridors" step in its simplest form |
| threejs-procedural-dungeon | Sample project | Three.js | MIT | https://github.com/majidmanzarpour/threejs-procedural-dungeon (pushed 2026-07) | Yes (Delaunay/MST) | Seeded room-graph dungeon |
| **Level Building Sidekick** (ISILab-Utalca) | Research editor | Unity | ? (NOASSERTION) | https://github.com/ISILab-Utalca/LevelBuildingSidekick (pushed 2026-09) | Partly | AI-assisted level editor inside an engine. Paper [60] |
| **PCG Benchmark** (Khalifa et al.) | Research benchmark | Python | ? (none listed) | https://github.com/amidos2006/pcg_benchmark (pushed 2026-10) | No | Batch evaluation of generators, comparable to our batch experiments and metrics. Paper [62] |
| **Townscaper** (Oskar Stålberg / Raw Fury) | Commercial game/toy | Unity (?) | Proprietary | https://store.steampowered.com/app/1291340/Townscaper/ (URL not fetched ?) | No (irregular-grid WFC) | Interactive incremental WFC on an irregular grid, a reference point for runtime partial regeneration |

#### Closest matches (summary)
1. **Edgar (DotNet/Unity) + Edgar.Godot**: graph→room-template layout with doors on tilemaps. It is the direct competitor for our graph→rooms step, but it has no multi-pass raster, CA, WFC overlay, agents, metrics or timeline.
2. **Dungeon Architect** (and DunGen): commercial flow-graph → rooms/snap modules with theming. It is closed-source and not a research environment.
3. **Ludoscope** (papers [21],[22]): transformation pipelines over graphs and tilemaps. It is the conceptual twin of our modifier stack, with lessons on maintainability.
4. **Ma et al. 2014 [1] / Nepožitek & Gemrot [2]**: the algorithmic basis of graph→layout.
5. **Eger 2026 [36] / Kim et al. 2019 [35] / CPPN2WFC [47]**: WFC guided by graph or global structure, matching our graph-guided textural WFC overlay.

---

## Theme C — Online/dynamic PCG, adaptive PCG, partial regeneration/repair, lock-and-key reachability, agent-based PCG and agent validators

Scope: related work for Procedural Graph Tools features (a) trigger-based runtime partial regeneration, (b) temporally-aware lock/key progression, (c) persistent headless validator, (d) walker agents that generate and test.

Method: about 45 queries across Semantic Scholar, arXiv and the web, plus citation chasing (the 95 papers citing Dormans & Bakkes 2011, and the Sturgeon/Cooper line). Every entry below was checked on Semantic Scholar (title, authors, year, venue, DOI) unless marked "?". "[Zotero]" means the item is already in your Zotero library.

---

### 1. Foundations: online, adaptive and experience-driven PCG

1. G. N. Yannakakis and J. Togelius, "Experience-driven procedural content generation," *IEEE Trans. Affective Computing*, vol. 2, no. 3, pp. 147–161, 2011. DOI: 10.1109/T-AFFC.2011.6
   — Sets out the EDPCG loop: player-experience model → content quality → representation → generator. Our tool adapts content to the player's *state* (position, inventory, trigger history), not to a model of the player's *affect*, so it fits the "online" axis without being experience-driven.

2. J. Togelius, G. N. Yannakakis, K. O. Stanley, and C. Browne, "Search-based procedural content generation: A taxonomy and survey," *IEEE Trans. Comput. Intell. AI Games*, vol. 3, no. 3, pp. 172–186, 2011. DOI: 10.1109/TCIAIG.2011.2148116
   — Defines the online/offline and generate-and-test distinctions. Our pipeline is online, and its generate-and-test step uses a simulation validator, so this taxonomy is the right one to position against.

3. R. Lopes and R. Bidarra, "Adaptivity challenges in games and simulations: A survey," *IEEE Trans. Comput. Intell. AI Games*, vol. 3, no. 2, pp. 85–99, 2011. DOI: 10.1109/TCIAIG.2011.2152841
   — Surveys adaptivity targets and calls for "online adjustments to game worlds." Our trigger-driven regeneration is one concrete way of making such an online adjustment to the world's topology.

4. R. Lopes, E. Eisemann, and R. Bidarra, "Authoring adaptive game world generation," *IEEE Trans. Games*, vol. 10, no. 1, pp. 42–55, 2018. DOI: 10.1109/TCIAIG.2017.2678759
   — Designers write adaptation rules that map player-skill profiles to content descriptions, and content is generated online by rule matching. It is close in spirit, since designers author when and what changes at runtime. However, it adapts to skill, not to progression state, and has no topology-preserving regeneration and no solvability validator.

5. J. Dormans and S. Bakkes, "Generating missions and spaces for adaptable play experiences," *IEEE Trans. Comput. Intell. AI Games*, vol. 3, no. 3, pp. 216–228, 2011. DOI: 10.1109/TCIAIG.2011.2149523
   — Uses graph-grammar mission/space generation, including lock-and-key, as a basis for player-adaptive levels. **Closest conceptual ancestor of (a)+(b)**: it rewrites graphs to adapt play. It does not regenerate a live level in place around the player, and it has no persistent validator.

6. N. Shaker, G. N. Yannakakis, and J. Togelius, "Towards automatic personalized content generation for platform games," in *Proc. AIIDE*, 2010. DOI: 10.1609/aiide.v6i1.12399
   — Adapts level parameters to a learned player-experience model. The adaptation happens between levels, whereas ours happens inside a level.

7. E. J. Hastings, R. K. Guha, and K. O. Stanley, "Automatic content generation in the Galactic Arms Race video game," *IEEE Trans. Comput. Intell. AI Games*, vol. 1, no. 4, pp. 245–263, 2009. DOI: 10.1109/TCIAIG.2009.2038365
   — The canonical example of content (weapons) generated continuously *while the game is played*. It shows online PCG works, but it covers items, not level topology.

8. G. Smith, E. Gan, A. Othenin-Girard, and J. Whitehead, "PCG-based game design: Enabling new play experiences through procedural content generation," in *Proc. PCGames Workshop (FDG)*, 2011. DOI: 10.1145/2000919.2000926
   — Endless Web treats runtime PCG as a core mechanic that the player steers. This is the design precedent for players causing regeneration, as our world triggers do.

9. S. Bakkes, S. Whiteson, G. Li, G. V. Vișniuc, E. Charitos, N. Heijne, and A. Swellengrebel, "Challenge balancing for personalised game spaces," in *Proc. IEEE Games Media Entertainment (GEM)*, 2014. DOI: 10.1109/GEM.2014.7047971
   — Uses offline exploration and then online gradient-based selection of the next level-design parameters during play (Infinite Mario). It adapts the upcoming space, never regenerates what already exists, and has no lock state.

10. N. N. Blackburn, M. Gardone, and D. S. Brown, "Player-centric procedural content generation: Enhancing runtime customization by integrating real-time player feedback," in *Companion Proc. CHI PLAY*, 2023. DOI: 10.1145/3573382.3616069
    — A recent framing of runtime adaptive PCG (Pac-Man), driven by explicit player feedback. Useful as recent CHI PLAY evidence of interest in runtime PCG. It does not deal with structural consistency or solvability.

### 2. Dynamic difficulty adjustment through level (re)generation

11. M. Jennings-Teats, G. Smith, and N. Wardrip-Fruin, "Polymorph: Dynamic difficulty adjustment through level generation," in *Proc. PCGames Workshop (FDG)*, 2010, Art. 11. DOI: 10.1145/1814256.1814267
    — Generates platformer segments just ahead of the player, matched to estimated skill. It appends content online rather than rewriting a region around the player, and its progression is linear, with no keys.

12. D. Wheat, M. Masek, C. P. Lam, and P. Hingston, "Dynamic difficulty adjustment in 2D platformers through agent-based procedural level generation," in *Proc. IEEE SMC*, 2015, pp. 2778–2785. DOI: 10.1109/SMC.2015.485
    — Agents build platformer levels whose difficulty is tuned to the player. This is the closest precedent that combines agent-based generation (d) with adaptivity. Its agents are generators only, not persistent validators.

13. P. Shi and K. Chen, "Online level generation in Super Mario Bros via learning constructive primitives," in *Proc. IEEE CIG*, 2016. DOI: 10.1109/CIG.2016.7860397
    — Builds levels online from learned, quality-assured segments and supports real-time DDA. It is segment-append, not topology-preserving regeneration.

14. T. Huber, S. Mertes, S. Rangelova, S. Flutura, and E. André, "Dynamic difficulty adjustment in virtual reality exergames through experience-driven procedural content generation," in *Proc. IEEE SSCI*, 2021. DOI: 10.1109/SSCI50451.2021.9660086
    — Uses deep RL to restructure a maze of exercise rooms to match the player's capability. The maze is regenerated per level, not partially during play.

### 3. Endless, streaming and runtime-changing spaces

15. L. Johnson, G. N. Yannakakis, and J. Togelius, "Cellular automata for real-time generation of infinite cave levels," in *Proc. PCGames Workshop (FDG)*, 2010, Art. 10. DOI: 10.1145/1814256.1814266
    — Generates cave chunks in real time as the player moves, with connectivity ensured between chunks. This is the classic streaming-generation reference. Chunks are fixed once generated, whereas we regenerate existing nodes.

16. T. Shu, J. Liu, and G. N. Yannakakis, "Experience-driven PCG via reinforcement learning: A Super Mario Bros study," in *Proc. IEEE CoG*, 2021. DOI: 10.1109/CoG52621.2021.9619124
    — EDRL generates endless levels online, with a learned repairer and AI-based playability testing per segment. **It is close to (c)** because it validates online. However, validation is per-segment and stateless, with no inventory or exploration memory.

17. Z. Wang, T. Shu, and J. Liu, "State-space closure: Revisiting endless online level generation via reinforcement learning," *IEEE Trans. Games*, vol. 16, no. 2, pp. 489–492, 2024. DOI: 10.1109/TG.2023.3262297
    — Analyses the properties of infinite-horizon online generation. Only background for the online-generation framing.

18. Y. Nie, S. Zheng, Z. Zhuang, and J. Togelius, "Nested wave function collapse enables large-scale content generation," *IEEE Trans. Games*, vol. 16, no. 4, pp. 892–902, 2024. DOI: 10.1109/TG.2024.3377637
    — Generates infinite, deterministic WFC content in nested sub-grids. Shows that localized sub-region generation can stay consistent with its neighbours. It works on tiles only and has no gameplay-state constraints.

19. R. Kar, "Runtime evaluation of procedural content generation in an endless runner game using autonomous agents," arXiv:2605.01783, 2026. DOI: 10.48550/arXiv.2605.01783 (preprint)
    — Puts runtime terrain generation and two autonomous evaluation agents (a scanner and a ground-traversal agent) inside the gameplay loop, checking content ahead of the player. **Closest prior art for (c)**, and the only work found that unifies runtime generation with runtime agent validation. Its differences from our tool: it uses an append-only stream, has no locks/keys or inventory, the agents keep no state across regenerations, and it does not rewrite existing topology.

20. K. Vasylevska, H. Kaufmann, M. Bolas, and E. A. Suma, "Flexible spaces: Dynamic layout generation for infinite walking in virtual environments," in *Proc. IEEE 3DUI*, 2013, pp. 39–42. DOI: 10.1109/3DUI.2013.6550194
    — Regenerates corridors and room layout out of the user's view while they walk, preserving the illusion of a consistent space. **It is a runtime "change the world behind the player" analogue to (a)**, built for VR locomotion. It has no progression and no solvability checking.

21. E. A. Suma, Z. Lipps, S. L. Finkelstein, D. M. Krum, and M. Bolas, "Impossible spaces: Maximizing natural walking in virtual environments with self-overlapping architecture," *IEEE Trans. Vis. Comput. Graph.*, vol. 18, no. 4, pp. 555–564, 2012. DOI: 10.1109/TVCG.2012.47
    — Dynamically swaps self-overlapping rooms at runtime. It is a perceptual and architectural precedent for in-play structural change, not PCG.

### 4. Local / partial regeneration, repair, inpainting, and pinned-region regeneration

22. G. Smith, J. Whitehead, and M. Mateas, "Tanagra: Reactive planning and constraint solving for mixed-initiative level design," *IEEE Trans. Comput. Intell. AI Games*, vol. 3, no. 3, pp. 201–215, 2011. DOI: 10.1109/TCIAIG.2011.2159716
    — The designer pins geometry and the system regenerates the rest while keeping it playable. **It is the authoring-time version of "regenerate selected parts, preserve the surroundings."** Ours does the same at runtime, triggered from inside the world.

23. I. Karth and A. M. Smith, "WaveFunctionCollapse is constraint solving in the wild," in *Proc. FDG*, 2017. DOI: 10.1145/3102071.3110566
    — Frames WFC as constraint solving, which makes partial re-solving with fixed cells natural. This is a technical basis for local regeneration on grids. Ours operates on a graph and then rasterizes.

24. A. Alvarez, S. Dahlskog, J. Font, and J. Togelius, "Empowering quality diversity in dungeon design with interactive constrained MAP-Elites," in *Proc. IEEE CoG*, 2019. DOI: 10.1109/CIG.2019.8848022
    — Evolutionary Dungeon Designer: designer edits feed back into the generator's suggestions. It is a design-time loop, with no runtime triggers.

25. H. Zhang, M. C. Fontaine, A. K. Hoover, J. Togelius, B. Dilkina, and S. Nikolaidis, "Video game level repair via mixed integer linear programming," in *Proc. AIIDE*, 2020, pp. 151–158. DOI: 10.1609/aiide.v16i1.7424
    — Generate-then-repair with minimum-cost edits that restore playability. "Minimal edits that keep the rest intact" is analogous to our topology preservation. It runs offline and on whole levels.

26. S. Cooper and A. Sarkar, "Pathfinding agents for platformer level repair," in *Proc. AIIDE Workshops (EXAG)*, 2020. URL: https://dblp.org/rec/conf/aiide/CooperS20 (DOI: ?)
    — Uses pathfinding agents to find and fix unplayable spots. Agents serve as repair oracles, which is related to our validator, but the work is offline.

27. S. Cooper, "Sturgeon: Tile-based procedural level generation via learned and designed constraints," in *Proc. AIIDE*, 2022, pp. 26–36. DOI: 10.1609/aiide.v18i1.21944
    — Constraint-based generation with reachability constraints. It explicitly supports **infilling and repair** of level regions, which makes it the strongest offline precedent for constrained local regeneration.

28. M. Bazzaz and S. Cooper, "Guided game level repair via explainable AI," in *Proc. AIIDE*, 2024. DOI: 10.1609/aiide.v20i1.31874
    — Uses explainability to localize the regions responsible for unsolvability, then focuses the solver there. It is related to deciding which nodes or edges to regenerate. It runs offline.

29. D. Bhaumik, J. Togelius, G. N. Yannakakis, and A. Khalifa, "Evolutionary level repair," in *Proc. GECCO Companion*, 2025. DOI: 10.1145/3712255.3726692
    — Search-based repair under a budget of few changes, ensuring reachability. It shares our goal of small edits that keep the level functional, but works offline.

30. J. Jara Gonzalez and M. Guzdial, "Reconstructing existing levels through level inpainting," arXiv:2309.09472, 2023 (S2 lists AIIDE 2023 as venue — ?). DOI: 10.48550/arXiv.2309.09472
    — Uses ML inpainting to reconstruct or extend masked level regions. It is the ML analogue of partial regeneration, with no gameplay-state constraints.

### 5. Lock-and-key progression, reachability over state, and simultaneous level+playthrough generation

31. J. Dormans, "Adventures in level design: Generating missions and spaces for action adventure games," in *Proc. PCGames Workshop (FDG)*, 2010, Art. 1. DOI: 10.1145/1814256.1814257
    — Mission graphs with lock/key dependencies are transformed into space. It is the base representation our graph pipeline extends. It is static: generated once, before play.

32. A. M. Smith and M. Mateas, "Answer set programming for procedural content generation: A design space approach," *IEEE Trans. Comput. Intell. AI Games*, vol. 3, no. 3, pp. 187–200, 2011. DOI: 10.1109/TCIAIG.2011.2158545
    — Declarative generation in which reachability and solvability are hard constraints. It guarantees solvability at generation time, whereas we check it by simulation after each regeneration.

33. A. Summerville and M. Mateas, "Sampling Hyrule: Multi-technique probabilistic level generation for action role playing games," in *Proc. AIIDE*, 2015. URL: https://ojs.aaai.org/index.php/AIIDE/article/view/12817 (DOI: ?)
    — Learns Zelda dungeon topologies, including key/lock structure, and samples playable graphs. It is graph-level and offline.

34. L. T. Pereira, P. V. de Souza Prado, R. M. Lopes, and C. F. M. Toledo, "Procedural generation of dungeons' maps and locked-door missions through an evolutionary algorithm validated with players," *Expert Syst. Appl.*, vol. 180, Art. 115009, 2021. DOI: 10.1016/j.eswa.2021.115009
    — Evolves dungeon trees with feasible key/lock placement, guaranteed by the encoding. Feasibility holds for the start state only. Our tool re-establishes feasibility from the *current* player state after each regeneration.

35. F. Venco and P. L. Lanzi, "An agent-based approach for procedural puzzle generation in graph-based maps," in *Proc. IEEE CoG*, 2021. DOI: 10.1109/CoG52621.2021.9619005
    — Specialized agents add locks, keys and switches to a graph map so that **no action sequence leads to a dead end**. **It is the closest prior art for (b) and (d) together**: agents on graphs, plus lock/key reasoning over action sequences. It works offline only, with no runtime regeneration and no player-state-relative re-placement.

36. M. Weeks and J. Davis, "Procedural dungeon generation for a 2D top-down game," in *Proc. ACM Southeast Conf. (ACMSE)*, 2022. DOI: 10.1145/3476883.3520214
    — Iterative A* that collects keys to decide solvability, stopping when an iteration makes no progress. This is algorithmically the same idea as our flood-fill plus lock simulation, but run once and offline.

37. C. Johnson, J. L. Trahan, T. Lu, and L. Peng, "Evaluation of algorithms for randomizing key item locations in game worlds," *IEEE Access*, vol. 9, pp. 48286–48302, 2021. DOI: 10.1109/ACCESS.2021.3069114
    — Formalizes item randomizers (Zelda/Metroid) as reachability on graphs with item-gated edges (random/forward/assumed fill). **It is a strong precedent for (b)**: key placement driven by an inventory-state reachability analysis. The analysis is done once, from the game start.

38. S. Cooper, "Sturgeon-MKIII: Simultaneous level and example playthrough generation via constraint satisfaction with tile rewrite rules," in *Proc. FDG*, 2023. DOI: 10.1145/3582437.3587205
    — Generates a level *together with* a playthrough, including lock-and-key dungeons. The playthrough is a state sequence, which corresponds to our validator's trace. Both are produced offline in a single solve.

39. S. Cooper and M. Bazzaz, "Sturgeon-MKIV: Constraint-based level and playthrough generation with graph label rewrite rules," in *Proc. AIIDE*, 2024, pp. 13–24. DOI: 10.1609/aiide.v20i1.31862
    — Extends MKIII to **graph** levels with mechanics as label rewrites. **It is the closest formal counterpart to our graph+progression model.** It has no runtime partial regeneration and no persistence across changes. A follow-up exists: Cooper and Bazzaz, "A constraint-based graph grammar approach unifying level and playthrough generation," EXAG@AIIDE 2025 (DOI: ?).

40. B. M. F. Viana and S. R. dos Santos, "Procedural dungeon generation: A survey," *J. Interactive Systems*, vol. 12, no. 1, pp. 83–101, 2021. DOI: 10.5753/jis.2021.999 [Zotero]
    — Finds that few dungeon generators support barriers (locks), and notes the advantages of online generation. It supports a motivation claim: dynamic barriers are under-explored.

### 6. Agent-based PCG (generators as agents)

41. J. Doran and I. Parberry, "Controlled procedural terrain generation using software agents," *IEEE Trans. Comput. Intell. AI Games*, vol. 2, no. 2, pp. 111–119, 2010. DOI: 10.1109/TCIAIG.2010.2049020
    — Terrain is produced by specialized agents (coastline, smoothing, beach, mountain, river) with designer-controlled parameters. It is the classic agent-based PCG reference that our walker capabilities (motor, painter, builder) generalize.

42. M. Kerssemakers, J. Tuxen, J. Togelius, and G. N. Yannakakis, "A procedural procedural level generator generator," in *Proc. IEEE CIG*, 2012, pp. 335–341. DOI: 10.1109/CIG.2012.6374174
    — Evolves agent-based level generators (digger agents with spawn and behaviour rules) for Super Mario. It is the precedent for treating agent behaviours as composable generator primitives, as in our wander/grow/seek/maze behaviours.

43. N. Shaker, J. Togelius, and M. J. Nelson, *Procedural Content Generation in Games*. Cham, Switzerland: Springer, 2016. DOI: 10.1007/978-3-319-42716-4 [Zotero]
    — Chapter 3 ("Constructive generation methods for dungeons and levels") covers agent-based digging (blind and look-ahead diggers) and cellular automata. It is the textbook source for drunkard-walk-style agents.

44. T. Short and T. Adams, Eds., *Procedural Generation in Game Design*. Boca Raton, FL, USA: CRC Press/A K Peters, 2017. ISBN 9781498799195 (DOI: ?) [Zotero has a related web item]
    — Includes J. Dormans's "Cyclic Generation" chapter (the Unexplored lock-and-key cycles). It is the industry reference for cyclic graph dungeons with locks and keys.

45. A. Khalifa, P. Bontrager, S. Earle, and J. Togelius, "PCGRL: Procedural content generation via reinforcement learning," in *Proc. AIIDE*, 2020. DOI: 10.1609/aiide.v16i1.7416
    — Treats level design as an agent acting on the map (narrow/turtle/wide representations). The "turtle" agent is the RL relative of our walker. Playability is computed as a reward, not by a persistent player simulation.

46. S. Earle, Z. Jiang, E. Vinitsky, and J. Togelius, "Video game level design as a multi-agent reinforcement learning problem," in *Proc. AIIDE*, 2025, pp. 32–42. DOI: 10.1609/aiide.v21i1.36807
    — Uses multiple generator agents acting locally, which generalize better to unseen map shapes. It supports our multi-walker design, and its local, modular policies relate to local regeneration.

### 7. Agents as playtesters/validators, and co-generation of content and solver

47. C. Holmgård, M. C. Green, A. Liapis, and J. Togelius, "Automated playtesting with procedural personas through MCTS with evolved heuristics," *IEEE Trans. Games*, vol. 11, no. 4, pp. 352–362, 2019. DOI: 10.1109/TG.2018.2808198 [Zotero]
    — Uses MCTS personas as synthetic playtesters for generated dungeons. These are richer behavioural agents than our validator, but they run per level and offline, with no state carried across content changes.

48. M. Beukman, S. James, and C. Cleghorn, "Towards objective metrics for procedurally generated video game levels," arXiv:2201.10334, 2022. URL: https://arxiv.org/abs/2201.10334
    — Uses A*-agent traces to measure diversity and difficulty. Simulation-based evaluation of PCG output, comparable to how our validator could report metrics.

49. L. Gisslén, A. Eakins, C. Gordillo, J. Bergdahl, and K. Tollmar, "Adversarial reinforcement learning for procedural content generation," in *Proc. IEEE CoG*, 2021. DOI: 10.1109/CoG52621.2021.9619053
    — Trains a Generator agent and a Solver agent adversarially, so that the Solver certifies solvability. It is the closest learned analogue of "agents both generate and test" (d). Training is offline, with no runtime regeneration.

50. P. Bontrager and J. Togelius, "Learning to generate levels from nothing," in *Proc. IEEE CoG*, 2021. DOI: 10.1109/CoG52621.2021.9619131
    — Generative Playing Networks co-train a playing agent and a generator for a 2D dungeon crawler. The agent defines playability, as in (d).

### 8. Commercial / industry precedents (ludography; cite as games, not papers)

- *Unexplored* (Ludomotion, 2017): cyclic lock-and-key dungeon generation (J. Dormans). Technical write-ups: https://www.gamedeveloper.com/design/unexplored-s-secret-cyclic-dungeon-generation- and https://www.boristhebrave.com/2021/04/10/dungeon-generation-in-unexplored/ . Locks and keys are consistent by construction; generation happens before play. Its successor generator, Ludoscope, is discussed in D. Protsenko, J. Dormans, and R. van Rozen, "Maintenance in procedural level design: Lessons from Ludoscope," *Proc. FDG*, 2025, DOI: 10.1145/3723498.3723784.
- *Layers of Fear* (Bloober Team, 2016) and *P.T.* (Kojima Productions, 2014): rooms and doors change while the player looks away. These are hand-scripted runtime topology changes, i.e. the experiential effect of (a) without generation or validation. Review evidence: https://www.thesixthaxis.com/2016/02/16/layers-of-fear-review/
- *Returnal* (Housemarque, 2021): hand-made rooms are reassembled into a new biome layout on every cycle (death). The change happens between runs, not in place during a run. Developer interview: https://www.pushsquare.com/news/2021/02/interview_returnal_ps5_developer_housemarque_talks_story_replayability_and_value
- Not found: published technical sources showing that *Hades*, *Dead Cells*, *Spelunky* or *Moonlighter* regenerate a level *in place during a run*. As far as public sources show, all of them generate per run or per floor visit. Do not claim otherwise without a source.

---

### Novelty assessment

**(a) Runtime, trigger-based partial regeneration that preserves the surrounding topology.**
- No academic system was found that regenerates *selected nodes/edges of a live graph level during play*, triggered by in-world triggers, while preserving the rest.
- Closest work in four groups:
  - **Online and endless generation** (Polymorph [11], Johnson CA [15], EDRL [16], Bakkes [9], Momentum [19]) only appends or adapts content *ahead* of the player. It never rewrites space that already exists.
  - **Pinned-region regeneration and repair/inpainting** (Tanagra [22], Sturgeon infill/repair [27], MIP repair [25], XAI-guided repair [28], evolutionary repair [29], inpainting [30]) does preserve-the-rest local regeneration, but only offline or at design time.
  - **Adaptive graph-grammar and world generation** (Dormans & Bakkes [5], Lopes et al. [4]) is the closest conceptually. It adapts content to the player but does not regenerate in place.
  - **VR Flexible/Impossible Spaces** [20], [21] and *Layers of Fear*/*P.T.* change topology at runtime, but they are hand-built or perceptual. They have no PCG pipeline and no progression logic.
- Assessment: **novel as a combination.** The individual ideas (local regeneration, online generation) are well established. Present (a) as "taking constrained local regeneration from design time into play."

**(b) Temporally-aware lock/key progression across regenerations, including trigger-gated key placement.**
- Lock/key feasibility is well studied, but always **from the start state, once**: Dormans [31], ASP [32], Pereira [34], Venco & Lanzi [35], Weeks & Davis [36], Sturgeon-MKIII/IV [38], [39], and randomizer fill algorithms [37], which are the most formal inventory-gated reachability on graphs.
- No work was found that re-places locks and keys relative to the player's *current* position and inventory after a mid-play change, or that makes a key's placement conditional on a trigger having fired.
- Closest: Johnson et al. [37] (assumed/forward fill over inventory state); Sturgeon-MKIV [39] (graph levels with playthrough state); Venco & Lanzi [35] (no dead ends under any action sequence).
- Assessment: **novel in the "re-planned from the current state" aspect.** Cite [37] and [39] as the formal backbone and state the difference explicitly.

**(c) Persistent headless validator that survives regenerations and re-explores from the trigger location, keeping inventory and explored state.**
- Simulation-based validation is standard (PCGRL rewards [45], A* metrics [48], MCTS personas [47], ARLPCG solver [49], EDRL AI testing [16], repair agents [26]).
- Only one work validates *at runtime inside the gameplay loop*: Kar, Momentum [19] (2026 arXiv preprint). Its agents scan streamed segments ahead of the player but keep no inventory or explored-set across changes, and its game has no locks.
- No validator was found that is incremental and stateful across content mutations.
- Assessment: **novel. Momentum [19] must be cited as the nearest prior art** (runtime generation plus runtime agent validation).

**(a)+(b)+(c) together:** **No prior work found that combines all three.**
- The nearest *pairs* are:
  - Momentum [19]: runtime generation plus runtime agent validation, but no locks and append-only.
  - Dormans & Bakkes [5] / Lopes et al. [4]: adaptive graph/world generation, but no in-place regeneration or persistent validator.
  - Sturgeon-MKIV [39] / Venco & Lanzi [35]: graph lock/key plus playthrough or agent guarantees, but offline.
- Caveats on honesty:
  - The search covered Semantic Scholar, arXiv and the web. Indie/commercial games and GDC talks may contain undocumented in-run shifting-dungeon systems.
  - *Layers of Fear*/*P.T.* show the *experience* is not new; the novelty claim should rest on the generative, validated, state-aware *mechanism*.

**(d) Agent simulation for both generation and testing.** Agent-based generation is old: Doran & Parberry [41], Kerssemakers [42], the PCG book [43], PCGRL [45], multi-agent PCGRL [46], Wheat [12], Venco & Lanzi [35]. Co-generation of generator and solver also exists (ARLPCG [49], GPN [50]). Our contribution is a **unified capability model** (motor/painter/builder/inventory) on graphs, in which the same agent framework generates content and validates it, with no learning required. Frame it as an engineering and tooling contribution, not as a new idea.

---

## Theme D — Mixed-initiative tools, PCG frameworks/pipelines, level analysis & evaluation, surveys, LLM/ML generation

Related-work search for "Procedural Graph Tools" (Godot editor + research workbench: undoable graph authoring, zones/prefabs, seeded stack of modular modifiers saved as JSON recipes, agent simulation, rasterization to tilemaps, graph-analysis dashboard, batch experiment runner, JSON/GraphML/GEXF/CSV export).

Verification: every entry was found in Semantic Scholar (metadata and DOI from the S2 API), arXiv, or the official web page. DOIs come from S2 `externalIds`. When a work has no DOI, the Semantic Scholar URL is given instead. Uncertain fields are marked "?". Entries marked [Zotero] are already in the user's library.

Abbreviations: PCG = procedural content generation; MI = mixed-initiative; ERA = expressive range analysis; PGT = Procedural Graph Tools (our tool).

---

### 1. Mixed-initiative / co-creative level and dungeon design tools

1. G. Smith, J. Whitehead, and M. Mateas, "Tanagra: A mixed-initiative level design tool," in *Proc. 5th Int. Conf. Foundations of Digital Games (FDG)*, 2010, pp. 209–216. DOI: 10.1145/1822348.1822376
   — Pairs a designer with a reactive-planning and constraint-solving generator for 2D platformer levels. Like PGT it combines manual editing with generation. Tanagra is tied to one genre and a beat-based geometry model, and it offers no graph topology, recipes, or batch analysis.

2. G. Smith, J. Whitehead, and M. Mateas, "Tanagra: Reactive planning and constraint solving for mixed-initiative level design," *IEEE Trans. Comput. Intell. AI Games*, vol. 3, no. 3, pp. 201–215, 2011. DOI: 10.1109/TCIAIG.2011.2159716
   — Journal version with the full ABL and constraint architecture. It is a reference point for designer-in-the-loop generation. PGT puts the designer in the loop through undoable commands and composable modifiers rather than one solver.

3. A. Liapis, G. N. Yannakakis, and J. Togelius, "Sentient Sketchbook: Computer-aided game level authoring," in *Proc. FDG*, 2013, pp. 213–220. URL: https://www.semanticscholar.org/paper/dd4c759cb5e537761af5768750ddb2bb3a913884
   — Designers sketch low-resolution strategy and dungeon maps. The tool shows playability metrics live (e.g., resource safety, exploration) and offers evolved alternatives. This is the closest early precedent for PGT's "author + live metrics" loop. Its metrics are tile- and gameplay-based, while PGT computes graph-theoretic metrics.

4. A. Liapis, G. N. Yannakakis, and J. Togelius, "Designer modeling for Sentient Sketchbook," in *Proc. IEEE Conf. Comput. Intell. Games (CIG)*, 2014, pp. 1–8. DOI: 10.1109/CIG.2014.6932873
   — Learns designer preferences from their choices among suggestions. PGT does not model designers. Its contribution is reproducible, recipe-based generation and analysis.

5. G. N. Yannakakis, A. Liapis, and C. Alexopoulos, "Mixed-initiative co-creativity," in *Proc. FDG*, 2014. URL: https://www.semanticscholar.org/paper/0a410eecf3b23042f95ebfbe0ffdc08ea697c9d9
   — Position paper that defines MI co-creativity, in which human and computer both take creative initiative. It gives the framing for describing where initiative lives in PGT (designer edits vs. modifier stack).

6. N. Shaker, M. Shaker, and J. Togelius, "Ropossum: An authoring tool for designing, optimizing and solving Cut the Rope levels," in *Proc. AAAI Conf. Artif. Intell. Interact. Digit. Entertain. (AIIDE)*, 2013. DOI: 10.1609/aiide.v9i1.12611
   — Authoring tool that combines evolutionary generation, a physics simulation, and an AI playability checker. Its agent-based validation is analogous to PGT's agent simulation, but it is game-specific and does not use graphs.

7. E. Butler, A. M. Smith, Y.-E. Liu, and Z. Popović, "A mixed-initiative tool for designing level progressions in games," in *Proc. ACM UIST*, 2013. DOI: 10.1145/2501988.2502011
   — MI tool for designing level *progressions* (sequences) with ASP-backed constraints. It is relevant to PGT's longest-path and progression analyses of graph structure.

8. A. Baldwin, S. Dahlskog, J. M. Font, and J. Holmberg, "Mixed-initiative procedural generation of dungeons using game design patterns," in *Proc. IEEE CIG*, 2017, pp. 25–32. DOI: 10.1109/CIG.2017.8080411
   — Original Evolutionary Dungeon Designer (EDD): a GA evolves grid dungeon rooms toward micro- and meso-level design patterns, with designer editing. This is the main dungeon-focused MI tool to compare against. EDD is grid-centric and evolutionary. PGT is graph-centric, modular, and deterministic.

9. A. Baldwin, S. Dahlskog, J. M. Font, and J. Holmberg, "Towards pattern-based mixed-initiative dungeon generation," in *Proc. FDG*, 2017. URL: https://www.semanticscholar.org/paper/ab8837384a80a9aed2374b9b18b04ec8d3c30440
   — Companion EDD paper with lab experiments and a user study with professional developers.

10. A. Alvarez, S. Dahlskog, J. Font, J. Holmberg, C. Nolasco, and A. Österman, "Fostering creativity in the mixed-initiative evolutionary dungeon designer," in *Proc. FDG*, 2018. DOI: 10.1145/3235765.3235815
    — Redesign of EDD. It adds a world-level room graph (multi-room dungeons) and a user study. The room-connection view is the nearest EDD feature to PGT's graph authoring.

11. A. Alvarez, S. Dahlskog, J. Font, J. Holmberg, and S. Johansson, "Assessing aesthetic criteria in the evolutionary dungeon designer," in *Proc. FDG*, 2018. DOI: 10.1145/3235765.3235810
    — Adds locking of regions plus symmetry and similarity fitness to EDD. Comparable to PGT's zones and prefab locking, which protect designer-authored structure from generators.

12. A. Alvarez, S. Dahlskog, J. Font, and J. Togelius, "Empowering quality diversity in dungeon design with interactive constrained MAP-Elites," in *Proc. IEEE Conf. Games (CoG)*, 2019, pp. 1–8. DOI: 10.1109/CIG.2019.8848022
    — Interactive MAP-Elites in EDD. Designers choose behavioral dimensions, and the archive feeds suggestions. PGT's parameter sweeps plus metrics could produce similar feature maps offline, but PGT has no built-in QD search.

13. A. Alvarez, J. Font, and J. Togelius, "Toward designer modeling through design style clustering," *IEEE Trans. Games*, vol. 14, no. 4, pp. 676–686, 2022. DOI: 10.1109/TG.2022.3143800
    — Clusters intermediate designs logged in EDD into design styles and personas. Relevant to PGT's undo/command log, which could support similar design-trace analysis.

14. A. Alvarez, J. Font, and J. Togelius, "Story Designer: Towards a mixed-initiative tool to create narrative structures," in *Proc. FDG*, 2022. DOI: 10.1145/3555858.3555929
    — MI tool that composes trope *graphs* (narrative graphs), uses MAP-Elites, and is constrained by EDD levels. A graph-authoring MI tool in which narrative and level are coupled.

15. D. Karavolos, A. Bouwer, and R. Bidarra, "Mixed-initiative design of game levels: Integrating mission and space into level generation," in *Proc. FDG*, 2015. URL: https://www.semanticscholar.org/paper/8953b1aa9b6a1708fe54038e18ab0cf1391ddc33
    — MI tool in which designers author mission graphs and the system maps them to spatial layouts. This closely mirrors PGT's graph-then-rasterize pipeline. PGT generalizes it into a modifier stack with analytics and batch runs.

16. M. Guzdial, N. Liao, and M. Riedl, "Co-creative level design via machine learning," in *Proc. AIIDE Workshops (EXAG)*, 2018. arXiv: 1809.09420
    — Framework and study for co-creative level design with PCGML agents (Morai Maker).

17. M. Guzdial, N. Liao, J. Chen, S.-Y. Chen, S. Shah, V. Shah, J. Reno, G. Smith, and M. O. Riedl, "Friend, collaborator, student, manager: How design of an AI-driven game level editor affects creators," in *Proc. CHI*, 2019. DOI: 10.1145/3290605.3300854
    — Two mixed-methods studies with Morai Maker show that designers want different AI roles. A useful framing for PGT's deliberately "tool-like" (non-agentive) generation.

18. T. Machado, A. Nealen, and J. Togelius, "Computationally intelligent collaborative environment for game and level design (Cicero)," 2017, venue: ? URL: https://www.semanticscholar.org/paper/2805c99d00b808d2b00b101309279e05d188eece
    — GVGAI-based MI game design assistant with AI playtesting. Its integrated agent simulation parallels PGT's.

19. T. Machado, D. Gopstein, A. Nealen, and J. Togelius, "Pitako — Recommending game design elements in Cicero," in *Proc. IEEE CoG*, 2019, pp. 1–8. DOI: 10.1109/CIG.2019.8848081
    — Recommender-system extension of Cicero that suggests mechanics.

20. M. Charity, A. Khalifa, and J. Togelius, "Baba is Y'all: Collaborative mixed-initiative level design," in *Proc. IEEE CoG*, 2020, pp. 542–549. DOI: 10.1109/CoG47356.2020.9231807
    — Asynchronous, multi-user MI level design with an evolver, an automated player, and a mechanics archive. Shows community and archival aspects that PGT does not target.

21. M. Charity, I. Dave, A. Khalifa, and J. Togelius, "Baba is Y'all 2.0: Design and investigation of a collaborative mixed-initiative system," *IEEE Trans. Games*, vol. 16, no. 1, pp. 75–89, 2024. DOI: 10.1109/TG.2022.3223527
    — Updated system with a user study.

22. S. Margarido, P. Machado, L. Roque, and P. Martins, "Boosting mixed-initiative co-creativity in game design: A tutorial," *ACM Comput. Surv.*, vol. 58, no. 1, 2025. DOI: 10.1145/3759914 (arXiv: 2401.05999)
    — Reviews MI co-creative game tools and proposes the "MI-CCy Quantifier" to assess them. Could be used to position PGT along initiative and control axes.

23. M. Kreminski, I. Karth, M. Mateas, and N. Wardrip-Fruin, "Evaluating mixed-initiative creative interfaces via expressive range coverage analysis," in *Proc. IUI Workshops*, 2022, pp. 34–45. URL: https://www.semanticscholar.org/paper/1ca50c9de4116ea082953bc5187232eb75e3da8e
    — Evaluates MI tools by how much of the generator's expressive range users reach. This is a candidate evaluation method for PGT's interactive vs. batch modes.

### 2. PCG frameworks, composable pipelines, grammar/constraint-based generators

24. J. Dormans, "Adventures in level design: Generating missions and spaces for action adventure games," in *Proc. PCG Workshop @ FDG*, 2010, pp. 1:1–1:8. DOI: 10.1145/1814256.1814257
    — Introduces mission graphs and space graphs generated by graph and shape grammars in successive transformation steps. Conceptual ancestor of PGT's staged topology, then geometry, then semantic modifiers.

25. J. Dormans and S. Bakkes, "Generating missions and spaces for adaptable play experiences," *IEEE Trans. Comput. Intell. AI Games*, vol. 3, no. 3, pp. 216–228, 2011. DOI: 10.1109/TCIAIG.2011.2149523
    — Formalizes model transformations from mission to space. In PGT, comparable transformations are user-composable modifiers with seeds.

26. D. Protsenko, J. Dormans, and R. van Rozen, "Maintenance in procedural level design: Lessons from Ludoscope," in *Proc. FDG*, 2025. DOI: 10.1145/3723498.3723784
    — Analyses how Ludoscope, the industrial pipeline tool behind *Unexplored 1 and 2* (more than 20K rewrite rules), was maintained, and proposes a DSL for "level blueprints." The closest *industrial* analogue to PGT's ordered, serializable generation pipelines. It also motivates PGT's recipe and JSON design for maintainability.

27. R. van Rozen, G. Samaritaki, and J. Dormans, "Debugging procedural level designs with Mental Maps," in *Proc. FDG*, 2022. DOI: 10.1145/3555858.3564252
    — Proposes a visual DSL of spatial relations between rooms and paths, used as generator blueprints and debugging lenses. Relevant to PGT's analysis dashboard as a "debugging lens" on generated graphs.

28. R. van der Linden, R. Lopes, and R. Bidarra, "Designing procedurally generated levels," in *Proc. AIIDE Workshop on AI in the Game Design Process*, 2013. DOI: 10.1609/aiide.v9i3.12592
    — Designer-authored gameplay constraints compile into graph grammars that produce action graphs, which are then mapped to dungeon layouts. Graph-first dungeon pipeline that is close to PGT.

29. A. M. Smith and M. Mateas, "Answer set programming for procedural content generation: A design space approach," *IEEE Trans. Comput. Intell. AI Games*, vol. 3, no. 3, pp. 187–200, 2011. DOI: 10.1109/TCIAIG.2011.2158545
    — Treats generators as declarative design-space specifications (ASP). PGT takes the complementary, imperative, composable route (modifier stacks), and its recipes play the role of a design-space spec.

30. T. Smith, J. Padget, and A. Vidler, "Graph-based generation of action-adventure dungeon levels using answer set programming," in *Proc. FDG*, 2018. DOI: 10.1145/3235765.3235817
    — ASP generates acyclic lock-and-key dungeon *graphs* under hard constraints and is evaluated with ERA. Directly related to PGT's graph generators and semantic (lock/key) modifiers.

31. A. Madkour, S. Marsella, C. Harteveld, M. Seif El-Nasr, and J.-W. van de Meent, "Guiding generative graph grammars of dungeon mission graphs via examples," in *Proc. AIIDE Workshops*, 2021. URL: https://www.semanticscholar.org/paper/98e4d7a51264e5506029a95763384a3f3291585b
    — Learns probabilistic graph-grammar parameters from example mission graphs.

32. A. Madkour, S. Marsella, and C. Harteveld, "Towards non-technical designer control over PCG systems: Investigating an example-based mechanism for controlling graph grammars," in *Proc. FDG*, 2022. DOI: 10.1145/3555858.3555895
    — Designers select a region of an ERA plot to steer a probabilistic graph grammar for dungeon mission graphs. Combines graph generation and ERA in one tool, so it is a close precedent for PGT's sweep-plus-metrics workflow.

33. S. Cooper and M. Bazzaz, "A constraint-based graph grammar approach unifying level and playthrough generation," in *Proc. EXAG/INT Workshop @ AIIDE*, 2025. URL: https://www.semanticscholar.org/paper/aff7af576aa09d9441a9a484d7952700f8d63d61
    — Constraint-solved graph grammars that jointly produce levels and playthroughs. A recent graph-grammar dungeon approach.

34. S. Cooper, "Sturgeon: Tile-based procedural level generation via learned and designed constraints," in *Proc. AIIDE*, 2022, pp. 26–36. DOI: 10.1609/aiide.v18i1.21944
    — Mid-level constraint API with pluggable solvers that supports repair, infilling, and ERA coverage. Comparable in spirit to PGT's pluggable modifiers, but at the tile level.

35. J. Gutierrez and J. Schrum, "Generative adversarial network rooms in generative graph grammar dungeons for The Legend of Zelda," in *Proc. IEEE Congr. Evol. Comput. (CEC)*, 2020, pp. 1–8. DOI: 10.1109/CEC48606.2020.9185631
    — Hybrid pipeline: a graph grammar generates dungeon topology from a designer backbone (lock/key), then a GAN generates room contents. An explicit two-stage graph-to-rooms pipeline that matches PGT's topology-then-rasterize split.

36. A. Liapis, "Multi-segment evolution of dungeon game levels," in *Proc. GECCO*, 2017. DOI: 10.1145/3071178.3071180
    — Evolves dungeons as connected segments.

37. R. M. Smelik, T. Tutenel, K. J. de Kraker, and R. Bidarra, "A declarative approach to procedural modeling of virtual worlds," *Computers & Graphics*, vol. 35, no. 2, pp. 352–363, 2011. DOI: 10.1016/j.cag.2010.11.011
    — SketchaWorld: layered declarative modeling with consistency maintenance between procedural and manual edits. Relevant to PGT's interplay of undoable manual edits and regenerated modifier output.

38. R. M. Smelik, T. Tutenel, K. J. de Kraker, and R. Bidarra, "Integrating procedural generation and manual editing of virtual worlds," in *Proc. PCG Workshop @ FDG*, 2010, pp. 2:1–2:8. DOI: 10.1145/1814256.1814258
    — Identifies the challenges of mixing procedural and manual edits iteratively, a core design issue that PGT addresses with commands and zones.

39. A. Khalifa, P. Bontrager, S. Earle, and J. Togelius, "PCGRL: Procedural content generation via reinforcement learning," in *Proc. AIIDE*, 2020. DOI: 10.1609/aiide.v16i1.7416
    — Frames level design as an MDP with an open-source gym framework. A research framework for generator *training*, whereas PGT is a framework for generator *composition and analysis*.

40. F. Rupp and K. Eckert, "G-PCGRL: Procedural graph data generation via reinforcement learning," in *Proc. IEEE CoG*, 2024, pp. 1–8. DOI: 10.1109/CoG60054.2024.10645633
    — Extends PCGRL to edit adjacency matrices for game graph data (economies, skill trees). A graph-native generator that could be wrapped as a PGT modifier.

41. A. Khalifa, R. Gallotta, M. Barthet, A. Liapis, J. Togelius, and G. N. Yannakakis, "The Procedural Content Generation Benchmark: An open-source testbed for generative challenges in games," in *Proc. FDG*, 2025. DOI: 10.1145/3723498.3723794 (arXiv: 2503.21474)
    — Twelve problems with standard quality, diversity, and controllability metrics for comparing generators. Shares PGT's reproducibility goal, but it is a headless benchmark with fixed problems. PGT is an interactive workbench with user-composed pipelines and graph metrics.

42. Epic Games, "Procedural Content Generation (PCG) framework — development guides," *Unreal Engine Documentation*, 2024–2025. URL: https://dev.epicgames.com/documentation/en-us/unreal-engine/pcg-development-guides
    — Industrial node-graph PCG system in UE5 (point/spatial data flowing through node graphs, hierarchical and runtime generation). The main commercial example of composable, node-based PCG. It targets scattering and geometry rather than abstract level graphs, and has no research-analysis tooling.

### 3. Evaluation and analysis of generated levels (ERA, metrics, graph analysis, datasets, reproducibility)

43. G. Smith and J. Whitehead, "Analyzing the expressive range of a level generator," in *Proc. PCG Workshop @ FDG*, 2010, pp. 4:1–4:7. DOI: 10.1145/1814256.1814260
    — Foundational ERA: generate many artifacts, compute metrics, and plot 2D histograms. PGT's batch runner, parameter sweeps, and CSV export directly support ERA over graph metrics.

44. M. Cook, J. Gow, G. Smith, and S. Colton, "Danesh: Interactive tools for understanding procedural content generators," *IEEE Trans. Games*, vol. 14, no. 3, pp. 329–338, 2022. DOI: 10.1109/TG.2021.3078323
    — Unity plugin for automatic analysis, generative-space visualization (ERA), parameter discovery, and interface smoothing. The closest *tool-level* analogue to PGT's analysis and batch features. Danesh analyzes arbitrary generator parameters with user metrics. PGT adds a graph editor, a pipeline stack, and a built-in suite of graph-theoretic metrics.

45. A. Summerville, J. R. H. Mariño, S. Snodgrass, S. Ontañón, and L. H. S. Lelis, "Understanding Mario: An evaluation of design metrics for platformers," in *Proc. FDG*, 2017. DOI: 10.1145/3102071.3102080
    — Tests which computational level metrics correlate with human judgments. A caution for PGT: graph metrics need validation against player or designer perception.

46. A. Liapis, G. N. Yannakakis, and J. Togelius, "Towards a generic method of evaluating game levels," in *Proc. AIIDE*, 2013. DOI: 10.1609/aiide.v9i1.12680
    — Genre-agnostic, quantifiable patterns (area control, exploration, balance) evaluated on strategy maps and roguelike dungeons. Many are graph- and path-based and complement PGT's centrality and flow metrics.

47. A. Canossa and G. Smith, "Towards a procedural evaluation technique: Metrics for level design," in *Proc. FDG (PCG Workshop)*, 2015. URL: https://www.semanticscholar.org/paper/250d614bc799c1c5600062386f0b9b3fbd967354
    — Derives level-design metrics from designer interviews. A source for justifying PGT's metric choices.

48. O. Withington and L. Tokarchuk, "The right variety: Improving expressive range analysis with metric selection methods," in *Proc. FDG*, 2023. DOI: 10.1145/3582437.3582453
    — Quantitative criteria for choosing ERA metric pairs. Directly applicable to PGT, which exposes many graph metrics and must help users pick informative pairs.

49. O. Withington and L. Tokarchuk, "Compressing and comparing the generative spaces of procedural content generators," in *Proc. IEEE CoG*, 2022, pp. 143–150. DOI: 10.1109/CoG51982.2022.9893615
    — Dimensionality reduction (e.g., MCA) to compare whole generative spaces. A possible extension to PGT's batch analytics.

50. O. Withington, M. Cook, and L. Tokarchuk, "On the evaluation of procedural level generation systems," in *Proc. FDG*, 2024. DOI: 10.1145/3649921.3650016 (arXiv: 2404.18657)
    — Taxonomy and survey of PCG evaluation practice. It finds weak reuse and calls for "diverse research frameworks" and code and methodology reuse. This is strong motivation for PGT's reproducible seeds, recipes, and exports.

51. J. D. Boucher, G. Smith, and Y. Telliel, "Axes of characterizing generative systems: A taxonomy of approaches to expressive range analysis," in *Proc. EXAG Workshop @ AIIDE*, 2024. URL: https://www.semanticscholar.org/paper/ac98196bca8d01e75e6fa038b117d9da6edf0b9c
    — Taxonomy of ERA variants, useful for positioning PGT's analysis.

52. M. Bazzaz and S. Cooper, "Level generation with constrained expressive range," in *Proc. FDG*, 2025. DOI: 10.1145/3723498.3723845
    — Uses the ERA grid as a target space and systematically fills it with a constraint-based generator, turning analysis into generation.

53. H. Schaa and N. A. Barriga, "Evaluating the expressive range of Super Mario Bros level generators," *Algorithms*, vol. 17, no. 7, p. 307, 2024. DOI: 10.3390/a17070307
    — Recent ERA comparison of GA, GAN, and Markov generators over nine metrics, showing the standard comparative-ERA protocol that PGT batch runs can reproduce.

54. D. Gravina, A. Khalifa, A. Liapis, J. Togelius, and G. N. Yannakakis, "Procedural content generation through quality diversity," in *Proc. IEEE CoG*, 2019, pp. 1–8. DOI: 10.1109/CIG.2019.8848053
    — Overview of QD for PCG, where behavior metrics define the coverage space. PGT's graph metrics could serve as QD behavior descriptors.

55. G. Bao, B. Weng, L. Ding, Q. Du, Y. Zang, J. Wang, and F. Yan, "Functional node layout in Metroidvania game worlds: A complex network analysis," *PLoS ONE*, vol. 21, 2026. DOI: 10.1371/journal.pone.0354705
    — Converts *Hollow Knight*, *Prince of Persia: The Lost Crown*, and *Blasphemous 2* maps into graphs and analyses save, teleport, and boss placement with network shortest-path NNI, k-hop reachability, closeness, and betweenness. Very close to PGT's analysis dashboard (betweenness, centrality on level graphs) applied to commercial games. PGT makes such analyses interactive and batchable on generated graphs.

56. P. Martin, "A spatial analysis of the JBA headquarters in Splinter Cell: Double Agent," venue: ? (S2 lists *Entertainment Computing*, while the DOI prefix suggests ACM *Computers in Entertainment*), 2011. DOI: 10.1145/2159365.2159382 (?)
    — Applies space-syntax measures (integration/segregation, isovists, visibility/accessibility discrepancy) to game levels. A space-syntax precedent for graph-theoretic level analysis. *Venue and DOI are uncertain and should be checked before citing.*

57. A. Summerville, M. Behrooz, M. Mateas, and A. Jhala, "The learning of Zelda: Data-driven learning of level topology," in *Proc. FDG (PCG Workshop)*, 2015. URL: https://www.semanticscholar.org/paper/0e6378e0e3215e2aa37ae410144597a59bfb9f94
    — Encodes *The Legend of Zelda* dungeons as annotated graphs and learns topological properties (Bayes nets). A key dataset-and-analysis precedent for dungeon *graphs*.

58. A. Summerville and M. Mateas, "Sampling Hyrule: Multi-technique probabilistic level generation for action role playing games," in *Proc. AIIDE*, 2015. DOI: 10.1609/aiide.v11i3.12817
    — Samples learned Zelda topology distributions (graphs) and then rooms via PCA. Another graph-then-rooms pipeline.

59. A. J. Summerville, S. Snodgrass, M. Mateas, and S. Ontañón, "The VGLC: The Video Game Level Corpus," in *Proc. PCG Workshop @ FDG*, 2016. arXiv: 1606.07487
    — Standard corpus of game levels, including Zelda dungeons with room-graph annotations. A candidate dataset for PGT import and for benchmarking graph metrics against human-designed dungeons.

60. R. van der Linden, R. Lopes, and R. Bidarra, "Procedural generation of dungeons," *IEEE Trans. Comput. Intell. AI Games*, vol. 6, no. 1, pp. 78–89, 2014. DOI: 10.1109/TCIAIG.2013.2290371
    — Survey of dungeon generation that calls for gameplay-based control and better designer tooling, the gap that PGT targets.

### 4. Surveys and books

61. N. Shaker, J. Togelius, and M. J. Nelson, *Procedural Content Generation in Games*. Cham, Switzerland: Springer, 2016. DOI: 10.1007/978-3-319-42716-4 [Zotero]
    — Standard textbook. The chapters on constructive dungeon methods, grammars, ASP, mixed-initiative design, and evaluation are all relevant background.

62. T. X. Short and T. Adams, Eds., *Procedural Generation in Game Design*. Boca Raton, FL, USA: CRC Press, 2017. ISBN: 978-1-4987-9919-5 (?) [Zotero, stored as webpage]
    — Practitioner perspectives, including Dormans on cyclic dungeon generation. Check the ISBN before citing.

63. J. Togelius, G. N. Yannakakis, K. O. Stanley, and C. Browne, "Search-based procedural content generation: A taxonomy and survey," *IEEE Trans. Comput. Intell. AI Games*, vol. 3, no. 3, pp. 172–186, 2011. DOI: 10.1109/TCIAIG.2011.2148116
    — Gives the taxonomy (online/offline, constructive/generate-and-test, etc.) used to classify PGT's modifiers.

64. M. Zamorano, C. Cetina, and F. Sarro, "The quest for content: A survey of search-based procedural content generation for video games," arXiv: 2311.04710, 2023. DOI: 10.48550/arXiv.2311.04710 [Zotero]
    — Software-engineering-oriented SBPCG survey covering 2011–2022.

65. A. Summerville, S. Snodgrass, M. Guzdial, C. Holmgård, A. K. Hoover, A. Isaksen, A. Nealen, and J. Togelius, "Procedural content generation via machine learning (PCGML)," *IEEE Trans. Games*, vol. 10, no. 3, pp. 257–270, 2018. DOI: 10.1109/TG.2018.2846639

66. J. Liu, S. Snodgrass, A. Khalifa, S. Risi, G. N. Yannakakis, and J. Togelius, "Deep learning for procedural content generation," *Neural Comput. Appl.*, vol. 33, pp. 19–37, 2021. DOI: 10.1007/s00521-020-05383-8

67. B. M. F. Viana and S. R. dos Santos, "Procedural dungeon generation: A survey," *J. Interact. Syst.*, vol. 12, no. 1, pp. 83–101, 2021. DOI: 10.5753/jis.2021.999 [Zotero]
    — Finds that mixed-initiative dungeon tools and barrier (lock/key) support are under-explored, both of which PGT addresses.

68. M. Farrokhi Maleki and R. Zhao, "Procedural content generation in games: A survey with insights on emerging LLM integration," in *Proc. AIIDE*, vol. 20, 2024. DOI: 10.1609/aiide.v20i1.31877 [Zotero]

69. R. Gallotta, G. Todd, M. Zammit, S. Earle, A. Liapis, J. Togelius, and G. N. Yannakakis, "Large language models and games: A survey and roadmap," *IEEE Trans. Games*, 2024. DOI: 10.1109/TG.2024.3461510

70. X. Mao, W. Yu, K. D. Yamada, and M. R. Zielewski, "Procedural content generation via generative artificial intelligence," *Interdisciplinary Information Sciences*, 2026 (arXiv 2024: 2407.09013). DOI: 10.4036/iis.2026.R.01
    — Survey of generative-AI PCG. The author list differs between the arXiv and journal versions (S2 lists extra authors on the journal version), so check before citing.

### 5. Recent LLM/ML-based level and graph generation (2023–2026)

71. G. Todd, S. Earle, M. U. Nasir, M. C. Green, and J. Togelius, "Level generation through large language models," in *Proc. FDG*, 2023. DOI: 10.1145/3582437.3587211
    — Fine-tuned LLMs generate Sokoban levels, and performance scales with data. Baseline for LLM-based level generation, which could become an LLM modifier in PGT.

72. S. Sudhakaran, M. González-Duque, C. Glanois, M. Freiberger, E. Najarro, and S. Risi, "MarioGPT: Open-ended text2level generation through large language models," in *Proc. NeurIPS*, 2023. arXiv: 2302.05981
    — Text-prompted tile-level generation plus novelty search. Mentioned briefly because it targets tiles rather than graphs.

73. M. U. Nasir, S. James, and J. Togelius, "Word2World: Generating stories and worlds through large language models," arXiv: 2405.06686, 2024.
    — LLM pipeline from story to entities to tile placement to playable world. A multi-step LLM pipeline, comparable in structure to PGT's stack but not deterministic or seeded.

74. V. Kumaran, D. Carpenter, J. Rowe, B. Mott, and J. Lester, "Procedural level generation in educational games from natural language instruction," *IEEE Trans. Games*, vol. 16, no. 4, pp. 937–946, 2024. DOI: 10.1109/TG.2024.3392670 [Zotero]
    — An LLM turns designer natural language into constraints and objectives, and RL agents then validate the generated levels. This NL → generator parameters → agent-validation loop maps onto PGT's recipe → pipeline → agent-simulation loop.

75. C. H. Lim, M. Yan, Y. Bai, R. Li, and H. Zhang, "Zero-shot 3D map generation with LLM agents: A dual-agent architecture for procedural content generation," arXiv: 2512.10501, 2025.
    — LLM actor and critic agents configure parameters of existing PCG tools from natural language. Suggests a future LLM front end that writes PGT JSON recipes.

76. I.-C. Baek, S.-H. Kim, S. Earle, Z. Jiang, J. Noh, J. Togelius, and K.-J. Kim, "PCGRLLM: Large language model-driven reward design for procedural content generation reinforcement learning," *IEEE Trans. Games*, vol. 18, pp. 529–542, 2026 (?). DOI: 10.1109/TG.2026.3695197 (arXiv: 2502.10906)

77. M. Júnior, M. H. A. C. Adaniya, and L. Nunes, "Customizable procedural content generation with LLMs," in *Proc. SBGames*, 2025. DOI: 10.5753/sbgames.2025.10297
    — A fine-tuned DeepSeek-R1-distill model generates Zelda-like levels, evaluated for diversity with *graph-based analysis*. One of the few LLM-PCG works that uses graph metrics.

---

#### Notes and gaps
- I found no peer-reviewed 2023–2026 paper where an LLM directly generates dungeon *mission or room graphs* with lock/key semantics (arXiv and S2 searches came back empty). That gap supports PGT's positioning. Treat it as "not found," not "does not exist."
- Graph-theoretic analysis of real game maps is sparse. The most direct recent work is Bao et al. 2026 (#55), and space syntax (#56) is the older tradition. Neither provides an interactive, generator-integrated analysis tool.
- Reproducibility: Withington et al. 2024 (#50) and the PCG Benchmark (#41) are the strongest citations for PGT's seeded, recipe-based, exportable design.

---

## Theme E — Adversarial novelty check of claims (a)–(c) (2026-11-19)

*Compiled 2026-11-19. Scope: only works **not** already in `Documentation/RelatedWork.md`. Sources: Zotero (first), Semantic Scholar API, Crossref, arXiv, web, and publisher PDFs where reachable. All metadata verified against Crossref/S2. "?" marks fields I could not confirm. "[Zotero]" means the item is already in the library. AAAI OJS and NCSU repository pages blocked automated access, so for GME/PEM I used the published abstracts plus secondary descriptions, and say so where it matters.*

**Bottom line**
- (a): weakened (slightly)
- (b): weakened (moderately)
- (c): holds, but frame it as applying known incremental-replanning ideas, not as a new algorithm

The main body of prior art the survey misses is **experience management / narrative mediation** (Riedl and Young; Robertson and Young; Thue and Bulitko). These systems replan from the player's *current* state while play is running, and they revise world state the player has not observed. PGT should position against this body explicitly.

---

### Claim (a): trigger-based partial regeneration at runtime that preserves the surrounding topology

#### Threatening works (closest first)

[N1] J. Robertson and R. M. Young, "Automated gameplay generation from declarative world representations," in *Proc. AIIDE*, 2015. DOI: 10.1609/aiide.v11i1.12790
[N2] J. Robertson and R. M. Young, "The General Mediation Engine," in *Proc. AIIDE* (vol. 10, no. 3, workshop/demo track), 2014. DOI: 10.1609/aiide.v10i3.12739
[N3] J. Robertson and R. M. Young, "Perceptual experience management," *IEEE Trans. Games*, vol. 11, no. 1 (?), pp. 15–24, Mar. 2019. DOI: 10.1109/TG.2018.2817162

- **What they do.** GME is a game engine whose world comes from a PDDL-style planning domain. The abstract of [N1] says it uses "a PCG pipeline to generate and control a range of gameplay experiences from an underlying IN experience management construct." A secondary description says the game world "dynamically reconfigures whenever the experience management framework modifies the underlying world state." [N3] calls GME "an experience manager capable of procedurally generating and revising a game world." It revises parts of the world the player has not observed so that the author's constraints still hold.
- **How close.** **High at the concept level**: runtime, in-place revision of the game world during play, driven by a manager. This weakens any wording like "first to regenerate a live level during play."
- **Residual delta.**
  - GME revises *symbolic world state*: facts, and object or character positions in pre-authored locations.
  - I could not confirm (full texts blocked) that it rewrites spatial topology or tile geometry.
  - It has no designer-placed spatial triggers, no node/edge mask, and no raster/tilemap re-realization through a layered PCG pipeline.
  - Preservation is defined by player *knowledge*, not by graph topology.

[N4] L.-P. Cheng, E. Ofek, C. Holz, and A. D. Wilson, "VRoamer: Generating on-the-fly VR experiences while walking inside large, unknown real-world building environments," in *Proc. IEEE VR*, 2019, pp. ? DOI: 10.1109/VR.2019.8798074

- **What it does.** Procedurally generates a dungeon on the fly while the user walks. It instantiates pre-authored rooms or corridors and doors as the physical space is discovered, and uses doors to "prevent users from seeing changes beyond the current virtual scene."
- **How close.** Medium. Runtime topology generation hidden from the player.
- **Residual delta.** Append-only, like Momentum. It does not regenerate already-realized interior nodes, and it has no progression logic.

[N5] E. A. Suma, S. Clark, D. Krum, S. Finkelstein, M. Bolas, and Z. Wartell, "Leveraging change blindness for redirection in virtual environments," in *Proc. IEEE VR*, 2011. DOI: 10.1109/VR.2011.5759455
[N6] B. G. Koltai, J. E. Husted, R. Vangsted, T. N. Mikkelsen, and M. Kraus, "Procedurally generated self overlapping mazes in virtual reality," in *Proc. ArtsIT/DLI* (LNICST), 2020. DOI: 10.1007/978-3-030-53294-9_16
[N7] K. Vasylevska and H. Kaufmann, "Compressing VR: Fitting large virtual environments within limited physical space," *IEEE Comput. Graph. Appl.*, 2017. DOI: 10.1109/MCG.2017.3621226
[N8] S. Marwecki and P. Baudisch, "Scenograph: Fitting real-walking VR experiences into various tracking volumes," in *Proc. UIST*, 2018. DOI: 10.1145/3242587.3242648

- **What they do.** Swap doors or room layouts while the user is not looking ([N5], [N7]). Procedurally generate overlapping maze layouts ([N6]; whether this happens at runtime is "?"). Split narrative locations to fit a tracking volume while keeping the narrative structure ([N8]).
- **How close.** Low to medium. They extend the "impossible/flexible spaces" entries already in the survey.
- **Residual delta.** Perceptual or physical-space motivation. No generative graph pipeline, no lock/key semantics.

[N9] D. Thue and V. Bulitko, "Procedural game adaptation: Framing experience management as changing an MDP," in *Proc. AIIDE Workshops (INT)*, 2012. DOI: 10.1609/aiide.v8i2.12535

- **What it does.** A formal framework for changing a game's transition function *during play*. It represents Left 4 Dead's AI Director, including path changes, as an instance.
- **How close.** Low to medium. It is the formal umbrella under which PGT's runtime regeneration is a "game-dynamics change."

**Ludography (cite as games):**
- *Left 4 Dead 2* (Valve, 2009). The AI Director opens or closes pre-authored alternate routes. Sources: GamesRadar developer interview, https://www.gamesradar.com/left-4-dead-2-dev-interview/2 ; Valve Developer Community. The routes are selected, not generated. Whether they change mid-chapter is "?"
- *Tea For God* (void room, in development). A VR roguelite that generates impossible-space cells on the fly and discards distant ones (https://void-room.itch.io/tea-for-god/devlog/235914/open-world-with-impossible-spaces). This is streaming/append-and-evict, not trigger-scoped regeneration.

**Low threat (design-time):** A. Bauer and Z. Popović, "RRT-based game level analysis, visualization, and visual refinement," *Proc. AIIDE*, 2012, DOI: 10.1609/aiide.v8i1.12512. Interactive reachability-driven refinement, offline.

#### Verdict (a): **Weakened (slightly)**
Runtime revision of a game world under a manager (GME/PEM) and runtime hidden topology change (VR) both exist. Nothing found performs **designer-placed spatial triggers → masked subgraph regeneration → re-rasterization through the same PCG pipeline, with the rest of the graph fixed**.

**Suggested rewording:**
> "PGT brings constrained, mask-scoped regeneration (previously a design-time operation) into play: in-world triggers regenerate selected nodes/edges of the level graph and re-rasterize only the affected region, preserving the remaining topology. Unlike experience managers that revise symbolic world state [N1]–[N3], or VR systems that hide layout swaps [N4]–[N7], PGT operates on the spatial level graph within a full generation pipeline."

---

### Claim (b): temporally aware lock-and-key progression (re-planned from current position and inventory; trigger-gated keys)

#### Threatening works

[N10] C. Ashmore and M. Nitsche, "The quest in a generated world," in *Proc. DiGRA Conf.: Situated Play*, Tokyo, 2007. URL: https://dl.digra.org/index.php/dl/article/view/312

- **What it does (verified from the PDF).** In *Charbitat*, "world and quest generation … happen during the expansion of the game world." When the player reaches a world edge, the backend creates "a new tile based on the current player status and the surrounding world." It "has to be aware of what keys and locks exist in the world and how they are arranged," and places barriers (rivers, walls) and spawns keys in other tiles.
- **How close.** **High for the "keys/locks placed at runtime from the current player state" sub-claim.** This predates PGT by about 19 years and is missing from the survey.
- **Residual delta.**
  - Append-only (tiles persist; nothing is regenerated).
  - Keys are scored heuristically (about 13 evaluator rules), with no solvability guarantee.
  - No re-planning after mutation of existing space, and no trigger-gated withholding.

[N3] Robertson & Young, "Perceptual experience management" (see above).
[N11] J. Robertson and R. M. Young, "Finding Schrödinger's gun," in *Proc. AIIDE*, 2014. DOI: 10.1609/aiide.v10i1.12724
[N12] M. Riedl, C. J. Saretto, and R. M. Young, "Managing interaction between users and agents in a multi-agent storytelling environment," in *Proc. AAMAS*, 2003. DOI: 10.1145/860575.860694
[N13] M. O. Riedl and V. Bulitko, "Interactive narrative: An intelligent systems approach," *AI Mag.*, vol. 34, no. 1, 2013. DOI: 10.1609/aimag.v34i1.2449

- **What they do.** Narrative mediation: when the player deviates, the system either *accommodates* (replans from the current world state so goals stay achievable) or *intervenes*.
  - [N11] and [N3] use a model of player knowledge to change facts the player has not observed ("Schrödinger's gun": where an item is, or whether it exists, is decided late).
- **How close.** **Medium to high, conceptually.** Replanning the remaining solution from the player's current state after a disruption is the core of mediation. Deciding a key's location only once a trigger fires is the same deferred-commitment idea.
- **Residual delta.**
  - Their domain is story plans with STRIPS/PDDL actions, not a spatial lock-and-key graph with doors and keys realized in a tilemap.
  - The change is driven by player deviation, not by designer triggers.
  - No in-place topology regeneration.

[N14] V. Genoese-Zerbi, J. Robertson, and R. E. Cardona-Rivera, "Categorizing experience management problem difficulty using graph analysis," in *Proc. IEEE CoG*, 2026. DOI: 10.1109/CoG67430.2026.11778899

- **What it does.** Formalizes avoiding "online dead-ends where experiential outcomes cannot be achieved" using state-space and causal-graph properties (safety and liveness).
- **How close.** Medium. It is the 2026 formal statement of "keep the game solvable from the current state online." Cite it as the formal counterpart of PGT's temporal guarantees.

[N15] I. Swartjes, E. Kruizinga, M. Theune, and D. Heylen, "Emergent narrative and late commitment" (title per Crossref; may differ), in *Proc. IVA* (LNCS), 2008 (?). DOI: 10.1007/978-3-540-85483-8_80
[N16] B. Sunshine-Hill and N. Badler, "Perceptually realistic behavior through alibi generation," in *Proc. AIIDE*, 2010. DOI: 10.1609/aiide.v6i1.12389

- **What they do.** Late commitment: world facts (e.g., an object's location) or unobserved agent state are filled in at runtime, consistent with what the player has seen.
- **How close.** Low to medium. These are the conceptual ancestors of the "withheld key" mechanic.

[N17] L. Gomes, J. Ribeiro-Gomes, and J.-P. Barros, "Using Petri nets for analysis of navigation paths in constrained graphs – application to roguelike games," in *Proc. PNSE'24*, CEUR-WS vol. 3730, 2024. URL: https://ceur-ws.org/Vol-3730/paper17.pdf

- **What it does.** Resource-gated (key/lock) roguelike room graphs are converted to Petri nets. Reachability-graph analysis then classifies the map as viable, non-viable, or inviable regardless of player choices.
- **How close.** Low. Static and from the start state, but it is a formal backbone alongside Johnson et al. Re-running it from the current marking would be one way to formalize PGT's re-planning.

#### Verdict (b): **Weakened (moderately)**
Two ideas are prior art:
- Runtime key/lock placement from the current player status [N10].
- Replanning from the current state, with late commitment of unobserved facts so goals stay reachable [N3], [N11]–[N16].

What remains unfound is lock-and-key progression **re-planned after an in-place topology regeneration** that:
- respects opened doors and collected keys (temporal_state), and
- uses **trigger-gated withholding**, where the key is guaranteed to spawn inside the regenerated subgraph.

**Suggested rewording:**
- Drop any phrasing like "first to place keys according to the player's current state."
- Use instead: "PGT re-plans lock-and-key progression *after mid-play topology regeneration*, from the player's current position and inventory, and supports trigger-gated locks whose keys are committed only inside the regenerated region. This applies the late-commitment/accommodation principle of experience management [N3], [N11], [N12] to spatial lock-and-key graphs, extending runtime key placement in append-only worlds [N10] to mutating ones."

---

### Claim (c): persistent validator agent that survives regenerations (incremental solvability validation)

#### Threatening works

[N18] M. Likhachev and S. Koenig, "Incremental heuristic search in games: The quest for speed," in *Proc. AIIDE*, 2006. DOI: 10.1609/aiide.v2i1.18758
[N19] S. Koenig and M. Likhachev, "Fast replanning for navigation in unknown terrain," *IEEE Trans. Robot.*, vol. 21 (?), no. 3 (?), 2005. DOI: 10.1109/TRO.2004.838026 (D* Lite)
[N20] S. Koenig, M. Likhachev, and D. Furcy, "Lifelong planning A*," *Artif. Intell.*, vol. 155, 2004. DOI: 10.1016/j.artint.2003.12.001
[N21] V. King, "Fully dynamic algorithms for maintaining all-pairs shortest paths and transitive closure in digraphs," in *Proc. FOCS*, 1999. DOI: 10.1109/SFFCS.1999.814580

- **What they do.** An agent keeps its search state and repairs it when graph edges or costs change ([N18]–[N20]; [N18] explicitly targets games). Dynamic transitive closure maintains reachability under edge updates ([N21]).
- **How close.** **Medium at the algorithm level.** Keeping agent state and re-exploring only from the changed region is textbook incremental replanning.
- **Residual delta.** None of them is a *playability/solvability validator for PCG*. They have no inventory-gated state (keys), and the graph changes come from the environment, not from a generator.

[N22] C. Lewis and J. Whitehead, "Repairing games at runtime or, how we learned to stop worrying and love emergence," *IEEE Softw.*, vol. 28, no. 5, pp. 53–59, 2011. DOI: 10.1109/MS.2011.87 [Zotero]

- **What it does.** Mayet: runtime monitoring of game state, with automatic repair when undesirable states arise.
- **How close.** Low to medium. A runtime validity monitor and repairer, but rule-based, with no simulated player and no PCG.

[N23] S. Shirzadehhajimahmood, I. S. W. B. Prasetya, F. Dignum, M. Dastani, and G. Keller, "Using an agent-based approach for robust automated testing of computer games," in *Proc. A-TEST @ ESEC/FSE*, 2021. DOI: 10.1145/3472672.3473952
[N24] I. S. W. B. Prasetya *et al.*, "Navigation and exploration in 3D-game automated play testing," in *Proc. A-TEST*, 2020. DOI: 10.1145/3412452.3423570 (content beyond the title not verified here)

- **What they do.** BDI test agents (iv4XR) that keep beliefs and stay robust when "layout and game logic … change during development."
- **How close.** Low to medium. These are persistent-belief agents facing changed levels, but the changes happen between builds, not during a run, and the goal is regression testing, not PCG solvability.

[N25] S. Ariyurek, E. Surer, and A. Betin-Can, "Playtesting: What is beyond personas," *IEEE Trans. Games*, 2023. DOI: 10.1109/TG.2022.3165882 [Zotero]

- **What it does.** Developing personas that remember the paths they tested across sessions.
- **How close.** Low. The memory spans test sessions, not a mutating level.

**Searched with no hit:** 2024–2026 arXiv LLM "game master" / dynamic world papers. RPGBench (arXiv:2502.00595) BFS-checks reachability of LLM-generated games once, offline. Dungeon Crawl Infinite (arXiv:2508.15866) generates mechanics code at runtime with correctness guarantees but no spatial solvability. Neither validates across mutations.

#### Verdict (c): **Holds**, with a framing caveat
No work found uses a simulated player that persists across content regenerations as an *incremental solvability validator* for a mutating PCG level, keeping inventory and explored set and re-exploring from the trigger location. Momentum (Kar 2026, already listed) remains the nearest PCG prior art.

**Suggested rewording:**
- Do not claim algorithmic novelty.
- Use instead: "PGT applies incremental replanning [N18]–[N20] to PCG validation: a persistent validator agent carries inventory and explored state across regenerations and re-validates solvability from the trigger location, rather than re-validating the whole level from the start state."
- Cite D* Lite/LPA* and, optionally, dynamic reachability [N21].

---

### Re-assessment of entries already in the survey
- **Lopes, Eisemann & Bidarra 2018** and **Dormans & Bakkes 2011** remain the closest PCG works for (a). However, GME [N1]–[N3] is closer than both on "runtime revision in place" and should be added to the "closest prior art" table.
- **Momentum (Kar 2026)** is still the nearest work for (c). Its assessment is unchanged.
- In the ludography, add *Charbitat* (research game, [N10]), *Left 4 Dead 2*, and *Tea For God*.

### Low-relevance items found (for completeness, not threats)
- E. Halina and M. Guzdial, "Representing and generating levels over time through playtrace reconstructive partitioning," arXiv:2607.12097, 2026. A temporal "cake" level representation; offline (Sokoban).
- K. Hartsook, A. Zook, S. Das, and M. O. Riedl, "Toward supporting stories with procedurally generated game worlds," *Proc. IEEE CIG*, 2011, DOI: 10.1109/CIG.2011.6032020. Story-driven world generation, offline.
- S. Das, A. Zook, and M. O. Riedl, "Examining game world topology personalization," *Proc. CHI*, 2015, DOI: 10.1145/2702123.2702473. Abstract not retrieved, so whether it runs at runtime is "?"; check it before citing.
- J. Robertson, R. E. Cardona-Rivera, and R. M. Young, "Invisible dynamic mechanic adjustment in virtual reality games," *Proc. IEEE AIVR*, 2020, DOI: 10.1109/AIVR50618.2020.00057. Runtime mechanic changes gated by player knowledge. Relevant if PGT argues that its regenerations are imperceptible.

### Open verification items
- Full texts of [N1]–[N3]: confirm whether GME regenerates spatial layout (rooms and connectivity) or only object and fact state. This decides whether (a) stays "slightly" weakened.
- Issue number for [N3]; volume and issue for [N19]; exact title and year for [N15].
- L4D2: whether the Director changes routes mid-chapter or only at load.

---

## Theme F — Gap scan: 2026 work, workbenches, graph realization (2026-11-19)

Checked against `Documentation/RelatedWork.md` (compiled 2026-10-22) by grepping titles, authors, DOIs and arXiv IDs. Everything below is **missing from the survey**. None of these items is in the Zotero library either (spot-checked).

Sources:
- arXiv, 2026-06 to 2026-11.
- Crossref sweeps of FDG 2026 (10.1145/3815598.*), AIIDE 2026 (10.1609/aiide.v22i1.*, all DOIs from 43550 to 43620 enumerated), IEEE CoG 2026 (10.1109/cog67430.2026.*), IEEE ToG, Entertainment Computing and SBGames 2026.
- Semantic Scholar, plus GitHub (topic and keyword searches).

Metadata was verified on Crossref or arXiv. Anything I could not confirm is marked "?".

**Flag key:** ⚑ = comparable to or closer than an entry in the "closest prior art" table (RelatedWork.md lines 18–35). See the summary at the end.

Already in the survey, so not repeated here: Eger I3D 2026 (growing-graph WFC), Endrovski et al. FDG 2026, High-Dimensional PCG FDG 2026, PCG.ME CoG 2026, Two-Scale BSP ToG 2026, Nonuniform-tile WFC ToG 2026, PCGRLLM ToG 2026, Bao et al. PLoS ONE 2026, Earle et al. AIIDE 2025 (MARL level design), Lim et al. arXiv 2512.10501, Kar arXiv 2605.01783, LBS AIIDE 2023, PCG Benchmark, Gaea, Edgar.Godot, godot-constraint-solving, and the threejs-procedural-dungeon repo.

---

### 1. New work, 2026-06 to 2026-11 (venues and arXiv)

[1] K. Xu and C. Verbrugge, "Boss fights as spatio-temporal level generation," in *Proc. IEEE CoG*, 2026, pp. 1–4. doi: 10.1109/CoG67430.2026.11778879.
- **What it does:** Boss encounters are synthesized over a time-expanded (x, y, t) player-state space and validated under avatar physics.
- **How PGT differs:** PGT works on spatial graph and tile structure, not on time-expanded hazard schedules.

[2] J. Brazell and J. Robertson, "Pacing-aware procedural generation and runtime control," in *Proc. IEEE CoG*, 2026, pp. 1–4. doi: 10.1109/CoG67430.2026.11778894.
- **What it does:** One target pacing curve drives both terrain generation and a runtime director.
- **How PGT differs:** PGT regenerates the topology of selected graph regions. This work tunes pacing parameters and leaves the level structure alone.
- **Note:** Cite it under novelty claim (a), runtime regeneration.

[3] V. Genoese-Zerbi, J. Robertson, and R. E. Cardona-Rivera, "Categorizing experience management problem difficulty using graph analysis," in *Proc. IEEE CoG*, 2026, pp. 1–8. doi: 10.1109/CoG67430.2026.11778899.
- **What it does:** Links how hard it is to avoid dead-ends to measurable properties of the state-space graph.
- **How PGT differs:** PGT applies graph metrics to level topology, not to a narrative planning state space. The method could be reused for lock-and-key dead-end analysis.

[4] D. Rajesh, A. Khalifa, and J. Togelius, "Evolutionary wave function collapse," in *Proc. IEEE CoG*, 2026, pp. 1–4. doi: 10.1109/CoG67430.2026.11778645. (arXiv:2607.02082)
- **What it does:** Evolves WFC input examples and tests them on mazes and Zelda dungeons. Global constraints remain hard.
- **How PGT differs:** PGT uses WFC as a texturing pass constrained by graph structure, which supplies the global structure.

[5] T. Truesdell, E. Rankin, and B. Horn, "From tiles to jumps: Optimizing wave function collapse window size for playable platformer generation," in *Proc. IEEE CoG*, 2026. doi: 10.1109/CoG67430.2026.11778724.
- **What it does:** A parameter study of WFC window size against agent completion and player ratings.
- **How PGT differs:** The study is a single-algorithm sweep. PGT's batch experiments generalize this kind of study to whole modifier stacks.

[6] M. Siper, A. Khalifa, and J. Togelius, "Procedural content metageneration via program search and continual abstraction discovery," in *Proc. IEEE CoG*, 2026, pp. 1–7. doi: 10.1109/CoG67430.2026.11778816. (arXiv:2608.17947)
- **What it does:** LLM-driven evolution of whole generator programs. The learned libraries keep rediscovering reachability and validation utilities.
- **How PGT differs:** PGT offers hand-composed, deterministic modifier stacks rather than searched programs. The rediscovered primitives line up with PGT's built-in passes, which supports its design.

[7] Y. Zhang, K. Xu, R. Zhao, and C. Verbrugge, "Path2Patrol: Path-conditioned guard generation in stealth games through MAP-Elites," in *Proc. IEEE CoG*, 2026, pp. 1–8. doi: 10.1109/CoG67430.2026.11778548.
- **What it does:** QD generation of guard routes conditioned on player paths.
- **How PGT differs:** It covers agent placement only. PGT simulates agents on the graph or tilemap it generates.

[8] J. Martins, F. Cardoso, C. Hartz, K. Skorupska, and J. Kowalski, "Real-time procedural generation of coherent infinite multi-biome 2D landscapes," in *Proc. IEEE CoG*, 2026, pp. 1–4. doi: 10.1109/CoG67430.2026.11778897.
- **What it does:** Deterministic chunked biome blending with local physical simulation.
- **How PGT differs:** PGT assigns biomes by flood fill over the graph and rasterizes them, rather than streaming terrain.

[9] A. Vetter, E. Kühne, M. Geißler, K. Pfeiffer, and S. von Mammen, "Puzzle Anything: An assembly-graph representation for 3D puzzle authoring," in *Proc. IEEE CoG*, 2026, pp. 1–4. doi: 10.1109/CoG67430.2026.11778846.
- **What it does:** A graph representation for authoring 3D assembly puzzles.
- **How PGT differs:** That graph encodes part assembly. PGT's graphs encode spatial topology and progression.

[10] J. Pfau, I. Baverstock, M. de Ronde, M. Mol, and J. Vis, "Generative remastering: LLM versus diffusion-based level generation, target style realization, and autonomous augmentation," in *Proc. IEEE CoG*, 2026, pp. 1–8. doi: 10.1109/CoG67430.2026.11778726.
- **What it does:** A comparison of learned level generators.
- **How PGT differs:** PGT is non-learned and fully deterministic.

[11] M.-S. Park, D.-W. Kim, S. Kang, and S.-H. Jang, "Beyond playability: A design-space perspective on persistent spatial intent in co-creative PCGRL," in *Proc. IEEE CoG*, 2026. doi: 10.1109/CoG67430.2026.11778598.
- **What it does:** Keeps designer-painted regions intact during co-creative PCGRL.
- **How PGT differs:** It is related to PGT's DAG locks and pinned regions, but the mechanism is RL and grid-only.

[12] K. Xu, F. Meng, and C. Verbrugge, "Scene-modular LLM-driven procedural level generation for anomaly-detection games," in *Proc. IEEE CoG*, 2026. doi: 10.1109/CoG67430.2026.11778806.
- **What it does:** LLM-generated scene edits with a repair loop.
- **How PGT differs:** It does not generate topology or graphs.

[13] K. Kidokoro, Y. Miyake, D. Satoi, S. Asei, S. Sakata, and Y. Mizuno, "Reducing reward interference in PCGRL through multilayer level generation," in *Proc. AIIDE*, vol. 22, 2026, pp. 118–127. doi: 10.1609/aiide.v22i1.43570.
- **What it does:** Splits generation into layers so that reward terms stop interfering with each other.
- **How PGT differs:** It is a conceptual cousin of PGT's layered raster passes, but done with RL.

[14] S. Randall, M. Bazzaz, and S. Cooper, "Constraining the expressive range of shortest paths," in *Proc. AIIDE*, vol. 22, 2026. doi: 10.1609/aiide.v22i1.43592.
- **What it does:** Path-state reachability graphs that constrain all shortest paths to hit target ERA metrics. It belongs to the Cooper/Sturgeon line.
- **How PGT differs:** PGT measures path metrics after generation in its dashboard and sweeps. It does not solve for them as constraints.

[15] R. Mawhorter and M. Guzdial, "Syntactic segmentation and collage generation for videogame levels with perceptual distance," in *Proc. AIIDE*, vol. 22, 2026, pp. 149–159. doi: 10.1609/aiide.v22i1.43573. (arXiv:2610.38987)
- **What it does:** Uses a Space-Syntax-based "perceptual distance" to recover a room graph from existing levels, and runs a proof-of-concept collage generator over it.
- **How PGT differs:** It goes from tiles to a graph, the inverse of PGT's rasterizer. It could serve as an evaluation metric for PGT output.

[16] R. Agarwal *et al.* (M. Eger, senior author), "On the reproducibility of technical game AI research," in *Proc. AIIDE*, vol. 22, 2026, pp. 192–200. doi: 10.1609/aiide.v22i1.43577.
- **What it does:** Reports eight reproduction attempts and the structural barriers they hit.
- **How PGT differs:** It is not a tool. It supports PGT's reproducibility features: seeds, deterministic pipelines and CSV sweeps.

[17] R. Hardcastle and M. Guzdial, "Dungeons & Dragons encounter analysis with semi-random simulation in Foundry VTT," in *Proc. AIIDE*, vol. 22, 2026. doi: 10.1609/aiide.v22i1.43584. (arXiv:2610.38975)
- **What it does:** Analyzes encounters by simulating them with agents.
- **How PGT differs:** It covers combat only, with no spatial generation.

[18] F. Shyne, K. Facey, and S. Cooper, "Puzzle Garden 2.0: Exploring variable constraint genetic algorithms in a mixed initiative puzzle authoring tool," in *Proc. AIIDE*, vol. 22, 2026, pp. 373–383. doi: 10.1609/aiide.v22i1.43595.
- **What it does:** A mixed-initiative quality-diversity authoring framework for logic-grid puzzles.
- **How PGT differs:** It is a different domain and offers no spatial or graph pipeline.

[19] E. Halina and M. Guzdial, "Representing and generating levels over time through playtrace reconstructive partitioning," arXiv:2607.12097, Jul. 2026.
- **What it does:** A "cake" representation of a level over time, generated from playtraces (Sokoban).
- **How PGT differs:** PGT has a raster step-through timeline, but it does not use time as a generative representation.

[20] D. Wu, "PCGRL for complex platformers: Synthesizing playable and diverse levels via inflated envelopes and forward curricula," arXiv:2611.22250, Nov. 2026.
- **What it does:** Scales PCGRL to long platformer levels.
- **How PGT differs:** It is a learned, single-genre generator.

[21] A. Khalifa, M. U. Nasir, M. Siper, S. James, and J. Togelius, "Programmable cellular automata," arXiv:2609.06102, Sep. 2026.
- **What it does:** CA rules written as Python local and global functions, evaluated on PCG Benchmark games.
- **How PGT differs:** PGT's CA smoothing and erosion use fixed rules. This work is a reference for making CA passes programmable or inspectable.

[22] A. Najafgholizadeh and M. Afsharchi, "Infinite worlds from one example: What local generators must share," arXiv:2611.01048, Oct. 2026.
- **What it does:** Theory of when local, random-access WFC-style generators can be both valid and faithful to the example.
- **How PGT differs:** It is relevant to PGT's chunked or partial regeneration, but PGT gets its global structure from the graph.

[23] Z. Majercik *et al.*, "Providing rapid design feedback for 3D obstacle course games using constrained solvability queries," arXiv:2609.36225, Sep. 2026.
- **What it does:** An interactive design tool built around a GPU simulator, Go-Explore and an RL agent. It answers "can this be solved, and how?" queries, and its code is released.
- **How PGT differs:** It validates hand-authored obstacles in 3D. PGT generates the topology and validates it with walkers and the lock-and-key solver.

[24] A. Baars, F. Akker, A. Chatzimparmpas, and J. Pfau, "Ctrl + Create: Empowering creative control in AI-driven rapid level design," in *Proc. FDG*, 2026. doi: 10.1145/3815598.3815646.
- **What it does:** Diffusion-based level visualization with designer control.
- **How PGT differs:** It produces visuals only, with no structural generation.

[25] V. Gnatyuk, V. Koriukina, I. Levoshevich, P. Nurminskiy, and G. Wallner, "With the stroke of a brush: A generative-AI smart brush for instant game map editing," in *Proc. FDG*, 2026, pp. 1–12. doi: 10.1145/3815598.3815603.
- **What it does:** Learned brush-based map editing.
- **How PGT differs:** PGT's editing happens at graph level, with undo and deterministic passes.

[26] W. Wittrock and M. A. Gómez-Maureira, "Next level generation: Adaptive 3D procedural terrain driven by player skill," in *Proc. FDG*, 2026. doi: 10.1145/3815598.3815670.
- **What it does:** Experience-driven terrain parameters, with a user study (n = 30).
- **How PGT differs:** It adapts parameters, not topology.

[27] J. Varsaluoma, "Mapperoni: A tool for teaching the basics of level design," in *Proc. FDG*, 2026, Art. 95. doi: 10.1145/3815598.3815703.
- **What it does:** Turns a 2D layout image into a quick 3D walk-through.
- **How PGT differs:** It is a teaching tool with no generation.

[28] S. Davern and M. Haahr, "SPHINX 2: Procedural generation of narrative puzzles for open world games," *Entertain. Comput.*, vol. 58, Art. 101162, 2026. doi: 10.1016/j.entcom.2026.101162.
- **What it does:** Puzzle-dependency generation for open worlds.
- **How PGT differs:** It sits next to the survey's §A8, puzzle graphs linked to space. PGT's solver only tracks lock and key state.

[29] I. F. Vieira, K. S. C. Linares, E. W. G. Clua, and É. O. Rodrigues, "A novel procedural generation for level design of mansions and dungeons," arXiv:2606.03857, Jun. 2026. (A gamedev.net write-up says the paper is from SBGames 2025; not verified, "?".)
- **What it does:** BSP partition, then room links via graph traversal, then post-processing. BFS connectivity is checked on 100k seeded maps.
- **How PGT differs:** It is a single fixed pipeline. PGT makes these stages stackable and adds graph metrics.

[30] H. Tremblay, Y. Francillette, and B. Bouchard, "Analysis of difficulty gradients of player path variants: An evaluation tool to support level design," in *Proc. IEEE GEM*, 2026. doi: 10.1109/GEM72276.2026.11746952.
- **What it does:** Spatial difficulty and accessibility fields along path variants in platformer levels.
- **How PGT differs:** It is analysis only. It could be compared with PGT's flow and betweenness views.

[31] Z. Jiang, S. Earle, A. Khalifa, and J. Togelius, "Agentic PCG: Procedural content generation via tool-using LLMs," Zenodo preprint, Mar. 31 2026. doi: 10.5281/zenodo.19355469.
- **What it does:** An LLM agent iteratively calls PCG tools, evaluates the result with metrics and edits levels (Maze, Lode Runner, Zelda, Sokoban).
- **How PGT differs:** It is a natural future integration point: an LLM could drive PGT's modifier stack. PGT itself has no LLM.
- **Note:** This item is from before 2026-06, but it is missing from the survey.

---

### 2. Integrated PCG workbenches, frameworks, research platforms, tools

[32] N. Romero, F. Besoaín, C. Aliaga, N. Acevedo, A. Díaz, *et al.*, "The Level Building Sidekick mixed-initiative tool for game research in Unity: A tutorial," in *Proc. FDG*, 2026. doi: 10.1145/3815598.3815711.
- **What it does:** Repositions LBS as a reusable research platform with four modules: physical space (WFC, hill climbing), population (MAP-Elites), quests (grammars) and semi-automatic testing (A*).
- **How PGT differs:** LBS is grid- and Unity-based. It has no explicit graph pipeline, graph-metrics dashboard or parameter-sweep CSV.
- **Note:** The survey only cites the 2023 LBS paper. Cite this 2026 framing as well, because it is the closest research-platform framing to PGT's. ⚑

[33] S. Ferrada, S. Bravo, H. Schaa, and N. A. Barriga, "Evaluating the Level Building Sidekick mixed-initiative procedural content generation Unity package: Two case studies," in *Proc. 44th Int. Conf. Chilean Comput. Sci. Soc. (SCCC)*, 2025. doi: 10.1109/SCCC67219.2025.11420485.
- **What it does:** Case-study evaluation of LBS.
- **How PGT differs:** This is evaluation evidence for the comparator, not a new tool.

[34] R. M. de Oliveira and E. S. de Matos, "Omnigenesys: A universal framework for procedural map generation in digital games," in *Anais Estendidos do SBGames*, 2026. doi: 10.5753/sbgames_estendido.2026.25726.
- **What it does:** An engine-agnostic, modular map-generation core written in Go. It is seeded and deterministic, exports JSON and ships adapters for Unity and Unreal.
- **How PGT differs:** It does not mention a graph editor, metrics, agents or experiments, and its evaluation is listed as future work.
- **Note:** It is close to PGT's export and determinism story. ⚑ (weak)

[35] T. Y. Teoi, L. T. Pereira, and C. F. M. Toledo, "Towards requirements for mixed-initiative content orchestration tools for game development," in *Proc. SBGames*, 2026. doi: 10.5753/sbgames.2026.26432.
- **What it does:** Elicits requirements for tools that orchestrate several generators together.
- **How PGT differs:** It is useful for positioning PGT as an orchestration workbench.

[36] T. Y. Teoi, L. T. Pereira, and C. F. M. Toledo, "Adapting a content orchestrator across game genres: From top-down adventure to 2D platformer," *Entertain. Comput.*, vol. 58, Art. 101148, 2026. doi: 10.1016/j.entcom.2026.101148.
- **What it does:** Ports a content orchestrator across genres (abstract not retrieved, "?").
- **How PGT differs:** Orchestration across content types, compared with PGT's single graph-to-tilemap pipeline.

[37] M. Mazzotti Silvestrini, P. H. Salmaze, and L. Tortoro Pereira, "Mesa De Bar: An open, configurable platform for human–AI co-creation, with a multi-agent simulation study of creative homogenization," in *Proc. AIIDE*, vol. 22, 2026, pp. 300–310. doi: 10.1609/aiide.v22i1.43588.
- **What it does:** An open, file-configured platform that can run with human players or simulated agents, with parameter sweeps.
- **How PGT differs:** It concerns ideation, not levels. It is an analogous "platform + agent simulation + sweeps" research design.

[38] H. Noteboom, K. Nair, and S. Cooper, "Procedural level generation via program inversion," in *CEUR Workshop Proc.*, vol. 4090, 2025, short4. URL: https://ceur-ws.org/Vol-4090/short4.pdf
- **What it does:** Inverts a game's rewrite-rule program to generate solvable start levels.
- **How PGT differs:** It is a pre-2026 gap. It relates to PGT's grammar modifier and solver.

**Tools and repositories** (GitHub metadata checked 2026-11-19):

[39] Dragonboon, *Atrium* (Godot 4 addon), MIT, 89★, pushed 2026-10-30. https://github.com/Dragonboon/Atrium
- **What it does:** An editor-first Godot tool for rooms and dungeons. It has seeded critical-path and tree layouts with optional loops, multi-floor buildings, routed corridors, persistent locks on edits, socket validation and native scene export.
- **How PGT differs:** Atrium is 3D blockout with no explicit graph model, graph metrics, agents, lock-and-key solver or sweeps.
- **Note:** It is the closest Godot competitor after Edgar.Godot. ⚑

[40] yabadabu, *godot_flow* ("Flow Graph", a PCG node editor for Godot 4.7, inspired by Unreal's PCG framework), Apache-2.0, 32★, pushed 2026-10-21. https://github.com/yabadabu/godot_flow
- **What it does:** Point-set dataflow with 75+ nodes, grammar-along-spline, clustering, Watabou dungeon importers and a data inspector.
- **How PGT differs:** Like Gaea, it is a dataflow graph of operations rather than level topology.

[41] B. Py (BenPyton), *ProceduralDungeon* (Unreal Engine 4/5 plugin), 845★, pushed 2026-11-16, plus *DungeonRules*, a state-machine graph extension. https://github.com/BenPyton/ProceduralDungeon
- **What it does:** Room-prefab dungeon generation, with the companion plugin adding rule graphs.
- **How PGT differs:** It is a game-production plugin with no research or analysis layer.

[42] shun126, *DungeonGenerator* (Unreal Engine 5), GPL-3.0, 156★, pushed 2026-09-05. https://github.com/shun126/DungeonGenerator
- **What it does:** 3D dungeons, minimaps and "missions".
- **How PGT differs:** It is a production plugin.

[43] KoBeWi, *Metroidvania-System (MetSys)* (Godot), MIT, ~1.6k★, pushed 2026-10-23. https://github.com/KoBeWi/Metroidvania-System
- **What it does:** A Godot framework for metroidvania maps and room linking. A third-party generator exists (arunsrajan/godot-metroidvania-map-generator, 2026).
- **How PGT differs:** It is an authoring framework without procedural graph pipelines.

[44] OrganicaWild, *OrganicaWild* (Unity PCG framework with graph grammars), MIT, 75★, last pushed 2022. https://github.com/OrganicaWild/OrganicaWild
- **What it does:** A framework for organic worlds driven by graph grammars.
- **How PGT differs:** It is inactive and has no analysis or agents.

[45] Small 2026 repositories, worth a footnote only:
- *Kabyik-Kayal/dungeon-repair*: playability verification and intent-preserving repair of lock-and-key dungeons with solver plus agent (MIT, 2026-08).
- *mykaadev/NsDungeons*: cyclic lock-and-key grid generation for Unreal (MIT, 2026-10).
- *StevenClontz/key-lock-graphs*: formal "dungeon graph" solvability, with a web editor (MIT, 2025).

---

### 3. Graph → tilemap / graph realization / mission → space

[46] K. Xu and C. Verbrugge, "From experience to 3D platformer levels via topological graphs," in *Proc. AIIDE*, vol. 22, 2026, pp. 434–443. doi: 10.1609/aiide.v22i1.43601.
- **What it does:** The Experience Topological Graph (ETG) encodes progression order, branching and gating. A pipeline realizes the ETG as a level through incremental construction and a **local topological validator** that blocks unintended shortcuts. It is benchmarked against constructive, lane-based, evolutionary and CP baselines.
- **How PGT differs:** The ETG work is a single realization algorithm for 3D platformers. PGT is a 2D workbench with an editor, modifier stack, metrics, agents and sweeps.
- **Note:** This is the strongest 2026 mission→space paper and belongs next to closest-prior-art rows 1 and 4. ⚑

[47] A. Z. Fahreza, C. A. Putra, and Y. V. Via, "Procedural level generation for 2D platformer games based on graph and chunk," *J. Comput. Sci. Technol. (JOCSTEC)*, vol. 4, no. 3, 2026. doi: 10.59435/jocstec.v4i3.828.
- **What it does:** Maps graph nodes to chunks, arranges them by topology and validates reachability with a path-finding agent.
- **How PGT differs:** It is qualitative and descriptive with a fixed mapping. PGT realizes rooms through allocation and corridor routing.

[48] B. van Eden and N. Botha, "Constraint-guided hybrid procedural dungeon generation using CNN-based semantic refinement," in *Proc. SAIMC-INSPIRE*, 2026. doi: 10.1109/SAIMC-INSPIRE70184.2026.11772774.
- **What it does:** A constructive room-and-corridor stage, then a CNN that places doors, enemies and treasure, with solvability and connectivity checks.
- **How PGT differs:** It is a two-stage fixed pipeline with no graph model.

[49] R. D. M. dos Santos, R. C. Contreras, G. B. Guimarães, M. S. Viana, and R. C. Guido, "Controlling energy-propagation-based dungeon generation using genetic algorithms," in *Anais Estendidos do SBGames*, 2026. doi: 10.5753/sbgames_estendido.2026.25589.
- **What it does:** A GA steers a high-entropy room-graph generator.
- **How PGT differs:** It is parameter search over one generator, which PGT's batch sweeps could reproduce.

[50] M. V. P. Dias, A. de O. da R. Franco, J. W. F. da Silva, and J. G. R. Maia, "Procedural map generation by energy propagation," in *Proc. SBGames*, 2025. doi: 10.5753/sbgames.2025.10173.
- **What it does:** A linear-time room-graph generator whose output ranges from trees to grids.
- **How PGT differs:** It is a pre-2026 gap and a candidate to add as a PGT generator.

[51] G. G. Medeiros and C. B. de Oliveira, "Map generation for roguelike games from textual descriptions using large language models," in *Proc. SBGames*, 2026. doi: 10.5753/sbgames.2026.25721.
- **What it does:** Text-to-roguelike-map generation with structural checks.
- **How PGT differs:** It is LLM-based with no graph stage.

[52] J. M. Yap, N. C. Woo, B.-S. Tan, and K. S. Chong, "From algorithm to playable space: A technical note on BSP-based dungeon design," *Int. J. Creative Multimedia*, 2025. URL: https://journals.mmupress.com/index.php/ijcm/article/download/2470/1127 (DOI "?").
- **What it does:** A Unity BSP generator with DFS corridors.
- **How PGT differs:** It is a minor gap, a single generator.

---

### 4. Agent-based generation + simulation in one tool

No 2026 paper found combines **agent-driven generation (builder or painter agents) with agent simulation and analysis in one tool**, which is PGT's walker subsystem. The nearest items:

- **Majercik et al. [23]:** a simulator, solver agents and procedural obstacle generation in one design tool (3D, solvability focus).
- **Agentic PCG [31]:** an LLM agent that generates and evaluates by calling tools.
- **Mesa De Bar [37]:** a platform that switches between human and simulated agents, with sweeps (non-spatial).
- **Path2Patrol [7]:** agent routes generated over levels.
- **Fahreza et al. [47]:** a path-finding agent as reachability validator.
- **Kabyik-Kayal/dungeon-repair [45]:** solver plus agent repair of lock-and-key dungeons. It is a repository, not a paper.

Also seen, but only as a talk and not citable as a paper: E. Fredericks, "Every map an evolution, every room a generation: Co-evolution in a procedurally-generated video game," GPTP 2026 talk (slides only; GP-managed map and entity generation). https://gpbib.pmacs.upenn.edu/gp-html/Fredericks_2026_GPTP.html

---

### Flags against the "closest prior art" table

None of these displaces Edgar, Ludoscope or Sturgeon-MKIV as the closest overall match. Recommended additions:

1. **Xu & Verbrugge, AIIDE 2026 [46] (ETG).** Add as a new row near #1 and #4. It is graph→level realization with an in-loop topological validator, the closest 2026 match to PGT's graph→raster plus solver chain. It differs in being one algorithm, 3D platformer only, with no workbench.
2. **Atrium [39].** Add next to Edgar.Godot in row #1. It is a Godot 4 editor-first procedural dungeon tool with persistent edit locks and validation, the closest Godot packaging. It differs in being 3D blockout, with no graph model, metrics, agents or experiments.
3. **LBS FDG 2026 tutorial [32].** Update the LBS citation. Its explicit "research platform for PCG and HCI studies" framing overlaps PGT's positioning as a research workbench.
4. **Brazell & Robertson, CoG 2026 [2].** Not a table row, but cite it in novelty (a) as a runtime generation-plus-control system that adapts parameters, not topology.
5. **Omnigenesys [34].** A weak flag: an engine-agnostic modular framework with deterministic JSON export, but no published evaluation.

Gaps I could not close:
- EXAG 2026 and the PCG Workshop 2026 accepted lists were not retrievable.
- CHI PLAY 2026 proceedings were not swept.
- The CoG 2026 sweep was keyword-based (via Crossref), not exhaustive. The AIIDE 2026 sweep was exhaustive over the DOIs Crossref has.

---

## Theme G — Example-based motif mining → graph grammar (Pattern Extractor) (2026-11-19)

Scope: papers similar to PGT's new feature (`graph_pattern_extractor.gd`, `pattern_extractor_popup.gd`,
`trans_mutate_grow_patterns.gd` on `main`). Searched: Zotero library (nothing relevant beyond
surveys/textbook chapters already cited), Semantic Scholar, arXiv, web. Searched 2026-11-19.

### What the feature actually does (from the code)

- **Extraction:** For every node, it runs a bounded-depth BFS (radius `depth`), takes the induced subgraph and computes a signature:
  - *Topological:* the sorted degree sequence of the induced subgraph plus the edge count. Optionally it adds a multiset of pairwise node distances quantized to the grid, which is rotation/reflection invariant. **This is not a true canonical form.** Non-isomorphic neighbourhoods with the same degree sequence collide.
  - *Semantic:* the seed type plus the sorted multiset of the types of its direct neighbours. This is a **star / radius-1 signature regardless of `depth`**, the same idea as a WFC adjacency rule or one Weisfeiler–Lehman iteration.
- **Tally:** It counts occurrences per signature and keeps one exemplar mini-graph per signature, re-centred on its centroid. The results are sorted by frequency and shown as cards.
- **Generation (`MutateGrowPatterns`):** It picks a pattern at random, weighted by its weight, and picks a random perimeter anchor (DLA-like). It then stamps a rotated copy attached at the anchor, with planarity and spacing rejection.
  - This step has **no LHS/RHS context matching**. It is attach-only "motif stamping", not a rewriting grammar in the Dormans/Subdue sense.
  - The separate `MutateGrammar` modifier does LHS subgraph matching, but it uses hand-authored rules from `GraphSettings.grammar_rules`.

### Already in `Documentation/RelatedWork.md` (not re-reported)

These are directly relevant and already listed:
- Merrell 2023 (TOG, example-based graph grammars)
- Cooper 2023, Sturgeon-GRAPH (learns local labeled neighbourhood patterns from example graphs)
- Cooper & Balema 2023 (learned constrained graph layout)
- Cooper & Bazzaz 2024/2025 (graph label rewrite rules)
- Madkour et al. 2021/2022 (example-guided graph grammars)
- Summerville et al. 2015, "The learning of Zelda"; Summerville & Mateas, "Sampling Hyrule"
- VGLC
- Kim et al. 2019 (graph-based WFC, CoG)
- Eger 2026 (growing graph WFC)
- Baldwin et al. 2017 (pattern-based dungeon generation)
- Snodgrass & Ontañón (MdMC); Karth & Smith (WFC)
- Gutierrez & Schrum 2020; Rupp & Eckert (G-PCGRL); Alvarez et al. (design style clustering)
- Merrell & Manocha (model synthesis)

---

### A. Graph grammar induction from example *game levels* (closest)

[1] S. Londoño and O. Missura, "Graph grammars for Super Mario Bros levels," in *Proc. 6th Workshop on Procedural Content Generation (PCG) @ FDG*, Pacific Grove, CA, USA, 2015. DOI: ? URL: https://pcgworkshop.com/archive/londoño2015grammars.pdf
- *What:* It represents SMB levels as graphs and extends SubdueGL (MDL-driven frequent-substructure compression) to learn a **stochastic graph grammar from example levels**, then generates new level graphs from it.
- *PGT differs:* PGT counts radius-bounded BFS neighbourhoods with a hashed signature instead of MDL substructure discovery. It produces flat attach-only motifs, not a hierarchical, recursive grammar. PGT adds designer curation (cards, weights) and works on dungeon/room graphs rather than platformer tiles.
- *Note:* This is the single closest prior art for "mine recurring subgraphs from an example level and use them as grammar productions".

[2] E. Hauck and C. Aranha, "Automatic generation of Super Mario levels via graph grammars," in *Proc. IEEE Conf. Games (CoG)*, 2020, pp. 297–304. DOI: 10.1109/CoG47356.2020.9231526
- *What:* It builds a reachability graph of SMB levels, **automatically detects level structures**, and turns them into graph-grammar productions. A designer can add or remove structures.
- *PGT differs:* Hauck & Aranha's structure detection is tailored to the SMB tile grid. PGT's extraction is domain-agnostic over arbitrary attributed graphs, with optional geometry.

[3] M. K. Oguz and A. Dockhorn, "Markov Senior — Learning Markov Junior grammars to generate user-specified content," in *Proc. IEEE CoG*, 2024, pp. 1–8. DOI: 10.1109/CoG60054.2024.10645650
- *What:* It uses genetic programming to learn probabilistic rewrite-rule sets (MarkovJunior grammars) from a **single example**, with KL-divergence fitness on extracted positional and distance relations. It is tested on SMB and images.
- *PGT differs:* Markov Senior works on grids and *searches* rule sets against a pattern-distribution objective. PGT works on graphs and directly *extracts* rules by frequency, with no optimisation loop or fidelity objective.

[4] G. Hermans, T. Winters, and L. De Raedt, "Shape inference and grammar induction for example-based procedural generation," in *Proc. Int. Conf. Computational Creativity (ICCC)*, 2021. arXiv:2109.10217. DOI: 10.48550/arXiv.2109.10217
- *What:* SIGI infers shapes and **induces a shape grammar** from grid-based 3D Minecraft building examples, aimed at co-creative design.
- *PGT differs:* SIGI targets voxel shape grammars for buildings. PGT targets topological and semantic graph motifs for level graphs.

### B. Frequent-subgraph mining → graph grammar inference (general CS; the algorithmic ancestors)

[5] I. Jonyer, L. B. Holder, and D. J. Cook, "MDL-based context-free graph grammar induction and applications," *Int. J. Artif. Intell. Tools*, vol. 13, no. 1, pp. 65–79, 2004. DOI: 10.1142/S0218213004001429
- *What:* SubdueGL repeatedly finds the substructure that best compresses the graph (MDL), replaces it with a nonterminal, and handles recursion. It infers context-free graph grammars.
- *PGT differs:* PGT uses a frequency count only (no compression criterion), does no replacement/abstraction pass, and produces no recursive rules.

[6] J. P. Kukluk, L. B. Holder, and D. J. Cook, "Inference of node replacement graph grammars," *Intelligent Data Analysis*, vol. 11, no. 4, pp. 377–400, 2007. DOI: 10.3233/IDA-2007-11405
- *What:* It mines frequent subgraphs and **detects overlap between instances** to infer node-replacement productions, including recursive ones. It evaluates by recovering known grammars.
- *PGT differs:* PGT ignores how motif instances overlap or connect. That connection information is exactly what would turn PGT's motifs into productions with embedding rules, rather than free-floating stamps.

[7] S. Aguiñaga, D. Chiang, and T. Weninger, "Learning hyperedge replacement grammars for graph generation," *IEEE Trans. Pattern Anal. Mach. Intell.*, vol. 41, no. 3, pp. 625–638, 2019. DOI: ? (arXiv: 10.48550/arXiv.1802.08068)
- *What:* It extracts a hyperedge replacement grammar (HRG) from a graph's clique-tree decomposition. It then generates new graphs of a target size that preserve local substructures and global statistics.
- *PGT differs:* HRG productions carry formal boundary (attachment) semantics and come with size control. PGT has neither, but PGT is interactive and can use geometry.

[8] M. Guo, V. Thost, B. Li, P. Das, J. Chen, and W. Matusik, "Data-efficient graph grammar learning for molecular generation," in *Proc. ICLR*, 2022. arXiv:2203.08031
- *What:* It learns graph-grammar production rules automatically from about 20 example graphs and optimises the grammar for domain metrics.
- *PGT differs:* This is the same "few examples → grammar" premise in chemistry. PGT has no learned rule-selection objective.

[9] X. Yan and J. Han, "gSpan: Graph-based substructure pattern mining," in *Proc. IEEE ICDM*, 2002. DOI: ?
- *What:* This is the canonical frequent-subgraph miner. It uses minimum DFS codes as a true canonical form.
- *PGT differs:* PGT's degree-sequence hash is not canonical. A DFS-code, nauty or WL hash would remove signature collisions.

[10] R. Milo, S. Shen-Orr, S. Itzkovitz, N. Kashtan, D. Chklovskii, and U. Alon, "Network motifs: Simple building blocks of complex networks," *Science*, vol. 298, no. 5594, pp. 824–827, 2002. DOI: 10.1126/science.298.5594.824
- *What:* It defines motifs as subgraphs over-represented relative to randomized null models.
- *PGT differs:* PGT ranks by raw frequency, with no null model. Frequent ≠ characteristic: degree-2 corridor chains will dominate any dungeon.

[11] N. Shervashidze, P. Schweitzer, E. J. van Leeuwen, K. Mehlhorn, and K. M. Borgwardt, "Weisfeiler–Lehman graph kernels," *J. Mach. Learn. Res.*, vol. 12, pp. 2539–2561, 2011.
- *What:* WL relabeling hashes rooted labeled neighbourhoods of increasing radius into compact signatures.
- *PGT differs:* PGT's semantic signature is effectively one WL iteration (seed label + sorted neighbour labels). Citing WL justifies the design, and iterating it would make `depth` meaningful in semantic mode.

### C. Example-based procedural modeling with graphs / grammars (graphics, architecture, urban)

[12] D. G. Aliaga, C. A. Vanegas, and B. Beneš, "Interactive example-based urban layout synthesis," *ACM Trans. Graph.*, vol. 27, no. 5 (Proc. SIGGRAPH Asia), 2008. DOI: 10.1145/1457515.1409113
- *What:* It extracts local structure from example road networks (intersections and streets as a graph with attributes) and synthesizes new layouts that are locally similar to the example.
- *PGT differs:* Same "local neighbourhood statistics of an example graph → grow new graph" idea in the urban domain. PGT targets abstract level graphs and adds semantic labels.

[13] G. Nishida, I. Garcia-Dorado, and D. G. Aliaga, "Example-driven procedural urban roads," *Comput. Graph. Forum*, vol. 35, no. 6, pp. 5–17, 2016. DOI: 10.1111/cgf.12728
- *What:* It extracts road "patches" (local subgraphs) from real road networks and **grows** a new network by attaching patches at frontier vertices, combined with procedural growth.
- *PGT differs:* This is algorithmically the closest generation step to `MutateGrowPatterns`: patch extraction plus attach-at-frontier growth. PGT applies it to level graphs and ranks patches by frequency.

[14] J. O. Talton, L. Yang, R. Kumar, M. Lim, N. D. Goodman, and R. Měch, "Learning design patterns with Bayesian grammar induction," in *Proc. ACM UIST*, 2012. DOI: 10.1145/2380116.2380127
- *What:* It induces a probabilistic grammar from labeled hierarchical exemplars (Bayesian model merging) and samples new designs.
- *PGT differs:* Talton et al. work on hierarchical (tree) designs and give a principled probabilistic induction. PGT is a non-probabilistic, flat motif frequency count over general graphs.

[15] M. Bokeloh, M. Wand, and H.-P. Seidel, "A connection between partial symmetry and inverse procedural modeling," *ACM Trans. Graph.*, vol. 29, no. 4, 2010. DOI: ?
- *What:* It detects partial symmetries (repeated docking sites) in an example and derives a shape grammar that generates variations.
- *PGT differs:* Bokeloh et al. work on 3D geometry. PGT's "repeated neighbourhood → rule" is the graph analogue but has no docking/boundary formalism.

[16] P. Merrell, "Technical companion to Example-based procedural modeling using graph grammars," arXiv:2309.00275, 2023.
- *What:* This gives theoretical and implementation details for Merrell's TOG 2023 method (the main paper is already listed).
- *PGT differs:* Cite it only if you need detail on Merrell's primitive decomposition when contrasting it with PGT's BFS motifs.

### D. Graph-based WFC (local-adjacency learning on graphs)

[17] H. Kim, T. Hahn, S. Kim, and S. Kang, "Graph based wave function collapse algorithm for procedural content generation in games," *IEICE Trans. Inf. Syst.*, vol. E103.D, no. 8, 2020. DOI: 10.1587/transinf.2019EDP7295 (volume/issue ?)
- *What:* This is the journal version of Kim et al.'s CoG 2019 graph-WFC: association rules over nodes of a navmesh graph.
- *PGT differs:* Graph WFC *fills labels on a fixed graph*. PGT *grows topology* from mined motifs.

[18] H. Kim, B. Seo, and S. Kang, "Puzzle-level generation with simple-tiled and graph-based wave function collapse algorithms," *IEEE Trans. Games*, 2025. DOI: 10.1109/TG.2024.3368017 (vol./pages ?)
- *What:* It applies graph-based WFC and simple-tiled WFC to Strimko and Flow puzzles.
- *PGT differs:* Same distinction: label assignment on given graph structure versus topology growth.

### E. Pattern / n-gram / local-pattern learning from example levels (non-graph analogues)

[19] S. Dahlskog, J. Togelius, and M. J. Nelson, "Linear levels through n-grams," in *Proc. 18th Int. Academic MindTrek Conf.*, 2014. DOI: ? URL: http://www.kmjn.org/publications/NgramLevels_MT14.pdf
- *What:* It mines n-gram frequencies of vertical slices from SMB levels and samples new levels.
- *PGT differs:* This is the 1-D sequence analogue of PGT's frequency-weighted motif sampling. PGT generalises it to graph neighbourhoods but drops conditional (n−1 context) probabilities, so PGT is closer to a unigram-of-motifs model.

[20] V. Volz *et al.*, "Capturing local and global patterns in procedural content generation via machine learning," in *Proc. IEEE CoG*, 2020, pp. 399–406. DOI: 10.1109/CoG47356.2020.9231944
- *What:* It shows that local-neighbourhood models (MRF, GAN) miss global patterns such as symmetry, and augments neighbourhoods with symmetric positional information.
- *PGT differs:* This is relevant as a *limitation* reference. Purely local motif stamping (PGT) will not reproduce global structure (cycles, lock-key ordering, start→boss flow) unless constrained.

[21] M. Etheredge, "Fast exact graph matching using adjacency matrices," in *Proc. 3rd Workshop on PCG @ FDG*, 2012, pp. 10:1–10:6. DOI: 10.1145/2538528.2538536
- *What:* It gives fast exact subgraph search for graph-rewrite-based track generation (DroidRacers).
- *PGT differs:* This is relevant to `MutateGrammar`'s LHS matching, not to mining.

### F. GNN / deep graph-generative models for *game* level graphs

No peer-reviewed work was found that trains a GNN or graph-generative model (GraphRNN, graph VAE, graph diffusion) on game level/dungeon graphs, as of this search. The closest are:
- floorplan graph models (already listed: House-GAN, Graph2Plan, HouseDiffusion);
- G-PCGRL (already listed).

This gap is a possible future comparison baseline, not prior art against PGT.

---

### Closest works (ranked)

1. **Londoño & Missura 2015 [1]:** learns graph-grammar productions from recurring substructures in example *game levels* (SubdueGL). This is conceptually the same pipeline.
2. **Cooper 2023, Sturgeon-GRAPH (already in RelatedWork.md):** learns local labeled-neighbourhood patterns from example graphs (including Zelda dungeon graphs) and generates new graphs of varying structure that are locally similar. It is the closest in purpose and domain, and it adds constraint solving.
3. **Merrell 2023 (already listed):** example → graph-grammar primitives → generation. It is more principled (locally similar guarantee) but targets geometric shapes.
4. **Nishida et al. 2016 [13] / Aliaga et al. 2008 [12]:** extract local patches from an example graph and grow by attaching at the frontier. This is nearly identical to `MutateGrowPatterns`, in the urban domain.
5. **Kukluk et al. 2007 [6] / Jonyer et al. 2004 [5]:** the formal frequent-subgraph → graph-grammar induction that PGT approximates.

### Novelty verdict (candid)

- **The core algorithm is not novel.** Mining recurring local neighbourhoods from an example graph and reusing them as generative rules is established:
  - Subdue/SubdueGL grammar induction (2004–2007);
  - applied to game levels by Londoño & Missura (2015);
  - locally-similar graph generation from examples (Sturgeon-GRAPH 2023, Merrell 2023);
  - the "extract patches → grow at frontier" generation step (Nishida et al. 2016).
- **The feature is technically weaker than these baselines in three ways a reviewer will spot:**
  - The topological signature (degree sequence + |E|) is **not a canonical form**, so non-isomorphic motifs merge. Use WL hashing, nauty or gSpan DFS codes.
  - The semantic signature ignores `depth` beyond radius 1.
  - Generation is **attach-only stamping with no LHS context or embedding rules**, so calling it "grammar inference" overstates it. It is closer to a unigram motif sampler. Frequency is also used without a null model (cf. Milo et al.), so trivial corridor motifs dominate.
- **What is defensibly new is the integration and interaction, not the algorithm:**
  - a designer-facing, mixed-initiative curation loop (motif cards; toggling and weighting motifs);
  - a rotation-invariant geometric signature option;
  - composition with PGT's other modifiers in a Godot pipeline.

  None of the closest works offer this specific interactive workflow in an engine-integrated tool.
- **Recommended framing:** "example-driven, designer-curated motif extraction as a modifier in a graph PCG toolchain". Present it as a tool contribution, cite [1], [5]/[6], Sturgeon-GRAPH, Merrell 2023 and [13] as the algorithmic lineage, and fix the canonical signature before publishing.
- **Evaluation that would make it publishable (FDG/CoG short or EXAG/PCG workshop):** run on VGLC Zelda dungeon graphs and compare motif-distribution fidelity (e.g., KL over WL-subtree histograms) and expressive range against Sturgeon-GRAPH and a SubdueGL-style baseline.
