import 'dart:js' as js;

/// Check if the screenshot security JavaScript object is available
bool hasScreenshotSecurity() {
  return js.context.hasProperty('screenshotSecurity');
}

/// Call the JavaScript function to enable screenshot security
void callScreenshotSecurityEnable() {
  js.context.callMethod('screenshotSecurity.enable');
}

/// Call the JavaScript function to disable screenshot security
void callScreenshotSecurityDisable() {
  js.context.callMethod('screenshotSecurity.disable');
}
