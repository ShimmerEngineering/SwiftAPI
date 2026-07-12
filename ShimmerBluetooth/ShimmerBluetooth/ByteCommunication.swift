//
//  ByteCommunication.swift
//  ShimmerBluetooth
//
//  Created by Shimmer Engineering on 24/10/2023.
//

import Foundation

public protocol ByteCommunication {
    func connect() async ->Bool?;
    func disconnect() async ->Bool?;
    func writeBytes(bytes: [UInt8])->Bool;
}

public protocol ByteCommunicationDelegate {
    func byteCommunicationConnected()
    func byteCommunicationDisconnected(connectionloss: Bool)
    func byteCommunicationDisconnected(connectionloss: Bool, deviceName: String)
    func byteCommunicationDataReceived(data: Data?, deviceName: String)
}

public extension ByteCommunicationDelegate {
    //Default forwards to the legacy callback so existing conformers keep compiling
    func byteCommunicationDisconnected(connectionloss: Bool, deviceName: String) {
        byteCommunicationDisconnected(connectionloss: connectionloss)
    }
}
