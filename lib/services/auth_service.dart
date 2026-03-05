import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // Registro con validación de dominio
  Future<String?> register({required String email, required String password, required String role}) async {
    try {
      if (!email.endsWith('@ucatolica.edu.co')) {
        return 'Solo se permiten correos @ucatolica.edu.co';
      }

      UserCredential result = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password
      );

      // Guardamos datos extendidos incluyendo 'isStudentTutor'
      await _db.collection('users').doc(result.user!.uid).set({
        'email': email,
        'role': role, // 'Estudiante' o 'Profesor'
        'displayName': email.split('@')[0],
        'isStudentTutor': false, // Por defecto falso, se activa manual en Firebase
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (result.user != null && !result.user!.emailVerified) {
        await result.user!.sendEmailVerification();
        await _auth.signOut();
      }
      return null;
    } on FirebaseAuthException catch (e) { return e.message; } catch (e) { return 'Error: $e'; }
  }

  // Login
  Future<String?> login({required String email, required String password}) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      if (result.user != null && !result.user!.emailVerified) {
        await _auth.signOut();
        return 'Verifica tu correo antes de entrar.';
      }
      return null;
    } on FirebaseAuthException catch (e) { return e.message; }
  }

  // Obtener datos completos (Rol + si es Tutor)
  Future<Map<String, dynamic>> getUserData() async {
    if (currentUser == null) return {};
    try {
      final doc = await _db.collection('users').doc(currentUser!.uid).get();
      return doc.data() as Map<String, dynamic>;
    } catch (e) { return {}; }
  }

  Future<void> updateName(String name) async {
    if (currentUser == null) return;
    await _db.collection('users').doc(currentUser!.uid).update({'displayName': name});
    await currentUser!.updateDisplayName(name);
  }

  // Recuperar contraseña por correo
  Future<String?> resetPassword(String email) async {
    try {
      if (!email.endsWith('@ucatolica.edu.co')) {
        return 'Solo se permiten correos @ucatolica.edu.co';
      }
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Error: $e';
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}