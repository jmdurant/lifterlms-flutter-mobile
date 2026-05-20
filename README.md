# LifterLMS Mobile Platform

An AI-powered LifterLMS course delivery platform spanning mobile, TV, and web — with an MCP server for AI-assisted course authoring. Built for rapid generation and delivery of CME (Continuing Medical Education) content.

## Components

| Directory | Stack | Role |
|---|---|---|
| `lib/` | Flutter (Dart, GetX) | iOS / Android / Web learner app |
| `lifterlms-tv/` | React Native tvOS | Apple TV / Fire TV / Google TV app |
| `lifterlms-mobile-app/` | WordPress plugin (PHP) | Server-side REST API, CME credits, IAP, push, social login, certificates |
| `mcp-lifterlms/` | Node.js MCP server | AI course authoring tools (course CRUD, PowerPoint import/export, AI image/video, CME scaffolding) |

All four components talk to a single WordPress + LifterLMS site. The WordPress plugin defines the `llms/v1/mobile-app/*` REST surface that the Flutter and TV clients consume.

## Setup

### 1. WordPress backend

On your WordPress site:

1. Install and activate **LifterLMS**.
2. Install and activate the **LifterLMS Mobile App** plugin from `lifterlms-mobile-app/` (zip the folder and upload, or symlink during development).
3. Install **JWT Authentication for WP REST API** for user login support, and add to `wp-config.php`:
   ```php
   define('JWT_AUTH_SECRET_KEY', 'your-secret-key');
   define('JWT_AUTH_CORS_ENABLE', true);
   ```
4. Generate a LifterLMS REST API key at **WP Admin → LifterLMS → Settings → REST API → Add Key** with Read/Write permissions. Save the consumer key and secret.

### 2. Flutter app

Copy `.env.example` to `.env` at the repo root and fill in your LifterLMS site URL and consumer key/secret:

```bash
cp .env.example .env
# edit .env
flutter pub get
flutter run
```

The `.env` file is gitignored and bundled into the build at compile time via `flutter_dotenv`. Note: anything in `.env` ships inside the compiled binary and is extractable — treat the consumer key as semi-public and rely on LifterLMS user permissions / rate limiting for real security.

### 3. TV app

See [`lifterlms-tv/README.md`](lifterlms-tv/README.md). Requires `react-native-tvos` and a tvOS/Android TV target.

### 4. MCP server

See [`mcp-lifterlms/README.md`](mcp-lifterlms/README.md) for installation and the full tool list. Add to your Claude Code config with the same LifterLMS consumer key/secret, plus optional Gemini and Unsplash keys for AI image generation.

## Further reading

- [`docs/CME-ACCREDITATION-STRATEGY.md`](docs/CME-ACCREDITATION-STRATEGY.md) — ACCME / ANCC accreditation strategy via Duke and UNC
- [`docs/REFACTOR_HISTORY.md`](docs/REFACTOR_HISTORY.md) — history of the LearnPress → LifterLMS migration and GetX consolidation, plus remaining deferred work
