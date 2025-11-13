import 'dart:io';

const String _envOverride = String.fromEnvironment('API_BASE_URL');
const bool _preferUsbLoopback =
    bool.fromEnvironment('USE_USB_DEVICE_LOOPBACK', defaultValue: false);

String resolveBaseApiHostImpl() {
  final override = _normalizeUrl(_envOverride);
  if (override != null) return override;

  if (Platform.isAndroid) {
    if (_preferUsbLoopback) {
      // Works with `adb reverse tcp:8000 tcp:8000`, allowing devices to reach
      // the host dev server via their own loopback interface.
      return 'http://127.0.0.1:8000';
    }
    return 'http://10.0.2.2:8000';
  }
  if (Platform.isIOS || Platform.isMacOS) {
    return 'http://127.0.0.1:8000';
  }
  return 'http://localhost:8000';
}

String? _normalizeUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  return 'http://$trimmed';
}
