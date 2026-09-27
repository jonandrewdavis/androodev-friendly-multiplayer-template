# Multiplayer smoke checks

Run from the project root with Godot 4.7:

```sh
GODOT=/Applications/Godot_v4.7.app/Contents/MacOS/Godot
"$GODOT" --headless --path . res://tests/multiplayer_smoke.tscn -- offline
```

For paired checks, start the host and then start the client in another terminal:

```sh
"$GODOT" --headless --path . res://tests/multiplayer_smoke.tscn -- enet-host
"$GODOT" --headless --path . res://tests/multiplayer_smoke.tscn -- enet-client
```

Use relay-host / relay-client for NodeTunnel. The host writes its code to /private/tmp/nodetunnel-smoke-room.txt. These modes exercise discovery, replicated players, level changes, kick, ban, reconnect and native host departure. NodeTunnel's beta may delay departure events beyond the test deadlines; no custom disconnect workaround is expected. ENet also verifies that a banned IP cannot rejoin; relay peer IDs change on reconnect.

Additional modes:

- relay-session-host / relay-session-client: joins through the menu and keeps gameplay connected beyond 25 seconds, guarding against false ten-second timeouts.
- visual: offline checks in a real window, with menu, host and pause PNGs under /private/tmp.
- relay-invalid: invalid room code is rejected.
- relay-capacity-host: start this, then three relay-capacity-client processes, then relay-full-client; verifies the four-player limit.

Each process must exit successfully and print SMOKE PASS. Also inspect its output for script/native errors. The plugin itself logs an expected relay error for invalid-code and full-room rejection tests.

There is no Steam mode: SteamBackend needs a running Steam client and the GodotSteam extension, so test it manually with two accounts.

Service choices made by these checks are not persisted. Relay modes create temporary public test rooms using the configured App ID. Room-code coordination paths currently target macOS.
