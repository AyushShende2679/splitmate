// Platform helper for web/mobile conditional code
// On web, dart:io is not available, so we provide stubs

import 'package:flutter/foundation.dart' show kIsWeb;

bool get isMobilePlatform => !kIsWeb;
