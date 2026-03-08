import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

/// Servicio que usa Google Gemini para enriquecer el análisis académico
/// generado por el algoritmo local de AIService.
class GeminiService {
  static GenerativeModel? _model;

  /// Inicializa el modelo Gemini. Llamar una sola vez al arrancar la app.
  static void init() {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (apiKey.isEmpty || apiKey == 'TU_API_KEY_AQUI') {
      debugPrint('⚠️ GeminiService: API key no configurada, usando análisis local.');
      return;
    }
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        maxOutputTokens: 600,
      ),
    );
    debugPrint('🤖 GeminiService: modelo gemini-1.5-flash inicializado correctamente.');
  }

  /// Devuelve true si Gemini está disponible (API key configurada).
  static bool get disponible => _model != null;

  /// Recibe el contexto académico calculado localmente y pide a Gemini
  /// que genere un diagnóstico y recomendaciones más explicativas en español.
  ///
  /// Retorna un mapa con las claves:
  ///   - `justificacion`: diagnóstico narrativo enriquecido
  ///   - `recomendacion`: recomendaciones personalizadas detalladas
  ///
  /// Si falla, lanza excepción para que AIService use el fallback local.
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
    if (_model == null) throw Exception('Gemini no inicializado');

    debugPrint('🚀 GeminiService: enviando prompt a Gemini para score=$score, riesgo=$nivelRiesgo');

    final String contextoDias = diasSobrecargados.isEmpty
        ? 'ninguno'
        : diasSobrecargados.join(', ');

    final String contextoTutorias = sugerenciasTutorias.isEmpty
        ? 'No hay tutorías disponibles para sus materias en este momento.'
        : sugerenciasTutorias.take(4).join('\n');

    final String prompt = '''
Eres un asistente académico universitario amigable, motivador y muy explícito. 
Tu tarea es analizar la situación académica de un estudiante universitario y dar:
1. Un DIAGNÓSTICO claro y detallado de por qué tiene ese nivel de riesgo.
2. RECOMENDACIONES concretas, accionables y motivadoras.

**Datos del estudiante:**
- Score académico: $score / 100
- Nivel de riesgo: $nivelRiesgo
- Número de materias: $numMaterias
- Horas de clase por semana: ${horasSemanales.toStringAsFixed(1)}h
- Días con sobrecarga (más de 5h seguidas): $contextoDias
- Tutorías activas inscritas: $numTutorias
- Espacios de tutoría disponibles para sus materias:
$contextoTutorias

**Desglose de puntuación:**
$scoreDetalle

---
**INSTRUCCIONES:**
- Responde ÚNICAMENTE en español.
- Sé empático, claro y directo.
- El DIAGNÓSTICO debe explicar en detalle por qué el estudiante tiene ese score y ese nivel de riesgo, mencionando cada factor.
- Las RECOMENDACIONES deben ser pasos concretos que el estudiante puede hacer HOY para mejorar.
- Si hay tutorías disponibles, menciónalas explícitamente en las recomendaciones.
- Máximo 180 palabras por sección.
- Usa emojis moderadamente para hacer el texto más amigable.
- NO repitas los números del desglose, solo interprétalos en lenguaje natural.

**Responde con este formato exacto (no agregues texto fuera de esto):**

DIAGNÓSTICO:
[tu diagnóstico aquí]

RECOMENDACIONES:
[tus recomendaciones aquí]
''';

    final response = await _model!.generateContent([Content.text(prompt)]);
    final text = response.text ?? '';

    if (text.isEmpty) throw Exception('Respuesta vacía de Gemini');

    // Parsear la respuesta en las dos secciones
    final diagMatch = RegExp(
      r'DIAGNÓSTICO:\s*([\s\S]*?)(?=RECOMENDACIONES:|$)',
      caseSensitive: false,
    ).firstMatch(text);
    final recomMatch = RegExp(
      r'RECOMENDACIONES:\s*([\s\S]*?)$',
      caseSensitive: false,
    ).firstMatch(text);

    final diagnostico = diagMatch?.group(1)?.trim() ?? '';
    final recomendaciones = recomMatch?.group(1)?.trim() ?? '';

    if (diagnostico.isEmpty || recomendaciones.isEmpty) {
      throw Exception('Formato de respuesta inesperado de Gemini');
    }

    // Agregar sugerencias de tutorías al final si existen
    final recomConSugerencias = sugerenciasTutorias.isNotEmpty
        ? '$recomendaciones\n\n📍 Espacios disponibles para tus materias:\n${sugerenciasTutorias.take(4).join('\n')}'
        : recomendaciones;

    return {
      'justificacion': diagnostico,
      'recomendacion': recomConSugerencias,
    };
  }
}




