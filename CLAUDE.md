# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ru_project is a French university restaurant (RU) companion app: a Flutter mobile frontend + Node.js/Express/TypeScript backend with MongoDB. Features include restaurant menus (CROUS XML feed), real-time chat (Socket.IO), interactive floor maps with sectors, friend system, bus schedules (Ginko API), and bug reporting.

## Development Commands

### Backend (`cd backend`)
```bash
npx tsx watch src/server.ts    # Dev server with file watching (port 5000)
npm run build                  # TypeScript compilation to dist/
npm test                       # Run all Jest tests
npm run test:unit              # Unit tests only
npm run test:e2e               # E2E tests
```

### Flutter (`cd flutter`)
```bash
flutter pub get                # Install dependencies
flutter run                    # Run app (VS Code launch recommended)
flutter build apk              # Build Android APK
```

### Environment
Backend requires `.env` in `backend/` with: `MONGO_URI`, `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`, `GINKO_API_KEY`, `NODE_ENV`. Optional: `CORS_ORIGINS`, `TRUST_PROXY` (default `1` in production — the API sits behind nginx; without it every client shares the proxy IP for rate limiting).

## Architecture

### Backend (`backend/src/`)
- **Entry**: `server.ts` (DB connect, Socket.IO init) → `app.ts` (Express middleware, route mounting)
- **Routes** (`routes/`): Organized by domain — `auth/`, `user/`, `socket/`, `ru/`, `ginko/`, `sector/`. Each has controller + service files. All prefixed under `/api/`.
- **Models** (`models/`): Mongoose schemas — User (bcrypt-hashed passwords, role-based), Room, Message, Sector (auto-increment sectorId per restaurant), Restaurant, BugReport, FriendRequest, SectorSession.
- **Auth**: JWT access + refresh token pattern. Middleware in `middleware/` verifies tokens. Rate limiting: 50 req/min (admin excluded).
- **Real-time**: `utils/socket.ts` — SocketHandler class manages Socket.IO connections, user online tracking, room-based messaging.
- **Admin**: AdminJS dashboard with Mongoose adapter (User, BugReport, Sector resources). Custom React components in `components/`.
- **External APIs**: CROUS menu XML (`xml2js` parsing), Ginko bus API (`axios`).
- **File uploads**: Multer + Sharp for image compression (avatars, bug screenshots).
- **Config**: `config.ts` resolves paths differently for dev vs production (dist/ offset).

### Flutter (`flutter/lib/`)
- **Entry**: `main.dart` — services are instantiated manually and injected into a `MultiProvider`. `ChangeNotifierProvider`: `UserProvider`, `RestaurantProvider`, `ChatConnection`, `NotificationProvider`. Plain `Provider`: the services + `SecureStorage` + `ApiClient` + `SessionManager`.
- **Session**: `services/session_manager.dart` is the single place that opens (`openSession` after login/register) and closes (`logout`, `clearLocalSession`, `leaveGuestMode`) a session — tokens, guest RU, chat socket, unread counters, user state. Never clear these piecemeal.
- **Navigation**: `navigation/app_navigation.dart` owns `navigatorKey` and `goToHome` / `goToGuestHome` / `goToWelcome`, which replace the whole stack (use them for every session transition, never `pushReplacement`).
- **State**: Provider pattern with ChangeNotifier (`providers/`). `UserProvider.init()` runs at startup to restore session, load friends, and the user's restaurant.
- **Services** (`services/`): `api_client.dart` wraps Dio with JWT interceptor (refresh on 401 / 403 « Invalid or expired token », never on `/auth/*`; concurrent refreshes share one call; retries once; a refused refresh token calls `onSessionExpired` → `SessionManager.clearLocalSession` + welcome). Domain services: auth, user, friend, restaurant, socket, ginko, feedback. All share the one Dio instance from `ApiClient`.
- **Chat client**: `services/chat_connection.dart` = the single persistent Socket.IO connection (token in handshake `auth`; on an auth `connect_error` it refreshes the token and reopens once; on every (re)connect it replays the last `join_*` and emits `ChatResynced` so the open screen reloads history). `widgets/chat_ui.dart` (`openChat` / `ChatPage` / `ChatUi`) renders a room with `flutter_chat_ui` v2: one `InMemoryChatController` (chronological), optimistic send with sending/sent/error statuses + retry, long-press to copy/delete own messages, scroll-up pagination (`before`), sender name + avatar in Global. `widgets/inbox_widget.dart` lists Global + friends with live previews.
- **Token storage**: `flutter_secure_storage` for encrypted token persistence.
- **Widgets** (`widgets/`): `main_scaffold.dart` is the main view; tabs come from `navigation/main_destinations.dart` — connected: Carte, Menu, Messages, Amis, Plus (Profil, Bus, Réglages, Debug in dev, Déconnexion); guest (`kGuestDestinations`): Carte, Menu, Bus, plus an account menu (se connecter / créer un compte avec le RU pré-rempli / changer de RU / quitter le mode invité) and a dismissible guest banner. Auth screens in `welcome/` (`LoginPage`, `RegisterWidget`, `AuthFormWidget`).
- **Config** (`config.dart`): Switches API URLs based on `kReleaseMode` (production vs development).
- **Localization**: French (FR) — Material & Cupertino delegates.
- **Font**: Marianne (custom).

## Features

Each feature maps to a Flutter tab/screen and a backend route domain.

- **Auth & account** (`welcome/`, `auth/`): register / login / logout, JWT access (1h) + refresh (7d) tokens, token refresh, account deletion (also deletes the avatar file). Passwords bcrypt-hashed (salt 10) via a Mongoose `pre('save')` hook; credentials validated 3–32 chars.
- **Restaurant menus** (Menu tab, `ru/`): pulls the live CROUS BFC feed (`webservices-v2.crous-mobile.fr:8080/feed/bfc/externe/`) — `resto.xml` for the catalog, `menu.xml` for the meals — parses it (`xml2js`) and serves only today-and-later menus. Menus are **per restaurant**: `GET /api/ru/menus?restaurantId=rXXX` (CROUS id, default `r135`). Caching: each restaurant's menus live **1 day** in `node-cache`; the shared raw feed is re-fetched at most hourly. If the feed is unreachable, falls back to the local `menus.xml` fixture.
- **Restaurant catalog & selection**: the catalog lives in Mongo and is refreshed from `resto.xml` only when stale (**≥ 3 months**, based on `updatedAt`; forced sync: `POST /api/ru/restaurants/sync`, auth). Startup calls `syncRestaurantsFromCrous()` (skips if fresh). All ~46 CROUS restaurants are upserted keyed by their official `restaurantId` (unique index; extra fields `type`/`zone`). `GET /api/ru/restaurants` exposes them (public). Users pick a RU in a searchable list at registration / guest onboarding / settings; register and `PUT /users/update-restaurant` accept **both** the CROUS id (`r135`) and a Mongo ObjectId. `/me` returns the CROUS id as `restaurantId`. The Menu tab follows the selected RU (listener on `RestaurantProvider`).
- **Interactive floor map & sector "check-in"** (Map tab, `sector/` + `ru/`): a restaurant has numbered **sectors** (auto-incremented `sectorId` per restaurant via `mongoose-sequence`). A user "sits" in a sector for a chosen duration (`SectorSession` with `expiresAt` TTL) and can see which **friends** are currently in each sector. Sessions auto-expire. Backend exposes friends-only and all-users variants of sector occupancy.
- **Friend system** (Friends tab, `user/`): user search (relevance-scored: exact > prefix > substring > Levenshtein distance), send / accept / decline friend requests, remove friend. Sending a request when a reverse request already exists auto-accepts (mutual). Friendship is stored as a symmetric `friends[]` array on both users.
- **Real-time chat** (Messages tab, `socket/`): Socket.IO with JWT auth at handshake. A persistent **Global** room (all users) plus 1-to-1 **private rooms** (deterministic name = sorted `userId_userId`). Access is enforced by `resolveRoomForUser` (`socket.service.ts`): Global is open to every account, a private room only to its two participants, and a missing private room is created on the fly only if both users are friends. Messages persisted in Mongo; history = 50 most recent, paginated with `before`. Text 1–2000 chars, audio messages via `send-audio`. Delete-one: author or admin/moderator only; delete-all: participants for a private room, staff only for Global. Every socket joins a personal room `user:<id>` (multi-device); presence = `SocketHandler.connectedUsers` (`Map<userId, Set<socketId>>`).
- **Bus schedules** (Bus tab, `ginko/`): queries the Ginko (Besançon transit) API for next departures at a stop, grouped by line → destination. `GET /api/ginko/info`.
- **Profile** (Profile tab, `user/`): update username / password / status, upload avatar (Multer → Sharp JPEG compression). Statuses: "en ligne", "au ru", "absent".
- **Bug reporting / feedback** (bug icon, `feedback` package + `user/`): in-app `BetterFeedback` overlay lets users annotate a screenshot; submitted via `POST /api/users/send-bug-report` with app version + platform. Open to guests (`optionalAuth`: anonymous without token, 403 on an invalid token; dedicated limiter 10 / 15 min). Reports are reviewed in the AdminJS dashboard.
- **Debug tab**: only shown in development (`Config.env == "development"`).

### API reference (all under `/api`, JWT-protected unless noted)
- `auth/`: `POST /register` (public ; `restaurantId` optionnel : id CROUS `rXXX` ou ObjectId), `POST /login` (public ; identifiants faux → 401 `{ error: { message: 'Invalid credentials', field: 'password' } }`), `POST /token` (refresh), `POST /logout`, `DELETE /delete-account`
- `users/`: `GET /me` (`restaurantId` = id CROUS), `PUT /update-username|update-password|update-status|update-restaurant`, `PUT /update-profile-picture` (multipart), `GET /friends`, `GET /search?query=`, `DELETE /remove-friend`, `GET /friend-requests`, `POST /send-friend-request|accept-friend-request|decline-friend-request`, `POST /send-bug-report` (multipart, token optionnel)
- `ru/`: `GET /` (api doc, public), `GET /menus?restaurantId=rXXX`, `GET /restaurants` (catalogue CROUS complet, id officiel exposé), `POST /restaurants/sync` (auth, re-sync forcé), `GET /:restaurantId` (accepte ObjectId ou id CROUS), `GET /:restaurantId/info`, `GET /:restaurantId/sectors`, `GET /:restaurantId/sectors-sessions` (friends), `GET /:restaurantId/sectors-sessions/all`
- `sectors/`: `POST /join/:sectorId` (body: `duration`), `POST /leave/:sectorId`, `GET /:sectorId/friends`
- `socket/` (chat REST side): `POST /send-message`, `POST /send-audio` (multipart), `GET /messages?roomName=&before=` (→ `{ messages, hasMore }`), `GET /conversations`, `DELETE /delete-message?roomName=&messageId=`, `DELETE /delete-all-messages?roomName=` — 403 when the user has no access to the room
- `ginko/`: `GET /info`
- Other: `GET /api/health`, `GET /api/uploads/*` (static files), `/admin` (AdminJS), `/api-docs` (Swagger), `/test-socket`

### Socket.IO events
- Auth: JWT passed via `handshake.auth.token` (or query), verified against `JWT_ACCESS_SECRET`; `socket.data.userId` set on success.
- Client → server: `join_global_room`, `join_room` (payload: `{ participants: [userId, userId] }` — exactement 2, l'émetteur doit en faire partie), `leave_room`.
- Server → client: `room_joined`, `room_left`, `receive_message` (`{ roomName, message }`), `notify_message` (`{ roomName, message }`, cross-room, pour les non-lus), `receive_delete_message` (`{ roomName, messageId }`), `receive_delete_all_messages` (`{ roomName }`), `userOffline`, `error`. Room events go to everyone in the room except the sender's own sockets (`io.to(room).except('user:<id>')`). Message payload: `id, content, username, userId, avatarUrl, createdAt, audioUrl?, duration?`.
- The Socket.IO admin UI (`instrument`) is only enabled outside production.

### Data Flow
1. Flutter `ApiClient` (Dio) → Express routes → MongoDB (Mongoose)
2. Real-time: Flutter `socket_io_client` ↔ Express Socket.IO (JWT auth at handshake)
3. Token refresh: Dio interceptor catches 401 → calls refresh endpoint → retries original request → on failure, logs out user

## Testing
- Backend tests: Jest + ts-jest, `.spec.ts` files colocated with routes + `src/tests/`. ESM module support configured in `jest.config.js`. As of 2026-10-05: **198 tests pass across 24 suites**, and `tsc --noEmit` is clean. Tests use `mongodb-memory-server` + `supertest` and need the CI env vars (`NODE_ENV=test`, dummy `MONGO_URI` / JWT secrets / `GINKO_API_KEY`, see `ci-cd.yml`). Chat access rules are covered end-to-end in `routes/socket/chat.spec.ts`.
- Flutter tests (`flutter/test/`, `flutter test`): 36 tests — chat connection (fake socket), notifications, message model, providers, navigation scaffold (incl. guest mode).
- CI/CD : `.github/workflows/ci-cd.yml` — à chaque push `main` : tests Jest + build backend, analyse Flutter + builds APK/web, puis déploiement par **artefacts** (rsync du JS compilé + bundle web vers le serveur ; aucun build ni git sur le serveur, `npm ci --omit=dev` + `pm2 restart` seulement). Web servi sur `ru.leomaugeri.fr`, API derrière `api.ru.leomaugeri.fr`. Secret unique requis : `SSH_PRIVATE_KEY` (constant serveur en dur dans le workflow).
- Lint: backend `eslint` (flat config, TS + stylistic), Flutter `flutter analyze` (flutter_lints). Coverage and lint debt are tracked in `AUDIT.md`.

## Key Conventions
- Backend route pattern: `routes/{domain}/controller.ts` + `routes/{domain}/service.ts`
- API responses use consistent error format with field-level error info
- User statuses: "en ligne", "au ru", "absent"
- User roles: "user", "admin", "moderator"
- Socket events follow room-based broadcasting pattern
- Image uploads are compressed via Sharp before storage

> A standalone code/security audit lives in `AUDIT.md` (root). Keep it separate from this file.
