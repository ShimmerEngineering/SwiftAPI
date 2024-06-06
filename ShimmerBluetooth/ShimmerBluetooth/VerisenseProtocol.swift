//
//  Shimmer3BluetoothProtocol.swift
//  ShimmerBluetooth
//
//  Created by Shimmer Engineering on 19/10/2023.
//

import Foundation


public class VerisenseProtocol : NSObject, ShimmerProtocol {
    public var REV_HW_MAJOR: Int = -1
    
    public var REV_HW_MINOR: Int = -1
    
    public var REV_FW_MAJOR: Int = -1
    
    public var REV_FW_MINOR: Int = -1
    
    public var REV_FW_INTERNAL: Int = -1
    
    public var delegate: ShimmerProtocolDelegate?
    private var continuation: CheckedContinuation<Bool?, Never>?
    public func connect() async -> Bool {
        return true
    }
    
    public func disconnect() async -> Bool {
        return true
    }
    
    private var radio: BleByteRadio?
    let timeoutInSeconds: TimeInterval = 1 // Set your desired timeout duration in seconds
        
    public func sayHello(){
        print("Hello")
    }
    
    public init(radio:BleByteRadio) {
        super.init()
        self.radio = radio
        self.radio?.delegate = self
    }

    
    
    
    
    
    
    public func sendReadProductionCommand() async -> Bool?{
        let bytes:[UInt8] = [0x13,0x00,0x00]
        //let data = Data(bytes)
        //enableNotifications(enable: true)
        radio!.writeBytes(bytes:bytes)
        
        return await withCheckedContinuation { continuation in
            if self.continuation == nil {
                // 2
                self.continuation = continuation
            }
        }
    }
    public func sendReadStatusCommand() async -> Bool?{
        let bytes:[UInt8] = [0x11,0x00,0x00]
        //let data = Data(bytes)
        //enableNotifications(enable: true)
        radio!.writeBytes(bytes: bytes)
        return await withCheckedContinuation { continuation in
            if self.continuation == nil {
                // 2
                self.continuation = continuation
            }
        }
    }
    var startTime = CFAbsoluteTimeGetCurrent()
        
    public func sendReadMemoryLookupTableRequest() async{
        startTime = CFAbsoluteTimeGetCurrent()
        totalProcessedBytes=0
        let bytes:[UInt8] = [0x29,0x01,0x00,0x01]
        radio!.writeBytes(bytes: bytes)
    }
    
    private var totalProcessedBytes: Int = 0
        
        func calculateThroughput(data: [UInt8]) -> Double {
            let dataSize = data.count

            
            // Process the data (your specific processing logic)
            
            let endTime = CFAbsoluteTimeGetCurrent()
            let elapsedTime = endTime - startTime

            // Update the cumulative values
            totalProcessedBytes += dataSize
            print("datasize: \(totalProcessedBytes) elapsed time: \(elapsedTime)" )
            // Calculate cumulative throughput in KB/s
            let cumulativeThroughputKBs = Double(totalProcessedBytes) / (1024.0 * elapsedTime)
            
            return cumulativeThroughputKBs
        }
    
    private func processData(_ data: Data) {
        print(data as NSData)
        var received:[UInt8] = []
        received = Array(data)
        print(received)
        var tp = calculateThroughput(data:received)
        print("Cumulative Throughput: \(tp) KB/s")
        let bytes: [UInt8]=[received[1],received[2]]
        let u16 = UnsafePointer(bytes).withMemoryRebound(to: UInt16.self, capacity: 1){
            $0.pointee
        }
        print("u16: \(u16)")
        if ((data.count-3)==Int(u16)){
            if( received[0]==0x33) {
                
                print("Read Production Config Command Received")
                REV_HW_MAJOR=Int(received[10])
                REV_HW_MINOR=Int(received[11])
                REV_FW_MAJOR=Int(received[12])
                REV_FW_MINOR=Int(received[13])
                REV_FW_INTERNAL = Int(Int(received[15]) << 8) | Int(received[14])
                print("HW VERSION \(REV_HW_MAJOR) . \(REV_HW_MINOR)")
                print("FW VERSION \(REV_FW_MAJOR) . \(REV_FW_MINOR). \(REV_FW_INTERNAL)")
                self.delegate?.shimmerProtocolNewMessage(message: "HW VERSION \(REV_HW_MAJOR) . \(REV_HW_MINOR)")
                
            } else if (received[0]==0x31){
                print("Read Status Command Received")
                
            }
        } else {
            print("")
            return
        }
    }
}
extension VerisenseProtocol : ByteCommunicationDelegate {
    public func byteCommunicationConnected() {
        
    }
    
    public func byteCommunicationDisconnected(connectionloss: Bool) {
    
    }
    
    public func byteCommunicationDataReceived(data: Data?) {
        self.processData(data!)
        self.continuation?.resume(returning: true)
        self.continuation = nil
    }
    
}
