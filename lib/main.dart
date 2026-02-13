import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

// COLORES INTELIGENTES
Color getColorMateria(String materia) {
  final m = materia.toLowerCase();
  if (m.contains('mat') || m.contains('calc') || m.contains('fis')) return Colors.redAccent;
  if (m.contains('prog') || m.contains('soft') || m.contains('datos')) return Colors.blueAccent;
  if (m.contains('ingl') || m.contains('idio')) return Colors.orangeAccent;
  if (m.contains('hist') || m.contains('huma')) return Colors.brown;
  return Colors.indigo;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tutorías UCatólica',
      theme: ThemeData(
          useMaterial3: true,
          primaryColor: const Color(0xFF0D47A1),
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D47A1), secondary: const Color(0xFFFFA000)),
          inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey[50]),
          elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))
      ),
      home: const AuthWrapper(),
    );
  }
}

class ProfileButton extends StatelessWidget {
  const ProfileButton({super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: CircleAvatar(backgroundColor: Colors.white24, child: IconButton(icon: const Icon(Icons.person, color: Colors.white), onPressed: () {
        final nameCtrl = TextEditingController(text: AuthService().currentUser?.displayName);
        showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("Editar Perfil"), content: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Tu Nombre Completo", prefixIcon: Icon(Icons.badge))), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")), ElevatedButton(onPressed: () async { await AuthService().updateName(nameCtrl.text); if(ctx.mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text("Perfil actualizado"))); } }, child: const Text("Guardar"))]));
      })),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});
  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    return StreamBuilder(stream: authService.authStateChanges, builder: (context, snapshot) {
      if (!snapshot.hasData) return const LoginPage();
      return FutureBuilder<String>(future: authService.getUserRole(), builder: (context, roleSnapshot) {
        if (!roleSnapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        return roleSnapshot.data == 'Profesor' ? const ProfessorDashboard() : const StudentDashboard();
      });
    });
  }
}
// ------------------------------------------------------------------
// LOGIN PAGE
// ------------------------------------------------------------------
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _auth = AuthService();
  String _rol = 'Estudiante';
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1565C0), Color(0xFF0D47A1)])),
        child: Center(
          child: SingleChildScrollView(
            child: Card(
              margin: const EdgeInsets.all(25), elevation: 8, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.school_rounded, size: 70, color: Color(0xFF0D47A1)), const SizedBox(height: 10),
                  const Text("Tutorías UCatólica", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))), const SizedBox(height: 30),
                  TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: "Correo Institucional", prefixIcon: Icon(Icons.email))), const SizedBox(height: 15),
                  TextField(controller: _passCtrl, decoration: const InputDecoration(labelText: "Contraseña", prefixIcon: Icon(Icons.lock)), obscureText: true), const SizedBox(height: 20),
                  DropdownButtonFormField<String>(value: _rol, decoration: const InputDecoration(labelText: "Rol", prefixIcon: Icon(Icons.person_outline)), items: ['Estudiante', 'Profesor'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(), onChanged: (v) => setState(() => _rol = v!)), const SizedBox(height: 30),
                  if (_loading) const CircularProgressIndicator() else ...[
                    ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)), onPressed: () async { setState(() => _loading = true); String? error = await _auth.login(email: _emailCtrl.text.trim(), password: _passCtrl.text.trim()); if (error != null && mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red)); setState(() => _loading = false); } }, child: const Text("INGRESAR")),
                    const SizedBox(height: 10),
                    TextButton(onPressed: () async { setState(() => _loading = true); String? error = await _auth.register(email: _emailCtrl.text.trim(), password: _passCtrl.text.trim(), role: _rol); if (mounted) { if (error == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cuenta creada. Inicia sesión."), backgroundColor: Colors.green)); await _auth.logout(); } else { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red)); } setState(() => _loading = false); } }, child: const Text("Crear cuenta nueva"))
                  ]
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
// ------------------------------------------------------------------
// STUDENT DASHBOARD
// ------------------------------------------------------------------
class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});
  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  String _busqueda = "";

  void _mostrarDialogoReserva(BuildContext context, String docId, Map<String, dynamic> data) {
    final notaCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(title: Text("Reservar: ${data['materia']}"), content: Column(mainAxisSize: MainAxisSize.min, children: [const Text("Mensaje (opcional):"), TextField(controller: notaCtrl, maxLines: 2)]), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")), ElevatedButton(onPressed: () async { final user = AuthService().currentUser!; await FirebaseFirestore.instance.collection('tutorias').doc(docId).update({'status': 'reservada', 'studentId': user.uid, 'studentEmail': user.email, 'notaEstudiante': notaCtrl.text}); if(ctx.mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text("✅ Reserva exitosa"))); } }, child: const Text("Confirmar"))]));
  }

  void _cancelarReserva(BuildContext context, String docId) {
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("Cancelar"), content: const Text("¿Liberar cupo?"), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Volver")), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () async { await FirebaseFirestore.instance.collection('tutorias').doc(docId).update({'status': 'disponible', 'studentId': null, 'studentEmail': null, 'notaEstudiante': null}); if(ctx.mounted) Navigator.pop(ctx); }, child: const Text("Sí, cancelar"))]));
  }

  Widget _buildClassCard(Map<String, dynamic> data, String docId, bool isReserved) {
    final fecha = (data['fecha'] as Timestamp).toDate();
    final color = getColorMateria(data['materia']);
    final estado = data['status'];
    bool enCurso = estado == 'en_curso';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(color: enCurso ? Colors.purple[50] : Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))], border: enCurso ? Border.all(color: Colors.purple, width: 2) : null),
      child: Column(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10), decoration: BoxDecoration(color: enCurso ? Colors.purple : color.withOpacity(0.1), borderRadius: const BorderRadius.vertical(top: Radius.circular(15))), child: Row(children: [Icon(Icons.class_, color: enCurso ? Colors.white : color), const SizedBox(width: 10), Expanded(child: Text(data['materia'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: enCurso ? Colors.white : color))), if(enCurso) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)), child: const Text("🔴 EN VIVO", style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 10))) else if(isReserved) const Chip(label: Text("Reservada", style: TextStyle(color: Colors.white, fontSize: 10)), backgroundColor: Colors.green)])),
        Padding(padding: const EdgeInsets.all(15), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const Icon(Icons.calendar_today, size: 16), const SizedBox(width: 5), Text(DateFormat('EEE d MMM, hh:mm a').format(fecha))]), const SizedBox(height: 5), if(isReserved || enCurso) Text("🔗 ${data['link']}", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)) else Text("Prof: ${data['teacherEmail'].split('@')[0]}", style: TextStyle(color: Colors.grey[600]))])), Column(children: [if(!enCurso) ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: isReserved ? Colors.red[50] : color, foregroundColor: isReserved ? Colors.red : Colors.white, elevation: 0), onPressed: () => isReserved ? _cancelarReserva(context, docId) : _mostrarDialogoReserva(context, docId, data), child: Text(isReserved ? "Cancelar" : "Reservar")), if(enCurso) ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white), icon: const Icon(Icons.videocam), label: const Text("UNIRSE"), onPressed: (){}), if(isReserved && !enCurso) Padding(padding: const EdgeInsets.only(top: 8), child: OutlinedButton.icon(icon: const Icon(Icons.event, size: 16), label: const Text("Agendar"), onPressed: () { Add2Calendar.addEvent2Cal(Event(title: "Tutoría: ${data['materia']}", description: "Link: ${data['link']}", location: data['link']??'Virtual', startDate: fecha, endDate: fecha.add(const Duration(hours: 1)))); }))])]))
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser!;
    return DefaultTabController(length: 3, child: Scaffold(backgroundColor: Colors.grey[100], appBar: AppBar(title: const Text("Panel Estudiante", style: TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF0D47A1), elevation: 0, actions: [const ProfileButton(), IconButton(icon: const Icon(Icons.exit_to_app, color: Colors.white), onPressed: () => AuthService().logout())], bottom: const TabBar(labelColor: Colors.white, unselectedLabelColor: Colors.white60, indicatorColor: Colors.amber, tabs: [Tab(text: "Disponibles", icon: Icon(Icons.search)), Tab(text: "Mis Reservas", icon: Icon(Icons.bookmark)), Tab(text: "Historial", icon: Icon(Icons.history))])),
      body: TabBarView(children: [
        Column(children: [Container(color: const Color(0xFF0D47A1), padding: const EdgeInsets.fromLTRB(15, 0, 15, 20), child: TextField(onChanged: (v) => setState(() => _busqueda = v.toLowerCase()), decoration: const InputDecoration(hintText: "Buscar materia...", prefixIcon: Icon(Icons.search), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(30)), borderSide: BorderSide.none)))), Expanded(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('tutorias').where('status', whereIn: ['disponible', 'en_curso']).snapshots(), builder: (ctx, snap) { if (!snap.hasData) return const Center(child: CircularProgressIndicator()); final docs = snap.data!.docs.where((d) { final data = d.data() as Map; return data['materia'].toString().toLowerCase().contains(_busqueda); }).toList(); if(docs.isEmpty) return const Center(child: Text("No hay clases disponibles")); return ListView.builder(itemCount: docs.length, itemBuilder: (c, i) => _buildClassCard(docs[i].data() as Map<String, dynamic>, docs[i].id, false)); }))]),
        StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('tutorias').where('studentId', isEqualTo: user.uid).snapshots(), builder: (ctx, snap) { if (!snap.hasData) return const Center(child: CircularProgressIndicator()); final docs = snap.data!.docs.where((d) => (d.data() as Map)['status'] != 'finalizada').toList(); if(docs.isEmpty) return const Center(child: Text("No tienes reservas activas")); return ListView.builder(itemCount: docs.length, itemBuilder: (c, i) => _buildClassCard(docs[i].data() as Map<String, dynamic>, docs[i].id, true)); }),
        StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('tutorias').where('studentId', isEqualTo: user.uid).where('status', isEqualTo: 'finalizada').snapshots(), builder: (ctx, snap) { if (!snap.hasData) return const Center(child: CircularProgressIndicator()); if(snap.data!.docs.isEmpty) return const Center(child: Text("Sin historial")); return ListView.builder(itemCount: snap.data!.docs.length, itemBuilder: (c, i) { final data = snap.data!.docs[i].data() as Map<String, dynamic>; return ListTile(leading: const Icon(Icons.check_circle, color: Colors.grey), title: Text(data['materia'], style: const TextStyle(decoration: TextDecoration.lineThrough)), subtitle: Text(DateFormat('dd/MM/yyyy').format((data['fecha'] as Timestamp).toDate()))); }); }),
      ]),
    ));
  }
}
// ------------------------------------------------------------------
// PROFESSOR DASHBOARD
// ------------------------------------------------------------------
class ProfessorDashboard extends StatefulWidget {
  const ProfessorDashboard({super.key});
  @override
  State<ProfessorDashboard> createState() => _ProfessorDashboardState();
}

class _ProfessorDashboardState extends State<ProfessorDashboard> {
  void _crearTutoria() {
    final mC = TextEditingController(); final dC = TextEditingController(); final lC = TextEditingController();
    DateTime f = DateTime.now(); TimeOfDay h = TimeOfDay.now();
    showDialog(context: context, builder: (context) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(title: const Text("Nueva Clase"), content: SingleChildScrollView(child: Column(children: [TextField(controller: mC, decoration: const InputDecoration(labelText: "Materia", prefixIcon: Icon(Icons.book))), const SizedBox(height: 10), TextField(controller: dC, decoration: const InputDecoration(labelText: "Tema", prefixIcon: Icon(Icons.topic))), const SizedBox(height: 10), TextField(controller: lC, decoration: const InputDecoration(labelText: "Link Meet/Zoom", prefixIcon: Icon(Icons.link))), const SizedBox(height: 20), Row(children: [Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.calendar_month), label: Text("${f.day}/${f.month}"), onPressed: () async { final d = await showDatePicker(context: ctx, initialDate: f, firstDate: DateTime.now(), lastDate: DateTime(2026)); if(d!=null) setS(()=>f=d); })), const SizedBox(width: 10), Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.schedule), label: Text(h.format(ctx)), onPressed: () async { final t = await showTimePicker(context: ctx, initialTime: h); if(t!=null) setS(()=>h=t); }))])])), actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancelar")), ElevatedButton(onPressed: () async { if(mC.text.isEmpty) return; final user=AuthService().currentUser!; await FirebaseFirestore.instance.collection('tutorias').add({'materia': mC.text, 'descripcion': dC.text, 'link': lC.text, 'teacherId': user.uid, 'teacherEmail': user.email, 'fecha': Timestamp.fromDate(DateTime(f.year, f.month, f.day, h.hour, h.minute)), 'status': 'disponible'}); if(mounted){Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Clase creada"), backgroundColor: Colors.green));} }, child: const Text("Publicar"))])));
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser!;
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(title: const Text("Gestión de Clases", style: TextStyle(color: Colors.white)), backgroundColor: Colors.orange[800], actions: [const ProfileButton(), IconButton(icon: const Icon(Icons.exit_to_app, color: Colors.white), onPressed: () => AuthService().logout())]),
      body: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('tutorias').where('teacherId', isEqualTo: user.uid).snapshots(), builder: (ctx, snap) {
        if(!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if(docs.isEmpty) return const Center(child: Text("Sin clases creadas"));

        return ListView.builder(itemCount: docs.length, itemBuilder: (c, i) {
          final data = docs[i].data() as Map<String, dynamic>; final id = docs[i].id; final fecha = (data['fecha'] as Timestamp).toDate(); final estado = data['status'] ?? 'disponible';
          Color colorEstado = Colors.green;
          if(estado == 'reservada') colorEstado = Colors.red;
          if(estado == 'en_curso') colorEstado = Colors.purple;
          if(estado == 'finalizada') colorEstado = Colors.grey;

          return Card(margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8), elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), child: Column(children: [
            Container(height: 8, decoration: BoxDecoration(color: colorEstado, borderRadius: const BorderRadius.vertical(top: Radius.circular(15)))),
            ListTile(title: Text(data['materia'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const SizedBox(height: 5), Text("📅 ${DateFormat('dd/MMM - HH:mm').format(fecha)}"), Text("Tema: ${data['descripcion']}", maxLines: 1, overflow: TextOverflow.ellipsis), if(data.containsKey('studentEmail') && data['studentEmail'] != null) Text("👤 Alumno: ${data['studentEmail']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo))]), trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => FirebaseFirestore.instance.collection('tutorias').doc(id).delete())),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Estado:", style: TextStyle(fontWeight: FontWeight.bold)), Container(padding: const EdgeInsets.symmetric(horizontal: 10), decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)), child: DropdownButton<String>(value: estado, underline: Container(), items: const [DropdownMenuItem(value: 'disponible', child: Text("🟢 Disponible")), DropdownMenuItem(value: 'reservada', child: Text("🔴 Reservada")), DropdownMenuItem(value: 'en_curso', child: Text("🟣 En Curso")), DropdownMenuItem(value: 'finalizada', child: Text("⚫ Finalizada"))], onChanged: (nuevo) { if(nuevo != null) FirebaseFirestore.instance.collection('tutorias').doc(id).update({'status': nuevo}); }))]))
          ]));
        });
      }),
      floatingActionButton: FloatingActionButton.extended(backgroundColor: Colors.orange[800], onPressed: _crearTutoria, icon: const Icon(Icons.add), label: const Text("Nueva")),
    );
  }
}