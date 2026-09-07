import SwiftUI
import SoundbarCore
import AppKit

struct MixerView: View {
    var engine: any AudioEngine
    @State private var tick = 0 // forces refresh when engine notifies via holder

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Divider()
            if engine.apps.isEmpty {
                Text("No apps making sound right now.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(engine.apps) { app in
                    AppRowView(app: app, engine: engine)
                }
            }
            if let err = engine.tapError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            footer
        }
        .padding(12)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "speaker.wave.2.fill")
                Text("Soundbar").font(.headline)
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.link)
                    .font(.caption)
            }
            // Output picker
            if !engine.devices.isEmpty {
                Picker("Output", selection: Binding(
                    get: { engine.devices.first(where: { $0.isDefault })?.id ?? 0 },
                    set: { id in if let d = engine.devices.first(where: { $0.id == id }) { engine.selectOutputDevice(d) } }
                )) {
                    ForEach(engine.devices) { d in
                        Text(d.name).tag(d.id)
                    }
                }
                .pickerStyle(.menu)
                .font(.caption)
            }
            // Master
            HStack {
                Button {
                    engine.setMasterVolume(engine.masterVolume > 0 ? 0 : 1.0)
                } label: {
                    Image(systemName: engine.masterVolume == 0 ? "speaker.slash.fill" : "speaker.fill")
                }
                .buttonStyle(.plain)
                Slider(value: Binding(
                    get: { engine.masterVolume },
                    set: { engine.setMasterVolume($0) }
                ), in: 0...1)
                Text("\(Int((engine.masterVolume * 100).rounded()))%")
                    .font(.caption.monospacedDigit())
                    .frame(width: 40, alignment: .trailing)
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Refresh") { engine.refresh() }
                .font(.caption)
            Spacer()
            Text("per-app volume")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
