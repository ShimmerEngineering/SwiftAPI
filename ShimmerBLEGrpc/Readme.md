# Getting Started

## Running from Xcode
To run the BLE gRPC server, set the active scheme at the top-middle of Xcode to ShimmerBLEGrpc, target My Mac
Then, select the Start button at the top-left of Xcode to start the app
Then, open the Shimmer-Java-Android-API ShimmerGRPC.java class from: https://github.com/ShimmerEngineering/Shimmer-Java-Android-API/blob/master/ShimmerDriverPC/src/main/java/com/shimmerresearch/pcDriver/ShimmerGRPC.java
Set the name of the device you want to connect to, in Line 101 of the class. This is e.g. "Shimmer3-XXXX".
Note that this is not the Bluetooth Mac address, as MacOS BLE is limited to using Bluetooth device names.
Then, run ShimmerGRPC.java

## Running from the command line
The server is a Swift Package Manager executable and can be run directly:

```
swift run shimmer-ble-grpc            # listens on the default port 50052
swift run shimmer-ble-grpc --port 50100
swift run shimmer-ble-grpc --version  # prints the server version
```

The server binds to `127.0.0.1` (loopback) only. Plaintext (unencrypted) transport is
used deliberately and is acceptable **only** because the server is never exposed off the
local machine. `--port` must be in the range 1...65535. If the chosen port is already in
use, the server prints a clear message and exits non-zero.

## Note on Bluetooth device names
macOS BLE exposes peripherals by Bluetooth device name rather than MAC address, so all
requests identify a device by its name (e.g. `Shimmer3-XXXX`).

# RPCs
Failures are reported using proper gRPC status codes (previously the server returned OK
with an error message in the body). The human-readable text is preserved in the status
message.

| RPC | Shape | Behaviour / error semantics |
| --- | --- | --- |
| `ConnectShimmer` | unary request, **server-streaming** `StateStatus` | Scans for and connects the named device. Streams `connecting` then `connected`; the stream stays open for the connection lifetime and emits a terminal `disconnected` status on teardown. `FAILED_PRECONDITION` if another connect is already in progress; `UNAVAILABLE` if Bluetooth is off / the scan can't start or the radio fails to connect; `NOT_FOUND` if the device is never discovered; `DEADLINE_EXCEEDED` if the connect attempt times out (~30s); `ABORTED` if the attempt is cancelled by a disconnect or server shutdown. |
| `DisconnectShimmer` | unary request, unary `Reply` | Disconnects the named device and cleans up. `NOT_FOUND` if the device is not connected. |
| `GetDataStream` | unary request, **server-streaming** `ObjectClusterByteArray` | Streams received BLE byte packets for the device. `NOT_FOUND` if the device is not connected; `FAILED_PRECONDITION` if a data stream is already active for that device. Ends when the device disconnects or the client cancels. |
| `WriteBytesShimmer` | unary request, unary `Reply` | Writes bytes to the device's TX characteristic. `NOT_FOUND` if the device is not connected; `UNAVAILABLE` if the write characteristic is not available. |
| `SayHello` | unary request, unary `Reply` | Simple echo/health check. |
| `SendDataStream` | client-streaming, unary `Reply` | `UNIMPLEMENTED`. |
| `GetTestDataStream` | unary request, server-streaming | `UNIMPLEMENTED`. |

# Changelog
v1.0.0
- Initial Release

v1.0.1
- Improve logging in ShimmerServer
- Improve thread safety in ShimmerBLEService

v1.0.2
- Fix connection state machine (no more permanently-stuck connecting flag; connect awaits the real outcome with a timeout)
- Push-based data streaming (no busy-poll); single active data stream per device
- Report failures as gRPC status codes instead of OK-with-error-text
- Graceful shutdown on SIGINT/SIGTERM that disconnects all devices
- Add `--port` validation and `--version`; clearer bind-failure message
- Command-line `swift run` support (SwiftPM manifests for the server and the ShimmerBluetooth library)
