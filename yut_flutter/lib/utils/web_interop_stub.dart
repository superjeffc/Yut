import 'dart:async';
import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';

AudioPlayer? _bgPlayer;

void playBackgroundMusic() async {
  try {
    if (_bgPlayer == null) {
      _bgPlayer = AudioPlayer();
      await _bgPlayer!.setReleaseMode(ReleaseMode.loop);
      await _bgPlayer!.play(AssetSource('audio/song.mp3'));
    } else {
      await _bgPlayer!.resume();
    }
  } catch (e) {
    print("Audio error: $e");
  }
}

void pauseBackgroundMusic() async {
  try {
    await _bgPlayer?.pause();
  } catch (_) {}
}

void removeLoader() {}

void openExternalUrl(String url) async {
  try {
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  } catch (e) {
    print("URL Launch Error: $e");
  }
}

void triggerGoogleAuth(void Function(String) onSuccess, void Function(String) onError) async {
  try {
    final GoogleSignIn googleSignIn = GoogleSignIn(
      serverClientId: "223698446706-nf21ero1897j813o81db0nsmsrhavojs.apps.googleusercontent.com",
      scopes: ['email', 'profile'],
    );
    try {
      await googleSignIn.signOut();
    } catch (_) {}
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
