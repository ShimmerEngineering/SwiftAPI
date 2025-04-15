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
    private var radio: BleByteRadio?
    private var shimmer3Protocol: Shimmer3Protocol?
    public var protocolShimmer3 = 0
    private var deviceNameToConnect: String = ""
    private var isConnecting: Bool = false
    
    private var bluetoothDeviceMap = [String: CBPeripheral]()
    private var serviceMap = [String: CBService]()
    private var uartTXMap = [String: CBCharacteristic]()
    private var uartRXMap = [String: CBCharacteristic]()
//    private var queueMap = [String: [Data]]()  // Mimics a concurrent queue for binary data.
//    private var queueMap = [String: [UInt8]]()  // Mimics a concurrent queue for binary data.
    private var queueMap = [String: ConcurrentQueue<Data>]()
//    private var queueMap = [String: Data]()
//    private var connectStreamMap: [String: GRPCCore.RPCWriter<ShimmerBLEGRPC_StateStatus>] = [:]
    private var connectStreamMap = [String: GRPCCore.RPCWriter<ShimmerBLEGRPC_StateStatus>]()
//    private var radioMap = [String: ]
    private var hashMap = [String: Int64]()

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
        print("Received writeBytes request for: " + request.address)
        radio!.writeData(data: request.byteToWrite)
        return ShimmerBLEGRPC_Reply.with {
            $0.message = "Written " + request.address
        }
    }
    
    func disconnectShimmer(request: ShimmerBLEGRPC_Request, context: GRPCCore.ServerContext) async throws -> ShimmerBLEGRPC_Reply {
//        print("Received disconnectShimmer request for: " + request.name)
        startDisconnectShimmer(name: request.name)
        return ShimmerBLEGRPC_Reply.with {
            $0.message = "Disconnect " + request.name
        }
    }
    
    //Initiates a BLE scan first, before completing the process in startConnectShimmer()
    func connectShimmer(request: ShimmerBLEGRPC_Request, response: GRPCCore.RPCWriter<ShimmerBLEGRPC_StateStatus>, context: GRPCCore.ServerContext) async throws {
        deviceNameToConnect = request.name
        print("Received connectShimmer request for: " + deviceNameToConnect)
        isConnecting = true
        print("Start Bluetooth Manager Scan")
        var res = bluetoothManager?.startScanning(deviceName: deviceNameToConnect, timeout: 3)
        connectStreamMap[deviceNameToConnect] = response
        await testWrite(response: response)
        try await Task.sleep(for: .seconds(4))
        while(bluetoothDeviceMap.keys.contains(deviceNameToConnect)) {
            try await Task.sleep(for: .seconds(0.1)) //sleep 100ms
        }
    }
    
    private func testWrite(response: GRPCCore.RPCWriter<ShimmerBLEGRPC_StateStatus>) async {
        var status = ShimmerBLEGRPC_StateStatus()
        status.state = ShimmerBLEGRPC_BluetoothState.connecting
        status.message = "Connecting"
        let stateStatusStream = connectStreamMap[deviceNameToConnect]
        do {
            try await stateStatusStream?.write(status)
        } catch let error {
            print(error)
        }
    }
        
    func sendDataStream(request: GRPCCore.RPCAsyncSequence<ShimmerBLEGRPC_ObjectClusterByteArray, any Error>, context: GRPCCore.ServerContext) async throws -> ShimmerBLEGRPC_Reply {
        let reply = ShimmerBLEGRPC_Reply()
        return reply
    }
    
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
                
                let unixTimestampMillis = Double(Date().timeIntervalSince1970 * 1_000)
                
                var res = ShimmerBLEGRPC_ObjectClusterByteArray()
                res.bluetoothAddress = request.message
                res.binaryData = data
                res.calibratedTimeStamp = unixTimestampMillis
                
                try await response.write(res)
            }
            try await Task.sleep(for: .seconds(0.001)) //sleep 1ms
        }

    }
    
    func startConnectShimmer() async {
        var peripheral = bluetoothManager?.getPeripheral(deviceName: deviceNameToConnect)
        
        bluetoothDeviceMap[deviceNameToConnect] = peripheral
        queueMap[deviceNameToConnect] = ConcurrentQueue<Data>()
        
        self.radio = BleByteRadio(deviceName: deviceNameToConnect,cbperipheral: peripheral!,bluetoothManager: bluetoothManager!)
        self.radio?.delegate = self
//        shimmer3Protocol = Shimmer3Protocol(radio: self.radio!)
//        shimmer3Protocol?.delegate = self
        
//            var success = await shimmer3Protocol?.connect()
        var success = await radio?.connect()
        if(success ?? false) {
            //TODO: update init below
            var status = ShimmerBLEGRPC_StateStatus()
            status.state = ShimmerBLEGRPC_BluetoothState.connected
            status.message = "Success"
            let stateStatusStream = connectStreamMap[deviceNameToConnect]
            do {
                try await stateStatusStream?.write(status)
            } catch let error {
                print(error)
            }
//                    await UartRX.StartNotificationsAsync();
//                    var data = new StateStatus
//                    {
//                        Message = "Success",
//                        State = BluetoothState.Connected
//                    };
//                    bluetoothDevice.GattServerDisconnected += BluetoothDevice_GattServerDisconnected;
//                    ConnectStreamMap.TryAdd(macAddress, stateStatusStream);
//                    await stateStatusStream.WriteAsync(data);
        }
        isConnecting = false
    }
    
    func startDisconnectShimmer(name: String) {
        Task {
//            await shimmer3Protocol!.disconnect()
            await radio?.disconnect()
            bluetoothDeviceMap.removeValue(forKey: name)
            connectStreamMap.removeValue(forKey: name)
            queueMap.removeValue(forKey: name)
        }
    }
    
}

extension ShimmerBLEService : BluetoothManagerDelegate {
    func scanCompleted() {
        print("Bluetooth Manager Scan Completed")
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
    
    func byteCommunicationDataReceived(data: Data?) {
        var queue = queueMap[deviceNameToConnect]
        if(data != nil) {
            queue?.enqueue(data ?? Data())
        }
    }
}
