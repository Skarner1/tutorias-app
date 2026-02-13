import 'package:cloud_firestore/cloud_firestore.dart';

class TutoriasService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> crearTutoria({
    required String teacherId,
    required String teacherEmail,
    required String materia,
    required DateTime fecha,
  }) async {
    await _db.collection('tutorias').add({
      'teacherId': teacherId,
      'teacherEmail': teacherEmail,
      'materia': materia,
      'fecha': Timestamp.fromDate(fecha),
      'status': 'disponible',
      'studentId': null,
      'studentEmail': null,
    });
  }

  // SIN ORDERBY PARA EVITAR ERRORES DE ÍNDICE
  Stream<QuerySnapshot> verTutoriasDisponibles() {
    return _db.collection('tutorias')
        .where('status', isEqualTo: 'disponible')
        .snapshots();
  }

  Future<void> reservarTutoria(String idTutoria, String studentId, String studentEmail) async {
    await _db.collection('tutorias').doc(idTutoria).update({
      'status': 'reservada',
      'studentId': studentId,
      'studentEmail': studentEmail,
    });
  }

  Stream<QuerySnapshot> verMisTutorias(String teacherId) {
    return _db.collection('tutorias')
        .where('teacherId', isEqualTo: teacherId)
        .snapshots();
  }
}