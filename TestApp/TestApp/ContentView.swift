//
//  ContentView.swift
//  TestApp
//
//  Created by Shimmer Engineering on 19/10/2023.
//
//  Restyled to the "Consensys" design system (Shimmer's desktop instrument
//  UI look). See design spec: consensys-design-spec.md.
//
//  Note on font: the spec's `--cs-font-family` is "Carlito" (metric-compatible
//  with Calibri), which is not bundled with this app and is not one of the
//  system-provided fonts on iOS. We fall back to `.system(...)` (San
//  Francisco) per the spec's own guidance that weight/size/letter-spacing —
//  not the exact glyph shapes — carry the "look" when Carlito isn't bundled.
//
//  Deployment target is iOS 15.0, so only iOS 15-safe APIs are used
//  (e.g. `.kerning()` instead of `Text.tracking()`, which is iOS 16+).
//

import SwiftUI

// MARK: - Consensys Design Tokens

/// Static design tokens (colors, spacing, radius, type scale) lifted from the
/// Consensys design spec's CSS custom properties.
enum ConsensysTheme {

    // MARK: Colors

    static let orange = rgb(0xF1, 0x5D, 0x22)
    static let orangeDeep = rgb(0xD6, 0x66, 0x17)
    static let orangePressed = rgb(0xBB, 0x59, 0x13)
    static let orangeTint = rgb(0xFD, 0xEF, 0xE7)

    static let blue = rgb(0x00, 0x81, 0xC6)
    static let blueDeep = rgb(0x06, 0x45, 0xAD)

    static let surface = rgb(0xFF, 0xFF, 0xFF)
    static let surfaceAlt = rgb(0xF5, 0xF5, 0xF5)

    static let grey100 = rgb(0xEA, 0xEA, 0xEA)
    static let grey150 = rgb(0xE9, 0xE9, 0xE9)
    static let grey200 = rgb(0xE8, 0xE8, 0xE8)
    static let grey300 = rgb(0xD7, 0xD7, 0xD7)

    static let border = rgb(0xD3, 0xD3, 0xD3)
    static let borderStrong = rgb(0xA0, 0xA0, 0xA0)

    static let text = rgb(0x80, 0x80, 0x80)
    static let textMid = rgb(0x8A, 0x8A, 0x8A)
    static let textStrong = rgb(0x48, 0x48, 0x48)
    static let textOnAccent = rgb(0xFF, 0xFF, 0xFF)

    static let greenProgress = rgb(0xC3, 0xD6, 0x9B)
    static let green = rgb(0x7C, 0xAC, 0x7C)
    static let greenTint = rgb(0xE4, 0xF3, 0xE4)
    static let successText = rgb(0x3D, 0x6B, 0x3D)

    static let red = rgb(0xB2, 0x22, 0x22)
    static let redTint = rgb(0xFB, 0xEA, 0xEA)

    static let infoTint = rgb(0xE3, 0xF1, 0xF9)

    private static func rgb(_ r: Int, _ g: Int, _ b: Int) -> Color {
        Color(red: Double(r) / 255.0, green: Double(g) / 255.0, blue: Double(b) / 255.0)
    }

    // MARK: Spacing (px)

    static let space1: CGFloat = 4
    static let space2: CGFloat = 8
    static let space3: CGFloat = 12
    static let space4: CGFloat = 16
    static let space5: CGFloat = 24
    static let space6: CGFloat = 32

    // MARK: Radius

    static let radius: CGFloat = 2
    static let radiusRound: CGFloat = 999

    // MARK: Type scale (px)

    static let textXS: CGFloat = 12
    static let textSM: CGFloat = 13
    static let textMD: CGFloat = 14
    static let textLG: CGFloat = 16
    static let textXL: CGFloat = 18
    static let text2XL: CGFloat = 22
    static let text3XL: CGFloat = 24
}

// MARK: - Consensys Button Style

/// Implements the `cs-button` recipe: uppercase label, 2px radius, 1px
/// border, default/accent/destructive color variants, 0.45 opacity when
/// disabled, orange "pressed" feedback via `configuration.isPressed`.
struct ConsensysButtonStyle: ButtonStyle {

    enum Variant {
        case standard
        case accent
        case destructive
    }

    var variant: Variant = .standard

    func makeBody(configuration: Configuration) -> some View {
        ConsensysButtonBody(configuration: configuration, variant: variant)
    }

    private struct ConsensysButtonBody: View {
        let configuration: ButtonStyleConfiguration
        let variant: Variant
        @Environment(\.isEnabled) private var isEnabled: Bool

        var body: some View {
            let (bg, border, fg) = colors(pressed: configuration.isPressed)
            // Note: `.kerning()` only exists on `Text`, not as a general View
            // modifier (unlike `.textCase`/`.font`/`.foregroundColor`, which
            // propagate via the environment), so it can't be applied here to
            // `configuration.label` (an Image+Text compound view). It's
            // applied directly to the Text in `actionRow` below instead.
            configuration.label
                .font(.system(size: ConsensysTheme.textSM, weight: .semibold))
                .textCase(.uppercase)
                .foregroundColor(fg)
                .padding(.vertical, ConsensysTheme.space2 - 2)
                .padding(.horizontal, ConsensysTheme.space4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(bg)
                .cornerRadius(ConsensysTheme.radius)
                .overlay(
                    RoundedRectangle(cornerRadius: ConsensysTheme.radius)
                        .stroke(border, lineWidth: 1)
                )
                .opacity(isEnabled ? 1.0 : 0.45)
        }

        private func colors(pressed: Bool) -> (Color, Color, Color) {
            switch variant {
            case .standard:
                if pressed {
                    return (ConsensysTheme.surface, ConsensysTheme.orangePressed, ConsensysTheme.orangePressed)
                }
                return (ConsensysTheme.surface, ConsensysTheme.borderStrong, ConsensysTheme.text)
            case .accent:
                if pressed {
                    return (ConsensysTheme.orangePressed, ConsensysTheme.orangePressed, ConsensysTheme.textOnAccent)
                }
                return (ConsensysTheme.orange, ConsensysTheme.orange, ConsensysTheme.textOnAccent)
            case .destructive:
                if pressed {
                    return (ConsensysTheme.red, ConsensysTheme.red, ConsensysTheme.textOnAccent)
                }
                return (ConsensysTheme.surface, ConsensysTheme.red, ConsensysTheme.red)
            }
        }
    }
}

// MARK: - Panel

/// Implements the `cs-panel` recipe: white surface, 1px `--cs-border`
/// hairline, 2px radius, uppercase tracked title row, 16px padding.
struct Panel<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ConsensysTheme.space3) {
            Text(title)
                .font(.system(size: ConsensysTheme.textSM, weight: .bold))
                .kerning(0.5)
                .textCase(.uppercase)
                .foregroundColor(ConsensysTheme.textStrong)

            VStack(alignment: .leading, spacing: ConsensysTheme.space3) {
                content
            }
        }
        .padding(ConsensysTheme.space4)
        .background(ConsensysTheme.surface)
        .cornerRadius(ConsensysTheme.radius)
        .overlay(
            RoundedRectangle(cornerRadius: ConsensysTheme.radius)
                .stroke(ConsensysTheme.border, lineWidth: 1)
        )
    }
}

// MARK: - SectionHeading

/// Implements the `cs-section-heading` recipe: 13px bold uppercase, 0.8px
/// letter-spacing, muted grey (`--cs-text`) — used for sub-groupings inside
/// a Panel (e.g. the InfoMem DisclosureGroup label) rather than the Panel's
/// own title row.
struct SectionHeading: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.system(size: ConsensysTheme.textSM, weight: .bold))
            .kerning(0.8)
            .textCase(.uppercase)
            .foregroundColor(ConsensysTheme.text)
    }
}

// MARK: - StatusBadge

/// Implements the `cs-status-badge` recipe (neutral + success tones only,
/// which is all this screen needs): 12px bold uppercase, square 2px radius,
/// 8px round dot.
struct StatusBadge: View {
    let label: String
    let connected: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(connected ? ConsensysTheme.successText : ConsensysTheme.textStrong)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: ConsensysTheme.textXS, weight: .bold))
                .kerning(0.5)
                .textCase(.uppercase)
                .foregroundColor(connected ? ConsensysTheme.successText : ConsensysTheme.textStrong)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 10)
        .background(connected ? ConsensysTheme.greenTint : ConsensysTheme.grey150)
        .cornerRadius(ConsensysTheme.radius)
    }
}

// MARK: - ContentView

struct ContentView: View {
    @StateObject var viewModel = ViewModel()

    var body: some View {
        // NavigationView's default nav bar is dropped in favor of a
        // Consensys-style custom header bar (uppercase title, white bg,
        // bottom hairline) per the spec's Toolbar recipe. Deployment target
        // remains iOS 15 (no NavigationStack used anywhere).
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: ConsensysTheme.space4) {
                    statusPanel
                    verisenseConnectionPanel
                    verisenseCommandsPanel
                    shimmer3ConnectionPanel
                    shimmer3CommandsPanel
                    activityLogPanel
                }
                .padding(ConsensysTheme.space4)
            }
        }
        .background(ConsensysTheme.surface.ignoresSafeArea())
        .preferredColorScheme(.light)
    }

    // MARK: - Header (Toolbar recipe)

    private var header: some View {
        HStack {
            Text("Shimmer Device Demo")
                .font(.system(size: ConsensysTheme.textLG, weight: .bold))
                .kerning(0.5)
                .textCase(.uppercase)
                .foregroundColor(ConsensysTheme.textStrong)
            Spacer()
        }
        .padding(.horizontal, ConsensysTheme.space4)
        .padding(.vertical, ConsensysTheme.space3)
        .background(ConsensysTheme.surface)
        .overlay(
            Rectangle()
                .fill(ConsensysTheme.border)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Panels

    private var statusPanel: some View {
        Panel("Status") {
            HStack {
                StatusBadge(label: "Dev1 (Verisense)", connected: viewModel.isDev1Connected)
                Spacer()
                StatusBadge(label: "Dev2 (Shimmer3)", connected: viewModel.isDev2Connected)
            }
            HStack {
                Text(viewModel.statusMessage)
                    .font(.system(size: ConsensysTheme.textMD))
                    .foregroundColor(ConsensysTheme.text)
                Spacer()
                if viewModel.isScanning {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: ConsensysTheme.orange))
                }
            }
        }
    }

    private var verisenseConnectionPanel: some View {
        Panel("Connection — Verisense (Dev1)") {
            actionRow("Scan for Verisense", systemImage: "antenna.radiowaves.left.and.right", disabled: viewModel.isScanning) {
                viewModel.test()
            }
            actionRow("Connect", systemImage: "link", variant: .accent, disabled: viewModel.isDev1Connected) {
                Task { await viewModel.connect() }
            }
            actionRow("Disconnect", systemImage: "xmark.circle", variant: .destructive, disabled: !viewModel.isDev1Connected) {
                Task { await viewModel.disconnect() }
            }
        }
    }

    private var verisenseCommandsPanel: some View {
        Panel("Device Commands — Verisense (Dev1)") {
            actionRow("Read Production Info", systemImage: "info.circle", disabled: !viewModel.isDev1Connected) {
                Task { await viewModel.sendReadProductionCommand() }
            }
            actionRow("Speed Test", systemImage: "speedometer", disabled: !viewModel.isDev1Connected) {
                Task { await viewModel.sendSpeedTestCommand() }
            }
        }
    }

    private var shimmer3ConnectionPanel: some View {
        Panel("Connection — Shimmer3 (Dev2)") {
            actionRow("Scan for Shimmer3", systemImage: "antenna.radiowaves.left.and.right", disabled: viewModel.isScanning) {
                viewModel.scanShimmer3()
            }
            actionRow("Connect", systemImage: "link", variant: .accent, disabled: viewModel.isDev2Connected) {
                Task { await viewModel.connectDev2() }
            }
            actionRow("Disconnect", systemImage: "xmark.circle", variant: .destructive, disabled: !viewModel.isDev2Connected) {
                Task { await viewModel.disconnectDev2() }
            }
        }
    }

    private var shimmer3CommandsPanel: some View {
        Panel("Device Commands — Shimmer3 (Dev2)") {
            actionRow("Start Streaming", systemImage: "play.fill", disabled: !viewModel.isDev2Connected) {
                Task { await viewModel.sendStartStreamingCommandDev2() }
            }
            actionRow("Stop Streaming", systemImage: "stop.fill", disabled: !viewModel.isDev2Connected) {
                Task { await viewModel.sendStopStreamingCommandDev2() }
            }
            DisclosureGroup {
                VStack(alignment: .leading, spacing: ConsensysTheme.space3) {
                    actionRow("IMU", systemImage: "square.and.pencil", disabled: !viewModel.isDev2Connected) {
                        Task { await viewModel.sendInfoMemIMU() }
                    }
                    actionRow("Accel", systemImage: "square.and.pencil", disabled: !viewModel.isDev2Connected) {
                        Task { await viewModel.sendInfoMemAccel() }
                    }
                    actionRow("ECG", systemImage: "square.and.pencil", disabled: !viewModel.isDev2Connected) {
                        Task { await viewModel.sendInfoMemECG() }
                    }
                    actionRow("EMG", systemImage: "square.and.pencil", disabled: !viewModel.isDev2Connected) {
                        Task { await viewModel.sendInfoMemEMG() }
                    }
                    actionRow("EXG Test", systemImage: "square.and.pencil", disabled: !viewModel.isDev2Connected) {
                        Task { await viewModel.sendInfoMemEXGTest() }
                    }
                    actionRow("Respiration", systemImage: "square.and.pencil", disabled: !viewModel.isDev2Connected) {
                        Task { await viewModel.sendInfoMemRespiration() }
                    }
                }
                .padding(.top, ConsensysTheme.space2)
            } label: {
                SectionHeading("Write InfoMem (Advanced)")
            }
        }
    }

    private var activityLogPanel: some View {
        Panel("Activity Log") {
            if viewModel.activityLog.isEmpty {
                Text("No activity yet")
                    .font(.system(size: ConsensysTheme.textXS, design: .monospaced))
                    .foregroundColor(ConsensysTheme.text)
            } else {
                VStack(alignment: .leading, spacing: ConsensysTheme.space1) {
                    ForEach(Array(viewModel.activityLog.prefix(10).enumerated()), id: \.offset) { _, entry in
                        Text(entry)
                            .font(.system(size: ConsensysTheme.textXS, design: .monospaced))
                            .foregroundColor(ConsensysTheme.text)
                    }
                }
                .padding(ConsensysTheme.space2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ConsensysTheme.surfaceAlt)
                .cornerRadius(ConsensysTheme.radius)
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func actionRow(
        _ title: String,
        systemImage: String,
        variant: ConsensysButtonStyle.Variant = .standard,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .frame(width: 16, height: 16)
                Text(title)
                    .kerning(0.5)
            }
        }
        .buttonStyle(ConsensysButtonStyle(variant: variant))
        .disabled(disabled)
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
