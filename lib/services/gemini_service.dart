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

  /// Detecta si una materia pertenece a las carreras de Ingeniería que cubre la app.
  /// La app solo tiene quiz para temas técnicos (Facultad de Ingeniería). Cualquier
  /// otra materia se ignora y NO se le hacen preguntas al estudiante.
  static bool esMateriaIngenieria(String materia) {
    final String m = materia.trim().toLowerCase();
    if (m.isEmpty) return false;
    const claves = [
      // Matemáticas / Ciencias base
      'matemat', 'matemát', 'aritmet', 'aritmét', 'numer', 'núm',
      'calculo', 'cálculo', 'derivad', 'integral', 'limite', 'límite',
      'algebra', 'álgebra', 'ecuacion', 'ecuación', 'factoriz', 'matriz', 'matric', 'vector',
      'estadist', 'estadíst', 'probabilid',
      'fisic', 'físic', 'mecanic', 'mecánic', 'cinemat', 'dinamic', 'dinámic', 'estatic', 'estátic',
      'quimic', 'químic',
      // Ingeniería de Sistemas / Datos / IA
      'program', 'codig', 'código', 'python', 'java', 'dart', 'software', 'algoritm',
      'estructura de dat', 'base de dat', 'redes', 'sistemas', 'computa',
      'datos', 'inteligencia artificial', 'machine learning', 'ia',
      // Civil / Estructural
      'civil', 'estructur', 'hidraul', 'hidrául', 'topograf', 'geotecn', 'concret', 'acero',
      // Industrial
      'industr', 'logist', 'logíst', 'productiv', 'calidad', 'procesos',
      // Electrónica / Eléctrica
      'electr', 'electrón', 'circuit', 'señales',
      // Genérico ingeniería
      'ingenier',
    ];
    return claves.any((k) => m.contains(k));
  }

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
    // Filtro de carrera: la app solo evalúa temas de Ingeniería.
    // Si la materia no encaja, devolvemos lista vacía y el flujo principal
    // saltará el quiz para ir directamente a la reserva sin preguntas.
    if (!esMateriaIngenieria(materia)) {
      debugPrint('Quiz omitido: "$materia" no es materia de Ingeniería.');
      return const [];
    }
    if (_apiKey != null) {
      final String prompt =
          'Eres un docente universitario de la FACULTAD DE INGENIERIA. Genera EXACTAMENTE $cantidad '
          'preguntas de opcion multiple (4 opciones cada una) SOBRE EL CONTENIDO REAL Y BASICO '
          'de la materia "$materia", enmarcada SIEMPRE dentro del contexto de carreras de '
          'ingenieria (Ing. de Sistemas/Computacion, Ing. Civil, Ing. Industrial, Ing. de Datos e IA, '
          'Ing. Electronica/Mecanica). Las preguntas deben evaluar conocimientos concretos del tema, '
          'NO estrategias de estudio ni habitos. NO incluyas temas de derecho, medicina, arte, '
          'historia general, idiomas, filosofia ni ciencias sociales: SOLO temas tecnicos de ingenieria.\n'
          'Ejemplos del tipo de preguntas esperadas:\n'
          '- Matematicas/aritmetica: operaciones, fracciones, porcentajes, notacion cientifica.\n'
          '- Calculo: derivadas, integrales basicas, limites simples.\n'
          '- Algebra (lineal): ecuaciones, matrices, vectores, despejes.\n'
          '- Fisica: unidades del SI, cinematica (v=d/t), dinamica (F=ma), energia.\n'
          '- Programacion/algoritmos: sintaxis basica, tipos de datos, bucles, complejidad.\n'
          '- Estadistica/probabilidad: media, mediana, varianza, eventos.\n'
          '- Quimica (para ingenieria): tabla periodica, balanceo simple, mol.\n'
          '- Circuitos/electronica: ley de Ohm, serie/paralelo, componentes basicos.\n'
          '- Estructuras/civil: fuerzas, esfuerzos, materiales, planos.\n'
          '- Industrial: productividad, eficiencia, diagramas de proceso.\n'
          'NO uses preguntas avanzadas ni de teoria abstracta. Las preguntas deben ser de nivel '
          'introductorio para verificar prerrequisitos antes de la tutoria.\n'
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
    } else if (any(['algebra', 'álgebra', 'ecuacion', 'ecuación', 'factoriz', 'matriz', 'matric', 'vector'])) {
      banco = _bancoAlgebra();
    } else if (any(['matemat', 'matemát', 'aritmet', 'aritmét', 'numer', 'núm'])) {
      banco = _bancoMatematicas();
    } else if (any(['fisic', 'físic', 'mecanic', 'mecánic', 'cinemat', 'dinamic', 'dinámic', 'estatic', 'estátic'])) {
      banco = _bancoFisica();
    } else if (any(['program', 'codig', 'código', 'python', 'java', 'dart', 'software', 'algoritm', 'estructura de dat', 'base de dat'])) {
      banco = _bancoProgramacion();
    } else if (any(['quimic', 'químic', 'materiales', 'reaccion', 'reacción'])) {
      banco = _bancoQuimica();
    } else if (any(['estadist', 'estadíst', 'probabilid'])) {
      banco = _bancoEstadistica();
    } else if (any(['ingenier', 'circuit', 'electr', 'electrón', 'mecanism', 'estructur', 'civil', 'industr', 'redes', 'sistem', 'computa', 'datos', 'inteligencia artificial'])) {
      banco = _bancoIngenieria();
    } else {
      // Cualquier otra materia se trata como tema general de ingenieria,
      // ya que la app esta enfocada en la Facultad de Ingenieria.
      banco = _bancoIngenieria();
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

  static List<QuizPregunta> _bancoBiologia() => [
        QuizPregunta(
          pregunta: '¿Cuál es la unidad básica de la vida?',
          opciones: const ['Átomo', 'Célula', 'Tejido', 'Órgano'],
          correcta: 1,
          explicacion: 'La célula es la unidad estructural y funcional de los seres vivos.',
        ),
        QuizPregunta(
          pregunta: 'El ADN se encuentra principalmente en:',
          opciones: const ['Mitocondria', 'Núcleo', 'Ribosoma', 'Citoplasma'],
          correcta: 1,
          explicacion: 'El ADN se almacena en el núcleo de las células eucariotas.',
        ),
        QuizPregunta(
          pregunta: 'La fotosíntesis ocurre principalmente en:',
          opciones: const ['Raíz', 'Tallo', 'Hojas', 'Flor'],
          correcta: 2,
          explicacion: 'En las hojas, gracias a los cloroplastos.',
        ),
        QuizPregunta(
          pregunta: '¿Cuántos cromosomas tiene una célula humana normal?',
          opciones: const ['23', '46', '48', '64'],
          correcta: 1,
          explicacion: '46 cromosomas (23 pares).',
        ),
      ];

  static List<QuizPregunta> _bancoMedicina() => [
        QuizPregunta(
          pregunta: '¿Cuántas cámaras tiene el corazón humano?',
          opciones: const ['2', '3', '4', '5'],
          correcta: 2,
          explicacion: '2 aurículas y 2 ventrículos = 4 cámaras.',
        ),
        QuizPregunta(
          pregunta: 'El hueso más largo del cuerpo humano es:',
          opciones: const ['Húmero', 'Tibia', 'Fémur', 'Radio'],
          correcta: 2,
          explicacion: 'El fémur es el hueso del muslo.',
        ),
        QuizPregunta(
          pregunta: 'La presión arterial normal en adultos es aproximadamente:',
          opciones: const ['80/50', '120/80', '160/100', '200/120'],
          correcta: 1,
          explicacion: '120/80 mmHg es el rango normal.',
        ),
        QuizPregunta(
          pregunta: '¿Qué órgano produce la insulina?',
          opciones: const ['Hígado', 'Páncreas', 'Riñón', 'Estómago'],
          correcta: 1,
          explicacion: 'Las células beta del páncreas producen insulina.',
        ),
        QuizPregunta(
          pregunta: 'La sangre es bombeada al cuerpo por el:',
          opciones: const ['Pulmón', 'Hígado', 'Corazón', 'Cerebro'],
          correcta: 2,
          explicacion: 'El corazón es la bomba del sistema circulatorio.',
        ),
      ];

  static List<QuizPregunta> _bancoDerecho() => [
        QuizPregunta(
          pregunta: 'La norma jerárquicamente superior en un Estado es:',
          opciones: const ['Decreto', 'Ley', 'Constitución', 'Reglamento'],
          correcta: 2,
          explicacion: 'La Constitución es la norma suprema del ordenamiento.',
        ),
        QuizPregunta(
          pregunta: 'El derecho que regula relaciones entre particulares es:',
          opciones: const ['Penal', 'Civil', 'Constitucional', 'Tributario'],
          correcta: 1,
          explicacion: 'El derecho civil regula relaciones privadas.',
        ),
        QuizPregunta(
          pregunta: 'La presunción de inocencia significa que:',
          opciones: const ['Toda persona es culpable hasta probar lo contrario', 'Toda persona es inocente hasta que se demuestre lo contrario', 'No existe culpabilidad penal', 'El juez decide sin pruebas'],
          correcta: 1,
          explicacion: 'Es un principio fundamental del debido proceso.',
        ),
        QuizPregunta(
          pregunta: '¿Qué rama del derecho regula los delitos y sanciones?',
          opciones: const ['Civil', 'Laboral', 'Penal', 'Mercantil'],
          correcta: 2,
          explicacion: 'El derecho penal define delitos y penas.',
        ),
      ];

  static List<QuizPregunta> _bancoEconomia() => [
        QuizPregunta(
          pregunta: 'Si la oferta de un producto sube y la demanda baja, el precio tiende a:',
          opciones: const ['Subir', 'Bajar', 'Mantenerse igual', 'Duplicarse'],
          correcta: 1,
          explicacion: 'A mayor oferta y menor demanda, los precios bajan.',
        ),
        QuizPregunta(
          pregunta: 'El PIB mide:',
          opciones: const ['La inflación', 'La producción total de un país', 'La cantidad de habitantes', 'El número de empresas'],
          correcta: 1,
          explicacion: 'PIB = Producto Interno Bruto = producción total.',
        ),
        QuizPregunta(
          pregunta: 'En contabilidad, Activo = Pasivo + ?',
          opciones: const ['Ingresos', 'Gasto', 'Patrimonio', 'Utilidad'],
          correcta: 2,
          explicacion: 'Ecuación contable básica: Activo = Pasivo + Patrimonio.',
        ),
        QuizPregunta(
          pregunta: 'El interés simple sobre 1.000.000 al 10% anual durante 1 año es:',
          opciones: const ['10.000', '100.000', '1.000.000', '110.000'],
          correcta: 1,
          explicacion: '1.000.000 × 0.10 × 1 = 100.000.',
        ),
        QuizPregunta(
          pregunta: 'La inflación es:',
          opciones: const ['Aumento generalizado de precios', 'Bajada de precios', 'Estabilidad económica', 'Crecimiento del empleo'],
          correcta: 0,
          explicacion: 'Es el aumento sostenido del nivel general de precios.',
        ),
      ];

  static List<QuizPregunta> _bancoFilosofia() => [
        QuizPregunta(
          pregunta: '"Pienso, luego existo" es una frase de:',
          opciones: const ['Platón', 'Aristóteles', 'Descartes', 'Kant'],
          correcta: 2,
          explicacion: 'Cogito ergo sum, de René Descartes.',
        ),
        QuizPregunta(
          pregunta: 'La ética estudia:',
          opciones: const ['El origen del universo', 'La conducta moral del ser humano', 'Las leyes del Estado', 'Las matemáticas puras'],
          correcta: 1,
          explicacion: 'Es la rama que reflexiona sobre lo bueno y lo correcto.',
        ),
        QuizPregunta(
          pregunta: 'Un silogismo válido tiene:',
          opciones: const ['1 premisa y 1 conclusión', '2 premisas y 1 conclusión', '3 premisas y 2 conclusiones', 'Solo conclusiones'],
          correcta: 1,
          explicacion: 'Premisa mayor + premisa menor → conclusión.',
        ),
      ];

  static List<QuizPregunta> _bancoPsicologia() => [
        QuizPregunta(
          pregunta: 'El padre del psicoanálisis es:',
          opciones: const ['Skinner', 'Freud', 'Pavlov', 'Watson'],
          correcta: 1,
          explicacion: 'Sigmund Freud fundó el psicoanálisis.',
        ),
        QuizPregunta(
          pregunta: 'El experimento del perro de Pavlov demuestra:',
          opciones: const ['Condicionamiento clásico', 'Condicionamiento operante', 'Aprendizaje social', 'Inteligencia emocional'],
          correcta: 0,
          explicacion: 'Asociación entre estímulo neutro y respuesta.',
        ),
        QuizPregunta(
          pregunta: 'Las tres instancias psíquicas según Freud son:',
          opciones: const ['Mente, cuerpo, alma', 'Yo, super-yo, ello', 'Pasado, presente, futuro', 'Razón, emoción, instinto'],
          correcta: 1,
          explicacion: 'Yo (consciente), super-yo (moral), ello (impulsos).',
        ),
      ];

  static List<QuizPregunta> _bancoGeografia() => [
        QuizPregunta(
          pregunta: '¿Cuál es el continente más grande?',
          opciones: const ['África', 'Asia', 'América', 'Europa'],
          correcta: 1,
          explicacion: 'Asia es el continente más extenso del mundo.',
        ),
        QuizPregunta(
          pregunta: 'El río más largo del mundo es:',
          opciones: const ['Nilo', 'Amazonas', 'Yangtsé', 'Misisipi'],
          correcta: 1,
          explicacion: 'Estudios recientes ubican al Amazonas como el más largo.',
        ),
        QuizPregunta(
          pregunta: '¿Cuántos océanos hay en el mundo?',
          opciones: const ['3', '4', '5', '7'],
          correcta: 2,
          explicacion: 'Pacífico, Atlántico, Índico, Ártico y Antártico = 5.',
        ),
        QuizPregunta(
          pregunta: 'La capital de Colombia es:',
          opciones: const ['Medellín', 'Cali', 'Bogotá', 'Cartagena'],
          correcta: 2,
          explicacion: 'Bogotá D.C. es la capital de Colombia.',
        ),
      ];

  static List<QuizPregunta> _bancoLenguaArte() => [
        QuizPregunta(
          pregunta: '¿Cuál es un sustantivo?',
          opciones: const ['Correr', 'Bonito', 'Casa', 'Rápidamente'],
          correcta: 2,
          explicacion: 'Casa es un sustantivo (objeto/cosa).',
        ),
        QuizPregunta(
          pregunta: 'Una oración debe tener al menos:',
          opciones: const ['Un sustantivo', 'Un sujeto y un predicado', 'Una coma', 'Tres palabras'],
          correcta: 1,
          explicacion: 'Toda oración tiene sujeto y predicado.',
        ),
        QuizPregunta(
          pregunta: '"Don Quijote de la Mancha" fue escrito por:',
          opciones: const ['García Márquez', 'Cervantes', 'Borges', 'Neruda'],
          correcta: 1,
          explicacion: 'Miguel de Cervantes Saavedra.',
        ),
        QuizPregunta(
          pregunta: 'Un sinónimo de "feliz" es:',
          opciones: const ['Triste', 'Contento', 'Cansado', 'Enojado'],
          correcta: 1,
          explicacion: 'Contento expresa el mismo sentimiento.',
        ),
      ];

  static List<QuizPregunta> _bancoIngenieria() => [
        QuizPregunta(
          pregunta: 'La Ley de Ohm establece que V = ?',
          opciones: const ['I × R', 'I + R', 'I / R', 'I − R'],
          correcta: 0,
          explicacion: 'Voltaje = Intensidad × Resistencia.',
        ),
        QuizPregunta(
          pregunta: 'La unidad de potencia eléctrica es:',
          opciones: const ['Voltio', 'Amperio', 'Watt', 'Ohm'],
          correcta: 2,
          explicacion: 'P = V·I, medido en Watts (W).',
        ),
        QuizPregunta(
          pregunta: 'El concreto está compuesto principalmente por:',
          opciones: const ['Madera y agua', 'Cemento, arena, grava y agua', 'Solo cemento', 'Hierro y carbón'],
          correcta: 1,
          explicacion: 'La mezcla básica del hormigón.',
        ),
        QuizPregunta(
          pregunta: 'Una palanca es un ejemplo de:',
          opciones: const ['Fuente de energía', 'Máquina simple', 'Material conductor', 'Circuito eléctrico'],
          correcta: 1,
          explicacion: 'Es una de las máquinas simples clásicas.',
        ),
      ];

  static List<QuizPregunta> _bancoArquitectura() => [
        QuizPregunta(
          pregunta: 'La escala 1:100 significa que 1 cm en el plano equivale a:',
          opciones: const ['1 cm real', '10 cm reales', '100 cm reales', '1 km real'],
          correcta: 2,
          explicacion: '1 cm en el plano = 100 cm = 1 m en la realidad.',
        ),
        QuizPregunta(
          pregunta: 'Un plano arquitectónico básico debe incluir:',
          opciones: const ['Solo el color', 'Plantas, cortes y fachadas', 'Solo las puertas', 'Solo el mobiliario'],
          correcta: 1,
          explicacion: 'Es el conjunto mínimo para representar un proyecto.',
        ),
        QuizPregunta(
          pregunta: 'El estilo gótico se caracteriza por:',
          opciones: const ['Cúpulas redondas', 'Arcos ojivales y vitrales', 'Columnas dóricas', 'Pirámides escalonadas'],
          correcta: 1,
          explicacion: 'Arcos puntiagudos, bóvedas de crucería y vitrales.',
        ),
      ];

  static List<QuizPregunta> _bancoComunicacion() => [
        QuizPregunta(
          pregunta: 'Las 5W del periodismo son: qué, quién, cuándo, dónde y…',
          opciones: const ['Por qué', 'Cuánto', 'Cómo', 'Cuál'],
          correcta: 0,
          explicacion: 'En inglés "Why" → por qué. (What, Who, When, Where, Why)',
        ),
        QuizPregunta(
          pregunta: 'El lead o "entradilla" de una noticia es:',
          opciones: const ['El último párrafo', 'El primer párrafo con lo esencial', 'El título', 'La fuente'],
          correcta: 1,
          explicacion: 'Resume lo más importante en el primer párrafo.',
        ),
        QuizPregunta(
          pregunta: 'En comunicación, el "feedback" se refiere a:',
          opciones: const ['Una falla técnica', 'La respuesta del receptor', 'El ruido del canal', 'El emisor'],
          correcta: 1,
          explicacion: 'Es la retroalimentación del receptor al emisor.',
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
