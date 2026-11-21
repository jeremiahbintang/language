import 'package:shared_preferences/shared_preferences.dart';

/// Local, on-device storage (no account). Everything lives in SharedPreferences.
class SettingsStore {
  static const _apiKeyKey = 'anthropic_api_key';

  Future<String?> getApiKey() async {
    final p = await SharedPreferences.getInstance();
    final k = p.getString(_apiKeyKey);
    return (k == null || k.isEmpty) ? null : k;
  }

  Future<void> setApiKey(String? key) async {
    final p = await SharedPreferences.getInstance();
    if (key == null || key.trim().isEmpty) {
      await p.remove(_apiKeyKey);
    } else {
      await p.setString(_apiKeyKey, key.trim());
    }
  }
}
