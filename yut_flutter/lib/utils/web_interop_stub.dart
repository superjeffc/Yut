import 'dart:async';

void playBackgroundMusic() {}
void pauseBackgroundMusic() {}
void removeLoader() {}
void openExternalUrl(String url) {}
void triggerGoogleAuth(void Function(String) onSuccess, void Function(String) onError) {
  onError("Google Auth via Web interop is not supported on native mobile.");
}
void reloadPage() {}

String getWsUrl(String pathAndParams) {
  return "wss://yut-game.pages.dev$pathAndParams";
}
