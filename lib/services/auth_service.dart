import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Obtener usuario actual
  User? get currentUser => _auth.currentUser;

  // Registro restringido
  Future<String?> register({required String email, required String password}) async {
    try {
      if (!email.endsWith('@ucatolica.edu.co')) {
        return 'Error: Solo se permiten correos @ucatolica.edu.co';
      }
      UserCredential result = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password
      );
      await result.user?.sendEmailVerification();
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Error: $e';
    }
  }

  // Login
  Future<String?> login({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // Cerrar sesión
  Future<void> logout() async {
    await _auth.signOut();
  }
}