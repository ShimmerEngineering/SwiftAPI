//
//  GSRSensor.swift
//  ShimmerBluetooth
//
//  Created by Shimmer Engineering on 22/11/2023.
//

import Foundation

public class GSRSensor: Sensor , SensorProcessing{
    
    public var packetIndex:Int = -1
    public var gsrRange:Int = -1
    public static let GSR = "GSR"
    public static let SHIMMER3_GSR_REF_RESISTORS_KOHMS:[Double] = [
                40.200,     //Range 0
                287.000,     //Range 1
                1000.000,     //Range 2
                3300.000];  //Range 3
    // Equation breaks down below 683 for range 3
    
    
    public static let SHIMMER3_GSR_RESISTANCE_MIN_MAX_KOHMS : [[Double]] = [
                [8.0, 63.0],         //Range 0
                [63.0, 220.0],         //Range 1
                [220.0, 680.0],     //Range 2
                [680.0, 4700.0]]     //Range 3
    
    public static let GSR_UNCAL_LIMIT_RANGE3:Double = 683;
    
    public func processData(sensorPacket: [UInt8], objectCluster: ObjectCluster) -> ObjectCluster {
        let x = Array(sensorPacket[packetIndex..<packetIndex+2])
        let rawDataX = Double(ShimmerUtilities.parseSensorData(sensorData: x, dataType: SensorDataType.u16)!)
        if (calibrationEnabled){
            var newGSRRange = gsrRange
            var gsrData = Double((Int(rawDataX) & 4095));
            var gsrResistanceKOhms: Double = 0
            if (gsrRange == 4)
            {
                newGSRRange = (49152 & Int(rawDataX)) >> 14;
            }
            if (gsrRange == 0 || newGSRRange == 0)
            {
                gsrResistanceKOhms = calibrateGsrDataToResistanceFromAmplifierEq(gsrData, 0);
            }
            else if (gsrRange == 1 || newGSRRange == 1)
            {
                
                gsrResistanceKOhms = calibrateGsrDataToResistanceFromAmplifierEq(gsrData, 1);
            }
            else if (gsrRange == 2 || newGSRRange == 2)
            {
                
                gsrResistanceKOhms = calibrateGsrDataToResistanceFromAmplifierEq(gsrData, 2);
            }
            else if (gsrRange == 3 || newGSRRange == 3)
            {
                
                if (gsrData < GSRSensor.GSR_UNCAL_LIMIT_RANGE3)
                {
                    gsrData = GSRSensor.GSR_UNCAL_LIMIT_RANGE3;
                }
                gsrResistanceKOhms = calibrateGsrDataToResistanceFromAmplifierEq(gsrData, 3);
            }
            print("GSR (kOhms): \(gsrResistanceKOhms)")
            objectCluster.addData(sensorName: GSRSensor.GSR, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.kiloOhms.rawValue, value: gsrResistanceKOhms)
        }
        objectCluster.addData(sensorName: GSRSensor.GSR, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: rawDataX)
        return objectCluster
    }
    
    public func setInfoMem(infomem: [UInt8]) {
        gsrRange = (Int(infomem[ConfigByteLayoutShimmer3.idxConfigSetupByte3])>>ConfigByteLayoutShimmer3.bitShiftGSRRange) & ConfigByteLayoutShimmer3.maskGSRRange
        var enabled = Int(infomem[ConfigByteLayoutShimmer3.idxSensors0]>>2) & 1
        if (enabled == 1){
            sensorEnabled = true
        } else {
            sensorEnabled = false
        }
    }
    
    func nudgeDouble(_ valToNudge: Double,_ minVal: Double,_ maxVal: Double) -> Double {
        return max(minVal, min(maxVal, valToNudge))
    }
    
    func NudgeGsrResistance(_ gsrResistanceKOhms : Double,_ gsrRangeSetting: Int) ->Double
            {
                if (gsrRangeSetting != 4)
                {
                    return nudgeDouble(gsrResistanceKOhms, GSRSensor.SHIMMER3_GSR_RESISTANCE_MIN_MAX_KOHMS[gsrRangeSetting][0], GSRSensor.SHIMMER3_GSR_RESISTANCE_MIN_MAX_KOHMS[gsrRangeSetting][1]);
                }
                return gsrResistanceKOhms;
            }
    
    func calibrateGsrDataToResistanceFromAmplifierEq(_ gsrUncalibratedData : Double, _ range : Int) -> Double
            {
                let rFeedback = GSRSensor.SHIMMER3_GSR_REF_RESISTORS_KOHMS[range];
                let volts = calibrateMspAdcChannel(gsrUncalibratedData) / 1000.0;
                let rSource = rFeedback / ((volts / 0.5) - 1.0);
                return rSource;
            }
    
    func calibrateMspAdcChannel(_ unCalData: Double) -> Double
    {
        let offset = 0.0; let vRefP = 3.0; let gain = 1.0;
        let calData = calibrateU12AdcValue(unCalData, offset, vRefP, gain);
        return calData;
    }
    

}
