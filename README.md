# wow-ios

[![Build unsigned IPA](actions/workflows/build-ipa.yml/badge.svg)](../../actions/workflows/build-ipa.yml)
![platform](https://img.shields.io/badge/iOS-18%2B%20%C2%B7%20tested%20on%2026-black)
![swift](https://img.shields.io/badge/Swift-5-orange)
![license](https://img.shields.io/badge/license-MIT-black)

**Wallpapers, Live Photos and a tweaks bench for iPhone — built from scratch, no third-party binary involved.**

wow-ios imports your own clips, turns them into proper paired Live Photos, loops them seamlessly, exports the master file at full quality with nothing burned in, and ships a tweaks tab that removes the Liquid Glass look from everything the app owns. Wallpaper packs can also stream over a port exposed by a local dev VPN, so the phone pulls from your own machine instead of a cloud account.

---

## Why the Live Photo dance

iOS only accepts a *video* wallpaper as a Live Photo: a still JPEG plus a MOV that share one `com.apple.quicktime.content.identifier`. wow-ios writes both, so the result behaves like an Apple-bought live wallpaper instead of a plain video.

* Frames are copied through a **passthrough** `AVAssetReader`/`AVAssetWriter` — no re-encode, no watermark, no downscale, 4K stays 4K.
* Trimming cuts through an `AVMutableComposition` so timing is re-based to zero (no dead air at the start).
* The pair is saved with `PHAssetCreationRequest` as `.photo` + `.pairedVideo`.

**iOS does not let an app set the wallpaper.** No public API exists. wow-ios finishes the file, saves it, and walks you through Settings → Wallpaper → Add New Wallpaper → Photos. There is no fake "apply" switch pretending otherwise.

## Feature matrix

| | |
|---|---|
| **Wallpapers** | 6 animated `MeshGradient` presets · photo import (1080/1440/2160 ceiling) · MP4/MOV → Live Photo · trim with two sliders · seamless loop via `AVPlayerLooper` · pause loops in Low Power Mode · safe-area/clock guides |
| **Preset studio** | Build a gradient from three colours + motion speed, preview live, save it, export at 1179×2556, re-edit any saved gradient |
| **Export** | HD master copy, untouched or metadata-stripped · export vault keeps the last 40 exports for re-sharing · share sheet to Files/AirDrop/Messages |
| **Library** | Search across titles/tags · favourites · sort by newest/A–Z/HD · sections for presets, custom gradients, dev packs and imports · long-press menus |
| **Dev link** | Plain HTTP to `host:port` over your tunnel · `/api/manifest` plus byte-for-byte file streaming · Range requests · pull one pack or all of them · `wowios://connect?host=&port=` deep link for QR codes |
| **Tweaks** | 18 tweaks, live · neutralize Liquid Glass · kill bar blur · hairlines · square corners · no motion · compact density · AMOLED black · mint accent · guides · loop defaults · auto Live Photo · auto-trim · keep resolution · strip metadata · auto-connect · plus two injection rows |
| **Profiles** | Save the current tweak set under a name and reapply it in one tap |
| **Injection** | Exports a JSON profile for the SpringBoard-owned chrome (Dock, Control Center, system apps) that no sandboxed app can patch |

## Chrome: how the glass actually goes away

1. `UIDesignRequiresCompatibility` in `Info.plist` opts the app out of the iOS 26 Liquid Glass redesign.
2. `ChromeSurface` / `ChromeBars` stop asking for `.ultraThinMaterial` and paint an opaque fill with a hairline edge instead — nothing glassy renders anywhere in the app.
3. SpringBoard chrome is another process. Those rows are labelled **Injection** and write `wowios-injection-profile.json` for your dev VPN tweak loader, exported from the Tweaks tab.

Details per tweak: [docs/TWEAKS.md](docs/TWEAKS.md).

## Build

```bash
open WowIos.xcodeproj      # Xcode 16+, iOS 18 deployment target
```

Pick your team under *Signing & Capabilities* and run. `Info.plist` already carries the photo-library, local-network and URL-scheme keys.

### Cloud build (no Mac needed)

The workflow [.github/workflows/build-ipa.yml](.github/workflows/build-ipa.yml) builds on a macOS runner and uploads an **unsigned IPA** — the format a dev VPN / sideload tool re-signs with your certificate.

```bash
bash tools/publish.sh            # init + commit + push to the build repo
```

Repo → **Actions** → *Build unsigned IPA* → download **WowIos-unsigned-ipa** → sign and install. Red run? Grab the **build-log** artifact.

Tag a release (`git tag v1 && git push --tags`) and [release.yml](.github/workflows/release.yml) attaches the IPA to a GitHub Release instead.

## Dev server

```bash
python server/devserver.py --port 8787           # serve server/library
python server/devserver.py --demo --port 8787    # seed demo gradient packs
python tools/make_samples.py                     # optional ffmpeg demo clips
```

```
server/library/
  aurora-loop/
    pack.json      optional: title, kind, author, tags, trimStart/trimEnd, allowDownload, hd
    preview.jpg    required thumbnail
    video.mp4      master clip, served byte for byte
    still.jpg      optional paired still
```

`GET /api/manifest` → `{version, name, packs[]}`; files support `Range` (206). Bind is `0.0.0.0`, so forward the port through your tunnel and enter that host in the app.

## Layout

```
WowIos/
  App/         WowIosApp (deep links), RootView (tabs, welcome)
  Core/        AppSettings (persisted), Tweak catalog, Theme, DevLink, LocalLibrary + export vault,
               Models, ColorHex, StudioModels, Haptics
  Core/Media/  LivePhotoBuilder, LoopVideoView, ShareSheet
  Features/    Wallpapers (library, detail, import, presets), Studio, Tweaks, DevLink, Settings, Welcome
  Components/  pills, buttons, cards, thumbnails, lock-screen guides
server/ devserver.py    tools/ publish.sh · make_icon.py · make_samples.py · check_swift_balance.py
```

## Status

Verified here: the dev server (manifest, Range/206, 404s, traversal rejection, pack builder), Info.plist and asset-catalog parsing, scheme/blueprint consistency, Python compilation, and a delimiter pass over every Swift file. The Xcode build itself runs on GitHub Actions — the first run caught and fixed a real compile error, so the pipeline is the source of truth.

Not verified: on-device behaviour. The Live Photo pipeline, Photos saving and haptics need a real iPhone.

## License

MIT — see [LICENSE](LICENSE).
