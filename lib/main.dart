import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tutorías UCatólica',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});
  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    if (authService.currentUser != null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Bienvenido")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("¡Has iniciado sesión!"),
              ElevatedButton(
                onPressed: () async {
                  await authService.logout();
                  setState(() {});
                },
                child: const Text("Cerrar Sesión"),
              )
            ],
          ),
        ),
      );
    } else {
      return const LoginPage();
    }
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final AuthService _auth = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Acceso Tutorías")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Correo Institucional"),
            ),
            TextField(
              controller: _passController,
              decoration: const InputDecoration(labelText: "Contraseña"),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                String? error = await _auth.login(
                    email: _emailController.text.trim(),
                    password: _passController.text.trim()
                );
                if (error != null && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                } else {
                  setState(() {});
                }
              },
              child: const Text("Iniciar Sesión"),
            ),
            TextButton(
              onPressed: () async {
                String? error = await _auth.register(
                    email: _emailController.text.trim(),
                    password: _passController.text.trim()
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(error ?? "Registro exitoso. Revisa tu correo."),
                    backgroundColor: error == null ? Colors.green : Colors.red,
                  ));
                }
              },
              child: const Text("Registrarse (Solo @ucatolica)"),
            )
          ],
        ),
      ),
    );
  }
}