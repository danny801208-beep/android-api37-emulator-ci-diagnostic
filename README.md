# Android API 37 Emulator SurfaceFlinger Crash on GitHub Actions

A sanitized, app-agnostic investigation of an Android API 37 (`android-37.0`) AVD issue on GitHub-hosted Ubuntu runners.

The key finding was that an older Android SDK Command-line Tools / `avdmanager` could silently create an API 37 AVD with:

```text
target=android-0
```

instead of:

```text
target=android-37.0
```

In the tested environment, the incorrectly created AVD correlated with a repeatable SurfaceFlinger crash loop involving `RegionSampling`, `mapper.ranchu`, and `hasReadColorBufferDma`. Recreating the same AVD with Command-line Tools 22.0 corrected the target and eliminated the observed crash during the same diagnostic window.

> This repository documents one reproducible CI configuration. It does **not** claim that every API 37 emulator crash has this root cause.

## Environment

Observed in September 2026 with:

- GitHub-hosted Ubuntu 24.04 runner
- Android Emulator 37.1.11
- Android API 37.0
- `system-images;android-37.0;google_apis;x86_64`
- headless emulator
- software GPU / gfxstream path
- 2 virtual CPU cores
- 4096 MB RAM

## Symptom

The emulator could eventually report:

```text
sys.boot_completed=1
```

while SurfaceFlinger was still unstable and restarting.

Representative crash signature:

```text
Fatal signal 6 (SIGABRT)
thread: RegionSampling
process: surfaceflinger

Abort message:
Assertion failed: !rcEnc->featureInfo()->hasReadColorBufferDma

/vendor/lib64/hw/mapper.ranchu.so
GoldfishMapper::readFromHost
```

The important lesson is that `sys.boot_completed=1` alone is not always sufficient to establish emulator health for graphics-sensitive instrumentation runs.

## A/B result

The same API level, architecture, emulator version, GPU mode, RAM and disk settings were compared with different Android SDK Command-line Tools versions.

| Check | Baseline | Fixed |
|---|---:|---:|
| Command-line Tools | 12.0 | 22.0 |
| AVD target | `android-0` | `android-37.0` |
| SurfaceFlinger PID changed during observation | Yes | No |
| Samples where SurfaceFlinger was missing | 2 | 0 |
| Matching crash-signature lines | 76 | 0 |
| `hasReadColorBufferDma` observed | Yes | No |

The observation window was approximately three minutes after boot.

## What was happening

API 37 introduced a `Major.Minor` package identifier:

```text
android-37.0
```

Older Command-line Tools releases can silently mis-handle this format when `avdmanager` creates the AVD and write:

```text
target=android-0
```

instead of the expected API target.

In this tested environment the broken metadata coincided with an unstable graphics stack:

```text
SurfaceFlinger
  -> RegionSampling
  -> mapper.ranchu
  -> GoldfishMapper::readFromHost
  -> hasReadColorBufferDma assertion
  -> SIGABRT
```

After pinning Command-line Tools 22.0 and recreating the AVD, the metadata became:

```text
target=android-37.0
```

and the same crash signature was not observed during the diagnostic window.

## Recommended fix

For API 37 CI jobs:

1. Pin an Android SDK Command-line Tools version that correctly supports `android-37.0`.
2. Command-line Tools 22.0 was verified in this test.
3. Delete any AVD that was created by the older tools.
4. Recreate the API 37 AVD.
5. Validate the AVD metadata **before** launching the emulator.
6. Fail fast if the target is not `android-37.0`.
7. After boot, verify SurfaceFlinger stability in addition to checking `sys.boot_completed`.

Google's SDK documentation also recommends choosing a specific Command-line Tools version in scripts so that automation does not change unexpectedly when `latest` moves.

## Useful CI guards

Check the AVD target immediately after creation:

```bash
grep -R '^target=' "$ANDROID_AVD_HOME"
```

Expected for API 37:

```text
target=android-37.0
```

Treat this as invalid:

```text
target=android-0
```

After boot, confirm SurfaceFlinger exists:

```bash
adb shell pidof surfaceflinger
```

Useful crash-signature search:

```bash
adb logcat -d | grep -E \
  'hasReadColorBufferDma|mapper\.ranchu|RegionSampling|SIGABRT'
```

## Reproduction workflow

This repository includes a manually triggered GitHub Actions workflow:

```text
.github/workflows/api37-diagnostic.yml
```

It compares two explicitly pinned toolchains:

- Command-line Tools 12.0 (`11076708`)
- Command-line Tools 22.0 (`15859902`)

The workflow intentionally does not depend on whichever Command-line Tools version happens to be preinstalled on the runner that day.

Run it from **Actions -> API 37 AVD Diagnostic -> Run workflow**.

Because Android system images and emulator packages continue to change over time, the exact SurfaceFlinger crash may stop reproducing in a future image. The AVD `target=` comparison is still useful for demonstrating the old `avdmanager` parsing behavior.

## Why RAM, disk and boot timeout were misleading

Before identifying the AVD target problem, several common emulator explanations can look plausible:

- insufficient RAM
- insufficient `/data` space
- slow boot
- application instrumentation failure
- generic GPU instability

Those checks are still useful, but in this case they did not explain why API 35 was stable while API 37 repeatedly failed before application tests could run.

Inspecting the AVD metadata and performing a controlled A/B test isolated the tooling difference much more effectively than continuing to change unrelated emulator resources.

## Lessons learned

- `sys.boot_completed=1` does not necessarily mean the Android graphics stack is healthy.
- Validate AVD metadata in CI, especially when Android introduces a new package-version format.
- Pin build and SDK tooling used by reproducible automation.
- Separate application failures from guest OS / emulator / CI infrastructure failures.
- Prefer controlled single-variable A/B experiments over repeatedly changing RAM, disk, timeouts and GPU flags together.
- Preserve exact crash signatures; they are often what allows the next developer to find the relevant upstream issue.

## Upstream context

Related public discussions and the comments that link back to this reproducible case:

- GitHub runner-images issue #14484 — Command-line Tools versions and `Major.Minor` AVD targets:  
  https://github.com/actions/runner-images/issues/14484
  - Published A/B reproduction comment:  
    https://github.com/actions/runner-images/issues/14484#issuecomment-5915589950
- ReactiveCircus/android-emulator-runner issue #482 — API 37.0 support:  
  https://github.com/ReactiveCircus/android-emulator-runner/issues/482
  - Published A/B reproduction comment:  
    https://github.com/ReactiveCircus/android-emulator-runner/issues/482#issuecomment-5915604980
- ReactiveCircus/android-emulator-runner PR #483 — update SDK Command-line Tools to 22.0:  
  https://github.com/ReactiveCircus/android-emulator-runner/pull/483
- Android SDK Command-line Tools documentation:  
  https://developer.android.com/tools/sdkmanager
- Android Emulator release notes:  
  https://developer.android.com/studio/releases/emulator

## Scope and privacy

This repository intentionally contains no application source code, product information, private repository references, private workflow URLs, credentials, API keys, application IDs or organization-specific data.

It is only a minimal technical reproduction and diagnostic record for the Android emulator / CI behavior described above.

## License

MIT License. See [LICENSE](LICENSE).
