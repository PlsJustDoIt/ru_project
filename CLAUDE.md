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
Backend requires `.env` in `backend/` with: `MONGO_URI`, `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`, `GINKO_API_KEY`, `NODE_ENV`.

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
- **Entry**: `main.dart` — services are instantiated manually and injected into a `MultiProvider`. `ChangeNotifierProvider`: `UserProvider`, `RestaurantProvider`. Plain `Provider`: the services + `SecureStorage` + `ApiClient`. (`providers/menu_provider.dart` exists but is **not** wired up — see `AUDIT.md`.)
- **State**: Provider pattern with ChangeNotifier (`providers/`). `UserProvider.init()` runs at startup to restore session, load friends, and the user's restaurant.
- **Services** (`services/`): `api_client.dart` wraps Dio with JWT interceptor (auto-refresh on 401/403, retries once, logs out on `/auth/token` failure). Domain services: auth, user, friend, restaurant, socket, ginko, feedback. All share the one Dio instance from `ApiClient`.
- **Token storage**: `flutter_secure_storage` for encrypted token persistence.
- **Widgets** (`widgets/`): `tab_bar_widget.dart` is the main authenticated view with 7 tabs: Map, Menu, Friends, Chat, Profile, Bus, Debug. Auth screens in `welcome/`.
- **Config** (`config.dart`): Switches API URLs based on `kReleaseMode` (production vs development).
- **Localization**: French (FR) — Material & Cupertino delegates.
- **Font**: Marianne (custom).

## Features

Each feature maps to a Flutter tab/screen and a backend route domain.

- **Auth & account** (`welcome/`, `auth/`): register / login / logout, JWT access (1h) + refresh (7d) tokens, token refresh, account deletion (also deletes the avatar file). Passwords bcrypt-hashed (salt 10) via a Mongoose `pre('save')` hook; credentials validated 3–32 chars.
- **Restaurant menus** (Menu tab, `ru/`): pulls the CROUS menu XML feed, parses it (`xml2js`), caches results 1 week in `node-cache`, and serves only today-and-later menus. `GET /api/ru/menus`.
- **Interactive floor map & sector "check-in"** (Map tab, `sector/` + `ru/`): a restaurant has numbered **sectors** (auto-incremented `sectorId` per restaurant via `mongoose-sequence`). A user "sits" in a sector for a chosen duration (`SectorSession` with `expiresAt` TTL) and can see which **friends** are currently in each sector. Sessions auto-expire. Backend exposes friends-only and all-users variants of sector occupancy.
- **Friend system** (Friends tab, `user/`): user search (relevance-scored: exact > prefix > substring > Levenshtein distance), send / accept / decline friend requests, remove friend. Sending a request when a reverse request already exists auto-accepts (mutual). Friendship is stored as a symmetric `friends[]` array on both users.
- **Real-time chat** (Chat tab, `socket/`): Socket.IO with JWT auth at handshake. A persistent **Global** room (all users) plus 1-to-1 **private rooms** (deterministic name = sorted `userId_userId`). Messages persisted in Mongo (last 50 fetched). Supports send, delete-one, delete-all. Online/offline presence tracked in-memory (`SocketHandler.connectedUsers`).
- **Bus schedules** (Bus tab, `ginko/`): queries the Ginko (Besançon transit) API for next departures at a stop, grouped by line → destination. `GET /api/ginko/info`.
- **Profile** (Profile tab, `user/`): update username / password / status, upload avatar (Multer → Sharp JPEG compression). Statuses: "en ligne", "au ru", "absent".
- **Bug reporting / feedback** (bug icon, `feedback` package + `user/`): in-app `BetterFeedback` overlay lets users annotate a screenshot; submitted via `POST /api/users/send-bug-report` with app version + platform. Reports are reviewed in the AdminJS dashboard.
- **Debug tab**: only shown in development (`Config.env == "development"`).

### API reference (all under `/api`, JWT-protected unless noted)
- `auth/`: `POST /register` (public), `POST /login` (public), `POST /token` (refresh), `POST /logout`, `DELETE /delete-account`
- `users/`: `GET /me`, `PUT /update-username|update-password|update-status`, `PUT /update-profile-picture` (multipart), `GET /friends`, `GET /search?query=`, `DELETE /remove-friend`, `GET /friend-requests`, `POST /send-friend-request|accept-friend-request|decline-friend-request`, `POST /send-bug-report` (multipart)
- `ru/`: `GET /` (api doc, public), `GET /menus`, `GET /restaurants`, `GET /:restaurantId`, `GET /:restaurantId/info`, `GET /:restaurantId/sectors`, `GET /:restaurantId/sectors-sessions` (friends), `GET /:restaurantId/sectors-sessions/all`
- `sectors/`: `POST /join/:sectorId` (body: `duration`), `POST /leave/:sectorId`, `GET /:sectorId/friends`
- `socket/` (chat REST side): `POST /send-message`, `GET /messages?roomName=`, `DELETE /delete-message`, `DELETE /delete-all-messages`
- `ginko/`: `GET /info`
- Other: `GET /api/health`, `GET /api/uploads/*` (static files), `/admin` (AdminJS), `/api-docs` (Swagger), `/test-socket`

### Socket.IO events
- Auth: JWT passed via `handshake.auth.token` (or query), verified against `JWT_ACCESS_SECRET`; `socket.data.userId` set on success.
- Client → server: `join_global_room`, `join_room` (payload: `[userId, userId]`), `leave_room`.
- Server → client: `room_joined`, `room_left`, `receive_message`, `receive_delete_message`, `receive_delete_all_messages`, `userOffline`, `error`.

### Data Flow
1. Flutter `ApiClient` (Dio) → Express routes → MongoDB (Mongoose)
2. Real-time: Flutter `socket_io_client` ↔ Express Socket.IO (JWT auth at handshake)
3. Token refresh: Dio interceptor catches 401 → calls refresh endpoint → retries original request → on failure, logs out user

## Testing
- Backend tests: Jest + ts-jest, 15 `.spec.ts` files (colocated with routes + `src/tests/`). ESM module support configured in `jest.config.js`. As of 2026-05-29: **158 tests pass across 15 suites**, and `tsc --noEmit` is clean. Tests use `mongodb-memory-server` + `supertest`.
- No Flutter tests currently configured.
- No CI/CD pipeline — manual deployment.
- Lint: backend `eslint` (flat config, TS + stylistic), Flutter `flutter analyze` (flutter_lints). Coverage and lint debt are tracked in `AUDIT.md`.

## Key Conventions
- Backend route pattern: `routes/{domain}/controller.ts` + `routes/{domain}/service.ts`
- API responses use consistent error format with field-level error info
- User statuses: "en ligne", "au ru", "absent"
- User roles: "user", "admin", "moderator"
- Socket events follow room-based broadcasting pattern
- Image uploads are compressed via Sharp before storage

> A standalone code/security audit lives in `AUDIT.md` (root). Keep it separate from this file.
