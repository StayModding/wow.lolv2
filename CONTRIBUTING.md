# Contributing

Bug reports and pull requests are welcome. Two rules keep this repo buildable:

1. **It has to compile with no signing.** CI builds with `CODE_SIGNING_ALLOWED=NO`, on a stock macOS runner, using only public iOS 18+ APIs.
2. **No pretending.** If iOS cannot do something (setting the wallpaper, patching SpringBoard), the UI says so and offers the real workaround. Dead switches are a bug.

## Local loop

```bash
python tools/check_swift_balance.py     # cheap structural check before pushing
python server/devserver.py --demo       # wallpaper server on :8787
open WowIos.xcodeproj                   # Xcode 16+
```

Pushing to `main` runs the unsigned-IPA workflow; download the `build-log` artifact if it goes red.

## Adding a tweak

1. New case in `TweakID`.
2. Row in `TweakCatalog.all` with a group, scope and `defaultOn`.
3. Map it into `AppSettings.theme` (visual) or branch on `settings.isOn(...)` in the pipeline.
4. Injection-scoped tweaks must also appear in `AppSettings.injectionProfile()`.

The Tweaks screen builds itself from the catalog, so there is no separate UI to wire.

## Code style

Small files, one job each. Comments explain *why* something is done the hard way (Live Photo pairing, passthrough transcoding, SpringBoard limits) rather than restating the code.
