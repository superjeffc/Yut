import 'dart:async';
import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';

void playBackgroundMusic() {}
void pauseBackgroundMusic() {}
void removeLoader() {}
void openExternalUrl(String url) {}

void triggerGoogleAuth(void Function(String) onSuccess, void Function(String) onError) async {
  try {
    final GoogleSignIn googleSignIn = GoogleSignIn(
      clientId: "223698446706-bsii8tatf0giceemon51hj50c7u2pvn9.apps.googleusercontent.com",
      serverClientId: "223698446706-nf21ero1897j813o81db0nsmsrhavojs.apps.googleusercontent.com",
      scopes: ['email', 'profile'],
    );
    final account = await googleSignIn.signIn();
    if (account == null) {
      onError("Sign in cancelled by user.");
      return;
    }
    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null || idToken.isEmpty) {
      onError("Failed to retrieve Google ID Token.");
      return;
    }
    onSuccess(jsonEncode({
      "token": idToken,
      "email": account.email,
      "name": account.displayName ?? "Player",
    }));
  } catch (e) {
    onError("Google Sign-In Error: $e");
  }
}

void reloadPage() {}

String getWsUrl(String pathAndParams) {
  return "wss://yut-game.pages.dev$pathAndParams";
}
