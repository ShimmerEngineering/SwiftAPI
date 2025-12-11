//
//  HighGAccel.swift
//  ShimmerBluetooth
//
//  Created by Shimmer Engineering on 04/06/2025.
//

import Foundation

public class HighGAccelSensor : IMUSensor , SensorProcessing{
    
    
    public var packetIndexHighGAccelX:Int = -1
    public var packetIndexHighGAccelY:Int = -1
    public var packetIndexHighGAccelZ:Int = -1
    public static let HIGHG_ACCEL_X = "HighG Accel X"
    public static let HIGHG_ACCEL_Y = "HighG Accel Y"
    public static let HIGHG_ACCEL_Z = "HighG Accel Z"
    var highGAccelRange = 0
    var CALIBRATION_ID = 40
    var AlignmentMatrix : [[Double]] = [[]]
    var SensitivityMatrix : [[Double]] = [[]]
    var OffsetVector : [Double] = []
    
    public func processData(sensorPacket: [UInt8], objectCluster: ObjectCluster) -> ObjectCluster {
        let x = Array(sensorPacket[packetIndexHighGAccelX..<packetIndexHighGAccelX+2])
        let y = Array(sensorPacket[packetIndexHighGAccelY..<packetIndexHighGAccelY+2])
        let z = Array(sensorPacket[packetIndexHighGAccelZ..<packetIndexHighGAccelZ+2])
        let rawDataX = Double(ShimmerUtilities.parseSensorData(sensorData: x, dataType: SensorDataType.i12MSB)!)
        let rawDataY = Double(ShimmerUtilities.parseSensorData(sensorData: y, dataType: SensorDataType.i12MSB)!)
        let rawDataZ = Double(ShimmerUtilities.parseSensorData(sensorData: z, dataType: SensorDataType.i12MSB)!)
        if (calibrationEnabled){
            let data:[Double] = [rawDataX,rawDataY,rawDataZ]

            let(calData)=IMUSensor.calibrateInertialSensorData(data,AlignmentMatrix,SensitivityMatrix,OffsetVector)
            objectCluster.addData(sensorName: HighGAccelSensor.HIGHG_ACCEL_X, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.meterPerSecondSquared.rawValue, value: calData![0])
            objectCluster.addData(sensorName: HighGAccelSensor.HIGHG_ACCEL_Y, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.meterPerSecondSquared.rawValue, value: calData![1])
            objectCluster.addData(sensorName: HighGAccelSensor.HIGHG_ACCEL_Z, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.meterPerSecondSquared.rawValue, value: calData![2])
            print("HG X : \(calData![0]) ,  HG Y : \(calData![1]),  HG Z : \(calData![2])")
        }
        print("HGR X : \(rawDataX) ,  HGR Y : \(rawDataY),  HGR Z : \(rawDataZ)")
        objectCluster.addData(sensorName: HighGAccelSensor.HIGHG_ACCEL_X, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.meterPerSecondSquared.rawValue, value: rawDataX)
        objectCluster.addData(sensorName: HighGAccelSensor.HIGHG_ACCEL_Y, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.meterPerSecondSquared.rawValue, value: rawDataY)
        objectCluster.addData(sensorName: HighGAccelSensor.HIGHG_ACCEL_Z, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.meterPerSecondSquared.rawValue, value: rawDataZ)
        
        return objectCluster
    }
    
    public override func parseSensorCalibrationDump(bytes: [UInt8]){
        var sensorID = Int(bytes[0]) + (Int(bytes[1])<<8)
        if bytes[0] == CALIBRATION_ID {
            var range = bytes[2]
            var calbytes = bytes
            calbytes.removeFirst(12)
            (AlignmentMatrix,SensitivityMatrix,OffsetVector) = parseIMUCalibrationParameters(bytes: calbytes)
        }
    }
    
    public func setInfoMem(infomem: [UInt8]) {
        
        var enabled = Int(infomem[ConfigByteLayoutShimmer3.idxSensors2]>>6) & 1
        
        if (enabled == 1){
            sensorEnabled = true
        } else {
            sensorEnabled = false
        }
    }
    
    
}
