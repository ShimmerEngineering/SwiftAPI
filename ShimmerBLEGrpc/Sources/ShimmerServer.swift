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
    static let configuration = CommandConfiguration(abstract: "Starts the Shimmer BLE gRPC server.")

    @Option(help: "The port to listen on")
    var port: Int = 50052

    func run() async throws {
      // Disable buffering so logs aren’t batched when stdout/stderr are pipes
      setbuf(stdout, nil)
      setbuf(stderr, nil)
      installSignalHandlers()
        
      let server = await GRPCServer(
        transport: .http2NIOPosix(
          address: .ipv4(host: "127.0.0.1", port: self.port),
          transportSecurity: .plaintext
        ),
        services: [ShimmerBLEService()]
      )
        
      try await withThrowingDiscardingTaskGroup { group in
        group.addTask { try await server.serve() }
        if let address = try await server.listeningAddress {
          print("Shimmer BLE gRPC listening on \(address)")
            print("Server Version: v1.0.1")
        }
      }
    }
    
    // Log termination signals to help diagnose unexpected exits
    private func installSignalHandlers() {
        let signals = [SIGTERM, SIGHUP, SIGINT, SIGQUIT]
        for sig in signals {
            signal(sig) { s in
                let msg = "[Swift] received signal \( s)\n"
                FileHandle.standardError.write(Data(msg.utf8))
                // Ensure logs are flushed before exiting
                fflush(stdout); fflush(stderr)
                _exit(128 + s) // Conventional exit for signaled process
            }
        }
    }
}
