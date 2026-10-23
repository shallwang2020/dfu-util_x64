# dfu-util for Android x86_64

This repository contains a cross-build script for a **64-bit Android (x86_64) CLI binary** of `dfu-util`, statically linked with libusb. It requires Linux/macOS build tools and Android NDK r25 or newer; no NDK is bundled.

## Build

```sh
export ANDROID_NDK_HOME=/path/to/android-ndk
# Optional; defaults to API 23
export ANDROID_API=23
./build-android-x86_64.sh
```

The result is `dist/dfu-util`. Copy it to an Android x86_64 device (for example with `adb push dist/dfu-util /data/local/tmp/`) and run:

```sh
adb shell chmod 755 /data/local/tmp/dfu-util
adb shell /data/local/tmp/dfu-util --help
```

Build dependencies on the host: `git`, `make`, `autoconf`, `automake`, `libtool`, `pkg-config`, and a C compiler. The build script checks that the NDK and required tools are present.

## USB access on Android

A successful x86_64 build does **not** ensure that a regular Android shell can access a USB DFU device. `dfu-util` uses libusb's Linux USBFS backend, and access typically requires suitable permissions to `/dev/bus/usb` (often root or a device-specific udev/SELinux configuration). Android's USB Host permission granted to an app is not automatically granted to this command-line process. Confirm USB access on the target device before relying on it for firmware updates.

The source repositories are upstream `dfu-util` and `libusb`; the script checks out their current default branches. For controlled/release builds, pin the two clone revisions in the script to audited commit hashes.
