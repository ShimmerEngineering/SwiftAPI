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

@MainActor
final class ShimmerBLEService: ShimmerBLEGRPC_ShimmerBLEByteServer.SimpleServiceProtocol {

    private var centralManager: CBCentralManager?
    private var bluetoothManager: BluetoothManager?
    private var deviceNameToConnect: String = ""
    private var isConnecting: Bool = false

    //The key for all Dictionaries below is the Bluetooth device name
    private var bluetoothDeviceMap = [String: CBPeripheral]() //stores the currently connected devices
    private var connectStreamMap = [String: GRPCCore.RPCWriter<ShimmerBLEGRPC_StateStatus>]() //stores the writers for the status streams back to gRPC client
    private var radioMap = [String: BleByteRadio]()
    //Push-based buffers for received bytes. The stream is created before radio.connect()
    //so packets arriving during characteristic discovery are not dropped.
    private var dataStreamMap = [String: AsyncStream<Data>]()
    private var dataStreamContinuationMap = [String: AsyncStream<Data>.Continuation]()
    //Names of devices with a getDataStream() currently draining their buffer
    private var activeDataStreams = Set<String>()
    //Names of devices with a disconnect/teardown already in flight (guards reentry when
    //an intentional disconnect triggers the link-loss delegate callback)
    private var disconnectingDevices = Set<String>()

    //Outcome of a connect attempt, delivered from startConnectShimmer() back to connectShimmer()
    private enum ConnectOutcome {
        case connected(BleByteRadio, CBPeripheral)
        case deviceNotFound
        case radioFailed
        case timedOut
        case cancelled
    }
    private var connectContinuation: CheckedContinuation<ConnectOutcome, Never>?
    private var connectTimeoutTask: Task<Void, Never>?

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
        //Report an honest gRPC status when the device is not connected
        guard let radio = radioMap[request.address] else {
            throw RPCError(code: .notFound, message: "Write failed: device \(request.address) not connected")
        }
        //writeData returns false when the TX characteristic is not available
        let written = radio.writeData(data: request.byteToWrite)
        if !written {
            throw RPCError(code: .unavailable, message: "Write failed for \(request.address): characteristic not available")
        }
        return ShimmerBLEGRPC_Reply.with {
            $0.message = "Written " + request.address
        }
    }

    func disconnectShimmer(request: ShimmerBLEGRPC_Request, context: GRPCCore.ServerContext) async throws -> ShimmerBLEGRPC_Reply {
        print("Received disconnectShimmer request for: " + request.name)
        let name = request.name
        //Fail honestly if the device is not known to us at all
        guard bluetoothDeviceMap[name] != nil
                || radioMap[name] != nil
                || connectStreamMap[name] != nil
                || dataStreamMap[name] != nil else {
            throw RPCError(code: .notFound, message: "Disconnect failed: device \(name) not connected")
        }
        //Await the disconnect + cleanup inline (we are already on the main actor)
        await startDisconnectShimmer(name: name)
        return ShimmerBLEGRPC_Reply.with {
            $0.message = "Disconnect " + name
        }
    }

    //Initiates a BLE scan first, then awaits the outcome of the connect flow which is
    //driven by scanCompleted() -> startConnectShimmer().
    func connectShimmer(request: ShimmerBLEGRPC_Request, response: GRPCCore.RPCWriter<ShimmerBLEGRPC_StateStatus>, context: GRPCCore.ServerContext) async throws {
        //Single-flight for the connect HANDSHAKE only: the BluetoothManager library supports
        //one scan/connect at a time, but multiple devices may stay connected concurrently.
        guard !isConnecting else {
            print("Received connectShimmer request for: " + request.name)
            print("Error: connection attempt already in progress!")
            throw RPCError(code: .failedPrecondition, message: "Connection attempt already in progress; retry once it completes")
        }
        let name = request.name
        guard bluetoothDeviceMap[name] == nil else {
            throw RPCError(code: .failedPrecondition, message: "Device \(name) is already connected")
        }
        deviceNameToConnect = name
        //Held only for the handshake; reset on the scan-failure throw below and right
        //after the outcome continuation resolves. No defer: this RPC keeps running for
        //the whole connection lifetime, and a deferred reset would clobber a later
        //device's in-flight handshake.
        isConnecting = true
        print("Received connectShimmer request for: " + name)

        // register the writer up front
        connectStreamMap[name] = response

        await writeStatusResponse(deviceName: name,
                                  state: ShimmerBLEGRPC_BluetoothState.connecting,
                                  message: "Connecting")

        let scanStarted = bluetoothManager?.startScanning(deviceName: name, timeout: 3) ?? false
        if !scanStarted {
            await writeStatusResponse(deviceName: name,
                                      state: ShimmerBLEGRPC_BluetoothState.disconnected,
                                      message: "Bluetooth is not powered on or scan could not start")
            cleanupConnectAttempt(name)
            isConnecting = false
            throw RPCError(code: .unavailable, message: "Bluetooth is not powered on or scan could not start")
        }

        //Await the real outcome of the connect flow, bounded by an overall timeout so a
        //hung library call can't leak the RPC forever. Client cancellation during this
        //suspension is observed once the outcome resolves (scan timeout / 30s guard).
        let outcome: ConnectOutcome = await withCheckedContinuation { continuation in
            self.connectContinuation = continuation
            self.connectTimeoutTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(30))
                self?.resumeConnect(.timedOut)
            }
        }
        //Handshake is over: free the single-flight slot so other devices can connect
        //while this stream stays open for the connection lifetime.
        isConnecting = false

        switch outcome {
        case .connected(let radio, let peripheral):
            bluetoothDeviceMap[name] = peripheral
            radioMap[name] = radio
            await writeStatusResponse(deviceName: name,
                                      state: ShimmerBLEGRPC_BluetoothState.connected,
                                      message: "Success")
            //Keep the connect stream open while the device stays connected (exists in map).
            //If the client cancels the RPC, Task.sleep throws and we tear the connection down.
            do {
                while bluetoothDeviceMap[name] != nil {
                    try await Task.sleep(for: .seconds(0.1)) //sleep 100ms
                }
            } catch {
                await startDisconnectShimmer(name: name)
            }
            connectStreamMap.removeValue(forKey: name)
        case .deviceNotFound:
            await writeStatusResponse(deviceName: name,
                                      state: ShimmerBLEGRPC_BluetoothState.disconnected,
                                      message: "Failed to discover device")
            cleanupConnectAttempt(name)
            throw RPCError(code: .notFound, message: "Device \(name) was not discovered during scan")
        case .radioFailed:
            await writeStatusResponse(deviceName: name,
                                      state: ShimmerBLEGRPC_BluetoothState.disconnected,
                                      message: "Radio failed to connect")
            cleanupConnectAttempt(name)
            throw RPCError(code: .unavailable, message: "Radio failed to connect for \(name)")
        case .timedOut:
            await writeStatusResponse(deviceName: name,
                                      state: ShimmerBLEGRPC_BluetoothState.disconnected,
                                      message: "Connection attempt timed out")
            cleanupConnectAttempt(name)
            throw RPCError(code: .deadlineExceeded, message: "Connection attempt for \(name) timed out")
        case .cancelled:
            await writeStatusResponse(deviceName: name,
                                      state: ShimmerBLEGRPC_BluetoothState.disconnected,
                                      message: "Connection attempt cancelled")
            cleanupConnectAttempt(name)
            throw RPCError(code: .aborted, message: "Connection attempt for \(name) was cancelled")
        }
    }

    //Resume the pending connect continuation exactly once (guards against double-resume).
    //Returns false when there was no pending continuation to deliver the outcome to.
    @discardableResult
    private func resumeConnect(_ outcome: ConnectOutcome) -> Bool {
        connectTimeoutTask?.cancel()
        connectTimeoutTask = nil
        guard let continuation = connectContinuation else { return false }
        connectContinuation = nil
        continuation.resume(returning: outcome)
        return true
    }

    //Create the per-device push buffer if it does not already exist. Bounded so a device
    //that streams with no getDataStream() client draining it can't grow memory forever;
    //the oldest packets are dropped once the backlog is full.
    private func ensureDataStream(for name: String) {
        guard dataStreamMap[name] == nil else { return }
        let (stream, continuation) = AsyncStream.makeStream(of: Data.self, bufferingPolicy: .bufferingNewest(4096))
        dataStreamMap[name] = stream
        dataStreamContinuationMap[name] = continuation
    }

    //Tear down every trace of a device after a failed/aborted connect attempt.
    private func cleanupConnectAttempt(_ name: String) {
        dataStreamContinuationMap[name]?.finish()
        dataStreamContinuationMap.removeValue(forKey: name)
        dataStreamMap.removeValue(forKey: name)
        connectStreamMap.removeValue(forKey: name)
        bluetoothDeviceMap.removeValue(forKey: name)
        radioMap.removeValue(forKey: name)
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
        throw RPCError(code: .unimplemented, message: "SendDataStream is not implemented")
    }

    //Currently unused
    func getTestDataStream(request: ShimmerBLEGRPC_StreamRequest, response: GRPCCore.RPCWriter<ShimmerBLEGRPC_ObjectClusterByteArray>, context: GRPCCore.ServerContext) async throws {
        print("Received getTestDataStream request for: " + request.message)
        throw RPCError(code: .unimplemented, message: "GetTestDataStream is not implemented")
    }

    func getDataStream(request: ShimmerBLEGRPC_StreamRequest, response: GRPCCore.RPCWriter<ShimmerBLEGRPC_ObjectClusterByteArray>, context: GRPCCore.ServerContext) async throws {
        print("Received getDataStream request for: " + request.message)
        let name = request.message
        //Device must be connected and have a live push buffer
        guard bluetoothDeviceMap[name] != nil, let stream = dataStreamMap[name] else {
            throw RPCError(code: .notFound, message: "Device \(name) is not connected")
        }
        //Only one active drain per device, otherwise concurrent streams steal each other's packets
        guard !activeDataStreams.contains(name) else {
            throw RPCError(code: .failedPrecondition, message: "A data stream is already active for \(name)")
        }
        activeDataStreams.insert(name)
        //Client cancellation terminates the AsyncStream, so if the device is still
        //connected when the drain ends, rebuild the buffer so a later getDataStream
        //call can attach again instead of iterating a dead stream.
        defer {
            activeDataStreams.remove(name)
            if bluetoothDeviceMap[name] != nil {
                dataStreamContinuationMap[name]?.finish()
                dataStreamContinuationMap.removeValue(forKey: name)
                dataStreamMap.removeValue(forKey: name)
                ensureDataStream(for: name)
            }
        }

        //Ends when the continuation is finished (on disconnect) or the client cancels
        //(AsyncStream iteration honors task cancellation).
        for await data in stream {
            let res = ShimmerBLEGRPC_ObjectClusterByteArray.with {
                $0.bluetoothAddress = name
                $0.binaryData = data
                $0.calibratedTimeStamp = Double(Date().timeIntervalSince1970 * 1_000) //Unix timestamp in milliseconds
            }
            try await response.write(res)
        }
    }

    func startConnectShimmer() async {
        let name = deviceNameToConnect
        guard let peripheral = bluetoothManager?.getPeripheral(deviceName: name) else {
            resumeConnect(.deviceNotFound)
            return
        }

        //Create radio, then the push buffer BEFORE awaiting connect so packets arriving
        //during characteristic discovery are buffered rather than dropped.
        let radio = BleByteRadio(deviceName: name,
                                 cbperipheral: peripheral,
                                 bluetoothManager: bluetoothManager!)
        radio.delegate = self
        ensureDataStream(for: name)

        let success = await radio.connect()
        if success ?? false {
            if !resumeConnect(.connected(radio, peripheral)) {
                //The RPC already gave up (timeout/cancelled): release the live
                //CoreBluetooth link rather than orphaning it.
                _ = await radio.disconnect()
            }
        } else {
            //Discovery can fail after the central connected; release any half-open link
            _ = await radio.disconnect()
            resumeConnect(.radioFailed)
        }
    }

    func startDisconnectShimmer(name: String) async {
        guard !disconnectingDevices.contains(name) else { return }
        disconnectingDevices.insert(name)
        defer { disconnectingDevices.remove(name) }
        //If a connect attempt for this device is still pending, resume it so the
        //connectShimmer RPC doesn't hang until its timeout.
        if name == deviceNameToConnect {
            resumeConnect(.cancelled)
        }
        if let radio = radioMap[name] {
            await radio.disconnect()
        }
        //Finish the data stream so any active getDataStream() loop ends
        dataStreamContinuationMap[name]?.finish()
        dataStreamContinuationMap.removeValue(forKey: name)
        dataStreamMap.removeValue(forKey: name)
        //Write a terminal status BEFORE removing the writer from the map
        await writeStatusResponse(deviceName: name,
                                  state: ShimmerBLEGRPC_BluetoothState.disconnected,
                                  message: "Disconnected")
        connectStreamMap.removeValue(forKey: name)
        bluetoothDeviceMap.removeValue(forKey: name)
        radioMap.removeValue(forKey: name)
    }

    //Called on server shutdown (SIGINT/SIGTERM): disconnect everything and clear all state.
    func disconnectAllDevices() async {
        //Resume any pending connect attempt so its RPC unblocks immediately
        resumeConnect(.cancelled)
        for radio in Array(radioMap.values) {
            await radio.disconnect()
        }
        for continuation in dataStreamContinuationMap.values {
            continuation.finish()
        }
        for name in Array(connectStreamMap.keys) {
            await writeStatusResponse(deviceName: name,
                                      state: ShimmerBLEGRPC_BluetoothState.disconnected,
                                      message: "Server shutting down")
        }
        bluetoothDeviceMap.removeAll()
        radioMap.removeAll()
        connectStreamMap.removeAll()
        dataStreamMap.removeAll()
        dataStreamContinuationMap.removeAll()
        activeDataStreams.removeAll()
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

    func byteCommunicationDisconnected(connectionloss: Bool, deviceName: String) {
        //Unsolicited link loss (device out of range, battery died): tear down the device's
        //state so the connect stream ends with a terminal status and its maps are cleared.
        //Without this the keep-alive loop in connectShimmer would spin forever.
        guard bluetoothDeviceMap[deviceName] != nil || radioMap[deviceName] != nil else { return }
        Task {
            await startDisconnectShimmer(name: deviceName)
        }
    }

    func byteCommunicationDataReceived(data: Data?, deviceName: String) {
        //Ignore nil data and push into the per-device buffer
        guard let data = data, let continuation = dataStreamContinuationMap[deviceName] else { return }
        continuation.yield(data)
    }
}
