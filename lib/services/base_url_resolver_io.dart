import 'dart:io';

const String _envOverride = String.fromEnvironment('API_BASE_URL');
const bool _preferUsbLoopback =
    bool.fromEnvironment('USE_USB_DEVICE_LOOPBACK', defaultValue: false);

// Clean, hard-coded production host used when no override is supplied.
const String _defaultProductionHost =
    'https://tirta-rendy-ragaspace.pbp.cs.ui.ac.id';

String resolveBaseApiHostImpl() {
  final override = _normalizeUrl(_envOverride);
  if (override != null) return override;

  // In day-to-day development you can still point to a local backend by
  // supplying API_BASE_URL via --dart-define. For non-overridden builds we
  // default to the deployed production host so that installed APKs "just work".
  if (Platform.isAndroid || Platform.isIOS) {
    return _defaultProductionHost;
  }

  // Desktop / CLI defaults – still usable for local testing.
  if (Platform.isMacOS) {
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