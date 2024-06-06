//
//  ECGSensor.swift
//  ShimmerBluetooth
//
//  Created by Shimmer Engineering on 15/02/2024.
//

import Foundation
public class EXGSensor: Sensor , SensorProcessing{
    public enum Gain: Int {
               case GAIN_1 = 0
               case GAIN_2 = 1
               case GAIN_3 = 2
               case GAIN_4 = 3
               case GAIN_6 = 4
               case GAIN_8 = 5
               case GAIN_12 = 6
               
               public static func fromValue(_ value : UInt8) -> Gain? {
                   switch value{
                   case 0:
                       return .GAIN_1
                   case 1:
                       return .GAIN_2
                   case 2:
                       return .GAIN_3
                   case 3:
                       return .GAIN_4
                   case 4:
                       return .GAIN_6
                   case 5:
                       return .GAIN_8
                   case 6:
                       return .GAIN_12
                   default:
                       return nil
                   }
               }
        
        public static func fromGainValue(_ value : Int) -> Gain? {
            switch value{
            case 1:
                return .GAIN_1
            case 2:
                return .GAIN_2
            case 3:
                return .GAIN_3
            case 4:
                return .GAIN_4
            case 6:
                return .GAIN_6
            case 8:
                return .GAIN_8
            case 12:
                return .GAIN_12
            default:
                return nil
            }
        }
        
        
           }
           
    var CurrentGain = Gain.GAIN_1
    
    public enum Resolution : UInt8 {
        case RESOLUTION_16BIT = 0x00
        case RESOLUTION_24BIT = 0x01
        
        public static func fromValue(_ value : UInt8) -> Resolution? {
            switch value{
            case 0:
                return .RESOLUTION_16BIT
            case 1:
                return .RESOLUTION_24BIT
            default:
                return nil
            }
        }
    }
    var CurrentResolution = Resolution.RESOLUTION_16BIT

    public var packetIndex:Int = -1
    public static let EXG1_STATUS = "ECG_EMG_Status"
    public static let EXG2_STATUS = "ECG_EMG_Status2"
    public static let EXG1_CH1_24BIT = "EXG1_CH1_24Bit"
    public static let EXG1_CH2_24BIT = "EXG1_CH2_24Bit"
    public static let EXG2_CH1_24BIT = "EXG2_CH1_24Bit"
    public static let EXG2_CH2_24BIT = "EXG2_CH2_24Bit"
    public static let ECG_LL_RA_24BIT = "ECG_LL-RA_24BIT"
    public static let ECG_LA_RA_24BIT = "ECG_LA-RA_24BIT"
    public static let ECG_VX_RL_24BIT = "ECG_Vx-RL_24BIT"
    public static let ECG_LL_LA_24BIT = "ECG_LL-LA_24BIT"
    public static let EXG_TEST_CHIP1_CH1_24BIT = "TEST_CHIP1_CH1_24BIT"
    public static let EXG_TEST_CHIP1_CH2_24BIT = "TEST_CHIP1_CH2_24BIT"
    public static let EXG_TEST_CHIP2_CH1_24BIT = "TEST_CHIP2_CH1_24BIT"
    public static let EXG_TEST_CHIP2_CH2_24BIT = "TEST_CHIP2_CH2_24BIT"
    public static let EXG1_CH1_16BIT = "EXG1_CH1_16Bit"
    public static let EXG1_CH2_16BIT = "EXG1_CH2_16Bit"
    public static let EXG2_CH1_16BIT = "EXG2_CH1_16Bit"
    public static let EXG2_CH2_16BIT = "EXG2_CH2_16Bit"
    public static let ECG_LL_RA_16BIT = "ECG_LL-RA_16BIT"
    public static let ECG_LA_RA_16BIT = "ECG_LA-RA_16BIT"
    public static let ECG_VX_RL_16BIT = "ECG_Vx-RL_16BIT"
    public static let ECG_LL_LA_16BIT = "ECG_LL-LA_16BIT"
    public static let EXG_TEST_CHIP1_CH1_16BIT = "TEST_CHIP1_CH1_16BIT"
    public static let EXG_TEST_CHIP1_CH2_16BIT = "TEST_CHIP1_CH2_16BIT"
    public static let EXG_TEST_CHIP2_CH1_16BIT = "TEST_CHIP2_CH1_16BIT"
    public static let EXG_TEST_CHIP2_CH2_16BIT = "TEST_CHIP2_CH2_16BIT"
    public static let EMG_CH1_24BIT = "EMG_CH1_24BIT"
    public static let EMG_CH2_24BIT = "EMG_CH2_24BIT"
    public static let EMG_CH1_16BIT = "EMG_CH1_16BIT"
    public static let EMG_CH2_16BIT = "EMG_CH2_16BIT"
    public static let ECG_RESP_24BIT = "ECG_RESP_24BIT"
    public static let ECG_RESP_16BIT = "ECG_RESP_16BIT"
    private var isEXG1Enabled:Bool = false
    private var isEXG2Enabled:Bool = false
    var CurrentEXGMode:EXGMode = EXGMode.UNKNOWN
    private var isEXG24Bit = false;
    private var isEXG16Bit = false;
    public var exg1RegisterArray:[UInt8] = [];
    public var exg2RegisterArray:[UInt8] = [];
    public var exg1GainValue = 0
    public var exg2GainValue = 0

    public enum EXGMode {
        case ECG
        case EMG
        case TEST_SIGNAL
        case RESPIRATION
        case UNKNOWN

        var description: String {
            switch self {
            case .ECG:
                return "ECG"
            case .EMG:
                return "EMG"
            case .TEST_SIGNAL:
                return "TEST SIGNAL"
            case .RESPIRATION:
                return "RESPIRATION"
            case .UNKNOWN:
                return "UNKNOWN"
            }
        }

        // Add any other properties or methods you might need here
    }
    
    public func processData(sensorPacket: [UInt8], objectCluster: ObjectCluster) -> ObjectCluster {
            if(isEXG24Bit){
                if(isEXG1Enabled){
                    let exg1status = Array(sensorPacket[3..<4])
                    let exg1ch1 = Array(sensorPacket[4..<7])
                    let exg1ch2 = Array(sensorPacket[7..<10])
                    
                    let rawExg1Status = Double(ShimmerUtilities.parseSensorData(sensorData: exg1status, dataType: SensorDataType.u8)!)
                    let rawDataExg1Ch1 = Double(ShimmerUtilities.parseSensorData(sensorData: exg1ch1, dataType: SensorDataType.i24MSB)!)
                    let rawDataExg1Ch2 = Double(ShimmerUtilities.parseSensorData(sensorData: exg1ch2, dataType: SensorDataType.i24MSB)!)
                    
                    objectCluster.addData(sensorName: EXGSensor.EXG1_STATUS, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: Double(rawExg1Status))
                    
                    if (calibrationEnabled){
                        objectCluster.addData(sensorName: EXGSensor.EXG1_STATUS, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.noUnit.rawValue, value: Double(rawExg1Status))
                        
                        let calDataExg1Ch1 = rawDataExg1Ch1 * ((2.42 * 1000) / ((Double)(exg1GainValue)) / (pow(2, 23) - 1))
                        let calDataExg1Ch2 = rawDataExg1Ch2 * ((2.42 * 1000) / ((Double)(exg1GainValue)) / (pow(2, 23) - 1))
                        
                        if(CurrentEXGMode == EXGMode.ECG || CurrentEXGMode == EXGMode.RESPIRATION ){
                            //EXG1
                            objectCluster.addData(sensorName: EXGSensor.ECG_LL_RA_24BIT, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: rawDataExg1Ch1)
                            objectCluster.addData(sensorName: EXGSensor.ECG_LL_RA_24BIT, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.milliVolts.rawValue, value: calDataExg1Ch1)
                            
                            objectCluster.addData(sensorName: EXGSensor.ECG_LA_RA_24BIT, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: rawDataExg1Ch2)
                            objectCluster.addData(sensorName: EXGSensor.ECG_LA_RA_24BIT, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.milliVolts.rawValue, value: calDataExg1Ch2)
                            
                        }else if(CurrentEXGMode == EXGMode.EMG ){
                            //EXG1
                            objectCluster.addData(sensorName: EXGSensor.EMG_CH1_24BIT, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: rawDataExg1Ch1)
                            objectCluster.addData(sensorName: EXGSensor.EMG_CH2_24BIT, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: rawDataExg1Ch2)
                            objectCluster.addData(sensorName: EXGSensor.EMG_CH1_24BIT, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.milliVolts.rawValue, value: calDataExg1Ch1)
                            objectCluster.addData(sensorName: EXGSensor.EMG_CH2_24BIT, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.milliVolts.rawValue, value: calDataExg1Ch2)
                            
                        }else if(CurrentEXGMode == EXGMode.TEST_SIGNAL ){
                            objectCluster.addData(sensorName: EXGSensor.EXG_TEST_CHIP1_CH1_24BIT, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: rawDataExg1Ch1)
                            objectCluster.addData(sensorName: EXGSensor.EXG_TEST_CHIP1_CH2_24BIT, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: rawDataExg1Ch2)
                            objectCluster.addData(sensorName: EXGSensor.EXG_TEST_CHIP1_CH1_24BIT, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.milliVolts.rawValue, value: calDataExg1Ch1)
                            objectCluster.addData(sensorName: EXGSensor.EXG_TEST_CHIP1_CH2_24BIT, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.milliVolts.rawValue, value: calDataExg1Ch2)
                            
                        }else{
                            //EXG1
                            objectCluster.addData(sensorName: EXGSensor.EXG1_CH1_24BIT, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: rawDataExg1Ch1)
                            objectCluster.addData(sensorName: EXGSensor.EXG1_CH2_24BIT, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: rawDataExg1Ch2)
                            objectCluster.addData(sensorName: EXGSensor.EXG1_CH1_24BIT, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.milliVolts.rawValue, value: calDataExg1Ch1)
                            objectCluster.addData(sensorName: EXGSensor.EXG1_CH2_24BIT, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.milliVolts.rawValue, value: calDataExg1Ch2)
                            
                        }
                        
                        //Additional channels offset
                        
                        if(CurrentEXGMode == EXGMode.ECG || CurrentEXGMode == EXGMode.RESPIRATION ){
                            
                            objectCluster.addData(sensorName: EXGSensor.ECG_LL_LA_24BIT, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: rawDataExg1Ch1 - rawDataExg1Ch2)
                            if (calibrationEnabled){
                                objectCluster.addData(sensorName: EXGSensor.ECG_LL_LA_24BIT, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.milliVolts.rawValue, value: calDataExg1Ch1 - calDataExg1Ch2)
                            }
                        }
                    }
                    
                    }
                    
                    
                    if(isEXG2Enabled){
                        let exg2status = Array(sensorPacket[10..<11])
                        let exg2ch1 = Array(sensorPacket[11..<14])
                        let exg2ch2 = Array(sensorPacket[14..<17])
                        
                        let rawExg2Status = Double(ShimmerUtilities.parseSensorData(sensorData: exg2status, dataType: SensorDataType.u8)!)
                        let rawDataExg2Ch1 = Double(ShimmerUtilities.parseSensorData(sensorData: exg2ch1, dataType: SensorDataType.i24MSB)!)
                        let rawDataExg2Ch2 = Double(ShimmerUtilities.parseSensorData(sensorData: exg2ch2, dataType: SensorDataType.i24MSB)!)
                        
                        objectCluster.addData(sensorName: EXGSensor.EXG2_STATUS, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: Double(rawExg2Status))
                        
                        if (calibrationEnabled){
                            objectCluster.addData(sensorName: EXGSensor.EXG2_STATUS, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.noUnit.rawValue, value: Double(rawExg2Status))
                            
                            let calDataExg2Ch1 = rawDataExg2Ch1 * ((2.42 * 1000) / ((Double)(exg2GainValue)) / (pow(2, 23) - 1))
                            let calDataExg2Ch2 = rawDataExg2Ch2 * ((2.42 * 1000) / ((Double)(exg2GainValue)) / (pow(2, 23) - 1))
                            
                            if(CurrentEXGMode == EXGMode.ECG || CurrentEXGMode == EXGMode.RESPIRATION ){
                                
                                //EXG2
                                objectCluster.addData(sensorName: EXGSensor.ECG_VX_RL_24BIT, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: rawDataExg2Ch2)
                                objectCluster.addData(sensorName: EXGSensor.ECG_VX_RL_24BIT, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.milliVolts.rawValue, value: calDataExg2Ch2)
                                if(CurrentEXGMode == EXGMode.RESPIRATION ){
                                    objectCluster.addData(sensorName: EXGSensor.ECG_RESP_24BIT, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: rawDataExg2Ch1)
                                    objectCluster.addData(sensorName: EXGSensor.ECG_RESP_24BIT, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.milliVolts.rawValue, value: calDataExg2Ch1)
                                }
                            }else if(CurrentEXGMode == EXGMode.EMG ){
                                
                                //EXG2
                                objectCluster.addData(sensorName: EXGSensor.EXG2_CH1_24BIT, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: 0)
                                objectCluster.addData(sensorName: EXGSensor.EXG2_CH2_24BIT, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: 0)
                                objectCluster.addData(sensorName: EXGSensor.EXG2_CH1_24BIT, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.milliVolts.rawValue, value: 0)
                                objectCluster.addData(sensorName: EXGSensor.EXG2_CH2_24BIT, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.milliVolts.rawValue, value: 0)
                            }else if(CurrentEXGMode == EXGMode.TEST_SIGNAL){
                                
                                
                                objectCluster.addData(sensorName: EXGSensor.EXG_TEST_CHIP2_CH1_24BIT, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: rawDataExg2Ch1)
                                objectCluster.addData(sensorName: EXGSensor.EXG_TEST_CHIP2_CH2_24BIT, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: rawDataExg2Ch2)
                                objectCluster.addData(sensorName: EXGSensor.EXG_TEST_CHIP2_CH1_24BIT, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.milliVolts.rawValue, value: calDataExg2Ch1)
                                objectCluster.addData(sensorName: EXGSensor.EXG_TEST_CHIP2_CH2_24BIT, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.milliVolts.rawValue, value: calDataExg2Ch2)
                            }else{
                                
                                //EXG2
                                objectCluster.addData(sensorName: EXGSensor.EXG2_CH1_24BIT, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: rawDataExg2Ch1)
                                objectCluster.addData(sensorName: EXGSensor.EXG2_CH1_24BIT, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.milliVolts.rawValue, value: calDataExg2Ch1)
                            }
                        }
                    }
                    
                    return objectCluster
            }else{//16Bit
                if(isEXG1Enabled){
                    let exg1status = Array(sensorPacket[3..<4])
                    let exg1ch1 = Array(sensorPacket[4..<6])
                    let exg1ch2 = Array(sensorPacket[6..<8])
                    
                    let rawExg1Status = Double(ShimmerUtilities.parseSensorData(sensorData: exg1status, dataType: SensorDataType.u8)!)
                    let rawDataExg1Ch1 = Double(ShimmerUtilities.parseSensorData(sensorData: exg1ch1, dataType: SensorDataType.i16MSB)!)
                    let rawDataExg1Ch2 = Double(ShimmerUtilities.parseSensorData(sensorData: exg1ch2, dataType: SensorDataType.i16MSB)!)
                    
                    objectCluster.addData(sensorName: EXGSensor.EXG1_STATUS, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: Double(rawExg1Status))
                    
                    if (calibrationEnabled){
                        objectCluster.addData(sensorName: EXGSensor.EXG1_STATUS, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.noUnit.rawValue, value: Double(rawExg1Status))
                        
                        let calDataExg1Ch1 = rawDataExg1Ch1 * (((2.42 * 1000) / (Double)(exg1GainValue * 2)) / (pow(2, 15) - 1))
                        let calDataExg1Ch2 = rawDataExg1Ch2 * (((2.42 * 1000) / (Double)(exg1GainValue * 2)) / (pow(2, 15) - 1))
                        
                        if(CurrentEXGMode == EXGMode.ECG || CurrentEXGMode == EXGMode.RESPIRATION ){
                            //EXG1
                            objectCluster.addData(sensorName: EXGSensor.ECG_LL_RA_16BIT, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: rawDataExg1Ch1)
                            objectCluster.addData(sensorName: EXGSensor.ECG_LL_RA_16BIT, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.milliVolts.rawValue, value: calDataExg1Ch1)
                            
                            objectCluster.addData(sensorName: EXGSensor.ECG_LA_RA_16BIT, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: rawDataExg1Ch2)
                            objectCluster.addData(sensorName: EXGSensor.ECG_LA_RA_16BIT, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.milliVolts.rawValue, value: calDataExg1Ch2)
                            
                        }else if(CurrentEXGMode == EXGMode.EMG ){
                            //EXG1
                            objectCluster.addData(sensorName: EXGSensor.EMG_CH1_16BIT, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: rawDataExg1Ch1)
                            objectCluster.addData(sensorName: EXGSensor.EMG_CH2_16BIT, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: rawDataExg1Ch2)
                            objectCluster.addData(sensorName: EXGSensor.EMG_CH1_16BIT, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.milliVolts.rawValue, value: calDataExg1Ch1)
                            objectCluster.addData(sensorName: EXGSensor.EMG_CH2_16BIT, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.milliVolts.rawValue, value: calDataExg1Ch2)
                            
                        }else if(CurrentEXGMode == EXGMode.TEST_SIGNAL){
                            objectCluster.addData(sensorName: EXGSensor.EXG_TEST_CHIP1_CH1_16BIT, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: rawDataExg1Ch1)
                            objectCluster.addData(sensorName: EXGSensor.EXG_TEST_CHIP1_CH2_16BIT, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: rawDataExg1Ch2)
                            objectCluster.addData(sensorName: EXGSensor.EXG_TEST_CHIP1_CH1_16BIT, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.milliVolts.rawValue, value: calDataExg1Ch1)
                            objectCluster.addData(sensorName: EXGSensor.EXG_TEST_CHIP1_CH2_16BIT, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.milliVolts.rawValue, value: calDataExg1Ch2)
                            
                        }else{
                            //EXG1
                            objectCluster.addData(sensorName: EXGSensor.EXG1_CH1_16BIT, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: rawDataExg1Ch1)
                            objectCluster.addData(sensorName: EXGSensor.EXG1_CH2_16BIT, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: rawDataExg1Ch2)
                            objectCluster.addData(sensorName: EXGSensor.EXG1_CH1_16BIT, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.milliVolts.rawValue, value: calDataExg1Ch1)
                            objectCluster.addData(sensorName: EXGSensor.EXG1_CH2_16BIT, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.milliVolts.rawValue, value: calDataExg1Ch2)
                            
                        }
                        
                        //Additional channels offset
                        
                        if(CurrentEXGMode == EXGMode.ECG || CurrentEXGMode == EXGMode.RESPIRATION ){
                            
                            objectCluster.addData(sensorName: EXGSensor.ECG_LL_LA_16BIT, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: rawDataExg1Ch1 - rawDataExg1Ch2)
                            if (calibrationEnabled){
                                objectCluster.addData(sensorName: EXGSensor.ECG_LL_LA_16BIT, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.milliVolts.rawValue, value: calDataExg1Ch1 - calDataExg1Ch2)
                            }
                        }
                    }
                    
                    }
                    
                    
                    if(isEXG2Enabled){
                        let exg2status = Array(sensorPacket[8..<9])
                        let exg2ch1 = Array(sensorPacket[9..<11])
                        let exg2ch2 = Array(sensorPacket[11..<13])
                        
                        let rawExg2Status = Double(ShimmerUtilities.parseSensorData(sensorData: exg2status, dataType: SensorDataType.u8)!)
                        let rawDataExg2Ch1 = Double(ShimmerUtilities.parseSensorData(sensorData: exg2ch1, dataType: SensorDataType.i16MSB)!)
                        let rawDataExg2Ch2 = Double(ShimmerUtilities.parseSensorData(sensorData: exg2ch2, dataType: SensorDataType.i16MSB)!)
                        
                        objectCluster.addData(sensorName: EXGSensor.EXG2_STATUS, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: Double(rawExg2Status))
                        
                        if (calibrationEnabled){
                            objectCluster.addData(sensorName: EXGSensor.EXG2_STATUS, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.noUnit.rawValue, value: Double(rawExg2Status))
                            
                            let calDataExg2Ch1 = rawDataExg2Ch1 * (((2.42 * 1000) / (Double)(exg2GainValue * 2))  / (pow(2, 15) - 1))
                            let calDataExg2Ch2 = rawDataExg2Ch2 * (((2.42 * 1000) / (Double)(exg2GainValue * 2))  / (pow(2, 15) - 1))
                            
                            if(CurrentEXGMode == EXGMode.ECG || CurrentEXGMode == EXGMode.RESPIRATION ){
                                
                                //EXG2
                                objectCluster.addData(sensorName: EXGSensor.ECG_VX_RL_16BIT, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: rawDataExg2Ch2)
                                objectCluster.addData(sensorName: EXGSensor.ECG_VX_RL_16BIT, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.milliVolts.rawValue, value: calDataExg2Ch2)
                                if(CurrentEXGMode == EXGMode.RESPIRATION ){
                                    objectCluster.addData(sensorName: EXGSensor.ECG_RESP_16BIT, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: rawDataExg2Ch1)
                                    objectCluster.addData(sensorName: EXGSensor.ECG_RESP_16BIT, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.milliVolts.rawValue, value: calDataExg2Ch1)
                                }
                            }else if(CurrentEXGMode == EXGMode.EMG){
                                
                                //EXG2
                                objectCluster.addData(sensorName: EXGSensor.EXG2_CH1_16BIT, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: 0)
                                objectCluster.addData(sensorName: EXGSensor.EXG2_CH2_16BIT, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: 0)
                                objectCluster.addData(sensorName: EXGSensor.EXG2_CH1_16BIT, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.milliVolts.rawValue, value: 0)
                                objectCluster.addData(sensorName: EXGSensor.EXG2_CH2_16BIT, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.milliVolts.rawValue, value: 0)
                            }else if(CurrentEXGMode == EXGMode.TEST_SIGNAL){
                                
                                
                                objectCluster.addData(sensorName: EXGSensor.EXG_TEST_CHIP2_CH1_16BIT, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: rawDataExg2Ch1)
                                objectCluster.addData(sensorName: EXGSensor.EXG_TEST_CHIP2_CH2_16BIT, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: rawDataExg2Ch2)
                                objectCluster.addData(sensorName: EXGSensor.EXG_TEST_CHIP2_CH1_16BIT, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.milliVolts.rawValue, value: calDataExg2Ch1)
                                objectCluster.addData(sensorName: EXGSensor.EXG_TEST_CHIP2_CH2_16BIT, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.milliVolts.rawValue, value: calDataExg2Ch2)
                            }else{
                                
                                //EXG2
                                objectCluster.addData(sensorName: EXGSensor.EXG2_CH1_16BIT, formatName: SensorFormats.Raw.rawValue, unitName: SensorUnits.noUnit.rawValue, value: rawDataExg2Ch1)
                                objectCluster.addData(sensorName: EXGSensor.EXG2_CH1_16BIT, formatName: SensorFormats.Calibrated.rawValue, unitName: SensorUnits.milliVolts.rawValue, value: calDataExg2Ch1)
                            }
                        }
                    }
                    
                    return objectCluster
            }
        }
 
    public func convertEcgGainSettingToValue(setting: Int) -> Int {
        let settingInHexString = String(setting, radix: 16)
        var gain = -1
        if(settingInHexString.isEqual("0")){
            gain = 6
        }else if(settingInHexString.isEqual("10")){
            gain = 1
        }else if(settingInHexString.isEqual("20")){
            gain = 2
        }else if(settingInHexString.isEqual("30")){
            gain = 3
        }else if(settingInHexString.isEqual("40")){
            gain = 4
        }else if(settingInHexString.isEqual("50")){
            gain = 8
        }else if(settingInHexString.isEqual("60")){
            gain = 12
        }
        return gain
    }
    
    public func convertEmgGainSettingToValue(setting: Int) -> Int {
        let settingInHexString = String(setting, radix: 16)
        var gain = -1
        if(settingInHexString.isEqual("9")){
            gain = 6
        }else if(settingInHexString.isEqual("19")){
            gain = 1
        }else if(settingInHexString.isEqual("29")){
            gain = 2
        }else if(settingInHexString.isEqual("39")){
            gain = 3
        }else if(settingInHexString.isEqual("49")){
            gain = 4
        }else if(settingInHexString.isEqual("59")){
            gain = 8
        }else if(settingInHexString.isEqual("69")){
            gain = 12
        }
        return gain
    }
    public func convertTestGainSettingToValue(setting: Int) -> Int {
        let settingInHexString = String(setting, radix: 16)
        var gain = -1
        if(settingInHexString.isEqual("5")){
            gain = 6
        }else if(settingInHexString.isEqual("15")){
            gain = 1
        }else if(settingInHexString.isEqual("25")){
            gain = 2
        }else if(settingInHexString.isEqual("35")){
            gain = 3
        }else if(settingInHexString.isEqual("45")){
            gain = 4
        }else if(settingInHexString.isEqual("55")){
            gain = 8
        }else if(settingInHexString.isEqual("65")){
            gain = 12
        }
        return gain
    }
        
    public func setInfoMem(infomem: [UInt8]) {
        
        var isEXG24Bit = Int(infomem[ConfigByteLayoutShimmer3.idxSensors0]>>4) & 1
        var isEXG16Bit = Int(infomem[ConfigByteLayoutShimmer3.idxSensors2]>>4) & 1
        
        if (isEXG24Bit == 1){
            self.isEXG24Bit = true
        } else {
            self.isEXG24Bit = false
        }
        
        if (isEXG16Bit == 1){
            self.isEXG16Bit = true
        } else {
            self.isEXG16Bit = false
        }
        
        if (isEXG24Bit == 1 || isEXG16Bit == 1){
            sensorEnabled = true
            isEXG1Enabled = true
        } else {
            sensorEnabled = false
            isEXG1Enabled = false
        }
        
        
        var exg2_24Bit = Int(infomem[ConfigByteLayoutShimmer3.idxSensors0]>>3) & 1
        var exg2_16Bit = Int(infomem[ConfigByteLayoutShimmer3.idxSensors2]>>3) & 1
        if (exg2_24Bit == 1 || exg2_16Bit == 1){
            //sensorEnabled = true
            isEXG2Enabled = true
        } else {
            //sensorEnabled = false
            isEXG2Enabled = false
        }
        
        exg1RegisterArray = Array(infomem[10..<20])
        exg2RegisterArray = Array(infomem[20..<30])
        
        CurrentEXGMode = EXGMode.UNKNOWN
        
        if(((exg1RegisterArray[3] & 0x0F)==5)
           && ((exg1RegisterArray[4] & 0x0F)==5)
           && ((exg2RegisterArray[3] & 0x0F)==5)
           && ((exg2RegisterArray[4] & 0x0F)==5)){
            CurrentEXGMode = EXGMode.TEST_SIGNAL
        } else {
        }
        
        if(((exg1RegisterArray[3] & 0x0F)==9)
           && ((exg1RegisterArray[4] & 0x0F)==0)
           && ((exg2RegisterArray[3] & 0x0F)==1)
           && ((exg2RegisterArray[4] & 0x0F)==1)){
            CurrentEXGMode = EXGMode.EMG
        } else {
        }
        
        if(((exg1RegisterArray[3] & 0x0F)==0)
           && ((exg1RegisterArray[4] & 0x0F)==0)
           && ((exg2RegisterArray[3] & 0x0F)==0)
           && ((exg2RegisterArray[4] & 0x0F)==7)){
            CurrentEXGMode = EXGMode.ECG
        }
        
        if(((exg1RegisterArray[3] & 0x0F)==0)
           && ((exg1RegisterArray[4] & 0x0F)==0)
           && ((exg2RegisterArray[3] & 0x0F)==0)
           && ((exg2RegisterArray[8] & 0xEA)==0xEA)){
            CurrentEXGMode = EXGMode.RESPIRATION
        }
        

        let exg1GainSetting = exg1RegisterArray[3]
        let exg2GainSetting = exg2RegisterArray[3]
        
        let resByte0InHexString = String(infomem[ConfigByteLayoutShimmer3.idxSensors0], radix: 16)

        if(CurrentEXGMode == EXGMode.EMG){
            exg1GainValue = convertEmgGainSettingToValue(setting: Int(exg1GainSetting))
            if(resByte0InHexString.isEqual("0")){
                CurrentResolution = Resolution.RESOLUTION_16BIT
            }else if(resByte0InHexString.isEqual("10")){
                CurrentResolution = Resolution.RESOLUTION_24BIT
            }
        }else{
            if(resByte0InHexString.isEqual("0")){
                CurrentResolution = Resolution.RESOLUTION_16BIT
            }else if(resByte0InHexString.isEqual("18")){
                CurrentResolution = Resolution.RESOLUTION_24BIT
            }
            
            if(CurrentEXGMode == EXGMode.ECG || CurrentEXGMode == EXGMode.RESPIRATION){
                exg1GainValue = convertEcgGainSettingToValue(setting: Int(exg1GainSetting))
                exg2GainValue = convertEcgGainSettingToValue(setting: Int(exg2GainSetting))
            }else if(CurrentEXGMode == EXGMode.TEST_SIGNAL){
                exg1GainValue = convertTestGainSettingToValue(setting: Int(exg1GainSetting))
                exg2GainValue = convertTestGainSettingToValue(setting: Int(exg2GainSetting))
            }
            
            if (exg1GainValue==exg2GainValue){
                if (exg1GainValue>0){
                    CurrentGain = Gain.fromGainValue(exg1GainValue)!
                }
            }
        }
    }
    
    public func updateInfoMemExgResolution(infomem: [UInt8],resolution: Resolution) -> [UInt8]{
        var infomemtoupdate = infomem
        let exgResolutionToSet = resolution
        print("oriinfomem: \(infomemtoupdate)")

        var ecgResBytesToUpdate: [UInt8] = [0x00, 0x00, 0x00]

        if(CurrentEXGMode == EXGMode.EMG){
            if (exgResolutionToSet == Resolution.RESOLUTION_16BIT){
                ecgResBytesToUpdate = [0x00, 0x00, 0x10]
            }else{
                ecgResBytesToUpdate = [0x10, 0x00, 0x00]
            }
        }else{
            if (exgResolutionToSet == Resolution.RESOLUTION_16BIT){
                ecgResBytesToUpdate = [0x00, 0x00, 0x18]
            }else{
                ecgResBytesToUpdate = [0x18, 0x00, 0x00]
            }
        }
        
        infomemtoupdate[ConfigByteLayoutShimmer3.idxSensors0] = ecgResBytesToUpdate[0]
        infomemtoupdate[ConfigByteLayoutShimmer3.idxSensors1] = ecgResBytesToUpdate[1]
        infomemtoupdate[ConfigByteLayoutShimmer3.idxSensors2] = ecgResBytesToUpdate[2]
        
        print("updatedinfomem: \(infomemtoupdate)")
        
        return infomemtoupdate
        
    }
    public func updateInfoMemExgGain(infomem: [UInt8],gain: Gain) -> [UInt8]{
        var infomemtoupdate = infomem
        let exgGainToSet = gain
        print("oriinfomem: \(infomemtoupdate)")
       
      
        if(CurrentEXGMode == EXGMode.ECG){
            infomemtoupdate = getUpdatedEcgGainInfomem(infomem: infomemtoupdate, gain: exgGainToSet)
        }else if(CurrentEXGMode == EXGMode.RESPIRATION){
            infomemtoupdate = getUpdatedRespGainInfomem(infomem: infomemtoupdate, gain: exgGainToSet)
        }else if(CurrentEXGMode == EXGMode.EMG){
            infomemtoupdate = getUpdatedEmgGainInfomem(infomem: infomemtoupdate, gain: exgGainToSet)
        }else if(CurrentEXGMode == EXGMode.TEST_SIGNAL){
            infomemtoupdate = getUpdatedTestGainInfomem(infomem: infomemtoupdate, gain: exgGainToSet)
        }
        print("updatedinfomem: \(infomemtoupdate)")

        return infomemtoupdate
        
       }
    
    public func getUpdatedEcgGainInfomem(infomem: [UInt8], gain: Gain) -> [UInt8]{
        var infomemtoupdate = infomem
        var ecgGainBytesToUpdate: [UInt8] = [0x00, 0x00, 0x00, 0x00]
        if (gain == Gain.GAIN_1){
            ecgGainBytesToUpdate = [0x10, 0x10, 0x10, 0x17]
        } else if (gain == Gain.GAIN_2){
            ecgGainBytesToUpdate  = [0x20, 0x20, 0x20, 0x27]
        } else if (gain == Gain.GAIN_3){
            ecgGainBytesToUpdate  = [0x30, 0x30, 0x30, 0x37]
        } else if (gain == Gain.GAIN_4){
            ecgGainBytesToUpdate  = [0x40, 0x40, 0x40, 0x47]
        } else if (gain == Gain.GAIN_6){
            ecgGainBytesToUpdate  = [0x00, 0x00, 0x00, 0x07]
        } else if (gain == Gain.GAIN_8){
            ecgGainBytesToUpdate  = [0x50, 0x50, 0x50, 0x57]
        } else if (gain == Gain.GAIN_12){
            ecgGainBytesToUpdate  = [0x60, 0x60, 0x60, 0x67]
        }

        infomemtoupdate[ConfigByteLayoutShimmer3.idxEXGADS1292RChip1Ch1Set] = ecgGainBytesToUpdate[0]
        infomemtoupdate[ConfigByteLayoutShimmer3.idxEXGADS1292RChip1Ch2Set] = ecgGainBytesToUpdate[1]
        infomemtoupdate[ConfigByteLayoutShimmer3.idxEXGADS1292RChip2Ch1Set] = ecgGainBytesToUpdate[2]
        infomemtoupdate[ConfigByteLayoutShimmer3.idxEXGADS1292RChip2Ch2Set] = ecgGainBytesToUpdate[3]

        return infomemtoupdate
    }
    public func getUpdatedEmgGainInfomem(infomem: [UInt8],gain: Gain) -> [UInt8]{
        var infomemtoupdate = infomem
        var emgGainBytesToUpdate: [UInt8] = [0x00, 0x00, 0x00, 0x00]
        if (gain == Gain.GAIN_1){
            emgGainBytesToUpdate = [0x19, 0x10, 0x91, 0x91]
        } else if (gain == Gain.GAIN_2){
            emgGainBytesToUpdate  = [0x29, 0x20, 0xA1, 0xA1]
        } else if (gain == Gain.GAIN_3){
            emgGainBytesToUpdate  = [0x39, 0x30, 0xB1, 0xB1]
        } else if (gain == Gain.GAIN_4){
            emgGainBytesToUpdate  = [0x49, 0x40, 0xC1, 0xC1]
        } else if (gain == Gain.GAIN_6){
            emgGainBytesToUpdate  = [0x09, 0x00, 0x81, 0x81]
        } else if (gain == Gain.GAIN_8){
            emgGainBytesToUpdate  = [0x59, 0x50, 0xD1, 0xD1]
        } else if (gain == Gain.GAIN_12){
            emgGainBytesToUpdate  = [0x69, 0x60, 0xE1, 0xE1]
        }

        infomemtoupdate[ConfigByteLayoutShimmer3.idxEXGADS1292RChip1Ch1Set] = emgGainBytesToUpdate[0]
        infomemtoupdate[ConfigByteLayoutShimmer3.idxEXGADS1292RChip1Ch2Set] = emgGainBytesToUpdate[1]
        infomemtoupdate[ConfigByteLayoutShimmer3.idxEXGADS1292RChip2Ch1Set] = emgGainBytesToUpdate[2]
        infomemtoupdate[ConfigByteLayoutShimmer3.idxEXGADS1292RChip2Ch2Set] = emgGainBytesToUpdate[3]

        return infomemtoupdate
    }
    public func getUpdatedRespGainInfomem(infomem: [UInt8],gain: Gain) -> [UInt8]{
        var infomemtoupdate = infomem
        var respGainBytesToUpdate: [UInt8] = [0x00]
        if (gain == Gain.GAIN_1){
            respGainBytesToUpdate = [0x10]
        } else if (gain == Gain.GAIN_2){
            respGainBytesToUpdate  = [0x20]
        } else if (gain == Gain.GAIN_3){
            respGainBytesToUpdate  = [0x30]
        } else if (gain == Gain.GAIN_4){
            respGainBytesToUpdate  = [0x40]
        } else if (gain == Gain.GAIN_6){
            respGainBytesToUpdate  = [0x00]
        } else if (gain == Gain.GAIN_8){
            respGainBytesToUpdate  = [0x50]
        } else if (gain == Gain.GAIN_12){
            respGainBytesToUpdate  = [0x60]
        }

        infomemtoupdate[ConfigByteLayoutShimmer3.idxEXGADS1292RChip1Ch1Set] = respGainBytesToUpdate[0]
        infomemtoupdate[ConfigByteLayoutShimmer3.idxEXGADS1292RChip1Ch2Set] = respGainBytesToUpdate[0]
        infomemtoupdate[ConfigByteLayoutShimmer3.idxEXGADS1292RChip2Ch1Set] = respGainBytesToUpdate[0]
        infomemtoupdate[ConfigByteLayoutShimmer3.idxEXGADS1292RChip2Ch2Set] = respGainBytesToUpdate[0]

        return infomemtoupdate
    }
    public func getUpdatedTestGainInfomem(infomem: [UInt8],gain: Gain) -> [UInt8]{
        var infomemtoupdate = infomem
        var testGainBytesToUpdate: [UInt8] = [0x00]
        if (gain == Gain.GAIN_1){
            testGainBytesToUpdate = [0x15]
        } else if (gain == Gain.GAIN_2){
            testGainBytesToUpdate  = [0x25]
        } else if (gain == Gain.GAIN_3){
            testGainBytesToUpdate  = [0x35]
        } else if (gain == Gain.GAIN_4){
            testGainBytesToUpdate  = [0x45]
        } else if (gain == Gain.GAIN_6){
            testGainBytesToUpdate  = [0x05]
        } else if (gain == Gain.GAIN_8){
            testGainBytesToUpdate  = [0x55]
        } else if (gain == Gain.GAIN_12){
            testGainBytesToUpdate  = [0x65]
        }

        infomemtoupdate[ConfigByteLayoutShimmer3.idxEXGADS1292RChip1Ch1Set] = testGainBytesToUpdate[0]
        infomemtoupdate[ConfigByteLayoutShimmer3.idxEXGADS1292RChip1Ch2Set] = testGainBytesToUpdate[0]
        infomemtoupdate[ConfigByteLayoutShimmer3.idxEXGADS1292RChip2Ch1Set] = testGainBytesToUpdate[0]
        infomemtoupdate[ConfigByteLayoutShimmer3.idxEXGADS1292RChip2Ch2Set] = testGainBytesToUpdate[0]

        return infomemtoupdate
    }

        
    public func getGain()->Gain{
        return CurrentGain
    }
    
    public func getResolution()->Resolution{
        return CurrentResolution
    }
    
    public func updateInfoMemExgRate(infomem: [UInt8], samplingRateFreq: Double) -> [UInt8]{
        var infomemtoupdate = infomem
        var exgRate = UInt8(0)
        if(samplingRateFreq <= 125){
            exgRate = UInt8(0)
        }else if(samplingRateFreq <= 250){
            exgRate = UInt8(1)
        }else if(samplingRateFreq <= 500){
            exgRate = UInt8(2)
        }else if(samplingRateFreq <= 1000){
            exgRate = UInt8(3)
        }else if(samplingRateFreq <= 2000){
            exgRate = UInt8(4)
        }else if(samplingRateFreq <= 4000){
            exgRate = UInt8(5)
        }else{
            exgRate = UInt8(6)
        }
        var exg1ar1 = (exg1RegisterArray[0]) & 0xF8
        exg1ar1 = exg1ar1|exgRate
        var exg2ar1 = (exg2RegisterArray[0]) & 0xF8
        exg2ar1 = exg2ar1|exgRate

        infomemtoupdate[ConfigByteLayoutShimmer3.idxEXGADS1292RChip1Config1] = exg1ar1
        infomemtoupdate[ConfigByteLayoutShimmer3.idxEXGADS1292RChip2Config1] = exg2ar1

        return infomemtoupdate
    }
    
    public func updateExgRateConfig(samplingRateFreq: Double)-> [UInt8]{
        
        var exgRate = 0
        var buff = [UInt8]()
        
        if(samplingRateFreq <= 125){
            exgRate = 0
        }else if(samplingRateFreq <= 250){
            exgRate = 1
        }else if(samplingRateFreq <= 500){
            exgRate = 2
        }else if(samplingRateFreq <= 1000){
            exgRate = 3
        }else if(samplingRateFreq <= 2000){
            exgRate = 4
        }else if(samplingRateFreq <= 4000){
            exgRate = 5
        }else{
            exgRate = 6
        }
        
        var exg1ar1 = (exg1RegisterArray[0]) & 0xF8
        exg1ar1 = exg1ar1|UInt8(exgRate)
        var exg2ar1 = (exg2RegisterArray[0]) & 0xF8
        exg2ar1 = exg2ar1|UInt8(exgRate)
        
        buff.append(exg1ar1)
        buff.append(exg2ar1)
        return buff
    }
}
