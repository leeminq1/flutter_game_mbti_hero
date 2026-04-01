import 'package:flutter/foundation.dart';

void debugLog(String message) {
  if (!kDebugMode) {
    return;
  }
  debugPrint(message);
}

void debugLogError(String message, Object error) {
  if (!kDebugMode) {
    return;
  }
  debugPrint('$message$error');
}
