# Build environment (macOS)

- **Last updated:** 2026-08-23
- Set up on this machine on 2026-08-23; `flutter doctor` Android toolchain went from ✗ to ✓.

## What was installed

| Piece | Where | Why |
|---|---|---|
| `android-commandlinetools` (Homebrew cask) | `/opt/homebrew/share/android-commandlinetools` | No Android Studio on this machine; the CLI tools are enough to build |
| `platform-tools`, `platforms;android-36`, `build-tools;36.0.0` | under the SDK root | Flutter 3.41.7 defaults to `compileSdk 36` / `targetSdk 36` |
| CMake 3.22.1 | under the SDK root | Pulled in automatically by the first Gradle build |
| `openjdk@21` (Homebrew) | `/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home` | **The system JDK is 25, which AGP rejects** — see below |

## Flutter config (already applied, persists)

```
flutter config --android-sdk /opt/homebrew/share/android-commandlinetools
flutter config --jdk-dir /opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
```

`ANDROID_HOME` is **not** set in the shell profile. Flutter's own config covers `flutter build`;
export it manually if invoking `sdkmanager`/`adb` directly:

```
export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools
export PATH="$ANDROID_HOME/platform-tools:$PATH"
```

## Two failures worth remembering

### 1. `FAILURE: Build failed with an exception. * What went wrong: 25.0.2`

The entire error message is a version number. It means the JDK is too new for the Android Gradle
Plugin — the system JDK here is **25**, and AGP supports 17–21. Fixed by installing `openjdk@21` and
pointing Flutter at it with `--jdk-dir`. **Do not** `brew link openjdk@21` globally; the Flutter
setting is enough and leaves the rest of the system on 25.

### 2. `Dependency ':flutter_local_notifications' requires core library desugaring`

Fails at `:app:checkDebugAarMetadata`. The plugin uses `java.time`, which does not exist below API
26, so the build needs desugaring turned on. Fixed permanently in `android/app/build.gradle.kts`:

```kotlin
compileOptions {
    isCoreLibraryDesugaringEnabled = true
    ...
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

This is a **Gradle** dependency, not a pubspec one — no new Dart packages were added.

## Running it yourself

Every command below is run from the repo root. `ANDROID_HOME` is not exported in your shell
profile, but `flutter run`/`flutter build` do not need it — Flutter's own config already knows where
the SDK is.

### On the Mac (fastest loop — no phone needed)

```
flutter run -d macos
```

Hot reload with `r`, hot restart with `R`, quit with `q`. This is the one to use while iterating on
UI.

To just launch the last build without rebuilding:

```
open build/macos/Build/Products/Debug/gymflow.app
```

And to close it:

```
pkill -f gymflow.app
```

### On the phone

Plug it in with USB debugging on, then:

```
flutter devices          # confirm the phone is listed
flutter run -d <device>  # hot reload against the phone
```

Or sideload a built APK — see Building below.

### Checking what the app actually stored

The macOS build's database is a plain SQLite file:

```
sqlite3 ~/Library/Containers/dev.ishan.gymflow/Data/Documents/gymflow.sqlite \
  "SELECT name FROM exercises LIMIT 5;"
sqlite3 ~/Library/Containers/dev.ishan.gymflow/Data/Documents/gymflow.sqlite \
  "PRAGMA user_version;"      # schema version
```

### Tests and static analysis

```
flutter test               # whole suite
flutter test <path>        # one file
flutter analyze
```

## Building

```
flutter build apk --release     # ~63 MB, ~75s warm
flutter build apk --debug       # ~159 MB
flutter build macos --debug     # desktop, useful for quick UI checks
```

Output: `build/app/outputs/flutter-apk/app-release.apk`.

**The release APK is signed with the debug key** (`android/app/build.gradle.kts`, `buildTypes.release`).
Fine for sideloading onto one device; it means the APK cannot be updated over a differently-signed
build, and is not distributable.

## macOS desktop build — a caveat

Handy for clicking through UI without a phone, but it uses a **separate database** at
`~/Library/Containers/dev.ishan.gymflow/Data/Documents/gymflow.sqlite`. It is not the phone's data,
so it proves behaviour, not your real migration.

## Revision log
- 2026-08-23 — created after setting up the Android toolchain from scratch.
