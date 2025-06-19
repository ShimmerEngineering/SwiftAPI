//
//  GyroSensor.swift
//  
//
//  Created by Shimmer Engineering on 21/11/2023.
//

import Foundation

public class GyroSensor : IMUSensor , SensorProcessing{
    
    public enum Range: UInt8 {
        case RANGE_250DPS = 0x0
        case RANGE_500DPS = 0x1
        case RANGE_1000DPS = 0x2
        case RANGE_2000DPS = 0x3
        
        public static func fromValue(_ value : UInt8) -> Range? {
            switch value{
            case 0:
                return .RANGE_250DPS
            case 1:
                return .RANGE_500DPS
            case 2:
                return .RANGE_1000DPS
            case 3:
                return .RANGE_2000DPS
            default:
                return nil
            }
        }
    }
    
    public enum Range3R: UInt8 {
        case RANGE_125DPS = 0x0
        case RANGE_250DPS = 0x1
        case RANGE_500DPS = 0x2
        case RANGE_1000DPS = 0x3
        case RANGE_2000DPS = 0x4
        case RANGE_4000DPS = 0x5
        
        public static func fromValue(_ value : UInt8) -> Range3R? {
            switch value{
            case 0:
                return .RANGE_125DPS
            case 1:
                return .RANGE_250DPS
            case 2:
                return .RANGE_500DPS
            case 3:
                return .RANGE_1000DPS
            case 4:
                return .RANGE_2000DPS
            case 5:
                return .RANGE_4000DPS
            default:
                return nil
            }
        }
    }

    
    var CurrentRange = Range.RANGE_250DPS
    var Current3RRange = Range3R.RANGE_250DPS


    public var packetIndexGyroX:Int = -1
    public var packetIndexGyroY:Int = -1
    public var packetIndexGyroZ:Int = -1
    public static let GYROSCOPE_X = "Gyroscope X"
    public static let GYROSCOPE_Y = "Gyroscope Y"
    public static let GYROSCOPE_Z = "Gyroscope Z"
    var CALIBRATION_ID = 30
    var AlignmentMatrix_125DPS:[[Double]] = [[]]
    var SensitivityMatrix_125DPS:[[Double]] = [[]]
    var OffsetVector_125DPS:[Double]=[]
    var AlignmentMatrix_250DPS:[[Double]] = [[]]
    var SensitivityMatrix_250DPS:[[Double]] = [[]]
    var OffsetVector_250DPS:[Double]=[]
    var AlignmentMatrix_500DPS:[[Double]] = [[]]
    var SensitivityMatrix_500DPS:[[Double]] = [[]]
    var OffsetVector_500DPS:[Double]=[]
    var AlignmentMatrix_1000DPS:[[Double]] = [[]]
    var SensitivityMatrix_1000DPS:[[Double]] = [[]]
    var OffsetVector_1000DPS:[Double]=[]
    var AlignmentMatrix_2000DPS:[[Double]] = [[]]
    var SensitivityMatrix_2000DPS:[[Double]] = [[]]
    var OffsetVector_2000DPS:[Double]=[]
    var AlignmentMatrix_4000DPS:[[Double]] = [[]]
    var SensitivityMatrix_4000DPS:[[Double]] = [[]]
    var OffsetVector_4000DPS:[Double]=[]
    
    var gyroRange = 1
    var AlignmentMatrix : [[Double]] = [[]]
    var SensitivityMatrix : [[Double]] = [[]]
    var OffsetVector : [Double] = []
    
    var calibBytes_125DPS: [UInt8] = []
    var calibBytes_250DPS: [UInt8] = []
    var calibBytes_500DPS: [UInt8] = []
    var calibBytes_1000DPS: [UInt8] = []
    var calibBytes_2000DPS: [UInt8] = []
    var calibBytes_4000DPS: [UInt8] = []
    
    public func processData(sensorPacket: [UInt8], objectCluster: ObjectCluster) -> ObjectCluster {
        let x = Array(sensorPacket[packetIndexGyroX..<packetIndexGyroX+2])
        let y = Array(sensorPacket[packetIndexGyroY..<packetIndexGyroY+2])
        let z = Array(sensorPacket[packetIndexGyroZ..<packetIndexGyroZ+2])
        var rawDataX: Double = 0
        var rawDataY: Double = 0
        var rawDataZ: Double = 0

        if(HardwareVersion == Shimmer3Protocol.HardwareType.Shimmer3.rawValue){
            rawDataX = Double(ShimmerUtilities.parseSensorData(sensorData: x, dataType: SensorDataType.i16MSB)!)
            rawDataY = Double(ShimmerUtilities.parseSensorData(sensorData: y, dataType: SensorDataType.i16MSB)!)
            rawDataZ = Double(ShimmerUtilities.parseSensorData(sensorData: z, dataType: SensorDataType.i16MSB)!)
        }else if(HardwareVersion == Shimmer3Protocol.HardwareType.Shimmer3R.rawValue){
            rawDataX = Double(ShimmerUtilities.parseSensorData(sensorData: x, dataType: SensorDataType.i16)!)
            rawDataY = Double(ShimmerUtilities.parseSensorData(sensorData: y, dataType: SensorDataType.i16)!)
            rawDataZ = Double(ShimmerUtilities.parseSensorData(sensorData: z, dataType: SensorDataType.i16)!)
        }
       
        //print("G X : \(rawDataX) ,  G Y : \(rawDataY),  G Z : \(rawDataZ)")
        if (calibrationEnabled){
            let data:[Double] = [rawDataX,rawDataY,rawDataZ]

            let(calData)=LNAccelSensor.calibrateInertialSensorData(data,AlignmentMatrix,SensitivityMatrix,OffsetVector)
            objectCluster.addData(sensorName: GyroSensor.GYROSCOPE_X, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.degreepersecond.rawValue, value: calData![0])
            objectCluster.addData(sensorName: GyroSensor.GYROSCOPE_Y, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.degreepersecond.rawValue, value: calData![1])
            objectCluster.addData(sensorName: GyroSensor.GYROSCOPE_Z, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.degreepersecond.rawValue, value: calData![2])
            print("G X : \(calData![0]) ,  G Y : \(calData![1]),  G Z : \(calData![2])")
        }
        objectCluster.addData(sensorName: GyroSensor.GYROSCOPE_X, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.degreepersecond.rawValue, value: rawDataX)
        objectCluster.addData(sensorName: GyroSensor.GYROSCOPE_X, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.degreepersecond.rawValue, value: rawDataY)
        objectCluster.addData(sensorName: GyroSensor.GYROSCOPE_X, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.degreepersecond.rawValue, value: rawDataZ)
        return objectCluster
    }
    
    public override func parseSensorCalibrationDump(bytes: [UInt8]){
        if(HardwareVersion == Shimmer3Protocol.HardwareType.Shimmer3R.rawValue){
            CALIBRATION_ID = 38
        }
        var sensorID = Int(bytes[0]) + (Int(bytes[1])<<8)
        if bytes[0] == CALIBRATION_ID {
            var range = bytes[2]
            var calbytes = bytes
            calbytes.removeFirst(12)
            
            if(HardwareVersion == Shimmer3Protocol.HardwareType.Shimmer3.rawValue){
                if range==0{
                    calibBytes_250DPS = calbytes
                    (AlignmentMatrix_250DPS,SensitivityMatrix_250DPS,OffsetVector_250DPS) = parseIMUCalibrationParameters(bytes: calbytes)
                    SensitivityMatrix_250DPS = ShimmerUtilities.divideMatrixElements(SensitivityMatrix_250DPS, 100)
                }
                if range==1{
                    calibBytes_500DPS = calbytes
                    (AlignmentMatrix_500DPS,SensitivityMatrix_500DPS,OffsetVector_500DPS) = parseIMUCalibrationParameters(bytes: calbytes)
                    SensitivityMatrix_500DPS = ShimmerUtilities.divideMatrixElements(SensitivityMatrix_500DPS, 100)
                }
                if range==2{
                    calibBytes_1000DPS = calbytes
                    (AlignmentMatrix_1000DPS,SensitivityMatrix_1000DPS,OffsetVector_1000DPS) = parseIMUCalibrationParameters(bytes: calbytes)
                    SensitivityMatrix_1000DPS = ShimmerUtilities.divideMatrixElements(SensitivityMatrix_1000DPS, 100)
                }
                if range==3{
                    calibBytes_2000DPS = calbytes
                    (AlignmentMatrix_2000DPS,SensitivityMatrix_2000DPS,OffsetVector_2000DPS) = parseIMUCalibrationParameters(bytes: calbytes)
                    SensitivityMatrix_2000DPS = ShimmerUtilities.divideMatrixElements(SensitivityMatrix_2000DPS, 100)
                }
            }else if(HardwareVersion == Shimmer3Protocol.HardwareType.Shimmer3R.rawValue){
                if range==0{
                    calibBytes_125DPS = calbytes
                    (AlignmentMatrix_125DPS,SensitivityMatrix_125DPS,OffsetVector_125DPS) = parseIMUCalibrationParameters(bytes: calbytes)
                    SensitivityMatrix_125DPS = ShimmerUtilities.divideMatrixElements(SensitivityMatrix_125DPS, 100)
                }
                if range==1{
                    calibBytes_250DPS = calbytes
                    (AlignmentMatrix_250DPS,SensitivityMatrix_250DPS,OffsetVector_250DPS) = parseIMUCalibrationParameters(bytes: calbytes)
                    SensitivityMatrix_250DPS = ShimmerUtilities.divideMatrixElements(SensitivityMatrix_250DPS, 100)
                }
                if range==2{
                    calibBytes_500DPS = calbytes
                    (AlignmentMatrix_500DPS,SensitivityMatrix_500DPS,OffsetVector_500DPS) = parseIMUCalibrationParameters(bytes: calbytes)
                    SensitivityMatrix_500DPS = ShimmerUtilities.divideMatrixElements(SensitivityMatrix_500DPS, 100)
                }
                if range==3{
                    calibBytes_1000DPS = calbytes
                    (AlignmentMatrix_1000DPS,SensitivityMatrix_1000DPS,OffsetVector_1000DPS) = parseIMUCalibrationParameters(bytes: calbytes)
                    SensitivityMatrix_1000DPS = ShimmerUtilities.divideMatrixElements(SensitivityMatrix_1000DPS, 100)
                }
                if range==4{
                    calibBytes_2000DPS = calbytes
                    (AlignmentMatrix_2000DPS,SensitivityMatrix_2000DPS,OffsetVector_2000DPS) = parseIMUCalibrationParameters(bytes: calbytes)
                    SensitivityMatrix_2000DPS = ShimmerUtilities.divideMatrixElements(SensitivityMatrix_2000DPS, 100)
                }
                if range==5{
                    calibBytes_4000DPS = calbytes
                    (AlignmentMatrix_4000DPS,SensitivityMatrix_4000DPS,OffsetVector_4000DPS) = parseIMUCalibrationParameters(bytes: calbytes)
                    SensitivityMatrix_4000DPS = ShimmerUtilities.divideMatrixElements(SensitivityMatrix_4000DPS, 100)
                }
            }

            
            
        }
    }
    
    public func updateInfoMemGyroRange(infomem: [UInt8],range: Range) -> [UInt8]{
        var infomemtoupdate = infomem
        print("oriinfomem: \(infomemtoupdate)")
        var gyroRange = 0
        var calibBytes = calibBytes_250DPS
            if (range == Range.RANGE_250DPS){
                gyroRange = 0
                calibBytes = calibBytes_250DPS
            } else if (range == Range.RANGE_500DPS){
                gyroRange = 1
                calibBytes = calibBytes_500DPS
            } else if (range == Range.RANGE_1000DPS){
                gyroRange = 2
                calibBytes = calibBytes_1000DPS
            } else if (range == Range.RANGE_2000DPS){
                gyroRange = 3
                calibBytes = calibBytes_2000DPS
            }
        
        
        infomemtoupdate.replaceSubrange(
                        ConfigByteLayoutShimmer3.idxGyroCalibration..<ConfigByteLayoutShimmer3.idxGyroCalibration + ConfigByteLayoutShimmer3.lengthGeneralCalibrationBytes,
                        with: calibBytes[0..<ConfigByteLayoutShimmer3.lengthGeneralCalibrationBytes])
        
            let orivalue = infomemtoupdate[ConfigByteLayoutShimmer3.idxConfigSetupByte2]
            let value = infomemtoupdate[ConfigByteLayoutShimmer3.idxConfigSetupByte2] & ~UInt8(ConfigByteLayoutShimmer3.maskMPU9150GyroRange<<ConfigByteLayoutShimmer3.bitShiftMPU9150GyroRange)
            let range = UInt8(gyroRange<<ConfigByteLayoutShimmer3.bitShiftMPU9150GyroRange)
         
            print("orivalue range: \(orivalue)")
            print("value: \(value)")
            print("range: \(range)")

            infomemtoupdate[ConfigByteLayoutShimmer3.idxConfigSetupByte2] = value | range
            print("updatedinfomem: \(infomemtoupdate)")
        
       
        return infomemtoupdate
     
    }
    
    
    public func updateInfoMem3RGyroRange(infomem: [UInt8],range: Range3R) -> [UInt8]{
        var infomemtoupdate = infomem
        print("oriinfomem: \(infomemtoupdate)")
        var gyroRange = 0
        var calibBytes = calibBytes_125DPS
        if (range == Range3R.RANGE_125DPS){
            gyroRange = 0
            calibBytes = calibBytes_125DPS
        }else if (range == Range3R.RANGE_250DPS){
            gyroRange = 1
            calibBytes = calibBytes_250DPS
        } else if (range == Range3R.RANGE_500DPS){
            gyroRange = 2
            calibBytes = calibBytes_500DPS
        } else if (range == Range3R.RANGE_1000DPS){
            gyroRange = 3
            calibBytes = calibBytes_1000DPS
        } else if (range == Range3R.RANGE_2000DPS){
            gyroRange = 4
            calibBytes = calibBytes_2000DPS
        }else if (range == Range3R.RANGE_4000DPS){
            gyroRange = 5
            calibBytes = calibBytes_4000DPS
        }
        
        
        infomemtoupdate.replaceSubrange(
                        ConfigByteLayoutShimmer3.idxGyroCalibration..<ConfigByteLayoutShimmer3.idxGyroCalibration + ConfigByteLayoutShimmer3.lengthGeneralCalibrationBytes,
                        with: calibBytes[0..<ConfigByteLayoutShimmer3.lengthGeneralCalibrationBytes])
        
        let orivalue = infomemtoupdate[ConfigByteLayoutShimmer3.idxConfigSetupByte2]
        let value = infomemtoupdate[ConfigByteLayoutShimmer3.idxConfigSetupByte2] & ~UInt8(ConfigByteLayoutShimmer3.maskMPU9150GyroRange<<ConfigByteLayoutShimmer3.bitShiftMPU9150GyroRange)
        let range = UInt8(gyroRange<<ConfigByteLayoutShimmer3.bitShiftMPU9150GyroRange)
     
        print("orivalue range: \(orivalue)")
        print("value: \(value)")
        print("range: \(range)")

        infomemtoupdate[ConfigByteLayoutShimmer3.idxConfigSetupByte2] = value | range
        print("updatedinfomem: \(infomemtoupdate)")
        
        let orivalue2 = infomemtoupdate[ConfigByteLayoutShimmer3.idxConfigSetupByte4]
        let value2 = infomemtoupdate[ConfigByteLayoutShimmer3.idxConfigSetupByte4] & ~UInt8(ConfigByteLayoutShimmer3.maskLSM6DSVyroRangeMSB<<ConfigByteLayoutShimmer3.bitShiftLSM6DSVyroRangeMSB)
        let range2 = UInt8((gyroRange>>2)<<ConfigByteLayoutShimmer3.bitShiftLSM6DSVyroRangeMSB)
     
        print("orivalue2 range: \(orivalue2)")
        print("value2: \(value2)")
        print("range2: \(range2)")

        infomemtoupdate[ConfigByteLayoutShimmer3.idxConfigSetupByte4] = value2 | range2
        print("updatedinfomem: \(infomemtoupdate)")
    
   
    return infomemtoupdate
    }
     
    public func getRange()->Range{
        return CurrentRange
    }
    
    public func get3RRange()->Range3R{
        return Current3RRange
    }
    
    public func setInfoMem(infomem: [UInt8]) {
        
        var enabled = Int(infomem[ConfigByteLayoutShimmer3.idxSensors0]>>6) & 1
        if (enabled == 1){
            sensorEnabled = true
        } else {
            sensorEnabled = false
        }
        
        if(HardwareVersion == Shimmer3Protocol.HardwareType.Shimmer3.rawValue){
            gyroRange = (Int(infomem[ConfigByteLayoutShimmer3.idxConfigSetupByte2] >> ConfigByteLayoutShimmer3.bitShiftMPU9150GyroRange) & ConfigByteLayoutShimmer3.maskMPU9150GyroRange)
            if (gyroRange == 0){
                CurrentRange = Range.RANGE_250DPS
                AlignmentMatrix = AlignmentMatrix_250DPS
                SensitivityMatrix = SensitivityMatrix_250DPS
                OffsetVector = OffsetVector_250DPS
            }
            if (gyroRange == 1){
                CurrentRange = Range.RANGE_500DPS
                AlignmentMatrix = AlignmentMatrix_500DPS
                SensitivityMatrix = SensitivityMatrix_500DPS
                OffsetVector = OffsetVector_500DPS
            }
            if (gyroRange == 2){
                CurrentRange = Range.RANGE_1000DPS
                AlignmentMatrix = AlignmentMatrix_1000DPS
                SensitivityMatrix = SensitivityMatrix_1000DPS
                OffsetVector = OffsetVector_1000DPS
            }
            if (gyroRange == 3){
                CurrentRange = Range.RANGE_2000DPS
                AlignmentMatrix = AlignmentMatrix_2000DPS
                SensitivityMatrix = SensitivityMatrix_2000DPS
                OffsetVector = OffsetVector_2000DPS
            }
        }else if(HardwareVersion == Shimmer3Protocol.HardwareType.Shimmer3R.rawValue){
            let gyroRangeLSB = (Int(infomem[ConfigByteLayoutShimmer3.idxConfigSetupByte2] >> ConfigByteLayoutShimmer3.bitShiftMPU9150GyroRange) & ConfigByteLayoutShimmer3.maskMPU9150GyroRange)
            let gyroRangeMSB = (Int(infomem[ConfigByteLayoutShimmer3.idxConfigSetupByte4] >> ConfigByteLayoutShimmer3.bitShiftLSM6DSVyroRangeMSB) & ConfigByteLayoutShimmer3.maskLSM6DSVyroRangeMSB)
            
            gyroRange = ((gyroRangeMSB<<2) | gyroRangeLSB)
            if (gyroRange == 0){
                Current3RRange = Range3R.RANGE_125DPS
                AlignmentMatrix = AlignmentMatrix_125DPS
                SensitivityMatrix = SensitivityMatrix_125DPS
                OffsetVector = OffsetVector_125DPS
            }
            if (gyroRange == 1){
                Current3RRange = Range3R.RANGE_250DPS
                AlignmentMatrix = AlignmentMatrix_250DPS
                SensitivityMatrix = SensitivityMatrix_250DPS
                OffsetVector = OffsetVector_250DPS
            }
            if (gyroRange == 2){
                Current3RRange = Range3R.RANGE_500DPS
                AlignmentMatrix = AlignmentMatrix_500DPS
                SensitivityMatrix = SensitivityMatrix_500DPS
                OffsetVector = OffsetVector_500DPS
            }
            if (gyroRange == 3){
                Current3RRange = Range3R.RANGE_1000DPS
                AlignmentMatrix = AlignmentMatrix_1000DPS
                SensitivityMatrix = SensitivityMatrix_1000DPS
                OffsetVector = OffsetVector_1000DPS
            }
            if (gyroRange == 4){
                Current3RRange = Range3R.RANGE_2000DPS
                AlignmentMatrix = AlignmentMatrix_2000DPS
                SensitivityMatrix = SensitivityMatrix_2000DPS
                OffsetVector = OffsetVector_2000DPS
            }
            if (gyroRange == 5){
                Current3RRange = Range3R.RANGE_4000DPS
                AlignmentMatrix = AlignmentMatrix_4000DPS
                SensitivityMatrix = SensitivityMatrix_4000DPS
                OffsetVector = OffsetVector_4000DPS
            }
        }
    }
    
    public func setLowPowerGyro(enable: Bool, samplingRate: Double, infomem: [UInt8])-> [UInt8]{
        let LowPowerGyroEnabled = enable
        //for Shimmer3 Hardware version
        var infomemtoupdate = infomem
        
        if(!LowPowerGyroEnabled){
            if(samplingRate <= 51.28){
                infomemtoupdate = updateInfoMemGyroRate(infomem: infomem, gyroRate:0x9B)
            }else if(samplingRate <= 102.56){
                infomemtoupdate = updateInfoMemGyroRate(infomem: infomem, gyroRate:0x4D)
            }else if(samplingRate <= 129.03){
                infomemtoupdate = updateInfoMemGyroRate(infomem: infomem, gyroRate:0x3D)
            }else if(samplingRate <= 173.91){
                infomemtoupdate = updateInfoMemGyroRate(infomem: infomem, gyroRate:0x2D)
            }else if(samplingRate <= 205.13){
                infomemtoupdate = updateInfoMemGyroRate(infomem: infomem, gyroRate:0x26)
            }else if(samplingRate <= 258.06){
                infomemtoupdate = updateInfoMemGyroRate(infomem: infomem, gyroRate:0x1E)
            }else if(samplingRate <= 533.33){
                infomemtoupdate = updateInfoMemGyroRate(infomem: infomem, gyroRate:0xE)
            }else{
                infomemtoupdate = updateInfoMemGyroRate(infomem: infomem, gyroRate:6)
            }
        }else{
            infomemtoupdate = updateInfoMemGyroRate(infomem: infomem, gyroRate:0xFF)
        }
            
        return infomemtoupdate
    }
    
    public func updateInfoMemGyroRate(infomem: [UInt8],gyroRate: UInt8) -> [UInt8]{
        var infomemtoupdate = infomem

        print("oriinfomem : \(infomemtoupdate)")

        let orivalue = infomemtoupdate[ConfigByteLayoutShimmer3.idxConfigSetupByte1]
        let value = infomemtoupdate[ConfigByteLayoutShimmer3.idxConfigSetupByte1] & ~UInt8(ConfigByteLayoutShimmer3.maskMPU9150AccelGyroSamplingRate<<ConfigByteLayoutShimmer3.bitShiftMPU9150AccelGyroSamplingRate)
        let rate = UInt8(gyroRate<<ConfigByteLayoutShimmer3.bitShiftMPU9150AccelGyroSamplingRate)
        
        print("orivalue range : \(orivalue)")
        print("value : \(value)")
        print("rate : \(rate)")

        infomemtoupdate[ConfigByteLayoutShimmer3.idxConfigSetupByte1] = value | rate
        
        return infomemtoupdate
    }
}
