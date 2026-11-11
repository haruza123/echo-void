# ECHO//VOID — Product Requirements Document (PRD)

**Version:** 1.0 (design baseline, not yet implemented)  
**Platform:** Roblox, PC-first, mobile-compatible target  
**Genre:** Co-op sound-based extraction horror  
**Players:** 1–4  
**Implementation language:** Luau / Roblox Studio  
**Primary implementers:** Claude Code or Google Antigravity  
**Status:** Approved core decisions; numeric tuning provisional.

## 1. Product vision
Players are effectively blind in a dangerous procedural facility. Audible events create temporary visible outline/wireframe echoes. Teams retrieve valuables, meet recurring company quotas, earn currency, equip gear, and escape. Making noise reveals the world but may expose the team to monsters.

**Unique selling proposition:** The same sound event powers information, teamwork, and enemy perception. It is not merely a darkness filter.

## 2. Approved decisions and defaults
### User-approved
- No normal vision. Previously revealed echoes fade slowly.
- Footsteps, manual sonar, and environmental sounds create echoes.
- Most monsters rely on sound; others have specialized detection/behavior.
- High-variation procedural maps.
- Downed players can be revived.
- Quotas + currency + equipment progression.
- Outline/wireframe aesthetic.

### Proposed defaults pending playtesting, not user-approved mandates
- 1–4 players; first-person; 8–12 minute expedition; PC-first, mobile controls included later.
- Sound events shared among players; rendering and occlusion individual per client.
- Modular procedural room assembly, not unconstrained random terrain or a static map.
- Central extraction point close to initial spawn; optionally alternate exits in later release.
- One initial biome (industrial facility), more themes later.

## 3. Design pillars
1. **Sound is sight and danger:** every revealing action must have readable consequences.
2. **Uncertainty with agency:** blind but not helpless; players should reliably regain orientation.
3. **Cooperative tension:** sound sharing, rescues, carrying loot, and extraction decisions create teamwork.
4. **Replayable with rules:** procedural maps varied but navigable and fair.
5. **Fair monster behavior:** no omniscient enemy tracking. Debuggable hearing and last-known-position AI.

## 4. Core game loop
1. In lobby, equip purchased tools, see quota/deadline, select expedition difficulty (where unlocked).
2. Server generates a validated map using a seed and places loot, hazards, monsters, and extraction.
3. Players navigate using passive footsteps, manual sonar, and world sounds.
4. Acquire items; choose to push deeper or retreat; help downed teammates.
5. Extract before timer expiration. Only extracted items count as sold value; anti-loss rules defined below.
6. Calculate credits, fulfill quota, update persistent unlocks, present results.
7. If quota deadline arrives, apply loss/recovery consequence, avoiding permanent economic softlock.

## 5. Echo mechanics
### 5.1 SoundEvent contract
Every authoritative world sound creates a unified sound event:
`{ eventId, sourceType, worldPosition, startedAtServer, revealRadius, soundStrength, propagationSpeed, duration, materialProfile, actorId? }`.
- Server validates gameplay events, positions, cooldowns, and strengths.
- Client renders the temporary echo for sound events in its relevancy range.
- Monster manager consumes validated events independently of visual rendering.
- No transmission of per-edge/per-vertex visuals over networking.
- Event timing reconciles with server time for multiplayer.

### 5.2 Initial tunable values (NOT final)
| Source | Visual radius (studs) | Fade (s) | AI strength (arbitrary) | Trigger |
|---|---:|---:|---:|---|
| Crouch step | 4 | 0.8 | 3 | Footstep cadence |
| Walk step | 10 | 1.4 | 12 | Footstep cadence |
| Run step | 15 | 1.1 | 32 | Footstep cadence |
| Manual Q ping | 38 | 2.7 | 65 | 3 s cooldown |
| Dropped item | 12–25 | 1.5 | 20–55 | Material/weight |
| Environmental machine | 20–50 | 1–3 | 40–90 | Scheduled/event-driven |

These are separate **reveal radius** and **AI hearing strength** quantities. AI effective hearing depends on distance, obstacles, monster sensitivity, and possible environmental masking. Do not equate radius with hearing range.

### 5.3 Rendering requirements
- Baseline game geometry is not normally visible; physical collision remains active.
- Echo radius expands over time. A visible wireframe segment is revealed when the wave reaches it AND an occlusion test allows it.
- Per-segment fade follows configurable curve; repeat ping refreshes visibility, not duplicate infinite line instances.
- Draw only authored edge metadata / generated wireframe for map modules; do not generate unrestricted edge geometry from every decorative MeshPart.
- Solid walls occlude. Doors change occlusion when opened. Optional limited diffraction is post-MVP.
- Color codes: cyan level structures, white interactions, amber valuables, red threats. Accessibility presets must not rely on color alone.
- Screen overlay black alone is insufficient if normal geometry leaks through; verify visual privacy in actual clients.
- Ensure crosshair, menu, extraction guidance and accessibility prompts remain visible even when echo expires.
- Reusable pooled line/Beam/Adornment render components; quality presets for PC and mobile.

### 5.4 Shared echoes
All players near an audible event can potentially receive its echo. Individual visibility depends on player-local available/streamed geometry, occlusion, and settings. A player can reveal terrain by throwing a stone, and nearby friends can benefit. Some unique gear may have private readouts later but does not redefine core physical echoes.

### 5.5 Surface and event audio
Distinct footfall profiles (metal, concrete, water), brief sonar pulse, distant mechanical ambience and directional enemy sounds. Maintain gameplay signals even on low-end speakers; add optional visual directional indicators that do not trivialize threat detection. If voice chat is used, game must remain fully playable without it.

## 6. Procedural generation
### 6.1 Algorithm
Use deterministic seeded **modular room graph** generation followed by spatial placement. At each generation:
1. Generate a connected logical graph with spawn, corridors, branches, a few loops, loot regions, danger areas, and extraction.
2. Choose compatible room templates from catalog based on required connector count and biome.
3. Place modules on a snap/grid system with defined door sockets and orientation. Check non-overlap and clearance.
4. Cap tries; backtrack or regenerate on placement conflicts.
5. Place doors, obstacles, landmarks, machinery, noise emitters, and cover.
6. Spawn loot/monsters using distance-from-spawn and risk weighting.
7. Validate traversability and quota-achievable loot distribution, then publish map. Retry invalid seeds; after retry cap use safe fallback layout.
8. Save/log seed and generation validation result for reproduction.

### 6.2 Early content targets
- Generator proof: 6–8 room templates and ~8–12 rooms/run.
- Vertical slice: 12–15 room templates and ~15–25 rooms/run.
- Full launch may expand room count based on measured performance, not arbitrary target.
- Room tags: `Spawn`, `Exit`, `Corridor`, `Junction`, `Loot`, `Danger`, `Machine`, `Loop`, `DeadEnd`.
- Socket attributes: `DoorSocketId`, `Direction`, `Size`, `RoomCategory`, `CanSeal`.
- Deterministic seed means equivalent graph, geometry and spawn tables under same content version (unless dynamic live behavior changes).

### 6.3 Hard validation invariants
- Spawn to extraction reachable by players without requiring an unowned item.
- Every mission-critical item reachable and carryable to extraction.
- No overlaps, sealed required sockets, floating doorways, or irrecoverable falls.
- At least one safe route exists at generation time (not necessarily monster-free later).
- Monster pathfinding can access intended patrol/attack regions; unreachable zones are intentionally tagged.
- Extraction zone has adequate clearance for four players and carried items.
- Accessibility: distinct navigational landmarks/sound cues so repeated hallways do not produce impossible orientation.

## 7. Monsters and AI
### 7.1 Shared sensing model
- Every monster has hearing sensitivity, cooldown, target memory, threat state and movement model.
- Event strength attenuates across distance and relevant occlusion, optionally with environmental masking.
- On hearing: investigate last known sound origin, not perfect player coordinates.
- On seeing/contact or fresh loud sound: pursue; reacquire only via legitimate senses; otherwise search and return patrol.
- PathfindingService handles routes, with bounded recomputation and recovery from unreachable waypoints.
- Debug overlay: detected event, estimated direction/intensity, target memory age, state and path.

### 7.2 Planned roster
- **Listener (MVP):** hearing-heavy patroller, investigates footsteps and sonar, can be distracted by thrown objects.
- **Still One (post-MVP):** nearly silent statue-like creature; active sonar may trigger behavior.
- **Mimic (post-MVP):** plays deceptive footsteps / signals, never impersonates system UI or players' private voice without consent.
- **Resonant (post-MVP):** tracks repeated active sonar events with rising threat.

### 7.3 States
`Idle → Patrol → Investigate → Chase → Search → Return`, plus temporary `Stunned` where appropriate. Do not grant wallhack pathfinding targeting; navigation to legitimate last-known source is allowed.

## 8. Downed & revive
- When HP reaches zero, enter `Downed` rather than immediate removal (unless explicit special hazard later).
- Downed players crawl slowly, cannot use full-power ping, and can emit limited help sound with a cooldown.
- Teammate interaction holds to revive, e.g. 5 seconds. Interrupt on movement/damage/out-of-range.
- Revived players return with partial health and temporary re-down protection, values tunable.
- Bleed-out timer provisional 45 seconds, pause/extend rules to test. A downed player can be carried later (not MVP).
- If all players are downed/dead, round ends. Dead players can spectate with restricted information so they cannot trivialize enemy detection.
- Exploit protection: revive timing, distance and state validated server-side.

## 9. Loot, quota, economy
- Loot has `itemId`, `rarity`, `creditValue`, `weight`, `noiseOnPickup`, `noiseOnDrop`, `carrySlots`, `behaviorTag`.
- Initial items: small scrap, crystal, heavy core, anomalous object. Each is distinctive by echo outline and sound.
- Quota is due after a configurable number of expeditions (example: 3). Value of successfully extracted loot contributes to quota and player/company credits under a clearly defined payout formula.
- Preferred simplification: communal company quota, personal/campaign currency balances for purchases; no trading in MVP.
- Prevent softlock: basic sonar and starting kit are always free; losing a round never removes ability to play. Provide low-tier facilities and recovery starter equipment after bankruptcy/deadline failure.
- Progression unlocks different tools/difficulties, not unbounded power. Suggested equipment: throwable echo pebble, timed beacon, quiet boots, advanced sonar with increased sound risk.
- Default monetization: non-pay-to-win cosmetics only; do not sell crucial sonar reach/visibility advantage.

## 10. Rounds, multiplayer, UI
- Lobby 1–4 players, readiness and equipment; create one dedicated map/run on server per round.
- Default run target 8–12 minutes, with escalation rather than instant monster overwhelm.
- Player count scaling adjusts loot and monster pressure; solo remains feasible.
- Server authority: inventory, loot ownership, sale values, quota, generation seed, monster behavior, damage, revive and extraction.
- Client ownership: echo rendering, camera, local UI, audio cosmetics and input; validation prevents client forging world sounds.
- UI: crosshair, pulse cooldown, carry slots, quota, expedition timer, teammate state, revives, extraction status; no always-on minimap.
- Ping / preset chat communication must work without voice chat.
- Accessibility: readable color-independent symbols, adjustable motion/flash, sound cues with optional directional indicators, performance/contrast presets.

## 11. Technical architecture
Suggested directory:
```
ReplicatedStorage/
  Shared/{Config, Types, SoundEventSchema, RoomDefinitions, ItemDefinitions}
  Remotes/{RequestManualPing, RequestInteract, EchoSoundEvent, RoundState, PlayerState}
ServerScriptService/
  Systems/{RoundService, MapGenerator, MapValidator, SoundService, MonsterService,
           LootService, QuotaService, InventoryService, ReviveService, DataService}
ServerStorage/
  RoomTemplates/ Industrial/
StarterPlayer/StarterPlayerScripts/
  Controllers/{EchoRenderer, InputController, AudioController, UIController}
StarterGui/ GameHUD/
Workspace/ RuntimeMap/
Tests/{GeneratorSeeds, RoundFlow, SoundPropagation, Economy, Revive}
```

Roblox implementation notes:
- `Workspace:Raycast()` with `RaycastParams` for local occlusion and interactions.
- `PathfindingService` for NPC navigation; monitor invalid/blocked routes on generated maps.
- Roblox client-server replication and optional `StreamingEnabled` require graceful handling of unloaded map geometry.
- Deterministic graph algorithm and spatial constraints are custom game systems; Roblox's `ProceduralModel` feature is optional rather than required.
- Do not build a single monolithic server Script or spam one RemoteEvent per wireframe edge.
- Use semantic tags/attributes on all map parts and authored wireframe edges, and object pooling for rendering.

## 12. Implementation phases and acceptance criteria
### P0 — Architecture, game skeleton
- Repository / Rojo or equivalent project layout documented; Studio import and test instructions.
- Modular configs, events and server/client boundaries.
- A complete first-person game shell with black visual world and test arena.
**Acceptance:** clean startup; no uncaught runtime errors; separate server/client components.

### P1 — Sound-vision vertical test
- Walking emits cadence-based small echoes; Q emits larger cooldown-limited echo.
- Environmental emitter and dropped test item create echoes.
- Wireframe wave arrival, wall occlusion, fade and re-reveal.
**Acceptance:** at least two clients can see the same event where legitimately visible; no reveal through solid walls; idle players lose echo visibility as configured; frame-rate remains playable.

### P2 — Procedural generator
- Room graph, socket placement, seed, validator and fail-safe fallback.
- Initially 6–8 templates, at least 8–12 rooms, one industrial biome.
**Acceptance:** 100 deterministic test seeds yield a connected reachable spawn/extraction and no critical overlaps; log failed seeds; source remains reproducible.

### P3 — One monster and risk/reward
- Listener with sound investigation and last-known-position tracking.
- Loot, 1 carrying system, extraction, round timer and results.
**Acceptance:** monster responds to steps/ping/throwable and can lose target; full round can be completed solo; recovered loot credited exactly once.

### P4 — Multiplayer, downed and persistence
- 1–4 co-op, revive, spectator limits, server-authoritative inventory.
- Basic currency and quota saved robustly.
**Acceptance:** two-to-four-player simulated sessions resolve extraction/disconnect/death without item dupes or desync; revives validated by server.

### P5 — Quality and release readiness
- Content scale-up, second monster, more room templates, menu polish, sound pass, mobile control/performance QA.
- Difficulty and accessibility tuning from playtests.
**Acceptance:** new users understand sonar and goal without developer instruction; no known progression softlocks or map softlocks.

## 13. Performance and QA guardrails
- Profile mobile and desktop separately; choose 60 FPS target on capable PC and 30 FPS floor on supported mobile, not guaranteed on every device.
- Pool edges; batch segment updates; enforce configurable per-frame render budget and max concurrent waves.
- Test walls/closed doors, overlapping pulses, rejoining clients, disconnected carrier, last alive player going down, revive at bleed-out threshold, loot dropped into gaps, and server shutdown saving.
- Store and report generator seed and version on failures.
- Review network frequency, latency, and malicious requests; never trust client-created sounds, loot value, or revival status.

## 14. Explicit exclusions until approved
- Unlimited fully random geometry/terrain; instead modular procedural rooms.
- Full acoustic simulation, realistic diffraction or reverberation tracing.
- 4+ monsters in MVP, classes/skill trees, PvP, trading, pay-to-win sonar purchases.
- Mandatory voice chat, elaborate NPC cinematic animations, persistent player location map.

## 15. AI developer instructions
1. Read this PRD first. Do not turn provisional values into immutable design decisions.
2. Implement ONLY the current requested milestone; complete and test it before expanding scope.
3. Before implementation, return architecture summary, affected Roblox services, files, assumptions, and acceptance tests.
4. Prefer reusable Luau modules and configurations over hardcoded logic.
5. Provide exact Roblox Studio integration instructions and an automated/reproducible testing path where feasible.
6. On obstacles, report the specific engine limitation and propose the smallest viable compromise; never silently remove blindness, occlusion, procedural generation, or server authority.
7. Retain all user-approved six decisions and wireframe direction.

## 16. References
- Raycasting: https://create.roblox.com/docs/workspace/raycasting
- Client-server runtime: https://create.roblox.com/docs/projects/client-server
- Pathfinding: https://create.roblox.com/docs/characters/pathfinding
- Procedural models (optional): https://create.roblox.com/docs/parts/procedural-models
