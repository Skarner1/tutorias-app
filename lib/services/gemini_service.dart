import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Modelo de pregunta de evaluación previa
class QuizPregunta {
  final String pregunta;
  final List<String> opciones; // 4 opciones (A, B, C, D)
  final int correcta;          // índice 0..3
  final String explicacion;
  QuizPregunta({
    required this.pregunta,
    required this.opciones,
    required this.correcta,
    required this.explicacion,
  });
}

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
          final diagMatch = RegExp(r'DIAGNOSTICO:\s*([\s\S]*?)(?=RECOMENDACIONES:|$)', caseSensitive: false).firstMatch(text);
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

  /// Genera un quiz de 4 preguntas tipo opción múltiple sobre una materia
  /// para evaluar si el estudiante tiene los conceptos básicos antes de
  /// solicitar la tutoría. Si la API no está disponible o falla, devuelve
  /// un set genérico local de fallback.
  static Future<List<QuizPregunta>> generarQuiz({
    required String materia,
    int cantidad = 4,
  }) async {
    if (_apiKey != null) {
      final String prompt =
          'Eres un docente universitario. Genera EXACTAMENTE $cantidad preguntas '
          'de opcion multiple (4 opciones cada una) SOBRE EL CONTENIDO REAL Y '
          'BASICO de la materia "$materia". Las preguntas deben evaluar '
          'conocimientos concretos del tema, NO estrategias de estudio ni habitos. '
          'Ejemplos del tipo de preguntas esperadas:\n'
          '- Si la materia es "matematicas" o "aritmetica": operaciones simples '
          '(sumas, restas, multiplicaciones, divisiones, fracciones, porcentajes).\n'
          '- Si es "calculo": derivadas e integrales basicas, limites simples.\n'
          '- Si es "algebra": ecuaciones lineales, factorizacion, despejes.\n'
          '- Si es "fisica": unidades, formulas basicas (v=d/t, F=ma).\n'
          '- Si es "programacion": sintaxis basica, tipos de datos, bucles.\n'
          '- Si es "quimica": tabla periodica, formulas, balanceo simple.\n'
          '- Si es "historia": fechas y hechos importantes.\n'
          '- Si es "ingles" u otro idioma: vocabulario y gramatica basica.\n'
          'NO uses preguntas avanzadas ni de teoria abstracta. Las preguntas '
          'deben ser de nivel introductorio para verificar prerrequisitos.\n'
          'Devuelve SOLO un JSON valido sin texto adicional, con esta forma exacta:\n'
          '{"preguntas":[{"pregunta":"...","opciones":["A","B","C","D"],'
          '"correcta":0,"explicacion":"..."}]}\n'
          'El campo "correcta" es el indice (0,1,2 o 3). Las explicaciones '
          'deben ser cortas (max 2 lineas) y en espanol.';

      for (final modelo in _modelos) {
        try {
          debugPrint('OpenRouter quiz: probando $modelo...');
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
              'messages': [
                {'role': 'system', 'content': 'Responde SOLO con JSON valido. Nada mas.'},
                {'role': 'user', 'content': prompt},
              ],
              'max_tokens': 900,
              'temperature': 0.6,
              'provider': {'allow_fallbacks': true},
            }),
          ).timeout(const Duration(seconds: 35));

          if (response.statusCode != 200) {
            debugPrint('OpenRouter quiz $modelo HTTP ${response.statusCode}');
            continue;
          }
          final data = jsonDecode(response.body);
          String text = (data['choices'][0]['message']['content'] as String? ?? '').trim();
          // Algunos modelos rodean el JSON con ```json ... ```
          text = text.replaceAll(RegExp(r'^```(json)?', multiLine: true), '').replaceAll('```', '').trim();
          // Recortar al primer { y último }
          final int ini = text.indexOf('{');
          final int fin = text.lastIndexOf('}');
          if (ini < 0 || fin <= ini) continue;
          text = text.substring(ini, fin + 1);

          final parsed = jsonDecode(text) as Map<String, dynamic>;
          final List preguntasRaw = (parsed['preguntas'] as List?) ?? const [];
          final List<QuizPregunta> result = [];
          for (final p in preguntasRaw) {
            try {
              final m = p as Map<String, dynamic>;
              final List ops = (m['opciones'] as List).cast();
              if (ops.length < 4) continue;
              final int correcta = (m['correcta'] is int)
                  ? m['correcta'] as int
                  : int.tryParse(m['correcta'].toString()) ?? 0;
              result.add(QuizPregunta(
                pregunta: (m['pregunta'] ?? '').toString(),
                opciones: ops.take(4).map((e) => e.toString()).toList(),
                correcta: correcta.clamp(0, 3),
                explicacion: (m['explicacion'] ?? '').toString(),
              ));
            } catch (_) {}
          }
          if (result.length >= 2) {
            debugPrint('OpenRouter quiz: ${result.length} preguntas generadas con $modelo');
            return result.take(cantidad).toList();
          }
        } catch (e) {
          debugPrint('OpenRouter quiz $modelo fallo: $e');
        }
      }
    }
    // Fallback local genérico
    return _quizFallback(materia, cantidad);
  }

  /// Fallback local: detecta el tipo de materia por palabras clave y devuelve
  /// preguntas reales del CONTENIDO (no estrategia). Si no reconoce la materia
  /// usa preguntas de razonamiento general aplicables a cualquier asignatura.
  static List<QuizPregunta> _quizFallback(String materia, int cantidad) {
    final String m = materia.trim().toLowerCase();

    bool any(List<String> keys) => keys.any((k) => m.contains(k));

    List<QuizPregunta> banco;

    if (any(['calculo', 'cálculo', 'derivad', 'integral', 'limite', 'límite'])) {
      banco = _bancoCalculo();
    } else if (any(['algebra', 'álgebra', 'ecuacion', 'ecuación', 'factoriz'])) {
      banco = _bancoAlgebra();
    } else if (any(['matemat', 'matemát', 'aritmet', 'aritmét', 'numer', 'núm'])) {
      banco = _bancoMatematicas();
    } else if (any(['fisic', 'físic', 'mecanic', 'mecánic', 'cinemat'])) {
      banco = _bancoFisica();
    } else if (any(['program', 'codig', 'código', 'python', 'java', 'dart', 'software', 'algoritm'])) {
      banco = _bancoProgramacion();
    } else if (any(['quimic', 'químic'])) {
      banco = _bancoQuimica();
    } else if (any(['ingles', 'inglés', 'english'])) {
      banco = _bancoIngles();
    } else if (any(['histor'])) {
      banco = _bancoHistoria();
    } else if (any(['estadist', 'estadíst', 'probabilid'])) {
      banco = _bancoEstadistica();
    } else {
      banco = _bancoGenerico(materia);
    }

    banco.shuffle();
    return banco.take(cantidad).toList();
  }

  static List<QuizPregunta> _bancoMatematicas() => [
        QuizPregunta(
          pregunta: '¿Cuánto es 12 + 8 × 2?',
          opciones: const ['28', '40', '20', '32'],
          correcta: 0,
          explicacion: 'Por jerarquía: primero 8×2=16, luego 12+16=28.',
        ),
        QuizPregunta(
          pregunta: '¿Cuál es el resultado de 144 ÷ 12?',
          opciones: const ['11', '12', '13', '14'],
          correcta: 1,
          explicacion: '12 × 12 = 144, así que 144 ÷ 12 = 12.',
        ),
        QuizPregunta(
          pregunta: '¿Cuánto es 3/4 de 80?',
          opciones: const ['50', '55', '60', '65'],
          correcta: 2,
          explicacion: '80 ÷ 4 = 20, y 20 × 3 = 60.',
        ),
        QuizPregunta(
          pregunta: '¿Qué porcentaje representa 25 de 200?',
          opciones: const ['10%', '12.5%', '20%', '25%'],
          correcta: 1,
          explicacion: '(25 / 200) × 100 = 12.5%.',
        ),
        QuizPregunta(
          pregunta: '¿Cuál es el valor de 7² − 3²?',
          opciones: const ['40', '46', '49', '16'],
          correcta: 0,
          explicacion: '49 − 9 = 40.',
        ),
        QuizPregunta(
          pregunta: '¿Cuánto es la raíz cuadrada de 81?',
          opciones: const ['7', '8', '9', '10'],
          correcta: 2,
          explicacion: '9 × 9 = 81.',
        ),
      ];

  static List<QuizPregunta> _bancoCalculo() => [
        QuizPregunta(
          pregunta: '¿Cuál es la derivada de f(x) = x²?',
          opciones: const ['x', '2x', 'x²/2', '2'],
          correcta: 1,
          explicacion: 'd/dx(xⁿ) = n·xⁿ⁻¹, así que d/dx(x²) = 2x.',
        ),
        QuizPregunta(
          pregunta: '¿Cuál es la integral de 2x dx?',
          opciones: const ['x² + C', '2 + C', 'x + C', '2x² + C'],
          correcta: 0,
          explicacion: 'La antiderivada de 2x es x² (más constante C).',
        ),
        QuizPregunta(
          pregunta: '¿Cuál es el límite cuando x→0 de sen(x)/x?',
          opciones: const ['0', '∞', '1', 'No existe'],
          correcta: 2,
          explicacion: 'Es un límite notable fundamental: vale 1.',
        ),
        QuizPregunta(
          pregunta: 'La derivada de una constante es:',
          opciones: const ['La misma constante', '1', '0', 'x'],
          correcta: 2,
          explicacion: 'La derivada de cualquier constante es 0.',
        ),
        QuizPregunta(
          pregunta: '¿Cuál es la derivada de sen(x)?',
          opciones: const ['cos(x)', '−cos(x)', '−sen(x)', 'tan(x)'],
          correcta: 0,
          explicacion: 'd/dx(sen x) = cos x.',
        ),
      ];

  static List<QuizPregunta> _bancoAlgebra() => [
        QuizPregunta(
          pregunta: 'Si 2x + 4 = 10, ¿cuánto vale x?',
          opciones: const ['2', '3', '4', '5'],
          correcta: 1,
          explicacion: '2x = 6 → x = 3.',
        ),
        QuizPregunta(
          pregunta: '¿Cuál es la factorización de x² − 9?',
          opciones: const ['(x−3)(x−3)', '(x+3)(x+3)', '(x−3)(x+3)', 'x(x−9)'],
          correcta: 2,
          explicacion: 'Diferencia de cuadrados: a²−b² = (a−b)(a+b).',
        ),
        QuizPregunta(
          pregunta: '¿Cuál es el resultado de (x + 2)²?',
          opciones: const ['x² + 4', 'x² + 4x + 4', 'x² + 2x + 2', 'x² + 2x + 4'],
          correcta: 1,
          explicacion: 'Binomio al cuadrado: (a+b)² = a² + 2ab + b².',
        ),
        QuizPregunta(
          pregunta: 'Resuelve: 3(x − 2) = 9. x =',
          opciones: const ['3', '4', '5', '6'],
          correcta: 2,
          explicacion: 'x − 2 = 3 → x = 5.',
        ),
        QuizPregunta(
          pregunta: 'Si y = 2x + 1, ¿cuánto vale y cuando x = 4?',
          opciones: const ['7', '8', '9', '10'],
          correcta: 2,
          explicacion: '2(4) + 1 = 9.',
        ),
      ];

  static List<QuizPregunta> _bancoFisica() => [
        QuizPregunta(
          pregunta: 'La fórmula de la velocidad media es:',
          opciones: const ['v = m·a', 'v = d/t', 'v = F/m', 'v = t/d'],
          correcta: 1,
          explicacion: 'Velocidad = distancia recorrida / tiempo.',
        ),
        QuizPregunta(
          pregunta: 'La segunda ley de Newton dice que:',
          opciones: const ['F = m·v', 'F = m·a', 'F = m/a', 'F = a/m'],
          correcta: 1,
          explicacion: 'Fuerza = masa × aceleración.',
        ),
        QuizPregunta(
          pregunta: '¿En qué unidad se mide la fuerza en el SI?',
          opciones: const ['Joule', 'Watt', 'Newton', 'Pascal'],
          correcta: 2,
          explicacion: 'La unidad de fuerza es el Newton (N).',
        ),
        QuizPregunta(
          pregunta: 'Si un objeto cae libremente, su aceleración es aprox.:',
          opciones: const ['1 m/s²', '4.9 m/s²', '9.8 m/s²', '20 m/s²'],
          correcta: 2,
          explicacion: 'La gravedad terrestre es ≈ 9.8 m/s².',
        ),
        QuizPregunta(
          pregunta: 'Energía cinética se calcula como:',
          opciones: const ['m·g·h', '½·m·v²', 'F·d', 'm·v'],
          correcta: 1,
          explicacion: 'Ec = ½ m v².',
        ),
      ];

  static List<QuizPregunta> _bancoProgramacion() => [
        QuizPregunta(
          pregunta: '¿Cuál de estos es un tipo de dato entero?',
          opciones: const ['string', 'int', 'bool', 'char'],
          correcta: 1,
          explicacion: '"int" representa números enteros.',
        ),
        QuizPregunta(
          pregunta: '¿Qué hace un bucle "for"?',
          opciones: const ['Define una función', 'Repite un bloque de código', 'Declara una variable', 'Importa una librería'],
          correcta: 1,
          explicacion: 'Sirve para iterar y repetir instrucciones.',
        ),
        QuizPregunta(
          pregunta: 'En la mayoría de lenguajes, los índices de un arreglo empiezan en:',
          opciones: const ['−1', '0', '1', 'Depende del lenguaje siempre'],
          correcta: 1,
          explicacion: 'Casi todos (C, Java, Python, Dart…) inician en 0.',
        ),
        QuizPregunta(
          pregunta: '¿Cuál es el resultado de 5 % 2?',
          opciones: const ['1', '2', '2.5', '0'],
          correcta: 0,
          explicacion: '% es el módulo: el residuo de 5 ÷ 2 es 1.',
        ),
        QuizPregunta(
          pregunta: 'Una variable booleana puede tomar los valores:',
          opciones: const ['0 o cualquier número', 'true o false', 'Sólo letras', 'Cualquier texto'],
          correcta: 1,
          explicacion: 'Booleano = true / false.',
        ),
      ];

  static List<QuizPregunta> _bancoQuimica() => [
        QuizPregunta(
          pregunta: '¿Cuál es el símbolo químico del agua?',
          opciones: const ['O2', 'H2O', 'CO2', 'NaCl'],
          correcta: 1,
          explicacion: 'Dos hidrógenos y un oxígeno: H₂O.',
        ),
        QuizPregunta(
          pregunta: '¿Cuántos protones tiene el átomo de hidrógeno?',
          opciones: const ['0', '1', '2', '8'],
          correcta: 1,
          explicacion: 'El hidrógeno tiene número atómico 1.',
        ),
        QuizPregunta(
          pregunta: 'El pH del agua pura a 25°C es aproximadamente:',
          opciones: const ['0', '7', '10', '14'],
          correcta: 1,
          explicacion: 'pH 7 = neutro.',
        ),
        QuizPregunta(
          pregunta: '¿Qué elemento tiene el símbolo "Na"?',
          opciones: const ['Nitrógeno', 'Níquel', 'Sodio', 'Neón'],
          correcta: 2,
          explicacion: 'Na proviene de "Natrium" (sodio).',
        ),
      ];

  static List<QuizPregunta> _bancoIngles() => [
        QuizPregunta(
          pregunta: 'La traducción correcta de "house" es:',
          opciones: const ['Caballo', 'Casa', 'Hueso', 'Habitación'],
          correcta: 1,
          explicacion: '"House" significa casa.',
        ),
        QuizPregunta(
          pregunta: '¿Cuál es el pasado simple de "go"?',
          opciones: const ['goed', 'gone', 'went', 'going'],
          correcta: 2,
          explicacion: 'Verbo irregular: go → went → gone.',
        ),
        QuizPregunta(
          pregunta: 'Completa: "She ___ a student."',
          opciones: const ['am', 'is', 'are', 'be'],
          correcta: 1,
          explicacion: 'Tercera persona singular: is.',
        ),
        QuizPregunta(
          pregunta: '¿Cómo se dice "lunes" en inglés?',
          opciones: const ['Sunday', 'Tuesday', 'Monday', 'Friday'],
          correcta: 2,
          explicacion: 'Monday = lunes.',
        ),
      ];

  static List<QuizPregunta> _bancoHistoria() => [
        QuizPregunta(
          pregunta: '¿En qué año llegó Cristóbal Colón a América?',
          opciones: const ['1492', '1500', '1521', '1810'],
          correcta: 0,
          explicacion: 'El 12 de octubre de 1492.',
        ),
        QuizPregunta(
          pregunta: '¿En qué siglo ocurrió la Revolución Francesa?',
          opciones: const ['XVI', 'XVII', 'XVIII', 'XIX'],
          correcta: 2,
          explicacion: 'Inició en 1789 (siglo XVIII).',
        ),
        QuizPregunta(
          pregunta: 'La Segunda Guerra Mundial terminó en:',
          opciones: const ['1918', '1939', '1945', '1950'],
          correcta: 2,
          explicacion: 'Finalizó en 1945.',
        ),
      ];

  static List<QuizPregunta> _bancoEstadistica() => [
        QuizPregunta(
          pregunta: 'La media de los valores 2, 4, 6, 8 es:',
          opciones: const ['4', '5', '6', '20'],
          correcta: 1,
          explicacion: '(2+4+6+8)/4 = 20/4 = 5.',
        ),
        QuizPregunta(
          pregunta: 'La probabilidad de obtener cara al lanzar una moneda justa es:',
          opciones: const ['0', '0.25', '0.5', '1'],
          correcta: 2,
          explicacion: 'Hay 2 resultados igualmente probables: 1/2 = 0.5.',
        ),
        QuizPregunta(
          pregunta: 'La mediana de 3, 1, 4, 1, 5 es:',
          opciones: const ['1', '3', '4', '5'],
          correcta: 1,
          explicacion: 'Ordenado: 1,1,3,4,5 → el del medio es 3.',
        ),
        QuizPregunta(
          pregunta: 'Si lanzas un dado, la probabilidad de sacar 6 es:',
          opciones: const ['1/2', '1/3', '1/6', '6/6'],
          correcta: 2,
          explicacion: 'Hay 1 caso favorable de 6 posibles: 1/6.',
        ),
      ];

  static List<QuizPregunta> _bancoGenerico(String materia) {
    final m = materia.trim().isEmpty ? 'la materia' : materia.trim();
    return [
      QuizPregunta(
        pregunta: '¿Tienes claros los conceptos introductorios de $m?',
        opciones: const [
          'Sí, dominio los temas básicos',
          'Solo algunos, me falta repaso',
          'Casi nada, necesito empezar desde cero',
          'No estoy seguro',
        ],
        correcta: 0,
        explicacion: 'Identificar tu nivel inicial ayuda al tutor a enfocar la sesión.',
      ),
      QuizPregunta(
        pregunta: 'Antes de la tutoría de $m, ¿qué deberías traer preparado?',
        opciones: const [
          'Las definiciones y ejemplos básicos del tema',
          'Nada, el tutor lo explica todo desde cero',
          'Solo tu cuaderno en blanco',
          'Únicamente el nombre del tema',
        ],
        correcta: 0,
        explicacion: 'Llegar con bases revisadas hace la tutoría más productiva.',
      ),
      QuizPregunta(
        pregunta: 'Si en $m no entiendes un concepto, lo mejor es:',
        opciones: const [
          'Saltarlo y seguir adelante',
          'Identificar exactamente qué parte no entiendes',
          'Esperar al examen',
          'Copiar el ejercicio sin analizarlo',
        ],
        correcta: 1,
        explicacion: 'Detectar el punto de bloqueo es el primer paso para resolverlo.',
      ),
      QuizPregunta(
        pregunta: '¿Qué nivel de práctica previa tienes en $m?',
        opciones: const [
          'He resuelto varios ejercicios',
          'Solo he leído la teoría',
          'Ninguna práctica',
          'No recuerdo',
        ],
        correcta: 0,
        explicacion: 'La práctica constante consolida los conceptos.',
      ),
    ];
  }
}
