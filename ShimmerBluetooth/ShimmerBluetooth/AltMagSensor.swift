//
//  AltMagSensor.swift
//  ShimmerBluetooth
//
//  Created by Shimmer Engineering on 26/05/2025.
//

import Foundation

public class AltMagSensor : IMUSensor , SensorProcessing{
    
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
    
    public var packetIndexAltMagX:Int = -1
    public var packetIndexAltMagY:Int = -1
    public var packetIndexAltMagZ:Int = -1
    public static let ALT_MAGNETOMETER_X = "Alt Magnetometer X"
    public static let ALT_MAGNETOMETER_Y = "Alt Magnetometer Y"
    public static let ALT_MAGNETOMETER_Z = "Alt Magnetometer Z"
    var calibBytes_4Ga: [UInt8] = []
    var calibBytes_8Ga: [UInt8] = []
    var calibBytes_12Ga: [UInt8] = []
    var calibBytes_16Ga: [UInt8] = []
    var altMagRange = 0
    var CALIBRATION_ID = 41
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
        let x = Array(sensorPacket[packetIndexAltMagX..<packetIndexAltMagX+2])
        let y = Array(sensorPacket[packetIndexAltMagY..<packetIndexAltMagY+2])
        let z = Array(sensorPacket[packetIndexAltMagZ..<packetIndexAltMagZ+2])
        let rawDataX = Double(ShimmerUtilities.parseSensorData(sensorData: x, dataType: SensorDataType.i16)!)
        let rawDataY = Double(ShimmerUtilities.parseSensorData(sensorData: y, dataType: SensorDataType.i16)!)
        let rawDataZ = Double(ShimmerUtilities.parseSensorData(sensorData: z, dataType: SensorDataType.i16)!)
        if (calibrationEnabled){
            let data:[Double] = [rawDataX,rawDataY,rawDataZ]

            let(calData)=IMUSensor.calibrateInertialSensorData(data,AlignmentMatrix,SensitivityMatrix,OffsetVector)
            objectCluster.addData(sensorName: AltMagSensor.ALT_MAGNETOMETER_X, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.localflux.rawValue, value: calData![0])
            objectCluster.addData(sensorName: AltMagSensor.ALT_MAGNETOMETER_Y, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.localflux.rawValue, value: calData![1])
            objectCluster.addData(sensorName: AltMagSensor.ALT_MAGNETOMETER_Z, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.localflux.rawValue, value: calData![2])
            print("M X : \(calData![0]) ,  M Y : \(calData![1]),  M Z : \(calData![2])")
        }
        print("MR X : \(rawDataX) ,  MR Y : \(rawDataY),  MR Z : \(rawDataZ)")
        objectCluster.addData(sensorName: AltMagSensor.ALT_MAGNETOMETER_X, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.localflux.rawValue, value: rawDataX)
        objectCluster.addData(sensorName: AltMagSensor.ALT_MAGNETOMETER_Y, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.localflux.rawValue, value: rawDataY)
        objectCluster.addData(sensorName: AltMagSensor.ALT_MAGNETOMETER_Z, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.localflux.rawValue, value: rawDataZ)
        
        return objectCluster
    }
    
    public override func parseSensorCalibrationDump(bytes: [UInt8]){
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
                }
                if range==1{
                    calibBytes_8Ga = calbytes
                    (AlignmentMatrix_8Ga,SensitivityMatrix_8Ga,OffsetVector_8Ga) = parseIMUCalibrationParameters(bytes: calbytes)
                }
                if range==2{
                    calibBytes_12Ga = calbytes
                    (AlignmentMatrix_12Ga,SensitivityMatrix_12Ga,OffsetVector_12Ga) = parseIMUCalibrationParameters(bytes: calbytes)
                }
                if range==3{
                    calibBytes_16Ga = calbytes
                    (AlignmentMatrix_16Ga,SensitivityMatrix_16Ga,OffsetVector_16Ga) = parseIMUCalibrationParameters(bytes: calbytes)
                }
            }
        }
    }
    
    public func setInfoMem(infomem: [UInt8]) {
        
        var enabled = Int(infomem[ConfigByteLayoutShimmer3.idxSensors2]>>ConfigByteLayoutShimmer3.bitShiftLSM303DLHCMagRange) & 1
        if (enabled == 1){
            sensorEnabled = true
        } else {
            sensorEnabled = false
        }
        altMagRange = (Int(infomem[ConfigByteLayoutShimmer3.idxConfigSetupByte2] >> ConfigByteLayoutShimmer3.bitShiftLSM303DLHCMagRange) & ConfigByteLayoutShimmer3.maskLSM303DLHCMagRange)
        
        if(HardwareVersion == Shimmer3Protocol.HardwareType.Shimmer3R.rawValue){
            if (altMagRange == 0){
                Current3RRange = Range3R.RANGE_4Ga
                AlignmentMatrix = AlignmentMatrix_4Ga
                SensitivityMatrix = SensitivityMatrix_4Ga
                OffsetVector = OffsetVector_4Ga
            }
            if (altMagRange == 1){
                Current3RRange = Range3R.RANGE_8Ga
                AlignmentMatrix = AlignmentMatrix_8Ga
                SensitivityMatrix = SensitivityMatrix_8Ga
                OffsetVector = OffsetVector_8Ga
            }
            if (altMagRange == 2){
                Current3RRange = Range3R.RANGE_12Ga
                AlignmentMatrix = AlignmentMatrix_12Ga
                SensitivityMatrix = SensitivityMatrix_12Ga
                OffsetVector = OffsetVector_12Ga
            }
            if (altMagRange == 3){
                Current3RRange = Range3R.RANGE_16Ga
                AlignmentMatrix = AlignmentMatrix_16Ga
                SensitivityMatrix = SensitivityMatrix_16Ga
                OffsetVector = OffsetVector_16Ga
            }
        }
    }
    
    public func setLowPowerAltMag(enable: Bool, isShimmer3withUpdatedSensors: Bool, isShimmer3Sensor: Bool, samplingRate: Double, infomem: [UInt8])-> [UInt8]{
        let LowPowerMagEnabled = enable
        var infomemtoupdate = infomem
        if(HardwareVersion == Shimmer3Protocol.HardwareType.Shimmer3R.rawValue){
            if(!LowPowerMagEnabled){
                if(samplingRate > 560){
                    infomemtoupdate = updateInfoMemAltMagRate(infomem: infomem, magRate:0x01)
                }else if(samplingRate > 300){
                    infomemtoupdate = updateInfoMemAltMagRate(infomem: infomem, magRate:0x11)
                }else if(samplingRate > 155){
                    infomemtoupdate = updateInfoMemAltMagRate(infomem: infomem, magRate:0x21)
                }else if(samplingRate > 100){
                    infomemtoupdate = updateInfoMemAltMagRate(infomem: infomem, magRate:0x31)
                }else if(samplingRate > 50){
                    infomemtoupdate = updateInfoMemAltMagRate(infomem: infomem, magRate:0x31)
                }else if(samplingRate > 20){
                    infomemtoupdate = updateInfoMemAltMagRate(infomem: infomem, magRate:0x3E)
                }else if(samplingRate > 10){
                    infomemtoupdate = updateInfoMemAltMagRate(infomem: infomem, magRate:0x3A)
                }else{
                    infomemtoupdate = updateInfoMemAltMagRate(infomem: infomem, magRate:0x08)
                }
            }else{
                infomemtoupdate = updateInfoMemAltMagRate(infomem: infomem, magRate:0x08)
            }
        }
        return infomemtoupdate

    }
    
    public func updateInfoMem3RAltMagRange(infomem: [UInt8],range: Range3R) -> [UInt8]{
        var infomemtoupdate = infomem
        print("oriinfomem: \(infomemtoupdate)")
        var altMagRange = 0
        var calibBytes = calibBytes_4Ga
        if (range == Range3R.RANGE_4Ga){
            altMagRange = 0
            calibBytes = calibBytes_4Ga
        }else if (range == Range3R.RANGE_8Ga){
            altMagRange = 1
            calibBytes = calibBytes_8Ga
        } else if (range == Range3R.RANGE_12Ga){
            altMagRange = 2
            calibBytes = calibBytes_12Ga
        } else if (range == Range3R.RANGE_16Ga){
            altMagRange = 3
            calibBytes = calibBytes_16Ga
        }
        
        infomemtoupdate.replaceSubrange(
            ConfigByteLayoutShimmer3.idxLIS3MDLAltMagCalibration..<ConfigByteLayoutShimmer3.idxLIS3MDLAltMagCalibration + ConfigByteLayoutShimmer3.lengthGeneralCalibrationBytes,
            with: calibBytes[0..<ConfigByteLayoutShimmer3.lengthGeneralCalibrationBytes])
        
        let orivalue = infomemtoupdate[ConfigByteLayoutShimmer3.idxConfigSetupByte2]
        let value = infomemtoupdate[ConfigByteLayoutShimmer3.idxConfigSetupByte2] & ~UInt8(ConfigByteLayoutShimmer3.maskLSM303DLHCMagRange<<ConfigByteLayoutShimmer3.bitShiftLSM303DLHCMagRange)
        let range = UInt8(altMagRange<<ConfigByteLayoutShimmer3.bitShiftLSM303DLHCMagRange)
        
        print("orivalue range: \(orivalue)")
        print("value: \(value)")
        print("range: \(range)")
        
        infomemtoupdate[ConfigByteLayoutShimmer3.idxConfigSetupByte2] = value | range
        print("updatedinfomem: \(infomemtoupdate)")
        
        return infomemtoupdate
    }
    
    
    public func updateInfoMemAltMagRate(infomem: [UInt8],magRate: UInt8) -> [UInt8]{
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


