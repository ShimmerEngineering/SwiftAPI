//
//  TimeSensor.swift
//  ShimmerBluetooth
//
//  Created by Shimmer Engineering on 20/11/2023.
//

import Foundation

public class TimeSensor : Sensor , SensorProcessing{
    public var packetIndexTimeStamp:Int = -1
    public static let TimeStamp = "Time Stamp"
    
    public func processData(sensorPacket: [UInt8], objectCluster: ObjectCluster) -> ObjectCluster {
        let desiredRange = Array(sensorPacket[packetIndexTimeStamp..<packetIndexTimeStamp+3])
        let rawData = ShimmerUtilities.parseSensorData(sensorData: desiredRange, dataType: SensorDataType.u24)
        if (calibrationEnabled){
            var calData = calibrateTimeStamp(timeStamp: Double(rawData!))
            objectCluster.addData(sensorName: TimeSensor.TimeStamp, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.milliSeconds.rawValue, value: calData)
            print("TimeStamp (mS) :  \(calData)")
        }
        objectCluster.addData(sensorName: TimeSensor.TimeStamp, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: Double(rawData!))
        return objectCluster
    }
    
    var LastReceivedTimeStamp:Double = 0
    var TimeStampPacketRawMaxValue:Double = 16777216;
    var CurrentTimeStampCycle:Double = 0
    func calibrateTimeStamp(timeStamp: Double) -> Double {
        if (LastReceivedTimeStamp > (timeStamp + (TimeStampPacketRawMaxValue * CurrentTimeStampCycle)))
        {
            CurrentTimeStampCycle = CurrentTimeStampCycle + 1;
        }
        LastReceivedTimeStamp = (timeStamp + (TimeStampPacketRawMaxValue * CurrentTimeStampCycle));

        let clockConstant:Double = 32768;
        let calibratedTimeStamp = LastReceivedTimeStamp / clockConstant * 1000;   // to convert into mS
        return calibratedTimeStamp
    }
    
    public func setInfoMem(infomem: [UInt8]) {
        
    }
    
    
}
