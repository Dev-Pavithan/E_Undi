import 'dart:js' as js;

// PWA functions
dynamic installPWA() {
  if (js.context.hasProperty('installPWA')) {
    return js.context.callMethod('installPWA');
  }
  return Future.value(false);
}

bool isPWAInstalled() {
  if (js.context.hasProperty('isPWAInstalled')) {
    return js.context.callMethod('isPWAInstalled') as bool? ?? false;
  }
  return false;
}

bool isPWAPromptReady() {
  if (js.context.hasProperty('isPWAPromptReady')) {
    return js.context.callMethod('isPWAPromptReady') as bool? ?? false;
  }
  return false;
}