import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
class GeminiService {
  static String? _apiKey;
  static const List<String> _modelos = [
    'qwen/qwen3-4b:free',
    'google/gemma-3-4b-it:free',
    'meta-llama/llama-3.2-3b-instruct:free',
    'google/gemma-3-12b-it:free',
    'meta-llama/llama-3.3-70b-instruct:free',
    'mistralai/mistral-small-3.1-24b-instruct:free',
    'nvidia/nemotron-nano-9b-v2:free',
    'stepfun/step-3.5-flash:free',
  ];
  static void init() {
    final apiKey = dotenv.env['OPENROUTER_API_KEY'] ?? '';
    if (apiKey.isEmpty || apiKey.startsWith('TU_API_KEY')) {
      debugPrint('OpenRouter: API key no configurada.');
      return;
    }
    _apiKey = apiKey;
    debugPrint('OpenRouter: inicializado. Key: ${apiKey.substring(0, 10)}...');
  }
  static bool get disponible => _apiKey != null;
  static Future<Map<String, String>> enriquecerAnalisis({
    required int score,
    required String nivelRiesgo,
    required int numMaterias,
    required double horasSemanales,
    required List<String> diasSobrecargados,
    required int numTutorias,
    required List<String> sugerenciasTutorias,
    required String scoreDetalle,
  }) async {
    if (_apiKey == null) throw Exception('OpenRouter no inicializado');
    final String contextoDias = diasSobrecargados.isEmpty ? 'ninguno' : diasSobrecargados.join(', ');
    final String contextoTutorias = sugerenciasTutorias.isEmpty
        ? 'No hay tutorias disponibles.'
        : sugerenciasTutorias.take(4).join('\n');
    final String prompt = 'Eres un asistente academico universitario. '
        'Responde en espanol con este formato EXACTO:\n\n'
        'DIAGNOSTICO:\n[Explica el score y riesgo. Max 120 palabras.]\n\n'
        'RECOMENDACIONES:\n[Pasos para mejorar. Max 120 palabras.]\n\n'
        'DATOS: Score=$score/100, Riesgo=$nivelRiesgo, Materias=$numMaterias, '
        'Horas=${horasSemanales.toStringAsFixed(1)}, Tutorias=$numTutorias, '
        'Dias sobrecargados=$contextoDias. Tutorias: $contextoTutorias';
    Exception? ultimoError;
    for (final modelo in _modelos) {
      for (int intento = 1; intento <= 2; intento++) {
        try {
          debugPrint('OpenRouter: $modelo intento $intento...');
          final response = await http.post(
            Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
              'HTTP-Referer': 'https://tutorias-ucatolica.app',
              'X-Title': 'Tutorias UCatolica',
            },
            body: jsonEncode({
              'model': modelo,
              'messages': [{'role': 'user', 'content': prompt}],
              'max_tokens': 500,
              'temperature': 0.7,
              'provider': {'allow_fallbacks': true},
            }),
          ).timeout(const Duration(seconds: 40));
          if (response.statusCode != 200) {
            final err = jsonDecode(response.body);
            final msg = err['error']?['message'] ?? 'HTTP ${response.statusCode}';
            if (msg.contains('Provider') && intento < 2) {
              await Future.delayed(const Duration(seconds: 3));
              continue;
            }
            throw Exception(msg);
          }
          final data = jsonDecode(response.body);
          final text = (data['choices'][0]['message']['content'] as String? ?? '').trim();
          if (text.isEmpty) throw Exception('Respuesta vacia');
          final diagMatch = RegExp(r'DIAGN[OÓ]STICO:\s*([\s\S]*?)(?=RECOMENDACIONES:|$)', caseSensitive: false).firstMatch(text);
          final recomMatch = RegExp(r'RECOMENDACIONES:\s*([\s\S]*?)$', caseSensitive: false).firstMatch(text);
          final diagnostico = diagMatch?.group(1)?.trim() ?? text;
          final recomendaciones = recomMatch?.group(1)?.trim() ?? 'Revisa tu carga academica con tu tutor.';
          debugPrint('OpenRouter exito con $modelo');
          final recomFinal = sugerenciasTutorias.isNotEmpty
              ? '$recomendaciones\n\nEspacios disponibles:\n${sugerenciasTutorias.take(4).join('\n')}'
              : recomendaciones;
          return {'justificacion': diagnostico, 'recomendacion': recomFinal};
        } catch (e) {
          debugPrint('OpenRouter: $modelo intento $intento fallo: $e');
          ultimoError = Exception(e.toString());
          if (intento < 2) await Future.delayed(const Duration(seconds: 2));
        }
      }
    }
    throw ultimoError ?? Exception('Todos los modelos fallaron');
  }
}
