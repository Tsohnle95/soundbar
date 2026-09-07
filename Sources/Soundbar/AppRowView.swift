import SwiftUI
import SoundbarCore
import AppKit

struct AppRowView: View {
    var app: AppAudioInfo
    var engine: any AudioEngine

    var body: some View {
        HStack(spacing: 8) {
            appIcon
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(app.appName)
                    .font(.callout)
                    .lineLimit(1)
                Slider(value: Binding(
                    get: { app.isMuted ? 0 : app.volume },
                    set: { engine.setVolume($0, for: app.pid) }
                ), in: 0...2)
                .disabled(app.isMuted)
            }
            Text("\(Int((app.volume * 100).rounded()))%")
                .font(.caption.monospacedDigit())
                .frame(width: 44, alignment: .trailing)
                .foregroundStyle(app.volume > 1.0 ? .orange : .primary)
            Button {
                engine.setMuted(!app.isMuted, for: app.pid)
            } label: {
                Image(systemName: app.isMuted ? "speaker.slash.fill" : "speaker.fill")
            }
            .buttonStyle(.plain)
        }
        .opacity(app.isMuted ? 0.6 : 1.0)
    }

    @ViewBuilder
    private var appIcon: some View {
        if let bid = app.bundleID,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
        } else if let running = NSRunningApplication(processIdentifier: app.pid) {
            Image(nsImage: running.icon ?? NSImage())
                .resizable()
        } else {
            Image(systemName: "app.fill")
                .resizable()
        }
    }
}
