//
//  Shimmer3Protocol.swift
//  ShimmerBluetooth
//
//  Created by Shimmer Engineering on 24/10/2023.
//

import Foundation

public class Shimmer3Protocol : NSObject, ShimmerProtocol {
    
    public enum HardwareType: Int {
        case UNKNOWN = -1
        case Shimmer3 = 3
        case Shimmer3R = 10
        var description: String {
            switch self {
            case .Shimmer3:
                return "Shimmer3"
            case .Shimmer3R:
                return "Shimmer3R"
            case .UNKNOWN:
                return "Unknown"
            }
        }
    }

    var startTime = Date()
    var numberOfPackets = 0
    public var REV_HW_MAJOR: Int = -1
    
    public var REV_HW_MINOR: Int = -1
    
    public var REV_FW_IDENTIFIER: Int = -1
    
    public var REV_FW_MAJOR: Int = -1
    
    public var REV_FW_MINOR: Int = -1
    
    public var REV_FW_INTERNAL: Int = -1
    
    public var EXPANSION_BOARD_ID: Int = -1

    public var EXPANSION_BOARD_REV: Int = -1
    
    public var EXPANSION_BOARD_REV_SPECIAL: Int = -1

    public var lnAccelSensor: LNAccelSensor = LNAccelSensor(hwid: HardwareType.UNKNOWN.rawValue)
    public var wrAccelSensor: WRAccelSensor = WRAccelSensor(hwid: HardwareType.UNKNOWN.rawValue)
    var timeSensor: TimeSensor = TimeSensor()
    public var magSensor: MagSensor = MagSensor(hwid: HardwareType.UNKNOWN.rawValue)
    public var gyroSensor: GyroSensor = GyroSensor(hwid: HardwareType.UNKNOWN.rawValue)
    var adcA13Sensor: ADCSensor = ADCSensor()
    var adcA12Sensor: ADCSensor = ADCSensor()
    var adcA1Sensor: ADCSensor = ADCSensor()
    var adcA7Sensor: ADCSensor = ADCSensor()
    var adcA6Sensor: ADCSensor = ADCSensor()
    var adcA15Sensor: ADCSensor = ADCSensor()
    var gsrSensor: GSRSensor = GSRSensor()
    public var exgSensor: EXGSensor = EXGSensor()
    public var pressureTempSensor : PressureTempSensor = PressureTempSensor(hwid: HardwareType.UNKNOWN.rawValue)
    var battVoltageSensor : BattVoltageSensor = BattVoltageSensor()
    public var RTCErrorEnabled = false;
    var infoMem: [UInt8] = []
    var inquiry: [UInt8] = []
    var calibdumpresponse: [UInt8] = []
    var receivedBytes: [UInt8] = []
    var commandSent:PacketTypeShimmer?
    var CRCMode:BTCRCMode = BTCRCMode.OFF
    var BTState:Shimmer3BTState = Shimmer3BTState.DISCONNECTED
    var deviceName : String?
    private var continuation: CheckedContinuation<Bool?, Never>?
    private var continuationByteArray: CheckedContinuation<[UInt8]?, Never>?
    public var shimmer3InfoMem: Shimmer3InfoMem = Shimmer3InfoMem()
    
    let timeoutInSeconds: TimeInterval = 1 // Set your desired timeout duration in seconds

    public enum SamplingRate: Double {
        case RATE_1Hz = 1.0
        case RATE_10_2Hz = 10.2
        case RATE_51_2Hz = 51.2
        case RATE_102_4Hz = 102.4
        case RATE_204_8Hz = 204.8
        case RATE_256Hz = 256.0
        case RATE_512Hz = 512.0
        case RATE_1024Hz = 1024.0
        
        public static func fromValue(_ value: Double) -> SamplingRate? {
            switch value {
            case 0:
                return .RATE_1Hz
            case 1:
                return .RATE_10_2Hz
            case 2:
                return .RATE_51_2Hz
            case 3:
                return .RATE_102_4Hz
            case 4:
                return .RATE_204_8Hz
            case 5:
                return .RATE_256Hz
            case 6:
                return .RATE_512Hz
            case 7:
                return .RATE_1024Hz
            default:
                return nil
            }
        }
        
    }
    var CurrentSamplingRate = SamplingRate.RATE_51_2Hz.rawValue

    public func getInfoMemByteArray() -> [UInt8]{
        return infoMem
    }
    
    func writeInfoMem(bytes:[UInt8]) async -> Bool{
        
        radio!.writeBytes(bytes:bytes)
        let result = await withCheckedContinuation { continuation in
            if self.continuation == nil {
                // 2
                self.continuation = continuation
            }
        }
        
        return result!
    }
    
    public func writeShimmer3InfoMem(infoMem:[UInt8]) async -> Bool{
        self.changeState(btState:Shimmer3BTState.CONFIGURING)
        if(infoMem.count != (128*3)){
            return false;
        } else {
            commandSent = PacketTypeShimmer.setInfoMem
            var im0 = [UInt8](repeating: 0, count: 128 + 4)
            var im1 = [UInt8](repeating: 0, count: 128 + 4)
            var im2 = [UInt8](repeating: 0, count: 128 + 4)
            let cmdim0: [UInt8] = [PacketTypeShimmer.setInfoMem.rawValue, 0x80, 0x00, 0x00]
            let cmdim1: [UInt8] = [PacketTypeShimmer.setInfoMem.rawValue, 0x80, 0x80, 0x00]
            let cmdim2: [UInt8] = [PacketTypeShimmer.setInfoMem.rawValue, 0x80, 0x00, 0x01]

            im0.replaceSubrange(0..<cmdim0.count, with: cmdim0)
            im1.replaceSubrange(0..<cmdim1.count, with: cmdim1)
            im2.replaceSubrange(0..<cmdim2.count, with: cmdim2)

            let startIndex = 0
            let infoMemStartIndex = 0

            im0.replaceSubrange(4..<132, with: infoMem[infoMemStartIndex..<(infoMemStartIndex + 128)])
            im1.replaceSubrange(4..<132, with: infoMem[(infoMemStartIndex + 128)..<(infoMemStartIndex + 256)])
            im2.replaceSubrange(4..<132, with: infoMem[(infoMemStartIndex + 256)..<(infoMemStartIndex + 384)])
            var res = await writeInfoMem(bytes:im0)
            if res {
                res = await writeInfoMem(bytes:im1)
                if res {
                    var res = await writeInfoMem(bytes:im2)
                    if res {
                        self.infoMem = infoMem
                        initializeSensors()
                        res = await sendInquiryCommand()!
                    }
                }
            }
            if (res){
                self.changeState(btState:Shimmer3BTState.CONNECTED)
            }
            return res
            
        }
    }
    
    public func getSamplingRateIndex()->Int{
        var index = 0
        if(CurrentSamplingRate.isEqual(to: Shimmer3Protocol.SamplingRate.RATE_1Hz.rawValue)){
            index = 0
        }else if(CurrentSamplingRate.isEqual(to: Shimmer3Protocol.SamplingRate.RATE_10_2Hz.rawValue)){
            index = 1
        }else if(CurrentSamplingRate.isEqual(to: Shimmer3Protocol.SamplingRate.RATE_51_2Hz.rawValue)){
            index = 2
        }else if(CurrentSamplingRate.isEqual(to: Shimmer3Protocol.SamplingRate.RATE_102_4Hz.rawValue)){
            index = 3
        }else if(CurrentSamplingRate.isEqual(to: Shimmer3Protocol.SamplingRate.RATE_204_8Hz.rawValue)){
            index = 4
        }else if(CurrentSamplingRate.isEqual(to: Shimmer3Protocol.SamplingRate.RATE_256Hz.rawValue)){
            index = 5
        }else if(CurrentSamplingRate.isEqual(to: Shimmer3Protocol.SamplingRate.RATE_512Hz.rawValue)){
            index = 6
        }else if(CurrentSamplingRate.isEqual(to: Shimmer3Protocol.SamplingRate.RATE_1024Hz.rawValue)){
            index = 7
        }
        return index
    }
    
    public func getCalibrationDump() async {
        var byteresult:[UInt8]?=[]
        calibdumpresponse = []
        byteresult = await sendGetMemoryCommand(cmd: PacketTypeShimmer.getCalibDumpCommand,val0: 0x80, val1: 0x00, val2: 0x00)
        var length = (Int(byteresult![0]) + (Int(byteresult![1])<<8)) + 2
        print("Calibration Dump Length: \(length)")
        calibdumpresponse.append(contentsOf: byteresult!)
        /*
        byteresult = await sendGetMemoryCommand(cmd: PacketTypeShimmer.getCalibDumpCommand,val0: 0x80, val1: 0x00, val2: 0x01)
        calibdumpresponse.append(contentsOf: byteresult!)
        byteresult = await sendGetMemoryCommand(cmd: PacketTypeShimmer.getCalibDumpCommand,val0: 0x80, val1: 0x80, val2: 0x01)
        calibdumpresponse.append(contentsOf: byteresult!)
        byteresult = await sendGetMemoryCommand(cmd: PacketTypeShimmer.getCalibDumpCommand,val0: 0x1A, val1: 0x00, val2: 0x02)
        calibdumpresponse.append(contentsOf: byteresult!)
         */
        while (calibdumpresponse.count != length){
            var address = Array(ShimmerUtilities.intToUInt8Array(calibdumpresponse.count).reversed())
            var count = length - calibdumpresponse.count
            if (count>=128){
                count = 128
            }
            byteresult = await sendGetMemoryCommand(cmd: PacketTypeShimmer.getCalibDumpCommand,val0: UInt8(count), val1: address[0], val2: address[1])
            calibdumpresponse.append(contentsOf: byteresult!)
        }
    }
    
    public func setEnableRTCLEDError(enable: Bool, infomem: [UInt8])-> [UInt8]{
        var infomemtoupdate = infomem
        if (enable){
            infomemtoupdate[ConfigByteLayoutShimmer3.idxSDExperimentConfig0] = infomemtoupdate[ConfigByteLayoutShimmer3.idxSDExperimentConfig0] | (1<<ConfigByteLayoutShimmer3.bitShiftRTCError)
        } else {
            var data = (1<<ConfigByteLayoutShimmer3.bitShiftRTCError);
            var value = UInt8(ShimmerUtilities.calculateOnesComplement(of: data,bitWidth: 8));
            infomemtoupdate[ConfigByteLayoutShimmer3.idxSDExperimentConfig0] = infomemtoupdate[ConfigByteLayoutShimmer3.idxSDExperimentConfig0] & value;
        }
        return infomemtoupdate
    }
    
    func changeState(btState:Shimmer3BTState){
        BTState = btState
        self.delegate?.shimmerBTStateChange(message: BTState)
    }
    
    public func connect() async -> Bool {
        changeState(btState:Shimmer3BTState.CONNECTING)
        var result = await radio?.connect()
        if (result!){
            startProcessing()
            let res = await sendCRCCommand(crcMode: BTCRCMode.TWO_BYTE)
            if (res!){
                await sendReadFWVersionCommand()
                await sendReadShimmerVersionCommand()
                await sendReadExpBoardVersionCommand()
                createSensors()
                //[0x8E 0x80 0x00 0x00]
                //[0x8E 0x80 0x80 0x00]
                //[0x8E 0x80 0x00 0x01]
                infoMem = []
                inquiry = []
                var byteresult = await sendGetMemoryCommand(cmd: PacketTypeShimmer.getInfoMem,val0: 0x80, val1: 0x00, val2: 0x00)
                infoMem.append(contentsOf: byteresult!)
                byteresult = await sendGetMemoryCommand(cmd: PacketTypeShimmer.getInfoMem,val0: 0x80, val1: 0x80, val2: 0x00)
                infoMem.append(contentsOf: byteresult!)
                byteresult = await sendGetMemoryCommand(cmd: PacketTypeShimmer.getInfoMem,val0: 0x80, val1: 0x00, val2: 0x01)
                infoMem.append(contentsOf: byteresult!)
                print("Infomem \(infoMem)")
                await getCalibrationDump()
                parseCalibrationDump(calibdumpresponse)
                if (Shimmer3InfoMem.checkConfigBytesValid(infoMemContents: infoMem))
                {
                    print("Infomem Valid, number of Bytes \(infoMem.count)")
                } else {
                    print("Infomem Invalid")
                }
                shimmer3InfoMem.configByteParse(configBytes: infoMem)
                initializeSensors()
                if (REV_HW_MAJOR==HardwareType.Shimmer3.rawValue){
                    await sendBMP280PressureCalibCoefficientsCommand()
                } else if (REV_HW_MAJOR==HardwareType.Shimmer3R.rawValue){
                    await sendPressureCalibCoefficientsCommand()
                }
                
                await sendInquiryCommand()
                changeState(btState:Shimmer3BTState.CONNECTED)
                print("Current State: \(BTState)")
            }
        } else {
            return false
        }
        return true
    }
    
    func parseCalibrationDump(_ bytes:[UInt8]){
        let length = Int(bytes[0]) + (Int(bytes[1])<<8)
        var calibrationBytes = Array(bytes.prefix(length+2))
        let infoBytes = Array(calibrationBytes.prefix(10))
        calibrationBytes.removeFirst(10)
        print(infoBytes)
        while(calibrationBytes.count>10){

            let calibrationlength = Int(calibrationBytes[3])
            let sensorcalibrationdumplength = calibrationlength + 12 //4 + 8TS
            let sensorcalibrationdump = Array(calibrationBytes.prefix(sensorcalibrationdumplength))
            print(sensorcalibrationdump)
            calibrationBytes.removeFirst(sensorcalibrationdumplength)
            lnAccelSensor.parseSensorCalibrationDump(bytes: sensorcalibrationdump)
            gyroSensor.parseSensorCalibrationDump(bytes: sensorcalibrationdump)
            wrAccelSensor.parseSensorCalibrationDump(bytes: sensorcalibrationdump)
            magSensor.parseSensorCalibrationDump(bytes: sensorcalibrationdump)
        }
    }
    
    func createSensors(){
        if (REV_HW_MAJOR==HardwareType.Shimmer3.rawValue){
            lnAccelSensor = LNAccelSensor(hwid: REV_HW_MAJOR)
            wrAccelSensor = WRAccelSensor(hwid: REV_HW_MAJOR)
            timeSensor = TimeSensor()
            magSensor = MagSensor(hwid: REV_HW_MAJOR)
            gyroSensor = GyroSensor(hwid: REV_HW_MAJOR)
            adcA13Sensor = ADCSensor(adc: ADCSensor.ADCType.Shimmer3_A13)
            adcA12Sensor = ADCSensor(adc: ADCSensor.ADCType.Shimmer3_A12)
            adcA1Sensor = ADCSensor(adc: ADCSensor.ADCType.Shimmer3_A1)
            adcA7Sensor = ADCSensor(adc: ADCSensor.ADCType.Shimmer3_A7)
            adcA6Sensor = ADCSensor(adc: ADCSensor.ADCType.Shimmer3_A6)
            adcA15Sensor = ADCSensor(adc: ADCSensor.ADCType.Shimmer3_A15)
            gsrSensor = GSRSensor()
            exgSensor = EXGSensor()
            pressureTempSensor = PressureTempSensor(hwid: REV_HW_MAJOR)
            battVoltageSensor = BattVoltageSensor()
        } else if(REV_HW_MAJOR==HardwareType.Shimmer3R.rawValue){
            lnAccelSensor = LNAccelSensor(hwid: REV_HW_MAJOR)
            timeSensor = TimeSensor()
        }
    }
    
    func initializeSensors(){
        if (REV_HW_MAJOR==HardwareType.Shimmer3.rawValue){
            lnAccelSensor.setInfoMem(infomem: infoMem)
            wrAccelSensor.setInfoMem(infomem: infoMem)
            timeSensor.setInfoMem(infomem: infoMem)
            magSensor.setInfoMem(infomem: infoMem)
            gyroSensor.setInfoMem(infomem: infoMem)
            adcA13Sensor.setInfoMem(infomem: infoMem)
            adcA7Sensor.setInfoMem(infomem: infoMem)
            adcA6Sensor.setInfoMem(infomem: infoMem)
            adcA15Sensor.setInfoMem(infomem: infoMem)
            adcA12Sensor.setInfoMem(infomem: infoMem)
            adcA1Sensor.setInfoMem(infomem: infoMem)

            gsrSensor.setInfoMem(infomem: infoMem)
            exgSensor.setInfoMem(infomem: infoMem)
            pressureTempSensor.setInfoMom(infomem: infoMem)
            battVoltageSensor.setInfoMom(infomem: infoMem)
        } else  if (REV_HW_MAJOR==HardwareType.Shimmer3R.rawValue){
            timeSensor.setInfoMem(infomem: infoMem)
            lnAccelSensor.setInfoMem(infomem: infoMem)
        }
    }

    
    public func disconnect() async -> Bool {
        var result = await radio?.disconnect()
        return result!
    }
    
    private func removeACKandCRCForResponse(bytes:inout[UInt8]){
        bytes.removeFirst() //remove ack
        bytes.removeFirst() //remove response type
        if(self.CRCMode == BTCRCMode.ONE_BYTE){
            bytes.removeLast()
        } else if(self.CRCMode == BTCRCMode.TWO_BYTE){
            bytes.removeLast()
            bytes.removeLast()
        }
    }
    
    private func buildMsg(bytes:[UInt8]) -> ObjectCluster{
        var ojc = ObjectCluster(deviceName: self.deviceName!)
        if timeSensor.sensorEnabled {
            ojc = timeSensor.processData(sensorPacket: bytes, objectCluster: ojc)
        }
        if lnAccelSensor.sensorEnabled {
            ojc = lnAccelSensor.processData(sensorPacket: bytes, objectCluster: ojc)
        }
        if wrAccelSensor.sensorEnabled {
            ojc = wrAccelSensor.processData(sensorPacket: bytes, objectCluster: ojc)
        }
        if magSensor.sensorEnabled {
            ojc = magSensor.processData(sensorPacket: bytes, objectCluster: ojc)
        }
        if gyroSensor.sensorEnabled {
            ojc = gyroSensor.processData(sensorPacket: bytes, objectCluster: ojc)
        }
        if adcA13Sensor.sensorEnabled {
            ojc = adcA13Sensor.processData(sensorPacket: bytes, objectCluster: ojc)
        }
        if adcA12Sensor.sensorEnabled {
            ojc = adcA12Sensor.processData(sensorPacket: bytes, objectCluster: ojc)
        }
        if adcA1Sensor.sensorEnabled {
            ojc = adcA1Sensor.processData(sensorPacket: bytes, objectCluster: ojc)
        }
        if adcA15Sensor.sensorEnabled {
            ojc = adcA15Sensor.processData(sensorPacket: bytes, objectCluster: ojc)
        }
        if adcA6Sensor.sensorEnabled {
            ojc = adcA6Sensor.processData(sensorPacket: bytes, objectCluster: ojc)
        }
        if adcA7Sensor.sensorEnabled {
            ojc = adcA7Sensor.processData(sensorPacket: bytes, objectCluster: ojc)
        }
        if gsrSensor.sensorEnabled {
            ojc = gsrSensor.processData(sensorPacket: bytes, objectCluster: ojc)
        }
        if exgSensor.sensorEnabled{
            ojc = exgSensor.processData(sensorPacket: bytes, objectCluster: ojc)
        }
        if pressureTempSensor.sensorEnabled{
            ojc = pressureTempSensor.processData(sensorPacket: bytes, objectCluster: ojc)
        }
        if battVoltageSensor.sensorEnabled{
            ojc = battVoltageSensor.processData(sensorPacket: bytes, objectCluster: ojc)
        }
        if (numberOfPackets==0){
            startTime = Date()
        }
        numberOfPackets+=1
        let endTime = Date()
        var elapsedTime = endTime.timeIntervalSince(self.startTime)
        if (elapsedTime == 0){
            elapsedTime = 1
        }
        var PRR = Int((((Double)(numberOfPackets)/self.CurrentSamplingRate)/elapsedTime)*100)
        if (PRR>100){
            PRR=100
        }
        ojc.PacketReceptionRate = PRR
        print("Elapsed time: \(elapsedTime) seconds ; Number of packets: \(numberOfPackets) ; Packet Reception Rate(%): \(PRR)")
        return ojc
    }
    
    private var radio: BleByteRadio?
    public var delegate: ShimmerProtocolDelegate?
    public let TimeStampPacketByteSize = 3;
    private var EnabledSensors = 0;
    private var PacketSize = 0;
    private var SignalDataTypeArray = [SensorDataType]()
    private var processing: Bool = false
    
    // A DispatchQueue for background processing
    private let processingQueue = DispatchQueue(label: "com.shimmerresearch.ByteProcessingQueue", attributes: .concurrent)
    
    // Start the processing loop
    func startProcessing() {
        self.receivedBytes.removeAll()
        self.processing = true
        processingQueue.async {
            while self.processing {
                if (self.BTState == Shimmer3BTState.STREAMING){
                    
                    if (self.receivedBytes.count>self.PacketSize){
                        var received = Array(self.receivedBytes.prefix(self.PacketSize+1)) //1 for the start of the packet
                        print(received)
                        received.removeFirst()
                        var ojc = self.buildMsg(bytes: received)
                        self.delegate?.shimmerProtocolNewObjectCluster(message: ojc)
                        self.receivedBytes.removeFirst(self.PacketSize+1)
                    }
                    if (self.receivedBytes.count==1+self.CRCMode.rawValue){ //ack+crc
                        if (self.commandSent==PacketTypeShimmer.stopStreamingCommand){
                            print("Streaming stop")
                            print(self.receivedBytes)
                            self.changeState(btState:Shimmer3BTState.CONNECTED)
                            self.receivedBytes.removeAll()
                        }
                    }
                }
                else{
                    if (self.receivedBytes.first==PacketTypeShimmer.ackCommand.rawValue){
                        if (self.commandSent==PacketTypeShimmer.getCalibDumpCommand){
                            if (self.receivedBytes[1] == PacketTypeShimmer.calibDumpResponse.rawValue)
                            {
                                Thread.sleep(forTimeInterval: 0.5)
                                var received = self.receivedBytes
                                print("\(received.count) data: \(received)")
                                let length = received[2]
                                if (received.count == (length + 3 + 2 + self.CRCMode.rawValue)){ //3=ack byte and response byte and length byte, 2 = currentmemoryoffset
                                    print("Expected calib dump length received")
                                } else {
                                    print("[DEBUG] unexpected infomem length received")
                                }
                                
                                var crcresult = true
                                if(self.CRCMode != BTCRCMode.OFF){
                                    print("CRC infomem Calculated: \(self.shimmerUartCrcCalc(received,(received.count-Int(self.CRCMode.rawValue))))")
                                    crcresult = self.checkCrc(received,(received.count-Int(self.CRCMode.rawValue)))
                                    print("CRC infomem Check:  \(crcresult) ")
                                }
                                if (crcresult){
                                    self.removeACKandCRCForResponse(bytes: &received)
                                    received.removeFirst() //remove the length
                                    received.removeFirst() //remove the offset
                                    received.removeFirst() //remove the offset
                                    self.continuationByteArray?.resume(returning: received)
                                    self.continuationByteArray = nil
                                } else{
                                    self.continuationByteArray?.resume(returning: nil)
                                    self.continuationByteArray = nil
                                    print("[CRC ERROR] : \(self.commandSent!)")
                                }
                                self.receivedBytes.removeAll()
                            }
                        }
                        if (self.commandSent==PacketTypeShimmer.getInfoMem){
                            if (self.receivedBytes[1] == PacketTypeShimmer.getInfoMemResponse.rawValue)
                            {
                                Thread.sleep(forTimeInterval: 0.5)
                                //print(self.receivedBytes)
                                var received = self.receivedBytes
                                //print(received)
                                let length = received[2]
                                if (received.count == (length + 3 + self.CRCMode.rawValue)){ //3=ack byte and response byte and length byte
                                    print("Expected infomem length received")
                                } else {
                                    print("[DEBUG] unexpected infomem length received")
                                }
                                var crcresult = true
                                if(self.CRCMode != BTCRCMode.OFF){
                                    print("CRC infomem Calculated: \(self.shimmerUartCrcCalc(received,(received.count-Int(self.CRCMode.rawValue))))")
                                    crcresult = self.checkCrc(received,(received.count-Int(self.CRCMode.rawValue)))
                                    print("CRC infomem Check:  \(crcresult) ")
                                }
                                if (crcresult){
                                    self.removeACKandCRCForResponse(bytes: &received)
                                    received.removeFirst() //remove the length
                                    self.continuationByteArray?.resume(returning: received)
                                    self.continuationByteArray = nil
                                } else{
                                    self.continuationByteArray?.resume(returning: nil)
                                    self.continuationByteArray = nil
                                    print("[CRC ERROR] : \(self.commandSent!)")
                                }
                                self.receivedBytes.removeAll()
                            }
                        }
                        if (self.commandSent==PacketTypeShimmer.setCRCCommand){

                            let received = Array(self.receivedBytes.prefix(1+Int(self.CRCMode.rawValue)))
                            self.receivedBytes.removeFirst(1+Int(self.CRCMode.rawValue))
                            var crcresult = true
                            if(self.CRCMode != BTCRCMode.OFF){
                                print("CRC 3 Calculated: \(self.shimmerUartCrcCalc(received,(received.count-Int(self.CRCMode.rawValue))))")
                                crcresult = self.checkCrc(received,(received.count-Int(self.CRCMode.rawValue)))
                                print("CRC 3 Check:  \(crcresult) ")
                            }
                            if (crcresult){
                                self.continuation?.resume(returning: true)
                                self.continuation = nil
                            } else{
                                self.continuation?.resume(returning: false)
                                self.continuation = nil
                                print("[CRC ERROR] : \(self.commandSent!)")
                            }
                            print("Command ACK Received and Processed: \(self.commandSent!)")
                        } else if(self.commandSent == PacketTypeShimmer.setInfoMem){
                            let received = Array(self.receivedBytes.prefix(1+Int(self.CRCMode.rawValue)))
                            self.receivedBytes.removeFirst(1+Int(self.CRCMode.rawValue))
                            var crcresult = true
                            if(self.CRCMode != BTCRCMode.OFF){
                                print("CRC InfoMem Calculated: \(self.shimmerUartCrcCalc(received,(received.count-Int(self.CRCMode.rawValue))))")
                                crcresult = self.checkCrc(received,(received.count-Int(self.CRCMode.rawValue)))
                                print("CRC InfoMem Check:  \(crcresult) ")
                            }
                            if (crcresult){
                                self.continuation?.resume(returning: true)
                                self.continuation = nil
                            } else{
                                self.continuation?.resume(returning: false)
                                self.continuation = nil
                                print("[CRC ERROR] : \(self.commandSent!)")
                            }
                            print("Command ACK Received and Processed: \(self.commandSent!)")
                        } else if (self.commandSent==PacketTypeShimmer.inquiryCommand){
                            if (self.receivedBytes[1] == PacketTypeShimmer.inquiryResponse.rawValue)
                            {
                                print(self.receivedBytes.map { String($0) }.joined(separator: " "))
                                var length = 1 + 1 + 8 //ack + response byte + 8
                                var xlength = 0
                                if (self.REV_HW_MAJOR==HardwareType.Shimmer3R.rawValue){
                                    xlength = 3
                                    length = length + xlength
                                }
                                var received = Array(self.receivedBytes.prefix(length))
                                self.receivedBytes.removeFirst(length)
                                
                                for index in 0..<(received[2+6+xlength]+self.CRCMode.rawValue){
                                    received.append(self.receivedBytes.removeFirst())
                                }
                                var crcresult = true
                                if(self.CRCMode != BTCRCMode.OFF){
                                    print("CRC 3 Calculated: \(self.shimmerUartCrcCalc(received,(received.count-Int(self.CRCMode.rawValue))))")
                                    crcresult = self.checkCrc(received,(received.count-Int(self.CRCMode.rawValue)))
                                    print("CRC 3 Check:  \(crcresult) ")
                                }
                                if (crcresult){
                                    print("Inquiry Response Received")
                                    self.removeACKandCRCForResponse(bytes: &received)
                                    print(received)
                                    self.inquiry = received
                                    if (self.REV_HW_MAJOR==HardwareType.Shimmer3R.rawValue){
                                        self.interpretInquiryResponseShimmer3R(packet: received)
                                    } else if (self.REV_HW_MAJOR==HardwareType.Shimmer3.rawValue){
                                        self.interpretInquiryResponseShimmer3(packet: received)
                                    }
                                    print("Command ACK Received and Processed: \(self.commandSent!)")
                                    self.continuation?.resume(returning: true)
                                    self.continuation = nil
                                } else{
                                    self.continuation?.resume(returning: false)
                                    self.continuation = nil
                                    print("[CRC ERROR] : \(self.commandSent!)")
                                }
                                
                                
                            }
                        } else if (self.commandSent==PacketTypeShimmer.getShimmerVersionCommand){
                            if (self.receivedBytes[1] == PacketTypeShimmer.getShimmerVersionResponse.rawValue)
                            {
                                var length = 1 + 1 + 1 + Int(self.CRCMode.rawValue)//ack + response byte + 1
                                var received = Array(self.receivedBytes.prefix(length))
                                self.receivedBytes.removeFirst(length)
                                var crcresult = true
                                if(self.CRCMode != BTCRCMode.OFF){
                                    print("CRC Shimmer Version Calculated: \(self.shimmerUartCrcCalc(received,(received.count-Int(self.CRCMode.rawValue))))")
                                    crcresult = self.checkCrc(received,(received.count-Int(self.CRCMode.rawValue)))
                                    print("CRC Shimmer Version Check:  \(crcresult) ")
                                }
                                if (crcresult){
                                    self.removeACKandCRCForResponse(bytes: &received)
                                    print("ShimmerVersion Response Received: \(received)")
                                    self.REV_HW_MAJOR = Int(received[0])
                                    //self.inquiry = received
                                    //self.interpretInquiryResponseShimmer3(packet: received)
                                    print("Command ACK Received and Processed: \(self.commandSent!)")
                                    self.continuation?.resume(returning: true)
                                    self.continuation = nil
                                } else{
                                    self.continuation?.resume(returning: false)
                                    self.continuation = nil
                                    print("[CRC ERROR] : \(self.commandSent!)")
                                }
                                
                            }
                        } else if (self.commandSent==PacketTypeShimmer.getDaughterCardIDCommand){
                            if (self.receivedBytes[1] == PacketTypeShimmer.daughterCardIDResponse.rawValue)
                            {
                                var len = Int(self.receivedBytes[2]);
                                
                                var length = 1 + 1 + 1 + len + Int(self.CRCMode.rawValue)//ack + response byte + 1 (length)
                                var received = Array(self.receivedBytes.prefix(length))
                                self.receivedBytes.removeFirst(length)
                                var crcresult = true
                                if(self.CRCMode != BTCRCMode.OFF){
                                    print("CRC Daughter Card Version Calculated: \(self.shimmerUartCrcCalc(received,(received.count-Int(self.CRCMode.rawValue))))")
                                    crcresult = self.checkCrc(received,(received.count-Int(self.CRCMode.rawValue)))
                                    print("CRC Daugther Card Version Check:  \(crcresult) ")
                                }
                                if (crcresult){
                                    self.removeACKandCRCForResponse(bytes: &received)
                                    print("Daughter Card Version Response Received: \(received)")
                                    self.EXPANSION_BOARD_ID = Int(received[1]) //index starts at 1 because 0 is the length
                                    self.EXPANSION_BOARD_REV = Int(received[2])
                                    self.EXPANSION_BOARD_REV_SPECIAL = Int(received[3])
                                    print("Daughter Card SR \(self.EXPANSION_BOARD_ID).\(self.EXPANSION_BOARD_REV).\(self.EXPANSION_BOARD_REV_SPECIAL)")
                                    //self.REV_HW_MAJOR = Int(received[0])
                                    //self.inquiry = received
                                    //self.interpretInquiryResponseShimmer3(packet: received)
                                    print("Command ACK Received and Processed: \(self.commandSent!)")
                                    self.continuation?.resume(returning: true)
                                    self.continuation = nil
                                } else{
                                    self.continuation?.resume(returning: false)
                                    self.continuation = nil
                                    print("[CRC ERROR] : \(self.commandSent!)")
                                }
                                
                            }
                        } else if (self.commandSent==PacketTypeShimmer.getFWVersionCommand){
                            if (self.receivedBytes[1] == PacketTypeShimmer.fwVersionResponse.rawValue)
                            {
                                var length = 1 + 1 + 6 + Int(self.CRCMode.rawValue)//ack + response byte + 1
                                var received = Array(self.receivedBytes.prefix(length))
                                self.receivedBytes.removeFirst(length)
                                var crcresult = true
                                if(self.CRCMode != BTCRCMode.OFF){
                                    print("CRC FW Version Calculated: \(self.shimmerUartCrcCalc(received,(received.count-Int(self.CRCMode.rawValue))))")
                                    crcresult = self.checkCrc(received,(received.count-Int(self.CRCMode.rawValue)))
                                    print("CRC FW Version Check:  \(crcresult) ")
                                }
                                if (crcresult){
                                    self.removeACKandCRCForResponse(bytes: &received)
                                    self.REV_FW_IDENTIFIER =  Int((UInt16(received[1]) & 0xFF) << 8 | (UInt16(received[0]) & 0xFF))
                                    self.REV_FW_MAJOR = Int((UInt16(received[3]) & 0xFF) << 8 | (UInt16(received[2]) & 0xFF))
                                    self.REV_FW_MINOR = Int(received[4])
                                    self.REV_FW_INTERNAL = Int(received[5])
                                    print("FW Version Response Received: \(self.REV_FW_IDENTIFIER).\(self.REV_FW_MAJOR).\(self.REV_FW_MINOR).\(self.REV_FW_INTERNAL)")
                                    //self.REV_HW_MAJOR = Int(received[0])
                                    //self.inquiry = received
                                    //self.interpretInquiryResponseShimmer3(packet: received)
                                    print("Command ACK Received and Processed: \(self.commandSent!)")
                                    self.continuation?.resume(returning: true)
                                    self.continuation = nil
                                } else{
                                    self.continuation?.resume(returning: false)
                                    self.continuation = nil
                                    print("[CRC ERROR] : \(self.commandSent!)")
                                }
                                
                            }
                        }else if (self.commandSent==PacketTypeShimmer.startStreamingCommand){
                                print("Start Streaming ACK Received")
                                
                                let received = Array(self.receivedBytes.prefix(1+Int(self.CRCMode.rawValue)))
                                self.receivedBytes.removeFirst(1+Int(self.CRCMode.rawValue))
                                print(received)
                                var crcresult = true
                                if(self.CRCMode != BTCRCMode.OFF){
                                    print("CRC 4 Calculated: \(self.shimmerUartCrcCalc(received,(received.count-Int(self.CRCMode.rawValue))))")
                                    crcresult = self.checkCrc(received,(received.count-Int(self.CRCMode.rawValue)))
                                    print("CRC 4 Check:  \(crcresult) ")
                                }
                                if (crcresult){
                                    self.continuation?.resume(returning: true)
                                    self.continuation = nil
                                } else{
                                    self.continuation?.resume(returning: false)
                                    self.continuation = nil
                                    print("[CRC ERROR] : \(self.commandSent!)")
                                }
                            }
                        else if (self.commandSent==PacketTypeShimmer.getBmp280CalibrationCoefficientsCommand){
                            if (self.receivedBytes[1] == PacketTypeShimmer.bmp280CalibrationCoefficientsResponse.rawValue)
                            {
                                print("Get Bmp280 Calib Coefficient ACK Received")
                                Thread.sleep(forTimeInterval: 0.5)
                                
                                
                                var length = 1 + 1 + 24 //ack + response byte + 24
                                var received = Array(self.receivedBytes.prefix(length))
                                received.removeFirst(2)
                                self.pressureTempSensor.parseCalParamByteArray(pressureResoRes: received)
                                print("\(received.count) data: \(received)")
                                
                                var crcresult = true
                                if(self.CRCMode != BTCRCMode.OFF){
                                    print("CRC 5 Calculated: \(self.shimmerUartCrcCalc(self.receivedBytes,(self.receivedBytes.count-Int(self.CRCMode.rawValue))))")
                                    crcresult = self.checkCrc(self.receivedBytes,(self.receivedBytes.count-Int(self.CRCMode.rawValue)))
                                    print("CRC 5 Check:  \(crcresult) ")
                                }
                                if (crcresult){
                                    self.continuation?.resume(returning: true)
                                    self.continuation = nil
                                } else{
                                    self.continuation?.resume(returning: false)
                                    self.continuation = nil
                                    print("[CRC ERROR] : \(self.commandSent!)")
                                }
                                
                            
                                self.receivedBytes.removeAll()

                               
                            }
                        }else if (self.commandSent==PacketTypeShimmer.setSamplingRateCommand){
                            
                            print("Set Sampling Rate Command ACK Received")
                            let received = Array(self.receivedBytes.prefix(1+Int(self.CRCMode.rawValue)))
                            self.receivedBytes.removeFirst(1+Int(self.CRCMode.rawValue))
                            var crcresult = true
                            if(self.CRCMode != BTCRCMode.OFF){
                                print("CRC 3 Calculated: \(self.shimmerUartCrcCalc(received,(received.count-Int(self.CRCMode.rawValue))))")
                                crcresult = self.checkCrc(received,(received.count-Int(self.CRCMode.rawValue)))
                                print("CRC 3 Check:  \(crcresult) ")
                            }
                            if (crcresult){
                                self.continuation?.resume(returning: true)
                                self.continuation = nil
                            } else{
                                self.continuation?.resume(returning: false)
                                self.continuation = nil
                                print("[CRC ERROR] : \(self.commandSent!)")
                            }
                            print("Command ACK Received and Processed: \(self.commandSent!)")
                            self.receivedBytes.removeAll()

                               
                            
                        }else if (self.commandSent==PacketTypeShimmer.setExgRegsCommand){
                            
                            print("Set Exg Regs Command ACK Received")
                            let received = Array(self.receivedBytes.prefix(1+Int(self.CRCMode.rawValue)))
                            self.receivedBytes.removeFirst(1+Int(self.CRCMode.rawValue))
                            var crcresult = true
                            if(self.CRCMode != BTCRCMode.OFF){
                                print("CRC 3 Calculated: \(self.shimmerUartCrcCalc(received,(received.count-Int(self.CRCMode.rawValue))))")
                                crcresult = self.checkCrc(received,(received.count-Int(self.CRCMode.rawValue)))
                                print("CRC 3 Check:  \(crcresult) ")
                            }
                            if (crcresult){
                                self.continuation?.resume(returning: true)
                                self.continuation = nil
                            } else{
                                self.continuation?.resume(returning: false)
                                self.continuation = nil
                                print("[CRC ERROR] : \(self.commandSent!)")
                            }
                            print("Command ACK Received and Processed: \(self.commandSent!)")
                            //self.receivedBytes.removeAll()

                               
                            
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
    
    
    
    func interpretDataPacketFormat(nC: Int, signalid: [UInt8]) {
        //signalDataTypeArray.append("u16")
        var packetSize = 2 // Time stamp

        //if CompatibilityCode >= 6 {
        packetSize = TimeStampPacketByteSize // Time stamp
        timeSensor.packetIndexTimeStamp = 0
        timeSensor.sensorEnabled = true
        //}

        var enabledSensors = Int(0)

        for i in 0..<nC {
            let signalIdByte: UInt8 = signalid[i]

            switch signalIdByte {
            case ChannelContentsShimmer3.XLNAccel.rawValue:
                lnAccelSensor.packetIndexAccelX = packetSize
                packetSize += 2
                enabledSensors |= Int(SensorBitmapShimmer3.SENSOR_A_ACCEL.rawValue)
            case ChannelContentsShimmer3.YLNAccel.rawValue:
                lnAccelSensor.packetIndexAccelY = packetSize
                packetSize += 2
                enabledSensors |= Int(SensorBitmapShimmer3.SENSOR_A_ACCEL.rawValue)
            case ChannelContentsShimmer3.ZLNAccel.rawValue:
                lnAccelSensor.packetIndexAccelZ = packetSize
                packetSize += 2
                enabledSensors |= Int(SensorBitmapShimmer3.SENSOR_A_ACCEL.rawValue)
            case ChannelContentsShimmer3.VBatt.rawValue:
                packetSize += 2
                enabledSensors |= Int(SensorBitmapShimmer3.SENSOR_VBATT.rawValue)
            case ChannelContentsShimmer3.XWRAccel.rawValue:
                wrAccelSensor.packetIndexAccelX = packetSize
                packetSize += 2
                enabledSensors |= Int(SensorBitmapShimmer3.SENSOR_D_ACCEL.rawValue)
            case ChannelContentsShimmer3.YWRAccel.rawValue:
                wrAccelSensor.packetIndexAccelY = packetSize
                packetSize += 2
                enabledSensors |= Int(SensorBitmapShimmer3.SENSOR_D_ACCEL.rawValue)
            case ChannelContentsShimmer3.ZWRAccel.rawValue:
                wrAccelSensor.packetIndexAccelZ = packetSize
                packetSize += 2
                enabledSensors |= Int(SensorBitmapShimmer3.SENSOR_D_ACCEL.rawValue)
            case ChannelContentsShimmer3.XMag.rawValue:
                magSensor.packetIndexMagX = packetSize
                packetSize += 2
                enabledSensors |= Int(SensorBitmapShimmer3.SENSOR_LSM303DLHC_MAG.rawValue)
            case ChannelContentsShimmer3.YMag.rawValue:
                magSensor.packetIndexMagY = packetSize
                packetSize += 2
                enabledSensors |= Int(SensorBitmapShimmer3.SENSOR_LSM303DLHC_MAG.rawValue)
            case ChannelContentsShimmer3.ZMag.rawValue:
                magSensor.packetIndexMagZ = packetSize
                packetSize += 2
                enabledSensors |= Int(SensorBitmapShimmer3.SENSOR_LSM303DLHC_MAG.rawValue)
            case ChannelContentsShimmer3.XGyro.rawValue:
                gyroSensor.packetIndexGyroX = packetSize
                packetSize += 2
                enabledSensors |= Int(SensorBitmapShimmer3.SENSOR_MPU9150_GYRO.rawValue)
            case ChannelContentsShimmer3.YGyro.rawValue:
                gyroSensor.packetIndexGyroY = packetSize
                packetSize += 2
                enabledSensors |= Int(SensorBitmapShimmer3.SENSOR_MPU9150_GYRO.rawValue)
            case ChannelContentsShimmer3.ZGyro.rawValue:
                gyroSensor.packetIndexGyroZ = packetSize
                packetSize += 2
                enabledSensors |= Int(SensorBitmapShimmer3.SENSOR_MPU9150_GYRO.rawValue)
            case ChannelContentsShimmer3.GsrRaw.rawValue:
                gsrSensor.packetIndex = packetSize
                packetSize += 2
                enabledSensors |= Int(SensorBitmapShimmer3.SENSOR_GSR.rawValue)
            case ChannelContentsShimmer3.Exg1_Status.rawValue:
                packetSize += 1
            case ChannelContentsShimmer3.Exg1_CH1.rawValue:
                packetSize += 3
                enabledSensors |= Int(SensorBitmapShimmer3.SENSOR_EXG1_24BIT.rawValue)
            case ChannelContentsShimmer3.Exg1_CH2.rawValue:
                packetSize += 3
                enabledSensors |= Int(SensorBitmapShimmer3.SENSOR_EXG1_24BIT.rawValue)
            case ChannelContentsShimmer3.Exg2_Status.rawValue:
                packetSize += 1
            case ChannelContentsShimmer3.Exg2_CH1.rawValue:
                packetSize += 3
                enabledSensors |= Int(SensorBitmapShimmer3.SENSOR_EXG2_24BIT.rawValue)
            case ChannelContentsShimmer3.Exg2_CH2.rawValue:
                packetSize += 3
                enabledSensors |= Int(SensorBitmapShimmer3.SENSOR_EXG2_24BIT.rawValue)
            case ChannelContentsShimmer3.Exg1_CH1_16Bit.rawValue:
                packetSize += 2
                enabledSensors |= Int(SensorBitmapShimmer3.SENSOR_EXG1_16BIT.rawValue)
            case ChannelContentsShimmer3.Exg1_CH2_16Bit.rawValue:
                packetSize += 2
                enabledSensors |= Int(SensorBitmapShimmer3.SENSOR_EXG1_16BIT.rawValue)
            case ChannelContentsShimmer3.Exg2_CH1_16Bit.rawValue:
                packetSize += 2
                enabledSensors |= Int(SensorBitmapShimmer3.SENSOR_EXG2_16BIT.rawValue)
            case ChannelContentsShimmer3.Exg2_CH2_16Bit.rawValue:
                packetSize += 2
                enabledSensors |= Int(SensorBitmapShimmer3.SENSOR_EXG2_16BIT.rawValue)
            case ChannelContentsShimmer3.InternalAdc13.rawValue:
                adcA13Sensor.packetIndex = packetSize
                packetSize += 2
                enabledSensors |= Int(SensorBitmapShimmer3.SENSOR_INT_A13.rawValue)
            case ChannelContentsShimmer3.ExternalAdc15.rawValue:
                adcA15Sensor.packetIndex = packetSize
                packetSize += 2
                enabledSensors |= Int(SensorBitmapShimmer3.SENSOR_EXT_A15.rawValue)
            case ChannelContentsShimmer3.InternalAdc12.rawValue:
                adcA12Sensor.packetIndex = packetSize
                packetSize += 2
                enabledSensors |= Int(SensorBitmapShimmer3.SENSOR_INT_A12.rawValue)
            case ChannelContentsShimmer3.InternalAdc1.rawValue:
                adcA1Sensor.packetIndex = packetSize
                packetSize += 2
                enabledSensors |= Int(SensorBitmapShimmer3.SENSOR_INT_A1.rawValue)
            case ChannelContentsShimmer3.ExternalAdc6.rawValue:
                adcA6Sensor.packetIndex = packetSize
                packetSize += 2
                enabledSensors |= Int(SensorBitmapShimmer3.SENSOR_EXT_A6.rawValue)
            case ChannelContentsShimmer3.ExternalAdc7.rawValue:
                adcA7Sensor.packetIndex = packetSize
                packetSize += 2
                enabledSensors |= Int(SensorBitmapShimmer3.SENSOR_EXT_A7.rawValue)
            case ChannelContentsShimmer3.Temperature.rawValue:
                packetSize += 2
                enabledSensors |= Int(SensorBitmapShimmer3.SENSOR_BMP180_PRESSURE.rawValue)
            case ChannelContentsShimmer3.Pressure.rawValue:
                packetSize += 3
                enabledSensors |= Int(SensorBitmapShimmer3.SENSOR_BMP180_PRESSURE.rawValue)
            default:
                packetSize += 2
            }

            
        }
        
        EnabledSensors = enabledSensors
        PacketSize = packetSize + Int(CRCMode.rawValue)
        print(PacketSize)
        //print("Packet Size : \(PacketSize)  CRC Mode and starting byte not included")
    }
    var SamplingRate:Double=0
    
    func interpretInfoMem(infomem:[UInt8]){
        
    }
    
    func interpretInquiryResponseShimmer3(packet: [UInt8]) {
        // Check if this packet is sane and not just random
        if packet.count >= 4 { // Max number of channels currently allowable
            let ADCRawSamplingRateValue = Int(packet[0]) + (Int(packet[1]) << 8 & 0xFF00)
            CurrentSamplingRate = Double(32768) / Double(ADCRawSamplingRateValue)

            let ConfigSetupByte0 = Int64(packet[2]) + (Int64(packet[3]) << 8) + (Int64(packet[4]) << 16) + (Int64(packet[5]) << 24)
            let AccelHRBit = Int((ConfigSetupByte0 >> 0) & 0x01)
            let AccelLPBit = Int((ConfigSetupByte0 >> 1) & 0x01)
            let AccelRange = Int((ConfigSetupByte0 >> 2) & 0x03)
            let GyroRange = Int((ConfigSetupByte0 >> 16) & 0x03)
            let MagGain = Int((ConfigSetupByte0 >> 21) & 0x07)
            let AccelSamplingRate = Int((ConfigSetupByte0 >> 4) & 0xF)
            let Mpu9150SamplingRate = Int((ConfigSetupByte0 >> 8) & 0xFF)
            let magSamplingRate = Int((ConfigSetupByte0 >> 18) & 0x07)
            let PressureResolution = Int((ConfigSetupByte0 >> 28) & 0x03)
            let GSRRange = Int((ConfigSetupByte0 >> 25) & 0x07)
            let InternalExpPower = Int((ConfigSetupByte0 >> 24) & 0x01)
            let Mpu9150AccelRange = Int((ConfigSetupByte0 >> 30) & 0x03)
            
            if magSamplingRate == 4 && ADCRawSamplingRateValue < 3200 {
                // 3200 is the raw ADC value and not in HZ
                let LowPowerMagEnabled = true
            }
            
            if AccelSamplingRate == 2 && ADCRawSamplingRateValue < 3200 {
                let LowPowerAccelEnabled = true
            }
            
            if Mpu9150SamplingRate == 0xFF && ADCRawSamplingRateValue < 3200 {
                let LowPowerGyroEnabled = true
            }
            
            let NumberofChannels = Int(packet[6])
            let BufferSize = Int(packet[7])
            var ListofSensorChannels: [UInt8] = []
            
            for i in 0..<NumberofChannels {
                ListofSensorChannels.append(packet[8 + i])
            }
            
            let signalIdArray = ListofSensorChannels
            interpretDataPacketFormat(nC: NumberofChannels, signalid: signalIdArray)
            //isFilled = true
        }
    }
    
    func interpretInquiryResponseShimmer3R(packet: [UInt8]) {
        // Check if this packet is sane and not just random
        if packet.count >= 4 { // Max number of channels currently allowable
            let ADCRawSamplingRateValue = Int(packet[0]) + (Int(packet[1]) << 8 & 0xFF00)
            CurrentSamplingRate = Double(32768) / Double(ADCRawSamplingRateValue)

            let ConfigSetupByte0 = Int64(packet[2]) + (Int64(packet[3]) << 8) + (Int64(packet[4]) << 16) + (Int64(packet[5]) << 24)
            let AccelHRBit = Int((ConfigSetupByte0 >> 0) & 0x01)
            let AccelLPBit = Int((ConfigSetupByte0 >> 1) & 0x01)
            let AccelRange = Int((ConfigSetupByte0 >> 2) & 0x03)
            let GyroRange = Int((ConfigSetupByte0 >> 16) & 0x03)
            let MagGain = Int((ConfigSetupByte0 >> 21) & 0x07)
            let AccelSamplingRate = Int((ConfigSetupByte0 >> 4) & 0xF)
            let Mpu9150SamplingRate = Int((ConfigSetupByte0 >> 8) & 0xFF)
            let magSamplingRate = Int((ConfigSetupByte0 >> 18) & 0x07)
            let PressureResolution = Int((ConfigSetupByte0 >> 28) & 0x03)
            let GSRRange = Int((ConfigSetupByte0 >> 25) & 0x07)
            let InternalExpPower = Int((ConfigSetupByte0 >> 24) & 0x01)
            let Mpu9150AccelRange = Int((ConfigSetupByte0 >> 30) & 0x03)
            
            if magSamplingRate == 4 && ADCRawSamplingRateValue < 3200 {
                // 3200 is the raw ADC value and not in HZ
                let LowPowerMagEnabled = true
            }
            
            if AccelSamplingRate == 2 && ADCRawSamplingRateValue < 3200 {
                let LowPowerAccelEnabled = true
            }
            
            if Mpu9150SamplingRate == 0xFF && ADCRawSamplingRateValue < 3200 {
                let LowPowerGyroEnabled = true
            }
            
            let NumberofChannels = Int(packet[6+3])
            let BufferSize = Int(packet[7+3])
            var ListofSensorChannels: [UInt8] = []
            
            for i in 0..<NumberofChannels {
                ListofSensorChannels.append(packet[8 + 3 + i])
            }
            
            let signalIdArray = ListofSensorChannels
            interpretDataPacketFormat(nC: NumberofChannels, signalid: signalIdArray)
            //isFilled = true
        }
    }
    
    
    

    
    public func sayHello(){
        print("Hello")
    }
    
    public init(radio:BleByteRadio) {
        super.init()
        self.radio = radio
        self.deviceName = radio.deviceName
        self.radio?.delegate = self
    }
    
    public func sendStartStreamingCommand() async ->Bool?{
        let bytes:[UInt8] = [PacketTypeShimmer.startStreamingCommand.rawValue]
        commandSent = PacketTypeShimmer.startStreamingCommand
        //let data = Data(bytes)
        //enableNotifications(enable: true)
        radio!.writeBytes(bytes:bytes)
        
        let result = await withCheckedContinuation { continuation in
            if self.continuation == nil {
                // 2
                self.continuation = continuation
            }
        }
        if (result!){
            print("StartStreaming!")
            numberOfPackets = 0
            self.changeState(btState:Shimmer3BTState.STREAMING)
        }
        return result
    }


    
    public func sendStopStreamingCommand() {
        let bytes:[UInt8] = [PacketTypeShimmer.stopStreamingCommand.rawValue]
        commandSent = PacketTypeShimmer.stopStreamingCommand
        //let data = Data(bytes)
        //enableNotifications(enable: true)
        print("send stop streaming command")
        radio!.writeBytes(bytes:bytes)
        print("sent stop streaming command")
    }
    
    func readInfoMemCommand(command: Int, address: Int, size: Int) {
        let memLengthToRead: [UInt8] = [UInt8(size)]
        var memAddressToRead = withUnsafeBytes(of: UInt16(address)) { (ptr) -> [UInt8] in
            return ptr.map { $0 }
        }
        memAddressToRead = memAddressToRead.reversed()
      
        var instructionBuffer:[UInt8] = []
        instructionBuffer.append(UInt8(command))
        instructionBuffer.append(contentsOf: memLengthToRead)
        instructionBuffer.append(contentsOf: memAddressToRead)
        
        
        
    }
    
    func sendGetMemoryCommand(cmd:PacketTypeShimmer,val0:UInt8,val1:UInt8,val2:UInt8) async -> [UInt8]?{
        let size = 512
        let INFOMEM_D_ADD = 0x001800
        let INFOMEM_LAST_ADD = 0x0019FF
        //0x80
        let bytes:[UInt8] = [cmd.rawValue,val0,val1,val2]
        //[0x8E 0x80 0x00 0x00]
        //[0x8E 0x80 0x80 0x00]
        //[0x8E 0x80 0x00 0x01]
        commandSent = cmd
        radio!.writeBytes(bytes:bytes)
        let result = await withCheckedContinuation { continuation in
            if self.continuationByteArray == nil {
                // 2
                self.continuationByteArray = continuation
            }
        }
        
        return result
    }
    
    public func sendWriteMemInfo() async -> Bool?{
        return false
    }
    
    private func sendCRCCommand(crcMode:BTCRCMode) async ->Bool?{
        let bytes:[UInt8] = [PacketTypeShimmer.setCRCCommand.rawValue,crcMode.rawValue]
        commandSent = PacketTypeShimmer.setCRCCommand
        radio!.writeBytes(bytes:bytes)
        self.CRCMode = crcMode
        return await withCheckedContinuation { continuation in
            if self.continuation == nil {
                // 2
                self.continuation = continuation
            }
        }
    }
    
    public func sendReadShimmerVersionCommand() async -> Bool?{
        let bytes:[UInt8] = [PacketTypeShimmer.getShimmerVersionCommand.rawValue]
        commandSent = PacketTypeShimmer.getShimmerVersionCommand
        radio!.writeBytes(bytes: bytes)
        return await withCheckedContinuation { continuation in
            if self.continuation == nil {
                // 2
                self.continuation = continuation
            }
        }
    }
    
    public func sendReadExpBoardVersionCommand() async -> Bool?{
        let bytes:[UInt8] = [PacketTypeShimmer.getDaughterCardIDCommand.rawValue,3,0]
        commandSent = PacketTypeShimmer.getDaughterCardIDCommand
        radio!.writeBytes(bytes: bytes)
        return await withCheckedContinuation { continuation in
            if self.continuation == nil {
                // 2
                self.continuation = continuation
            }
        }
    }
    
    public func sendReadFWVersionCommand() async -> Bool?{
        let bytes:[UInt8] = [PacketTypeShimmer.getFWVersionCommand.rawValue]
        commandSent = PacketTypeShimmer.getFWVersionCommand
        radio!.writeBytes(bytes: bytes)
        return await withCheckedContinuation { continuation in
            if self.continuation == nil {
                // 2
                self.continuation = continuation
            }
        }
    }
    
    private func sendInquiryCommand() async -> Bool?{
        
        let bytes:[UInt8] = [PacketTypeShimmer.inquiryCommand.rawValue]
        commandSent = PacketTypeShimmer.inquiryCommand
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
    
    private func sendBMP280PressureCalibCoefficientsCommand() async -> Bool?{
        
        let bytes:[UInt8] = [PacketTypeShimmer.getBmp280CalibrationCoefficientsCommand.rawValue]
        commandSent = PacketTypeShimmer.getBmp280CalibrationCoefficientsCommand
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
    
    private func sendPressureCalibCoefficientsCommand() async -> Bool?{
        return true;
    }
    
    public func sendSetSamplingRateCommand(samplingRate: Double) async -> Bool?{
        var samplingByteValue = (Int)(32768/samplingRate)
        var bytes = [UInt8]()

        bytes.append(PacketTypeShimmer.setSamplingRateCommand.rawValue)
        bytes.append((UInt8)(samplingByteValue & 0xFF))
        bytes.append((UInt8)((samplingByteValue >> 8) & 0xFF))
        
        commandSent = PacketTypeShimmer.setSamplingRateCommand
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
    public func updateInfoMemSamplingRate(infomem: [UInt8],samplingRateFreq: Double) -> [UInt8]{

        var infomemtoupdate = infomem
        let samplingRate = (Int)(round(32768.0/samplingRateFreq))
        var buff = [UInt8]()
        buff.append(UInt8(samplingRate & 0xFF))
        buff.append(UInt8((samplingRate >> 8) & 0xFF))
    
        infomemtoupdate[ConfigByteLayoutShimmer3.idxShimmerSamplingRate] = buff[ConfigByteLayoutShimmer3.idxShimmerSamplingRate]
        infomemtoupdate[ConfigByteLayoutShimmer3.idxShimmerSamplingRate + 1] = buff[ConfigByteLayoutShimmer3.idxShimmerSamplingRate + 1]

        return infomemtoupdate
        
    }
    
    public func writeExgRate(exgArr: [UInt8]){

        let exg1ar1 = exgArr[0]
        let exg2ar1 = exgArr[1]
        sendSetExgRegsCommand()
        sendSetExgRegsCommand(byte: (UInt8)(0))
        sendSetExgRegsCommand(byte: (UInt8)(0))
        sendSetExgRegsCommand(byte: (UInt8)(1))
        sendSetExgRegsCommand(byte: exg1ar1)
        exgSensor.exg1RegisterArray[0] = exg1ar1

        sendSetExgRegsCommand()
        sendSetExgRegsCommand(byte: (UInt8)(1))
        sendSetExgRegsCommand(byte: (UInt8)(0))
        sendSetExgRegsCommand(byte: (UInt8)(1))
        sendSetExgRegsCommand(byte: exg2ar1)
        exgSensor.exg2RegisterArray[0] = exg2ar1

        writeExgConfigurations(valuesChip1: exgSensor.exg1RegisterArray, valuesChip2: exgSensor.exg2RegisterArray)
    }
   
    public func writeExgConfigurations(valuesChip1: [UInt8], valuesChip2: [UInt8]){
        sendSetExgRegsCommand()
        sendSetExgRegsCommand(byte: (UInt8)(0))
        sendSetExgRegsCommand(byte: (UInt8)(0))
        sendSetExgRegsCommand(byte: (UInt8)(10))
        for i in 0..<10 {
            sendSetExgRegsCommand(byte: valuesChip1[i])
            exgSensor.exg1RegisterArray[i] = valuesChip1[i]
        }
        sendSetExgRegsCommand()
        sendSetExgRegsCommand(byte: (UInt8)(1))
        sendSetExgRegsCommand(byte: (UInt8)(0))
        sendSetExgRegsCommand(byte: (UInt8)(10))
        for i in 0..<10 {
            sendSetExgRegsCommand(byte: valuesChip1[i])
            exgSensor.exg1RegisterArray[i] = valuesChip1[i]
        }
    }
    public func sendSetExgRegsCommand(){
        let bytes:[UInt8] = [PacketTypeShimmer.setExgRegsCommand.rawValue]
        commandSent = PacketTypeShimmer.setExgRegsCommand
        //let data = Data(bytes)
        //enableNotifications(enable: true)
        radio!.writeBytes(bytes:bytes)
    }
    
    public func sendSetExgRegsCommand(byte: UInt8){
        let bytes:[UInt8] = [byte]
        commandSent = PacketTypeShimmer.setExgRegsCommand
        //let data = Data(bytes)
        //enableNotifications(enable: true)
        radio!.writeBytes(bytes:bytes)
    }
    
    func shimmerUartCrcCalc(_ msg: [UInt8], _ len: Int) -> [UInt8] {
        let CRC_INIT: Int = 0xB0CA
        var crcCalc = shimmerUartCrcByte(CRC_INIT, msg[0])
        var i = 1

        while i < len {
            crcCalc = shimmerUartCrcByte(crcCalc, msg[i])
            i += 1
        }

        if len % 2 > 0 {
            crcCalc = shimmerUartCrcByte(crcCalc, 0x00)
        }

        let crcCalcArray: [UInt8] = [
            UInt8(crcCalc & 0xFF),    // CRC LSB
            UInt8((crcCalc >> 8) & 0xFF)   // CRC MSB
        ]

        return crcCalcArray
    }
    
    func shimmerUartCrcByte(_ crc: Int, _ b: UInt8) -> Int {
        var crcValue = crc & 0xFFFF
        crcValue = (crcValue >> 8) | (crcValue << 8)
        crcValue ^= Int(b) & 0xFF
        crcValue ^= (crcValue & 0xFF) >> 4
        crcValue ^= crcValue << 12
        crcValue ^= (crcValue & 0xFF) << 5
        crcValue &= 0xFFFF
        return crcValue
    }

    func checkCrc(_ bufferTemp: [UInt8], _ length: Int) -> Bool {
        let crcCalc = shimmerUartCrcCalc(bufferTemp, length)

        if CRCMode == BTCRCMode.ONE_BYTE || CRCMode == BTCRCMode.TWO_BYTE {
            if bufferTemp[bufferTemp.count-Int(CRCMode.rawValue)] != crcCalc[0] {
                return false
            }
        }
    
        if CRCMode == BTCRCMode.TWO_BYTE {
            if bufferTemp[bufferTemp.count - 1] != crcCalc[1] {
                return false
            }
        }
        return true
    }

    
    private func getUnsignedRightShift(_ value: Int, _ s: Int) -> Int {
        return Int(UInt(value) >> s)
    }
    
    let queue = DispatchQueue(label: "thread-safe-obj", attributes: .concurrent)
    
    private func processData(_ data: Data) {
        var received:[UInt8] = []
        received = Array(data)
        queue.async(flags: .barrier) {
            print("Data added to buffer")
            self.receivedBytes.append(contentsOf: received)
        }

        /*
        if (BTState==Shimmer3BTState.STREAMING){
            if(received[0]==PacketTypeShimmer.dataPacket.rawValue){
                let result = splitArrayIntoChunks(data:received,packetSize:PacketSize+1) //+1 for the 0 data packet type at the start of each packet
                print(result)
            }
        } else {
            print(received)
            if(received[0]==PacketTypeShimmer.ackCommand.rawValue){
                print("ACK Received")
                print("CRC Calculated: \(shimmerUartCrcCalc(received,(received.count-Int(CRCMode.rawValue))))")
                var crcresult = checkCrc(received,(received.count-Int(CRCMode.rawValue)))
                print("CRC Check:  \(crcresult) ")
                if (crcresult){
                    self.continuation?.resume(returning: true)
                    self.continuation = nil
                } else{
                    self.continuation?.resume(returning: false)
                    self.continuation = nil
                }
                if ((received.count-Int(CRCMode.rawValue))>=2){
                    if(received[1]==PacketTypeShimmer.inquiryResponse.rawValue){
                        received.removeFirst() //remove ack
                        received.removeFirst() //remove response type
                        if(CRCMode == BTCRCMode.ONE_BYTE){
                            received.removeLast()
                        } else if(CRCMode == BTCRCMode.TWO_BYTE){
                            received.removeLast()
                            received.removeLast()
                        }
                        interpretInquiryResponseShimmer3(packet: received)
                    }
                }
            }
        }
         */
        
    }
    
    func splitArrayIntoChunks(data: [UInt8], packetSize: Int) -> [[UInt8]] {
        var chunks: [[UInt8]] = []
        var currentChunk: [UInt8] = []
        
        for byte in data {
            currentChunk.append(byte)
            
            if currentChunk.count == packetSize {
                chunks.append(currentChunk)
                currentChunk = []
            }
        }
        
        // Add the remaining bytes as the last chunk (if any)
        if !currentChunk.isEmpty {
            chunks.append(currentChunk)
        }
        
        return chunks
    }
    
    public func isShimmer3withUpdatedSensors()-> Bool{
        if(REV_HW_MAJOR==HardwareType.Shimmer3.rawValue) && (
            (EXPANSION_BOARD_ID == ExpansionBoardDetectShimmer3.EXP_BRD_GSR_UNIFIED.rawValue && EXPANSION_BOARD_REV >= 3)
            || (EXPANSION_BOARD_ID == ExpansionBoardDetectShimmer3.EXP_BRD_EXG_UNIFIED.rawValue && EXPANSION_BOARD_REV >= 3)
            || (EXPANSION_BOARD_ID == ExpansionBoardDetectShimmer3.EXP_BRD_BR_AMP_UNIFIED.rawValue && EXPANSION_BOARD_REV >= 2)
            || (EXPANSION_BOARD_ID == ExpansionBoardDetectShimmer3.SHIMMER3.rawValue && EXPANSION_BOARD_REV >= 6)
            || (EXPANSION_BOARD_ID == ExpansionBoardDetectShimmer3.EXPANSION_PROTO3_DELUXE.rawValue && EXPANSION_BOARD_REV >= 3))
        {
            return true
        }else{
            return false
        }
    }
    
    public func isShimmer3Sensor() -> Bool{
        if(REV_HW_MAJOR==HardwareType.Shimmer3.rawValue){
            return true
        }else{
            return false
        }

    }
    
    
    class ShimmerConfiguration {
        class SignalNames {
            static let TIMESTAMP = "Timestamp"
            static let SYSTEM_TIMESTAMP = "System Timestamp"
            static let SYSTEM_TIMESTAMP_PLOT = "System Timestamp Plot"
        }
        
        class SignalFormats {
            static let CAL = "CAL"
            static let RAW = "RAW"
        }
        
        class SignalUnits {
            static let MilliSeconds = "mSecs"
            static let NoUnits = "no units"
            static let MeterPerSecondSquared = "m/(sec^2)"
            static let MeterPerSecondSquared_DefaultCal = "m/(sec^2)*"
            static let DegreePerSecond = "deg/sec"
            static let DegreePerSecond_DefaultCal = "deg/sec*"
            static let MilliVolts = "mVolts"
            static let MilliVolts_DefaultCal = "mVolts*"
            static let KiloPascal = "kPa"
            static let Celcius = "Celcius*"
            static let Local = "local"
            static let Local_DefaultCal = "local*"
            static let KiloOhms = "kOhms"
            static let MicroSiemens = "uSiemens"
            static let NanoAmpere = "nA"
        }
    }
    
    public class Shimmer3Configuration {
        static let EXG_ECG_CONFIGURATION_CHIP1: [UInt8] = [0x00, 0xA0, 0x10, 0x40, 0x40, 0x2D, 0x00, 0x00, 0x02, 0x03]
        static let EXG_ECG_CONFIGURATION_CHIP2: [UInt8] = [0x00, 0xA0, 0x10, 0x40, 0x47, 0x00, 0x00, 0x00, 0x02, 0x01]
        static let EXG_EMG_CONFIGURATION_CHIP1: [UInt8] = [0x00, 0xA0, 0x10, 0x69, 0x60, 0x20, 0x00, 0x00, 0x02, 0x03]
        static let EXG_EMG_CONFIGURATION_CHIP2: [UInt8] = [0x00, 0xA0, 0x10, 0xE1, 0xE1, 0x00, 0x00, 0x00, 0x02, 0x01]
        static let EXG_TEST_SIGNAL_CONFIGURATION_CHIP1: [UInt8] = [0x00, 0xA3, 0x10, 0x45, 0x45, 0x00, 0x00, 0x00, 0x02, 0x01]
        static let EXG_TEST_SIGNAL_CONFIGURATION_CHIP2: [UInt8] = [0x00, 0xA3, 0x10, 0x45, 0x45, 0x00, 0x00, 0x00, 0x02, 0x01]
        
        public class SignalNames {
            static let V_SENSE_BATT = "VSenseBatt"

            static let MAGNETOMETER_X = "Magnetometer X"
            static let MAGNETOMETER_Y = "Magnetometer Y"
            static let MAGNETOMETER_Z = "Magnetometer Z"
            static let EXTERNAL_ADC_A7 = "External ADC A7"
            static let EXTERNAL_ADC_A6 = "External ADC A6"
            static let EXTERNAL_ADC_A15 = "External ADC A15"
            static let INTERNAL_ADC_A1 = "Internal ADC A1"
            static let INTERNAL_ADC_A12 = "Internal ADC A12"
            static let INTERNAL_ADC_A14 = "Internal ADC A14"
            static let PRESSURE = "Pressure"
            static let TEMPERATURE = "Temperature"
            static let GSR_CONDUCTANCE = "GSR Conductance"
            static let EXG1_STATUS = "EXG1 Status"
            static let EXG2_STATUS = "EXG2 Status"
            static let ECG_LL_RA = "ECG LL-RA"
            static let ECG_LA_RA = "ECG LA-RA"
            static let ECG_VX_RL = "ECG Vx-RL"
            static let EMG_CH1 = "EMG CH1"
            static let EMG_CH2 = "EMG CH2"
            static let EXG1_CH1 = "EXG1 CH1"
            static let EXG1_CH2 = "EXG1 CH2"
            static let EXG2_CH1 = "EXG2 CH1"
            static let EXG2_CH2 = "EXG2 CH2"
            static let EXG1_CH1_16BIT = "EXG1 CH1 16Bit"
            static let EXG1_CH2_16BIT = "EXG1 CH2 16Bit"
            static let EXG2_CH1_16BIT = "EXG2 CH1 16Bit"
            static let EXG2_CH2_16BIT = "EXG2 CH2 16Bit"
            static let EXG1_CH1_24BIT = "EXG1 CH1 24Bit"
            static let EXG1_CH2_24BIT = "EXG1 CH2 24Bit"
            static let EXG2_CH1_24BIT = "EXG2 CH1 24Bit"
            static let EXG2_CH2_24BIT = "EXG2 CH2 24Bit"
            static let BRIGE_AMPLIFIER_HIGH = "Bridge Amplifier High"
            static let BRIGE_AMPLIFIER_LOW = "Bridge Amplifier Low"
            static let QUATERNION_0 = "Quaternion 0"
            static let QUATERNION_1 = "Quaternion 1"
            static let QUATERNION_2 = "Quaternion 2"
            static let QUATERNION_3 = "Quaternion 3"
            static let AXIS_ANGLE_A = "Axis Angle A"
            static let AXIS_ANGLE_X = "Axis Angle X"
            static let AXIS_ANGLE_Y = "Axis Angle Y"
            static let AXIS_ANGLE_Z = "Axis Angle Z"
        }

        
    }
    
    enum SensorBitmapShimmer3: UInt32 {
        case SENSOR_A_ACCEL = 0x80
        case SENSOR_MPU9150_GYRO = 0x040
        case SENSOR_LSM303DLHC_MAG = 0x20
        case SENSOR_GSR = 0x04
        case SENSOR_EXT_A7 = 0x02
        case SENSOR_EXT_A6 = 0x01
        case SENSOR_VBATT = 0x2000
        case SENSOR_D_ACCEL = 0x1000
        case SENSOR_EXT_A15 = 0x0800
        case SENSOR_INT_A1 = 0x0400
        case SENSOR_INT_A12 = 0x0200
        case SENSOR_INT_A13 = 0x0100
        case SENSOR_INT_A14 = 0x800000
        case SENSOR_BMP180_PRESSURE = 0x40000
        case SENSOR_EXG1_24BIT = 0x10
        case SENSOR_EXG2_24BIT = 0x08
        case SENSOR_EXG1_16BIT = 0x100000
        case SENSOR_EXG2_16BIT = 0x080000
        case SENSOR_BRIDGE_AMP = 0x8000
    }
    
    enum ChannelContentsShimmer3: UInt8 {
        case XLNAccel = 0x00
        case YLNAccel = 0x01
        case ZLNAccel = 0x02
        case VBatt = 0x03
        case XWRAccel = 0x04
        case YWRAccel = 0x05
        case ZWRAccel = 0x06
        case XMag = 0x07
        case YMag = 0x08
        case ZMag = 0x09
        case XGyro = 0x0A
        case YGyro = 0x0B
        case ZGyro = 0x0C
        case ExternalAdc7 = 0x0D
        case ExternalAdc6 = 0x0E
        case ExternalAdc15 = 0x0F
        case InternalAdc1 = 0x10
        case InternalAdc12 = 0x11
        case InternalAdc13 = 0x12
        case InternalAdc14 = 0x13
        // Unsupported cases
        case AlternativeXAccel = 0x14
        case AlternativeYAccel = 0x15
        case AlternativeZAccel = 0x16
        case AlternativeXMag = 0x17
        case AlternativeYMag = 0x18
        case AlternativeZMag = 0x19
        // Unsupported cases
        case Temperature = 0x1A
        case Pressure = 0x1B
        case Exg1_Status = 0x1D
        case Exg1_CH1 = 0x1E
        case Exg1_CH2 = 0x1F
        case Exg2_Status = 0x20
        case Exg2_CH1 = 0x21
        case Exg2_CH2 = 0x22
        case Exg1_CH1_16Bit = 0x23
        case Exg1_CH2_16Bit = 0x24
        case Exg2_CH1_16Bit = 0x25
        case Exg2_CH2_16Bit = 0x26
        case STRAIN_HIGH = 0x27
        case STRAIN_LOW = 0x28
        case GsrRaw = 0x1C
    }

    
    enum PacketTypeShimmer: UInt8 {
        case dataPacket = 0x00
        case inquiryCommand = 0x01
        case inquiryResponse = 0x02
        case getSamplingRateCommand = 0x03
        case samplingRateResponse = 0x04
        case setSamplingRateCommand = 0x05
        case toggleLEDCommand = 0x06
        case startStreamingCommand = 0x07
        case setSensorsCommand = 0x08
        case setAccelRangeCommand = 0x09
        case accelRangeResponse = 0x0A
        case getAccelRangeCommand = 0x0B
        case set5VRegulatorCommand = 0x0C
        case setPowerMuxCommand = 0x0D
        case setConfigSetupByte0Command = 0x0E
        case configSetupByte0Response = 0x0F
        case getConfigSetupByte0Command = 0x10
        case setAccelCalibrationCommand = 0x11
        case accelCalibrationResponse = 0x12
        case getAccelCalibrationCommand = 0x13
        case setGyroCalibrationCommand = 0x14
        case gyroCalibrationResponse = 0x15
        case getGyroCalibrationCommand = 0x16
        case setMagCalibrationCommand = 0x17
        case magCalibrationResponse = 0x18
        case getMagCalibrationCommand = 0x19
        case stopStreamingCommand = 0x20
        case setGSRRRangeCommand = 0x21
        case gsrRangeResponse = 0x22
        case getGSRRangeCommand = 0x23
        case getShimmerVersionCommand = 0x3F
        case getShimmerVersionResponse = 0x25
        case setEMGCalibrationCommand = 0x26
        case emgCalibrationResponse = 0x27
        case getEMGCalibrationCommand = 0x28
        case setECGCalibrationCommand = 0x29
        case ecgCalibrationResponse = 0x2A
        case getECGCalibrationCommand = 0x2B
        case getAllCalibrationCommand = 0x2C
        case allCalibrationResponse = 0x2D
        case getFWVersionCommand = 0x2E
        case fwVersionResponse = 0x2F
        case setBlinkLED = 0x30
        case blinkLEDResponse = 0x31
        case getBlinkLED = 0x32
        case setGyroTempVrefCommand = 0x33
        case setBufferSizeCommand = 0x34
        case bufferSizeResponse = 0x35
        case getBufferSizeCommand = 0x36
        case setMagGainCommand = 0x37
        case magGainResponse = 0x38
        case getMagGainCommand = 0x39
        case setMagSamplingRateCommand = 0x3A
        case magSamplingRateResponse = 0x3B
        case getMagSamplingRateCommand = 0x3C
        case daughterCardIDResponse = 0x65
        case getDaughterCardIDCommand = 0x66
        case setInfoMem = 0x8c
        case getInfoMemResponse = 0x8d
        case getInfoMem = 0x8e
        case setCRCCommand = 0x8b
        case calibDumpResponse = 0x99
        case getCalibDumpCommand = 0x9a
        case ackCommand = 0xFF
        case getBmp180CalibrationCoefficientsCommand = 0x59
        case bmp180CalibrationCoefficientsResponse = 0x58
        case getBmp280CalibrationCoefficientsCommand = 0xA0
        case bmp280CalibrationCoefficientsResponse = 0x9F
        case getpressureCalibrationCoefficientsCommand = 0xA7
        case pressureCalibrationCoefficientsResponse = 0xA6
        case setExgRegsCommand = 0x61
        case exgRegsResponse = 0x62
        case getExgRegsCommand = 0x63
    }
    public enum BTCRCMode: UInt8 {
        case OFF = 0
        case ONE_BYTE = 1
        case TWO_BYTE = 2
    }
    
    public enum Shimmer3BTState: UInt8 {
        case DISCONNECTED = 0x0
        case CONNECTING = 0x1
        case CONNECTED = 0x2
        case STREAMING = 0x3
        case CONFIGURING = 0x4
        
        public var stringValue: String {
                switch self {
                case .DISCONNECTED:
                    return "Disconnected"
                case .CONNECTING:
                    return "Connecting"
                case .CONNECTED:
                    return "Connected"
                case .STREAMING:
                    return "Streaming"
                case .CONFIGURING:
                    return "Configuring"
                }
            }
        
    }
    
    public enum ExpansionBoardDetectShimmer3: Int
    {
        case EXPANSION_BRIDGE_AMPLIFIER_PLUS = 8
        case EXPANSION_GSR_PLUS = 14
        case EXPANSION_PROTO3_MINI = 36
        case EXPANSION_EXG = 37
        case EXPANSION_PROTO3_DELUXE = 38
        case SHIMMER_3_EXG_EXTENDED = 59
        case SHIMMER3 = 31
        case EXP_BRD_HIGH_G_ACCEL = 44
        case EXP_BRD_GPS = 46
        case EXP_BRD_EXG_UNIFIED = 47
        case EXP_BRD_GSR_UNIFIED = 48
        case EXP_BRD_BR_AMP_UNIFIED = 49
    }
}
extension Shimmer3Protocol : ByteCommunicationDelegate {
    public func byteCommunicationConnected() {
        
    }
    
    public func byteCommunicationDisconnected(connectionloss: Bool) {
        self.changeState(btState:Shimmer3BTState.DISCONNECTED)
        stopProcessing()
        print("Current State: \(BTState)")
    }
    
    public func byteCommunicationDataReceived(data: Data?) {
        self.processData(data!)
    }
    
}

