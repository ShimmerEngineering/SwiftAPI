//
//  ContentView.swift
//  TestApp
//
//  Created by Shimmer Engineering on 19/10/2023.
//

import SwiftUI
import Charts
import ShimmerBluetooth

// MARK: - Consensys design system
//
// SwiftUI port of Shimmer's "Consensys" desktop instrument UI. Light mode only
// (the design system defines no dark tokens). All values are taken from the
// design spec's tokens: colors as exact hex, a px type/spacing scale, and a
// near-square 2px corner radius used almost everywhere.
//
// FONT NOTE: the spec's font family is "Carlito" (Calibri-metric-compatible),
// which is NOT bundled in this project. Per the spec we intentionally fall back
// to the system font (San Francisco); the sizes/weights/letter-spacing below
// are what actually carry the look. Do not attempt to bundle a font here.

enum ConsensysTheme {

    /// Build a Color from a 24-bit RGB hex literal (e.g. 0xF15D22).
    static func color(_ hex: UInt) -> Color {
        Color(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }

    // Colors
    static let orange = color(0xF15D22)          // primary accent
    static let orangeDeep = color(0xD66617)      // hover
    static let orangePressed = color(0xBB5913)   // pressed/active
    static let orangeTint = color(0xFDEFE7)      // selected/accent badge bg
    static let blue = color(0x0081C6)            // info tone / chart series 2
    static let surface = color(0xFFFFFF)         // primary surface
    static let surfaceAlt = color(0xF5F5F5)      // hover/alt surface, pending bg
    static let grey100 = color(0xEAEAEA)         // table hairline
    static let grey150 = color(0xE9E9E9)         // neutral badge bg / grid lines
    static let grey200 = color(0xE8E8E8)         // table header bg
    static let grey300 = color(0xD7D7D7)         // slider track / dividers
    static let border = color(0xD3D3D3)          // panel/toolbar border
    static let borderStrong = color(0xA0A0A0)    // input/button/control border
    static let text = color(0x808080)            // labels, headings, default text
    static let textMid = color(0x8A8A8A)         // placeholder / empty-state text
    static let textStrong = color(0x484848)      // values, titles
    static let onAccent = Color.white            // text on orange
    static let chartGreen = color(0x7CAC7C)      // chart series 3
    static let greenTint = color(0xE4F3E4)       // success badge bg
    static let greenText = color(0x3D6B3D)       // success badge text
    static let red = color(0xB22222)             // error / destructive
    static let redTint = color(0xFBEAEA)         // error badge bg
    static let infoBg = color(0xE3F1F9)          // info badge bg

    // Spacing scale (px)
    static let space1: CGFloat = 4
    static let space2: CGFloat = 8
    static let space3: CGFloat = 12
    static let space4: CGFloat = 16
    static let space5: CGFloat = 24
    static let space6: CGFloat = 32

    // Radius — near-square corners everywhere.
    static let radius: CGFloat = 2

    /// System-font substitute for Carlito (see FONT NOTE above).
    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}

// MARK: - Reusable Consensys components

/// UPPERCASE, tracked, bold field/heading label in the muted grey (#808080).
private struct ConsensysFieldLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(ConsensysTheme.font(12, .bold))
            .tracking(0.5)
            .textCase(.uppercase)
            .foregroundColor(ConsensysTheme.text)
    }
}

/// Bordered white panel: 1px #D3D3D3 hairline, 2px radius, 16px padding, with an
/// optional UPPERCASE tracked title row (13px bold, #484848).
private struct ConsensysPanel<Content: View>: View {
    private let title: String?
    private let content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                Text(title)
                    .font(ConsensysTheme.font(13, .bold))
                    .tracking(0.5)
                    .textCase(.uppercase)
                    .foregroundColor(ConsensysTheme.textStrong)
                    .padding(.bottom, ConsensysTheme.space3)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ConsensysTheme.space4)
        .background(ConsensysTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: ConsensysTheme.radius)
                .stroke(ConsensysTheme.border, lineWidth: 1)
        )
        .cornerRadius(ConsensysTheme.radius)
    }
}

/// Label/value row following the "values strong (#484848), labels grey (#808080)"
/// idiom.
private struct ConsensysInfoRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            ConsensysFieldLabel(text: label)
            Spacer(minLength: ConsensysTheme.space3)
            Text(value)
                .font(ConsensysTheme.font(14))
                .foregroundColor(ConsensysTheme.textStrong)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, ConsensysTheme.space1)
    }
}

/// Square status chip (2px radius, 12px bold uppercase) with a round tone dot or
/// spinner.
private struct ConsensysStatusBadge: View {
    enum Tone { case neutral, success, info, accent, error, pending }

    let tone: Tone
    let text: String
    var showSpinner: Bool = false

    private var background: Color {
        switch tone {
        case .neutral: return ConsensysTheme.grey150
        case .success: return ConsensysTheme.greenTint
        case .info: return ConsensysTheme.infoBg
        case .accent: return ConsensysTheme.orangeTint
        case .error: return ConsensysTheme.redTint
        case .pending: return ConsensysTheme.surfaceAlt
        }
    }

    private var foreground: Color {
        switch tone {
        case .neutral: return ConsensysTheme.textStrong
        case .success: return ConsensysTheme.greenText
        case .info: return ConsensysTheme.blue
        case .accent: return ConsensysTheme.orangeDeep
        case .error: return ConsensysTheme.red
        case .pending: return ConsensysTheme.textMid
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            if showSpinner {
                ProgressView().controlSize(.small)
            } else {
                Circle().fill(foreground).frame(width: 8, height: 8)
            }
            Text(text)
                .font(ConsensysTheme.font(12, .bold))
                .tracking(0.5)
                .textCase(.uppercase)
                .foregroundColor(foreground)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 2)
        .background(background)
        .overlay(
            RoundedRectangle(cornerRadius: ConsensysTheme.radius)
                .strokeBorder(
                    tone == .pending ? ConsensysTheme.borderStrong : .clear,
                    style: StrokeStyle(lineWidth: 1, dash: tone == .pending ? [3] : [])
                )
        )
        .cornerRadius(ConsensysTheme.radius)
    }
}

/// Shared button chrome so real Buttons and Menu labels look identical.
private struct ConsensysButtonSurface<Label: View>: View {
    let variant: ConsensysButtonStyle.Variant
    var isPressed: Bool = false
    private let label: Label
    @Environment(\.isEnabled) private var isEnabled

    init(variant: ConsensysButtonStyle.Variant = .standard,
         isPressed: Bool = false,
         @ViewBuilder label: () -> Label) {
        self.variant = variant
        self.isPressed = isPressed
        self.label = label()
    }

    private var foreground: Color {
        switch variant {
        case .standard: return isPressed ? ConsensysTheme.orangePressed : ConsensysTheme.text
        case .accent: return ConsensysTheme.onAccent
        case .destructive: return ConsensysTheme.red
        }
    }

    private var background: Color {
        switch variant {
        case .standard: return ConsensysTheme.surface
        case .accent: return isPressed ? ConsensysTheme.orangePressed : ConsensysTheme.orange
        case .destructive: return isPressed ? ConsensysTheme.redTint : ConsensysTheme.surface
        }
    }

    private var borderColor: Color {
        switch variant {
        case .standard: return isPressed ? ConsensysTheme.orangePressed : ConsensysTheme.borderStrong
        case .accent: return isPressed ? ConsensysTheme.orangePressed : ConsensysTheme.orange
        case .destructive: return ConsensysTheme.red
        }
    }

    var body: some View {
        label
            .font(ConsensysTheme.font(14, .semibold))
            .tracking(0.5)
            .textCase(.uppercase)
            .foregroundColor(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, ConsensysTheme.space2)
            .padding(.horizontal, ConsensysTheme.space5)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: ConsensysTheme.radius)
                    .stroke(borderColor, lineWidth: 1)
            )
            .cornerRadius(ConsensysTheme.radius)
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(Rectangle())
    }
}

/// Consensys button: uppercase label, 2px radius, quick 0.12s state fade.
/// default = white + grey hairline + grey text; accent = orange fill + white;
/// destructive = red outline (red tint fill when pressed). Disabled = 0.45 opacity.
struct ConsensysButtonStyle: ButtonStyle {
    enum Variant { case standard, accent, destructive }
    var variant: Variant = .standard

    func makeBody(configuration: Configuration) -> some View {
        ConsensysButtonSurface(variant: variant, isPressed: configuration.isPressed) {
            configuration.label
        }
        .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Select-styled row: field label above a white, hairline-bordered field with a
/// value in strong grey and a chevron. Backed by a Menu so it works on iOS + macOS.
private struct ConsensysSelectRow: View {
    let label: String
    let options: [String]
    @Binding var selection: Int
    var onSelect: ((Int) -> Void)? = nil

    private var displayText: String {
        (selection >= 0 && selection < options.count) ? options[selection] : "—"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ConsensysTheme.space1) {
            ConsensysFieldLabel(text: label)
            Menu {
                ForEach(options.indices, id: \.self) { index in
                    Button(options[index]) {
                        selection = index
                        onSelect?(index)
                    }
                }
            } label: {
                HStack {
                    Text(displayText)
                        .font(ConsensysTheme.font(14))
                        .foregroundColor(ConsensysTheme.textStrong)
                    Spacer(minLength: ConsensysTheme.space2)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(ConsensysTheme.textMid)
                }
                .padding(.horizontal, ConsensysTheme.space2)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ConsensysTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: ConsensysTheme.radius)
                        .stroke(ConsensysTheme.borderStrong, lineWidth: 1)
                )
                .cornerRadius(ConsensysTheme.radius)
            }
        }
    }
}

// MARK: - Content

struct ContentView: View {
    @StateObject private var viewModel = ViewModel()

    // Local picker state (indices) mirrored into the ViewModel's plain inputs.
    @State private var protocolSelection = 0
    @State private var deviceSelection = 0
    @State private var numberOfSignalsIndex = 0   // 0-based; maps to 1...3 signals
    @State private var signalSelection = 0

    /// Chart series colors, per the design brief (Shimmer orange / blue / green).
    private let seriesPalette: [Color] = [
        ConsensysTheme.orange,
        ConsensysTheme.blue,
        ConsensysTheme.chartGreen
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                ConsensysTheme.surface.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: ConsensysTheme.space4) {
                        chartPanel
                        devicePanel
                        if viewModel.isConnected {
                            plotSettingsPanel
                            sensorPresetPanel
                            sensorConfigurationPanel
                            samplingRatePanel
                            streamingPanel
                        }
                    }
                    .padding(ConsensysTheme.space4)
                }
            }
            .navigationTitle("Shimmer Plot")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .animation(.default, value: viewModel.stateText)
            .animation(.default, value: viewModel.isScanning)
        }
        .preferredColorScheme(.light)
    }

    // MARK: - Live chart

    private var chartPanel: some View {
        ConsensysPanel("Live Signal") {
            VStack(alignment: .leading, spacing: ConsensysTheme.space3) {
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
        .chartXAxis {
            AxisMarks { _ in
                AxisGridLine().foregroundStyle(ConsensysTheme.grey150)
                AxisTick().foregroundStyle(ConsensysTheme.border)
                AxisValueLabel().foregroundStyle(ConsensysTheme.text)
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisGridLine().foregroundStyle(ConsensysTheme.grey150)
                AxisTick().foregroundStyle(ConsensysTheme.border)
                AxisValueLabel().foregroundStyle(ConsensysTheme.text)
            }
        }
    }

    private var legend: some View {
        HStack(spacing: ConsensysTheme.space4) {
            ForEach(viewModel.plotSeries) { series in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: ConsensysTheme.radius)
                        .fill(seriesPalette[series.id])
                        .frame(width: 10, height: 10)
                    Text(series.name)
                        .font(ConsensysTheme.font(12))
                        .foregroundColor(ConsensysTheme.text)
                }
            }
        }
    }

    private var plotPlaceholder: some View {
        VStack(spacing: ConsensysTheme.space3) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 44))
                .foregroundColor(ConsensysTheme.borderStrong)
            Text(viewModel.isConnected
                 ? "Start streaming to see live sensor data."
                 : "Connect a Shimmer device to begin.")
                .font(ConsensysTheme.font(14))
                .foregroundColor(ConsensysTheme.textMid)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Device connection

    private var devicePanel: some View {
        ConsensysPanel("Device") {
            VStack(alignment: .leading, spacing: ConsensysTheme.space3) {
                HStack {
                    ConsensysFieldLabel(text: "Status")
                    Spacer(minLength: ConsensysTheme.space3)
                    ConsensysStatusBadge(
                        tone: statusTone,
                        text: statusText,
                        showSpinner: statusShowsSpinner
                    )
                }
                .padding(.vertical, ConsensysTheme.space1)

                if let name = viewModel.connectedDeviceName, viewModel.isConnected {
                    ConsensysInfoRow(label: "Name", value: name)
                }
                if let hardware = viewModel.hardwareTypeName {
                    ConsensysInfoRow(label: "Hardware", value: hardware)
                }
                if let firmware = viewModel.firmwareVersionString {
                    ConsensysInfoRow(label: "Firmware", value: firmware)
                }

                if viewModel.isConnected {
                    Button {
                        Task { await viewModel.disconnectDev2() }
                    } label: {
                        Label("Disconnect", systemImage: "xmark.circle")
                    }
                    .buttonStyle(ConsensysButtonStyle(variant: .destructive))
                } else {
                    ConsensysSelectRow(
                        label: "Protocol",
                        options: viewModel.pickerProtocol,
                        selection: $protocolSelection
                    ) { newValue in
                        viewModel.protocolShimmer3 = newValue
                    }

                    Button {
                        viewModel.scanShimmer3()
                    } label: {
                        Label("Scan for Devices", systemImage: "magnifyingglass")
                    }
                    .buttonStyle(ConsensysButtonStyle())
                    .disabled(viewModel.isScanning)

                    deviceList

                    Button {
                        Task { await viewModel.connectDev2() }
                    } label: {
                        Label("Connect", systemImage: "link")
                    }
                    .buttonStyle(ConsensysButtonStyle(variant: .accent))
                    .disabled(viewModel.pickerDevices.isEmpty || viewModel.isScanning || viewModel.isBusy)
                }
            }
        }
    }

    @ViewBuilder
    private var deviceList: some View {
        if viewModel.isScanning {
            HStack(spacing: ConsensysTheme.space2) {
                ProgressView().controlSize(.small)
                Text("Scanning for devices…")
                    .font(ConsensysTheme.font(14))
                    .foregroundColor(ConsensysTheme.textMid)
            }
        } else if viewModel.pickerDevices.isEmpty {
            Text("No devices found. Tap Scan to search.")
                .font(ConsensysTheme.font(14))
                .foregroundColor(ConsensysTheme.textMid)
        } else {
            ConsensysSelectRow(
                label: "Discovered",
                options: viewModel.pickerDevices,
                selection: $deviceSelection
            ) { newValue in
                viewModel.deviceIndex = newValue
            }
        }
    }

    // Status-badge mapping (preserves the busy/scanning spinner behavior).

    private var statusTone: ConsensysStatusBadge.Tone {
        if viewModel.isScanning { return .accent }
        switch viewModel.btState {
        case .CONNECTED: return .success
        case .STREAMING: return .info
        case .CONNECTING, .CONFIGURING: return .accent
        case .DISCONNECTED: return .neutral
        }
    }

    private var statusText: String {
        viewModel.isScanning ? "Scanning" : viewModel.stateText
    }

    private var statusShowsSpinner: Bool {
        viewModel.isScanning || viewModel.isBusy
    }

    // MARK: - Plot settings

    private var plotSettingsPanel: some View {
        ConsensysPanel("Plot Settings") {
            VStack(alignment: .leading, spacing: ConsensysTheme.space3) {
                ConsensysSelectRow(
                    label: "Signals Shown",
                    options: ["1", "2", "3"],
                    selection: $numberOfSignalsIndex
                ) { newIndex in
                    viewModel.numberOfSignals = newIndex + 1
                    clearSignals()
                }

                ConsensysSelectRow(
                    label: "Channel",
                    options: viewModel.pickerData,
                    selection: $signalSelection
                ) { newValue in
                    viewModel.startIndex = newValue
                    clearSignals()
                }
            }
        }
    }

    // MARK: - Sensor presets

    @ViewBuilder
    private var sensorPresetPanel: some View {
        if viewModel.isShimmer3Hardware || viewModel.isShimmer3RHardware {
            ConsensysPanel("Sensor Preset") {
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
                    ConsensysButtonSurface(variant: .standard) {
                        Label("Apply Sensor Preset", systemImage: "slider.horizontal.3")
                    }
                }
                .disabled(viewModel.isBusy)
            }
        }
    }

    private func presetButton(_ title: String, action: @escaping () async -> Void) -> some View {
        Button(title) { Task { await action() } }
    }

    // MARK: - Sensor configuration

    private var sensorConfigurationPanel: some View {
        ConsensysPanel("Sensor Configuration") {
            VStack(alignment: .leading, spacing: ConsensysTheme.space3) {
                ConsensysSelectRow(label: "EXG Gain", options: viewModel.exgGain, selection: $viewModel.exgGainIndex)
                ConsensysSelectRow(label: "EXG Resolution", options: viewModel.exgResolution, selection: $viewModel.exgResIndex)
                ConsensysSelectRow(label: "WR Accel Range", options: viewModel.wrRange, selection: $viewModel.wrRangeIndex)

                if viewModel.isShimmer3Hardware {
                    ConsensysSelectRow(label: "Gyro Range", options: viewModel.gyroRange, selection: $viewModel.gyroRangeIndex)
                    ConsensysSelectRow(label: "Pressure Resolution", options: viewModel.pressResolution, selection: $viewModel.pressResIndex)
                    writeConfigButton { await viewModel.sendS3InfoMemConfigUpdate() }
                } else if viewModel.isShimmer3RHardware {
                    ConsensysSelectRow(label: "LN Accel Range", options: viewModel.lnAccelRange, selection: $viewModel.lnAccelRangeIndex)
                    ConsensysSelectRow(label: "Alt Mag Range", options: viewModel.altMagRange3R, selection: $viewModel.altMagRange3RIndex)
                    ConsensysSelectRow(label: "Gyro Range", options: viewModel.gyroRange3R, selection: $viewModel.gyroRange3RIndex)
                    writeConfigButton { await viewModel.sendS3RInfoMemConfigUpdate() }
                }
            }
        }
    }

    private func writeConfigButton(action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            Label("Write Configuration", systemImage: "square.and.arrow.down")
        }
        .buttonStyle(ConsensysButtonStyle())
        .disabled(viewModel.isBusy)
    }

    // MARK: - Sampling rate

    private var samplingRatePanel: some View {
        ConsensysPanel("Sampling Rate") {
            VStack(alignment: .leading, spacing: ConsensysTheme.space3) {
                ConsensysSelectRow(label: "Rate", options: viewModel.samplingRate, selection: $viewModel.samplingRateIndex)
                Button {
                    Task { await viewModel.sendInfoMemSamplingRate() }
                } label: {
                    Label("Set Sampling Rate", systemImage: "metronome")
                }
                .buttonStyle(ConsensysButtonStyle())
                .disabled(viewModel.isBusy)
            }
        }
    }

    // MARK: - Streaming

    private var streamingPanel: some View {
        ConsensysPanel("Streaming") {
            VStack(alignment: .leading, spacing: ConsensysTheme.space3) {
                Button {
                    Task { await viewModel.sendStartStreamingCommandDev2() }
                } label: {
                    Label("Start Streaming", systemImage: "play.fill")
                }
                .buttonStyle(ConsensysButtonStyle(variant: .accent))
                .disabled(viewModel.isStreaming)

                Button {
                    Task { await viewModel.sendStopStreamingCommandDev2() }
                } label: {
                    Label("Stop Streaming", systemImage: "stop.fill")
                }
                .buttonStyle(ConsensysButtonStyle(variant: .destructive))
                .disabled(!viewModel.isStreaming)
            }
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
