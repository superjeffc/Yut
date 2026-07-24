export 'web_interop_stub.dart'
    if (dart.library.js_interop) 'web_interop_web.dart'
    if (dart.library.html) 'web_interop_web.dart';
