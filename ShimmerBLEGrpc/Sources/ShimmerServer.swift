//
//  ShimmerServer.swift
//  ShimmerBLEGrpc
//
//  Created by Joseph Yong on 24/04/2025.
//

import ArgumentParser
import GRPCCore
import GRPCNIOTransportHTTP2
import GRPCProtobuf
import Foundation
import Darwin


@main
struct ShimmerServer: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Starts the Shimmer BLE gRPC server.",
        version: "1.0.2"
    )

    @Option(help: "The port to listen on")
    var port: Int = 50052

    func validate() throws {
        guard (1...65535).contains(port) else {
            throw ValidationError("Port must be between 1 and 65535")
        }
    }

    func run() async throws {
      // Disable buffering so logs aren't batched when stdout/stderr are pipes
      setbuf(stdout, nil)
      setbuf(stderr, nil)

      let service = await ShimmerBLEService()

      // Plaintext transport is acceptable here only because the server binds loopback-only (127.0.0.1).
      let server = await GRPCServer(
        transport: .http2NIOPosix(
          address: .ipv4(host: "127.0.0.1", port: self.port),
          transportSecurity: .plaintext
        ),
        services: [service]
      )

      // Graceful shutdown on termination signals. DispatchSourceSignal keeps signal
      // handling off the (non-async-signal-safe) C handler path.
      let signalSources = installSignalHandlers(service: service, server: server)
      defer { for source in signalSources { source.cancel() } }

      do {
        try await withThrowingDiscardingTaskGroup { group in
          group.addTask { try await server.serve() }
          if let address = try await server.listeningAddress {
            print("Shimmer BLE gRPC listening on \(address)")
          }
        }
      } catch {
        FileHandle.standardError.write(Data("Failed to start server on port \(self.port): \(error)\nThe port may already be in use; try a different --port.\n".utf8))
        throw ExitCode.failure
      }
    }

    // Install DispatchSource-based handlers for SIGINT/SIGTERM that disconnect all devices,
    // begin graceful shutdown, and hard-exit if shutdown hangs.
    private func installSignalHandlers<Transport: ServerTransport>(service: ShimmerBLEService, server: GRPCServer<Transport>) -> [DispatchSourceSignal] {
        let queue = DispatchQueue(label: "com.shimmer.signal-handler")
        let signals: [Int32] = [SIGINT, SIGTERM]
        var sources: [DispatchSourceSignal] = []
        for sig in signals {
            // Ignore the default disposition so the DispatchSource receives the signal
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: queue)
            source.setEventHandler {
                FileHandle.standardError.write(Data("[Swift] received signal \(sig); shutting down\n".utf8))
                Task {
                    await service.disconnectAllDevices()
                    server.beginGracefulShutdown()
                }
                // Fallback hard-exit if graceful shutdown hangs
                queue.asyncAfter(deadline: .now() + 5) {
                    _exit(128 + sig) // Conventional exit code for a signaled process
                }
            }
            source.resume()
            sources.append(source)
        }
        return sources
    }
}
