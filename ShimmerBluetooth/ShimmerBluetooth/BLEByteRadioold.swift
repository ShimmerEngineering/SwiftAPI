//
//  VerisenseBLEByteRadio.swift
//  ShimmerBluetooth
//
//  Created by Shimmer Engineering on 20/10/2023.
//

import Foundation
import CoreBluetooth


public protocol BLEDelegate {
    func radioBLEDidUpdateState(state: CBManagerState)
    func radioBLEDidConnectToPeripheral(peripheral: CBPeripheral)
    func radioBLEDidDisconenctFromPeripheral(peripheral: CBPeripheral)
    func radioBLEDidDiscoverCharacteristics()
    func radioBLEDidReceiveData(data: Data?)
    func radioBLENewMessage(peripheral:CBPeripheral,msg:String)
}

let VERISENSE_RBL_SERVICE_UUID = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
let VERISENSE_RBL_CHAR_RX_UUID = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"
let VERISENSE_RBL_CHAR_TX_UUID = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"

let SHIMMER3_RBL_SERVICE_UUID = "49535343-FE7D-4AE5-8FA9-9FAFD205E455"
let SHIMMER3_RBL_CHAR_RX_UUID = "49535343-1E4D-4BD9-BA61-23C647249616"
let SHIMMER3_RBL_CHAR_TX_UUID = "49535343-8841-43F4-A8D4-ECBE34729BB3"

public enum DeviceType: String {
    case shimmer3 = "Shimmer3"
    case verisense = "Verisense"
    // ...
}

public class BLEByteRadioold:NSObject {
    public var delegate: BLEDelegate?
    private var RBL_SERVICE_UUID: String = ""
    private var RBL_CHAR_RX_UUID: String = ""
    private var RBL_CHAR_TX_UUID: String = ""
    private var deviceName:String = ""
    
    private      var centralManager:   CBCentralManager!
    private      var characteristics = [String : CBCharacteristic]()
    private      var data:             NSMutableData?
    private      var RSSICompletionHandler: ((NSNumber?, NSError?) -> ())?
    
    public       var activePeripheral: CBPeripheral?
    public private(set) var peripherals = [CBPeripheral]()
    
    public init(deviceType: DeviceType, deviceName: String) {
        super.init()
        switch deviceType {
        case .shimmer3:
            self.RBL_SERVICE_UUID = SHIMMER3_RBL_SERVICE_UUID
            self.RBL_CHAR_RX_UUID = SHIMMER3_RBL_CHAR_RX_UUID
            self.RBL_CHAR_TX_UUID = SHIMMER3_RBL_CHAR_TX_UUID
        case .verisense:
            self.RBL_SERVICE_UUID = VERISENSE_RBL_SERVICE_UUID
            self.RBL_CHAR_RX_UUID = VERISENSE_RBL_CHAR_RX_UUID
            self.RBL_CHAR_TX_UUID = VERISENSE_RBL_CHAR_TX_UUID
        }

        self.deviceName = deviceName
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
        self.data = NSMutableData()
    }
    
    public func startScanningAndConnectifFound(timeout: Double) -> Bool {
        
        if self.centralManager.state != .poweredOn {
            
            print("[ERROR] Couldn´t start scanning")
            return false
        }
        
        print("[DEBUG] Scanning started")
        
        // CBCentralManagerScanOptionAllowDuplicatesKey
        /*
        Timer.scheduledTimer(timeInterval: timeout, target: self, selector: #selector(BLE.scanTimeout), userInfo: nil, repeats: false)
         */
        self.centralManager.scanForPeripherals(withServices: [CBUUID(string: RBL_SERVICE_UUID)], options: nil)
        print(self.centralManager.isScanning)
        return true
    }
    
    public func connectToPeripheral(peripheral: CBPeripheral) -> Bool {
        
        if self.centralManager.state != .poweredOn {
            
            print("[ERROR] Couldn´t connect to peripheral")
            return false
        }
        
        print("[DEBUG] Connecting to peripheral: \(peripheral.identifier.uuidString)")
        
        self.centralManager.connect(peripheral, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey : NSNumber(value: true)])
        
        return true
    }
    
    public func enableNotifications(enable: Bool) {
        
        guard let char = self.characteristics[RBL_CHAR_RX_UUID] else { return }
        print("Notifications Enabled")
        self.activePeripheral?.setNotifyValue(enable, for: char)
    }
    
    private func processData(_ data: Data) {
        print(data as NSData)
        var received:[UInt8] = []
        received = Array(data)
        print(received)
        let bytes: [UInt8]=[received[1],received[2]]
        let u16 = UnsafePointer(bytes).withMemoryRebound(to: UInt16.self, capacity: 1){
            $0.pointee
        }
        print("u16: \(u16)")
        if ((data.count-3)==Int(u16)){
            if( received[0]==0x33) {
                print("Read Production Config Command Received")
                print("HW VERSION \(received[10]) . \(received[11])")
                print("FW VERSION \(received[12]) . \(received[1])")
                self.delegate?.radioBLENewMessage(peripheral: self.activePeripheral!, msg: "HW VERSION \(received[10]) . \(received[11])")
            } else if (received[0]==0x31){
                print("Read Status Command Received")
            }
        } else {
            print("[ERROR] length incorrect")
            return
        }
    }
    
}

extension BLEByteRadioold: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        self.delegate?.radioBLEDidUpdateState(state: central.state)
    }
    
    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String : Any],
        rssi RSSI: NSNumber
    ) {
        print("[DEBUG] Find verisense: \(peripheral.identifier.uuidString) RSSI: \(RSSI)")
        print("Found", peripheral.name ?? "Unknown")
        if peripheral.name == deviceName {
            let index = peripherals.index(where: { $0.identifier.uuidString == peripheral.identifier.uuidString })
        
            if let index = index {
                peripherals[index] = peripheral
            } else {
                peripherals.append(peripheral)
            }
        
            if self.connectToPeripheral(peripheral: peripheral) {
                self.centralManager.stopScan()
            }
        }
    }
     
    /*
    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String : Any],
        rssi RSSI: NSNumber
    ){
        print(peripheral.name)
    }*/
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: NSError?) {
        print("[ERROR] Could not connecto to peripheral \(peripheral.identifier.uuidString) error: \(error!.description)")
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        
        print("[DEBUG] Connected to peripheral \(peripheral.identifier.uuidString)")
        
        self.activePeripheral = peripheral
        
        self.activePeripheral?.delegate = self
        self.activePeripheral?.discoverServices([CBUUID(string: RBL_SERVICE_UUID)])
        
        self.delegate?.radioBLEDidConnectToPeripheral(peripheral: peripheral)
        
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        
        var text = "[DEBUG] Disconnected from peripheral: \(peripheral.identifier.uuidString)"
        
        if error != nil {
            text += ". Error: \(error!.description)"
        }
        
        print(text)
        
        self.activePeripheral?.delegate = nil
        self.activePeripheral = nil
        self.characteristics.removeAll(keepingCapacity: false)
        
        self.delegate?.radioBLEDidDisconenctFromPeripheral(peripheral: peripheral)
    }
}

extension BLEByteRadioold : CBPeripheralDelegate {
    /*public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverServices error: Error?
    ){
        print("Discovered")
    }*/
    
    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverServices error: Error?
    ) {
        
        if error != nil {
            print("[ERROR] Error discovering services.")
            return
        }
        
        print("[DEBUG] Found services for peripheral: \(peripheral.identifier.uuidString)")
        
        
        for service in peripheral.services! {
            let theCharacteristics = [CBUUID(string: RBL_CHAR_RX_UUID), CBUUID(string: RBL_CHAR_TX_UUID)]
            
            peripheral.discoverCharacteristics(theCharacteristics, for: service)
        }
    }
    /*
    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ){
        print("disc char")
    }*/
    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ){
        
        if error != nil {
            print("[ERROR] Error discovering characteristics.")
            return
        }
        
        print("[DEBUG] Found characteristics for peripheral: \(peripheral.identifier.uuidString)")
        
        for characteristic in service.characteristics! {
            self.characteristics[characteristic.uuid.uuidString] = characteristic
        }
        
        enableNotifications(enable: true)
        self.delegate?.radioBLEDidDiscoverCharacteristics()
    }
    public func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ){
        print("Updated")
    }
    /*public func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ){
        print("RX")
    }*/
    public func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if error != nil {
            
            print("[ERROR] Error updating value.")
            return
        }
        
        if characteristic.uuid.uuidString == RBL_CHAR_RX_UUID {
            if let data = characteristic.value {
                self.processData(data)
                
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: NSError?) {
        self.RSSICompletionHandler?(RSSI, error)
        self.RSSICompletionHandler = nil
    }
}
