//
//  ShimmerBLEService.swift
//  ShimmerBLEGrpc
//
//  Created by Joseph Yong on 09/04/2025.
//

import Combine
import CoreBluetooth
import ShimmerBluetooth
import ArgumentParser
import GRPCCore
import GRPCNIOTransportHTTP2
import GRPCProtobuf

@MainActor // CHANGE: serialize all shared mutable state on the main actor
final class ShimmerBLEService: ShimmerBLEGRPC_ShimmerBLEByteServer.SimpleServiceProtocol {
    
    private var centralManager: CBCentralManager?
    private var bluetoothManager: BluetoothManager?
    private var deviceNameToConnect: String = ""
    private var isConnecting: Bool = false
    
    //The key for all Dictionaries below is the Bluetooth device name
    private var bluetoothDeviceMap = [String: CBPeripheral]() //stores the currently connected devices
    private var queueMap = [String: ConcurrentQueue<Data>]() //stores the received bytes from connected devices which are written back to gRPC client in getDataStream()
    private var connectStreamMap = [String: GRPCCore.RPCWriter<ShimmerBLEGRPC_StateStatus>]() //stores the writers for the status streams back to gRPC client
    private var radioMap = [String: BleByteRadio]()
    
    init() {
        self.centralManager = CBCentralManager() // main queue by default
        self.bluetoothManager = BluetoothManager(centralmanager: self.centralManager!)
        bluetoothManager?.delegate = self
    }
    
    func sayHello(request: ShimmerBLEGRPC_Request, context: GRPCCore.ServerContext) async throws -> ShimmerBLEGRPC_Reply {
        return ShimmerBLEGRPC_Reply.with {
            $0.message = "Hello " + request.name
        }
    }
    
    func writeBytesShimmer(request: ShimmerBLEGRPC_WriteBytes, context: GRPCCore.ServerContext) async throws -> ShimmerBLEGRPC_Reply {
        // CHANGE: avoid force-unwrap and handle when device not connected
        guard let radio = radioMap[request.address] else {
            return ShimmerBLEGRPC_Reply.with {
                $0.message = "Write failed: device \( request.address) not connected"
            }
        }
        radio.writeData(data: request.byteToWrite)
        return ShimmerBLEGRPC_Reply.with {
            $0.message = "Written " + request.address
        }
    }
    
    func disconnectShimmer(request: ShimmerBLEGRPC_Request, context: GRPCCore.ServerContext) async throws -> ShimmerBLEGRPC_Reply {
        print("Received disconnectShimmer request for: " + request.name)
        startDisconnectShimmer(name: request.name)
        return ShimmerBLEGRPC_Reply.with {
            $0.message = "Disconnect " + request.name
        }
    }
    
    //Initiates a BLE scan first, before completing the process in startConnectShimmer()
    func connectShimmer(request: ShimmerBLEGRPC_Request, response: GRPCCore.RPCWriter<ShimmerBLEGRPC_StateStatus>, context: GRPCCore.ServerContext) async throws {
        if !isConnecting {
            deviceNameToConnect = request.name
            isConnecting = true
            print("Received connectShimmer request for: " + deviceNameToConnect)
            
            // register the writer up front
            connectStreamMap[deviceNameToConnect] = response
            
            await writeStatusResponse(deviceName: deviceNameToConnect,
                                      state: ShimmerBLEGRPC_BluetoothState.connecting,
                                      message: "Connecting")
            
            _ = bluetoothManager?.startScanning(deviceName: self.deviceNameToConnect, timeout: 3)
            
            try await Task.sleep(for: .seconds(4))
            // Keep the writer open while the device stays connected (exists in map)
            while bluetoothDeviceMap[deviceNameToConnect] != nil {
                try await Task.sleep(for: .seconds(0.1)) //sleep 100ms
            }
        } else {
            print("Received connectShimmer request for: " + deviceNameToConnect)
            print("Error: connection attempt already in progress!")
            await writeStatusResponseWithRPCWriter(
                state: ShimmerBLEGRPC_BluetoothState.disconnected,
                message: "Connection failed! Existing connection attempt in progress",
                writer: response
            )
        }
    }
    
    private func writeStatusResponse(deviceName: String, state: ShimmerBLEGRPC_BluetoothState, message: String) async {
        let stateStatusStream = connectStreamMap[deviceName]
        await writeStatusResponseWithRPCWriter(state: state, message: message, writer: stateStatusStream)
    }
    
    private func writeStatusResponseWithRPCWriter(state: ShimmerBLEGRPC_BluetoothState, message: String, writer: GRPCCore.RPCWriter<ShimmerBLEGRPC_StateStatus>?) async {
        guard let writer = writer else { return }
        let status = ShimmerBLEGRPC_StateStatus.with {
            $0.state = state
            $0.message = message
        }
        do {
            try await writer.write(status)
        } catch {
            print("writeStatusResponse error:", error)
        }
    }
    
    //Currently unused
    func sendDataStream(request: GRPCCore.RPCAsyncSequence<ShimmerBLEGRPC_ObjectClusterByteArray, any Error>, context: GRPCCore.ServerContext) async throws -> ShimmerBLEGRPC_Reply {
        let reply = ShimmerBLEGRPC_Reply()
        return reply
    }
    
    //Currently unused
    func getTestDataStream(request: ShimmerBLEGRPC_StreamRequest, response: GRPCCore.RPCWriter<ShimmerBLEGRPC_ObjectClusterByteArray>, context: GRPCCore.ServerContext) async throws {
        print("Received getTestDataStream request for: " + request.message)
    }
    
    func getDataStream(request: ShimmerBLEGRPC_StreamRequest, response: GRPCCore.RPCWriter<ShimmerBLEGRPC_ObjectClusterByteArray>, context: GRPCCore.ServerContext) async throws {
        print("Received getDataStream request for: " + request.message)
        while bluetoothDeviceMap[request.message] != nil {
            if let q = queueMap[request.message] {
                var data = Data()
                while !q.isEmpty {
                    data.append(q.dequeue() ?? Data())
                }
                
                if !data.isEmpty {
                    let res = ShimmerBLEGRPC_ObjectClusterByteArray.with {
                        $0.bluetoothAddress = request.message
                        $0.binaryData = data
                        $0.calibratedTimeStamp = Double(Date().timeIntervalSince1970 * 1_000) //Unix timestamp in milliseconds
                    }
                    try await response.write(res)
                }
            }
            try await Task.sleep(for: .seconds(0.001)) //sleep 1ms
        }
    }
    
    func startConnectShimmer() async {
        // CHANGE: always reset isConnecting at the end
        defer { isConnecting = false }
        
        guard let peripheral = bluetoothManager?.getPeripheral(deviceName: deviceNameToConnect) else {
            await writeStatusResponse(deviceName: deviceNameToConnect,
                                      state: ShimmerBLEGRPC_BluetoothState.disconnected,
                                      message: "Failed to discover device")
            return
        }
        
        // CHANGE: create radio first, connect, and only then register in maps
        let radio = BleByteRadio(deviceName: deviceNameToConnect,
                                 cbperipheral: peripheral,
                                 bluetoothManager: bluetoothManager!)
        radio.delegate = self
        
        let success = await radio.connect()
        if success ?? false {
            bluetoothDeviceMap[deviceNameToConnect] = peripheral
            queueMap[deviceNameToConnect] = ConcurrentQueue<Data>()
            radioMap[deviceNameToConnect] = radio
            await writeStatusResponse(deviceName: deviceNameToConnect,
                                      state: ShimmerBLEGRPC_BluetoothState.connected,
                                      message: "Success")
        } else {
            await writeStatusResponse(deviceName: deviceNameToConnect,
                                      state: ShimmerBLEGRPC_BluetoothState.disconnected,
                                      message: "Radio failed to connect")
        }
    }
    
    func startDisconnectShimmer(name: String) {
        // CHANGE: run the disconnect and cleanup on the main actor
        Task { @MainActor in
            if let radio = radioMap[name] {
                await radio.disconnect()
            }
            bluetoothDeviceMap.removeValue(forKey: name)
            connectStreamMap.removeValue(forKey: name)
            queueMap.removeValue(forKey: name)
            radioMap.removeValue(forKey: name)
        }
    }
    
}

extension ShimmerBLEService : BluetoothManagerDelegate {
    func scanCompleted() {
        if isConnecting {
            Task {
                await startConnectShimmer() // will hop onto the main actor
            }
        }
    }
    
    func isConnected() {
        print("Bluetooth Manager Connected Device")
    }
    
    func isDisconnected() {
        print("Bluetooth Manager Disconnected Device")
    }
}

extension ShimmerBLEService : ByteCommunicationDelegate {
    func byteCommunicationConnected() {
    }
    
    func byteCommunicationDisconnected(connectionloss: Bool) {
    }
    
    func byteCommunicationDataReceived(data: Data?, deviceName: String) {
        // CHANGE: avoid optional chaining and ignore nil data
        guard let data = data, let queue = queueMap[deviceName] else { return }
        queue.enqueue(data)
    }
}

