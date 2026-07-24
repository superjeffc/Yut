import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Shop {
  static final Shop instance = Shop._internal();
  
  Shop._internal();

  SharedPreferences? _prefs;
  bool _initialized = false;
  final Map<String, dynamic> _fallbackStorage = {};

  final Map<String, int> costs = {
    "Seal": 0,
    "Penguin": 0,
    "Rabbit": 10,
    "Bird": 10,
    "Hedgehog": 10,
    "Fennec-Fox": 10,
    "Polar-Bear": 50,
    "Leopard": 60,
    "Husky": 100,
  };

  // Maps display name to the file prefix used in PNG assets
  final Map<String, String> assetPrefixes = {
    "Seal": "seal",
    "Penguin": "penguin",
    "Rabbit": "rabbit",
    "Bird": "bird",
    "Hedgehog": "hedgehog",
    "Fennec-Fox": "fennecfox",
    "Polar-Bear": "polarbear",
    "Leopard": "leopard",
    "Husky": "husky",
  };

  String playerAnimals = "Seal Penguin";
  String lastSavedAnimals = "Seal Penguin";

  Future<void> initializeShop() async {
    if (_initialized) return;
    try {
      // Set a 1.5 second timeout on SharedPreferences initialization
      _prefs = await SharedPreferences.getInstance().timeout(
        const Duration(milliseconds: 1500),
        onTimeout: () => throw TimeoutException("SharedPreferences timed out"),
      );

      // Default unlocks
      if (_prefs!.getInt("Seal") == null) _prefs!.setInt("Seal", 1);
      if (_prefs!.getInt("Penguin") == null) _prefs!.setInt("Penguin", 1);
      if (_prefs!.getInt("coins") == null) _prefs!.setInt("coins", 0);

      playerAnimals = _prefs!.getString("animals") ?? "Seal Penguin";
      lastSavedAnimals = playerAnimals;
    } catch (e) {
      // Bypasses cookie block and iframe policy blocks on storage
      playerAnimals = "Seal Penguin";
      lastSavedAnimals = playerAnimals;
      _fallbackStorage["Seal"] = 1;
      _fallbackStorage["Penguin"] = 1;
      _fallbackStorage["coins"] = 999; // Default coins fallback
    } finally {
      _initialized = true;
    }
  }

  // Gets the asset path for a static animal image given a stack value (1 to 4)
  String getImagePath(String animal, int stackValue) {
    String prefix = assetPrefixes[animal] ?? "seal";
    return "assets/images/${prefix}${stackValue}jump1.png";
  }

  // Gets the list of asset paths for jump animation frames given a stack value (1 to 4)
  List<String> getJumpFrames(String animal, int stackValue) {
    String prefix = assetPrefixes[animal] ?? "seal";
    return [
      "assets/images/${prefix}${stackValue}jump1.png",
      "assets/images/${prefix}${stackValue}jump2.png",
      "assets/images/${prefix}${stackValue}jump3.png",
      "assets/images/${prefix}${stackValue}jump2.png",
    ];
  }

  // Gets the goal (finish line) image path
  String getGoalImagePath(String animal) {
    String prefix = assetPrefixes[animal] ?? "seal";
    return "assets/images/${prefix}_goal.png";
  }

  // Gets the player icon image path
  String getIconImagePath(String animal) {
    String prefix = assetPrefixes[animal] ?? "seal";
    return "assets/images/${prefix}_icon.png";
  }

  int getCoins() {
    if (_prefs != null) {
      try {
        return _prefs!.getInt("coins") ?? 0;
      } catch (_) {}
    }
    return _fallbackStorage["coins"] as int? ?? 0;
  }

  void addCoins(int amount) {
    int current = getCoins();
    int newValue = current + amount;
    _fallbackStorage["coins"] = newValue;
    if (_prefs != null) {
      try {
        _prefs!.setInt("coins", newValue);
      } catch (_) {}
    }
  }

  bool isUnlocked(String animal) {
    if (_prefs != null) {
      try {
        return (_prefs!.getInt(animal) ?? 0) != 0;
      } catch (_) {}
    }
    return (_fallbackStorage[animal] as int? ?? 0) != 0;
  }

  bool makePurchase(String animal) {
    int cost = costs[animal] ?? 0;
    int coins = getCoins();

    if (coins >= cost && !isUnlocked(animal)) {
      _fallbackStorage[animal] = 1;
      _fallbackStorage["coins"] = coins - cost;
      if (_prefs != null) {
        try {
          _prefs!.setInt(animal, 1);
          _prefs!.setInt("coins", coins - cost);
        } catch (_) {}
      }
      syncWithCloud();
      return true;
    }
    return false;
  }

  List<String> getLockedAvatars() {
    return costs.keys.where((animal) => !isUnlocked(animal)).toList();
  }

  List<String> getUnlockedAvatars() {
    return costs.keys.where((animal) => isUnlocked(animal)).toList();
  }

  List<String> getSelectedAnimals() {
    var list = playerAnimals.trim().split(RegExp(r'\s+'));
    if (list.length < 2) {
      if (list.isEmpty || list[0].isEmpty) {
        list = ["Seal", "Penguin"];
      } else {
        list = [list[0], list[0] == "Seal" ? "Penguin" : "Seal"];
      }
      playerAnimals = "${list[0]} ${list[1]}";
    }
    return list.take(2).toList();
  }

  void switchAvatars() {
    var selected = getSelectedAnimals();
    playerAnimals = "${selected[1]} ${selected[0]}";
  }

  void resetSelection() {
    playerAnimals = lastSavedAnimals;
  }

  Future<void> saveAvatars() async {
    _fallbackStorage["animals"] = playerAnimals;
    if (_prefs != null) {
      try {
        await _prefs!.setString("animals", playerAnimals);
      } catch (_) {}
    }
    lastSavedAnimals = playerAnimals;
  }

  void changeAvatar(int playerIndex, String animal) {
    var selected = getSelectedAnimals();
    if (playerIndex == 0) {
      playerAnimals = "$animal ${selected[1]}";
    } else {
      playerAnimals = "${selected[0]} $animal";
    }
  }

  bool getSoundEnabled() {
    if (_prefs != null) {
      try {
        return _prefs!.getBool("sound") ?? true;
      } catch (_) {}
    }
    return _fallbackStorage["sound"] as bool? ?? true;
  }

  void setSoundEnabled(bool enabled) {
    _fallbackStorage["sound"] = enabled;
    if (_prefs != null) {
      try {
        _prefs!.setBool("sound", enabled);
      } catch (_) {}
    }
  }

  // Stats tracking
  int getGames() {
    if (_prefs != null) {
      try {
        return _prefs!.getInt("games") ?? 0;
      } catch (_) {}
    }
    return _fallbackStorage["games"] as int? ?? 0;
  }

  void incrementGames() {
    int current = getGames();
    int newValue = current + 1;
    _fallbackStorage["games"] = newValue;
    if (_prefs != null) {
      try {
        _prefs!.setInt("games", newValue);
      } catch (_) {}
    }
    syncWithCloud();
  }

  int getWins() {
    if (_prefs != null) {
      try {
        return _prefs!.getInt("wins") ?? 0;
      } catch (_) {}
    }
    return _fallbackStorage["wins"] as int? ?? 0;
  }

  void incrementWins() {
    int current = getWins();
    int newValue = current + 1;
    _fallbackStorage["wins"] = newValue;
    if (_prefs != null) {
      try {
        _prefs!.setInt("wins", newValue);
      } catch (_) {}
    }
    syncWithCloud();
  }

  int getLosses() {
    if (_prefs != null) {
      try {
        return _prefs!.getInt("losses") ?? 0;
      } catch (_) {}
    }
    return _fallbackStorage["losses"] as int? ?? 0;
  }

  void incrementLosses() {
    int current = getLosses();
    int newValue = current + 1;
    _fallbackStorage["losses"] = newValue;
    if (_prefs != null) {
      try {
        _prefs!.setInt("losses", newValue);
      } catch (_) {}
    }
    syncWithCloud();
  }

  // Account Linking
  String? getLinkedEmail() {
    if (_prefs != null) {
      try {
        return _prefs!.getString("linked_email");
      } catch (_) {}
    }
    return _fallbackStorage["linked_email"] as String?;
  }

  String? getLinkedName() {
    if (_prefs != null) {
      try {
        return _prefs!.getString("linked_name");
      } catch (_) {}
    }
    return _fallbackStorage["linked_name"] as String?;
  }

  String? getLinkedToken() {
    if (_prefs != null) {
      try {
        return _prefs!.getString("linked_token");
      } catch (_) {}
    }
    return _fallbackStorage["linked_token"] as String?;
  }

  void linkAccount(String email, String name, String token) {
    _fallbackStorage["linked_email"] = email;
    _fallbackStorage["linked_name"] = name;
    _fallbackStorage["linked_token"] = token;
    if (_prefs != null) {
      try {
        _prefs!.setString("linked_email", email);
        _prefs!.setString("linked_name", name);
        _prefs!.setString("linked_token", token);
      } catch (_) {}
    }
  }

  void unlinkAccount() {
    _fallbackStorage.remove("linked_email");
    _fallbackStorage.remove("linked_name");
    _fallbackStorage.remove("linked_token");
    if (_prefs != null) {
      try {
        _prefs!.remove("linked_email");
        _prefs!.remove("linked_name");
        _prefs!.remove("linked_token");
      } catch (_) {}
    }
  }

  Future<bool> deleteAccountAndCloudData() async {
    String? email = getLinkedEmail();
    unlinkAccount();

    if (email != null && email.isNotEmpty) {
      try {
        await http.post(
          Uri.parse("/api/auth?action=delete_account"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"email": email}),
        ).timeout(const Duration(seconds: 5));
        return true;
      } catch (_) {}
    }
    return true;
  }

  Future<bool> syncWithCloud() async {
    String? token = getLinkedToken();
    if (token == null) return false;

    try {
      final response = await http.post(
        Uri.parse("/api/auth?action=google"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "token": token,
          "coins": getCoins(),
          "unlockedAnimals": getUnlockedAvatars().join(" "),
          "games": getGames(),
          "wins": getWins(),
          "losses": getLosses(),
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true) {
          int remoteCoins = data["coins"] ?? 0;
          String remoteAnimalsStr = data["unlockedAnimals"] ?? "Seal Penguin";
          int remoteGames = data["games"] ?? 0;
          int remoteWins = data["wins"] ?? 0;
          int remoteLosses = data["losses"] ?? 0;

          _fallbackStorage["coins"] = remoteCoins;
          if (_prefs != null) _prefs!.setInt("coins", remoteCoins);

          _fallbackStorage["games"] = remoteGames;
          _fallbackStorage["wins"] = remoteWins;
          _fallbackStorage["losses"] = remoteLosses;
          if (_prefs != null) {
            _prefs!.setInt("games", remoteGames);
            _prefs!.setInt("wins", remoteWins);
            _prefs!.setInt("losses", remoteLosses);
          }

          var remoteAnimalsList = remoteAnimalsStr.split(" ").where((s) => s.isNotEmpty).toList();
          for (var animal in remoteAnimalsList) {
            if (costs.containsKey(animal)) {
              _fallbackStorage[animal] = 1;
              if (_prefs != null) _prefs!.setInt(animal, 1);
            }
          }

          return true;
        }
      }
    } catch (e) {
      print("Sync error: $e");
    }
    return false;
  }

  Future<bool> loginAndSyncGoogle(String token, String email, String name) async {
    try {
      final response = await http.post(
        Uri.parse("/api/auth?action=google"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "token": token,
          "coins": getCoins(),
          "unlockedAnimals": getUnlockedAvatars().join(" "),
          "games": getGames(),
          "wins": getWins(),
          "losses": getLosses(),
        }),
      ).timeout(const Duration(seconds: 5));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data["success"] == true) {
        linkAccount(email, name, token);

        int remoteCoins = data["coins"] ?? 0;
        String remoteAnimalsStr = data["unlockedAnimals"] ?? "Seal Penguin";
        int remoteGames = data["games"] ?? 0;
        int remoteWins = data["wins"] ?? 0;
        int remoteLosses = data["losses"] ?? 0;

        _fallbackStorage["coins"] = remoteCoins;
        if (_prefs != null) _prefs!.setInt("coins", remoteCoins);
        _fallbackStorage["games"] = remoteGames;
        _fallbackStorage["wins"] = remoteWins;
        _fallbackStorage["losses"] = remoteLosses;
        if (_prefs != null) {
          _prefs!.setInt("games", remoteGames);
          _prefs!.setInt("wins", remoteWins);
          _prefs!.setInt("losses", remoteLosses);
        }

        var remoteAnimalsList = remoteAnimalsStr.split(" ").where((s) => s.isNotEmpty).toList();
        for (var animal in remoteAnimalsList) {
          if (costs.containsKey(animal)) {
            _fallbackStorage[animal] = 1;
            if (_prefs != null) _prefs!.setInt(animal, 1);
          }
        }
        return true;
      } else {
        throw Exception(data["error"] ?? "Authentication failed");
      }
    } catch (e) {
      rethrow;
    }
  }
}
