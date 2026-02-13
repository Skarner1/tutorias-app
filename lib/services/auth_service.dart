import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<String?> register({required String email, required String password, required String role}) async {
    try {
      if (!email.endsWith('@ucatolica.edu.co')) return 'Solo correos @ucatolica.edu.co';
      UserCredential result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      await _db.collection('users').doc(result.user!.uid).set({
        'email': email,
        'role': role,
        'displayName': email.split('@')[0], // Nombre por defecto
        'createdAt': FieldValue.serverTimestamp(),
      });
      return null;
    } on FirebaseAuthException catch (e) { return e.message; } catch (e) { return 'Error: $e'; }
  }

  Future<String?> login({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) { return e.message; }
  }

  Future<String> getUserRole() async {
    if (currentUser == null) return 'error';
    final doc = await _db.collection('users').doc(currentUser!.uid).get();
    return doc.data()?['role'] ?? 'Estudiante';
  }

  // --- NUEVA FUNCIÓN: ACTUALIZAR NOMBRE ---
  Future<void> updateName(String name) async {
    if (currentUser == null) return;
    await _db.collection('users').doc(currentUser!.uid).update({'displayName': name});
    await currentUser!.updateDisplayName(name);
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}