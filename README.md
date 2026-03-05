# Tutorías UCatólica

Aplicación móvil desarrollada en Flutter para la gestión de tutorías académicas en la Universidad Católica de Colombia. Este proyecto fue desarrollado como trabajo de grado (tesis) con el objetivo de centralizar y optimizar el proceso de oferta, búsqueda y reserva de espacios de tutoría entre estudiantes y docentes.

---

## ¿Qué hace esta aplicación?

La app conecta a **estudiantes** y **profesores** dentro de la comunidad universitaria (@ucatolica.edu.co), facilitando:

- La publicación y búsqueda de espacios de tutoría disponibles.
- La gestión del horario académico personal de cada usuario.
- La creación y participación en grupos de estudio entre pares.
- Un análisis automático de carga académica con inteligencia artificial (IA local).

---

## Roles de usuario

### 👨‍🎓 Estudiante
El panel del estudiante cuenta con **5 pestañas**:

| Pestaña | Descripción |
|---|---|
| **Explorar** | Lista de tutorías disponibles (sesiones libres publicadas por docentes y horarios institucionales). Permite buscar por materia y detecta automáticamente cruces con el horario personal. |
| **Grupos** | Grupos de estudio creados por otros estudiantes. Muestra advertencia si el encuentro es fuera del campus. Permite unirse, salir o crear nuevos grupos. |
| **Reservas** | Tutorías individuales reservadas por el estudiante. Permite cancelar la reserva. |
| **Horario** | Gestión del horario personal de clases (materia, día, hora inicio/fin y salón). Sirve como base para la detección de conflictos y el análisis de IA. |
| **Análisis IA** | Diagnóstico académico automatizado que calcula un score de 0 a 100 basado en carga horaria, número de materias, días sobrecargados y uso de tutorías. Incluye desglose detallado, recomendaciones y sugerencias de tutorías disponibles. |

### 👨‍🏫 Profesor
El panel del profesor cuenta con **3 pestañas**:

| Pestaña | Descripción |
|---|---|
| **Perfil** | Información de contacto pública (nombre, correo, teléfono), lista de materias que dicta y tutorías que ofrece. |
| **Horario** | Bloques de clases institucionales configurados por el docente (materia, día, hora, salón). Son visibles para los estudiantes en la pestaña "Explorar". |
| **Tutorías** | Espacios de tutoría extra publicados por el docente con fecha, hora y lugar específico. Muestra si están disponibles o ya reservados, e indica el correo del estudiante que reservó. |

---

## Motor de Inteligencia Artificial (IA Local)

La IA integrada en la aplicación (`AIService`) analiza el perfil académico del estudiante **sin conexión a servicios externos**. Calcula un **score académico** compuesto por cuatro componentes:

| Componente | Peso | Criterio |
|---|---|---|
| Cobertura de materias | 35 pts | Ideal: 5 materias. Penaliza exceso (>7) o escasez (<3). |
| Carga horaria semanal | 30 pts | Zona ideal: 15–22 horas. Penaliza sobrecarga o poca dedicación. |
| Balance entre días | 20 pts | Penaliza días con más de 5 horas acumuladas. |
| Uso de tutorías | 15 pts | Ideal: 1–3 tutorías activas. |

**Niveles de riesgo académico:**
- 🔴 **Alto** (score < 40): requiere acción inmediata.
- 🟡 **Medio** (score 40–69): situación aceptable con margen de mejora.
- 🟢 **Bajo** (score ≥ 70): carga equilibrada y buen uso de recursos.

El análisis incluye:
- Desglose numérico de cada componente del score.
- Diagnóstico textual personalizado según el nivel de riesgo.
- Recomendaciones accionables (redistribuir días, agregar tutorías, etc.).
- Sugerencias de tutorías disponibles para las materias del estudiante.
- Gráfico de barras con la carga de horas por día de la semana.

---

## Funcionalidades transversales

- **Autenticación segura**: registro e inicio de sesión con correo institucional `@ucatolica.edu.co`. Verificación de correo electrónico obligatoria antes del primer acceso.
- **Recuperación de contraseña**: envío de enlace de restablecimiento al correo institucional.
- **Detección de conflictos de horario**: al explorar tutorías, se indica automáticamente si el horario de la sesión choca con las clases del estudiante.
- **Grupos de estudio con aviso de seguridad**: si el lugar del grupo está fuera del campus, se muestra una advertencia visible para todos los participantes.
- **Actualización en tiempo real**: todos los datos se sincronizan mediante Firestore listeners (`StreamBuilder`), sin necesidad de recargar manualmente.

---

## Tecnologías utilizadas

| Tecnología | Uso |
|---|---|
| [Flutter](https://flutter.dev) | Framework de UI multiplataforma (Android, iOS, Web, Desktop) |
| [Firebase Authentication](https://firebase.google.com/docs/auth) | Registro, login y verificación de correo |
| [Cloud Firestore](https://firebase.google.com/docs/firestore) | Base de datos en tiempo real (NoSQL) |
| [intl](https://pub.dev/packages/intl) | Formateo de fechas en español |

---

## Estructura del proyecto

```
lib/
├── main.dart                  # Punto de entrada, toda la UI (Login, Student/Professor Dashboard)
└── services/
    ├── auth_service.dart      # Autenticación con Firebase Auth
    ├── tutorias_service.dart  # CRUD de tutorías, grupos y horario de estudiante
    └── ai_service.dart        # Motor de análisis académico con IA local
```

---

## Modelo de datos en Firestore

| Colección | Descripción |
|---|---|
| `users/{uid}` | Perfil del usuario (rol, nombre, materias, isStudentTutor, contacto) |
| `users/{uid}/horario` | Clases del estudiante (materia, día, horaInicio, horaFin, salón) |
| `tutorias` | Sesiones de tutoría y grupos de estudio (libre, reservada, GrupoEstudio) |
| `horarios_profesores` | Bloques de clases institucionales publicados por docentes |

---

## Cómo ejecutar el proyecto

### Prerrequisitos
- [Flutter SDK](https://flutter.dev/docs/get-started/install) ≥ 3.10.3
- Proyecto de Firebase configurado con Authentication y Firestore habilitados
- Archivo `google-services.json` (Android) o `GoogleService-Info.plist` (iOS) en su carpeta correspondiente

### Pasos

```bash
# 1. Instalar dependencias
flutter pub get

# 2. Ejecutar en modo debug
flutter run
```

---

## Autores

Proyecto de grado — Ingeniería de Sistemas  
Universidad Católica de Colombia
