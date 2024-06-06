//
//  IMUSensor.swift
//  ShimmerBluetooth
//
//  Created by Shimmer Engineering on 23/11/2023.
//

import Foundation

public class IMUSensor: Sensor, IMUProcessing {
    
    public static func calibrateInertialSensorData(_ data: [Double], _ AM: [[Double]], _ SM: [[Double]], _ OV: [Double]) -> [Double]? {
        /* Based on the theory outlined by Ferraris F, Grimaldi U, and Parvis M.
           in "Procedure for effortless in-field calibration of three-axis rate gyros and accelerometers" Sens. Mater. 1995; 7: 311-30.
           C = [R^(-1)] .[K^(-1)] .([U]-[B])
           where.....
           [C] -> [3 x n] Calibrated Data Matrix
           [U] -> [3 x n] Uncalibrated Data Matrix
           [B] -> [3 x n] Replicated Sensor Offset Vector Matrix
           [R^(-1)] -> [3 x 3] Inverse Alignment Matrix
           [K^(-1)] -> [3 x 3] Inverse Sensitivity Matrix
           n = Number of Samples
        */
        
        var tempdata = data
        var data2d: [[Double]] = [[data[0]], [data[1]], [data[2]]]
        var OV2d: [[Double]] = [[OV[0]], [OV[1]], [OV[2]]]
        
        let inverseAM = ShimmerUtilities.matrixInverse3x3(AM)
        let inverseSM = ShimmerUtilities.matrixInverse3x3(SM)
        let matrixResult = ShimmerUtilities.matrixMultiplication(ShimmerUtilities.matrixMultiplication(inverseAM!, inverseSM!)!, ShimmerUtilities.matrixMinus(data2d, OV2d)!)
        
        tempdata[0] = matrixResult![0][0]
        tempdata[1] = matrixResult![1][0]
        tempdata[2] = matrixResult![2][0]
        
        return tempdata
    }
    
    public func parseIMUCalibrationParameters(bytes: [UInt8]) -> ([[Double]], [[Double]], [Double]) {
        var AM = [Double](repeating: 0.0, count: 9)
        for i in 0..<9 {
            AM[i] = Double(ShimmerUtilities.parseSensorData(sensorData: [bytes[6*2 + i]], dataType: SensorDataType.i8)!) / 100.0
        }
        var alignmentMatrix: [[Double]] = [
            [AM[0], AM[1], AM[2]],
            [AM[3], AM[4], AM[5]],
            [AM[6], AM[7], AM[8]]
        ]
        
        var sensitivityMatrix: [[Double]] = [
            [Double(ShimmerUtilities.parseSensorData(sensorData: Array(bytes[6...7]), dataType: SensorDataType.i16MSB)!), 0, 0],
            [0, Double(ShimmerUtilities.parseSensorData(sensorData: Array(bytes[8...9]), dataType: SensorDataType.i16MSB)!), 0],
            [0, 0, Double(ShimmerUtilities.parseSensorData(sensorData: Array(bytes[10...11]), dataType: SensorDataType.i16MSB)!)]]
        var offsetVector: [Double] =
            [Double(ShimmerUtilities.parseSensorData(sensorData: Array(bytes[0...1]), dataType: SensorDataType.i16MSB)!),
             Double(ShimmerUtilities.parseSensorData(sensorData: Array(bytes[2...3]), dataType: SensorDataType.i16MSB)!),
             Double(ShimmerUtilities.parseSensorData(sensorData: Array(bytes[4...5]), dataType: SensorDataType.i16MSB)!)]
        return(alignmentMatrix,sensitivityMatrix,offsetVector)
    }
    

}
