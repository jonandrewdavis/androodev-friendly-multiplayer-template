# NodeTunnel integration plan amendments

The Desktop plan remains the implementation baseline. Preserve the restored Minimal Elevation theme and current project settings unrelated to multiplayer.

- Separate backend shutdown from leaving a game: shutdown must not reconnect a discarded relay peer.
- Queue a method that reads the current relay peer when fetching rooms, rather than binding a method on a stale peer.
- Keep backend status in the service so newly created menus can display it.
- Suspend the relay before offline play and ignore obsolete callbacks during cleanup.
- Cancel unfinished level loads when leaving, and gate world replication on an active lobby.
- Validate discovery packets, room metadata, saved backend values, and blank join addresses.
- Verify imports, startup, offline and two-peer networking with bounded automated checks; report any external relay or GUI checks that cannot be completed.

## Beta-plugin findings addressed

Player departures now use Godot/NodeTunnel's native peer_disconnected, server_disconnected and forced_disconnect events. Custom departure RPCs, presence tracking, heartbeats, relay probes and in-game watchdogs were removed at the user's request (2026-09-08). Initial connection/menu timeouts remain.

Native error callbacks must be deferred before releasing the peer: a full-room refusal exposed a Rust borrow crash with synchronous cleanup. All plugin callbacks now carry a generation token and use deferred delivery. Admission reservations prevent simultaneous join approvals from exceeding the player limit.

GGT emits scene_transition_finished before resetting its transition flag. Gameplay waits one additional frame before starting an exit transition, including when a connection ends during the initial fade.

NodeTunnel IDs change on reconnect; bans cannot identify the same person across relay reconnects. The bundled native plugin does not support web exports.
