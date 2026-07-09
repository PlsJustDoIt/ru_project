# Migration domaine + séparation admin — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate prod to `api.ru.leomaugeri.fr`, extract AdminJS into its own
Node process served on `admin.ru.leomaugeri.fr`, and clean up every
`/admin`-related trace left in the main API process.

**Architecture:** A new entry point `backend/src/adminServer.ts` runs AdminJS
standalone (own Express app, own Mongo connection, own port `ADMIN_PORT`,
default `5001`), reusing the existing models/config from the same repo. The
main API (`backend/src/server.ts`, port `5000`) loses every `/admin` route,
middleware exception, and the `adminJsSetup` call. Socket.IO stays untouched
on the main API process. nginx (outside this repo, applied manually on the
prod server) routes each subdomain to its port.

**Tech Stack:** Express 5, AdminJS 7, Mongoose 8, TypeScript (ESM, `tsx`),
Jest + ts-jest, Flutter/Dart.

## Global Constraints

- Backend uses npm (not yarn).
- Keep mongoose on 8.x — `@adminjs/mongoose` is abandoned and crashes on
  mongoose 9. Do not touch the mongoose version in this work.
- `npm test` (158 tests / 15 suites as of 2026-05-29) and `tsc --noEmit` must
  stay green after every task.
- No test currently exercises `/admin` routes — confirmed via
  `grep -rl "'/admin` across `backend/src/**/*.spec.ts"` (no match). Don't
  add admin route tests unless a task below says so explicitly.
- Don't touch `@socket.io/admin-ui` (`utils/socket.ts`) — different tool from
  AdminJS, out of scope, stays on the main API process.
- Don't touch Socket.IO paths/events — no bug there, only the domain changes
  (handled by the Flutter config task).

---

### Task 1: Fix `handleImageRequest` for cross-domain redirects

**Context:** AdminJS's file-preview components (avatar, bug-report
screenshot) hit a route that 302-redirects to the real upload file. Today
`res.redirect('/api/uploads/...')` is a **relative** redirect — it works only
because AdminJS and the API currently share the same origin. Once AdminJS
moves to `admin.ru.leomaugeri.fr` (Task 2) while uploads stay served from
`api.ru.leomaugeri.fr`, a relative redirect would resolve against
`admin.ru.leomaugeri.fr` and 404. This task must land first so Task 2 can
build on a working absolute redirect.

**Files:**
- Modify: `backend/src/config.ts`
- Modify: `backend/src/middleware/imageHandler.ts`
- Test: `backend/src/middleware/imageHandler.spec.ts` (new)

**Interfaces:**
- Produces: `apiPublicUrl: string` exported from `backend/src/config.ts` —
  the public base URL of the main API (e.g. `https://api.ru.leomaugeri.fr` in
  prod, `http://localhost:5000` in dev), no trailing slash.
- Consumes (Task 2): `handleImageRequest` keeps its existing signature
  `(req: Request, res: Response) => void`, now redirecting to an absolute
  URL built from `apiPublicUrl`.

- [ ] **Step 1: Write the failing test**

Create `backend/src/middleware/imageHandler.spec.ts`:

```ts
import { Request, Response } from 'express';

jest.mock('../config.js', () => ({
    apiPublicUrl: 'https://api.ru.leomaugeri.fr',
}));

import { handleImageRequest } from './imageHandler.js';

describe('handleImageRequest', () => {
    const buildRes = () => {
        const res = { redirect: jest.fn() } as unknown as Response;
        return res;
    };

    it('redirects to an absolute URL under /api/uploads for a bare file path', () => {
        const req = { params: { path: 'avatar/foo.jpg' } } as unknown as Request;
        const res = buildRes();

        handleImageRequest(req, res);

        expect(res.redirect).toHaveBeenCalledWith(
            'https://api.ru.leomaugeri.fr/api/uploads/avatar/foo.jpg',
        );
    });

    it('redirects to an absolute URL preserving a path that already starts with uploads/', () => {
        const req = { params: { path: 'uploads/avatar/foo.jpg' } } as unknown as Request;
        const res = buildRes();

        handleImageRequest(req, res);

        expect(res.redirect).toHaveBeenCalledWith(
            'https://api.ru.leomaugeri.fr/uploads/avatar/foo.jpg',
        );
    });

    it('joins an array path param with slashes', () => {
        const req = { params: { path: ['avatar', 'foo.jpg'] } } as unknown as Request;
        const res = buildRes();

        handleImageRequest(req, res);

        expect(res.redirect).toHaveBeenCalledWith(
            'https://api.ru.leomaugeri.fr/api/uploads/avatar/foo.jpg',
        );
    });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && npx jest src/middleware/imageHandler.spec.ts`
Expected: FAIL — `apiPublicUrl` doesn't exist yet in `config.ts`, and the
current implementation redirects to a relative path (`/api/uploads/...`),
not the absolute URL asserted above.

- [ ] **Step 3: Add `apiPublicUrl` to config**

In `backend/src/config.ts`, add this constant next to the other derived
values (after `const uploadsPath = ...` and friends, before the `export`
block):

```ts
// URL publique de l'API (celle que les navigateurs voient), utilisée pour
// construire des redirections absolues depuis le process admin (autre
// domaine). En prod, poser API_PUBLIC_URL=https://api.ru.leomaugeri.fr.
const apiPublicUrl = process.env.API_PUBLIC_URL || 'http://localhost:5000';
```

Add `apiPublicUrl` to the `export { ... }` list at the bottom of the file.

- [ ] **Step 4: Update `handleImageRequest`**

Replace the full contents of `backend/src/middleware/imageHandler.ts`:

```ts
import { Request, Response } from 'express';
import { apiPublicUrl } from '../config.js';

export const handleImageRequest = (req: Request, res: Response) => {
    const filePath = Array.isArray(req.params.path) ? req.params.path.join('/') : req.params.path;
    const finalPath = filePath.startsWith('uploads/') ? filePath : `api/uploads/${filePath}`;
    res.redirect(`${apiPublicUrl}/${finalPath}`);
};
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd backend && npx jest src/middleware/imageHandler.spec.ts`
Expected: PASS (3 tests).

- [ ] **Step 6: Run the full backend suite to confirm no regression**

Run: `cd backend && npm test`
Expected: all 15 suites still pass (158+ tests — one new spec file adds 3).

- [ ] **Step 7: Commit**

```bash
git add backend/src/config.ts backend/src/middleware/imageHandler.ts backend/src/middleware/imageHandler.spec.ts
git commit -m "fix(backend): redirection absolue pour les images admin (cross-domaine)"
```

---

### Task 2: Extract AdminJS into its own process

**Context:** Moves AdminJS off the main API process entirely. `admin.ts`'s
`rootPath` becomes `/` (the subdomain is fully dedicated to it), a new
`adminServer.ts` entry point boots it standalone on `ADMIN_PORT` (default
`5001`), and every `/admin` trace is removed from `app.ts`/`server.ts`. This
is one task (not split further) because `admin.ts`'s `rootPath` change only
makes sense together with removing the old mount point — landing them
separately would leave AdminJS double-mounted or unreachable.

**Files:**
- Modify: `backend/src/modules/admin.ts`
- Modify: `backend/src/app.ts`
- Modify: `backend/src/server.ts`
- Create: `backend/src/adminServer.ts`
- Modify: `backend/package.json`

**Interfaces:**
- Consumes (from Task 1): `handleImageRequest` from
  `backend/src/middleware/imageHandler.ts` (now redirects absolutely via
  `apiPublicUrl`).
- Produces: `adminJsSetup: (app: Express) => Promise<void>` (unchanged
  signature, exported default from `backend/src/modules/admin.ts`), now
  mounting AdminJS at `/` instead of `/admin`. `backend/src/adminServer.ts`
  is a standalone runnable module (`tsx watch src/adminServer.ts` /
  `node dist/adminServer.js`), no exports consumed elsewhere.

- [ ] **Step 1: Update `admin.ts` — rootPath and dead code**

In `backend/src/modules/admin.ts`:

1. Change `rootPath: '/admin',` to `rootPath: '/',` (inside the `new AdminJS({...})` call).
2. Delete these two lines (the dead `customRouter` — declared but never
   mounted anywhere):

```ts
const customRouter = express.Router();
```

and, further down:

```ts
customRouter.use(admin.options.rootPath, adminRouter);

logger.info(`admin JS running on http://localhost:${5000}${admin.options.rootPath}`);
```

3. In `adminJsSetup`, update the static mount (it hardcoded `/admin`, now the
   whole app is AdminJS so mount at the root):

```ts
const adminJsSetup = async (app: Express) => {
    app.use(admin.options.rootPath, adminRouter);
    if (isProduction) {
        await admin.initialize();
        app.use(express.static(join(rootDir, '.adminjs')));
    } else {
        admin.watch();
    }
};

export default adminJsSetup;
```

(`express` default import stays — `express.static` still needs it; `Express`
type import stays too.)

- [ ] **Step 2: Create `backend/src/adminServer.ts`**

```ts
import express from 'express';
import helmet from 'helmet';
import compression from 'compression';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';
import { connect } from 'mongoose';
import { createWriteStream } from 'fs';
import { join } from 'path';
import logger from './utils/logger.js';
import { isProduction, mongoUri, rootDir } from './config.js';
import { handleImageRequest } from './middleware/imageHandler.js';
import adminJsSetup from './modules/admin.js';

const app = express();

app.use(helmet({ contentSecurityPolicy: false }));
app.use(compression());

// Limiteur anti-brute-force dédié au login admin (même politique que
// l'ancien /admin/login sur le process API).
const authLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: 10,
    standardHeaders: 'draft-7',
    legacyHeaders: false,
    handler: (req, res) => {
        logger.error(`Too many admin login attempts from ${req.ip}`);
        return res.status(429).json({ error: 'Too many attempts, please try again later.' });
    },
});
app.use('/login', authLimiter);

// Routes de redirection vers les fichiers uploadés, référencées par les
// composants AdminJS (avatar, screenshot de bug report).
app.use('/resources/:model/records/:recordId/uploads/*path', handleImageRequest);
app.use('/resources/uploads/*path', handleImageRequest);

if (isProduction) {
    const accessLogStream = createWriteStream(join(rootDir, 'logs', 'admin-access.log'), { flags: 'a+' });
    app.use(morgan('combined', { stream: accessLogStream }));
} else {
    app.use(morgan('dev'));
}

connect(mongoUri)
    .then(() => logger.info('MongoDB Connected (admin)'))
    .catch(err => logger.error('MongoDB connection error (admin):', err));

adminJsSetup(app);

const ADMIN_PORT = process.env.ADMIN_PORT || 5001;
app.listen(ADMIN_PORT, () => {
    logger.info(`Admin server running on port ${ADMIN_PORT}`);
});

export default app;
```

- [ ] **Step 3: Remove admin traces from `app.ts`**

In `backend/src/app.ts`:

1. Delete the import (line 11): `import { handleImageRequest } from './middleware/imageHandler.js';`
2. In the global `limiter`, delete the `skip` option entirely (and its
   comment) so the object becomes:

```ts
const limiter = rateLimit({
    windowMs: 1 * 60 * 1000, // 1 minute
    limit: 50, // Limit each IP to 50 requests per windows
    standardHeaders: 'draft-7', // draft-6: `RateLimit-*` headers; draft-7: combined `RateLimit` header
    legacyHeaders: false, // Disable the `X-RateLimit-*` headers.
    handler: (req, res) => {
        logger.error('Too many requests, please try again later.');
        return res.status(429).json({ error: 'Too many requests, please try again later.' });
    },
});
```

3. Delete the line `app.use('/admin/login', authLimiter);` (keep the two
   `/api/auth/...` lines above it).
4. Delete the entire `// Image handling routes` block (all 8
   `app.use(...handleImageRequest)` lines — every one of them was either
   `/admin`-prefixed or an unused `/api/resources/...` variant; none of them
   apply to the main API anymore).

- [ ] **Step 4: Remove `adminJsSetup` from `server.ts`**

In `backend/src/server.ts`:
1. Delete the import: `import adminJsSetup from './modules/admin.js';`
2. Delete the call: `adminJsSetup(app);`

- [ ] **Step 5: Add the `dev:admin` npm script**

In `backend/package.json`, add to `"scripts"`:

```json
"dev:admin": "tsx watch src/adminServer.ts",
```

(alongside the existing `"dev": "tsx watch src/server.ts"`.)

- [ ] **Step 6: Typecheck and run the full backend suite**

Run: `cd backend && npx tsc --noEmit`
Expected: no errors (in particular: no "declared but never used" on
`customRouter`, `handleImageRequest` unused import in `app.ts`, etc.).

Run: `cd backend && npm test`
Expected: all suites still pass — no test exercises `/admin`, so removing it
from `app.ts`/`server.ts` doesn't touch any assertion.

- [ ] **Step 7: Manual smoke test — both processes boot and serve the right things**

Run in one terminal: `cd backend && ADMIN_PORT=5001 npx tsx watch src/adminServer.ts`
Expected log: `Admin server running on port 5001`, then, a moment later,
`MongoDB Connected (admin)`.

Run in another terminal: `curl -i http://localhost:5001/login`
Expected: `200` (or a redirect into AdminJS's login page) — **not** 404.

In a third terminal, confirm the main API no longer serves admin at all:
`cd backend && npx tsx watch src/server.ts` then
`curl -i http://localhost:5000/admin` and `curl -i http://localhost:5000/admin/login`.
Expected: both `404` (no route matches — `/admin` is entirely gone from this
process).

Also confirm the main API still works normally:
`curl -i http://localhost:5000/api/health`
Expected: `200 {"message":"API is alive !"}`.

- [ ] **Step 8: Commit**

```bash
git add backend/src/modules/admin.ts backend/src/app.ts backend/src/server.ts backend/src/adminServer.ts backend/package.json
git commit -m "feat(backend): sépare AdminJS dans son propre process (admin.ru.leomaugeri.fr)"
```

---

### Task 3: nginx example configs for the two subdomains

**Context:** Documents the reverse-proxy setup needed on the prod server for
`api.ru.leomaugeri.fr` (port 5000, with websocket upgrade on `/socket.io/`)
and `admin.ru.leomaugeri.fr` (port 5001, plain HTTP proxy). These files are
committed as reference/templates — nothing in this task touches the actual
prod server (no access to it from this session).

**Files:**
- Create: `nginx/api.ru.leomaugeri.fr.conf.example`
- Create: `nginx/admin.ru.leomaugeri.fr.conf.example`

**Interfaces:** None — these are standalone deployment artifacts, not
imported by any code.

- [ ] **Step 1: Write `nginx/api.ru.leomaugeri.fr.conf.example`**

```nginx
# Exemple de config nginx pour api.ru.leomaugeri.fr — à adapter et poser
# manuellement sur le serveur (ex. /etc/nginx/sites-available/), puis
# `ln -s` dans sites-enabled et `nginx -t && systemctl reload nginx`.
# Certificats TLS à obtenir via certbot :
#   certbot --nginx -d api.ru.leomaugeri.fr

server {
    listen 80;
    server_name api.ru.leomaugeri.fr;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name api.ru.leomaugeri.fr;

    ssl_certificate     /etc/letsencrypt/live/api.ru.leomaugeri.fr/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.ru.leomaugeri.fr/privkey.pem;

    # Connexion Socket.IO : nécessite la propagation des en-têtes d'upgrade
    # websocket, sinon le client retombe en long-polling (ou échoue).
    location /socket.io/ {
        proxy_pass http://127.0.0.1:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

- [ ] **Step 2: Write `nginx/admin.ru.leomaugeri.fr.conf.example`**

```nginx
# Exemple de config nginx pour admin.ru.leomaugeri.fr — à adapter et poser
# manuellement sur le serveur. Certificats via certbot :
#   certbot --nginx -d admin.ru.leomaugeri.fr

server {
    listen 80;
    server_name admin.ru.leomaugeri.fr;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name admin.ru.leomaugeri.fr;

    ssl_certificate     /etc/letsencrypt/live/admin.ru.leomaugeri.fr/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/admin.ru.leomaugeri.fr/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:5001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

- [ ] **Step 3: Sanity-check nginx syntax locally**

Local `nginx` is installed (`nginx/1.24.0`) — wrap both files in a throwaway
`http{}` context to validate syntax without touching the system config:

```bash
tmpdir=$(mktemp -d)
cat > "$tmpdir/nginx.conf" <<EOF
events {}
http {
    include $(pwd)/nginx/api.ru.leomaugeri.fr.conf.example;
    include $(pwd)/nginx/admin.ru.leomaugeri.fr.conf.example;
}
EOF
nginx -t -c "$tmpdir/nginx.conf"
rm -rf "$tmpdir"
```

Expected: `nginx: configuration file ... test is successful` (ignore any
`ssl_certificate` file-not-found complaint if nginx also validates file
existence — swap in `ssl_certificate /dev/null;` / a self-signed dummy pair
in the temp copy only if `nginx -t` refuses to proceed past that; the goal
here is syntax validity, not a working TLS handshake).

- [ ] **Step 4: Commit**

```bash
git add nginx/api.ru.leomaugeri.fr.conf.example nginx/admin.ru.leomaugeri.fr.conf.example
git commit -m "docs: exemples de config nginx pour api./admin.ru.leomaugeri.fr"
```

---

### Task 4: Update Flutter to the new domain

**Context:** `flutter/lib/config.dart` is the only file in the whole repo
referencing the old domain (`ru.api.mehmetates.fr`) — confirmed by a
repo-wide grep across `.ts`/`.dart`/`.js`/`.json` in Task-planning research.
`serverUrl` is also what `ChatConnection`/`IoChatSocket`
(`flutter/lib/services/chat_connection.dart:24`) uses for the Socket.IO
connection, so this single change covers both REST and websocket traffic.

**Files:**
- Modify: `flutter/lib/config.dart`

**Interfaces:** None — `Config.apiUrl` / `Config.serverUrl` keep their
existing `static final String` type, only the literal value changes.

- [ ] **Step 1: Update the production URLs**

In `flutter/lib/config.dart`, replace:

```dart
  static final String apiUrl = env == "production"
      ? "https://ru.api.mehmetates.fr/api"
      : "http://localhost:5000/api";

  static final String serverUrl = env == "production"
      ? "https://ru.api.mehmetates.fr/"
      : "http://localhost:5000";
```

with:

```dart
  static final String apiUrl = env == "production"
      ? "https://api.ru.leomaugeri.fr/api"
      : "http://localhost:5000/api";

  static final String serverUrl = env == "production"
      ? "https://api.ru.leomaugeri.fr/"
      : "http://localhost:5000";
```

- [ ] **Step 2: Confirm no other reference to the old domain remains**

Run: `grep -rn "mehmetates" /home/leo/DOCS/ru_project --include="*.dart" --include="*.ts" --include="*.js" --include="*.json" 2>/dev/null | grep -v node_modules`
Expected: no output.

- [ ] **Step 3: Static-analyze Flutter**

Run: `cd flutter && flutter analyze lib/config.dart`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add flutter/lib/config.dart
git commit -m "fix(flutter): pointe la config prod vers api.ru.leomaugeri.fr"
```

---

## Post-plan deployment notes (not executed by these tasks — no server access)

On the actual prod server, once these commits are deployed:
1. DNS: point `api.ru.leomaugeri.fr` and `admin.ru.leomaugeri.fr` at the
   server.
2. `certbot --nginx -d api.ru.leomaugeri.fr` and
   `certbot --nginx -d admin.ru.leomaugeri.fr`, using `nginx/*.conf.example`
   from Task 3 as a starting point (drop the `.example` suffix once adapted
   with real cert paths — certbot usually rewrites the `ssl_certificate*`
   lines itself).
3. Add to the prod `.env`: `ADMIN_PORT=5001`,
   `API_PUBLIC_URL=https://api.ru.leomaugeri.fr`, and update
   `CORS_ORIGINS` to include `https://api.ru.leomaugeri.fr` (and any web
   frontend origin still in use).
4. `git pull && npm run build` in `backend/`, then start/restart **two** pm2
   processes: `pm2 restart ru_project` (main API, unchanged) and
   `pm2 start dist/adminServer.js --name ru_project_admin` (first time) or
   `pm2 restart ru_project_admin` (subsequent deploys).
5. Do **not** set `SSL_KEY_PATH`/`SSL_CERT_PATH` in prod for either process —
   nginx terminates TLS; both processes serve plain HTTP (see
   [[project_prod_deploy]]).
