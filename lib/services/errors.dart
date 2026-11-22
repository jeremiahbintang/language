import 'package:flutter/foundation.dart';

/// Turns exceptions into short messages for the UI. The raw error is logged
/// (visible with `adb logcat -s flutter`).
String friendlyError(Object e) {
  final s = e.toString();
  debugPrint('Error: $s');
  if (s.contains('SocketException') ||
      s.contains('Failed host lookup') ||
      s.contains('Connection refused') ||
      s.contains('Network is unreachable') ||
      s.contains('XMLHttpRequest error')) {
    return 'Keine Internetverbindung – check your connection and try again.';
  }
  if (s.contains('TimeoutException')) {
    return 'The server took too long – try again.';
  }
  return s.replaceFirst('Exception: ', '');
}
