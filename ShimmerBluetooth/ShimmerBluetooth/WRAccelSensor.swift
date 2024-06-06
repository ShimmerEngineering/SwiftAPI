//
//  WRAccelSensor.swift
//  ShimmerBluetooth
//
//  Created by Shimmer Engineering on 17/11/2023.
//

import Foundation

public class WRAccelSensor : IMUSensor , SensorProcessing{
    
    public enum Range: UInt8 {
        case RANGE_2G = 0x0
        case RANGE_4G = 0x1
        case RANGE_8G = 0x2
        case RANGE_16G = 0x3
        
        public static func fromValue(_ value: UInt8) -> Range? {
            switch value {
            case 0:
                return .RANGE_2G
            case 1:
                return .RANGE_4G
            case 2:
                return .RANGE_8G
            case 3:
                return .RANGE_16G
            default:
                return nil
            }
        }
        
    }
    
    var CurrentRange = Range.RANGE_2G
    
    public var packetIndexAccelX:Int = -1
    public var packetIndexAccelY:Int = -1
    public var packetIndexAccelZ:Int = -1
    public static let WIDE_RANGE_ACCELEROMETER_X = "Wide Range Accelerometer X"
    public static let WIDE_RANGE_ACCELEROMETER_Y = "Wide Range Accelerometer Y"
    public static let WIDE_RANGE_ACCELEROMETER_Z = "Wide Range Accelerometer Z"
    
    let CALIBRATION_ID = 31
    var AlignmentMatrix_2G:[[Double]] = [[]]
    var SensitivityMatrix_2G:[[Double]] = [[]]
    var OffsetVector_2G:[Double]=[]
    var AlignmentMatrix_4G:[[Double]] = [[]]
    var SensitivityMatrix_4G:[[Double]] = [[]]
    var OffsetVector_4G:[Double]=[]
    var AlignmentMatrix_8G:[[Double]] = [[]]
    var SensitivityMatrix_8G:[[Double]] = [[]]
    var OffsetVector_8G:[Double]=[]
    var AlignmentMatrix_16G:[[Double]] = [[]]
    var SensitivityMatrix_16G:[[Double]] = [[]]
    var OffsetVector_16G:[Double]=[]
    var wrAccelRange = 1
    var AlignmentMatrix : [[Double]] = [[]]
    var SensitivityMatrix : [[Double]] = [[]]
    var OffsetVector : [Double] = []
    
    public func processData(sensorPacket: [UInt8], objectCluster: ObjectCluster) -> ObjectCluster {
        let x = Array(sensorPacket[packetIndexAccelX..<packetIndexAccelX+2])
        let y = Array(sensorPacket[packetIndexAccelY..<packetIndexAccelY+2])
        let z = Array(sensorPacket[packetIndexAccelZ..<packetIndexAccelZ+2])
        let rawDataX = Double(ShimmerUtilities.parseSensorData(sensorData: x, dataType: SensorDataType.i16)!)
        let rawDataY = Double(ShimmerUtilities.parseSensorData(sensorData: y, dataType: SensorDataType.i16)!)
        let rawDataZ = Double(ShimmerUtilities.parseSensorData(sensorData: z, dataType: SensorDataType.i16)!)
        if (calibrationEnabled){
            let data:[Double] = [rawDataX,rawDataY,rawDataZ]

            let(calData)=LNAccelSensor.calibrateInertialSensorData(data,AlignmentMatrix,SensitivityMatrix,OffsetVector)
            objectCluster.addData(sensorName: WRAccelSensor.WIDE_RANGE_ACCELEROMETER_X, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.meterPerSecondSquared.rawValue, value: calData![0])
            objectCluster.addData(sensorName: WRAccelSensor.WIDE_RANGE_ACCELEROMETER_Y, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.meterPerSecondSquared.rawValue, value: calData![1])
            objectCluster.addData(sensorName: WRAccelSensor.WIDE_RANGE_ACCELEROMETER_Z, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.meterPerSecondSquared.rawValue, value: calData![2])
            print("WR X : \(calData![0]) ,  WR Y : \(calData![1]),  WR Z : \(calData![2])")
        }
        objectCluster.addData(sensorName: WRAccelSensor.WIDE_RANGE_ACCELEROMETER_X, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.meterPerSecondSquared.rawValue, value: rawDataX)
        objectCluster.addData(sensorName: WRAccelSensor.WIDE_RANGE_ACCELEROMETER_Y, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.meterPerSecondSquared.rawValue, value: rawDataY)
        objectCluster.addData(sensorName: WRAccelSensor.WIDE_RANGE_ACCELEROMETER_Z, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.meterPerSecondSquared.rawValue, value: rawDataZ)
        return objectCluster
    }
    
    public override func parseSensorCalibrationDump(bytes: [UInt8]){
        var sensorID = Int(bytes[0]) + (Int(bytes[1])<<8)
        if bytes[0] == CALIBRATION_ID {
            var range = bytes[2]
            var calbytes = bytes
            calbytes.removeFirst(12)
            if range==0{
                (AlignmentMatrix_2G,SensitivityMatrix_2G,OffsetVector_2G) = parseIMUCalibrationParameters(bytes: calbytes)
            }
            if range==2{
                (AlignmentMatrix_4G,SensitivityMatrix_4G,OffsetVector_4G) = parseIMUCalibrationParameters(bytes: calbytes)
            }
            if range==3{
                (AlignmentMatrix_8G,SensitivityMatrix_8G,OffsetVector_8G) = parseIMUCalibrationParameters(bytes: calbytes)
            }
            if range==1{
                (AlignmentMatrix_16G,SensitivityMatrix_16G,OffsetVector_16G) = parseIMUCalibrationParameters(bytes: calbytes)
            }
            
        }
    }
    
    public func updateInfoMemAccelRange(infomem: [UInt8],range: Range) -> [UInt8]{
        var infomemtoupdate = infomem
        var wrAccelRange = 0
        if (range == Range.RANGE_2G){
            wrAccelRange = 0
        } else if (range == Range.RANGE_4G){
            wrAccelRange = 2
        } else if (range == Range.RANGE_8G){
            wrAccelRange = 3
        } else if (range == Range.RANGE_16G){
            wrAccelRange = 1
        }
        let orivalue = infomemtoupdate[ConfigByteLayoutShimmer3.idxConfigSetupByte0]
        let value = infomemtoupdate[ConfigByteLayoutShimmer3.idxConfigSetupByte0] & ~UInt8(ConfigByteLayoutShimmer3.maskLSM303DLHCAccelRange<<ConfigByteLayoutShimmer3.bitShiftLSM303DLHCAccelRange)
        let range = UInt8(wrAccelRange<<ConfigByteLayoutShimmer3.bitShiftLSM303DLHCAccelRange)
        
        infomemtoupdate[ConfigByteLayoutShimmer3.idxConfigSetupByte0] = value | range
        return infomemtoupdate
        
    }
    
    public func getRange()->Range{
        return CurrentRange
    }
    
    public func setInfoMem(infomem: [UInt8]) {
        
        var enabled = Int(infomem[ConfigByteLayoutShimmer3.idxSensors1]>>4) & 1
        if (enabled == 1){
            sensorEnabled = true
        } else {
            sensorEnabled = false
        }
        
        wrAccelRange = (Int(infomem[ConfigByteLayoutShimmer3.idxConfigSetupByte0]>>ConfigByteLayoutShimmer3.bitShiftLSM303DLHCAccelRange) & ConfigByteLayoutShimmer3.maskLSM303DLHCAccelRange)
        if (wrAccelRange == 0){
            CurrentRange = Range.RANGE_2G
            AlignmentMatrix = AlignmentMatrix_2G
            SensitivityMatrix = SensitivityMatrix_2G
            OffsetVector = OffsetVector_2G
        }
        if (wrAccelRange == 2){
            CurrentRange = Range.RANGE_4G
            AlignmentMatrix = AlignmentMatrix_4G
            SensitivityMatrix = SensitivityMatrix_4G
            OffsetVector = OffsetVector_4G
        }
        if (wrAccelRange == 3){
            CurrentRange = Range.RANGE_8G
            AlignmentMatrix = AlignmentMatrix_8G
            SensitivityMatrix = SensitivityMatrix_8G
            OffsetVector = OffsetVector_8G
        }
        if (wrAccelRange == 1){
            CurrentRange = Range.RANGE_16G
            AlignmentMatrix = AlignmentMatrix_16G
            SensitivityMatrix = SensitivityMatrix_16G
            OffsetVector = OffsetVector_16G
        }

    }
    
    public func setLowPowerWRAccel(enable: Bool, isShimmer3withUpdatedSensors: Bool, samplingRate: Double, infomem: [UInt8])-> [UInt8]{
        let LowPowerWRAccelEnabled = enable
        var infomemtoupdate = infomem
        
        if(!LowPowerWRAccelEnabled){
            if(isShimmer3withUpdatedSensors){
                if(samplingRate <= 12.5){
                    infomemtoupdate = updateInfoMemWRAccelRate(infomem: infomem, wrAccelRate:1)
                }else if(samplingRate <= 25){
                    infomemtoupdate = updateInfoMemWRAccelRate(infomem: infomem, wrAccelRate:2)
                }else if(samplingRate <= 50){
                    infomemtoupdate = updateInfoMemWRAccelRate(infomem: infomem, wrAccelRate:3)
                }else if(samplingRate <= 100){
                    infomemtoupdate = updateInfoMemWRAccelRate(infomem: infomem, wrAccelRate:4)
                }else if(samplingRate <= 200){
                    infomemtoupdate = updateInfoMemWRAccelRate(infomem: infomem, wrAccelRate:5)
                }else if(samplingRate <= 400){
                    infomemtoupdate = updateInfoMemWRAccelRate(infomem: infomem, wrAccelRate:6)
                }else if(samplingRate <= 800){
                    infomemtoupdate = updateInfoMemWRAccelRate(infomem: infomem, wrAccelRate:7)
                }else if(samplingRate <= 1600){
                    infomemtoupdate = updateInfoMemWRAccelRate(infomem: infomem, wrAccelRate:8)
                }else if(samplingRate <= 3200){
                    infomemtoupdate = updateInfoMemWRAccelRate(infomem: infomem, wrAccelRate:9)
                }else{
                    infomemtoupdate = updateInfoMemWRAccelRate(infomem: infomem, wrAccelRate:10)
                }
            }else{
                if(samplingRate <= 1){
                    infomemtoupdate = updateInfoMemWRAccelRate(infomem: infomem, wrAccelRate:1)
                }else if(samplingRate <= 10){
                    infomemtoupdate = updateInfoMemWRAccelRate(infomem: infomem, wrAccelRate:2)
                }else if(samplingRate <= 25){
                    infomemtoupdate = updateInfoMemWRAccelRate(infomem: infomem, wrAccelRate:3)
                }else if(samplingRate <= 50){
                    infomemtoupdate = updateInfoMemWRAccelRate(infomem: infomem, wrAccelRate:4)
                }else if(samplingRate <= 100){
                    infomemtoupdate = updateInfoMemWRAccelRate(infomem: infomem, wrAccelRate:5)
                }else if(samplingRate <= 200){
                    infomemtoupdate = updateInfoMemWRAccelRate(infomem: infomem, wrAccelRate:6)
                }else {
                    infomemtoupdate = updateInfoMemWRAccelRate(infomem: infomem, wrAccelRate:7)
                }
            }
        }else //low power accel for shimmer3 enabled
        {
            if(isShimmer3withUpdatedSensors){
                infomemtoupdate = updateInfoMemWRAccelRate(infomem: infomem, wrAccelRate:1)
            }else{
                infomemtoupdate = updateInfoMemWRAccelRate(infomem: infomem, wrAccelRate:2)
            }
        }
        return infomemtoupdate
    }
    
    public func updateInfoMemWRAccelRate(infomem: [UInt8],wrAccelRate: UInt8) -> [UInt8]{
        var infomemtoupdate = infomem

        print("oriinfomem : \(infomemtoupdate)")

        let orivalue = infomemtoupdate[ConfigByteLayoutShimmer3.idxConfigSetupByte0]
        let value = infomemtoupdate[ConfigByteLayoutShimmer3.idxConfigSetupByte0] & ~UInt8(ConfigByteLayoutShimmer3.maskLSM303DLHCAccelSamplingRate<<ConfigByteLayoutShimmer3.bitShiftLSM303DLHCAccelSamplingRate)
        let range = UInt8(wrAccelRate<<ConfigByteLayoutShimmer3.bitShiftLSM303DLHCAccelSamplingRate)
        
        print("orivalue range : \(orivalue)")
        print("value : \(value)")
        print("range : \(range)")

        infomemtoupdate[ConfigByteLayoutShimmer3.idxConfigSetupByte0] = value | range
        
        return infomemtoupdate
    }
}
