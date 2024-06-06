//
//  LNAccelSensor.swift
//  ShimmerBluetooth
//
//  Created by Shimmer Engineering on 17/11/2023.
//

import Foundation

public class LNAccelSensor : IMUSensor , SensorProcessing{
    public static let LOW_NOISE_ACCELEROMETER_X = "Low Noise Accelerometer X"
    public static let LOW_NOISE_ACCELEROMETER_Y = "Low Noise Accelerometer Y"
    public static let LOW_NOISE_ACCELEROMETER_Z = "Low Noise Accelerometer Z"
    public var packetIndexAccelX:Int = -1
    public var packetIndexAccelY:Int = -1
    public var packetIndexAccelZ:Int = -1
    var AlignmentMatrix:[[Double]] = [[]]
    var SensitivityMatrix:[[Double]] = [[]]
    var OffsetVector:[Double]=[]
    let CALIBRATION_ID = 2
    
    public func processData(sensorPacket: [UInt8], objectCluster: ObjectCluster) -> ObjectCluster {
        let x = Array(sensorPacket[packetIndexAccelX..<packetIndexAccelX+2])
        let y = Array(sensorPacket[packetIndexAccelY..<packetIndexAccelY+2])
        let z = Array(sensorPacket[packetIndexAccelZ..<packetIndexAccelZ+2])
        let rawDataX = Double(ShimmerUtilities.parseSensorData(sensorData: x, dataType: SensorDataType.u12)!)
        let rawDataY = Double(ShimmerUtilities.parseSensorData(sensorData: y, dataType: SensorDataType.u12)!)
        let rawDataZ = Double(ShimmerUtilities.parseSensorData(sensorData: z, dataType: SensorDataType.u12)!)
        
        if (calibrationEnabled){
            let data:[Double] = [rawDataX,rawDataY,rawDataZ]
            let(calData)=LNAccelSensor.calibrateInertialSensorData(data,AlignmentMatrix,SensitivityMatrix,OffsetVector)
            objectCluster.addData(sensorName: LNAccelSensor.LOW_NOISE_ACCELEROMETER_X, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.meterPerSecondSquared.rawValue, value: calData![0])
            objectCluster.addData(sensorName: LNAccelSensor.LOW_NOISE_ACCELEROMETER_Y, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.meterPerSecondSquared.rawValue, value: calData![1])
            objectCluster.addData(sensorName: LNAccelSensor.LOW_NOISE_ACCELEROMETER_Z, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.meterPerSecondSquared.rawValue, value: calData![2])
            print("LN X : \(calData![0]) ,  LN Y : \(calData![1]),  LN Z : \(calData![2])")
        }
        
        objectCluster.addData(sensorName: LNAccelSensor.LOW_NOISE_ACCELEROMETER_X, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: rawDataX)
        objectCluster.addData(sensorName: LNAccelSensor.LOW_NOISE_ACCELEROMETER_Y, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: rawDataY)
        objectCluster.addData(sensorName: LNAccelSensor.LOW_NOISE_ACCELEROMETER_Z, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: rawDataZ)
        //print(calData)
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
        var enabled = Int(infomem[ConfigByteLayoutShimmer3.idxSensors0]>>7) & 1
        if (enabled == 1){
            sensorEnabled = true
        } else {
            sensorEnabled = false
        }
    }
    
    
}
