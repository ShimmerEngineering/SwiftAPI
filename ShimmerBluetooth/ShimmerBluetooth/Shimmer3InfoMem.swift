//
//  Shimmer3InfoMem.swift
//  ShimmerBluetooth
//
//  Created by Shimmer Engineering on 02/11/2023.
//

import Foundation

public class Shimmer3InfoMem {
    
    var mTCX0 = 0
    
    static func convertSamplingRateBytesToFreq(samplingRateLSB: UInt8, samplingRateMSB: UInt8, samplingClockFreq: Double) -> Double {
        let srValue = Double(samplingRateLSB) + Double(UInt16(samplingRateMSB) << 8)
        let samplingRate = samplingClockFreq / srValue
        return samplingRate
    }
    
    /**
     * @return the mTCXO
     */
    private func isTCXO() -> Bool? {
        //return (this.mTCXO > 0)? true:false;
        if (mTCX0>0){
            return true
        }
        return false
    }
    
    public func getSamplingClockFreq() -> Double {
        if(isTCXO()!){
            /* probably not required for now
            if(isTcxoClock20MHz()){
                //20MHz / 64 = 312500;
                return 312500.0;
            } else {
                //16.369MHz / 64 = 255765.625;
                return 255765.625;
            }
             */
            return 255765.625;
        } else {
            return 32768.0;
        }
    }
    
    public func configByteParse(configBytes:[UInt8]){
        let samplingRateMSB = configBytes[ConfigByteLayoutShimmer3.idxShimmerSamplingRate+1];
        let samplingRateLSB = configBytes[ConfigByteLayoutShimmer3.idxShimmerSamplingRate];
        let samplingRate = Shimmer3InfoMem.convertSamplingRateBytesToFreq(samplingRateLSB:samplingRateLSB, samplingRateMSB: samplingRateMSB, samplingClockFreq: getSamplingClockFreq());
        
        print("\(samplingRate)Hz")
        
    }
    
    static public func checkConfigBytesValid(infoMemContents: [UInt8]) -> Bool {
        // Print each byte as a hexadecimal value
        /*for byte in infoMemContents {
            print(String(format: "0x%02X ", byte), terminator: " ")
        }
         */
        
        // Check first 6 bytes of InfoMem for 0xFF to determine if contents are valid
        let comparisonBuffer: [UInt8] = [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]
        var detectionBuffer = Array(infoMemContents.prefix(comparisonBuffer.count))
        
        if comparisonBuffer.elementsEqual(detectionBuffer) {
            return false
        }
        
        return true
    }
    
}
