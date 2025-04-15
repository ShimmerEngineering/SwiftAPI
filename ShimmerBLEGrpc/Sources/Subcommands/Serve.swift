/*
 * Copyright 2024, gRPC Authors All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import ArgumentParser
import GRPCCore
import GRPCNIOTransportHTTP2
import GRPCProtobuf

struct Serve: AsyncParsableCommand {
  static let configuration = CommandConfiguration(abstract: "Starts a greeter server.")

  @Option(help: "The port to listen on")
  var port: Int = 5000

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
        print("Greeter listening on \(address)")
      }
    }
  }
}

struct Greeter: ShimmerBLEGRPC_ShimmerBLEByteServer.SimpleServiceProtocol {
    func sayHello(request: ShimmerBLEGRPC_Request, context: GRPCCore.ServerContext) async throws -> ShimmerBLEGRPC_Reply {
//        let reply = Reply.with {
//          $0.message = "Hello " + request.name
//        }
//        return context.eventLoop.makeSucceededFuture(reply)
        print("Received sayHello request")
        let reply = ShimmerBLEGRPC_Reply()
        return reply
    }
    
    func writeBytesShimmer(request: ShimmerBLEGRPC_WriteBytes, context: GRPCCore.ServerContext) async throws -> ShimmerBLEGRPC_Reply {
        let reply = ShimmerBLEGRPC_Reply()
        return reply
    }
    
    func disconnectShimmer(request: ShimmerBLEGRPC_Request, context: GRPCCore.ServerContext) async throws -> ShimmerBLEGRPC_Reply {
        let reply = ShimmerBLEGRPC_Reply()
        return reply
    }
    
    func connectShimmer(request: ShimmerBLEGRPC_Request, response: GRPCCore.RPCWriter<ShimmerBLEGRPC_StateStatus>, context: GRPCCore.ServerContext) async throws {
        print("Received connectShimmer request -> " + request.name)
    }
    
    func sendDataStream(request: GRPCCore.RPCAsyncSequence<ShimmerBLEGRPC_ObjectClusterByteArray, any Error>, context: GRPCCore.ServerContext) async throws -> ShimmerBLEGRPC_Reply {
        let reply = ShimmerBLEGRPC_Reply()
        return reply
    }
    
    func getTestDataStream(request: ShimmerBLEGRPC_StreamRequest, response: GRPCCore.RPCWriter<ShimmerBLEGRPC_ObjectClusterByteArray>, context: GRPCCore.ServerContext) async throws {
        
    }
    
    func getDataStream(request: ShimmerBLEGRPC_StreamRequest, response: GRPCCore.RPCWriter<ShimmerBLEGRPC_ObjectClusterByteArray>, context: GRPCCore.ServerContext) async throws {
        
    }
}

//struct ShimmerBLEServiceImpl: ShimmerBLEByteServer.ShimmerBLEByteServerBase

//struct Greeter: Helloworld_Greeter.SimpleServiceProtocol {
//  func sayHello(
//    request: Helloworld_HelloRequest,
//    context: ServerContext
//  ) async throws -> Helloworld_HelloReply {
//    var reply = Helloworld_HelloReply()
//    let recipient = request.name.isEmpty ? "stranger" : request.name
//    reply.message = "Hello, \(recipient)"
//    return reply
//  }
//}
