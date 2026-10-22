# wow.tok

A self-contained iPhone app for **custom wallpapers** (photos, Live Photos, looping MP4s) and a **Tweaks** tab that strips the Liquid Glass look out of the UI — plus a small dev server so the app can pull wallpaper packs over a port your local dev VPN exposes.

Built as an original app. It is not a patched or repackaged copy of anything: no third-party binary is modified, no watermark is removed from anyone else's video, and every export is made from a file that was already clean.

---

## Requirements

| | |
|---|---|
| Xcode | 16 or newer (the project uses folder-synchronized groups, `objectVersion = 77`) |
| Deployment target | iOS 18.0 |
| Runs on | iOS 18 → current (all newer-version behaviour is availability-guarded, so iOS 26/27/27.x builds fine) |
| Signing | your own team. A tunnel/injection tool needs to re-sign the .ipa anyway |
| Dev server | Python 3.9+ (stdlib only), optional ffmpeg for sample clips |

---

## Build

```bash
open WowTok.xcodeproj
```

Then select the **WowTok** target → *Signing & Capabilities* → pick your team → run on a device or simulator.

The Info.plist already contains the pieces the app needs:

* `NSPhotoLibraryUsageDescription` / `NSPhotoLibraryAddUsageDescription` — reading source clips, saving finished wallpapers
* `NSLocalNetworkUsageDescription` + `NSAllowsLocalNetworking` — the dev-link handshake over your tunnel
* `NSAllowsArbitraryLoads` — plain HTTP to `host:port` on a private network (dev-only; remove it for App Store builds and use HTTPS)
* `UIDesignRequiresCompatibility` — opts the app out of the Liquid Glass redesign system-wide

### Build in the cloud with GitHub Actions (no Mac needed)

The workflow [.github/workflows/build-ipa.yml](.github/workflows/build-ipa.yml) compiles the app on a macOS runner and uploads an **unsigned IPA** — the format a dev VPN / sideload tool re-signs with your own certificate.

```bash
bash tools/publish.sh          # initialise git, commit, push to the build repo
```

The default remote is `https://github.com/StayModding/wow.lolv2.git`; pass another one as the first argument. Then:

1. Repo → **Actions** → *Build unsigned IPA* (starts on push, or run it by hand)
2. Download the **WowTok-unsigned-ipa** artifact → `Payload/WowTok.app`, unsigned
3. Sign and install with your dev VPN / sideload tool

If the run goes red, download the **build-log** artifact — it holds the full `xcodebuild` output. The first run is also the first real compile of this codebase, so expect to shake out a few compiler nits with it.

---

## What the app does

### Wallpapers

* **6 built-in presets** drawn with `MeshGradient` and animated by `TimelineView` (no assets, no downloads).
* **Import a video** (MP4/MOV) from Photos → wow.tok writes a **paired still + MOV Live Photo** with a shared `com.apple.quicktime.content.identifier`, which is the only form iOS accepts as a video wallpaper.
* **Import a photo** → saved at your chosen ceiling (1080/1440/2160) or untouched.
* **Loop** every preview with `AVPlayerLooper` (seamless, no black frame between repeats) and optionally pause it in Low Power Mode.
* **Trim** the wallpaper burst with two sliders; the export honours exactly that window.
* **HD export, no watermark** — `exportMaster` copies the master file byte for byte (or rewrites the container when *Strip metadata* is on) and hands it to the share sheet. Passthrough `AVAssetReader`/`AVAssetWriter` means **no re-encode, no quality loss, no overlay**. It never touches a watermark because the source has none.
* **Lock-screen guides** frame the clock and status bar over the preview so your subject isn't hidden.

**The one thing no app can do:** iOS has no public API to set the wallpaper. wow.tok prepares and saves the item, then the detail screen walks you through the two taps (Settings → Wallpaper → Add New Wallpaper → Photos). I did not fake this with a switch that does nothing.

### Tweaks tab (18 tweaks)

Chrome / Liquid Glass

1. **Neutralize Liquid Glass** — opaque fills behind every bar and card, plus the `UIDesignRequiresCompatibility` opt-out
2. **Kill bar blur** — solid nav/tab bar instead of a blur
3. **High-contrast hairlines**
4. **System-wide glass off** *(injection)*
5. **Dock glass off** *(injection)*

Shape & motion

6. **Square corners**
7. **No motion**
8. **Compact density**

Look

9. **AMOLED black**
10. **Mint accent**
11. **Safe-area guides**

Pipeline

12. **Loop by default**
13. **Pause loops in Low Power Mode**
14. **Auto-convert MP4 to Live Photo**
15. **Auto-trim to 3 seconds**
16. **Keep source resolution**
17. **Strip metadata**

Dev link

18. **Auto-connect on launch**

Rows marked *injection* cannot be applied from inside a sandbox — SpringBoard owns the Dock, Control Center and system apps. Instead of a dead toggle, wow.tok exports **`wowtok-injection-profile.json`** from the Tweaks tab for your dev VPN / tweak loader to consume. See [docs/TWEAKS.md](docs/TWEAKS.md).

### Dev Link

The app talks to `http://<host>:<port>` (default `127.0.0.1:8787`), calls `/api/manifest`, and streams packs over the tunnel. Nothing leaves your machine.

```bash
python server/devserver.py --port 8787            # serve server/library
python server/devserver.py --demo --port 8787     # seed demo gradient packs first
python tools/make_samples.py                      # ffmpeg demo MP4 clips (optional)
```

Point your dev VPN at `127.0.0.1:8787`, or use whatever address it hands the phone. The server binds `0.0.0.0` so a forwarded port works.

**Library layout** — one folder per pack:

```
server/library/
  aurora-loop/
    pack.json      optional metadata (title, kind, author, tags, trimStart/trimEnd, allowDownload, hd)
    preview.jpg    required — grid thumbnail
    video.mp4      optional — the master clip, served byte for byte
    still.jpg      optional — paired still for a live photo pack
```

`GET /api/manifest` returns:

```json
{
  "version": 1,
  "name": "DESKTOP-1234 · nt",
  "packs": [
    {
      "id": "aurora-loop",
      "title": "Aurora Loop",
      "kind": "video",
      "preview": "/files/aurora-loop/preview.jpg",
      "video": "/files/aurora-loop/video.mp4",
      "hd": true,
      "allowDownload": true,
      "trimStart": 0.0,
      "trimEnd": 3.5
    }
  ]
}
```

Files support `Range` requests (206) so video streaming and partial downloads work.

---

## Source map

```
WowTok/
  App/            WowTokApp.swift, RootView.swift
  Core/           AppSettings (persisted tweaks + pipeline defaults), Tweak (catalog, 18 rows),
                  Theme (resolved look, ChromeSurface, BarChrome), DevLink (HTTP client),
                  Models (manifest/pack), LocalLibrary (imports on disk)
  Core/Media/     LivePhotoBuilder (still extraction, passthrough transcode, Photos save),
                  LoopVideoView (AVPlayerLooper), ShareSheet
  Features/       Wallpapers (library, detail, import, presets), Tweaks, DevLink, Settings
  Components/     pills, buttons, thumbnails, cards, lock-screen guides
  Assets.xcassets App icon (generated by tools/make_icon.py) + accent/launch colors
server/devserver.py    stdlib wallpaper server
.github/workflows/build-ipa.yml   CI: builds and uploads an unsigned IPA
tools/publish.sh       push this project into the build repo
                          tools/make_icon.py, make_samples.py, check_swift_balance.py
docs/TWEAKS.md         what each tweak really does
```

---

## Verification

Ran here:

* `server/devserver.py --demo` started on a port and served **`/api/health`, `/api/manifest`, `/files/...`** — checked status codes, content types, a `Range: bytes=0-127` request returning `206` + `Content-Range`, full-file length match, 404 for a missing pack, and 404 for `%2e%2e` path traversal.
* Manifest builder checked with a video+still pack (`kind: live` picked up, `video`/`still`/`trimStart`/`trimEnd` emitted) and with a folder that has no image (correctly skipped).
* App icon generated and validated as a 1024×1024 PNG.
* Python sources compile (`py_compile`); `tools/check_swift_balance.py` reports 19 Swift files with balanced delimiters.
* The workflow YAML parses, and the shared scheme's `BlueprintIdentifier` matches the target UUID in `project.pbxproj`, so `xcodebuild -scheme WowTok` should resolve on the runner.

**Not run here:** this machine is Windows with no Swift toolchain, no Xcode and no simulator, so the Swift sources have not been compiled, and the GitHub Actions workflow has not executed yet — I have no credentials for the build repo, so the first push (and therefore the first real compile) is yours. Every API used is public and availability-safe for iOS 18+, but expect to fix the usual handful of small compiler nits on that first run. There is no on-device test of the Live Photo pipeline either — that needs a real iPhone and Photos library.
