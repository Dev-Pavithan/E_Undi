import 'dart:js' as js;

// PWA functions with null safety
dynamic installPWA() {
  if (js.context.hasProperty('installPWA')) {
    return js.context.callMethod('installPWA');
  }
  return Future.value(false);
}

bool isPWAInstalled() {
  if (js.context.hasProperty('isPWAInstalled')) {
    try {
      return js.context.callMethod('isPWAInstalled') as bool? ?? false;
    } catch (e) {
      return false;
    }
  }
  return false;
}

bool isPWAPromptReady() {
  if (js.context.hasProperty('isPWAPromptReady')) {
    try {
      return js.context.callMethod('isPWAPromptReady') as bool? ?? false;
    } catch (e) {
      return false;
    }
  }
  return false;
}