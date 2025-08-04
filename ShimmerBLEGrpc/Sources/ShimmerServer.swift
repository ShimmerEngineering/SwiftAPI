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

@main
struct ShimmerServer: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Starts the Shimmer BLE gRPC server.")

    @Option(help: "The port to listen on")
    var port: Int = 50052

    func run() async throws {
      let server = GRPCServer(
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
            print("Server Version: v1.0.0")
        }
      }
    }
}
