// Conditional import for dart:io
// Uses dart:io on mobile, stub on web
export 'io_stub_web.dart' if (dart.library.io) 'io_stub_mobile.dart';
