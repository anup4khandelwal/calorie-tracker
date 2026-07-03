# Mise

*Everything in its place.*

Mise is a calorie tracker built as **one unified conversational surface**. Each day is a
chat thread with a warm, capable food agent (Claude). Say what you ate — it grounds the
numbers, logs it, and every dish gets a **studio portrait** generated in one locked
editorial style (Gemini). Pinch out of any thread and the whole record unfolds into a
**magazine catalog** of everything you've plated.

| Move | What happens |
|---|---|
| *"had two eggs and sourdough toast"* | The agent logs both in one turn; cards develop in with a film-grain dissolve; a two-beat "plated" haptic lands |
| *"actually it was three eggs"* | It edits the existing entry, no re-logging |
| *"how am I doing this week?"* | It queries your history — averages, streaks, honest but kind |
| **Pinch in** on the thread | The chat recedes with a liquid ripple; the timeline catalog settles in behind it |
| **Swipe horizontally** | Page between days — every day is its own thread, past days can be backfilled |

## Setup (2 minutes)

Requirements: **Xcode 16+**, iOS 18 simulator or device, [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
xcodegen generate
open Mise.xcodeproj
# ⌘R on an iOS 18 simulator
```

On first run the app asks for:

- **Anthropic API key** (required) — the conversation runs on `claude-opus-4-8`.
  Get one at [console.anthropic.com](https://console.anthropic.com).
- **Gemini API key** (optional) — food photography via `gemini-3.1-flash-image`
  (falls back to `gemini-2.5-flash-image`). Get one at
  [aistudio.google.com](https://aistudio.google.com/apikey). Without it, dishes render
  as emoji on a ceramic plate — still pretty, just not photographed.

Keys live in the iOS Keychain only.

## What to look at

- **Every shader was audited frame-by-frame before shipping** — `tools/frameaudit/`
  ports the exact Metal math to numpy, renders labeled frame sequences and contact
  sheets, and the constants were tuned against those renders. (This pass caught the
  zoom sampling out-of-bounds at all four edges, a develop effect that read as mold,
  and a skeleton-loader shimmer — all replaced.)
- **The material system** — the page is a shader-drawn candlelit field (no stock
  gradients), chrome is procedural smoked glass (SDF rim light under a slowly drifting
  source, traveling edge gleam), and photographs *develop* like prints: present from
  frame one, highlights first, focus resolving, silver grain dissolving.
- **The zoom** — the thread lifts off as a physical page: corners round, a two-layer
  shadow grows, it recedes crisply at 0.84× while the timeline settles beneath with
  parallax. One raw progress, per-layer easing, fully interruptible, never blurred.
- **Typography discipline** — 4pt spacing grid, nested corner radii, baseline-aligned
  serif numerals, folio rules, every text pair ≥ 4:1 contrast (WCAG-audited).
- **Streaming text** — agent replies *condense* onto the page (per-glyph blur + rise via
  a custom iOS 18 `TextRenderer`), not teletype.
- **The agent** — tool-use loop over the Messages API (SSE), grounded by a bundled
  nutrition DB, with cheeky activity lines ("plating it…", "checking the pantry…").

## Simulator verification checklist

Run through after any change (this repo was authored in a Linux environment without
Xcode, so treat this as the acceptance pass):

1. Fresh install → onboarding sheet appears; "Set the table" disabled until an
   Anthropic key is pasted.
2. Today opens with a local greeting (no API call). Suggestion chips visible.
3. Send *"2 eggs and toast"* → activity ember pulses → text streams with the condense
   effect → two entry cards spring in → "plated" haptic → ring count animates up.
4. With a Gemini key: cards start as shimmering plates, then photos develop in with
   grain. Kill and relaunch — images load instantly from disk cache.
5. Send *"make it three eggs"* → the existing card's numbers tick over
   (`update_food_entry`), no duplicate card.
6. Pinch inward on the thread → interactive zoom; release early → springs back;
   release past ~1/3 → timeline commits. Tap a meal card → dives into that day and
   scrolls to that entry's message.
7. Swipe right → yesterday's thread; backfill something (*"had ramen for dinner"*);
   check it appears in the timeline under the right day.
8. Ask *"how am I doing this week?"* → history tool runs, answer references real totals.
9. Airplane mode → send → soft ember error banner (no alert). Recovers on retry.
10. Long-press an entry card → "Remove from log" → totals update.

## Repo map

```
project.yml          XcodeGen manifest (generates Mise.xcodeproj)
docs/ARCHITECTURE.md How everything fits, in detail
Mise/App             Entry point, AppModel (zoom + services), RootView stage
Mise/DesignSystem    Theme, motion/haptics, ring, mesh background, glass chrome
Mise/Shaders         Mise.metal + SwiftUI wrappers
Mise/Models          SwiftData models + Store helper
Mise/Nutrition       Seed nutrition DB (JSON) + fuzzy search
Mise/Agent           Claude SSE client, toolbox, system prompt, session loop
Mise/Imagery         Gemini generation + disk cache (the locked "shoot")
Mise/Chat            Pager, thread, streaming renderer, cards, composer
Mise/Timeline        The zoomed-out magazine catalog
Mise/Settings        Onboarding + settings
```
