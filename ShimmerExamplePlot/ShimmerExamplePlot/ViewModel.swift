import Combine
import CoreBluetooth
import ShimmerBluetooth
//let radio = BLEByteRadio(deviceType: DeviceType.verisense, deviceName: "Verisense-21082701B799")
//private let radio = BleByteRadio(deviceName: "Verisense-21082701B799")
private var pendingData=[Data]()
@available(macOS 10.15, *)
@MainActor
class ViewModel: NSObject, ObservableObject {
    private var radio: BleByteRadio?
    private var shimmer3Protocol: Shimmer3Protocol?
    private var shimmer3SpeedTestProtocol: Shimmer3SpeedTestProtocol?
    private var bluetoothManager: BluetoothManager?
    private var centralManager: CBCentralManager?
    public var signal1 : [Double] = []
    public var signal2 : [Double] = []
    public var signal3 : [Double] = []
    @Published var pickerData = ["No Signal"]
    @Published var pickerProtocol = ["LogAndStream","SpeedTest"]
    @Published var pickerDevices = ["Please scan"]
    @Published var wrRange = ["2G", "4G", "8G", "16G"]
    @Published var gyroRange = ["250DPS", "500DPS", "1000DPS", "2000DPS"]
    @Published var exgGain = ["1", "2", "3", "4", "6", "8", "12"]
    @Published var exgResolution = ["16 BIT", "24 BIT"]
    @Published var pressResolution = ["LOW", "STANDARD", "HIGH", "ULTRAHIGH"]
    @Published var samplingRate = ["1Hz", "10.2Hz", "51.2Hz", "102.4Hz", "204.8Hz", "256Hz", "512Hz", "1024Hz"]
    @Published var stateText = "Disconnected"
    private var updatedPicker = false;
    public var delegate: ViewModelDelegate?
    var count = 1
    @Published var wrRangeIndex = 0 // Initial value
    @Published var gyroRangeIndex = 0 // Initial value
    @Published var pressResIndex = 0 // Initial value
    @Published var exgGainIndex = 0 // Initial value
    @Published var exgResIndex = 0 // Initial value
    @Published var samplingRateIndex = 0 // Initial value
    public var startIndex = 0
    public var protocolShimmer3 = 0
    public var numberOfSignals = 1
    public var deviceIndex = 0
    
    @Published var isScanning = false
    public override init() {
        super.init()
        self.centralManager = CBCentralManager()//(delegate: self, queue: nil)
        //self.radio = BleByteRadio(deviceName: "Verisense-21082701B799",cbcentralmanager: centralManager!)
        self.bluetoothManager = BluetoothManager(centralmanager: self.centralManager!)
        bluetoothManager?.delegate = self
        //radio.delegate = self
    }
    func test(){
        //let printer = Test()
        //let printer = BluetoothManager()
        //printer.sayHello();
        
        
        //radio.startScanningAndConnectifFound(timeout: 20000)
        //820702820702radio!.startScanning(timeout: 20000)
        bluetoothManager?.startScanning(uuid: BleByteRadio.VERISENSE_RBL_SERVICE_UUID, timeout: 2)
        
        
    }
    
    func scanShimmer3(){
        //bluetoothManager?.startScanning(deviceName: "Shimmer3-3E36",timeout: 10)
        pickerDevices = ["Scanning"]
        bluetoothManager?.startScanning(timeout: 3)
    }
    
    func refreshUISettings(){
        wrRangeIndex = Int((shimmer3Protocol?.wrAccelSensor.getRange().rawValue)!)
        gyroRangeIndex = Int((shimmer3Protocol?.gyroSensor.getRange().rawValue)!)
        pressResIndex = Int((shimmer3Protocol?.pressureTempSensor.getResolution().rawValue)!)
        exgGainIndex = Int((shimmer3Protocol?.exgSensor.getGain().rawValue)!)
        exgResIndex = Int((shimmer3Protocol?.exgSensor.getResolution().rawValue)!)
        samplingRateIndex = Int((shimmer3Protocol?.getSamplingRateIndex())!)
    }
    
    func connectDev2() async{
        let deviceName = pickerDevices[deviceIndex]
        var peripheral = bluetoothManager?.getPeripheral(deviceName: deviceName)
        self.radio = BleByteRadio(deviceName: deviceName,cbperipheral: peripheral!,bluetoothManager: bluetoothManager!)
        if (protocolShimmer3==0){
            shimmer3Protocol = Shimmer3Protocol(radio: self.radio!)
            shimmer3Protocol?.delegate = self
            await shimmer3Protocol?.connect()
            refreshUISettings()
        } else {
            shimmer3SpeedTestProtocol = Shimmer3SpeedTestProtocol(radio: self.radio!)
            //shimmer3SpeedTestProtocol?.delegate = self
            await shimmer3SpeedTestProtocol?.connect()
            shimmer3SpeedTestProtocol?.startSpeedTest()
        }
    
    }
    func disconnectDev2() async{
        if (shimmer3Protocol==nil){
            await shimmer3SpeedTestProtocol!.disconnect()
        } else {
            await shimmer3Protocol!.disconnect()
        }
    }
    
    func sendInquiryCommandDev2() async {
        
    }
    
    func sendStartStreamingCommandDev2() async {
        updatedPicker = false;
         await shimmer3Protocol!.sendStartStreamingCommand()
        
    }
    
    func sendStopStreamingCommandDev2() async {
        shimmer3Protocol!.sendStopStreamingCommand()
       
    }
    
    func sendInfoMemConfigUpdate() async {
        var infomem =  shimmer3Protocol?.getInfoMemByteArray()
        var wrAccel = WRAccelSensor()
        infomem = wrAccel.updateInfoMemAccelRange(infomem: infomem!, range: WRAccelSensor.Range.fromValue(UInt8(wrRangeIndex))!)
        
        var gyro = GyroSensor()
        infomem = gyro.updateInfoMemGyroRange(infomem: infomem!, range: GyroSensor.Range.fromValue(UInt8(gyroRangeIndex))!)
        
        var press = PressureTempSensor()
        infomem = press.updateInfoMemPressureResolution(infomem: infomem!, res: PressureTempSensor.Resolution.fromValue(UInt8(pressResIndex))!)
        
        infomem = shimmer3Protocol?.exgSensor.updateInfoMemExgGain(infomem: infomem!, gain: EXGSensor.Gain.fromValue(UInt8(exgGainIndex))!)
        infomem = shimmer3Protocol?.exgSensor.updateInfoMemExgResolution(infomem: infomem!, resolution: EXGSensor.Resolution.fromValue(UInt8(exgResIndex))!)
        await shimmer3Protocol?.writeShimmer3InfoMem(infoMem: infomem!)
        //refreshUISettings()
    }
    
    func sendInfoMemSamplingRate() async {
        var infomem =  shimmer3Protocol?.getInfoMemByteArray()
        var samplingRate = Shimmer3Protocol.SamplingRate.fromValue(Double(samplingRateIndex))?.rawValue

        infomem = shimmer3Protocol?.updateInfoMemSamplingRate(infomem: infomem!,samplingRateFreq: samplingRate!)
        infomem = shimmer3Protocol?.exgSensor.updateInfoMemExgRate(infomem: infomem!,samplingRateFreq: samplingRate!)
        let updatedSensors = shimmer3Protocol?.isShimmer3withUpdatedSensors()
        var mag = MagSensor()
        infomem = mag.setLowPowerMag(enable:false, isShimmer3withUpdatedSensors: updatedSensors!, isShimmer3Sensor: (shimmer3Protocol?.isShimmer3Sensor())!, samplingRate: samplingRate!, infomem: infomem!)

        var wrAccel = WRAccelSensor()
        infomem = wrAccel.setLowPowerWRAccel(enable:false, isShimmer3withUpdatedSensors: updatedSensors!, samplingRate: samplingRate!, infomem: infomem!)
        
        var gyro = GyroSensor()
        infomem = gyro.setLowPowerGyro(enable:false, samplingRate: samplingRate!, infomem: infomem!)
        await shimmer3Protocol?.writeShimmer3InfoMem(infoMem: infomem!)

    }
    
    func setShimmerSamplingRate() async{
        var samplingRate = Shimmer3Protocol.SamplingRate.fromValue(Double(samplingRateIndex))?.rawValue

        await shimmer3Protocol?.sendSetSamplingRateCommand(samplingRate: samplingRate!)
        let buff = (shimmer3Protocol?.exgSensor.updateExgRateConfig(samplingRateFreq: samplingRate!))!
        shimmer3Protocol?.writeExgRate(exgArr:buff)
    }
    
    func sendInfoMemIMU() async{
        let infomwracc:[UInt8] = [ 0x80,0x02,0x01,0xE0,0x20,0x00,0x01,0x9B,0x0D,0x08,0x00,0x80,0x10,0x00,0x00,0x00,0x00,0x00,0x02,0x01,0x00,0x80,0x10,0x00,0x00,0x00,0x00,0x00,0x02,0x01,0x09,0x00,0x00,0x00,0x08,0xCD,0x08,0xCD,0x08,0xCD,0x00,0x5C,0x00,0x5C,0x00,0x5C,0x00,0x9C,0x00,0x9C,0x00,0x00,0x00,0x00,0x9C,0x00,0x00,0x00,0x00,0x00,0x00,0x19,0x96,0x19,0x96,0x19,0x96,0x00,0x9C,0x00,0x9C,0x00,0x00,0x00,0x00,0x9C,0x00,0x00,0x00,0x00,0x00,0x00,0x02,0x9B,0x02,0x9B,0x02,0x9B,0x00,0x9C,0x00,0x64,0x00,0x00,0x00,0x00,0x9C,0x00,0x00,0x00,0x00,0x00,0x00,0x06,0x87,0x06,0x87,0x06,0x87,0x00,0x9C,0x00,0x64,0x00,0x00,0x00,0x00,0x9C,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
            0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x53,0x68,0x69,0x6D,0x6D,0x65,0x72,0x5F,0x36,0x38,0x44,0x44,0x44,0x65,0x66,0x61,0x75,0x6C,0x74,0x54,0x72,0x69,0x61,0x6C,0x65,0x54,0x7E,0x40,0x00,0x00,0x31,0x00,0x00,0x00,0x00,0x00,0x00,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
            0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ]
        await shimmer3Protocol?.writeShimmer3InfoMem(infoMem: infomwracc)
        refreshUISettings()
    }
    
    func sendInfoMemAccel() async{
        let infomwracc:[UInt8] = [ 0x80,0x02,0x01,0x00,0x10,0x00,0x41,0xFF,0x01,0x08,0x00,0x80,0x10,0x00,0x00,0x00,0x00,0x00,0x02,0x01,0x00,0x80,0x10,0x00,0x00,0x00,0x00,0x00,0x02,0x01,0x09,0x00,0x00,0x00,0x08,0xCD,0x08,0xCD,0x08,0xCD,0x00,0x5C,0x00,0x5C,0x00,0x5C,0x00,0x9C,0x00,0x9C,0x00,0x00,0x00,0x00,0x9C,0x00,0x00,0x00,0x00,0x00,0x00,0x19,0x96,0x19,0x96,0x19,0x96,0x00,0x9C,0x00,0x9C,0x00,0x00,0x00,0x00,0x9C,0x00,0x00,0x00,0x00,0x00,0x00,0x02,0x9B,0x02,0x9B,0x02,0x9B,0x00,0x9C,0x00,0x64,0x00,0x00,0x00,0x00,0x9C,0x00,0x00,0x00,0x00,0x00,0x00,0x06,0x87,0x06,0x87,0x06,0x87,0x00,0x9C,0x00,0x64,0x00,0x00,0x00,0x00,0x9C,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
                    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x53,0x68,0x69,0x6D,0x6D,0x65,0x72,0x5F,0x36,0x38,0x44,0x44,0x44,0x65,0x66,0x61,0x75,0x6C,0x74,0x54,0x72,0x69,0x61,0x6C,0x65,0x55,0x8C,0x9F,0x00,0x00,0x31,0x00,0x00,0x00,0x00,0x00,0x00,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
                    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00]
        await shimmer3Protocol?.writeShimmer3InfoMem(infoMem: infomwracc)
        refreshUISettings()
    }
    
    func sendInfoMemGyro() async{
        let infomgyro:[UInt8] = [ 0x20, 0x00, 0x01, 0x40, 0x00, 0x00, 0x01, 0x06, 0x01, 0x08, 0x04, 0x88, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x01, 0x04, 0x80, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x01, 0x0B, 0x00, 0x00, 0x00, 0x08, 0xCD, 0x08, 0xCD, 0x08, 0xCD, 0x00, 0x5C, 0x00, 0x5C, 0x00, 0x5C, 0x00, 0x9C, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x19, 0x96, 0x19, 0x96, 0x19, 0x96, 0x00, 0x9C, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x9B, 0x02, 0x9B, 0x02, 0x9B, 0x00, 0x9C, 0x00, 0x64, 0x00, 0x00, 0x00, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x06, 0x87, 0x06, 0x87, 0x06, 0x87, 0x00, 0x9C, 0x00, 0x64, 0x00, 0x00, 0x00, 0x00, 0x9C, 0x20, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x53, 0x68, 0x69, 0x6D, 0x6D, 0x65, 0x72, 0x5F, 0x36, 0x38, 0x44, 0x44, 0x74, 0x72, 0x74, 0x72, 0x74, 0x72, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x66, 0x4C, 0x45, 0xA6, 0x00, 0x00, 0x31, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xD8, 0x47, 0x8F, 0x04, 0xBD, 0xA2, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00]
        await shimmer3Protocol?.writeShimmer3InfoMem(infoMem: infomgyro)
        refreshUISettings()
    }
   
    func sendInfoMemPPGGSR() async{
        let infomppggsr:[UInt8] = [0x80,0x02,0x01,0x04,0x01,0x00,0x01,0xFF,0x21,0x09,0x00,0x80,0x10,0x00,0x00,0x00,0x00,0x00,0x02,0x01,0x00,0x80,0x10,0x00,0x00,0x00,0x00,0x00,0x02,0x01,0x09,0x04,0x00,0x00,0x07,0xEF,0x07,0xED,0x07,0xF5,0x00,0x53,0x00,0x52,0x00,0x51,0xFF,0x9C,0x02,0x9C,0x00,0x00,0xFB,0x02,0x9C,0xFF,0x4D,0xFF,0x95,0xFF,0xD7,0x19,0x6D,0x19,0x42,0x19,0x53,0x00,0x9C,0x00,0x9C,0x01,0x01,0x02,0xFE,0x9C,0x05,0x08,0x03,0x1D,0xFE,0xE4,0x01,0xE2,0x01,0xDF,0x01,0xB6,0x9C,0x00,0x00,0x00,0x64,0x00,0x00,0x00,0x9C,0x00,0x00,0x00,0x00,0x00,0x00,0x06,0x5F,0x06,0x5F,0x06,0x5F,0x9C,0x00,0x00,0x00,0x64,0x00,0x00,0x00,0x9C,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x74,0x65,0x73,0x74,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0x44,0x65,0x66,0x61,0x75,0x6C,0x74,0x54,0x72,0x69,0x61,0x6C,0x65,0x5D,0xA2,0x5B,0x00,0x00,0x31,0x00,0x00,0x00,0x00,0x00,0x00,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,                     0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00]
        await shimmer3Protocol?.writeShimmer3InfoMem(infoMem: infomppggsr)
        refreshUISettings()
    }
    
    func sendInfoMemECG24Bit() async{
        //shimmer3Protocol?.exgSensor.resetEXG()
        let infomexg:[UInt8] = [0x80, 0x02, 0x01, 0x18, 0x00, 0x00, 0x01, 0xFF, 0x01, 0x09, 0x00, 0xA8, 0x10, 0x40, 0x40, 0x2D, 0x00, 0x00, 0x02, 0x03, 0x00, 0xA0, 0x10, 0x40, 0x47, 0x00, 0x00, 0x00, 0x02, 0x01, 0x09, 0x00, 0x00, 0x00, 0x08, 0xCD, 0x08, 0xCD, 0x08, 0xCD, 0x00, 0x5C, 0x00, 0x5C, 0x00, 0x5C, 0x00, 0x9C, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x19, 0x96, 0x19, 0x96, 0x19, 0x96, 0x00, 0x9C, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x9B, 0x02, 0x9B, 0x02, 0x9B, 0x00, 0x9C, 0x00, 0x64, 0x00, 0x00, 0x00, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x06, 0x87, 0x06, 0x87, 0x06, 0x87, 0x00, 0x9C, 0x00, 0x64, 0x00, 0x00, 0x00, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x53, 0x68, 0x69, 0x6D, 0x6D, 0x65, 0x72, 0x5F, 0x36, 0x38, 0x44, 0x44, 0x74, 0x72, 0x74, 0x72, 0x74, 0x72, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x65, 0xCB, 0x1F, 0xAA, 0x00, 0x00, 0x31, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xE8, 0xEB, 0x1B, 0x97, 0x67, 0xFC, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                                   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        
        //shimmer3Protocol?.exgSensor.isEXGUsingDefaultECGConfiguration = true
        await shimmer3Protocol?.writeShimmer3InfoMem(infoMem: infomexg)
        refreshUISettings()
    }
    func sendInfoMemECG16Bit() async{
        //shimmer3Protocol?.exgSensor.resetEXG()
        let infomexg:[UInt8] = [0x80, 0x02, 0x01, 0x00, 0x00, 0x18, 0x01, 0xFF, 0x01, 0x09, 0x00, 0xA8, 0x10, 0x40, 0x40, 0x2D, 0x00, 0x00, 0x02, 0x03, 0x00, 0xA0, 0x10, 0x40, 0x47, 0x00, 0x00, 0x00, 0x02, 0x01, 0x09, 0x00, 0x00, 0x00, 0x08, 0xCD, 0x08, 0xCD, 0x08, 0xCD, 0x00, 0x5C, 0x00, 0x5C, 0x00, 0x5C, 0x00, 0x9C, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x19, 0x96, 0x19, 0x96, 0x19, 0x96, 0x00, 0x9C, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x9B, 0x02, 0x9B, 0x02, 0x9B, 0x00, 0x9C, 0x00, 0x64, 0x00, 0x00, 0x00, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x06, 0x87, 0x06, 0x87, 0x06, 0x87, 0x00, 0x9C, 0x00, 0x64, 0x00, 0x00, 0x00, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x53, 0x68, 0x69, 0x6D, 0x6D, 0x65, 0x72, 0x5F, 0x36, 0x38, 0x44, 0x44, 0x74, 0x72, 0x74, 0x72, 0x74, 0x72, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x65, 0xCB, 0x1F, 0xAA, 0x00, 0x00, 0x31, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xE8, 0xEB, 0x1B, 0x97, 0x67, 0xFC, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                                   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        
        //shimmer3Protocol?.exgSensor.isEXGUsingDefaultECGConfiguration = true
        await shimmer3Protocol?.writeShimmer3InfoMem(infoMem: infomexg)
        refreshUISettings()
    }
    
    func sendInfoMemEMG() async{
        //shimmer3Protocol?.exgSensor.resetEXG()
        let infomemg:[UInt8] = [0x80, 0x02, 0x01, 0x10, 0x00, 0x00, 0x01, 0xFF, 0x01, 0x09, 0x00, 0xA8, 0x10, 0x69, 0x60, 0x20, 0x00, 0x00, 0x02, 0x03, 0x00, 0xA0, 0x10, 0xE1, 0xE1, 0x00, 0x00, 0x00, 0x02, 0x01, 0x09, 0x00, 0x00, 0x00, 0x08, 0xCD, 0x08, 0xCD, 0x08, 0xCD, 0x00, 0x5C, 0x00, 0x5C, 0x00, 0x5C, 0x00, 0x9C, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x19, 0x96, 0x19, 0x96, 0x19, 0x96, 0x00, 0x9C, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x9B, 0x02, 0x9B, 0x02, 0x9B, 0x00, 0x9C, 0x00, 0x64, 0x00, 0x00, 0x00, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x06, 0x87, 0x06, 0x87, 0x06, 0x87, 0x00, 0x9C, 0x00, 0x64, 0x00, 0x00, 0x00, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                                
                                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x53, 0x68, 0x69, 0x6D, 0x6D, 0x65, 0x72, 0x5F, 0x36, 0x38, 0x44, 0x44, 0x74, 0x72, 0x74, 0x72, 0x74, 0x72, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x65, 0xCC, 0x3B, 0xAA, 0x00, 0x00, 0x31, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xE8, 0xEB, 0x1B, 0x97, 0x67, 0xFC, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                                 
                                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]

        //shimmer3Protocol?.exgSensor.isEXGUsingDefaultEMGConfiguration = true
        await shimmer3Protocol?.writeShimmer3InfoMem(infoMem: infomemg)
        refreshUISettings()
    }
                                
    func sendInfoMemEXGTest() async{
        //shimmer3Protocol?.exgSensor.resetEXG()
        let infomexgtest:[UInt8] = [0x80, 0x02, 0x01, 0x18, 0x00, 0x00, 0x01, 0xFF, 0x01, 0x09, 0x00, 0xAB, 0x10, 0x15, 0x15, 0x00, 0x00, 0x00, 0x02, 0x01, 0x00, 0xA3, 0x10, 0x15, 0x15, 0x00, 0x00, 0x00, 0x02, 0x01, 0x09, 0x00, 0x00, 0x00, 0x08, 0xCD, 0x08, 0xCD, 0x08, 0xCD, 0x00, 0x5C, 0x00, 0x5C, 0x00, 0x5C, 0x00, 0x9C, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x19, 0x96, 0x19, 0x96, 0x19, 0x96, 0x00, 0x9C, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x9B, 0x02, 0x9B, 0x02, 0x9B, 0x00, 0x9C, 0x00, 0x64, 0x00, 0x00, 0x00, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x06, 0x87, 0x06, 0x87, 0x06, 0x87, 0x00, 0x9C, 0x00, 0x64, 0x00, 0x00, 0x00, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                                    
                                    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x53, 0x68, 0x69, 0x6D, 0x6D, 0x65, 0x72, 0x5F, 0x36, 0x38, 0x44, 0x44, 0x74, 0x72, 0x74, 0x72, 0x74, 0x72, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x65, 0xCC, 0x2F, 0xBD, 0x00, 0x00, 0x31, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xE8, 0xEB, 0x1B, 0x97, 0x67, 0xFC, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                                     
                                    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]

        //shimmer3Protocol?.exgSensor.isEXGUsingDefaultTestSignalConfiguration = true
        await shimmer3Protocol?.writeShimmer3InfoMem(infoMem: infomexgtest)
        refreshUISettings()
    }
        
    func sendInfoMemRespiration() async{
        //shimmer3Protocol?.exgSensor.resetEXG()
        let infomresp:[UInt8] = [0x80, 0x02, 0x01, 0x18, 0x00, 0x00, 0x01, 0xFF, 0x01, 0x09, 0x00, 0xA8, 0x10, 0x40, 0x40, 0x20, 0x00, 0x00, 0x02, 0x03, 0x00, 0xA0, 0x10, 0x40, 0x40, 0x00, 0x00, 0x00, 0xEA, 0x01, 0x09, 0x00, 0x00, 0x00, 0x08, 0xCD, 0x08, 0xCD, 0x08, 0xCD, 0x00, 0x5C, 0x00, 0x5C, 0x00, 0x5C, 0x00, 0x9C, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x19, 0x96, 0x19, 0x96, 0x19, 0x96, 0x00, 0x9C, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x9B, 0x02, 0x9B, 0x02, 0x9B, 0x00, 0x9C, 0x00, 0x64, 0x00, 0x00, 0x00, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x06, 0x87, 0x06, 0x87, 0x06, 0x87, 0x00, 0x9C, 0x00, 0x64, 0x00, 0x00, 0x00, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                                 
                                 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x53, 0x68, 0x69, 0x6D, 0x6D, 0x65, 0x72, 0x5F, 0x36, 0x38, 0x44, 0x44, 0x74, 0x72, 0x74, 0x72, 0x74, 0x72, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x65, 0xCC, 0x30, 0x06, 0x00, 0x00, 0x31, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xE8, 0xEB, 0x1B, 0x97, 0x67, 0xFC, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                                  
                                 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]

        //shimmer3Protocol?.exgSensor.isEXGUsingDefaultRespirationConfiguration = true
        await shimmer3Protocol?.writeShimmer3InfoMem(infoMem: infomresp)
        refreshUISettings()
    }
    
    func sendInfoMemPressureAndTemperature() async{
        let infompressuretemp:[UInt8] = [0x80, 0x02, 0x01, 0x00, 0x00, 0x04, 0x01, 0xFF, 0x01, 0x08, 0x00, 0x88, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x01, 0x00, 0x80, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x01, 0x09, 0x00, 0x00, 0x00, 0x08, 0xCD, 0x08, 0xCD, 0x08, 0xCD, 0x00, 0x5C, 0x00, 0x5C, 0x00, 0x5C, 0x00, 0x9C, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x19, 0x96, 0x19, 0x96, 0x19, 0x96, 0x00, 0x9C, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x9B, 0x02, 0x9B, 0x02, 0x9B, 0x00, 0x9C, 0x00, 0x64, 0x00, 0x00, 0x00, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x06, 0x87, 0x06, 0x87, 0x06, 0x87, 0x00, 0x9C, 0x00, 0x64, 0x00, 0x00, 0x00, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                                         
                                         0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x53, 0x68, 0x69, 0x6D, 0x6D, 0x65, 0x72, 0x5F, 0x36, 0x38, 0x44, 0x44, 0x74, 0x72, 0x74, 0x72, 0x74, 0x72, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x65, 0xD4, 0xBD, 0x5F, 0x00, 0x00, 0x31, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xE8, 0xEB, 0x1B, 0x97, 0x67, 0xFC, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                                          
                                         0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        await shimmer3Protocol?.writeShimmer3InfoMem(infoMem: infompressuretemp)
        refreshUISettings()
    }
    
    func sendInfoMemBattery() async{
        let infombatt:[UInt8] = [0x80, 0x02, 0x01, 0x00, 0x20, 0x00, 0x01, 0xFF, 0x01, 0x08, 0x00, 0x88, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x01, 0x00, 0x80, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x01, 0x09, 0x00, 0x00, 0x00, 0x08, 0xCD, 0x08, 0xCD, 0x08, 0xCD, 0x00, 0x5C, 0x00, 0x5C, 0x00, 0x5C, 0x00, 0x9C, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x19, 0x96, 0x19, 0x96, 0x19, 0x96, 0x00, 0x9C, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x9B, 0x02, 0x9B, 0x02, 0x9B, 0x00, 0x9C, 0x00, 0x64, 0x00, 0x00, 0x00, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x06, 0x87, 0x06, 0x87, 0x06, 0x87, 0x00, 0x9C, 0x00, 0x64, 0x00, 0x00, 0x00, 0x00, 0x9C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                                 
                                 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x53, 0x68, 0x69, 0x6D, 0x6D, 0x65, 0x72, 0x5F, 0x36, 0x38, 0x44, 0x44, 0x74, 0x72, 0x74, 0x72, 0x74, 0x72, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x65, 0xD4, 0xBD, 0xBD, 0x00, 0x00, 0x31, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xE8, 0xEB, 0x1B, 0x97, 0x67, 0xFC, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                                  
                                 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        await shimmer3Protocol?.writeShimmer3InfoMem(infoMem: infombatt)
        refreshUISettings()
    }
    
    
    func sendReadStatusCommand() {
    }
    
}
extension ViewModel : BluetoothManagerDelegate{
    func scanCompleted() {
        print("Bluetooth Manager Scan Completed")
        self.pickerDevices = (bluetoothManager?.getDiscoveredPeripherals().compactMap { $0.name })!
        print(pickerDevices)
    }
    
    func isConnected() {
        
    }
    
    func isDisconnected() {
        
    }
    
}
extension ViewModel : ShimmerProtocolDelegate {
    func shimmerBTStateChange(message: ShimmerBluetooth.Shimmer3Protocol.Shimmer3BTState) {
        DispatchQueue.main.async {
            self.stateText = message.stringValue
        }
    }
    
    func shimmerProtocolNewMessage(message: String) {
        print("View Model \(message)")
    }

    func shimmerProtocolNewObjectCluster(message: ShimmerBluetooth.ObjectCluster) {
        print(message)
        
        if (!updatedPicker){
            pickerData = message.SignalNames;
            updatedPicker = true;
        }
        
        if (message.SignalData.count>=1){
            if (message.SignalData.count<startIndex+numberOfSignals){
                startIndex=0
            }
            if (numberOfSignals>0){
                self.signal1.append(message.SignalData[startIndex+0])
            }
        }
        if (message.SignalData.count>=2){
            if (numberOfSignals>1){
                self.signal2.append(message.SignalData[startIndex+1])
            }
        }
        if (message.SignalData.count>=3){
            if (numberOfSignals>2){
                self.signal3.append(message.SignalData[startIndex+2])
            }
        }
        if (signal1.count==500){
            signal1.removeFirst()
        }
        if (signal2.count==500){
            signal2.removeFirst()
        }
        if (signal3.count==500){
            signal3.removeFirst()
        }
        self.count+=1
        if (self.count%10 == 0){
            self.delegate?.plotEvent(message: "")
        }
    }
    
}

public protocol ViewModelDelegate {
    func plotEvent(message:String)
}






