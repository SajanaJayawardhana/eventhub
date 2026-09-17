import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService {
  static const String _key = 'favorite_event_ids';

  static Future<Set<String>> getFavoriteIds() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_key);
    if (jsonString == null) return {};

    try {
      final List<dynamic> list = json.decode(jsonString);
      return list.cast<String>().toSet();
    } catch (e) {
      return {};
    }
  }

  static Future<void> toggleFavorite(String eventId) async {
    final prefs = await SharedPreferences.getInstance();
    final Set<String> favorites = await getFavoriteIds();

    if (favorites.contains(eventId)) {
      favorites.remove(eventId);
    } else {
      favorites.add(eventId);
    }

    await prefs.setString(_key, json.encode(favorites.toList()));
  }

  static Future<bool> isFavorite(String eventId) async {
    final Set<String> favorites = await getFavoriteIds();
    return favorites.contains(eventId);
  }
}
