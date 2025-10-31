# API Traffic Logging

## Overview
The Flutter shell now wraps all `http` traffic in a `LoggingHttpClient` so you can inspect live request/response payloads while debugging complex LLM interactions. Events are emitted into two channels simultaneously:

1. **Dart DevTools / Console** – Structured JSON is logged under the logger name `api.traffic`, making it easy to filter and copy exact payloads.
2. **In-App Access** – The `ApiTrafficRecorder` keeps a bounded in-memory history (`Provider` exposes it at the root). You can hook this into any diagnostics UI without additional plumbing.

## How To Use
1. Launch the app with `flutter run -d macos` (or the platform of your choice).
2. Open Dart DevTools and switch to the **Logging** tab.
3. Filter by `api.traffic` to see events grouped by `requestId`.
   - The first log for each id is the outbound request (method, URL, headers, JSON body).
   - Intermediate logs (optional) show streaming chunks when the response is SSE.
   - The final log captures status, headers, total latency, and the entire response body.
4. Copy/paste payloads directly from the log entries; they retain raw JSON formatting.

## Extending In-App Diagnostics
Because `ApiTrafficRecorder` is a top-level `Provider`, any widget can:

```dart
final recorder = context.watch<ApiTrafficRecorder>();
final events = recorder.recentEvents; // bounded history
```

From there you can build overlays, save captures, or expose per-channel filters without reworking the networking stack.

## Implementation Notes
- Streaming endpoints (LiteLLM) emit a chunk log per SSE data packet so you can rebuild the exact stream sequence.
- Binary payloads are represented as placeholders (e.g. `<<1024 bytes binary>>`) to avoid corrupting logs.
- Both Legion and MCP services use dedicated `LoggingHttpClient` instances but publish into the same recorder, so cross-service flows stay correlated.
