//
//  PressureTempSensor.swift
//  ShimmerBluetooth
//
//  Created by Shimmer Engineering on 21/02/2024.
//

import Foundation

public class PressureTempSensor: Sensor , SensorProcessing{
    public enum Resolution: UInt8 {
            case RES_LOW = 0x0
            case RES_STANDARD = 0x1
            case RES_HIGH = 0x2
            case RES_ULTRAHIGH = 0x3
            
            public static func fromValue(_ value : UInt8) -> Resolution? {
                switch value{
                case 0:
                    return .RES_LOW
                case 1:
                    return .RES_STANDARD
                case 2:
                    return .RES_HIGH
                case 3:
                    return .RES_ULTRAHIGH
                default:
                    return nil
                }
            }
        }
        
    var CurrentResolution = Resolution.RES_LOW
    var pressureResolution = 0
    public static let TEMPERATURE = "Temperature"
    public static let PRESSURE = "Pressure"
    public static var DIG_T1 = 27504.0;         // unsigned short
    public static var DIG_T2 = 26435.0;         // signed short
    public static var DIG_T3 = -1000.0;        // signed short
    public static var DIG_P1 = 36477.0;        // unsigned short
    public static var DIG_P2 = -10685.0;        // signed short
    public static var DIG_P3 = 3024.0;            // signed short
    public static var DIG_P4 = 2855.0;            // signed short
    public static var DIG_P5 = 140.0;             // signed short
    public static var DIG_P6 = -7.0;            // signed short
    public static var DIG_P7 = 15500.0;        // signed short
    public static var DIG_P8 = -14600.0;        // signed short
    public static var DIG_P9 = 6000.0;            // signed short
    public func processData(sensorPacket: [UInt8], objectCluster: ObjectCluster) -> ObjectCluster {
        let temperature = Array(sensorPacket[3..<5])
        let pressure = Array(sensorPacket[5..<8])
        
        var rawTemperature = Double(ShimmerUtilities.parseSensorData(sensorData: temperature, dataType: SensorDataType.u16MSB)!)
        var rawPressure = Double(ShimmerUtilities.parseSensorData(sensorData: pressure, dataType: SensorDataType.u24MSB)!)
        
        objectCluster.addData(sensorName: PressureTempSensor.TEMPERATURE, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: Double(rawTemperature))
        objectCluster.addData(sensorName: PressureTempSensor.PRESSURE, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: Double(rawPressure))
        
        if (calibrationEnabled){
            //for SensorBMP280
            rawTemperature = rawTemperature * pow(2,4)
            rawPressure = rawPressure/pow(2,4)
            
            let adc_T = rawTemperature;
            let adc_P = rawPressure;

            // Returns temperature in DegC, double precision. Output value of “51.23” equals 51.23 DegC.
            // t_fine carries fine temperature as global value
            var var1 = ((adc_T)/16384.0 - PressureTempSensor.DIG_T1/1024.0) * PressureTempSensor.DIG_T2;
            var var2 = (((adc_T)/131072.0 - PressureTempSensor.DIG_T1/8192.0) * (adc_T/131072.0 - PressureTempSensor.DIG_T1/8192.0)) * PressureTempSensor.DIG_T3;
            let t_fine = var1 + var2;
            let T = t_fine / 5120.0;
            //double fTemp = T * 1.8 + 32; // Fahrenheit
            //T = T/100.0;
            // Returns pressure in Pa as double. Output value of “96386.2” equals 96386.2 Pa = 963.862 hPa
            var1 = (t_fine/2.0) - 64000.0;
            var2 = var1 * var1 * PressureTempSensor.DIG_P6 / 32768.0;
            var2 = var2 + var1 * PressureTempSensor.DIG_P5 * 2.0;
            var2 = (var2/4.0)+(PressureTempSensor.DIG_P4 * 65536.0);
            var1 = (PressureTempSensor.DIG_P3 * var1 * var1 / 524288.0 + PressureTempSensor.DIG_P2 * var1) / 524288.0;
            var1 = (1.0 + var1 / 32768.0)*PressureTempSensor.DIG_P1;
            if (var1 == 0.0) {
            //   return 0; // avoid exception caused by division by zero
            }
            var p = 1048576.0 - adc_P;
            p = (p - (var2 / 4096.0)) * 6250.0 / var1;
            var1 = PressureTempSensor.DIG_P9 * p * p / 2147483648.0;
            var2 = p * PressureTempSensor.DIG_P8 / 32768.0;
            p = p + (var1 + var2 + PressureTempSensor.DIG_P7) / 16.0;
            let calTemperature = T
            let calPressure = p
            
            
            objectCluster.addData(sensorName: PressureTempSensor.TEMPERATURE, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.degreescelcius.rawValue, value: Double(calTemperature))
            objectCluster.addData(sensorName: PressureTempSensor.PRESSURE, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.kpascal.rawValue, value: Double(calPressure/1000))
        }
        
        return objectCluster
    }
    public func parseCalParamByteArray(pressureResoRes: [UInt8]) {
        PressureTempSensor.DIG_T1 = Double((Int(pressureResoRes[0]) + (Int(pressureResoRes[1]) << 8)))
        PressureTempSensor.DIG_T2 = Double(ShimmerUtilities.calculateTwosComplement(signedData: Int((Int(pressureResoRes[2]) + (Int(pressureResoRes[3]) << 8))), bitLength: 16))
        PressureTempSensor.DIG_T3 = Double(ShimmerUtilities.calculateTwosComplement(signedData: Int((Int(pressureResoRes[4]) + (Int(pressureResoRes[5]) << 8))), bitLength: 16))
        PressureTempSensor.DIG_P1 = Double((Int(pressureResoRes[6]) + (Int(pressureResoRes[7]) << 8)))
        PressureTempSensor.DIG_P2 = Double(ShimmerUtilities.calculateTwosComplement(signedData: Int((Int(pressureResoRes[8]) + (Int(pressureResoRes[9]) << 8))), bitLength: 16))
        PressureTempSensor.DIG_P3 = Double(ShimmerUtilities.calculateTwosComplement(signedData: Int((Int(pressureResoRes[10]) + (Int(pressureResoRes[11]) << 8))), bitLength: 16))
        PressureTempSensor.DIG_P4 = Double(ShimmerUtilities.calculateTwosComplement(signedData: Int((Int(pressureResoRes[12]) + (Int(pressureResoRes[13]) << 8))), bitLength: 16))
        PressureTempSensor.DIG_P5 = Double(ShimmerUtilities.calculateTwosComplement(signedData: Int((Int(pressureResoRes[14]) + (Int(pressureResoRes[15]) << 8))), bitLength: 16))
        PressureTempSensor.DIG_P6 = Double(ShimmerUtilities.calculateTwosComplement(signedData: Int((Int(pressureResoRes[16]) + (Int(pressureResoRes[17]) << 8))), bitLength: 16))
        PressureTempSensor.DIG_P7 = Double(ShimmerUtilities.calculateTwosComplement(signedData: Int((Int(pressureResoRes[18]) + (Int(pressureResoRes[19]) << 8))), bitLength: 16))
        PressureTempSensor.DIG_P8 = Double(ShimmerUtilities.calculateTwosComplement(signedData: Int((Int(pressureResoRes[20]) + (Int(pressureResoRes[21]) << 8))), bitLength: 16))
        PressureTempSensor.DIG_P9 = Double(ShimmerUtilities.calculateTwosComplement(signedData: Int((Int(pressureResoRes[22]) + (Int(pressureResoRes[23]) << 8))), bitLength: 16))
    }
    
    public func updateInfoMemPressureResolution(infomem: [UInt8],res: Resolution) -> [UInt8]{
           var infomemtoupdate = infomem
           print("oriinfomem: \(infomemtoupdate)")
       
           var pressReso = 0
           if (res == Resolution.RES_LOW){
               pressReso = 0
           } else if (res == Resolution.RES_STANDARD){
               pressReso = 1
           } else if (res == Resolution.RES_HIGH){
               pressReso = 2
           } else if (res == Resolution.RES_ULTRAHIGH){
               pressReso = 3
           }
           let orivalue = infomemtoupdate[ConfigByteLayoutShimmer3.idxConfigSetupByte3]
           let value = infomemtoupdate[ConfigByteLayoutShimmer3.idxConfigSetupByte3] & ~UInt8(ConfigByteLayoutShimmer3.maskBMPX80PressureResolution<<ConfigByteLayoutShimmer3.bitShiftBMPX80PressureResolution)
           let resolution = UInt8(pressReso<<ConfigByteLayoutShimmer3.bitShiftBMPX80PressureResolution)
        
           print("orivalue range: \(orivalue)")
           print("value: \(value)")
           print("resolution: \(resolution)")

           infomemtoupdate[ConfigByteLayoutShimmer3.idxConfigSetupByte3] = value | resolution
           print("updatedinfomem: \(infomemtoupdate)")

           return infomemtoupdate
        
       }
        
       public func getResolution()->Resolution{
           return CurrentResolution
       }
    
    public func setInfoMom(infomem: [UInt8]) {
        var enabled = Int(infomem[ConfigByteLayoutShimmer3.idxSensors2]>>2) & 1
        if (enabled == 1){
            sensorEnabled = true
        } else {
            sensorEnabled = false
        }
        pressureResolution = (Int(infomem[ConfigByteLayoutShimmer3.idxConfigSetupByte3]>>ConfigByteLayoutShimmer3.bitShiftBMPX80PressureResolution) & ConfigByteLayoutShimmer3.maskBMPX80PressureResolution)
        
        if (pressureResolution == 0){
            CurrentResolution = Resolution.RES_LOW
        } else if (pressureResolution == 1){
            CurrentResolution = Resolution.RES_STANDARD
        } else if (pressureResolution == 2){
            CurrentResolution = Resolution.RES_HIGH
        } else if (pressureResolution == 3){
            CurrentResolution = Resolution.RES_ULTRAHIGH
        }
    }
    
}
