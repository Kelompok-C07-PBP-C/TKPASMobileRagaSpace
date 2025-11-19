const String _envOverride = String.fromEnvironment('API_BASE_URL');

String resolveBaseApiHostImpl() {
  final override = _normalizeUrl(_envOverride);
  if (override != null) return override;

  final uri = Uri.base;

  // When running the Flutter web dev server locally, the app is usually
  // served from a random localhost port (e.g. http://localhost:60307),
  // while the Django backend runs on http://localhost:8000. In that case
  // we want API calls to go to port 8000, not the dev server port.
  if ((uri.host == 'localhost' || uri.host == '127.0.0.1') && uri.port != 8000) {
    return 'http://localhost:8000';
  }

  final origin = uri.origin;
  return origin.isNotEmpty ? origin : 'http://localhost:8000';
}

String? _normalizeUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  return 'http://$trimmed';
}
