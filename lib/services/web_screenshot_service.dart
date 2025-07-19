import 'package:flutter/foundation.dart';

// Conditional import for web platform
import 'web_screenshot_service_web.dart'
    if (dart.library.io) 'web_screenshot_service_stub.dart';

class WebScreenshotService {
  static final WebScreenshotService _instance =
      WebScreenshotService._internal();
  factory WebScreenshotService() => _instance;
  WebScreenshotService._internal();

  bool _isEnabled = false;

  /// Initialize the web screenshot service
  Future<void> initialize() async {
    if (!kIsWeb) return;

    // Wait for the JavaScript to be loaded
    await Future.delayed(const Duration(milliseconds: 500));

    // Check if the JavaScript security object is available
    if (hasScreenshotSecurity()) {
      _isEnabled = true;
      debugPrint('Web screenshot security initialized and enabled');
    } else {
      debugPrint('Web screenshot security not available');
    }
  }

  /// Enable screenshot blocking for web
  Future<void> enable() async {
    if (!kIsWeb) return;

    try {
      // Call the JavaScript function directly
      if (hasScreenshotSecurity()) {
        callScreenshotSecurityEnable();
        _isEnabled = true;
        debugPrint('Web screenshot blocking enabled');
      } else {
        debugPrint('Web screenshot blocking functions not available');
      }
    } catch (e) {
      debugPrint('Failed to enable web screenshot blocking: $e');
    }
  }

  /// Disable screenshot blocking for web
  Future<void> disable() async {
    if (!kIsWeb) return;

    try {
      // Call the JavaScript function directly
      if (hasScreenshotSecurity()) {
        callScreenshotSecurityDisable();
        _isEnabled = false;
        debugPrint('Web screenshot blocking disabled');
      } else {
        debugPrint('Web screenshot blocking functions not available');
      }
    } catch (e) {
      debugPrint('Failed to disable web screenshot blocking: $e');
    }
  }

  /// Check if web screenshot blocking is enabled
  bool get isEnabled => _isEnabled;

  /// Toggle screenshot blocking
  Future<void> toggle() async {
    if (_isEnabled) {
      await disable();
    } else {
      await enable();
    }
  }
}
