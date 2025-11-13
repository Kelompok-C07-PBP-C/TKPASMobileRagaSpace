const String _envOverride = String.fromEnvironment('API_BASE_URL');

String resolveBaseApiHostImpl() {
  final override = _normalizeUrl(_envOverride);
  if (override != null) return override;
  final origin = Uri.base.origin;
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
