const String _envOverride = String.fromEnvironment('API_BASE_URL');

// Match the mobile default so tests and other non-web/non-io platforms use
// the same production host unless explicitly overridden.
const String _defaultProductionHost =
    'https://tirta-rendy-ragaspace.pbp.cs.ui.ac.id';

String resolveBaseApiHostImpl() =>
    _normalizeUrl(_envOverride) ?? _defaultProductionHost;

String? _normalizeUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  return 'http://$trimmed';
}
