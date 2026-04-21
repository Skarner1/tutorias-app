import 'package:cloud_firestore/cloud_firestore.dart';

class TutoriasService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- GESTIÓN DE TUTORÍAS (PROFESOR) ---
  Future<void> crearTutoria({
    required String teacherId,
    required String teacherEmail,
    required String teacherName,
    required String materia,
    required String descripcion,
    required String link,
    required String tipo,
    required DateTime fecha,
  }) async {
    // Tutorías "Libre": expiran 1 día después de su fecha (sólo un día disponible)
    final DateTime expira = fecha.add(const Duration(days: 1));
    await _db.collection('tutorias').add({
      'teacherId': teacherId,
      'teacherEmail': teacherEmail,
      'teacherName': teacherName,
      'materia': materia,
      'descripcion': descripcion,
      'link': link,
      'tipo': tipo,
      'fecha': Timestamp.fromDate(fecha),
      'expiraEn': Timestamp.fromDate(expira),
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'disponible',
      'studentId': null,
      'studentEmail': null,
      'notaEstudiante': null,
      'materia_busqueda': materia.toLowerCase(),
      'participants': [], // Lista de alumnos que se han unido / la pidieron
    });
  }

  // --- GESTIÓN DE GRUPOS DE ESTUDIO ---
  Future<void> crearGrupoEstudio({
    required String creatorId,
    required String creatorName,
    required String materia,
    required String tema,
    required String lugar,
    required DateTime fecha,
  }) async {
    // Los grupos de estudio también caducan al día siguiente.
    final DateTime expira = fecha.add(const Duration(days: 1));
    await _db.collection('tutorias').add({
      'teacherId': creatorId, // El creador actúa como "teacher"
      'teacherName': creatorName,
      'materia': materia,
      'descripcion': tema,
      'link': lugar,
      'fecha': Timestamp.fromDate(fecha),
      'expiraEn': Timestamp.fromDate(expira),
      'createdAt': FieldValue.serverTimestamp(),
      'tipo': 'GrupoEstudio',
      'status': 'disponible',
      'participants': [],
    });
  }

  // Unirse a un grupo (Agregar ID al array)
  Future<void> unirseAGrupo(String docId, String studentId) async {
    await _db.collection('tutorias').doc(docId).update({
      'participants': FieldValue.arrayUnion([studentId])
    });
  }

  // Salir de un grupo (Quitar ID del array)
  Future<void> salirDeGrupo(String docId, String studentId) async {
    await _db.collection('tutorias').doc(docId).update({
      'participants': FieldValue.arrayRemove([studentId])
    });
  }

  // --- TUTORÍAS RECURRENTES (horarios_profesores) ---
  // Un estudiante se anota a una tutoría fija (lunes/martes/miércoles del semestre).
  Future<void> unirseABloqueFijo(String docId, String studentId) async {
    await _db.collection('horarios_profesores').doc(docId).update({
      'participants': FieldValue.arrayUnion([studentId]),
    });
  }

  Future<void> salirDeBloqueFijo(String docId, String studentId) async {
    await _db.collection('horarios_profesores').doc(docId).update({
      'participants': FieldValue.arrayRemove([studentId]),
    });
  }

  // El profesor puede modificar materia, día, horas, salón en cualquier momento
  Future<void> actualizarBloqueFijo(String docId, Map<String, dynamic> cambios) async {
    await _db.collection('horarios_profesores').doc(docId).update(cambios);
  }

  Future<void> borrarBloqueFijo(String docId) async {
    await _db.collection('horarios_profesores').doc(docId).delete();
  }

  // --- GESTIÓN DE PERFIL PROFESOR (MATERIAS QUE DICTA) ---
  Future<void> actualizarMateriasProfesor(String uid, List<String> materias) async {
    await _db.collection('users').doc(uid).update({
      'materias_dicta': materias,
    });
  }

  // --- GESTIÓN DE HORARIO ESTUDIANTE ---
  Future<void> agregarClaseEstudiante(String uid, String materia, String dia, int horaInicio, int horaFin, {String salon = ''}) async {
    await _db.collection('users').doc(uid).collection('horario').add({
      'materia': materia,
      'dia': dia,
      'horaInicio': horaInicio,
      'horaFin': horaFin,
      'salon': salon,
    });
  }

  Future<void> borrarClaseEstudiante(String uid, String docId) async {
    await _db.collection('users').doc(uid).collection('horario').doc(docId).delete();
  }

  Stream<QuerySnapshot> verHorarioEstudiante(String uid) {
    return _db.collection('users').doc(uid).collection('horario').snapshots();
  }

  // --- RESERVAS ---
  Future<void> reservarTutoria(String idTutoria, String studentId, String studentEmail, String nota) async {
    await _db.collection('tutorias').doc(idTutoria).update({
      'status': 'reservada',
      'studentId': studentId,
      'studentEmail': studentEmail,
      'notaEstudiante': nota,
      // También lo agregamos a participants para el conteo unificado.
      'participants': FieldValue.arrayUnion([studentId]),
    });
  }

  Future<void> cancelarReserva(String idTutoria) async {
    final doc = await _db.collection('tutorias').doc(idTutoria).get();
    final String? sid = (doc.data() ?? const {})['studentId'] as String?;
    final Map<String, dynamic> upd = {
      'status': 'disponible',
      'studentId': null,
      'studentEmail': null,
      'notaEstudiante': null,
    };
    if (sid != null) upd['participants'] = FieldValue.arrayRemove([sid]);
    await _db.collection('tutorias').doc(idTutoria).update(upd);
  }
}