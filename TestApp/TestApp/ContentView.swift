//
//  ContentView.swift
//  TestApp
//
//  Created by Shimmer Engineering on 19/10/2023.
//

import SwiftUI

struct ContentView: View {
    @StateObject var viewModel = ViewModel()

    var body: some View {
        // NavigationView (not NavigationStack) — app deployment target is iOS 15.
        NavigationView {
            List {
                statusSection
                verisenseConnectionSection
                verisenseCommandsSection
                shimmer3ConnectionSection
                shimmer3CommandsSection
                activityLogSection
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Shimmer Device Demo")
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Sections

    private var statusSection: some View {
        Section(header: Text("Status")) {
            HStack {
                statusBadge(label: "Dev1 (Verisense)", connected: viewModel.isDev1Connected)
                Spacer()
                statusBadge(label: "Dev2 (Shimmer3)", connected: viewModel.isDev2Connected)
            }
            HStack {
                Text(viewModel.statusMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                if viewModel.isScanning {
                    ProgressView()
                }
            }
        }
    }

    private var verisenseConnectionSection: some View {
        Section(header: Text("Connection — Verisense (Dev1)")) {
            actionRow("Scan for Verisense", systemImage: "antenna.radiowaves.left.and.right", disabled: viewModel.isScanning) {
                viewModel.test()
            }
            actionRow("Connect", systemImage: "link", disabled: viewModel.isDev1Connected) {
                Task { await viewModel.connect() }
            }
            actionRow("Disconnect", systemImage: "xmark.circle", disabled: !viewModel.isDev1Connected) {
                Task { await viewModel.disconnect() }
            }
        }
    }

    private var verisenseCommandsSection: some View {
        Section(header: Text("Device Commands — Verisense (Dev1)")) {
            actionRow("Read Production Info", systemImage: "info.circle", disabled: !viewModel.isDev1Connected) {
                Task { await viewModel.sendReadProductionCommand() }
            }
            actionRow("Speed Test", systemImage: "speedometer", disabled: !viewModel.isDev1Connected) {
                Task { await viewModel.sendSpeedTestCommand() }
            }
        }
    }

    private var shimmer3ConnectionSection: some View {
        Section(header: Text("Connection — Shimmer3 (Dev2)")) {
            actionRow("Scan for Shimmer3", systemImage: "antenna.radiowaves.left.and.right", disabled: viewModel.isScanning) {
                viewModel.scanShimmer3()
            }
            actionRow("Connect", systemImage: "link", disabled: viewModel.isDev2Connected) {
                Task { await viewModel.connectDev2() }
            }
            actionRow("Disconnect", systemImage: "xmark.circle", disabled: !viewModel.isDev2Connected) {
                Task { await viewModel.disconnectDev2() }
            }
        }
    }

    private var shimmer3CommandsSection: some View {
        Section(header: Text("Device Commands — Shimmer3 (Dev2)")) {
            actionRow("Start Streaming", systemImage: "play.fill", disabled: !viewModel.isDev2Connected) {
                Task { await viewModel.sendStartStreamingCommandDev2() }
            }
            actionRow("Stop Streaming", systemImage: "stop.fill", disabled: !viewModel.isDev2Connected) {
                Task { await viewModel.sendStopStreamingCommandDev2() }
            }
            DisclosureGroup("Write InfoMem (Advanced)") {
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
        }
    }

    private var activityLogSection: some View {
        Section(header: Text("Activity Log")) {
            if viewModel.activityLog.isEmpty {
                Text("No activity yet")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(viewModel.activityLog.prefix(10).enumerated()), id: \.offset) { _, entry in
                    Text(entry)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func actionRow(_ title: String, systemImage: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
        }
        .disabled(disabled)
    }

    private func statusBadge(label: String, connected: Bool) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(connected ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color(.secondarySystemBackground))
        )
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
