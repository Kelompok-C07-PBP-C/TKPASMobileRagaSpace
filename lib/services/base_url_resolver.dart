import 'base_url_resolver_stub.dart'
    if (dart.library.io) 'base_url_resolver_io.dart'
    if (dart.library.html) 'base_url_resolver_web.dart';

String resolveBaseApiHost() => resolveBaseApiHostImpl();
