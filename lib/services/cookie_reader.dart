import 'cookie_reader_stub.dart'
    if (dart.library.html) 'cookie_reader_web.dart';

String? readCookie(String name) => readCookieImpl(name);
