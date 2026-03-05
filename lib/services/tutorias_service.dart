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
    await _db.collection('tutorias').add({
      'teacherId': teacherId,
      'teacherEmail': teacherEmail,
      'teacherName': teacherName,
      'materia': materia,
      'descripcion': descripcion,
      'link': link,
      'tipo': tipo,
      'fecha': Timestamp.fromDate(fecha),
      'status': 'disponible',
      'studentId': null,
      'studentEmail': null,
      'notaEstudiante': null,
      'materia_busqueda': materia.toLowerCase(),
      'participants': [], // Inicializamos lista vacía para evitar errores
    });
  }

  // --- GESTIÓN DE GRUPOS DE ESTUDIO (NUEVO) ---
  Future<void> crearGrupoEstudio({
    required String creatorId,
    required String creatorName,
    required String materia,
    required String tema,
    required String lugar,
    required DateTime fecha,
  }) async {
    await _db.collection('tutorias').add({
      'teacherId': creatorId, // El creador actúa como "teacher"
      'teacherName': creatorName,
      'materia': materia,
      'descripcion': tema, // El tema específico
      'link': lugar, // El lugar físico
      'fecha': Timestamp.fromDate(fecha),
      'tipo': 'GrupoEstudio', // Tipo especial
      'status': 'disponible',
      'participants': [], // Lista de estudiantes que asisten
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
    });
  }

  Future<void> cancelarReserva(String idTutoria) async {
    await _db.collection('tutorias').doc(idTutoria).update({
      'status': 'disponible',
      'studentId': null,
      'studentEmail': null,
      'notaEstudiante': null,
    });
  }
}