# marco

Flutter client + Django backend for venue booking.

The repository contains:

- `lib/` – Flutter app (Android/iOS/web/desktop).
- `backend/` – Django project with REST API and admin UI.

## Getting Started

### 1. Start the Django backend

From the repo root:

```bash
cd backend
pip install -r requirements.txt
python manage.py migrate
python manage.py runserver 0.0.0.0:8000
```

On Windows you can run the same commands from PowerShell.

### 2. Run the Flutter app

Make sure you have Flutter installed and in your `PATH`, then from the repo root:

```bash
flutter pub get
flutter run
```

## Run on a USB-connected Android device

1. Boot your Django backend bound to all interfaces so the phone can reach it
   (from the repo root):
   ```bash
   cd backend
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
