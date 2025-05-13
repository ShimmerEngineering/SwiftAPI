//
//  ContentView.swift
//  TestApp
//
//  Created by Shimmer Engineering on 19/10/2023.
//

import SwiftUI
import Charts
import ShimmerBluetooth

struct ToyShape: Identifiable {
    var type: String
    var count: Double
    var id = UUID()
}

struct ContentView: View {
    @State var xNumbers = [1, 3, 5, 7, 9, 11, 13, 15]
    @State var yNumbers = [1, 3, 5, 7, 9, 11, 13, 15]
    @State var test = 2000.0
    @State var min = 0.0
    @State var max = 4000.0
    @State var numbers1: [Double] = []
    @State var numbers2: [Double] = []
    @State var numbers3: [Double] = []
    @StateObject var viewModel = ViewModel()
    func refreshPlot() {
        numbers1 = viewModel.signal1
        numbers2 = viewModel.signal2
        numbers3 = viewModel.signal3
        if (viewModel.signal1.count>0){
            min = viewModel.signal1.min()!
            max = viewModel.signal1.max()!
        }
        if (viewModel.signal2.count>0){
            if viewModel.signal2.min()! < min {
                min = viewModel.signal2.min()!
            }
            
            if viewModel.signal2.max()! > max {
                max = viewModel.signal2.max()!
            }
        }
        if (viewModel.signal3.count>0){
            if viewModel.signal3.min()! < min {
                min = viewModel.signal3.min()!
            }
            
            if viewModel.signal3.max()! > max {
                max = viewModel.signal3.max()!
            }
        }
        
        
    }
    @State private var selectedIndex = 0
    
    @State private var selectionS = 0
    @State private var selection = 0
    @State private var signalSelection = 0
    @State private var rangeSelection = 0
    @State private var protocolSelection = 0
    @State private var deviceSelection = 0
    
    var body: some View {
        ScrollView {
            Picker(selection: $selectionS, label: Text("Number Of Signals (Max 3)")) {
                ForEach(1 ..< 4) {
                    Text("\($0)") }
            }.onChange(of: selectionS) { _ in
                print(selectionS+1)
                viewModel.numberOfSignals = selectionS+1
                viewModel.signal1 = []
                viewModel.signal2 = []
                viewModel.signal3 = []
            }
            
            Picker(selection: $selection, label: Text("Signal Index")) {
                ForEach(0 ..< 22) {
                    Text("\($0)") }
            }.onChange(of: selection) { _ in
                print(selection)
                viewModel.startIndex = selection
                viewModel.signal1 = []
                viewModel.signal2 = []
                viewModel.signal3 = []
            }
            
            Picker("Select Plot", selection: $signalSelection) {
                ForEach(0..<viewModel.pickerData.count, id: \.self) { index in
                    Text(self.viewModel.pickerData[index])
                }
            }.onChange(of: signalSelection) { _ in
                print(signalSelection)
                viewModel.startIndex = signalSelection
            }
            
            Chart {
                ForEach(Array(numbers1.enumerated()), id: \.offset) { index, value in
                    LineMark(
                        x: .value("Index", index),
                        y: .value("Value1", value)
                    ).foregroundStyle(by: .value("Value1", "Value1"))
                }
                ForEach(Array(numbers2.enumerated()), id: \.offset) { index, value in
                    LineMark(
                        x: .value("Index", index),
                        y: .value("Value2", value)
                    ).foregroundStyle(by: .value("Value2", "Value2"))
                }
                
                ForEach(Array(numbers3.enumerated()), id: \.offset) { index, value in
                    LineMark(
                        x: .value("Index", index),
                        y: .value("Value3", value)
                    ).foregroundStyle(by: .value("Value3", "Value3"))
                }
            }.chartForegroundStyleScale(["Value1": Color.orange, "Value2": Color.blue, "Value3": Color.red]).chartYScale(domain: [min,max])
            
            Button("Scan Shimmer3",action: { viewModel.scanShimmer3()})
            Picker("Select Shimmer3", selection: $deviceSelection) {
                ForEach(0..<viewModel.pickerDevices.count, id: \.self) { index in
                    Text(self.viewModel.pickerDevices[index])
                }
            }.onChange(of: deviceSelection) { _ in
                print(deviceSelection)
                viewModel.deviceIndex = deviceSelection
            }
            Picker("Select Protocol", selection: $protocolSelection) {
                ForEach(0..<viewModel.pickerProtocol.count, id: \.self) { index in
                    Text(self.viewModel.pickerProtocol[index])
                }
            }.onChange(of: protocolSelection) { _ in
                print(protocolSelection)
                viewModel.protocolShimmer3 = protocolSelection
            }
            
            Text("BT State: \(viewModel.stateText)")
            Button("Connect Shimmer3",action: {Task {
                do {
                    viewModel.delegate = self
                    
                    await viewModel.connectDev2()
                } catch {
                    print("Error: \(error)")
                }
            }
            })
            Button("Disconnect Shimmer3",action:{ Task {
                do {
                    await viewModel.disconnectDev2()
                } catch {
                    print("Error: \(error)")
                }
            }
            })
            
            Button("StartStreaming Shimmer3",action:{ Task {
                do {
                    await viewModel.sendStartStreamingCommandDev2()
                } catch {
                    print("Error: \(error)")
                }
            }
            })
            Button("StopStreaming Shimmer3",action:{ Task {
                do {
                    await viewModel.sendStopStreamingCommandDev2()
                } catch {
                    print("Error: \(error)")
                }
            }
            })
            if (viewModel.shimmer3Protocol?.REV_HW_MAJOR==Shimmer3Protocol.HardwareType.Shimmer3.rawValue){
                Button("WriteInfoMem WRAccel Shimmer3",action:{ Task {
                    do {
                        await viewModel.sendInfoMemWRAccel()
                    } catch {
                        print("Error: \(error)")
                    }
                }
                })
                Button("WriteInfoMem IMU Shimmer3",action:{ Task {
                    do {
                        await viewModel.sendInfoMemIMU()
                    } catch {
                        print("Error: \(error)")
                    }
                }
                })
                Button("WriteInfoMem Pressure Temperature Shimmer3",action:{ Task {
                    do {
                        await viewModel.sendInfoMemPressureAndTemperature()
                    } catch {
                        print("Error: \(error)")
                    }
                }
                })
                Button("WriteInfoMem PPG+GSR Shimmer3",action:{ Task {
                    do {
                        await viewModel.sendInfoMemPPGGSR()
                    } catch {
                        print("Error: \(error)")
                    }
                }
                })
                
                Button("WriteInfoMem ECG 24-bit Shimmer3",action:{ Task {
                    do {
                        await viewModel.sendInfoMemECG24Bit()
                    } catch {
                        print("Error: \(error)")
                    }
                }
                })
                Button("WriteInfoMem ECG 16-bit Shimmer3",action:{ Task {
                    do {
                        await viewModel.sendInfoMemECG16Bit()
                    } catch {
                        print("Error: \(error)")
                    }
                }
                })
                Button("WriteInfoMem EMG Shimmer3",action:{ Task {
                    do {
                        await viewModel.sendInfoMemEMG()
                    } catch {
                        print("Error: \(error)")
                    }
                }
                })
                Button("WriteInfoMem EXG Test Shimmer3",action:{ Task {
                    do {
                        await viewModel.sendInfoMemEXGTest()
                    } catch {
                        print("Error: \(error)")
                    }
                }
                })
                Button("WriteInfoMem Respiration Shimmer3",action:{ Task {
                    do {
                        await viewModel.sendInfoMemRespiration()
                    } catch {
                        print("Error: \(error)")
                    }
                }
                })
                Button("WriteInfoMem Battery Voltage Shimmer3",action:{ Task {
                    do {
                        await viewModel.sendInfoMemBattery()
                    } catch {
                        print("Error: \(error)")
                    }
                }
                })
            } else if (viewModel.shimmer3Protocol?.REV_HW_MAJOR==Shimmer3Protocol.HardwareType.Shimmer3R.rawValue){
                Button("WriteInfoMem LNAccel Shimmer3R",action:{ Task {
                    do {
                        await viewModel.sendInfoMemS3RLNAccel()
                    } catch {
                        print("Error: \(error)")
                    }
                }
                })
                Button("WriteInfoMem Mag Shimmer3R",action:{ Task {
                    do {
                        await viewModel.sendInfoMemS3RMag()
                    } catch {
                        print("Error: \(error)")
                    }
                }
                })
            }
            Picker("Select EXG Gain", selection: $viewModel.exgGainIndex) {
                ForEach(0..<viewModel.exgGain.count, id: \.self) { index in
                    Text(viewModel.exgGain[index])
                }
            }
            .onChange(of: viewModel.exgGainIndex) { newValue in
                // Update the ViewModel's exgGainIndex property
                viewModel.exgGainIndex = newValue
            }
            Picker("Select EXG Resolution", selection: $viewModel.exgResIndex) {
                ForEach(0..<viewModel.exgResolution.count, id: \.self) { index in
                    Text(viewModel.exgResolution[index])
                }
            }
            .onChange(of: viewModel.exgResIndex) { newValue in
                // Update the ViewModel's exgResIndex property
                viewModel.exgResIndex = newValue
            }
            if (viewModel.shimmer3Protocol?.REV_HW_MAJOR==Shimmer3Protocol.HardwareType.Shimmer3.rawValue){
                Picker("Select WR Accel Range", selection: $viewModel.wrRangeIndex) {
                    ForEach(0..<viewModel.wrRange.count, id: \.self) { index in
                        Text(viewModel.wrRange[index])
                    }
                }
                .onChange(of: viewModel.wrRangeIndex) { newValue in
                    // Update the ViewModel's wrRangeIndex property
                    viewModel.wrRangeIndex = newValue
                }
                Picker("Select Gyro Range", selection: $viewModel.gyroRangeIndex) {
                    ForEach(0..<viewModel.gyroRange.count, id: \.self) { index in
                        Text(viewModel.gyroRange[index])
                    }
                }
                .onChange(of: viewModel.gyroRangeIndex) { newValue in
                    // Update the ViewModel's gyroRangeIndex property
                    viewModel.gyroRangeIndex = newValue
                }
                Picker("Select Pressure Resolution", selection: $viewModel.pressResIndex) {
                    ForEach(0..<viewModel.pressResolution.count, id: \.self) { index in
                        Text(viewModel.pressResolution[index])
                    }
                }
                .onChange(of: viewModel.pressResIndex) { newValue in
                    // Update the ViewModel's pressResIndex property
                    viewModel.pressResIndex = newValue
                }
                Button("WriteInfoMem Shimmer3",action:{ Task {
                    do {
                        await viewModel.sendS3InfoMemConfigUpdate()
                        //await viewModel.sendInfoMemGyroRange()
                        //await viewModel.sendInfoMemPPGGSR()
                        
                    } catch {
                        print("Error: \(error)")
                    }
                }
                    
                })
            } else if (viewModel.shimmer3Protocol?.REV_HW_MAJOR==Shimmer3Protocol.HardwareType.Shimmer3R.rawValue){
                Picker("Select LN Accel Range", selection: $viewModel.lnAccelRangeIndex) {
                    ForEach(0..<viewModel.lnAccelRange.count, id: \.self) { index in
                        Text(viewModel.lnAccelRange[index])
                    }
                }
                .onChange(of: viewModel.lnAccelRangeIndex) { newValue in
                    // Update the ViewModel's wrRangeIndex property
                    viewModel.lnAccelRangeIndex = newValue
                }
                Picker("Select Mag Range", selection: $viewModel.magRange3RIndex) {
                    ForEach(0..<viewModel.magRange3R.count, id: \.self) { index in
                        Text(viewModel.magRange3R[index])
                    }
                }
                .onChange(of: viewModel.magRange3RIndex) { newValue in
                    // Update the ViewModel's wrRangeIndex property
                    viewModel.magRange3RIndex = newValue
                }
                Button("WriteInfoMem Shimmer3R",action:{ Task {
                    do {
                        await viewModel.sendS3RInfoMemConfigUpdate()
                        
                    } catch {
                        print("Error: \(error)")
                    }
                }
                    
                })
            }
            Picker("Sampling Rate", selection: $viewModel.samplingRateIndex) {
                ForEach(0..<viewModel.samplingRate.count, id: \.self) { index in
                    Text(viewModel.samplingRate[index])
                }
            }
            .onChange(of: viewModel.samplingRateIndex) { newValue in
                // Update the ViewModel's samplingRateIndex property
                viewModel.samplingRateIndex = newValue
            }
            
            Button("SetSamplingRate Shimmer3",action:{ Task {
                do {
                    //await viewModel.setShimmerSamplingRate()
                    await viewModel.sendInfoMemSamplingRate()
                    
                } catch {
                    print("Error: \(error)")
                }
            }
            })
        }
    }
    
}
extension ContentView: ViewModelDelegate {
    func plotEvent(message: String) {
        self.refreshPlot()
    }
}

#Preview {
    ContentView()
}
