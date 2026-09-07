# Soundbar

Windows-style per-app volume mixer for macOS, living in the menu bar.

Built for Apple Silicon (M3 Pro) on macOS 14.2+ using the modern
CoreAudio Process Tap API — no virtual driver install, no reboot.

- `MenuBarExtra` popover: master volume, output picker, per-app sliders 0-200%, mute
- Live detection via `kAudioHardwarePropertyProcessObjectList` + `IsRunningOutput`
- Real gain via `AudioHardwareCreateProcessTap` (`CATapMutedWhenTapped`) + private aggregate + realtime `IOProc`
- Persists per-app volume/mute by bundleID

## Status

- Phase 1 (mock UI): done — `SOUNDBAR_ENGINE=mock`
- Phase 2 (live detection + master volume, no taps): default
- Phase 3 (real per-app gain): `SOUNDBAR_ENGINE=tap`, requires macOS 14.2+ and
  System Audio permission (Settings > Privacy & Security > Screen & System Audio Recording)

BackgroundMusic-style HAL drivers are intentionally not used — fragile on
Sequoia/Tahoe, GPL, admin install. See plan in issues.

## Requirements

- macOS 14.2+ (26 Tahoe recommended), Apple Silicon
- Xcode 16+ with macOS 26 SDK for the menu-bar app, or Swift 6 toolchain for `SoundbarCore`
- `NSAudioCaptureUsageDescription` — already in `Resources/Info.plist`

## Build

```bash
# core + tests (works with Command Line Tools only)
swift build
swift test

# run UI (needs Xcode — SPM executable hosts the MenuBarExtra app)
SOUNDBAR_ENGINE=mock swift run Soundbar
SOUNDBAR_ENGINE=detector swift run Soundbar
SOUNDBAR_ENGINE=tap swift run Soundbar   # real taps, will prompt for System Audio permission
```

To make a distributable `.app`:
1. Open in Xcode: `File > New > Project > macOS App`, add `Sources/` files,
   or `swift package generate-xcodeproj` (legacy).
2. Set `LSUIElement=true`, Hardened Runtime, Developer ID sign.
3. Include `Resources/Info.plist` (`NSAudioCaptureUsageDescription`) and
   `Resources/Soundbar.entitlements`.
4. Notarize for Tahoe or Gatekeeper will block tap creation prompts.

## How it works

```
MenuBarExtra (.window)
 -> AudioEngine (Mock / Detector / Tap)
   -> ProcessDetector: procList -> pid -> NSRunningApplication name/icon
   -> DeviceManager: default output UID, master volume, device switch
   -> TapFactory (14.2+): CATapDescription(stereoMixdownOfProcesses:[proc])
        uuid, .mutedWhenTapped, isPrivate
      -> AudioHardwareCreateAggregateDevice(tapUUID + outputUID, private, drift-comp)
      -> AudioDeviceCreateIOProcIDWithBlock: out = clamp(in * gain)
```

Taps are created lazily only when an app needs non-100% / mute, so the
orange recording indicator stays off otherwise. Device switch rebuilds aggregates.

## Permissions

First tap triggers the system prompt. If denied, errors surface as
`kAudioHardwareIllegalOperationError` with instructions to enable
Settings > Privacy & Security > Screen & System Audio Recording.
No private TCC SPI is used (App-Store safe pattern).

## Repo layout

- `Sources/SoundbarCore/`: `Models`, `GainMath`, `RingBuffer`, `PersistenceStore`,
  `ProcessDetector`, `DeviceManager`, `AudioEngine`, `MockEngine`, `DetectorEngine`,
  `ProcessTap` (`TapFactory`), `TapEngine`
- `Sources/Soundbar/`: `MixerApp`, `MixerView`, `AppRowView`
- `Tests/SoundbarTests/`: gain math, ring buffer, persistence
- `Resources/`: Info.plist, entitlements

## Roadmap

- [x] Phase 1 mock UI
- [x] Phase 2 live detection
- [x] Phase 3 tap skeleton (needs on-device validation with permission granted)
- [ ] Default-output change listener (instant rebuild vs 1s poll)
- [ ] RMS meters from IOProc, headphone hot-swap hardening
- [ ] Launch at Login (`SMAppService`), hide-list settings, boost warning
- [ ] Developer ID signing + notarization + Sparkle updates
