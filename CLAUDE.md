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
- **Entry**: `main.dart` — MultiProvider setup (UserProvider, RestaurantProvider, MenuProvider).
- **State**: Provider pattern with ChangeNotifier (`providers/`).
- **Services** (`services/`): `api_client.dart` wraps Dio with JWT interceptor (auto-refresh on 401). Domain services: auth, user, friend, restaurant, socket, ginko, feedback.
- **Token storage**: `flutter_secure_storage` for encrypted token persistence.
- **Widgets** (`widgets/`): `tab_bar_widget.dart` is the main authenticated view with 7 tabs: Map, Menu, Friends, Chat, Profile, Bus, Debug. Auth screens in `welcome/`.
- **Config** (`config.dart`): Switches API URLs based on `kReleaseMode` (production vs development).
- **Localization**: French (FR) — Material & Cupertino delegates.
- **Font**: Marianne (custom).

### Data Flow
1. Flutter `ApiClient` (Dio) → Express routes → MongoDB (Mongoose)
2. Real-time: Flutter `socket_io_client` ↔ Express Socket.IO (JWT auth at handshake)
3. Token refresh: Dio interceptor catches 401 → calls refresh endpoint → retries original request → on failure, logs out user

## Testing
- Backend tests: Jest + ts-jest, 19 `.spec.ts` files in `backend/src/tests/`. ESM module support configured in `jest.config.js`.
- No Flutter tests currently configured.
- No CI/CD pipeline — manual deployment.

## Key Conventions
- Backend route pattern: `routes/{domain}/controller.ts` + `routes/{domain}/service.ts`
- API responses use consistent error format with field-level error info
- User statuses: "en ligne", "au ru", "absent"
- User roles: "user", "admin", "moderator"
- Socket events follow room-based broadcasting pattern
- Image uploads are compressed via Sharp before storage
