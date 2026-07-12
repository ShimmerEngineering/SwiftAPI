//
//  ContentView.swift
//  TestApp
//
//  Created by Shimmer Engineering on 19/10/2023.
//

import SwiftUI
import Charts
import ShimmerBluetooth

struct ContentView: View {
    @StateObject private var viewModel = ViewModel()

    // Local picker state mirrored into the ViewModel's plain (non-published) inputs.
    @State private var protocolSelection = 0
    @State private var deviceSelection = 0
    @State private var numberOfSignalsSelection = 1
    @State private var signalSelection = 0

    /// Colors used for the live chart series (chart colors may be literal per the design brief).
    private let seriesPalette: [Color] = [.orange, .blue, .green]

    var body: some View {
        NavigationStack {
            Form {
                chartSection
                deviceSection
                if viewModel.isConnected {
                    plotSettingsSection
                    sensorPresetSection
                    sensorConfigurationSection
                    samplingRateSection
                    streamingSection
                }
            }
            .navigationTitle("Shimmer Plot")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .animation(.default, value: viewModel.stateText)
            .animation(.default, value: viewModel.isScanning)
        }
    }

    // MARK: - Live chart

    private var chartSection: some View {
        Section("Live Signal") {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    if viewModel.hasPlotData {
                        chart
                    } else {
                        plotPlaceholder
                    }
                }
                .frame(height: 240)
                .animation(.default, value: viewModel.hasPlotData)

                if viewModel.hasPlotData {
                    legend
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var chart: some View {
        Chart {
            ForEach(viewModel.plotSeries) { series in
                ForEach(Array(series.values.enumerated()), id: \.offset) { index, value in
                    LineMark(
                        x: .value("Sample", index),
                        y: .value("Value", value)
                    )
                    .foregroundStyle(by: .value("Series", String(series.id)))
                    .interpolationMethod(.catmullRom)
                }
            }
        }
        .chartForegroundStyleScale([
            "0": seriesPalette[0],
            "1": seriesPalette[1],
            "2": seriesPalette[2]
        ])
        .chartLegend(.hidden)
        .chartYScale(domain: viewModel.yAxisDomain)
        .chartXAxisLabel("Sample")
        .chartYAxisLabel("Value")
    }

    private var legend: some View {
        HStack(spacing: 16) {
            ForEach(viewModel.plotSeries) { series in
                HStack(spacing: 6) {
                    Circle()
                        .fill(seriesPalette[series.id])
                        .frame(width: 8, height: 8)
                    Text(series.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var plotPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(viewModel.isConnected
                 ? "Start streaming to see live sensor data."
                 : "Connect a Shimmer device to begin.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Device connection

    private var deviceSection: some View {
        Section("Device") {
            LabeledContent("Status") { statusBadge }

            if let name = viewModel.connectedDeviceName, viewModel.isConnected {
                LabeledContent("Name", value: name)
            }
            if let hardware = viewModel.hardwareTypeName {
                LabeledContent("Hardware", value: hardware)
            }
            if let firmware = viewModel.firmwareVersionString {
                LabeledContent("Firmware", value: firmware)
            }

            if viewModel.isConnected {
                Button(role: .destructive) {
                    Task { await viewModel.disconnectDev2() }
                } label: {
                    Label("Disconnect", systemImage: "xmark.circle")
                }
            } else {
                Picker("Protocol", selection: $protocolSelection) {
                    ForEach(0..<viewModel.pickerProtocol.count, id: \.self) { index in
                        Text(viewModel.pickerProtocol[index]).tag(index)
                    }
                }
                .onChange(of: protocolSelection) { newValue in
                    viewModel.protocolShimmer3 = newValue
                }

                Button {
                    viewModel.scanShimmer3()
                } label: {
                    Label("Scan for Devices", systemImage: "magnifyingglass")
                }
                .disabled(viewModel.isScanning)

                deviceList

                Button {
                    Task { await viewModel.connectDev2() }
                } label: {
                    Label("Connect", systemImage: "link")
                }
                .disabled(viewModel.pickerDevices.isEmpty || viewModel.isScanning || viewModel.isBusy)
            }
        }
    }

    @ViewBuilder
    private var deviceList: some View {
        if viewModel.isScanning {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Scanning for devices…").foregroundStyle(.secondary)
            }
        } else if viewModel.pickerDevices.isEmpty {
            Text("No devices found. Tap Scan to search.")
                .foregroundStyle(.secondary)
        } else {
            Picker("Discovered", selection: $deviceSelection) {
                ForEach(0..<viewModel.pickerDevices.count, id: \.self) { index in
                    Text(viewModel.pickerDevices[index]).tag(index)
                }
            }
            .onChange(of: deviceSelection) { newValue in
                viewModel.deviceIndex = newValue
            }
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 6) {
            if viewModel.isBusy || viewModel.isScanning {
                ProgressView().controlSize(.small)
            } else {
                Circle().fill(statusColor).frame(width: 8, height: 8)
            }
            Text(viewModel.isScanning ? "Scanning" : viewModel.stateText)
                .font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.15), in: Capsule())
    }

    private var statusColor: Color {
        switch viewModel.btState {
        case .CONNECTED: return .green
        case .STREAMING: return .blue
        case .CONNECTING, .CONFIGURING: return .orange
        case .DISCONNECTED: return .gray
        }
    }

    // MARK: - Plot settings

    private var plotSettingsSection: some View {
        Section("Plot Settings") {
            Picker("Signals Shown", selection: $numberOfSignalsSelection) {
                ForEach(1...3, id: \.self) { count in
                    Text("\(count)").tag(count)
                }
            }
            .onChange(of: numberOfSignalsSelection) { newValue in
                viewModel.numberOfSignals = newValue
                clearSignals()
            }

            Picker("Channel", selection: $signalSelection) {
                ForEach(0..<viewModel.pickerData.count, id: \.self) { index in
                    Text(viewModel.pickerData[index]).tag(index)
                }
            }
            .onChange(of: signalSelection) { newValue in
                viewModel.startIndex = newValue
                clearSignals()
            }
        }
    }

    // MARK: - Sensor presets

    @ViewBuilder
    private var sensorPresetSection: some View {
        if viewModel.isShimmer3Hardware || viewModel.isShimmer3RHardware {
            Section("Sensor Preset") {
                Menu {
                    if viewModel.isShimmer3Hardware {
                        presetButton("Wide-Range Accel") { await viewModel.sendInfoMemWRAccel() }
                        presetButton("IMU (9-DoF)") { await viewModel.sendInfoMemIMU() }
                        presetButton("Pressure & Temperature") { await viewModel.sendInfoMemPressureAndTemperature() }
                        presetButton("PPG + GSR") { await viewModel.sendInfoMemPPGGSR() }
                        presetButton("ECG (24-bit)") { await viewModel.sendInfoMemECG24Bit() }
                        presetButton("ECG (16-bit)") { await viewModel.sendInfoMemECG16Bit() }
                        presetButton("EMG") { await viewModel.sendInfoMemEMG() }
                        presetButton("EXG Test Signal") { await viewModel.sendInfoMemEXGTest() }
                        presetButton("Respiration") { await viewModel.sendInfoMemRespiration() }
                        presetButton("Battery Voltage") { await viewModel.sendInfoMemBattery() }
                    } else {
                        presetButton("Low-Noise Accel") { await viewModel.sendInfoMemS3RLNAccel() }
                        presetButton("Wide-Range Accel") { await viewModel.sendInfoMemS3RWRAccel() }
                        presetButton("Magnetometer") { await viewModel.sendInfoMemS3RMag() }
                        presetButton("Alt Magnetometer") { await viewModel.sendInfoMemS3RAltMag() }
                        presetButton("Gyroscope") { await viewModel.sendInfoMemS3RGyro() }
                    }
                } label: {
                    Label("Apply Sensor Preset", systemImage: "slider.horizontal.3")
                }
                .disabled(viewModel.isBusy)
            }
        }
    }

    private func presetButton(_ title: String, action: @escaping () async -> Void) -> some View {
        Button(title) { Task { await action() } }
    }

    // MARK: - Sensor configuration

    @ViewBuilder
    private var sensorConfigurationSection: some View {
        Section("Sensor Configuration") {
            configPicker("EXG Gain", options: viewModel.exgGain, selection: $viewModel.exgGainIndex)
            configPicker("EXG Resolution", options: viewModel.exgResolution, selection: $viewModel.exgResIndex)
            configPicker("WR Accel Range", options: viewModel.wrRange, selection: $viewModel.wrRangeIndex)

            if viewModel.isShimmer3Hardware {
                configPicker("Gyro Range", options: viewModel.gyroRange, selection: $viewModel.gyroRangeIndex)
                configPicker("Pressure Resolution", options: viewModel.pressResolution, selection: $viewModel.pressResIndex)
                writeConfigButton { await viewModel.sendS3InfoMemConfigUpdate() }
            } else if viewModel.isShimmer3RHardware {
                configPicker("LN Accel Range", options: viewModel.lnAccelRange, selection: $viewModel.lnAccelRangeIndex)
                configPicker("Alt Mag Range", options: viewModel.altMagRange3R, selection: $viewModel.altMagRange3RIndex)
                configPicker("Gyro Range", options: viewModel.gyroRange3R, selection: $viewModel.gyroRange3RIndex)
                writeConfigButton { await viewModel.sendS3RInfoMemConfigUpdate() }
            }
        }
    }

    private func configPicker(_ title: String, options: [String], selection: Binding<Int>) -> some View {
        Picker(title, selection: selection) {
            ForEach(0..<options.count, id: \.self) { index in
                Text(options[index]).tag(index)
            }
        }
    }

    private func writeConfigButton(action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            Label("Write Configuration", systemImage: "square.and.arrow.down")
        }
        .disabled(viewModel.isBusy)
    }

    // MARK: - Sampling rate

    private var samplingRateSection: some View {
        Section("Sampling Rate") {
            configPicker("Rate", options: viewModel.samplingRate, selection: $viewModel.samplingRateIndex)
            Button {
                Task { await viewModel.sendInfoMemSamplingRate() }
            } label: {
                Label("Set Sampling Rate", systemImage: "metronome")
            }
            .disabled(viewModel.isBusy)
        }
    }

    // MARK: - Streaming

    private var streamingSection: some View {
        Section("Streaming") {
            Button {
                Task { await viewModel.sendStartStreamingCommandDev2() }
            } label: {
                Label("Start Streaming", systemImage: "play.fill")
            }
            .disabled(viewModel.isStreaming)

            Button(role: .destructive) {
                Task { await viewModel.sendStopStreamingCommandDev2() }
            } label: {
                Label("Stop Streaming", systemImage: "stop.fill")
            }
            .disabled(!viewModel.isStreaming)
        }
    }

    // MARK: - Helpers

    private func clearSignals() {
        viewModel.signal1 = []
        viewModel.signal2 = []
        viewModel.signal3 = []
    }
}

#Preview {
    ContentView()
}
