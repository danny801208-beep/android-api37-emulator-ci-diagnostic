# Ready-to-post upstream comments

These comments are intentionally app-agnostic and contain only the public diagnostic findings from this repository.

## actions/runner-images #14484

Issue: https://github.com/actions/runner-images/issues/14484

```markdown
I was able to reproduce an additional failure mode related to the `android-37.0` / `target=android-0` issue on a GitHub-hosted Ubuntu 24.04 runner and verify the fix with an A/B test.

Environment:
- Ubuntu 24.04 GitHub-hosted runner
- Android Emulator 37.1.11
- API 37.0
- `google_apis;x86_64`
- `-gpu software`

Baseline with Command-line Tools 12.0:
- created AVD metadata: `target=android-0`
- emulator eventually reached `sys.boot_completed=1`
- SurfaceFlinger was still unstable
- during an approximately three-minute observation window:
  - `surfaceflinger_pid_changed=1`
  - `surfaceflinger_missing_samples=2`
  - `crash_signature_lines=76`

Representative recurring crash:

```text
Fatal signal 6 (SIGABRT)
thread: RegionSampling
process: surfaceflinger
Abort message: 'Assertion failed: !rcEnc->featureInfo()->hasReadColorBufferDma'
/vendor/lib64/hw/mapper.ranchu.so
GoldfishMapper::readFromHost
```

I then explicitly pinned Android SDK Command-line Tools 22.0 and recreated the same API 37 AVD.

Fixed case:
- AVD metadata: `target=android-37.0`
- same API level, architecture, Emulator 37.1.11 and software GPU configuration
- during the same observation window:
  - `surfaceflinger_pid_changed=0`
  - `surfaceflinger_missing_samples=0`
  - `crash_signature_lines=0`

So in this CI configuration the old tools did more than produce incorrect AVD metadata: the `target=android-0` case correlated with a reproducible `SurfaceFlinger -> RegionSampling -> mapper.ranchu -> hasReadColorBufferDma -> SIGABRT` crash loop.

Pinning Command-line Tools 22.0 corrected the target and eliminated the observed crash in the A/B test.

One additional CI lesson: `sys.boot_completed=1` alone was not sufficient to detect this failure, because SurfaceFlinger could keep restarting after Android reported boot completion.

Full sanitized reproduction workflow and diagnostic notes:
https://github.com/danny801208-beep/android-api37-emulator-ci-diagnostic
```

## ReactiveCircus/android-emulator-runner #482

Issue: https://github.com/ReactiveCircus/android-emulator-runner/issues/482

```markdown
I reproduced and A/B tested a concrete API 37 failure mode that may be useful for this issue and for PR #483.

Environment:
- GitHub-hosted Ubuntu 24.04 runner
- Android Emulator 37.1.11
- API 37.0
- `google_apis;x86_64`
- `-gpu software`

With Command-line Tools 12.0, AVD creation silently produced:

```text
target=android-0
```

The emulator could still reach `sys.boot_completed=1`, but SurfaceFlinger repeatedly crashed.

During an approximately three-minute observation window:

```text
surfaceflinger_pid_changed=1
surfaceflinger_missing_samples=2
crash_signature_lines=76
```

Representative crash:

```text
Fatal signal 6 (SIGABRT)
thread: RegionSampling
process: surfaceflinger
Abort message: 'Assertion failed: !rcEnc->featureInfo()->hasReadColorBufferDma'
/vendor/lib64/hw/mapper.ranchu.so
GoldfishMapper::readFromHost
```

After explicitly pinning Command-line Tools 22.0 and recreating the same API 37 AVD:

```text
target=android-37.0
surfaceflinger_pid_changed=0
surfaceflinger_missing_samples=0
crash_signature_lines=0
```

The rest of the tested configuration remained the same.

This suggests the Command-line Tools update in PR #483 is not only important for correct `android-37.0` metadata. In this CI configuration it also fixed a reproducible SurfaceFlinger crash loop associated with the incorrectly created `android-0` AVD.

A useful guard is to validate the AVD metadata immediately after creation and fail unless API 37 produces `target=android-37.0`.

Also, `sys.boot_completed=1` alone was not enough to detect the failure because SurfaceFlinger could continue restarting after boot completion.

Full sanitized reproduction workflow and A/B notes:
https://github.com/danny801208-beep/android-api37-emulator-ci-diagnostic
```
