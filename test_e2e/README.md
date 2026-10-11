# Pruebas e2e contra el backend real

No corren con `flutter test` normal (necesitan servidor). Pasos:

1. Clonar el backend en `..\streak_backend_main` con su propio venv e instalar `requirements.txt`.
2. Levantarlo (BD SQLite desechable, migraciones, datos de prueba, límites de peticiones altos;
   no modifica el repo del backend):

   ```
   powershell -File test_e2e/backend/run_backend.ps1
   ```

3. En otra terminal:

   ```
   flutter test test_e2e --dart-define=API_BASE_URL=http://127.0.0.1:8000/api -j 1
   ```

El backend se vuelve a sembrar cada vez que se arranca; `caro` (contraseña temporal) solo sirve
una vez por arranque, así que hay que reiniciar el backend antes de repetir la corrida.

## Capturas de pantalla (opcional)

`test_e2e/capturas_test.dart` regenera `docs/capturas/*.png` y ensucia el árbol de git, así que **no corre
por defecto** (queda omitido). Para generarlas, con el backend levantado:

```
flutter test test_e2e -t capturas --dart-define=CAPTURAS=true --dart-define=API_BASE_URL=http://127.0.0.1:8000/api -j 1
```

(Hacen falta las dos cosas: el tag `capturas` selecciona el archivo y `CAPTURAS=true` activa los tests.
`package:test` no permite un `exclude_tags` por defecto que `-t` pueda anular, por eso el doble requisito.)

## Prueba manual del pago PRO (requiere claves de prueba de Stripe)

Los e2e solo cubren lo que no necesita Stripe (503 sin configurar, historial de pagos vacío, estado).
El pago completo se prueba a mano en un teléfono/emulador Android:

1. Backend con claves de **prueba**: `STRIPE_SECRET_KEY=sk_test_...`, `STRIPE_WEBHOOK_SECRET=whsec_...`
   (por ejemplo con `stripe listen --forward-to http://127.0.0.1:8000/api/pro/webhook/`), `STRIPE_LIVE_MODE=False`.
2. App con la clave publicable de prueba (emulador Android accede al PC por 10.0.2.2):
   `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_...`
3. Entra con un usuario NO Pro (ana), abre **HAZTE PRO** y comprueba que el precio, "Pago único · sin
   renovación automática" y "Cómo cancelar" se ven antes del botón.
4. Pagar → tarjeta `4242 4242 4242 4242`, cualquier fecha futura y CVC → debe pasar a "ACTIVANDO PRO…" y,
   cuando llegue el webhook (unos segundos), a "Tu plan PRO" con el pago COMPLETADO en el historial.
5. Casos: tarjeta rechazada `4000 0000 0000 0002` (mensaje de error, se puede reintentar), cerrar el
   PaymentSheet (mensaje "Pago cancelado" y la **misma** Idempotency-Key en el reintento), apagar el webhook
   (tras ~30 s: "Pago recibido, activando PRO…" y botón "COMPROBAR DE NUEVO").
6. Un pago de prueba deja al usuario como PRO de verdad en esa base de datos: usa usuarios de prueba.
