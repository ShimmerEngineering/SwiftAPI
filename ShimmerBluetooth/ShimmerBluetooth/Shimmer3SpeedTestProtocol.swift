//
//  Shimmer3SpeedTestProtocol.swift
//  ShimmerBluetooth
//
//  Created by Shimmer Engineering on 16/04/2024.
//

import Foundation
public class Shimmer3SpeedTestProtocol : NSObject, ShimmerProtocol {
    public var REV_HW_MAJOR: Int = -1
    
    public var REV_HW_MINOR: Int = -1
    
    public var REV_FW_MAJOR: Int = -1
    
    public var REV_FW_MINOR: Int = -1
    
    var receivedBytes: [UInt8] = []
    private var processing: Bool = false
    // A DispatchQueue for background processing
    private let processingQueue = DispatchQueue(label: "com.shimmerresearch.ByteProcessingQueue", attributes: .concurrent)
    
    private var radio: BleByteRadio?
    var deviceName : String?
    public init(radio:BleByteRadio) {
        super.init()
        self.radio = radio
        self.deviceName = radio.deviceName
        self.radio?.delegate = self
    }
    
    public func startSpeedTest(){
        let bytes:[UInt8] = [0xA4,0x01]
        //let data = Data(bytes)
        //enableNotifications(enable: true)
        radio!.writeBytes(bytes:bytes)
    }
    
    public func connect() async -> Bool {
        var result = await radio?.connect()
        if (result!){
            startProcessing()
        }
        return result!
    }
    
    public func disconnect() async -> Bool {
        var result = await radio?.disconnect()
        return result!
    }
    let synchronizationQueue = DispatchQueue(label: "com.shimmerresearch.speedtestprotocol")

    var firstime = true
    var TestSignalTotalNumberOfBytes = 0
    var speedTestData: [UInt8] = []
    var lengthOfPacket = 5;
    var TestSignalTotalEffectiveNumberOfBytes = 0
    var startTime = Date()
    var keepValue = 0
    var NumberofNumbersSkipped = 0
    func startProcessing() {
        self.receivedBytes.removeAll()
        self.processing = true
        processingQueue.async {
            while self.processing {
                    
                self.synchronizationQueue.sync {
                    if (self.firstime && self.receivedBytes.count>0){
                        print(self.receivedBytes.removeFirst())
                        self.firstime = false;
                        self.startTime = Date()
                    }
                    self.TestSignalTotalNumberOfBytes += self.receivedBytes.count
                    self.speedTestData += self.receivedBytes
                    self.receivedBytes.removeAll()
                    
                    while(self.speedTestData.count >= (self.lengthOfPacket+1))
                    {
                        if (self.speedTestData[0] == 165 && self.speedTestData[5] == 165) //165 = 0XA5
                        {
                            var packet = Array(self.speedTestData.prefix(5))
                            self.speedTestData.removeFirst(5)
                            let removedBytesString = packet.map { String($0) }.joined(separator: " ")
                            //print("Removed bytes: \(removedBytesString)")
                            if (packet[0] == 0xA5)
                            {
                                self.TestSignalTotalEffectiveNumberOfBytes += self.lengthOfPacket
                                packet.removeFirst();
                                let data = Data(packet)
                                // Use withUnsafeBytes to access the contents as a contiguous block of memory
                                let intValue = data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> Int32 in
                                    ptr.load(as: Int32.self)
                                }
                                //print("intValue:", intValue)
                                
                                if (self.keepValue != 0)
                                {
                                    var difference = Int(intValue) - self.keepValue;
                                    if ((difference) != 1)
                                    {
                                        self.NumberofNumbersSkipped += difference;
                                    }
                                }
                                
                                if (intValue%500==0){
                                    let endTime = Date()
                                    let elapsedTime = endTime.timeIntervalSince(self.startTime)
                                    print("Elapsed time: \(elapsedTime) seconds")
                                    let throughput = Double(self.TestSignalTotalEffectiveNumberOfBytes)/elapsedTime
                                    print("B/s: \(throughput) , number of skips: \(self.NumberofNumbersSkipped)")
                                }
                            }
                        }
                    }
                    
                }
                    /*
                    self.queue.sync {
                        if self.receivedBytes.count>0{
                            print(self.receivedBytes.removeFirst())
                            
                        }
                    }
                     */
                
                
                // Add a delay to avoid busy-waiting
                Thread.sleep(forTimeInterval: 0.001)
            }
        }
    }
    
    func stopProcessing(){
        self.processing = false
    }
    let queue = DispatchQueue(label: "thread-safe-obj", attributes: .concurrent)
    private func processData(_ data: Data) {
        var received:[UInt8] = []
        received = Array(data)
        queue.async(flags: .barrier) {
            self.synchronizationQueue.sync {
                self.receivedBytes.append(contentsOf: received)
            }
        }

    }
    
}
extension Shimmer3SpeedTestProtocol : ByteCommunicationDelegate {
    public func byteCommunicationConnected() {
        
    }
    
    public func byteCommunicationDisconnected(connectionloss: Bool) {
        stopProcessing()
    }
    
    public func byteCommunicationDataReceived(data: Data?, deviceName: String) {
        self.processData(data!)
    }
    
}
