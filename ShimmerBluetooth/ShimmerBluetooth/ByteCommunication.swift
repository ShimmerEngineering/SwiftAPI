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
    func byteCommunicationDataReceived(data: Data?)
}
