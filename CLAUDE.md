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
- **Chat:** answers end with a `RECS: [...]` JSON line. Those items become one-tap "save" chips, which add to Saved and to the plan (`fromChat`).
- **Saved items** (`t.saved`): each has `state` (the loved/good/meh/didn't-go reaction, shown once the trip has started — `started(t)`), `review` (the user's own written review, added via the review sheet) and `more` (an on-demand, web-search-backed "what people say" blurb, fetched once and cached — `moreInfo()`). Items not already tied to a plan section (friend's tips, own ideas — `key:''`) get an explicit "+ Add to plan" action (`addSavedToPlan`).
- **Itinerary:** a separate AI step (`buildItinerary()`, the Itinerary tab) that sequences the trip's bookings, plan items and saved places into a day-by-day schedule (`t.itinerary.days`), anchoring on fixed-time bookings (flights, matches, tickets). It only uses what's already in the plan/saved/bookings — it doesn't invent new places.
- **Bookings** have a `match` type (⚽) for football fixtures, with a `findMatch()` AI helper (web search) that fills in kickoff date/time and venue from just the fixture name, the same way `extractBooking()` fills a booking from a pasted confirmation email.
- **Routing:** hash routes (`#/home`, `#/trip/<id>/<tab>`, `#/country/<code>`, `#/me`, `#/wish`, `#/settings`, `#/new`, `#/edit/<id>`, `#/ask/<id>`, `#/onboard`). Trip tabs: `plan`, `saved`, `itin`, `book`, `check`, `log`.
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
