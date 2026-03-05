import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/auth_service.dart';
import 'services/tutorias_service.dart';
import 'services/ai_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await initializeDateFormatting('es_ES', null);
  runApp(const MyApp());
}

// --- SISTEMA DE DISEÑO MODERNO ---
class AppColors {
  static const Color primary = Color(0xFF0056D2);
  static const Color accent = Color(0xFF00C2FF);
  static const Color background = Color(0xFFF8FAFF);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);

  static const Color statusAvailable = Color(0xFFDCFCE7);
  static const Color textAvailable = Color(0xFF166534);
  static const Color statusConflict = Color(0xFFFEF3C7);
  static const Color textConflict = Color(0xFF92400E);
  static const Color error = Color(0xFFEF4444);
}

class AppTextStyles {
  static const TextStyle headline = TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: -0.5);
  static const TextStyle titleModern = TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: -1.0);
  static const TextStyle label = TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.5);
}

class AppTheme {
  static InputDecoration inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
      prefixIcon: Icon(icon, color: AppColors.primary),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.blue.shade50)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
    );
  }
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
          scaffoldBackgroundColor: AppColors.background,
          primaryColor: AppColors.primary,
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
          appBarTheme: const AppBarTheme(backgroundColor: AppColors.background, foregroundColor: AppColors.textPrimary, elevation: 0, centerTitle: false)
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});
  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) return const LoginPage();
        final user = snapshot.data!;
        if (!user.emailVerified) return const LoginPage();
        return FutureBuilder<Map<String, dynamic>>(
          future: authService.getUserData(),
          builder: (context, dataSnap) {
            if (!dataSnap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
            final userData = dataSnap.data!;
            final role = userData['role'] ?? 'Estudiante';
            final isStudentTutor = userData['isStudentTutor'] ?? false;
            if (role == 'Profesor') return const ProfessorDashboard();
            return StudentDashboard(isTutor: isStudentTutor);
          },
        );
      },
    );
  }
}

// LOGIN PAGE
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(40),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.auto_awesome, size: 60, color: AppColors.primary)),
              const SizedBox(height: 24),
              const Text("Bienvenido de nuevo", textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: -1)),
              const Text("Gestiona tus tutorías fácilmente", textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
              const SizedBox(height: 48),
              TextField(controller: _emailCtrl, decoration: AppTheme.inputDecoration("Correo Institucional", Icons.alternate_email)),
              const SizedBox(height: 16),
              TextField(controller: _passCtrl, obscureText: true, decoration: AppTheme.inputDecoration("Contraseña", Icons.lock_person_outlined)),
              const SizedBox(height: 24),
              if (_loading) const Center(child: CircularProgressIndicator()) else ...[
                ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 8, shadowColor: AppColors.primary.withOpacity(0.4)),
                    onPressed: () async { setState(() => _loading = true); String? error = await _auth.login(email: _emailCtrl.text.trim(), password: _passCtrl.text.trim()); if (error != null && mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: AppColors.error)); setState(() => _loading = false); } },
                    child: const Text("INICIAR SESIÓN", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _mostrarRecuperarContrasena,
                    child: const Text("¿Olvidaste tu contraseña?", style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(onPressed: () async { setState(() => _loading = true); String? error = await _auth.register(email: _emailCtrl.text.trim(), password: _passCtrl.text.trim(), role: _rol); if (mounted) { if (error == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cuenta creada. Revisa tu correo."), backgroundColor: Colors.green)); await _auth.logout(); } else { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: AppColors.error)); } setState(() => _loading = false); } }, child: const Text("Crear cuenta nueva", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)))
              ]
            ]),
          ),
        ),
      ),
    );
  }
  void _mostrarRecuperarContrasena() {
    final emailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    bool enviando = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.lock_reset_rounded, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text("Recuperar contraseña", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.textPrimary))),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 12),
            Text(
              "Te enviaremos un enlace a tu correo institucional para que puedas crear una nueva contraseña.",
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: AppTheme.inputDecoration("Correo institucional", Icons.alternate_email),
            ),
            const SizedBox(height: 20),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("CANCELAR", style: TextStyle(color: AppColors.textSecondary)),
            ),
            enviando
                ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      setS(() => enviando = true);
                      final email = emailCtrl.text.trim();
                      final error = await _auth.resetPassword(email);
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      if (error == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(children: const [
                              Icon(Icons.check_circle_outline, color: Colors.white),
                              SizedBox(width: 10),
                              Expanded(child: Text("¡Enviado! Revisa tu correo @ucatolica.edu.co")),
                            ]),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(error),
                            backgroundColor: AppColors.error,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      }
                    },
                    child: const Text("ENVIAR ENLACE", style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------
// STUDENT DASHBOARD
// ------------------------------------------------------------------
class StudentDashboard extends StatefulWidget {
  final bool isTutor;
  const StudentDashboard({super.key, this.isTutor = false});
  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> with SingleTickerProviderStateMixin {
  String _busqueda = "";
  final TutoriasService _tutoriasService = TutoriasService();
  final AIService _aiService = AIService(firestore: FirebaseFirestore.instance);
  final _user = AuthService().currentUser!;
  List<Map<String, dynamic>> _miHorarioCache = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _cargarHorarioLocal();
  }

  void _cargarHorarioLocal() async {
    FirebaseFirestore.instance.collection('users').doc(_user.uid).collection('horario').snapshots().listen((snap) {
      if (mounted) setState(() => _miHorarioCache = snap.docs.map((d) => { ...d.data(), 'id': d.id }).toList());
    });
  }

  String _traducirDia(String dayEnglish) {
    const map = {'Monday':'Lunes', 'Tuesday':'Martes', 'Wednesday':'Miércoles', 'Thursday':'Jueves', 'Friday':'Viernes', 'Saturday':'Sábado', 'Sunday':'Domingo'};
    return map[dayEnglish] ?? dayEnglish;
  }

  String _formatoHora(int militar) {
    int h = (militar / 100).floor(); int m = militar % 100;
    return "${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}";
  }

  bool _hayConflicto(DateTime fechaTutoria, int duracionHoras) {
    String diaSemana = _traducirDia(DateFormat('EEEE').format(fechaTutoria));
    int inicioTutoria = fechaTutoria.hour * 100 + fechaTutoria.minute;
    int finTutoria = inicioTutoria + (duracionHoras * 100);
    for (var clase in _miHorarioCache) { if (clase['dia'] == diaSemana) { if (inicioTutoria < clase['horaFin'] && finTutoria > clase['horaInicio']) return true; } }
    return false;
  }

  bool _hayConflictoFijo(String diaSemana, int horaInicio, int horaFin) {
    for (var clase in _miHorarioCache) { if (clase['dia'] == diaSemana) { if (horaInicio < clase['horaFin'] && horaFin > clase['horaInicio']) return true; } }
    return false;
  }

  Color _getMateriaColor(String materia) {
    final colors = [Colors.blue.shade100, Colors.green.shade100, Colors.orange.shade100, Colors.purple.shade100, Colors.teal.shade100];
    return colors[materia.length % colors.length];
  }

  Widget _buildUnifiedCard(Map<String, dynamic> data, String docId, bool esFijo) {
    String materia = data['materia'] ?? 'Sin materia';
    String profesor = data['teacherName'] ?? 'Docente';
    String tipo = esFijo ? 'Institucional' : (data['tipo'] == 'GrupoEstudio' ? 'Grupo de Estudio' : 'Espacio Libre');
    String horarioTexto = "";
    bool conflicto = false;

    if (esFijo) {
      horarioTexto = "${data['dia']}, ${_formatoHora(data['horaInicio'])} - ${_formatoHora(data['horaFin'])}";
      conflicto = _hayConflictoFijo(data['dia'], data['horaInicio'], data['horaFin']);
    } else {
      DateTime f = (data['fecha'] as Timestamp).toDate();
      horarioTexto = DateFormat('EEEE d MMMM • hh:mm a', 'es_ES').format(f);
      horarioTexto = horarioTexto[0].toUpperCase() + horarioTexto.substring(1);
      bool soyYo = (data['participants'] as List?)?.contains(_user.uid) ?? data['studentId'] == _user.uid;
      if (!soyYo) conflicto = _hayConflicto(f, 1);
    }

    int estadoVisual = 0;
    bool soyParticipante = (data['participants'] as List?)?.contains(_user.uid) ?? data['studentId'] == _user.uid;
    if (data['teacherId'] == _user.uid && data['tipo'] == 'GrupoEstudio') estadoVisual = 4;
    else if (soyParticipante) estadoVisual = 2;
    else if (conflicto) estadoVisual = 1;
    else if (!esFijo && data['status'] == 'reservada') estadoVisual = 3;

    Color colorEstado = AppColors.primary;
    String labelStatus = "Disponible";
    if(estadoVisual==1) { colorEstado = Colors.orange; labelStatus="Cruce de Horario"; }
    if(estadoVisual==2) { colorEstado = Colors.green; labelStatus="Ya Inscrito"; }
    if(estadoVisual==3) { colorEstado = Colors.grey; labelStatus="Sin Cupos"; }

    // Detectar si el grupo es fuera del campus
    final String lugarRaw = data['link'] ?? data['salon'] ?? '';
    final bool esFueraCampus = lugarRaw.startsWith('⚠️ FUERA CAMPUS:');
    final String lugarDisplay = esFueraCampus
        ? lugarRaw.replaceFirst('⚠️ FUERA CAMPUS: ', '').replaceFirst('⚠️ FUERA CAMPUS:', '')
        : lugarRaw;
    final bool mostrarLugar = lugarDisplay.isNotEmpty && data['tipo'] == 'GrupoEstudio';
    final bool mostrarLugarFijo = esFijo && (data['salon'] ?? '').toString().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 8))]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: IntrinsicHeight(
          child: Row(children: [
            Container(width: 6, color: colorEstado),
            Expanded(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: colorEstado.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(labelStatus, style: TextStyle(color: colorEstado, fontSize: 10, fontWeight: FontWeight.w800))),
                  Text(tipo.toUpperCase(), style: AppTextStyles.label)
                ]),
                const SizedBox(height: 12),
                Text(materia, style: AppTextStyles.headline),
                const SizedBox(height: 12),
                Row(children: [Icon(Icons.calendar_month, size: 16, color: AppColors.textSecondary), const SizedBox(width: 8), Expanded(child: Text(horarioTexto, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500)))]),
                const SizedBox(height: 6),
                Row(children: [Icon(Icons.person_pin, size: 16, color: AppColors.textSecondary), const SizedBox(width: 8), Text(profesor, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500))]),
                // Lugar del grupo de estudio
                if (mostrarLugar) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.place_outlined, size: 16, color: esFueraCampus ? Colors.orange : Colors.teal),
                    const SizedBox(width: 8),
                    Expanded(child: Text(lugarDisplay, style: TextStyle(color: esFueraCampus ? Colors.orange.shade700 : Colors.teal.shade700, fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis)),
                  ]),
                ],
                // Salón del bloque fijo del profesor
                if (mostrarLugarFijo) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.meeting_room_outlined, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(data['salon'].toString(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis)),
                  ]),
                ],
                // Advertencia fuera del campus
                if (esFueraCampus && !soyParticipante) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.shade200)),
                    child: Row(children: [
                      Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange.shade700),
                      const SizedBox(width: 6),
                      Expanded(child: Text("Este encuentro es fuera del campus. Se recomienda reunirse dentro de la universidad.", style: TextStyle(fontSize: 11, color: Colors.orange.shade800, height: 1.4))),
                    ]),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: estadoVisual==2 ? Colors.green.shade50 : (estadoVisual==1 || estadoVisual==3 ? Colors.grey.shade50 : AppColors.primary), foregroundColor: estadoVisual==2 ? Colors.green : (estadoVisual==1 || estadoVisual==3 ? Colors.grey : Colors.white), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                    onPressed: estadoVisual==1 || estadoVisual==3 ? null : () {
                      if(estadoVisual==4) _borrarGrupo(docId);
                      else if(estadoVisual==2) { if(data['tipo']=='GrupoEstudio') _tutoriasService.salirDeGrupo(docId, _user.uid); else if(!esFijo) _cancelarReserva(context, docId); }
                      else { if(data['tipo']=='GrupoEstudio') _tutoriasService.unirseAGrupo(docId, _user.uid); else _mostrarDialogoReserva(context, docId, data, esFijo); }
                    },
                    child: Text(estadoVisual==4 ? "BORRAR GRUPO" : (estadoVisual==2 ? "CANCELAR" : (estadoVisual==1 ? "HORARIO OCUPADO" : "RESERVAR AHORA")), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13))
                ))
              ]),
            ))
          ]),
        ),
      ),
    );
  }

// ... (resto del archivo igual, solo reemplaza _buildScheduleTab)

  Widget _buildScheduleTab() {
    const List<String> diasOrden = ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"];
    return StreamBuilder<QuerySnapshot>(
      stream: _tutoriasService.verHorarioEstudiante(_user.uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final clases = snapshot.data!.docs
            .map((d) => {...d.data() as Map<String, dynamic>, 'docId': d.id})
            .toList();

        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _mostrarDialogoAgregarClase,
              icon: const Icon(Icons.add_task),
              label: const Text("AGREGAR NUEVA CLASE", style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
          if (clases.isEmpty)
            Expanded(
              child: Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text("Aún no tienes clases", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey.shade400)),
                  const SizedBox(height: 8),
                  Text("Agrega tus materias para visualizar tu horario", style: TextStyle(fontSize: 13, color: Colors.grey.shade400), textAlign: TextAlign.center),
                ]),
              ),
            )
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: diasOrden.map((dia) {
                  final clasesDelDia = clases.where((c) => c['dia'] == dia).toList()
                    ..sort((a, b) => (a['horaInicio'] as int).compareTo(b['horaInicio'] as int));
                  if (clasesDelDia.isEmpty) return const SizedBox.shrink();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 10, left: 4),
                        child: Row(children: [
                          Container(width: 4, height: 18, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4))),
                          const SizedBox(width: 10),
                          Text(dia.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 1.2)),
                          const SizedBox(width: 10),
                          Text("${clasesDelDia.length} clase(s)", style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                      ...clasesDelDia.map((clase) {
                        final Color color = _getMateriaColor(clase['materia'] ?? '');
                        final String horaInicio = _formatoHora(clase['horaInicio'] as int);
                        final String horaFin = _formatoHora(clase['horaFin'] as int);
                        final double horas = ((clase['horaFin'] as int) - (clase['horaInicio'] as int)) / 100.0;
                        final String salon = (clase['salon'] ?? '').toString().trim();

                        return GestureDetector(
                          onTap: () => _confirmarBorrarClase(dia, (clase['horaInicio'] as int) ~/ 100, clase['materia'] as String),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: color.withOpacity(0.18), blurRadius: 12, offset: const Offset(0, 4))],
                            ),
                            child: IntrinsicHeight(
                              child: Row(children: [
                                Container(
                                  width: 5,
                                  decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16))),
                                ),
                                Container(
                                  width: 64,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(color: color.withOpacity(0.08)),
                                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                    Text(horaInicio, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color)),
                                    Container(margin: const EdgeInsets.symmetric(vertical: 4), width: 1, height: 12, color: color.withOpacity(0.3)),
                                    Text(horaFin, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color.withOpacity(0.7))),
                                  ]),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(clase['materia'] ?? 'Sin nombre', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 4),
                                      Row(children: [
                                        Icon(Icons.access_time_rounded, size: 12, color: AppColors.textSecondary),
                                        const SizedBox(width: 4),
                                        Text("${horas.toStringAsFixed(horas == horas.roundToDouble() ? 0 : 1)}h de clase", style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                                      ]),
                                      if (salon.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Row(children: [
                                          Icon(Icons.meeting_room_outlined, size: 12, color: color),
                                          const SizedBox(width: 4),
                                          Expanded(child: Text(salon, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
                                        ]),
                                      ],
                                    ]),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red.shade300),
                                ),
                              ]),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 4),
                    ],
                  );
                }).toList(),
              ),
            ),
        ]);
      },
    );
  }

  Widget _buildAITab() {
    return FutureBuilder<IAResult>(
      future: _aiService.analizarEstudiante(_user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Analizando tu perfil académico...", style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ]));
        }
        if (snapshot.hasError) return Center(child: Text("Error en IA: ${snapshot.error}"));
        final res = snapshot.data!;
        final Color colorRiesgo = res.nivelRiesgo == 'Alto' ? Colors.red : (res.nivelRiesgo == 'Medio' ? Colors.orange : Colors.green);
        final String emojiRiesgo = res.nivelRiesgo == 'Alto' ? '🔴' : res.nivelRiesgo == 'Medio' ? '🟡' : '🟢';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Análisis de IA", style: AppTextStyles.titleModern),
            const SizedBox(height: 4),
            Text("Actualizado ahora mismo · Score basado en tu horario real", style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontWeight: FontWeight.w500)),
            const SizedBox(height: 24),

            // --- SCORE PRINCIPAL ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [colorRiesgo.withOpacity(0.08), colorRiesgo.withOpacity(0.02)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colorRiesgo.withOpacity(0.2), width: 1.5),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("$emojiRiesgo Riesgo ${res.nivelRiesgo}", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: colorRiesgo)),
                  const SizedBox(height: 6),
                  RichText(text: TextSpan(children: [
                    TextSpan(text: "${res.score}", style: TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: colorRiesgo, letterSpacing: -2)),
                    TextSpan(text: "/100", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colorRiesgo.withOpacity(0.5))),
                  ])),
                  Text("SCORE ACADÉMICO", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: colorRiesgo.withOpacity(0.7), letterSpacing: 1)),
                ]),
                // Indicador circular visual
                SizedBox(width: 80, height: 80, child: Stack(alignment: Alignment.center, children: [
                  CircularProgressIndicator(value: res.score / 100, strokeWidth: 7, backgroundColor: colorRiesgo.withOpacity(0.1), valueColor: AlwaysStoppedAnimation<Color>(colorRiesgo)),
                  Text("${res.score}%", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: colorRiesgo)),
                ])),
              ]),
            ),
            const SizedBox(height: 16),

            // --- MÉTRICAS RÁPIDAS ---
            Row(children: [
              Expanded(child: _metricaCard("Materias", "${res.materias}", Icons.book_outlined, AppColors.primary)),
              const SizedBox(width: 10),
              Expanded(child: _metricaCard("Horas/sem", "${res.horasSemanales.toStringAsFixed(1)}h", Icons.schedule, Colors.teal)),
              const SizedBox(width: 10),
              Expanded(child: _metricaCard("Tutorías", "${res.tutorias}", Icons.school_outlined, Colors.purple)),
            ]),
            const SizedBox(height: 16),

            // --- CARGA POR DÍA ---
            if (res.cargaPorDia.isNotEmpty) ...[
              _aiCard("Carga por día de la semana", "", Icons.bar_chart_rounded, AppColors.primary, child: _buildBarrasCarga(res.cargaPorDia, res.diasSobrecargados)),
              const SizedBox(height: 16),
            ],

            // --- DESGLOSE DE SCORE ---
            _aiCard("¿Por qué este puntaje?", res.scoreDetalle, Icons.calculate_outlined, Colors.indigo, icono: true),
            const SizedBox(height: 16),

            // --- DIAGNÓSTICO ---
            _aiCard("Diagnóstico académico", res.justificacion, Icons.psychology_alt, colorRiesgo, icono: true),
            const SizedBox(height: 16),

            // --- RECOMENDACIÓN ---
            _aiCard("Recomendaciones personalizadas", res.recomendacion, Icons.lightbulb_circle, Colors.blue, icono: true),
            const SizedBox(height: 24),
          ]),
        );
      },
    );
  }

  Widget _metricaCard(String label, String valor, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(valor, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary), textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _buildBarrasCarga(Map<String, double> cargaPorDia, List<String> diasSobrecargados) {
    const List<String> diasOrden = ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"];
    final double maxHoras = cargaPorDia.values.isEmpty ? 1 : cargaPorDia.values.reduce((a, b) => a > b ? a : b);

    return Column(
      children: diasOrden.map((dia) {
        final double horas = cargaPorDia[dia] ?? 0;
        if (horas == 0) return const SizedBox.shrink();
        final bool sobrecargado = diasSobrecargados.any((d) => d.startsWith(dia));
        final Color barColor = sobrecargado ? Colors.orange : AppColors.primary;
        final double porcentaje = maxHoras > 0 ? horas / maxHoras : 0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            SizedBox(width: 36, child: Text(dia.substring(0, 3), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: sobrecargado ? Colors.orange : AppColors.textSecondary))),
            const SizedBox(width: 8),
            Expanded(
              child: Stack(children: [
                Container(height: 24, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8))),
                FractionallySizedBox(
                  widthFactor: porcentaje.clamp(0.05, 1.0),
                  child: Container(height: 24, decoration: BoxDecoration(color: barColor.withOpacity(0.85), borderRadius: BorderRadius.circular(8))),
                ),
              ]),
            ),
            const SizedBox(width: 8),
            SizedBox(width: 36, child: Text("${horas.toStringAsFixed(1)}h", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: barColor))),
            if (sobrecargado) const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange),
          ]),
        );
      }).toList(),
    );
  }

  Widget _aiCard(String title, String text, IconData icon, Color color, {Widget? child, bool icono = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.12), width: 1.5),
        boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 18)),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 15))),
        ]),
        if (text.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(text, style: const TextStyle(color: AppColors.textPrimary, height: 1.6, fontWeight: FontWeight.w500, fontSize: 13)),
        ],
        if (child != null) ...[
          const SizedBox(height: 14),
          child,
        ],
      ]),
    );
  }


  @override
  Widget build(BuildContext context) {
    return DefaultTabController(length: 5, child: Scaffold(
      appBar: AppBar(
        toolbarHeight: 100,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Hola,", style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          Text(_user.displayName ?? "Estudiante", style: AppTextStyles.titleModern),
        ]),
        actions: [
          Padding(padding: const EdgeInsets.only(right: 12), child: CircleAvatar(backgroundColor: Colors.blue.shade50, child: IconButton(icon: const Icon(Icons.person_search, color: AppColors.primary), onPressed: _editarPerfil))),
          Padding(padding: const EdgeInsets.only(right: 20), child: CircleAvatar(backgroundColor: Colors.red.shade50, child: IconButton(icon: const Icon(Icons.logout_rounded, color: Colors.red), onPressed: () => AuthService().logout()))),
        ],
        bottom: TabBar(controller: _tabController, isScrollable: true, labelColor: AppColors.primary, unselectedLabelColor: AppColors.textSecondary, indicator: UnderlineTabIndicator(borderSide: const BorderSide(width: 4, color: AppColors.primary), insets: const EdgeInsets.symmetric(horizontal: 16)), labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14), tabs: const [Tab(text: "Explorar"), Tab(text: "Grupos"), Tab(text: "Reservas"), Tab(text: "Horario"), Tab(text: "Análisis IA")]),
      ),
      body: TabBarView(controller: _tabController, children: [
        Column(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), child: TextField(onChanged: (v) => setState(() => _busqueda = v.toLowerCase()), decoration: InputDecoration(hintText: "Buscar por materia...", prefixIcon: const Icon(Icons.search_rounded), border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none), filled: true, fillColor: Colors.blue.shade50.withOpacity(0.5)))),
          Expanded(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('tutorias').where('status', whereIn: ['disponible', 'en_curso']).snapshots(), builder: (ctx, snapLibres) { return StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('horarios_profesores').snapshots(), builder: (ctx, snapFijos) { if (!snapLibres.hasData || !snapFijos.hasData) return const Center(child: CircularProgressIndicator());
          var listLibres = snapLibres.data!.docs.where((d)=>d.data() is Map && (d.data() as Map)['tipo']!='GrupoEstudio').map((d)=>({'data':d.data() as Map<String,dynamic>,'id':d.id,'f':false})).toList();
          var listFijos = snapFijos.data!.docs.map((d)=>({'data':d.data() as Map<String,dynamic>,'id':d.id,'f':true})).toList();
          var list = [...listLibres, ...listFijos].where((e) {
            final data = e['data'] as Map<String, dynamic>; // Cast explícito para evitar error
            return (data['materia'] ?? '').toString().toLowerCase().contains(_busqueda);
          }).toList();
          return ListView.builder(padding: const EdgeInsets.all(20), itemCount: list.length, itemBuilder: (c, i) => _buildUnifiedCard(list[i]['data'] as Map<String, dynamic>, list[i]['id'] as String, list[i]['f'] as bool)); }); }))
        ]),
        Scaffold(backgroundColor: Colors.transparent, body: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('tutorias').where('tipo', isEqualTo: 'GrupoEstudio').snapshots(), builder: (ctx, snap) { if(!snap.hasData) return const Center(child: CircularProgressIndicator()); var g = snap.data!.docs; return ListView.builder(padding: const EdgeInsets.all(20), itemCount: g.length, itemBuilder: (c, i) => _buildUnifiedCard(g[i].data() as Map<String, dynamic>, g[i].id, false)); }), floatingActionButton: FloatingActionButton.extended(backgroundColor: AppColors.primary, icon: const Icon(Icons.group_add), label: const Text("CREAR MI GRUPO"), onPressed: _crearGrupoDialog)),
        StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('tutorias').where('studentId', isEqualTo: _user.uid).snapshots(), builder: (ctx, snap) { if (!snap.hasData) return const Center(child: CircularProgressIndicator()); final docs = snap.data!.docs.where((d) => (d.data() as Map)['status'] != 'finalizada').toList(); return ListView.builder(padding: const EdgeInsets.all(20), itemCount: docs.length, itemBuilder: (c, i) => _buildUnifiedCard(docs[i].data() as Map<String, dynamic>, docs[i].id, false)); }),
        _buildScheduleTab(),
        _buildAITab(),
      ]),
    ));
  }

  void _mostrarDialogoReserva(BuildContext context, String docId, Map<String, dynamic> data, bool esFijo) { final notaCtrl = TextEditingController(); showDialog(context: context, builder: (ctx) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), title: const Text("Confirmar Reserva", style: TextStyle(fontWeight: FontWeight.w900)), content: Column(mainAxisSize: MainAxisSize.min, children: [const Text("¿Quieres dejarle un mensaje al tutor?"), const SizedBox(height: 16), TextField(controller: notaCtrl, decoration: AppTheme.inputDecoration("Nota (opcional)", Icons.chat_bubble_outline))]), actions: [ElevatedButton(onPressed: () async { if (!esFijo) await _tutoriasService.reservarTutoria(docId, _user.uid, _user.email!, notaCtrl.text); Navigator.pop(ctx); }, child: const Text("CONFIRMAR"))])); }
  void _cancelarReserva(BuildContext context, String docId) { showDialog(context: context, builder: (ctx) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), title: const Text("¿Cancelar reserva?"), actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("NO")), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: () async { await _tutoriasService.cancelarReserva(docId); Navigator.pop(ctx); }, child: const Text("SÍ, CANCELAR"))])); }
  void _crearGrupoDialog() {
    final mC = TextEditingController();
    final lC = TextEditingController();
    DateTime f = DateTime.now();
    TimeOfDay h = TimeOfDay.now();
    bool dentroU = true;

    // Lugares sugeridos dentro de la U
    const lugaresU = [
      'Biblioteca Central', 'Sala de Estudio B1', 'Sala de Estudio B2',
      'Cafetería Central', 'Auditorio Principal', 'Laboratorio de Cómputo',
      'Bloque A - Sala común', 'Bloque B - Sala común',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (c, setS) => SingleChildScrollView(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 28),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.group_add, color: AppColors.primary, size: 20)),
              const SizedBox(width: 12),
              const Text("Crear Grupo de Estudio", style: AppTextStyles.headline),
            ]),
            const SizedBox(height: 20),
            TextField(controller: mC, decoration: AppTheme.inputDecoration("Materia", Icons.book_outlined)),
            const SizedBox(height: 16),

            // ── SELECTOR DENTRO / FUERA ──
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => setS(() => dentroU = true),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: dentroU ? AppColors.primary : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: dentroU ? AppColors.primary : Colors.grey.shade200, width: 1.5),
                  ),
                  child: Column(children: [
                    Icon(Icons.school_outlined, color: dentroU ? Colors.white : Colors.grey, size: 22),
                    const SizedBox(height: 4),
                    Text("Dentro de la U", style: TextStyle(color: dentroU ? Colors.white : Colors.grey, fontWeight: FontWeight.w800, fontSize: 12), textAlign: TextAlign.center),
                  ]),
                ),
              )),
              const SizedBox(width: 12),
              Expanded(child: GestureDetector(
                onTap: () => setS(() => dentroU = false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: !dentroU ? Colors.orange : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: !dentroU ? Colors.orange : Colors.grey.shade200, width: 1.5),
                  ),
                  child: Column(children: [
                    Icon(Icons.location_off_outlined, color: !dentroU ? Colors.white : Colors.grey, size: 22),
                    const SizedBox(height: 4),
                    Text("Fuera de la U", style: TextStyle(color: !dentroU ? Colors.white : Colors.grey, fontWeight: FontWeight.w800, fontSize: 12), textAlign: TextAlign.center),
                  ]),
                ),
              )),
            ]),
            const SizedBox(height: 12),

            // ── ADVERTENCIA SI ES FUERA ──
            if (!dentroU)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text("Los demás estudiantes verán un aviso de que este encuentro es fuera del campus. Siempre se recomienda reunirse dentro de la universidad.", style: TextStyle(fontSize: 12, color: Colors.orange.shade800, height: 1.4))),
                ]),
              ),

            // ── CAMPO LUGAR ──
            dentroU
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    TextField(controller: lC, decoration: AppTheme.inputDecoration("Lugar específico", Icons.place_outlined)),
                    const SizedBox(height: 8),
                    const Text("Sugerencias dentro del campus:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6, runSpacing: 6,
                      children: lugaresU.map((lugar) => GestureDetector(
                        onTap: () { lC.text = lugar; setS(() {}); },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: lC.text == lugar ? AppColors.primary.withOpacity(0.1) : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: lC.text == lugar ? AppColors.primary : Colors.blue.shade100),
                          ),
                          child: Text(lugar, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: lC.text == lugar ? AppColors.primary : AppColors.textSecondary)),
                        ),
                      )).toList(),
                    ),
                  ])
                : TextField(controller: lC, decoration: AppTheme.inputDecoration("Dirección / Link de meet", Icons.link_outlined)),

            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: OutlinedButton(
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), side: BorderSide(color: Colors.blue.shade100)),
                onPressed: () async {
                  final d = await showDatePicker(context: ctx, initialDate: f, firstDate: DateTime.now(), lastDate: DateTime(2027));
                  if (d != null) setS(() => f = d);
                },
                child: Column(children: [
                  const Text("Fecha", style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  Text("${f.day}/${f.month}/${f.year}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary)),
                ]),
              )),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton(
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), side: BorderSide(color: Colors.blue.shade100)),
                onPressed: () async {
                  final t = await showTimePicker(context: ctx, initialTime: h);
                  if (t != null) setS(() => h = t);
                },
                child: Column(children: [
                  const Text("Hora", style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  Text(h.format(ctx), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary)),
                ]),
              )),
            ]),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: () async {
                if (mC.text.isNotEmpty) {
                  final lugarFinal = lC.text.isEmpty ? (dentroU ? 'Dentro del campus' : 'Fuera del campus') : lC.text;
                  await _tutoriasService.crearGrupoEstudio(
                    creatorId: _user.uid, creatorName: _user.displayName ?? 'Est',
                    materia: mC.text, tema: '',
                    lugar: dentroU ? lugarFinal : '⚠️ FUERA CAMPUS: $lugarFinal',
                    fecha: DateTime(f.year, f.month, f.day, h.hour, h.minute),
                  );
                  Navigator.pop(ctx);
                }
              },
              child: const Text("CREAR GRUPO", style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 32),
          ]),
        ),
      ),
    );
  }
  void _borrarGrupo(String docId) { showDialog(context: context, builder: (ctx)=>AlertDialog(title: const Text("Borrar Grupo"), actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("CANCELAR")), ElevatedButton(onPressed: (){FirebaseFirestore.instance.collection('tutorias').doc(docId).delete(); Navigator.pop(ctx);}, child: const Text("BORRAR"))])); }
  void _editarPerfil() { final nC=TextEditingController(text: _user.displayName); showDialog(context: context, builder: (ctx) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), title: const Text("Mi Perfil"), content: TextField(controller: nC, decoration: AppTheme.inputDecoration("Nombre Completo", Icons.person)), actions: [ElevatedButton(onPressed: () async { await AuthService().updateName(nC.text); Navigator.pop(ctx); }, child: const Text("GUARDAR"))])); }
  void _mostrarDialogoAgregarClase() {
    final dias = ["Lunes","Martes","Miércoles","Jueves","Viernes","Sábado"];
    String dS = "Lunes";
    TimeOfDay hI = const TimeOfDay(hour: 7, minute: 0);
    TimeOfDay hF = const TimeOfDay(hour: 9, minute: 0);
    final mC = TextEditingController();
    final sC = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (c, setS) => SingleChildScrollView(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.add_task, color: AppColors.primary, size: 20)),
              const SizedBox(width: 12),
              const Text("Agregar Clase", style: AppTextStyles.headline),
            ]),
            const SizedBox(height: 20),
            TextField(controller: mC, decoration: AppTheme.inputDecoration("Asignatura", Icons.school_outlined)),
            const SizedBox(height: 12),
            TextField(controller: sC, decoration: AppTheme.inputDecoration("Salón / Aula (opcional)", Icons.meeting_room_outlined)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: dS,
              decoration: AppTheme.inputDecoration("Día de la semana", Icons.calendar_today),
              items: dias.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
              onChanged: (v) => setS(() => dS = v!),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: OutlinedButton(
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), side: BorderSide(color: Colors.blue.shade100)),
                onPressed: () async { final t = await showTimePicker(context: ctx, initialTime: hI); if (t != null) setS(() => hI = t); },
                child: Column(children: [
                  const Text("Inicio", style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  Text(hI.format(ctx), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.primary)),
                ]),
              )),
              const SizedBox(width: 12),
              Expanded(child: OutlinedButton(
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), side: BorderSide(color: Colors.blue.shade100)),
                onPressed: () async { final t = await showTimePicker(context: ctx, initialTime: hF); if (t != null) setS(() => hF = t); },
                child: Column(children: [
                  const Text("Fin", style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  Text(hF.format(ctx), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.primary)),
                ]),
              )),
            ]),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: () async {
                if (mC.text.isNotEmpty) {
                  await _tutoriasService.agregarClaseEstudiante(
                    _user.uid, mC.text, dS,
                    hI.hour * 100 + hI.minute, hF.hour * 100 + hF.minute,
                    salon: sC.text.trim(),
                  );
                  Navigator.pop(ctx);
                }
              },
              child: const Text("GUARDAR EN HORARIO", style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 32),
          ]),
        ),
      ),
    );
  }
  void _confirmarBorrarClase(String d, int h, String m) async { final snap = await FirebaseFirestore.instance.collection('users').doc(_user.uid).collection('horario').where('dia', isEqualTo: d).where('materia', isEqualTo: m).get(); if(snap.docs.isNotEmpty && mounted) { showDialog(context: context, builder: (ctx) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), title: const Text("¿Eliminar clase?"), content: Text("Se quitará '$m' de tu horario."), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("NO")), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: () { _tutoriasService.borrarClaseEstudiante(_user.uid, snap.docs.first.id); Navigator.pop(ctx); }, child: const Text("ELIMINAR"))])); } }
}

// ------------------------------------------------------------------
// PROFESSOR DASHBOARD (VERSION PREMIUM)
// ------------------------------------------------------------------
class ProfessorDashboard extends StatefulWidget {
  final bool isHybrid;
  const ProfessorDashboard({super.key, this.isHybrid = false});
  @override
  State<ProfessorDashboard> createState() => _ProfessorDashboardState();
}

class _ProfessorDashboardState extends State<ProfessorDashboard> with SingleTickerProviderStateMixin {
  final TutoriasService _tutoriasService = TutoriasService();
  late TabController _tabController;
  final _user = AuthService().currentUser!;
  List<String> _misMateriasConfiguradas = [];
  List<String> _misTutoriasConfiguradas = [];
  Map<String, String> _perfilContacto = {'nombre': '', 'correo': '', 'telefono': ''};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarConfiguracionPerfil();
  }

  void _cargarConfiguracionPerfil() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(_user.uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      if (mounted) {
        setState(() {
          _misMateriasConfiguradas = List<String>.from(data['materias_dicta'] ?? []);
          _misTutoriasConfiguradas = List<String>.from(data['tutorias_dicta'] ?? []);
          _perfilContacto = {
            'nombre': data['nombre_publico'] ?? _user.displayName ?? '',
            'correo': data['correo_publico'] ?? '',
            'telefono': data['telefono'] ?? '',
          };
        });
      }
    }
  }

  Color _getMateriaColor(String materia) {
    final colors = [Colors.blue.shade400, Colors.green.shade400, Colors.orange.shade400, Colors.purple.shade400, Colors.teal.shade400, Colors.pink.shade400];
    return colors[materia.length % colors.length];
  }

  String _formatoHora(int militar) {
    int h = (militar / 100).floor(); int m = militar % 100;
    return "${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}";
  }

  // ── TAB 0: PERFIL ──────────────────────────────────────────────
  Widget _buildPerfilTab() {
    final nombre = _perfilContacto['nombre']!.isNotEmpty ? _perfilContacto['nombre']! : (_user.displayName ?? 'Docente');
    final correo = _perfilContacto['correo']!.isNotEmpty ? _perfilContacto['correo']! : null;
    final telefono = _perfilContacto['telefono']!.isNotEmpty ? _perfilContacto['telefono']! : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── TARJETA HERO PERFIL ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.primary, AppColors.accent], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 24, offset: const Offset(0, 10))],
          ),
          child: Column(children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.white.withOpacity(0.25),
              child: Text(nombre.isNotEmpty ? nombre[0].toUpperCase() : 'D', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white)),
            ),
            const SizedBox(height: 14),
            Text(nombre, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
              child: const Text("DOCENTE", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
            ),
            if (correo != null || telefono != null) ...[
              const SizedBox(height: 16),
              const Divider(color: Colors.white24),
              const SizedBox(height: 12),
              if (correo != null)
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.alternate_email, color: Colors.white70, size: 16),
                  const SizedBox(width: 8),
                  Text(correo, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                ]),
              if (correo != null && telefono != null) const SizedBox(height: 8),
              if (telefono != null)
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.phone_outlined, color: Colors.white70, size: 16),
                  const SizedBox(width: 8),
                  Text(telefono, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                ]),
            ],
          ]),
        ),
        const SizedBox(height: 24),

        // ── BOTÓN EDITAR PERFIL ──
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            side: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          onPressed: _editarPerfilContacto,
          icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
          label: const Text("Editar información de contacto", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 28),

        // ── MATERIAS QUE DICTA ──
        _buildSeccionPerfil(
          titulo: "Materias que dicto",
          icono: Icons.menu_book_rounded,
          color: AppColors.primary,
          items: _misMateriasConfiguradas,
          onAgregar: () => _agregarItemLista(
            titulo: "Agregar materia",
            hint: "Ej: Cálculo I",
            icono: Icons.book,
            lista: _misMateriasConfiguradas,
            onGuardar: () => _tutoriasService.actualizarMateriasProfesor(_user.uid, _misMateriasConfiguradas),
          ),
          onEliminar: (i) async {
            setState(() => _misMateriasConfiguradas.removeAt(i));
            await _tutoriasService.actualizarMateriasProfesor(_user.uid, _misMateriasConfiguradas);
          },
        ),
        const SizedBox(height: 20),

        // ── TUTORÍAS QUE OFRECE ──
        _buildSeccionPerfil(
          titulo: "Tutorías que ofrezco",
          icono: Icons.school_rounded,
          color: Colors.teal,
          items: _misTutoriasConfiguradas,
          onAgregar: () => _agregarItemLista(
            titulo: "Agregar tutoría",
            hint: "Ej: Álgebra Lineal",
            icono: Icons.school,
            lista: _misTutoriasConfiguradas,
            onGuardar: () => FirebaseFirestore.instance.collection('users').doc(_user.uid).update({'tutorias_dicta': _misTutoriasConfiguradas}),
          ),
          onEliminar: (i) async {
            setState(() => _misTutoriasConfiguradas.removeAt(i));
            await FirebaseFirestore.instance.collection('users').doc(_user.uid).update({'tutorias_dicta': _misTutoriasConfiguradas});
          },
        ),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _buildSeccionPerfil({
    required String titulo,
    required IconData icono,
    required Color color,
    required List<String> items,
    required VoidCallback onAgregar,
    required Function(int) onEliminar,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: color.withOpacity(0.07), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icono, color: color, size: 18)),
              const SizedBox(width: 12),
              Text(titulo, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: color)),
            ]),
            TextButton.icon(
              onPressed: onAgregar,
              icon: Icon(Icons.add_circle_outline, color: color, size: 18),
              label: Text("Agregar", style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: color.withOpacity(0.04), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Icon(Icons.info_outline, color: color.withOpacity(0.5), size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text("Sin elementos. Toca Agregar para añadir.", style: TextStyle(color: color.withOpacity(0.6), fontSize: 13))),
              ]),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items.asMap().entries.map((entry) {
                final c = _getMateriaColor(entry.value);
                return GestureDetector(
                  onLongPress: () => onEliminar(entry.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: c.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: c.withOpacity(0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(entry.value, style: TextStyle(color: c.withOpacity(0.9), fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(width: 6),
                      Icon(Icons.close, size: 14, color: c.withOpacity(0.5)),
                    ]),
                  ),
                );
              }).toList(),
            ),
          ),
      ]),
    );
  }

  // ── TAB 1: HORARIO ─────────────────────────────────────────────
  Widget _buildHorarioTab() {
    const List<String> diasOrden = ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"];
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('horarios_profesores').where('teacherId', isEqualTo: _user.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final clases = snapshot.data!.docs.map((d) => {...d.data() as Map<String, dynamic>, 'docId': d.id}).toList();

        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                shadowColor: AppColors.primary.withOpacity(0.3),
              ),
              onPressed: _crearBloqueFijo,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text("AGREGAR BLOQUE DE CLASES", style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
          if (clases.isEmpty)
            Expanded(
              child: Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.event_note_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text("Sin horario configurado", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey.shade400)),
                  const SizedBox(height: 8),
                  Text("Agrega tus bloques de clases\npara que los estudiantes te encuentren", style: TextStyle(fontSize: 13, color: Colors.grey.shade400), textAlign: TextAlign.center),
                ]),
              ),
            )
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: diasOrden.map((dia) {
                  final clasesDelDia = clases.where((c) => c['dia'] == dia).toList()
                    ..sort((a, b) => (a['horaInicio'] as int).compareTo(b['horaInicio'] as int));
                  if (clasesDelDia.isEmpty) return const SizedBox.shrink();

                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 10, left: 4),
                      child: Row(children: [
                        Container(width: 4, height: 18, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4))),
                        const SizedBox(width: 10),
                        Text(dia.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 1.2)),
                        const SizedBox(width: 10),
                        Text("${clasesDelDia.length} bloque(s)", style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                    ...clasesDelDia.map((clase) {
                      final Color color = _getMateriaColor(clase['materia'] ?? '');
                      final String horaInicio = _formatoHora(clase['horaInicio'] as int);
                      final String horaFin = _formatoHora(clase['horaFin'] as int);
                      final double horas = ((clase['horaFin'] as int) - (clase['horaInicio'] as int)) / 100.0;
                      final String salon = clase['salon'] ?? 'Por definir';

                      return Dismissible(
                        key: Key(clase['docId'] as String),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(16)),
                          child: Icon(Icons.delete_rounded, color: Colors.red.shade400),
                        ),
                        confirmDismiss: (_) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              title: const Text("¿Eliminar bloque?"),
                              content: Text("Se eliminará '${clase['materia']}' del horario."),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCELAR")),
                                ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: () => Navigator.pop(ctx, true), child: const Text("ELIMINAR")),
                              ],
                            ),
                          ) ?? false;
                        },
                        onDismissed: (_) => FirebaseFirestore.instance.collection('horarios_profesores').doc(clase['docId'] as String).delete(),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: color.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 4))],
                          ),
                          child: IntrinsicHeight(
                            child: Row(children: [
                              Container(
                                width: 5,
                                decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16))),
                              ),
                              Container(
                                width: 64,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(color: color.withOpacity(0.08)),
                                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Text(horaInicio, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color)),
                                  Container(margin: const EdgeInsets.symmetric(vertical: 4), width: 1, height: 12, color: color.withOpacity(0.3)),
                                  Text(horaFin, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color.withOpacity(0.7))),
                                ]),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(clase['materia'] ?? 'Sin nombre', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Row(children: [
                                      Icon(Icons.access_time_rounded, size: 12, color: AppColors.textSecondary),
                                      const SizedBox(width: 4),
                                      Text("${horas.toStringAsFixed(horas == horas.roundToDouble() ? 0 : 1)}h", style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                      const SizedBox(width: 12),
                                      Icon(Icons.place_outlined, size: 12, color: AppColors.textSecondary),
                                      const SizedBox(width: 4),
                                      Expanded(child: Text(salon, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis)),
                                    ]),
                                  ]),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Icon(Icons.swipe_left_rounded, size: 18, color: Colors.red.shade200),
                              ),
                            ]),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 4),
                  ]);
                }).toList(),
              ),
            ),
        ]);
      },
    );
  }

  // ── TAB 2: ESPACIOS DE TUTORÍA ─────────────────────────────────
  Widget _buildEspaciosTab() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('tutorias').where('teacherId', isEqualTo: _user.uid).where('tipo', isEqualTo: 'Libre').snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text("Sin espacios publicados", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey.shade400)),
                const SizedBox(height: 8),
                Text("Toca el botón + para publicar\nun espacio de tutoría extra", style: TextStyle(fontSize: 13, color: Colors.grey.shade400), textAlign: TextAlign.center),
              ]),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            itemBuilder: (c, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final fecha = (data['fecha'] as Timestamp).toDate();
              final materia = data['materia'] ?? '';
              final link = data['link'] ?? 'Por definir';
              final color = _getMateriaColor(materia);
              final status = data['status'] ?? 'disponible';
              final isReservada = status == 'reservada';
              final studentEmail = data['studentEmail'] ?? '';

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: IntrinsicHeight(
                    child: Row(children: [
                      Container(width: 6, color: isReservada ? Colors.green : color),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: (isReservada ? Colors.green : color).withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                                child: Text(isReservada ? "RESERVADA" : "DISPONIBLE", style: TextStyle(color: isReservada ? Colors.green : color, fontSize: 10, fontWeight: FontWeight.w800)),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade300, size: 20),
                                onPressed: () => _confirmarBorrarEspacio(docs[i].id, materia),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ),
                            ]),
                            const SizedBox(height: 10),
                            Text(materia, style: AppTextStyles.headline),
                            const SizedBox(height: 8),
                            Row(children: [
                              Icon(Icons.calendar_month_outlined, size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Text(DateFormat('EEE d MMM • HH:mm', 'es_ES').format(fecha), style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                            ]),
                            const SizedBox(height: 4),
                            Row(children: [
                              Icon(Icons.place_outlined, size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Expanded(child: Text(link, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                            ]),
                            if (isReservada && studentEmail.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Row(children: [
                                Icon(Icons.person_outline, size: 14, color: Colors.green.shade600),
                                const SizedBox(width: 6),
                                Expanded(child: Text(studentEmail, style: TextStyle(color: Colors.green.shade600, fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                              ]),
                            ],
                          ]),
                        ),
                      ),
                    ]),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text("PUBLICAR ESPACIO", style: TextStyle(fontWeight: FontWeight.w800)),
        onPressed: _crearEspacioLibreDialog,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 90,
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Bienvenido,", style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            Text(_user.displayName ?? "Docente", style: AppTextStyles.titleModern),
          ]),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: CircleAvatar(
                backgroundColor: Colors.red.shade50,
                child: IconButton(icon: const Icon(Icons.logout_rounded, color: Colors.red), onPressed: () => AuthService().logout()),
              ),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicator: UnderlineTabIndicator(borderSide: const BorderSide(width: 4, color: AppColors.primary), insets: const EdgeInsets.symmetric(horizontal: 24)),
            labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
            tabs: const [
              Tab(icon: Icon(Icons.person_outline, size: 18), text: "Perfil"),
              Tab(icon: Icon(Icons.calendar_month_outlined, size: 18), text: "Horario"),
              Tab(icon: Icon(Icons.school_outlined, size: 18), text: "Tutorías"),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildPerfilTab(),
            _buildHorarioTab(),
            _buildEspaciosTab(),
          ],
        ),
      ),
    );
  }

  // ── DIÁLOGOS / ACCIONES ─────────────────────────────────────────
  void _editarPerfilContacto() {
    final nC = TextEditingController(text: _perfilContacto['nombre']);
    final eC = TextEditingController(text: _perfilContacto['correo']);
    final tC = TextEditingController(text: _perfilContacto['telefono']);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.badge_outlined, color: AppColors.primary, size: 20)),
            const SizedBox(width: 12),
            const Text("Información de contacto", style: AppTextStyles.headline),
          ]),
          const SizedBox(height: 8),
          Text("Todo es opcional. Solo se mostrará lo que completes.", style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          const SizedBox(height: 20),
          TextField(controller: nC, decoration: AppTheme.inputDecoration("Nombre público (opcional)", Icons.person_outline)),
          const SizedBox(height: 12),
          TextField(controller: eC, keyboardType: TextInputType.emailAddress, decoration: AppTheme.inputDecoration("Correo público (opcional)", Icons.alternate_email)),
          const SizedBox(height: 12),
          TextField(controller: tC, keyboardType: TextInputType.phone, decoration: AppTheme.inputDecoration("Teléfono (opcional)", Icons.phone_outlined)),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('users').doc(_user.uid).set({
                'nombre_publico': nC.text.trim(),
                'correo_publico': eC.text.trim(),
                'telefono': tC.text.trim(),
              }, SetOptions(merge: true));
              if (mounted) {
                setState(() => _perfilContacto = {'nombre': nC.text.trim(), 'correo': eC.text.trim(), 'telefono': tC.text.trim()});
                Navigator.pop(ctx);
              }
            },
            child: const Text("GUARDAR CAMBIOS", style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  void _agregarItemLista({
    required String titulo,
    required String hint,
    required IconData icono,
    required List<String> lista,
    required Future<void> Function() onGuardar,
  }) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: TextField(controller: ctrl, autofocus: true, decoration: AppTheme.inputDecoration(hint, icono)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () async {
              if (ctrl.text.trim().isNotEmpty) {
                setState(() => lista.add(ctrl.text.trim()));
                await onGuardar();
                if (mounted) Navigator.pop(ctx);
              }
            },
            child: const Text("AGREGAR"),
          ),
        ],
      ),
    );
  }

  void _crearBloqueFijo() {
    final dias = ["Lunes","Martes","Miércoles","Jueves","Viernes","Sábado"];
    String dS = "Lunes";
    TimeOfDay hI = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay hF = const TimeOfDay(hour: 10, minute: 0);
    String? mS = _misMateriasConfiguradas.isNotEmpty ? _misMateriasConfiguradas.first : null;
    final sC = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (c, setS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.calendar_month, color: AppColors.primary, size: 20)),
              const SizedBox(width: 12),
              const Text("Nuevo Bloque de Clases", style: AppTextStyles.headline),
            ]),
            const SizedBox(height: 20),
            if (_misMateriasConfiguradas.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text("Sin materias configuradas", style: TextStyle(fontWeight: FontWeight.w700)),
                    TextButton(onPressed: () { Navigator.pop(ctx); _tabController.animateTo(0); }, child: const Text("Ir a Perfil → Agregar materias")),
                  ])),
                ]),
              )
            else ...[
              DropdownButtonFormField<String>(
                value: mS,
                decoration: AppTheme.inputDecoration("Materia", Icons.book),
                items: _misMateriasConfiguradas.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (v) => setS(() => mS = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: dS,
                decoration: AppTheme.inputDecoration("Día de la semana", Icons.calendar_today),
                items: dias.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                onChanged: (v) => setS(() => dS = v!),
              ),
              const SizedBox(height: 12),
              TextField(controller: sC, decoration: AppTheme.inputDecoration("Salón / Aula (opcional)", Icons.place_outlined)),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _horaSelector(ctx, "Inicio", hI, (t) => setS(() => hI = t))),
                const SizedBox(width: 12),
                Expanded(child: _horaSelector(ctx, "Fin", hF, (t) => setS(() => hF = t))),
              ]),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: () async {
                  if (mS != null) {
                    await FirebaseFirestore.instance.collection('horarios_profesores').add({
                      'teacherId': _user.uid,
                      'teacherName': _user.displayName ?? 'Docente',
                      'materia': mS,
                      'dia': dS,
                      'horaInicio': hI.hour * 100 + hI.minute,
                      'horaFin': hF.hour * 100 + hF.minute,
                      'salon': sC.text.isEmpty ? 'Por definir' : sC.text,
                      'tipo': 'Institucional',
                    });
                    Navigator.pop(ctx);
                  }
                },
                child: const Text("GUARDAR BLOQUE", style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
            const SizedBox(height: 32),
          ]),
        ),
      ),
    );
  }

  Widget _horaSelector(BuildContext ctx, String label, TimeOfDay hora, Function(TimeOfDay) onChange) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(color: Colors.blue.shade100),
      ),
      onPressed: () async {
        final t = await showTimePicker(context: ctx, initialTime: hora);
        if (t != null) onChange(t);
      },
      child: Column(children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(hora.format(ctx), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.primary)),
      ]),
    );
  }

  void _crearEspacioLibreDialog() {
    if (_misMateriasConfiguradas.isEmpty && _misTutoriasConfiguradas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Configura tus materias o tutorías en el perfil primero."), backgroundColor: Colors.orange));
      _tabController.animateTo(0);
      return;
    }
    final allMaterias = {..._misMateriasConfiguradas, ..._misTutoriasConfiguradas}.toList();
    final lC = TextEditingController();
    DateTime f = DateTime.now();
    TimeOfDay hI = TimeOfDay.now();
    String mS = allMaterias.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (c, setS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 28),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.school_outlined, color: Colors.green, size: 20)),
              const SizedBox(width: 12),
              const Text("Publicar Espacio Extra", style: AppTextStyles.headline),
            ]),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: mS,
              decoration: AppTheme.inputDecoration("Materia / Tutoría", Icons.book_outlined),
              items: allMaterias.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (v) => setS(() => mS = v!),
            ),
            const SizedBox(height: 12),
            TextField(controller: lC, decoration: AppTheme.inputDecoration("Lugar / Link de Meet", Icons.place_outlined)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: OutlinedButton(
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), side: BorderSide(color: Colors.blue.shade100)),
                onPressed: () async {
                  final d = await showDatePicker(context: ctx, initialDate: f, firstDate: DateTime.now(), lastDate: DateTime(2027));
                  if (d != null) setS(() => f = d);
                },
                child: Column(children: [
                  const Text("Fecha", style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  Text("${f.day}/${f.month}/${f.year}", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primary)),
                ]),
              )),
              const SizedBox(width: 12),
              Expanded(child: OutlinedButton(
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), side: BorderSide(color: Colors.blue.shade100)),
                onPressed: () async {
                  final t = await showTimePicker(context: ctx, initialTime: hI);
                  if (t != null) setS(() => hI = t);
                },
                child: Column(children: [
                  const Text("Hora", style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  Text(hI.format(ctx), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primary)),
                ]),
              )),
            ]),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: () async {
                await _tutoriasService.crearTutoria(
                  teacherId: _user.uid, teacherEmail: _user.email!,
                  teacherName: _user.displayName ?? 'Docente',
                  materia: mS, descripcion: 'Extra',
                  link: lC.text.isEmpty ? 'Por definir' : lC.text,
                  fecha: DateTime(f.year, f.month, f.day, hI.hour, hI.minute),
                  tipo: 'Libre',
                );
                Navigator.pop(ctx);
              },
              child: const Text("PUBLICAR AHORA", style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 32),
          ]),
        ),
      ),
    );
  }

  void _confirmarBorrarEspacio(String docId, String materia) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("¿Eliminar espacio?"),
        content: Text("Se eliminará la tutoría de '$materia'."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () { FirebaseFirestore.instance.collection('tutorias').doc(docId).delete(); Navigator.pop(ctx); },
            child: const Text("ELIMINAR"),
          ),
        ],
      ),
    );
  }

}