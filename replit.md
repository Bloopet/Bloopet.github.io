# Bloopet

A browser-based game portal serving 88 locally-hosted games (HTML5, Unity, Flash via Ruffle). All games are fully local — no external links. Target audience: ages 13 and under.

## Project Structure

- `index.html` — Homepage (single file, all JS inline)
- `main.css` — Global styles (~1700 lines, full responsive + mobile)
- `server.js` — Node.js HTTP server (port 5000 / process.env.PORT), includes auth/leaderboard APIs
- `games/` — Locally-hosted game directories (each with its own assets/engine)
- `images/` — Game thumbnail images (PNG/JPG for real photos, SVG kept only for custom workshop tools; all game SVGs replaced with CDN URLs from GamePix/CrazyGames/Wikimedia)
- `db.js` — PostgreSQL database module (pg Pool, all async read/write functions, auto-migration from JSON on first run)
- `data/*.json` — Legacy flat-file data (kept for reference; server now uses PostgreSQL exclusively)
- `js/main.js` — Stub required by some Flash games

## Auth System
- POST /api/register — { username, password, avatar } → { token, username, avatar }
- POST /api/login — { username, password } → { token, username, avatar }
- GET /api/me — requires `Authorization: Bearer <token>` header
- Password hashed with SHA-256 + salt `bloopet-2025-salt`
- Token stored in localStorage as `bloopet_token`

## Leaderboard API
- GET /api/leaderboard → { topGames: [{id, count}], topPlayers: [{username, avatar, total, games, adminAccess, tags}] }

## Multiplayer / SSE System (NEW)

- `GET /api/sse` — Server-Sent Events endpoint; keeps persistent connection per browser tab
  - Auth via `?auth=<token>` query param (EventSource can't send headers)
  - Sends `{type:'welcome', connId}`, `{type:'online', list}`, `{type:'room_update', room}`, `{type:'room_msg', msg}`
  - Heartbeat every 25s; auto-cleanup on disconnect
- `POST /api/sse/game` — Update which game this connection is currently playing
- `GET /api/online` — Returns list of online players + count
- `POST /api/room/create` — Create a room (`{connId, gameId, gameName}` → `{code, room}`)
- `POST /api/room/join` — Join by 4-char code
- `POST /api/room/msg` — Send chat message to room (broadcast via SSE)
- `POST /api/room/leave` — Leave room
- In-memory state: `sseClients` Map (connId → client), `rooms` Map (code → room)
- Rooms hold up to 8 players, 4-char alphanumeric codes, last 20 chat messages

### Frontend Multiplayer UI
- "🟢 N" badge on the nav users icon showing live online count
- "Play Together" button in nav and mobile menu
- Modal: join by code OR create room for a specific game + live chat + room player list
- Secret games loaded for logged-in users from `/api/secret-games`

## Community Page (/u)

- URL: `/u` — Community hub (server-rendered HTML, no auth required to view)
- Logged-out users see a login prompt in the search panel; search still works
- Logged-in users see a Friends panel showing their friend list with remove buttons
- Player search calls `GET /api/users/search?q=<query>` — debounced 350ms, searches username + display_name
- Add/remove friend buttons call `POST /api/friends/add` / `/api/friends/remove` with `x-token` header
- Each user row links to their profile at `/u/:username`
- `db.searchUsers(query, limit)` added — case-insensitive LIKE on username + display_name, excludes banned users

## Public API v1 (/api/v1/)

- Documentation page at `/developer` — full reference with sidebar nav, endpoint docs, and code examples (JS, Python, curl)
- All v1 endpoints return `{ ok, data, meta? }` envelope; CORS enabled (`Access-Control-Allow-Origin: *`)
- Rate limit: 60 requests/minute per IP (in-memory, auto-cleaned every 5 min); returns HTTP 429 on breach
- Auth: pass `Authorization: Bearer <token>` or `x-token` header for `/api/v1/me`
- Game metadata maintained server-side in `GAME_META` object (84+ games with label + category)

### Endpoints
- `GET /api/v1/status` — Platform stats (games, totalPlays, registeredPlayers, onlineNow)
- `GET /api/v1/games[?category=]` — All games sorted by plays, optional category filter
- `GET /api/v1/games/:id` — Single game stats (id, label, category, plays, url)
- `GET /api/v1/leaderboard[?limit=]` — Top games + top players (limit 1–50, default 10)
- `GET /api/v1/players[?limit=]` — Top players by total plays (limit 1–100, default 20)
- `GET /api/v1/players/:username` — Public player profile (avatar, plays, top 5 games, joinedAt)
- `GET /api/v1/me` — 🔐 Auth-required: authenticated user's profile

## Secret Games Page (/games)

- URL: `/games` — Members-only hidden game collection (server-rendered HTML)
- Logged-out users see a "Members Only" lock screen with a login/signup button
- Logged-in users see all secret games fetched from `GET /api/secret-games` rendered as purple-accented cards
- Secret games are managed via the Admin Panel (Tabs: Secret Games)
- Cards link to the game's external URL (target=_blank)

## Admin Panel

- URL: `/admin.html` — supports master key login OR account login (for users with `adminAccess`)
- Default key: `bloopet-admin-2025` (override with `ADMIN_KEY` env var)
- Tabs: Stats | Users | Live Rooms | Announcements | Submissions | Secret Games
- Master-key-only actions: delete user, grant/revoke Owner status
- `isAdminAuth(key, token)` helper checks both auth modes; `getAdminAuth(req)` parses GET params
- `GET /api/admin/stats?key=|token=` — full stats + users list (includes `isMasterAdmin`)
- `POST /api/admin/stats/reset-game` — reset play count for a specific game
- `GET /api/admin/rooms?key=|token=` — live multiplayer rooms
- `GET /api/admin/announcement?key=|token=`, `POST /api/admin/announcement` — banner management
- `GET /api/admin/subs?key=|token=`, `POST /api/admin/subs/delete` — submissions
- `GET /api/admin/secret-games?key=|token=` — list secret games
- `POST /api/admin/secret-games/add`, `/remove` — manage secret games
- `POST /api/admin/users/delete` — delete user (master key only)
- `POST /api/admin/users/grant-admin` — grant Owner status (master key only)
- `POST /api/admin/users/revoke-admin` — revoke Owner status (master key only)
- `POST /api/admin/users/add-tag` — add custom tag to a user's profile
- `POST /api/admin/users/remove-tag` — remove a tag from a user's profile
- `data/secret-games.json` — persisted secret game entries (visible to logged-in users)

## User Banning
- `POST /api/admin/users/ban` — master key only; sets `banned: true` + `banReason`, invalidates token
- `POST /api/admin/users/unban` — master key only; removes ban
- Banned users cannot log in; login returns `{ error: 'banned', reason: '...' }` (403)
- Login form shows a styled ban message with reason in red
- Admin Users table shows 🚫 BANNED badge + ban reason text; master admin sees Ban/Unban button

## Personal Banners (per-user messages)
- Admin can set a custom message for any specific user via the Users tab in the admin panel
- Stored as `personalBanner` string on the user object in `users.json`
- `POST /api/admin/users/set-banner` (any admin) — set message; `POST /api/admin/users/clear-banner` — remove it
- `/api/me` returns `personalBanner` field if one is set
- On login and on page load: if a personalBanner exists, a styled amber modal pops up showing the message (once per session via sessionStorage key `bloopet_banner_seen_<username>`)
- Admin Users table shows active banner text in amber, plus input to set a new one and Clear button

## User Tags & Owner System
- Users with `adminAccess: true` display a 👑 Owner badge (gold, gradient) on their profile and leaderboard
- Custom tags can be added to any user by any admin via the Users tab in the admin panel
- Tags stored as `tags: []` array in `data/users.json`
- Shown as blue pills on profile modal and leaderboard; Owner tag is gold
- `/api/me` returns `adminAccess` and `tags`; `/api/leaderboard` includes both per player

## Virtual Controls (injected into all game pages)
- "⌨️ Keys" button: toggles floating on-screen keyboard (WASD, arrows, numbers, special keys)
- "🖱️ Mouse" button: toggles virtual trackpad (touch-to-mouse passthrough, click, scroll)
- Touch-to-mouse event passthrough active at all times for iPad compatibility

## Game Count (85 total)

13 mature/violent games were removed for age-appropriateness (ages 13 and under):
- Removed: BitLife, Moto X3M series (4), Rooftop Snipers, Getaway Shootout, Super Meat Boy, etc.
- Restored on request: Henry Stickmin, Bob the Robber 2, Super Smash Flash

## Thumbnail Status (all 85 games have proper thumbnails)

- Real PNG/JPG photos: ~28 games (from game folders or original library)
- Custom SVG artwork: ~57 games (game-specific, no placeholders)
- Key SVG artwork created: 2048, Astray, Breaklock, Chroma, Fireboy & Watergirl 2, Google Solitaire,
  Hextris, Wordle, A Dance of Fire & Ice, Basketball Stars, Cookie Clicker, Dinosaur Game,
  Doodle Jump, Drift, Duck Life 2, Flappy 2048, Flappy Bird, FNF Week 6, Geometry Dash,
  Gopher Kart, Hill Racing, MC Classic, Radius Raid, Run 3, Slope 2, Space Invaders,
  Tank Trouble, Tube Jumpers

## Cool Features (index.html client-side)

- **No Ads Ever** — universal ad stub (`js/main.js`) blocks GameMonetize, GameDistribution, MochiAds, CrazyGames, Google Ads; `games/drive-mad/Jump_Gamemonetize.js` replaced with clean no-op
- **Surprise Me! Spinner** — animated game picker using local `GAMES` array; spins through names then reveals a random pick with Play Now button
- **Cute Animal Widget** — random dog/fox/cat photo cycling between Dog CEO API, RandomFox API, and TheCatAPI (all free, no key)
- **Fun Fact Widget** — random trivia facts from uselessfacts.jsph.pl (free, no key)
- **Daily Trivia Card** — multiple-choice question from Open Trivia DB (free, no key); lazy-loads via IntersectionObserver
- **Joke of the Day** — kid-safe jokes from JokeAPI safe mode; footer tip/joke carousel with 🔄 button
- **No Ads pill** — green pulsing badge in stats bar
- **Site Footer** — brand, daily rotating tip, quick links, copyright year
- **Konami Code Easter Egg** — ↑↑↓↓←→←→BA triggers celebration overlay
- **Background particles** — CSS DOM emoji particles (`.bg-particle` divs with `@keyframes bg-float`), respects reduce-motion setting

## Key Architecture Rules

- Play counts stored in `data/plays.json`; `__total__` key tracks total plays for the stat counter
- The `/api/popular` endpoint returns `totalPlays` field for the stats bar
- Categories: filter bar in index.html; each game card has `data-category` attribute
- Favorites/Recent/Ratings: localStorage keys `bloopet_favs`, `bloopet_recent`, `bloopet_ratings`
- Home button injected server-side in `serveFile()` before `</body>` for all `/games/` HTML files
- Path traversal protection, CORS headers, and input validation in server.js
- Game count stat is hardcoded as 85 in three places in index.html (stat bar, section header, animateCount)

## Running

```
node server.js
```

Runs on `process.env.PORT || 5000`.

## Deployment

**Autoscale** deployment. Run command: `node server.js`.
