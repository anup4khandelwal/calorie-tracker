# Build progress

Working checklist — updated as commits land.

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
- [ ] Static review pass (swiftc -parse syntax audit of every file)

## Known limitations / future

- No simulator in the authoring environment — the README checklist is the acceptance pass.
- Timeline images all load through one engine dictionary; fine for months of data,
  would want LRU eviction at thousands of entries.
- Past-day pager reaches back 60 days; the timeline shows everything ever logged.
- Voice input, photo-of-your-plate logging, and widgets are natural next steps.
