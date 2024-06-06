//
//  ObjectCluster.swift
//  ShimmerBluetooth
//
//  Created by Shimmer Engineering on 17/11/2023.
//

import Foundation

public class ObjectCluster {
    var DeviceName = ""
    public var SignalNames : [String] = []
    public var SignalData : [Double] = []
    let Seperator = "_"
    public func addData(sensorName:String,formatName:String,unitName:String,value:Double){
        let newName = [sensorName,Seperator,formatName,Seperator,unitName].joined()
        SignalNames.append(newName)
        SignalData.append(value)
    }
        
    public init(deviceName:String){
        DeviceName = deviceName
    }
    
}
