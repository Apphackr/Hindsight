# Hindsight — "travel with hindsight"

Will's personal travel app. It's a phone web app (PWA) hosted on GitHub Pages at
https://apphackr.github.io/Hindsight/ and installed on his iPhone home screen.

## How it's built
- **One file does everything: `index.html`**, with inline CSS and plain JavaScript and no build step. Edit it directly.
- `sw.js`: the service worker (offline cache). Bump the `V` version string when the app shell changes.
- `manifest.webmanifest` and the icons: install metadata.
- **Data lives on the phone** in IndexedDB. The database is named `wayfarer` (the app's old working name). Don't rename it, or existing data is lost. `localStorage` is only a fallback.
- **AI:** the app calls the Anthropic Messages API from the browser using the user's own key, stored on the device (header `anthropic-dangerous-direct-browser-access`). The default model is `claude-sonnet-5`. Web search (`web_search_20250305`, max_uses 2) is used only for chat, watch-outs and checklists.
- **Plans:** each section is generated in parallel (`genPlan` → `genSection`, 3 at a time) and rendered as it arrives.
- **Chat:** answers end with a `RECS: [...]` JSON line, grouped and rendered as separate cards by category (`recCardsHtml`) rather than inline chips. Saving one is a bookmark only — it does NOT touch the plan.
- **Saved vs. plan — deliberately separate.** `t.saved` is a bookshelf of bookmarked ideas (from AI plan cards, chat recs, friend's tips, own ideas); nothing lands there "in the plan" automatically. Each saved item has `inPlan` (bool — set only via the explicit "+ Add to plan" toggle, `addSavedToPlan`, on its own place page, `vPlace`/`#/trip/<id>/place/<savedId>`), `cat` (its section heading — free text, so the user can create their own like "Breakfast"; the Saved tab groups by this and offers filter chips, `SFILT`/`filterSaved`, to show just one section), `state` (loved/good/meh/didn't-go, shown once `started(t)`; picking one auto-opens the review sheet), `review` (the user's own written review) and `more` (an on-demand "what people say" blurb, web-search-backed, fetched once and cached via `moreInfo()`).
- **Itinerary:** `buildItinerary()` (the Itinerary tab) builds a day-by-day schedule ONLY from bookings and saved items with `inPlan:true` — never the full saved list or the general AI plan sections. This is intentional: it's what makes "add to plan" mean something. Throws `NOTHING_COMMITTED` if there's nothing to build from.
- **Plan tab declutter:** `secHtml()` hides any AI-suggested card once it's saved (shows a "N saved — view" line instead of the card), so the list only ever shows things not yet decided on. Each remaining card is wrapped in `.swipe`/`.swipe-body`/`.swipe-del` — a lightweight touch-swipe-to-dismiss (global `touchstart`/`touchmove`/`touchend` handlers, `SWP` state) that permanently removes an unwanted suggestion via `dismissPlanItem`. "Ask about this trip" (`chatHtml`, `#ask-box`) sits at the top of the Plan tab, above the AI suggestions, and every trip tab's sticky `.tv-bar` carries a persistent "💬 Ask" pill (`askJump`) that jumps to it from anywhere.
- **Bookings** have a `match` type (⚽) for football fixtures, with a `findMatch()` AI helper (web search) that fills in kickoff date/time and venue from just the fixture name, the same way `extractBooking()` fills a booking from a pasted confirmation email.
- **Travel extras:** a small "Travel extras" card (`extrasCard()`, `setExtra` action) always sits at the top of the Checklist tab — Yes/No for airport lounge and airport parking, stored on `t.travelExtras` and fed into the AI context (`ctxTrip()`) so plan/checklist/itinerary generations know about them.
- **Suggestion detail sheet:** every AI-suggested card — in a Plan section (`secHtml`) or a chat recommendation (`recCard`) — is tappable (`data-act="openSug"`) and opens a bottom sheet (`sugSheetR`) showing the full detail, distance/directions, an on-demand "what people say online" AI+web-search lookup (`sugMore`), an honest "From the community — coming soon" placeholder (there's no real community data source yet), and a Save toggle (`sugSave`) that writes to `t.saved` the same way the inline Save buttons do — tapping the card is separate from tapping its own Save button (click delegation resolves to the innermost `data-act`, so nested buttons still work).
- **Your plan section:** the Plan tab has its own "📌 Your plan" section (`planItemsHtml()`), right below "Ask about this trip" — every saved item with `inPlan:true`, grouped by category the same way the Saved tab groups them, tapping through to the same place page. An empty state nudges towards "+ Add to plan" when nothing's committed yet, and a link jumps to the Itinerary tab.
- **Sharing recs:** each logged place in the Log tab has its own share icon (`shareOneRec`) that shares just that one tip, alongside the existing "Share my recs" button (`shareRecs`) which still bundles the whole log. Both build their text from the same `recText(l)` helper.
- **Notifications are local only, not push.** `S.settings.notify` (Settings → Notifications) turns on local reminders — day-countdown milestones (30/14/7/3/1/0 days out, `checkReminders()`, deduped via `t.notifiedDays`) and a checklist nudge once a trip is within 7 days if items are still undone (deduped via `t.checklistNotifiedAt`) — fired via `notify()` (service worker `showNotification` if registered, else `new Notification()`) on `boot()` and on `visibilitychange`. This only works while the app is open or has recently been open — true background push (arriving when the app is fully closed) needs a server/VAPID backend this build doesn't have, and the Settings copy says so plainly rather than overpromising.
- **Routing:** hash routes (`#/home`, `#/trip/<id>/<tab>`, `#/trip/<id>/place/<savedId>`, `#/country/<code>`, `#/me`, `#/wish`, `#/settings`, `#/new`, `#/edit/<id>`, `#/ask/<id>`, `#/onboard`) — `parse()` captures a 4th segment as `R.sub`. Trip tabs: `plan`, `saved`, `itin`, `book`, `check`, `log`.
- **Actions:** event delegation through `data-act` → the `A` object. Drafts live in `D`. State is `S`; call `save()`, then `render()`.
- **Trips:** a trip with `kind:'past'` is a memory of a past visit, added from a country page. Trips also have `base` (where you're staying), `saved`, `bookings`, `checklist`, `log` (the user's own recs, with photos), `chat` and `itinerary`.

## Deploying
Commit to `main`. GitHub Pages serves the repository root. Changes are live in about a minute. The user then fully closes the app and reopens it.

## Testing
Serve locally with `python3 -m http.server`. Drive it with Playwright, mocking `https://api.anthropic.com/**`. Check for page errors and screenshot at 390px width.

## Product direction
There's a spec doc ("Hindsight — MVP Spec") that has the roadmap. The app is currently single-user.

- **Next:** real community features (accounts, friends, shared recommendations, statuses, locals), which need a backend such as Supabase.
- **Later:** leaderboards and expert levels across users, Reddit-style communities, and travel booking partnerships.

## Preferences
- Light colour scheme.
- UK English.
- Prices in GBP.
- Keep the UI simple and Airbnb-like, and use tap-to-select choices instead of free text where possible.
