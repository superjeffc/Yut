import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;

void playBackgroundMusic() {
  try {
    js.context.callMethod('playBackgroundMusic');
  } catch (_) {}
}

void pauseBackgroundMusic() {
  try {
    js.context.callMethod('pauseBackgroundMusic');
  } catch (_) {}
}

void removeLoader() {
  try {
    js.context.callMethod('removeLoader');
  } catch (_) {}
}

void openExternalUrl(String url) {
  try {
    js.context.callMethod('open', [url]);
  } catch (_) {}
}

void triggerGoogleAuth(void Function(String) onSuccess, void Function(String) onError) {
  try {
    final successCallback = js.allowInterop((String resultStr) {
      onSuccess(resultStr);
    });
    final errorCallback = js.allowInterop((String errorMsg) {
      onError(errorMsg);
    });
    js.context.callMethod('triggerGoogleAuth', [successCallback, errorCallback]);
  } catch (e) {
    onError(e.toString());
  }
}

void reloadPage() {
  try {
    html.window.location.reload();
  } catch (_) {}
}

String getWsUrl(String pathAndParams) {
  final wsProtocol = html.window.location.protocol == "https:" ? "wss:" : "ws:";
  final host = html.window.location.host;
  return "$wsProtocol//$host$pathAndParams";
}
