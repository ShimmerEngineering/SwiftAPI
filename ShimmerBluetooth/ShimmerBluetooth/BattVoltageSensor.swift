//
//  BattVoltageSensor.swift
//  ShimmerBluetooth
//
//  Created by Shimmer Engineering on 21/02/2024.
//

import Foundation

public class BattVoltageSensor: Sensor , SensorProcessing{
    public static let BATTERY = "Battery"
    public static let BATTERY_PERCENTAGE = "Battery Percentage"

    public func processData(sensorPacket: [UInt8], objectCluster: ObjectCluster) -> ObjectCluster {
        let battery = Array(sensorPacket[3..<5])
        let rawBattery = Double(ShimmerUtilities.parseSensorData(sensorData: battery, dataType: SensorDataType.i16)!)
        
        objectCluster.addData(sensorName: BattVoltageSensor.BATTERY, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: Double(rawBattery))
        if (calibrationEnabled){
            
            let calBattery = ((rawBattery - 0) * ((3000/1)/4095)) * 2
            objectCluster.addData(sensorName: BattVoltageSensor.BATTERY, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.milliVolts.rawValue, value: Double(calBattery))
            var battVoltage = calBattery/1000
            //equations are only valid when: 3.2 < x < 4.167. Leaving a 0.2v either side just incase
            if(battVoltage > (4.167 + 0.2)){
                battVoltage = 4.167
            }else if (battVoltage < (3.2 - 0.2)){
                battVoltage = 3.2
            }
            
            // 4th order polynomial fit - good enough for purpose
            var estimatedChargePercentage = (1109.739792 * pow(battVoltage, 4)) - (17167.12674 * pow(battVoltage, 3)) + (99232.71686 * pow(battVoltage, 2)) - (253825.397 * battVoltage) + 242266.0527

            // 6th order polynomial fit - best fit -> think there is a bug with this one
            //battPercentage = -(29675.10393 * Math.pow(battVoltage, 6)) + (675893.9095 * Math.pow(battVoltage, 5)) - (6404308.2798 * Math.pow(battVoltage, 4)) + (32311485.5704 * Math.pow(battVoltage, 3)) - (91543800.1720 * Math.pow(battVoltage, 2)) + (138081754.0880 * battVoltage) - 86624424.6584;
                        
            if(estimatedChargePercentage > 100){
                estimatedChargePercentage = 100.0
            }else if (estimatedChargePercentage < 0){
                estimatedChargePercentage = 0.0
            }
            
            if(!estimatedChargePercentage.isNaN && !estimatedChargePercentage.isInfinite){
                objectCluster.addData(sensorName: BattVoltageSensor.BATTERY_PERCENTAGE, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.percent.rawValue, value: Double(estimatedChargePercentage))
            }
            
        }
        
        return objectCluster
    }
    
    public func setInfoMom(infomem: [UInt8]) {
        var enabled = Int(infomem[ConfigByteLayoutShimmer3.idxSensors1]>>5) & 1
        if (enabled == 1){
            sensorEnabled = true
        } else {
            sensorEnabled = false
        }
    }
}
