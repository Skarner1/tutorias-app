import 'dart:async';
import 'package:http/http.dart' as http;

/// Verifica si hay conexión real a internet (no solo a la red Wi-Fi).
/// Hace un HEAD a un endpoint ligero de Google que responde 204.
class ConnectivityService {
  static const String _checkUrl = 'https://clients3.google.com/generate_204';
  static const Duration _timeout = Duration(seconds: 5);

  static Future<bool> hasInternet() async {
    try {
      final r = await http.head(Uri.parse(_checkUrl)).timeout(_timeout);
      return r.statusCode >= 200 && r.statusCode < 400;
    } catch (_) {
      return false;
    }
  }
}