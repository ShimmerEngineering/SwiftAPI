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

final class ShimmerBLEService: ShimmerBLEGRPC_ShimmerBLEByteServer.SimpleServiceProtocol {
    
    private var bluetoothManager: BluetoothManager?
    private var centralManager: CBCentralManager?
    private var deviceNameToConnect: String = ""
    private var isConnecting: Bool = false
    
    //The key for all Dictionaries below is the Bluetooth device name
    private var bluetoothDeviceMap = [String: CBPeripheral]() //stores the currently connected devices
    private var queueMap = [String: ConcurrentQueue<Data>]() //stores the received bytes from connected devices which are written back to gRPC client in getDataStream()
    private var connectStreamMap = [String: GRPCCore.RPCWriter<ShimmerBLEGRPC_StateStatus>]() //stores the writers for the status streams back to gRPC client
    private var radioMap = [String: BleByteRadio]()
    
    init() {
        self.centralManager = CBCentralManager()
        self.bluetoothManager = BluetoothManager(centralmanager: self.centralManager!)
        bluetoothManager?.delegate = self
    }
    
    func sayHello(request: ShimmerBLEGRPC_Request, context: GRPCCore.ServerContext) async throws -> ShimmerBLEGRPC_Reply {
        return ShimmerBLEGRPC_Reply.with {
            $0.message = "Hello " + request.name
        }
    }
    
    func writeBytesShimmer(request: ShimmerBLEGRPC_WriteBytes, context: GRPCCore.ServerContext) async throws -> ShimmerBLEGRPC_Reply {
//        print("Received writeBytes request for: " + request.address)
        radioMap[request.address]!.writeData(data: request.byteToWrite)
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
        deviceNameToConnect = request.name
        isConnecting = true
        print("Received connectShimmer request for: " + deviceNameToConnect)
        var res = self.bluetoothManager?.startScanning(deviceName: self.deviceNameToConnect, timeout: 3)
        
        connectStreamMap[deviceNameToConnect] = response
        await writeStatusResponse(deviceName: deviceNameToConnect, state: ShimmerBLEGRPC_BluetoothState.connecting, message: "Connecting")
        
        try await Task.sleep(for: .seconds(4))
        while(bluetoothDeviceMap.keys.contains(deviceNameToConnect)) {
            //this keeps the response GRPCCore.RPCWriter<> open
            try await Task.sleep(for: .seconds(0.1)) //sleep 100ms
        }
    }
    
    private func writeStatusResponse(deviceName: String, state: ShimmerBLEGRPC_BluetoothState, message: String) async {
        var stateStatusStream = connectStreamMap[deviceName]
        if(stateStatusStream != nil) {
            let status = ShimmerBLEGRPC_StateStatus.with {
                $0.state = state
                $0.message = message
            }
            do {
                try await stateStatusStream?.write(status)
            } catch let error {
                print(error)
            }
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
        while(bluetoothDeviceMap.keys.contains(request.message)) {
            if(queueMap.keys.contains(request.message)) {
                var data = Data()
                while(!queueMap[request.message]!.isEmpty) {
                    data.append(queueMap[request.message]?.dequeue() ?? Data())
                }
                                
                let res = ShimmerBLEGRPC_ObjectClusterByteArray.with {
                    $0.bluetoothAddress = request.message
                    $0.binaryData = data
                    $0.calibratedTimeStamp = Double(Date().timeIntervalSince1970 * 1_000) //Unix timestamp in milliseconds
                }
                try await response.write(res)
            }
            
            try await Task.sleep(for: .seconds(0.001)) //sleep 1ms
        }

    }
    
    func startConnectShimmer() async {
        let peripheral = bluetoothManager?.getPeripheral(deviceName: deviceNameToConnect)
        if(peripheral != nil) {
            bluetoothDeviceMap[deviceNameToConnect] = peripheral
            queueMap[deviceNameToConnect] = ConcurrentQueue<Data>()
            
            let radio = BleByteRadio(deviceName: deviceNameToConnect,cbperipheral: peripheral!,bluetoothManager: bluetoothManager!)
            radio.delegate = self
            
            let success = await radio.connect()
            if(success ?? false) {
                radioMap[deviceNameToConnect] = radio
                await writeStatusResponse(deviceName: deviceNameToConnect, state: ShimmerBLEGRPC_BluetoothState.connected, message: "Success")
            } else {
                await writeStatusResponse(deviceName: deviceNameToConnect, state: ShimmerBLEGRPC_BluetoothState.disconnected, message: "Radio failed to connect")
            }
        } else {
            await writeStatusResponse(deviceName: deviceNameToConnect, state: ShimmerBLEGRPC_BluetoothState.disconnected, message: "Failed to discover device")
        }
        
        isConnecting = false
    }
    
    func startDisconnectShimmer(name: String) {
        Task {
            await radioMap[name]?.disconnect()
            bluetoothDeviceMap.removeValue(forKey: name)
            connectStreamMap.removeValue(forKey: name)
            queueMap.removeValue(forKey: name)
            radioMap.removeValue(forKey: name)
        }
    }
    
}

extension ShimmerBLEService : BluetoothManagerDelegate {
    func scanCompleted() {
        if(isConnecting) {
            Task {
                await startConnectShimmer()
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
        var queue = queueMap[deviceName]
        if(data != nil) {
            queue?.enqueue(data ?? Data())
        }
    }
}
