const String _envOverride = String.fromEnvironment('API_BASE_URL');

String resolveBaseApiHostImpl() =>
    _normalizeUrl(_envOverride) ?? 'http://localhost:8000';

String? _normalizeUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  return 'http://$trimmed';
}
