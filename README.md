# PrimeEye

A native macOS **notch app**: a **posture warner** that nudges you in the notch when you slouch,
plus a small **glanceable HUD** you can wire to any data source. Pure Apple frameworks, **zero
third-party dependencies**, built from scratch so every line is auditable (it uses the camera).

## Features

- **Posture warner** - on-device `Vision` body-pose at ~3fps. Calibrates your upright baseline on
  first run, then a solid pulsing amber→red banner nudges you in the notch when you slouch (glow
  @5s, "Sit up straight" @20s, clears on recovery). It pauses and stops counting when you step away
  from the Mac. **Frames are never stored or sent anywhere** - all processing is local and live.
- **Glanceable HUD** - a small status readout in the notch: collapsed by default, hover to peek,
  click to expand. It renders whatever an `AppState` provider fills in. The shipped
  `ExampleDataProvider` shows static sample values; **swap in your own** to glance at anything you
  like (see below).

## Requirements

- macOS 13 (Ventura) or later. Designed for Macs with a notch; degrades to a faux top-center HUD on
  notch-less displays.
- Xcode / Swift toolchain (Swift 5.9+).

## Build & run

```bash
git clone https://github.com/primeline-ai/PrimeEye.git
cd PrimeEye
./create-signing-identity.sh   # once: stable self-signed cert so the camera grant survives rebuilds
swift test                     # run the unit tests
./make-app.sh                  # build + bundle + sign PrimeEye.app
open PrimeEye.app              # grant camera on first run, sit upright to calibrate
```

First real run: grant the camera permission, hold an upright pose ~5s to calibrate, then it
monitors. Menu-bar eye icon: Recalibrate · Toggle posture · Start at login · Quit.

> The self-signed identity is optional but recommended: without a stable code signature, macOS
> re-prompts for the camera permission on every rebuild. `make-app.sh` falls back to ad-hoc signing
> if no identity exists.

## Start / Stop

`scripts/start-primeeye.command` and `scripts/stop-primeeye.command` are double-clickable. Stop kills
the process and fully releases the camera (handy before closing the lid); Start re-opens the app.
They look for `PrimeEye.app` at the repo root, then `/Applications`, then `~/Applications`.

## Wire your own HUD data

The HUD binds to fields on `AppState` (intents count, a label, a fitness value, a "next" item, a
usage string, plus `dataLive`/`dataStale` honesty flags). A provider just fills those fields.

`Sources/PrimeEye/ExampleDataProvider.swift` is a ~30-line static example. To show real data, copy
it and poll a file, hit an API, or read a system metric on a timer, then write the values onto
`AppState` (on the main actor). `AppDelegate` constructs the provider - point it at yours. The
posture warner is fully independent of this; the HUD is the optional second half.

## Verify without the UI

```bash
PRIMEEYE_DEMO_STAGE=message open PrimeEye.app   # render the nudge UI with no camera (glow|message)
```

## Architecture

- `Sources/PrimeEyeKit/` - pure, unit-tested logic: posture metrics, the warning state machine,
  daily stats, calibration, notch geometry. No AppKit/AVFoundation, so it's testable in isolation.
- `Sources/PrimeEye/` - the AppKit/SwiftUI/Vision/AVFoundation glue: notch window, camera monitor,
  menu bar, the SwiftUI view, and the HUD data provider.
- Frameworks: AppKit, SwiftUI, Vision, AVFoundation, ServiceManagement, Foundation. Nothing else.

### Privacy

The camera feed is processed frame-by-frame on-device by `Vision` to estimate body pose. No frame is
ever written to disk or transmitted. Posture stats kept on disk are just daily aggregate counts.

## License

MIT - see [LICENSE](LICENSE).
