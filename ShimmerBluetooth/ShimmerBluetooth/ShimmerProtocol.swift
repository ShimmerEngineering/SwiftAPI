//
//  ShimmerProtocol.swift
//  ShimmerBluetooth
//
//  Created by Shimmer Engineering on 24/10/2023.
//

import Foundation

public protocol ShimmerProtocol{
    
    var REV_HW_MAJOR:Int {get set}
    var REV_HW_MINOR:Int {get set}
    var REV_FW_MAJOR:Int {get set}
    var REV_FW_MINOR:Int {get set}
    
    func connect() async ->Bool;
    func disconnect() async ->Bool;
    
}
public protocol ShimmerProtocolDelegate {
    func shimmerProtocolNewMessage(message:String)
    func shimmerProtocolNewObjectCluster(message:ObjectCluster)
    func shimmerBTStateChange(message:Shimmer3Protocol.Shimmer3BTState)
}
