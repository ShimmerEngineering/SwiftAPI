//
//  MagSensor.swift
//  ShimmerBluetooth
//
//  Created by Shimmer Engineering on 21/11/2023.
//

import Foundation
public class MagSensor : IMUSensor , SensorProcessing{
    
    public var packetIndexMagX:Int = -1
    public var packetIndexMagY:Int = -1
    public var packetIndexMagZ:Int = -1
    public static let MAGNETOMETER_X = "Magnetometer X"
    public static let MAGNETOMETER_Y = "Magnetometer Y"
    public static let MAGNETOMETER_Z = "Magnetometer Z"
    var magRange = 0
    let CALIBRATION_ID = 32
    var AlignmentMatrix : [[Double]] = [[]]
    var SensitivityMatrix : [[Double]] = [[]]
    var OffsetVector : [Double] = []
    
    public func processData(sensorPacket: [UInt8], objectCluster: ObjectCluster) -> ObjectCluster {
        let x = Array(sensorPacket[packetIndexMagX..<packetIndexMagX+2])
        let y = Array(sensorPacket[packetIndexMagY..<packetIndexMagY+2])
        let z = Array(sensorPacket[packetIndexMagZ..<packetIndexMagZ+2])
        let rawDataX = Double(ShimmerUtilities.parseSensorData(sensorData: x, dataType: SensorDataType.i16)!)
        let rawDataY = Double(ShimmerUtilities.parseSensorData(sensorData: y, dataType: SensorDataType.i16)!)
        let rawDataZ = Double(ShimmerUtilities.parseSensorData(sensorData: z, dataType: SensorDataType.i16)!)
        if (calibrationEnabled){
            let data:[Double] = [rawDataX,rawDataY,rawDataZ]

            let(calData)=IMUSensor.calibrateInertialSensorData(data,AlignmentMatrix,SensitivityMatrix,OffsetVector)
            objectCluster.addData(sensorName: MagSensor.MAGNETOMETER_X, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.localflux.rawValue, value: calData![0])
            objectCluster.addData(sensorName: MagSensor.MAGNETOMETER_Y, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.localflux.rawValue, value: calData![1])
            objectCluster.addData(sensorName: MagSensor.MAGNETOMETER_Z, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.localflux.rawValue, value: calData![2])
            print("M X : \(calData![0]) ,  M Y : \(calData![1]),  M Z : \(calData![2])")
        }
        print("MR X : \(rawDataX) ,  MR Y : \(rawDataY),  MR Z : \(rawDataZ)")
        objectCluster.addData(sensorName: MagSensor.MAGNETOMETER_X, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.localflux.rawValue, value: rawDataX)
        objectCluster.addData(sensorName: MagSensor.MAGNETOMETER_Y, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.localflux.rawValue, value: rawDataY)
        objectCluster.addData(sensorName: MagSensor.MAGNETOMETER_Z, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.localflux.rawValue, value: rawDataZ)
        
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
        
        var enabled = Int(infomem[ConfigByteLayoutShimmer3.idxSensors0]>>5) & 1
        if (enabled == 1){
            sensorEnabled = true
        } else {
            sensorEnabled = false
        }
        
        magRange = Int((infomem[8]>>5) & 7)
        
    }
    
    public func setLowPowerMag(enable: Bool, isShimmer3withUpdatedSensors: Bool, isShimmer3Sensor: Bool, samplingRate: Double, infomem: [UInt8])-> [UInt8]{
        let LowPowerMagEnabled = enable
        var infomemtoupdate = infomem
        if(isShimmer3Sensor){
            if(!LowPowerMagEnabled){
                if(isShimmer3withUpdatedSensors){
                    if(samplingRate >= 100){
                        infomemtoupdate = updateInfoMemMagRate(infomem: infomem, magRate:3)
                    }else if(samplingRate >= 50){
                        infomemtoupdate = updateInfoMemMagRate(infomem: infomem, magRate:2)
                    }else if(samplingRate >= 20){
                        infomemtoupdate = updateInfoMemMagRate(infomem: infomem, magRate:1)
                    }else if(samplingRate >= 10){
                        infomemtoupdate = updateInfoMemMagRate(infomem: infomem, magRate:0)
                    }else{
                        infomemtoupdate = updateInfoMemMagRate(infomem: infomem, magRate:0)
                    }
                }else{
                    if(samplingRate >= 50){
                        infomemtoupdate = updateInfoMemMagRate(infomem: infomem, magRate:6)
                    }else if(samplingRate >= 20){
                        infomemtoupdate = updateInfoMemMagRate(infomem: infomem, magRate:5)
                    }else if(samplingRate >= 10){
                        infomemtoupdate = updateInfoMemMagRate(infomem: infomem, magRate:4)
                    }else{
                        infomemtoupdate = updateInfoMemMagRate(infomem: infomem, magRate:3)
                    }
                }
            }else //low power mag for shimmer3 enabled
            {
                if(isShimmer3withUpdatedSensors){
                    infomemtoupdate = updateInfoMemMagRate(infomem: infomem, magRate:0)
                }else{
                    infomemtoupdate = updateInfoMemMagRate(infomem: infomem, magRate:4)
                }
            }
        }else //Shimmer2
        {
            if(!LowPowerMagEnabled){
                if(samplingRate <= 1){
                    infomemtoupdate = updateInfoMemMagRate(infomem: infomem, magRate:1)
                }else if(samplingRate <= 15){
                    infomemtoupdate = updateInfoMemMagRate(infomem: infomem, magRate:4)
                }else if(samplingRate <= 30){
                    infomemtoupdate = updateInfoMemMagRate(infomem: infomem, magRate:5)
                }else if(samplingRate <= 75){
                    infomemtoupdate = updateInfoMemMagRate(infomem: infomem, magRate:6)
                }else{
                    infomemtoupdate = updateInfoMemMagRate(infomem: infomem, magRate:7)
                }
                
            }else
            {
                if(samplingRate >= 10){
                    infomemtoupdate = updateInfoMemMagRate(infomem: infomem, magRate:4)
                }else{
                    infomemtoupdate = updateInfoMemMagRate(infomem: infomem, magRate:1)
                }
            }
        }
       
        return infomemtoupdate
    }
    
    public func updateInfoMemMagRate(infomem: [UInt8],magRate: UInt8) -> [UInt8]{
        var infomemtoupdate = infomem

        print("oriinfomem : \(infomemtoupdate)")

        let orivalue = infomemtoupdate[ConfigByteLayoutShimmer3.idxConfigSetupByte2]
        let value = infomemtoupdate[ConfigByteLayoutShimmer3.idxConfigSetupByte2] & ~UInt8(ConfigByteLayoutShimmer3.maskLSM303DLHCMagSamplingRate<<ConfigByteLayoutShimmer3.bitShiftLSM303DLHCMagSamplingRate)
        let range = UInt8(magRate<<ConfigByteLayoutShimmer3.bitShiftLSM303DLHCMagSamplingRate)
        
        print("orivalue range : \(orivalue)")
        print("value : \(value)")
        print("range : \(range)")

        infomemtoupdate[ConfigByteLayoutShimmer3.idxConfigSetupByte2] = value | range
        
        return infomemtoupdate
    }
    
    
}
