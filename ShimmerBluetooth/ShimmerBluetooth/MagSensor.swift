//
//  MagSensor.swift
//  ShimmerBluetooth
//
//  Created by Shimmer Engineering on 21/11/2023.
//

import Foundation
public class MagSensor : IMUSensor , SensorProcessing{
    
    public enum Range3R: UInt8 {
            case RANGE_4Ga = 0x0
            case RANGE_8Ga = 0x1
            case RANGE_12Ga = 0x2
            case RANGE_16Ga = 0x3
     
            public static func fromValue(_ value : UInt8) -> Range3R? {
                switch value{
                case 0:
                    return .RANGE_4Ga
                case 1:
                    return .RANGE_8Ga
                case 2:
                    return .RANGE_12Ga
                case 3:
                    return .RANGE_16Ga
                default:
                    return nil
                }
            }
        }
     
    var Current3RRange = Range3R.RANGE_4Ga
    
    public var packetIndexMagX:Int = -1
    public var packetIndexMagY:Int = -1
    public var packetIndexMagZ:Int = -1
    public static let MAGNETOMETER_X = "Magnetometer X"
    public static let MAGNETOMETER_Y = "Magnetometer Y"
    public static let MAGNETOMETER_Z = "Magnetometer Z"
    var calibBytes_4Ga: [UInt8] = []
    var calibBytes_8Ga: [UInt8] = []
    var calibBytes_12Ga: [UInt8] = []
    var calibBytes_16Ga: [UInt8] = []
    var magRange = 0
    var CALIBRATION_ID = 32
    var AlignmentMatrix : [[Double]] = [[]]
    var SensitivityMatrix : [[Double]] = [[]]
    var OffsetVector : [Double] = []
    var AlignmentMatrix_4Ga:[[Double]] = [[]]
    var SensitivityMatrix_4Ga:[[Double]] = [[]]
    var OffsetVector_4Ga:[Double]=[]
    var AlignmentMatrix_8Ga:[[Double]] = [[]]
    var SensitivityMatrix_8Ga:[[Double]] = [[]]
    var OffsetVector_8Ga:[Double]=[]
    var AlignmentMatrix_12Ga:[[Double]] = [[]]
    var SensitivityMatrix_12Ga:[[Double]] = [[]]
    var OffsetVector_12Ga:[Double]=[]
    var AlignmentMatrix_16Ga:[[Double]] = [[]]
    var SensitivityMatrix_16Ga:[[Double]] = [[]]
    var OffsetVector_16Ga:[Double]=[]
    
    public func get3RRange()->Range3R{
            return Current3RRange
        }
    
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
        if(HardwareVersion == Shimmer3Protocol.HardwareType.Shimmer3R.rawValue){
            CALIBRATION_ID = 41
        }
        var sensorID = Int(bytes[0]) + (Int(bytes[1])<<8)
        if bytes[0] == CALIBRATION_ID {
            var range = bytes[2]
            var calbytes = bytes
            calbytes.removeFirst(12)
            if(HardwareVersion == Shimmer3Protocol.HardwareType.Shimmer3.rawValue){
                (AlignmentMatrix,SensitivityMatrix,OffsetVector) = parseIMUCalibrationParameters(bytes: calbytes)
            }else if(HardwareVersion == Shimmer3Protocol.HardwareType.Shimmer3R.rawValue){
                if range==0{
                    calibBytes_4Ga = calbytes
                    (AlignmentMatrix_4Ga,SensitivityMatrix_4Ga,OffsetVector_4Ga) = parseIMUCalibrationParameters(bytes: calbytes)
                    SensitivityMatrix_4Ga = ShimmerUtilities.divideMatrixElements(SensitivityMatrix_4Ga, 100)
                }
                if range==1{
                    calibBytes_8Ga = calbytes
                    (AlignmentMatrix_8Ga,SensitivityMatrix_8Ga,OffsetVector_8Ga) = parseIMUCalibrationParameters(bytes: calbytes)
                    SensitivityMatrix_8Ga = ShimmerUtilities.divideMatrixElements(SensitivityMatrix_8Ga, 100)
                }
                if range==2{
                    calibBytes_12Ga = calbytes
                    (AlignmentMatrix_12Ga,SensitivityMatrix_12Ga,OffsetVector_12Ga) = parseIMUCalibrationParameters(bytes: calbytes)
                    SensitivityMatrix_12Ga = ShimmerUtilities.divideMatrixElements(SensitivityMatrix_12Ga, 100)
                }
                if range==3{
                    calibBytes_16Ga = calbytes
                    (AlignmentMatrix_16Ga,SensitivityMatrix_16Ga,OffsetVector_16Ga) = parseIMUCalibrationParameters(bytes: calbytes)
                    SensitivityMatrix_16Ga = ShimmerUtilities.divideMatrixElements(SensitivityMatrix_16Ga, 100)
                }
            }
        }
    }
    
    public func setInfoMem(infomem: [UInt8]) {
        
        var enabled = Int(infomem[ConfigByteLayoutShimmer3.idxSensors0]>>ConfigByteLayoutShimmer3.bitShiftLSM303DLHCMagRange) & 1
        if (enabled == 1){
            sensorEnabled = true
        } else {
            sensorEnabled = false
        }
        magRange = (Int(infomem[ConfigByteLayoutShimmer3.idxConfigSetupByte2] >> ConfigByteLayoutShimmer3.bitShiftLSM303DLHCMagRange) & ConfigByteLayoutShimmer3.maskLSM303DLHCMagRange)
        
        if(HardwareVersion == Shimmer3Protocol.HardwareType.Shimmer3R.rawValue){
            if (magRange == 0){
                Current3RRange = Range3R.RANGE_4Ga
                AlignmentMatrix = AlignmentMatrix_4Ga
                SensitivityMatrix = SensitivityMatrix_4Ga
                OffsetVector = OffsetVector_4Ga
            }
            if (magRange == 1){
                Current3RRange = Range3R.RANGE_8Ga
                AlignmentMatrix = AlignmentMatrix_8Ga
                SensitivityMatrix = SensitivityMatrix_8Ga
                OffsetVector = OffsetVector_8Ga
            }
            if (magRange == 2){
                Current3RRange = Range3R.RANGE_12Ga
                AlignmentMatrix = AlignmentMatrix_12Ga
                SensitivityMatrix = SensitivityMatrix_12Ga
                OffsetVector = OffsetVector_12Ga
            }
            if (magRange == 3){
                Current3RRange = Range3R.RANGE_16Ga
                AlignmentMatrix = AlignmentMatrix_16Ga
                SensitivityMatrix = SensitivityMatrix_16Ga
                OffsetVector = OffsetVector_16Ga
            }
        }
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
    
    public func updateInfoMem3RMagRange(infomem: [UInt8],range: Range3R) -> [UInt8]{
        var infomemtoupdate = infomem
        print("oriinfomem: \(infomemtoupdate)")
        var magRange = 0
        var calibBytes = calibBytes_4Ga
        if (range == Range3R.RANGE_4Ga){
            magRange = 0
            calibBytes = calibBytes_4Ga
        }else if (range == Range3R.RANGE_8Ga){
            magRange = 1
            calibBytes = calibBytes_8Ga
        } else if (range == Range3R.RANGE_12Ga){
            magRange = 2
            calibBytes = calibBytes_12Ga
        } else if (range == Range3R.RANGE_16Ga){
            magRange = 3
            calibBytes = calibBytes_16Ga
        }
        
        
        infomemtoupdate.replaceSubrange(
            ConfigByteLayoutShimmer3.idxLSM303DLHCMagCalibration..<ConfigByteLayoutShimmer3.idxLSM303DLHCMagCalibration + ConfigByteLayoutShimmer3.lengthGeneralCalibrationBytes,
            with: calibBytes[0..<ConfigByteLayoutShimmer3.lengthGeneralCalibrationBytes])
        
        let orivalue = infomemtoupdate[ConfigByteLayoutShimmer3.idxConfigSetupByte2]
        let value = infomemtoupdate[ConfigByteLayoutShimmer3.idxConfigSetupByte2] & ~UInt8(ConfigByteLayoutShimmer3.maskLSM303DLHCMagRange<<ConfigByteLayoutShimmer3.bitShiftLSM303DLHCMagRange)
        let range = UInt8(magRange<<ConfigByteLayoutShimmer3.bitShiftLSM303DLHCMagRange)
        
        print("orivalue range: \(orivalue)")
        print("value: \(value)")
        print("range: \(range)")
        
        infomemtoupdate[ConfigByteLayoutShimmer3.idxConfigSetupByte2] = value | range
        print("updatedinfomem: \(infomemtoupdate)")
        
        return infomemtoupdate
    }
}
