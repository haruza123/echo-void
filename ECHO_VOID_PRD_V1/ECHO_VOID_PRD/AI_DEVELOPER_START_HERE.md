# ECHO//VOID — Instructions for Claude Code / Antigravity

Read `PRD_ECHO_VOID_V1.md` as the authoritative product baseline.

## First assignment: P0 + P1 only
Build a playable **first-person wireframe echolocation prototype** in Roblox Studio, NOT the whole extraction game.

Before coding: summarize your proposed file structure, strategy for keeping map geometry invisible while physics work, renderer options (with performance implications), and plan for server-authoritative sound events. State assumptions plainly.

Implement:
- Simple authored test room/arena with walls and obstacles.
- Black/no normal world vision; HUD/crosshair still visible.
- Walking echo, manual Q echo with cooldown, one environmental sound emitter.
- Expanding wireframe reveals, occlusion blocked by walls, configurable fade, event reuse.
- A local and shared multiplayer sound event path, safe validation of request.
- Studio launch/test steps, how to view logs, and minimum manual acceptance checklist.

Do not implement monster AI, progression, procedural generation or extraction yet; those follow later milestones.

**Critical:** 'Invisible' must not mean no collisions. 'Shared echo' must not leak map visibility through closed walls. Avoid flooding network with per-segment positions. Keep adjustable config values in modules.

On completion, report files created, exact testing steps, known limitations, and pass/fail of each acceptance condition. Never claim a test passed unless it ran.
