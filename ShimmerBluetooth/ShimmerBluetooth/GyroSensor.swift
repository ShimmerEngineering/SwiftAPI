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
    
    var CurrentRange = Range.RANGE_250DPS
    
    public var packetIndexGyroX:Int = -1
    public var packetIndexGyroY:Int = -1
    public var packetIndexGyroZ:Int = -1
    public static let GYROSCOPE_X = "Gyroscope X"
    public static let GYROSCOPE_Y = "Gyroscope Y"
    public static let GYROSCOPE_Z = "Gyroscope Z"
    let CALIBRATION_ID = 30
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
    var gyroRange = 1
    var AlignmentMatrix : [[Double]] = [[]]
    var SensitivityMatrix : [[Double]] = [[]]
    var OffsetVector : [Double] = []
    
    public func processData(sensorPacket: [UInt8], objectCluster: ObjectCluster) -> ObjectCluster {
        let x = Array(sensorPacket[packetIndexGyroX..<packetIndexGyroX+2])
        let y = Array(sensorPacket[packetIndexGyroY..<packetIndexGyroY+2])
        let z = Array(sensorPacket[packetIndexGyroZ..<packetIndexGyroZ+2])
        let rawDataX = Double(ShimmerUtilities.parseSensorData(sensorData: x, dataType: SensorDataType.i16MSB)!)
        let rawDataY = Double(ShimmerUtilities.parseSensorData(sensorData: y, dataType: SensorDataType.i16MSB)!)
        let rawDataZ = Double(ShimmerUtilities.parseSensorData(sensorData: z, dataType: SensorDataType.i16MSB)!)
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
        var sensorID = Int(bytes[0]) + (Int(bytes[1])<<8)
        if bytes[0] == CALIBRATION_ID {
            var range = bytes[2]
            var calbytes = bytes
            calbytes.removeFirst(12)
            if range==0{
                (AlignmentMatrix_250DPS,SensitivityMatrix_250DPS,OffsetVector_250DPS) = parseIMUCalibrationParameters(bytes: calbytes)
                SensitivityMatrix_250DPS = ShimmerUtilities.divideMatrixElements(SensitivityMatrix_250DPS, 100)
            }
            if range==1{
                (AlignmentMatrix_500DPS,SensitivityMatrix_500DPS,OffsetVector_500DPS) = parseIMUCalibrationParameters(bytes: calbytes)
                SensitivityMatrix_500DPS = ShimmerUtilities.divideMatrixElements(SensitivityMatrix_500DPS, 100)
            }
            if range==2{
                (AlignmentMatrix_1000DPS,SensitivityMatrix_1000DPS,OffsetVector_1000DPS) = parseIMUCalibrationParameters(bytes: calbytes)
                SensitivityMatrix_1000DPS = ShimmerUtilities.divideMatrixElements(SensitivityMatrix_1000DPS, 100)
            }
            if range==3{
                (AlignmentMatrix_2000DPS,SensitivityMatrix_2000DPS,OffsetVector_2000DPS) = parseIMUCalibrationParameters(bytes: calbytes)
                SensitivityMatrix_2000DPS = ShimmerUtilities.divideMatrixElements(SensitivityMatrix_2000DPS, 100)
            }
            
        }
    }
    
    public func updateInfoMemGyroRange(infomem: [UInt8],range: Range) -> [UInt8]{
        var infomemtoupdate = infomem
        print("oriinfomem: \(infomemtoupdate)")
        if(HardwareVersion == Shimmer3Protocol.HardwareType.Shimmer3.rawValue){
            var gyroRange = 0
            if (range == Range.RANGE_250DPS){
                gyroRange = 0
            } else if (range == Range.RANGE_500DPS){
                gyroRange = 1
            } else if (range == Range.RANGE_1000DPS){
                gyroRange = 2
            } else if (range == Range.RANGE_2000DPS){
                gyroRange = 3
            }
            let orivalue = infomemtoupdate[ConfigByteLayoutShimmer3.idxConfigSetupByte2]
            let value = infomemtoupdate[ConfigByteLayoutShimmer3.idxConfigSetupByte2] & ~UInt8(ConfigByteLayoutShimmer3.maskMPU9150GyroRange<<ConfigByteLayoutShimmer3.bitShiftMPU9150GyroRange)
            let range = UInt8(gyroRange<<ConfigByteLayoutShimmer3.bitShiftMPU9150GyroRange)
         
            print("orivalue range: \(orivalue)")
            print("value: \(value)")
            print("range: \(range)")

            infomemtoupdate[ConfigByteLayoutShimmer3.idxConfigSetupByte2] = value | range
            print("updatedinfomem: \(infomemtoupdate)")
        }
       
        return infomemtoupdate
     
    }
     
    public func getRange()->Range{
        return CurrentRange
    }
    
    public func setInfoMem(infomem: [UInt8]) {
        
        var enabled = Int(infomem[ConfigByteLayoutShimmer3.idxSensors0]>>6) & 1
        if (enabled == 1){
            sensorEnabled = true
        } else {
            sensorEnabled = false
        }
        
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
