# marco

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Run on a USB-connected Android device

1. Boot your Django backend bound to all interfaces so the phone can reach it:
   ```bash
   python manage.py runserver 0.0.0.0:8000
   ```
2. Plug in the device, enable developer mode, and confirm it shows up:
   ```powershell
   adb devices
   ```
3. Tunnel the backend port through the USB cable (rerun after unplugging):
   ```powershell
   adb reverse tcp:8000 tcp:8000
   ```
4. Launch Flutter with the USB loopback flag so Android uses `127.0.0.1:8000`:
   ```powershell
   flutter run --dart-define=USE_USB_DEVICE_LOOPBACK=true
   ```

Pointing at another host/port? Pass `--dart-define=API_BASE_URL=http://192.168.0.5:9000` instead (works for mobile, web, desktop). Cleartext HTTP is already enabled in the Android manifest, so you can iterate without extra config.
