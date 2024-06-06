//
//  ADCSensor.swift
//  ShimmerBluetooth
//
//  Created by Shimmer Engineering on 22/11/2023.
//

import Foundation

public class ADCSensor: Sensor, SensorProcessing {
    
    public var packetIndex:Int = -1
    public enum ADCType {
        case Shimmer3_A13
        case Shimmer3_A12
        case Shimmer3_A1
        case Shimmer3_A6
        case Shimmer3_A7
        case Shimmer3_A15

        var description: String {
            switch self {
            case .Shimmer3_A13:
                return "Internal ADC A13"
            case .Shimmer3_A12:
                return "Internal ADC A12"
            case .Shimmer3_A1:
                return "Internal ADC A1"
            case .Shimmer3_A7:
                return "External ADC A7"
            case .Shimmer3_A6:
                return "External ADC A6"
            case .Shimmer3_A15:
                return "External ADC A15"
            }
        }

        // Add any other properties or methods you might need here
    }

    public override init(){
        super.init()
    }

    public init(adc: ADCType) {
        super.init()
        self.internalADCType = adc
        self.ojcName = adc.description
    }
    
    private var internalADCType:ADCType = ADCType.Shimmer3_A13;
    private var ojcName = "Internal ADC A13"
    
    public func processData(sensorPacket: [UInt8], objectCluster: ObjectCluster) -> ObjectCluster {
        let x = Array(sensorPacket[packetIndex..<packetIndex+2])
        let rawData = Double(ShimmerUtilities.parseSensorData(sensorData: x, dataType: SensorDataType.u12)!)
        if (calibrationEnabled){
            let calData = calibrateU12AdcValue(rawData, 0, 3, 1);
            objectCluster.addData(sensorName: ojcName, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.milliVolts.rawValue, value: calData)
        }
        objectCluster.addData(sensorName: ojcName, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: rawData)
        return objectCluster
    }

    public func setInfoMem(infomem: [UInt8]) {
        
        if (self.internalADCType==ADCType.Shimmer3_A13){
            var enabled = Int(infomem[ConfigByteLayoutShimmer3.idxSensors1]) & 1
            if (enabled > 0){
                sensorEnabled = true
            } else {
                sensorEnabled = false
            }
        } else if (self.internalADCType==ADCType.Shimmer3_A12){
            var enabled = Int(infomem[ConfigByteLayoutShimmer3.idxSensors1]) & 2
            if (enabled > 0){
                sensorEnabled = true
            } else {
                sensorEnabled = false
            }
        } else if (self.internalADCType==ADCType.Shimmer3_A7){
            var enabled = Int(infomem[ConfigByteLayoutShimmer3.idxSensors0]) & 2
            if (enabled > 0){
                sensorEnabled = true
            } else {
                sensorEnabled = false
            }
        } else if (self.internalADCType==ADCType.Shimmer3_A6){
            var enabled = Int(infomem[ConfigByteLayoutShimmer3.idxSensors0]) & 1
            if (enabled > 0){
                sensorEnabled = true
            } else {
                sensorEnabled = false
            }
        } else if (self.internalADCType==ADCType.Shimmer3_A1){
            var enabled = Int(infomem[ConfigByteLayoutShimmer3.idxSensors1]) & 4
            if (enabled > 0){
                sensorEnabled = true
            } else {
                sensorEnabled = false
            }
        } else if (self.internalADCType==ADCType.Shimmer3_A15){
            var enabled = Int(infomem[ConfigByteLayoutShimmer3.idxSensors1]) & 8
            if (enabled > 0){
                sensorEnabled = true
            } else {
                sensorEnabled = false
            }
        }
        
    }
}
