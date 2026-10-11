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
