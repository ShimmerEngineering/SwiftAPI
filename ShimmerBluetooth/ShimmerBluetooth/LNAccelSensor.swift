//
//  LNAccelSensor.swift
//  ShimmerBluetooth
//
//  Created by Shimmer Engineering on 17/11/2023.
//

import Foundation

public class LNAccelSensor : IMUSensor , SensorProcessing{
    
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
    public static let LOW_NOISE_ACCELEROMETER_X = "Low Noise Accelerometer X"
    public static let LOW_NOISE_ACCELEROMETER_Y = "Low Noise Accelerometer Y"
    public static let LOW_NOISE_ACCELEROMETER_Z = "Low Noise Accelerometer Z"
    public var packetIndexAccelX:Int = -1
    public var packetIndexAccelY:Int = -1
    public var packetIndexAccelZ:Int = -1
    var AlignmentMatrix:[[Double]] = [[]]
    var SensitivityMatrix:[[Double]] = [[]]
    var OffsetVector:[Double]=[]
    var CalibrationID = 2
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
    var lnAccelRange = 1
    
    var calibBytes_2G: [UInt8] = []
    var calibBytes_4G: [UInt8] = []
    var calibBytes_8G: [UInt8] = []
    var calibBytes_16G: [UInt8] = []
    
    public func processData(sensorPacket: [UInt8], objectCluster: ObjectCluster) -> ObjectCluster {
        let x = Array(sensorPacket[packetIndexAccelX..<packetIndexAccelX+2])
        let y = Array(sensorPacket[packetIndexAccelY..<packetIndexAccelY+2])
        let z = Array(sensorPacket[packetIndexAccelZ..<packetIndexAccelZ+2])
        var rawDataX: Double = 0
        var rawDataY: Double = 0
        var rawDataZ: Double = 0
        if (HardwareVersion == Shimmer3Protocol.HardwareType.Shimmer3.rawValue){
            rawDataX = Double(ShimmerUtilities.parseSensorData(sensorData: x, dataType: SensorDataType.u12)!)
            rawDataY = Double(ShimmerUtilities.parseSensorData(sensorData: y, dataType: SensorDataType.u12)!)
            rawDataZ = Double(ShimmerUtilities.parseSensorData(sensorData: z, dataType: SensorDataType.u12)!)
        } else if (HardwareVersion == Shimmer3Protocol.HardwareType.Shimmer3R.rawValue){
            rawDataX = Double(ShimmerUtilities.parseSensorData(sensorData: x, dataType: SensorDataType.i16)!)
            rawDataY = Double(ShimmerUtilities.parseSensorData(sensorData: y, dataType: SensorDataType.i16)!)
            rawDataZ = Double(ShimmerUtilities.parseSensorData(sensorData: z, dataType: SensorDataType.i16)!)
        }
        if (calibrationEnabled){
            let data:[Double] = [rawDataX,rawDataY,rawDataZ]
            let(calData)=LNAccelSensor.calibrateInertialSensorData(data,AlignmentMatrix,SensitivityMatrix,OffsetVector)
            objectCluster.addData(sensorName: LNAccelSensor.LOW_NOISE_ACCELEROMETER_X, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.meterPerSecondSquared.rawValue, value: calData![0])
            objectCluster.addData(sensorName: LNAccelSensor.LOW_NOISE_ACCELEROMETER_Y, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.meterPerSecondSquared.rawValue, value: calData![1])
            objectCluster.addData(sensorName: LNAccelSensor.LOW_NOISE_ACCELEROMETER_Z, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.meterPerSecondSquared.rawValue, value: calData![2])
        }
        
        objectCluster.addData(sensorName: LNAccelSensor.LOW_NOISE_ACCELEROMETER_X, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: rawDataX)
        objectCluster.addData(sensorName: LNAccelSensor.LOW_NOISE_ACCELEROMETER_Y, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: rawDataY)
        objectCluster.addData(sensorName: LNAccelSensor.LOW_NOISE_ACCELEROMETER_Z, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: rawDataZ)
        //print(calData)
        return objectCluster
    }
    
    public override func parseSensorCalibrationDump(bytes: [UInt8]){
        if (HardwareVersion==Shimmer3Protocol.HardwareType.Shimmer3R.rawValue){
            CalibrationID = 37
        }
        var sensorID = Int(bytes[0]) + (Int(bytes[1])<<8)
        if bytes[0] == CalibrationID {
            var range = bytes[2]
            var calbytes = bytes
            calbytes.removeFirst(12)
            if(HardwareVersion == Shimmer3Protocol.HardwareType.Shimmer3.rawValue){
                (AlignmentMatrix,SensitivityMatrix,OffsetVector) = parseIMUCalibrationParameters(bytes: calbytes)
            }else if(HardwareVersion == Shimmer3Protocol.HardwareType.Shimmer3R.rawValue){
                if range==0{
                    calibBytes_2G = calbytes
                    (AlignmentMatrix_2G,SensitivityMatrix_2G,OffsetVector_2G) = parseIMUCalibrationParameters(bytes: calbytes)
                }
                if range==1{
                    calibBytes_4G = calbytes
                    (AlignmentMatrix_4G,SensitivityMatrix_4G,OffsetVector_4G) = parseIMUCalibrationParameters(bytes: calbytes)
                }
                if range==2{
                    calibBytes_8G = calbytes
                    (AlignmentMatrix_8G,SensitivityMatrix_8G,OffsetVector_8G) = parseIMUCalibrationParameters(bytes: calbytes)
                }
                if range==3{
                    calibBytes_16G = calbytes
                    (AlignmentMatrix_16G,SensitivityMatrix_16G,OffsetVector_16G) = parseIMUCalibrationParameters(bytes: calbytes)
                }
            }
            
            
        }
    }
    
    public func updateInfoMemLNAccelRange(infomem: [UInt8],range: Range) -> [UInt8]{
        var infomemtoupdate = infomem
        if(HardwareVersion == Shimmer3Protocol.HardwareType.Shimmer3R.rawValue){
            var lnAccelRange = 0
            var calibBytes = calibBytes_2G
            if (range == Range.RANGE_2G){
                lnAccelRange = 0
                calibBytes = calibBytes_2G
            } else if (range == Range.RANGE_4G){
                lnAccelRange = 1
                calibBytes = calibBytes_4G
            } else if (range == Range.RANGE_8G){
                lnAccelRange = 2
                calibBytes = calibBytes_8G
            } else if (range == Range.RANGE_16G){
                lnAccelRange = 3
                calibBytes = calibBytes_16G
            }

            infomemtoupdate.replaceSubrange(
                ConfigByteLayoutShimmer3.idxLSM6DSVAccelCalibration..<ConfigByteLayoutShimmer3.idxLSM6DSVAccelCalibration + ConfigByteLayoutShimmer3.lengthGeneralCalibrationBytes,
                with: calibBytes[0..<ConfigByteLayoutShimmer3.lengthGeneralCalibrationBytes])
            
            let orivalue = infomemtoupdate[ConfigByteLayoutShimmer3.idxConfigSetupByte3]
            let value = infomemtoupdate[ConfigByteLayoutShimmer3.idxConfigSetupByte3] & ~UInt8(ConfigByteLayoutShimmer3.maskMPU9150AccelRange<<ConfigByteLayoutShimmer3.bitShiftMPU9150AccelRange)
            let range = UInt8(lnAccelRange<<ConfigByteLayoutShimmer3.bitShiftMPU9150AccelRange)
            
            infomemtoupdate[ConfigByteLayoutShimmer3.idxConfigSetupByte3] = value | range
        }
        return infomemtoupdate
        
    }
    
    public func getRange()->Range{
        return CurrentRange
    }
    
    public func setInfoMem(infomem: [UInt8]) {
        var enabled = Int(infomem[ConfigByteLayoutShimmer3.idxSensors0]>>7) & 1
        if (enabled == 1){
            sensorEnabled = true
        } else {
            sensorEnabled = false
        }
        if(HardwareVersion == Shimmer3Protocol.HardwareType.Shimmer3R.rawValue){
            lnAccelRange = (Int(infomem[ConfigByteLayoutShimmer3.idxConfigSetupByte3]>>ConfigByteLayoutShimmer3.bitShiftMPU9150AccelRange) & ConfigByteLayoutShimmer3.maskMPU9150AccelRange)
            if (lnAccelRange == 0){
                CurrentRange = Range.RANGE_2G
                AlignmentMatrix = AlignmentMatrix_2G
                SensitivityMatrix = SensitivityMatrix_2G
                OffsetVector = OffsetVector_2G
            }
            if (lnAccelRange == 1){
                CurrentRange = Range.RANGE_4G
                AlignmentMatrix = AlignmentMatrix_4G
                SensitivityMatrix = SensitivityMatrix_4G
                OffsetVector = OffsetVector_4G
            }
            if (lnAccelRange == 2){
                CurrentRange = Range.RANGE_8G
                AlignmentMatrix = AlignmentMatrix_8G
                SensitivityMatrix = SensitivityMatrix_8G
                OffsetVector = OffsetVector_8G
            }
            if (lnAccelRange == 3){
                CurrentRange = Range.RANGE_16G
                AlignmentMatrix = AlignmentMatrix_16G
                SensitivityMatrix = SensitivityMatrix_16G
                OffsetVector = OffsetVector_16G
            }
        }
        

    }
    
    
}
