# STREAK — app móvil (Flutter)

Quinielas de fútbol entre amigos donde lo que cuenta no es acertar una vez, sino **no fallar nunca**.
Esta es la app del curso (Parte B del proyecto); el backend es Django REST (`streak_backend`).

- **Stack:** Flutter 3.41 / Dart 3.11 · Riverpod (estado) · go_router (navegación) · dio (red) ·
  flutter_secure_storage (tokens) · Hive (caché offline) · flutter_stripe (pagos) · share_plus · image_picker.
- **Idioma y zona horaria:** textos en español; el backend envía fechas en UTC y la app las muestra en hora local (RN-70).
- **Regla de oro:** nada de datos falsos en `lib/`. Si la API no da un dato, la pantalla lo deja vacío y queda
  anotado en [`docs/backend_pendientes.md`](docs/backend_pendientes.md).

## 1. Cómo correr la app

Requisitos: Flutter 3.41+, un emulador/teléfono Android y el backend levantado (ver §2).

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

### Variables de compilación (`--dart-define`)

| Variable | Para qué | Por defecto | Obligatoria en release |
| --- | --- | --- | --- |
| `API_BASE_URL` | URL del backend, **incluyendo `/api`** | Android: `http://10.0.2.2:8000/api` (el `localhost` de tu PC visto desde el emulador); web/escritorio: `http://localhost:8000/api` | Sí, y debe ser `https://` |
| `STRIPE_PUBLISHABLE_KEY` | Clave **publicable** de Stripe (`pk_test_…` en pruebas) para el PaymentSheet | vacía → el botón de pagar queda deshabilitado con un mensaje | No (sin ella no hay pagos) |
| `SUPPORT_EMAIL` | Correo de soporte que muestra "Eliminar mi cuenta" | `[CORREO_SOPORTE]` (marcador) | Sí |

Ejemplo completo (release):

```bash
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://mi-backend.example.com/api \
  --dart-define=STRIPE_PUBLISHABLE_KEY=pk_live_xxx \
  --dart-define=SUPPORT_EMAIL=soporte@mi-dominio.com
```

Un build de release **falla** si falta `SUPPORT_EMAIL` o `API_BASE_URL` https (lo valida `android/app/build.gradle.kts`
y, como segunda red, `main.dart` al arrancar). También falla sin `android/key.properties` (firma). Más en
[`docs/release_android.md`](docs/release_android.md).

## 2. Backend local para desarrollar

El backend vive en otro repo (`Delmar-Jimenez/streak_backend`). Para probar sin tocarlo, el proyecto trae un
script que levanta un clon con base SQLite desechable, datos de prueba y límites de peticiones altos:

```bash
git clone https://github.com/Delmar-Jimenez/streak_backend.git ../streak_backend_main
cd ../streak_backend_main && python -m venv venv && venv\Scripts\pip install -r requirements.txt   # una sola vez
cd ../streak_mobile && powershell -File test_e2e/backend/run_backend.ps1
```

Usuarios sembrados (`Clave1234x`): `ana` (normal), `beto` (PRO), `caro` (contraseña temporal: `Temporal123`).
Detalles en [`test_e2e/README.md`](test_e2e/README.md).

## 3. Pruebas

| Qué | Comando | Necesita backend |
| --- | --- | --- |
| Unitarias y de widget (115) | `flutter test` | No |
| Análisis estático | `flutter analyze` | No |
| Punta a punta (e2e) contra la API real (40) | `flutter test test_e2e --dart-define=API_BASE_URL=http://127.0.0.1:8000/api -j 1` | Sí |
| Capturas de pantallas (opcional) | `flutter test test_e2e -t capturas --dart-define=CAPTURAS=true --dart-define=API_BASE_URL=...` | Sí |

Para repetir las e2e hay que reiniciar el backend de pruebas (la usuaria `caro` solo sirve una vez por arranque).

Qué cubre cada archivo (para saber dónde mirar):

- `test/reglas_test.dart`, `pro_reglas_test.dart` — reglas puras: puesto con empates, etiquetas de puntos, cierre a 5 min,
  heurística de eliminatoria, reloj del servidor, backoff del pago, estadísticas.
- `test/paywall_test.dart`, `pago_pro_controller_test.dart` — paywall (RN-65) y flujo de pago con pasarela simulada.
- `test/tab_pendientes_test.dart`, `copia_offline_test.dart`, `deep_link_test.dart`, `accesibilidad_test.dart` — widgets,
  modo sin conexión, enlace de restablecer contraseña y contraste/semántica.
- `test_e2e/recorrido_e2e_test.dart` — **el recorrido completo** que se demuestra: registro → login → crear quiniela →
  código → segundo usuario se une → ambos pronostican → el admin finaliza los partidos → tabla con puntos y puesto →
  detalle de partido → estadísticas PRO bloqueadas. El paso de administrador usa `test_e2e/backend/admin.py`.

## 4. Estructura de carpetas

```
lib/
├─ main.dart                      Arranque: Hive, Stripe, validación de release, MaterialApp.router
├─ core/                          Lo compartido por todos los módulos
│  ├─ config/validacion_release.dart   Reglas de configuración publicable (SUPPORT_EMAIL, https)
│  ├─ constants/                  api_constants (rutas), app_constants (puntos, límites, precio PRO, correo)
│  ├─ errors/app_exception.dart   Errores RN-72 {"error":{codigo,mensaje,detalles}} → mensaje en español
│  ├─ network/                    dio_client, auth_interceptor (JWT + refresh), server_clock (hora del servidor)
│  ├─ router/                     app_router (rutas y redirects por sesión), deep_links (streak://reset-password)
│  ├─ storage/                    secure_storage_service (tokens), cache_store (Hive, copia offline)
│  ├─ theme/ utils/ widgets/      Paleta, tema, validación de contraseña, insignia PRO
└─ features/                      Un directorio por módulo, siempre con las mismas capas:
   ├─ auth/    (B1, B2)           domain/ (modelos) · data/ (repositorio HTTP) · application/ (Riverpod) · presentation/
   ├─ quinielas/ (B3, B4, B5)
   └─ pro/     (B6)
test/            pruebas sin red          test_e2e/   pruebas contra la API real (+ backend/ con seed.py y admin.py)
docs/            privacidad, ficha de Play, guía de release, pendientes del backend, capturas
tools/           generar_icono.py         android/    firma, deep link, MainActivity para Stripe
```

**Capas** (se repite en cada módulo): `domain` = modelos y reglas puras (sin Flutter ni red, fáciles de probar) →
`data` = repositorio que habla con la API y traduce errores → `application` = providers/controladores de Riverpod →
`presentation` = pantallas y widgets. Las pantallas nunca llaman a dio directamente.

## 5. Mapa del enunciado: módulos → pantallas

| Módulo | Pantallas (ruta) | Endpoints | Dónde está el código |
| --- | --- | --- | --- |
| **B1 Autenticación** | Splash (`/`), Login (`/login`), Registro (`/register`), Recuperar (`/recuperar`), Restablecer (`/restablecer/:uid/:token`), Enlace inválido, Cambio forzado de contraseña | `auth/login/`, `auth/register/`, `auth/login/refresh/`, `auth/recuperar/`, `auth/restablecer/`, `auth/cambiar-password/` | `features/auth/`, `core/network/auth_interceptor.dart`, `core/router/` |
| **B2 Perfil** | Mi perfil (`/perfil`): editar nombre, apellidos, teléfono y foto; "Eliminar mi cuenta" | `usuarios/me/` (GET, PATCH multipart) | `features/auth/presentation/screens/perfil_screen.dart` |
| **B3 Crear y unirse** | Crear quiniela (`/quinielas/crear`), Código y compartir (`/quinielas/:id/codigo`), Unirse (`/quinielas/unirse`) | `torneos/`, `quinielas/`, `quinielas/unirse/` | `features/quinielas/presentation/screens/` |
| **B4 Pantalla principal** | Home con "Mis quinielas" e Historial (`/home`), drawer con datos reales | `quinielas/mias/`, `quinielas/historial/`, `usuarios/me/` | `home_screen.dart` |
| **B5 Quiniela activa** | Quiniela (`/quinielas/:id`) con Pendientes · Finalizados · Tabla; Detalle de partido (`…/partido/:pid`); Detalle de participante (`…/participante/:uid`) | `quinielas/{id}/`, `…/partidos/`, `…/tabla/`, `…/pronosticos/`, `…/partidos/{pid}/detalle/`, `…/participantes/{uid}/detalle/`, `torneos/{id}/equipos|fases/` | `quiniela_activa_screen.dart`, `widgets/tab_*.dart`, `domain/reglas.dart` |
| **B6 Plan PRO** | Hazte PRO / Tu plan PRO (`/pro`), Mis estadísticas (`/quinielas/:id/estadisticas`) | `pro/estado/`, `pro/suscribir/`, `pro/pagos/` | `features/pro/` |
| **B7 Release Android** | — (no es pantalla) | — | `android/app/build.gradle.kts`, `docs/release_android.md`, `play_store.md`, `privacidad.md` |

## 6. Reglas de negocio y dónde se cumplen (para explicarlas)

| Regla | Qué hace la app | Archivo |
| --- | --- | --- |
| RN-03 contraseña (8+, letra y número) | Validación local | `core/utils/password_rules.dart` |
| RN-04 tokens seguros | Access/refresh en Keychain / EncryptedSharedPreferences | `core/storage/secure_storage_service.dart` |
| RN-07 contraseña temporal | El 403 fuerza la pantalla de cambio; tras cambiarla se hace **re-login** (el backend invalida los tokens) | `auth_interceptor.dart`, `auth_controller.dart` |
| RN-26 topes de participantes | Deslizador 2–50 (2–100 si PRO) | `crear_quiniela_screen.dart` |
| RN-27 código de quiniela | Campo en mayúsculas, sin `0 O I L` | `unirse_quiniela_screen.dart` |
| RN-31 ingreso tardío | Aviso antes de confirmar | `unirse_quiniela_screen.dart` |
| RN-33 solo lectura al finalizar | Banner y sin edición | `quiniela_activa_screen.dart`, `reglas.dart` |
| RN-35 marcador 0–20 | Steppers | `partido_pendiente_card.dart` |
| RN-37 cierre | La edición se cierra **5 min antes**, con la **hora del servidor** (header `Date`), no la del teléfono | `reglas.dart`, `core/network/server_clock.dart` |
| RN-39 pronósticos ocultos | "Oculto hasta el inicio del partido" | `partido_detalle_screen.dart` |
| RN-23 eliminatoria | Aviso de los 90' reglamentarios | `reglas.dart`, `partido_pendiente_card.dart` |
| RN-45 a 48 puntaje 5 / 4 / 3 / 0 | Etiquetas de puntos (el cálculo lo hace el backend) | `reglas.dart` |
| RN-53 puesto | "3.º de 12" desde `/tabla/`, empates compartidos | `reglas.dart`, `quiniela_activa_screen.dart` |
| RN-61 a 65 plan PRO | Solo comodidad y estadística; paywall con precio, periodo y cómo cancelar **antes** del pago | `features/pro/` |
| RN-72 errores | Un único formato; se muestra `mensaje` y el primer campo en `detalles` | `core/errors/app_exception.dart` |
| RN-74 sin conexión | Copia local por usuario de quiniela activa, mis quinielas, historial y perfil; banner "Sin conexión · datos de HH:mm"; se borra al cerrar sesión | `core/storage/cache_store.dart`, repositorios |

## 7. Flujos que conviene saber explicar

1. **Sesión y refresh.** El login guarda `access` (15 min) y `refresh` (7 días). `AuthInterceptor` agrega el token a cada
   petición; ante un 401 pide un nuevo access con el refresh y **reintenta** la petición; si el refresh también falla, cierra la sesión.
2. **Pago PRO** (`features/pro/application/pago_pro_controller.dart`). Genera una *Idempotency-Key* y la **guarda** (el backend solo
   deja reintentar una orden pendiente con la misma clave) → `POST pro/suscribir/` devuelve un `client_secret` → el PaymentSheet de
   Stripe cobra (la tarjeta nunca pasa por nuestro código) → la app consulta `pro/estado/` con backoff ~30 s, porque PRO lo activa el
   **webhook** de Stripe, no la app.
3. **Cierre de pronósticos.** `ServerClock` calcula el desfase con el header `Date`; `puedeEditarPronostico` (función pura)
   decide si se puede editar. El backend sigue siendo la autoridad: si responde `PRONOSTICOS_CERRADOS`, la app muestra el mensaje y refresca.
4. **Modo sin conexión.** Cada repositorio guarda la última respuesta en Hive; si falla la red devuelve esa copia con su hora y
   la pantalla muestra el banner y deshabilita guardar. Errores del servidor (500, 400…) **no** se disfrazan con la copia.

## 8. Documentación

- [`docs/backend_pendientes.md`](docs/backend_pendientes.md) — desviaciones del backend (con archivo:línea, RN afectada y propuesta).
- [`docs/release_android.md`](docs/release_android.md) — firma, JDK requerido, compilación e ícono.
- [`docs/play_store.md`](docs/play_store.md) y [`docs/privacidad.md`](docs/privacidad.md) — ficha y política (borradores con marcadores `[ENTRE CORCHETES]`).
- [`docs/capturas_telefono_pruebas/`](docs/capturas_telefono_pruebas/LEEME.md) — capturas reales del teléfono como evidencia (no son para Play); las de la ficha se hacen con `tools/capturas_play.ps1`.
- [`test_e2e/README.md`](test_e2e/README.md) — pruebas contra la API real y prueba manual del pago con tarjeta de prueba.

## 9. Limitaciones conocidas

- El release Android **aún no se ha compilado** en esta máquina (falta un JDK 17–24); ver `docs/release_android.md`.
- No hay eliminación de cuenta en la API: la app solo explica cómo pedirla por correo (bloqueante para Google Play).
- El pago con tarjeta solo se probó con pasarela simulada; falta la prueba manual con claves de prueba de Stripe.
- Las capturas de `docs/capturas/` son renders de widgets con datos reales, no de un dispositivo.
