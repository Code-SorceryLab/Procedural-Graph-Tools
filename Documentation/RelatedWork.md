# Related Work: Tools and Papers Similar to Procedural Graph Tools (PGT)

*Literature and tool scan, compiled 2026-10-22. Sources: Semantic Scholar, arXiv, Crossref, GitHub, publisher pages, and the Zotero library. Entries come with a DOI or URL. Fields that could not be confirmed are marked "?". Items already in Zotero are tagged [Zotero].*

The scan is split into four themes, and some papers appear in more than one (e.g., Dormans 2010, Smith et al. 2018, Sturgeon). Deduplicate them when you build the .bib file.

| Theme | Entries |
|---|---|
| A. Graph grammars, mission/space, lock-and-key, constraint-based solvability | 80 papers + 7 repos |
| B. Graph→layout, rasterization, CA, WFC, plus a tool survey | 65 papers + 31 tools |
| C. Online/dynamic PCG, partial regeneration, agent-based PCG and validators | 50 papers + ludography |
| D. Mixed-initiative tools, PCG pipelines, level analysis/metrics, surveys, LLM-based generation | 77 papers |

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

Reproducibility citations: Withington, Cook & Tokarchuk, FDG 2024, 10.1145/3649921.3650016; Khalifa et al., "PCG Benchmark," FDG 2025, 10.1145/3723498.3723794.

### Novelty assessment

- **(a) Trigger-based partial regeneration at runtime, preserving surrounding topology.**
  - No work found does this on a live level.
  - Online PCG (Polymorph, infinite caves, EDRL, Momentum) only appends content ahead of the player.
  - Partial regeneration and repair (Tanagra pinning, Sturgeon infill, level repair, inpainting) happens offline at design time.
  - Runtime "impossible spaces" in VR and games like *P.T.* or *Layers of Fear* are scripted or perceptual and have no generation pipeline.
  - Closest conceptually: Dormans & Bakkes 2011; Lopes, Eisemann & Bidarra 2018.
- **(b) Temporally aware lock-and-key progression.**
  - All lock-and-key feasibility work found (Dormans, ASP, randomizers, Sturgeon) guarantees solvability once, from the start state.
  - No work found re-plans keys after a mid-play change or uses trigger-gated key placement.
- **(c) Persistent validator agent that survives regenerations.**
  - Only Momentum (Kar 2026) validates at runtime, and it is stateless and append-only.
  - No incremental validator found that keeps state (inventory, explored set) across content mutations.
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

