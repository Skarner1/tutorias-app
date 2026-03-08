import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'gemini_service.dart';

class IAResult {
  final int score;
  final String nivelRiesgo;
  final String recomendacion;
  final int materias;
  final int tutorias;
  final String justificacion;
  // Nuevos campos enriquecidos
  final double horasSemanales;
  final Map<String, double> cargaPorDia;
  final List<String> diasSobrecargados;
  final List<String> sugerencias;
  final String scoreDetalle;
  /// true si el diagnóstico/recomendación fue generado por Gemini AI
  final bool usaGemini;

  IAResult({
    required this.score,
    required this.nivelRiesgo,
    required this.recomendacion,
    required this.materias,
    required this.tutorias,
    required this.justificacion,
    required this.horasSemanales,
    required this.cargaPorDia,
    required this.diasSobrecargados,
    required this.sugerencias,
    required this.scoreDetalle,
    this.usaGemini = false,
  });

  IAResult copyWith({
    String? justificacion,
    String? recomendacion,
    bool? usaGemini,
  }) {
    return IAResult(
      score: score,
      nivelRiesgo: nivelRiesgo,
      recomendacion: recomendacion ?? this.recomendacion,
      materias: materias,
      tutorias: tutorias,
      justificacion: justificacion ?? this.justificacion,
      horasSemanales: horasSemanales,
      cargaPorDia: cargaPorDia,
      diasSobrecargados: diasSobrecargados,
      sugerencias: sugerencias,
      scoreDetalle: scoreDetalle,
      usaGemini: usaGemini ?? this.usaGemini,
    );
  }
}

class AIService {
  final FirebaseFirestore firestore;
  AIService({required this.firestore});

  static const int maxMaterias = 7;
  static const double maxHorasDiarias = 5.0;
  static const double horasIdealSemanales = 20.0;

  Future<IAResult> analizarEstudiante(String uid) async {
    try {
      // 1. Obtener todas las entradas del horario del estudiante
      final horarioSnap = await firestore.collection('users').doc(uid).collection('horario').get();
      final List<Map<String, dynamic>> bloques = horarioSnap.docs.map((d) => d.data()).toList();

      // Materias únicas (por nombre)
      final Set<String> materiasUnicas = bloques
          .map((b) => (b['materia'] as String? ?? '').toLowerCase().trim())
          .where((m) => m.isNotEmpty)
          .toSet();
      final int numMaterias = materiasUnicas.length;

      // 2. Calcular horas por día y total semanal
      final Map<String, double> cargaPorDia = {};
      for (final bloque in bloques) {
        final String dia = bloque['dia'] as String? ?? '';
        final int inicio = bloque['horaInicio'] as int? ?? 0;
        final int fin = bloque['horaFin'] as int? ?? 0;
        final double horas = _horasEntreMilitar(inicio, fin);
        cargaPorDia[dia] = (cargaPorDia[dia] ?? 0) + horas;
      }
      final double horasSemanales = cargaPorDia.values.fold(0.0, (a, b) => a + b);

      // 3. Detectar días sobrecargados (> maxHorasDiarias)
      final List<String> diasSobrecargados = cargaPorDia.entries
          .where((e) => e.value > maxHorasDiarias)
          .map((e) => '${e.key} (${e.value.toStringAsFixed(1)}h)')
          .toList();

      // 4. Tutorías inscritas
      final tutoriasPropSnap = await firestore.collection('tutorias').where('studentId', isEqualTo: uid).get();
      final tutoriasGrupoSnap = await firestore.collection('tutorias').where('participants', arrayContains: uid).get();
      final int numTutorias = tutoriasPropSnap.docs.length + tutoriasGrupoSnap.docs.length;

      // 5. CALCULAR SCORE con 4 componentes
      // A) Cobertura de materias (0-35 pts): qué tan cerca está del ideal de 5 materias
      const int materiasIdeal = 5;
      double scoreMaterias = 0;
      if (numMaterias == 0) {
        scoreMaterias = 0;
      } else if (numMaterias <= materiasIdeal) {
        scoreMaterias = (numMaterias / materiasIdeal) * 35;
      } else {
        // Penalizar exceso: más de 7 baja el score
        scoreMaterias = 35 - ((numMaterias - materiasIdeal) * 3.0).clamp(0, 15);
      }

      // B) Carga horaria semanal (0-30 pts): ideal 15-22 horas
      double scoreHoras = 0;
      if (horasSemanales >= 15 && horasSemanales <= 22) {
        scoreHoras = 30; // Zona ideal
      } else if (horasSemanales < 15) {
        scoreHoras = (horasSemanales / 15) * 30;
      } else {
        // Penaliza sobrecarga (>22h)
        scoreHoras = (30 - ((horasSemanales - 22) * 2.5)).clamp(0, 30);
      }

      // C) Balance entre días (0-20 pts): penaliza días sobrecargados
      double scoreBalance = 20;
      scoreBalance -= (diasSobrecargados.length * 6.0).clamp(0, 20);

      // D) Uso de tutorías (0-15 pts): 1-3 tutorías es ideal
      double scoreTutorias = 0;
      if (numTutorias == 0 && numMaterias > 0) {
        scoreTutorias = 5; // Tiene materias pero no usa tutorías: score bajo
      } else if (numTutorias >= 1 && numTutorias <= 3) {
        scoreTutorias = 15; // Uso ideal
      } else if (numTutorias > 3) {
        scoreTutorias = (15 - ((numTutorias - 3) * 3.0)).clamp(5, 15);
      }

      final double scoreTotal = (scoreMaterias + scoreHoras + scoreBalance + scoreTutorias).clamp(0, 100);
      final int score = scoreTotal.round();
      final String riesgo = _clasificarRiesgo(score);

      // 6. Construir desglose numérico explícito
      final String scoreDetalle = _construirDesglose(
        score: score,
        numMaterias: numMaterias,
        scoreMaterias: scoreMaterias,
        horasSemanales: horasSemanales,
        scoreHoras: scoreHoras,
        diasSobrecargados: diasSobrecargados,
        scoreBalance: scoreBalance,
        numTutorias: numTutorias,
        scoreTutorias: scoreTutorias,
      );

      // 7. Justificación de riesgo (diagnóstico claro)
      final String justificacion = _construirJustificacion(
        riesgo: riesgo,
        numMaterias: numMaterias,
        horasSemanales: horasSemanales,
        diasSobrecargados: diasSobrecargados,
        numTutorias: numTutorias,
        score: score,
      );

      // 8. Buscar sugerencias de tutorías disponibles para las materias del estudiante
      final List<String> sugerencias = [];
      final tutoriasLibresSnap = await firestore.collection('tutorias').where('status', isEqualTo: 'disponible').get();
      for (var doc in tutoriasLibresSnap.docs) {
        final data = doc.data();
        if (data['tipo'] == 'GrupoEstudio') continue;
        final mat = (data['materia'] as String? ?? '').toLowerCase().trim();
        if (materiasUnicas.contains(mat)) {
          final DateTime fecha = (data['fecha'] as Timestamp).toDate();
          final String diaStr = _capitalizar(DateFormat('EEEE d', 'es_ES').format(fecha));
          final String horaStr = DateFormat('hh:mm a').format(fecha);
          sugerencias.add('📅 ${data['materia']}: $diaStr a las $horaStr con ${data['teacherName']}.');
        }
      }
      final horariosFijosSnap = await firestore.collection('horarios_profesores').get();
      for (var doc in horariosFijosSnap.docs) {
        final data = doc.data();
        final mat = (data['materia'] as String? ?? '').toLowerCase().trim();
        if (materiasUnicas.contains(mat)) {
          sugerencias.add('🏫 ${data['materia']}: ${data['dia']} de ${_formatoHora(data['horaInicio'])} a ${_formatoHora(data['horaFin'])} con ${data['teacherName']}.');
        }
      }

      // 9. Recomendación base contextual
      final String recomendacionFinal = _generarRecomendacion(
        riesgo: riesgo,
        numMaterias: numMaterias,
        horasSemanales: horasSemanales,
        diasSobrecargados: diasSobrecargados,
        numTutorias: numTutorias,
        sugerencias: sugerencias,
      );

      final IAResult localResult = IAResult(
        score: score,
        nivelRiesgo: riesgo,
        recomendacion: recomendacionFinal,
        materias: numMaterias,
        tutorias: numTutorias,
        justificacion: justificacion,
        horasSemanales: horasSemanales,
        cargaPorDia: cargaPorDia,
        diasSobrecargados: diasSobrecargados,
        sugerencias: sugerencias.take(4).toList(),
        scoreDetalle: scoreDetalle,
      );

      // Intentar enriquecer con Gemini AI (si está disponible)
      debugPrint('🔍 AIService: GeminiService.disponible = ${GeminiService.disponible}');
      if (GeminiService.disponible) {
        try {
          final geminiData = await GeminiService.enriquecerAnalisis(
            score: score,
            nivelRiesgo: riesgo,
            numMaterias: numMaterias,
            horasSemanales: horasSemanales,
            diasSobrecargados: diasSobrecargados,
            numTutorias: numTutorias,
            sugerenciasTutorias: sugerencias.take(4).toList(),
            scoreDetalle: scoreDetalle,
          );
          debugPrint('✅ AIService: Gemini respondió correctamente, usando análisis enriquecido.');
          return localResult.copyWith(
            justificacion: geminiData['justificacion'],
            recomendacion: geminiData['recomendacion'],
            usaGemini: true,
          );
        } catch (e) {
          // Fallback silencioso: devolver análisis local sin Gemini
          debugPrint('❌ AIService: Gemini falló ($e), usando análisis local como fallback.');
          return localResult;
        }
      }

      return localResult;
    } catch (e) {
      throw Exception('Error en IA: $e');
    }
  }

  // Convierte formato militar a horas decimales
  double _horasEntreMilitar(int inicio, int fin) {
    final double hInicio = (inicio ~/ 100) + (inicio % 100) / 60.0;
    final double hFin = (fin ~/ 100) + (fin % 100) / 60.0;
    return (hFin - hInicio).clamp(0, 12);
  }

  String _clasificarRiesgo(int score) {
    if (score < 40) return 'Alto';
    if (score < 70) return 'Medio';
    return 'Bajo';
  }

  String _construirDesglose({
    required int score,
    required int numMaterias,
    required double scoreMaterias,
    required double horasSemanales,
    required double scoreHoras,
    required List<String> diasSobrecargados,
    required double scoreBalance,
    required int numTutorias,
    required double scoreTutorias,
  }) {
    return '''
📊 Desglose de tu puntuación ($score/100):

① Cobertura de materias → ${scoreMaterias.toStringAsFixed(0)}/35 pts
   Tienes $numMaterias materia(s). El ideal universitario es 5.
   ${numMaterias == 0 ? '⚠️ Sin materias registradas.' : numMaterias < 3 ? '⚠️ Pocas materias: considera ampliar tu carga.' : numMaterias <= 5 ? '✅ Carga equilibrada.' : '⚠️ Carga alta: vigila tu rendimiento.'}

② Carga horaria semanal → ${scoreHoras.toStringAsFixed(0)}/30 pts
   Llevas ${horasSemanales.toStringAsFixed(1)}h/semana. La zona ideal es 15-22h.
   ${horasSemanales < 10 ? '⚠️ Muy poca carga: podrías aprovechar más el tiempo.' : horasSemanales <= 22 ? '✅ Carga horaria en rango saludable.' : '🔴 Sobrecarga horaria: riesgo de agotamiento.'}

③ Balance entre días → ${scoreBalance.toStringAsFixed(0)}/20 pts
   ${diasSobrecargados.isEmpty ? '✅ Ningún día supera las 5h. ¡Excelente distribución!' : '⚠️ Días con más de 5h: ${diasSobrecargados.join(', ')}. Redistribuye clases.'}

④ Uso de tutorías → ${scoreTutorias.toStringAsFixed(0)}/15 pts
   Tienes $numTutorias tutoría(s) activa(s). El rango ideal es 1-3.
   ${numTutorias == 0 ? '💡 No usas tutorías: úsalas para reforzar materias difíciles.' : numTutorias <= 3 ? '✅ Buen uso de tutorías.' : '⚠️ Muchas tutorías activas pueden indicar dificultades acumuladas.'}'''.trim();
  }

  String _construirJustificacion({
    required String riesgo,
    required int numMaterias,
    required double horasSemanales,
    required List<String> diasSobrecargados,
    required int numTutorias,
    required int score,
  }) {
    final String emoji = riesgo == 'Alto' ? '🔴' : riesgo == 'Medio' ? '🟡' : '🟢';
    String texto = '$emoji Riesgo Académico $riesgo — Score: $score/100\n\n';

    if (numMaterias == 0) {
      return texto + 'No tienes materias registradas en tu horario. Agrega tus clases para que la IA pueda hacer un análisis completo y personalizado de tu situación académica.';
    }

    texto += 'Tu perfil académico actual:\n';
    texto += '• $numMaterias materia(s) registradas\n';
    texto += '• ${horasSemanales.toStringAsFixed(1)} horas de clases por semana\n';
    texto += '• $numTutorias tutoría(s) activa(s)\n';
    if (diasSobrecargados.isNotEmpty) {
      texto += '• Días sobrecargados: ${diasSobrecargados.join(', ')}\n';
    }
    texto += '\n';

    switch (riesgo) {
      case 'Alto':
        texto += 'El análisis detecta señales de riesgo académico. ';
        if (horasSemanales > 22) texto += 'Tu carga horaria semanal (${horasSemanales.toStringAsFixed(1)}h) supera el límite recomendado de 22h, lo que puede llevar a fatiga y bajo rendimiento. ';
        if (diasSobrecargados.isNotEmpty) texto += 'Los días ${diasSobrecargados.join(' y ')} tienen demasiadas horas acumuladas. ';
        if (numMaterias < 3) texto += 'Con solo $numMaterias materia(s) hay poca continuidad académica. ';
        if (numTutorias > 4) texto += 'Tienes $numTutorias tutorías activas simultáneas, lo cual puede indicar dificultades en varias materias a la vez. ';
        texto += 'Es importante que tomes acción pronto para evitar que la situación se agrave.';
        break;
      case 'Medio':
        texto += 'Tu situación académica es aceptable, pero hay espacio de mejora. ';
        if (horasSemanales < 15) texto += 'Podrías aprovechar más el tiempo: solo llevas ${horasSemanales.toStringAsFixed(1)}h/semana. ';
        if (diasSobrecargados.isNotEmpty) texto += 'Algunos días están un poco cargados. Intenta distribuir mejor tus clases durante la semana. ';
        if (numTutorias == 0 && numMaterias > 0) texto += 'No estás usando tutorías: son un recurso valioso para reforzar los temas más difíciles. ';
        texto += 'Con ajustes menores puedes subir significativamente tu score.';
        break;
      default:
        texto += '¡Excelente situación académica! Llevas una carga equilibrada de ${horasSemanales.toStringAsFixed(1)}h/semana con $numMaterias materia(s). ';
        if (numTutorias > 0) texto += 'Además, usas las tutorías de forma proactiva, lo cual es un hábito muy positivo. ';
        texto += 'Sigue con esta dinámica y aprovecha los recursos disponibles para mantener tu rendimiento alto.';
    }

    return texto.trim();
  }

  String _generarRecomendacion({
    required String riesgo,
    required int numMaterias,
    required double horasSemanales,
    required List<String> diasSobrecargados,
    required int numTutorias,
    required List<String> sugerencias,
  }) {
    String texto = '';

    if (numMaterias == 0) {
      return 'Para comenzar, agrega tus materias y clases al horario. Esto permite que la IA analice tu carga real y te dé recomendaciones precisas.';
    }

    switch (riesgo) {
      case 'Alto':
        texto = 'Prioridad alta: necesitas reorganizar tu carga académica. ';
        if (diasSobrecargados.isNotEmpty) texto += 'Redistribuye las clases de los días sobrecargados (${diasSobrecargados.join(', ')}) hacia otros días con menos carga. ';
        if (horasSemanales > 22) texto += 'Considera reducir actividades no esenciales para bajar de las ${horasSemanales.toStringAsFixed(0)}h semanales actuales. ';
        texto += 'Las tutorías son clave para no quedarte atrás: asiste a las disponibles para tus materias con más dificultad.';
        break;
      case 'Medio':
        texto = 'Vas bien, pero puedes optimizar. ';
        if (numTutorias == 0) texto += 'Aprovecha las tutorías disponibles: incluso con buen desempeño, reforzar conceptos te dará una ventaja. ';
        if (horasSemanales < 15) texto += 'Tienes margen para agregar más actividades académicas o grupos de estudio. ';
        texto += 'Revisa qué materias te cuestan más y busca apoyo específico para ellas.';
        break;
      default:
        texto = '¡Sigue así! Mantén tu rutina actual. ';
        if (numTutorias == 0) texto += 'Aunque tu score es alto, las tutorías pueden ayudarte a ir por encima del promedio. ';
        texto += 'Considera unirte a grupos de estudio para mantener el ritmo y apoyar a otros compañeros.';
    }

    if (sugerencias.isNotEmpty) {
      texto += '\n\n📍 Espacios de tutoría disponibles para tus materias:\n';
      texto += sugerencias.take(4).join('\n');
    } else {
      texto += '\n\nActualmente no hay tutorías disponibles para tus materias. Revisa más tarde o consulta directamente con tus docentes.';
    }

    return texto.trim();
  }

  String _formatoHora(int militar) {
    int h = (militar / 100).floor();
    int m = militar % 100;
    return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}";
  }

  String _capitalizar(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
