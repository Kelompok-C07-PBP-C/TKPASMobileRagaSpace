import 'dart:html' as html;

String? readCookieImpl(String name) {
  final raw = html.document.cookie;
  if (raw == null || raw.trim().isEmpty) return null;

  final prefix = '$name=';
  for (final chunk in raw.split(';')) {
    final trimmed = chunk.trim();
    if (!trimmed.startsWith(prefix)) continue;
    final value = trimmed.substring(prefix.length);
    if (value.isEmpty) return null;
    return Uri.decodeComponent(value);
  }
  return null;
}
