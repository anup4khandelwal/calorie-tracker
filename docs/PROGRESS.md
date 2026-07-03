# Build progress

Working checklist — updated as commits land.

## Phase 2 — design overhaul ("cook hard")

- [x] Pixel-audit harness (`tools/frameaudit/`): numpy ports of all shader
      math, frame sequences rendered + visually inspected, WCAG report
- [x] Findings fixed: zoomRipple sampled out-of-bounds at all four edges
      (smearing); grainReveal read as mold mid-develop; plateShimmer was a
      skeleton-loader band; liquidGlass refraction was a no-op (sampled its
      own flat fill); creamFaint failed AA at 2.92:1
- [x] Shader suite v2: ambientField (replaces MeshGradient), stillLife,
      filmDevelop, glassRim (SDF procedural glass), edge-safe zoomRipple
- [x] Floating-page zoom choreography (no full-screen blur; per-layer easing)
- [x] Component redesign: 4pt spacing grid + radii tokens, Pressable button
      style, matted entry cards with macro meters + baseline-aligned numerals,
      folio-ruled masthead + timeline headers, staggered tile arrivals
- [x] App icon rendered from the same ambient math (eclipse ring, goal tick)
- [x] All Swift re-parsed clean; docs updated

## Phase 1 — build

- [x] Branch + scaffold (project.yml, docs, gitignore)
- [x] Design system: theme, typography, haptics, motion springs
- [x] Metal shaders + SwiftUI wrappers
- [x] SwiftData models + store helpers
- [x] Nutrition seed database (JSON) + search
- [x] Claude client (SSE streaming, tool use loop)
- [x] Agent toolbox + system prompt + AgentSession
- [x] Gemini image engine + disk cache
- [x] Chat UI: pager, thread, streaming renderer, entry cards, composer
- [x] Timeline: magazine catalog, day sections, zoom transitions
- [x] Settings + onboarding (keys, goals)
- [x] README with setup, simulator verification checklist
- [x] Static review pass — all 27 Swift files parse clean under swiftc 6.0.3;
      NutritionDB compiled + executed against Foods.json on Linux (search verified);
      JSON/YAML validated; semantic review fixes committed (wire-role ordering,
      lazy pager, observation-safe caches, MSL type promotion, deep-link landing)

## Known limitations / future

- No simulator in the authoring environment — the README checklist is the acceptance pass.
- Timeline images all load through one engine dictionary; fine for months of data,
  would want LRU eviction at thousands of entries.
- Past-day pager reaches back 60 days; the timeline shows everything ever logged.
- Voice input, photo-of-your-plate logging, and widgets are natural next steps.
