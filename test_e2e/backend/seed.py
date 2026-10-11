"""Datos de prueba para las e2e. Uso (desde la carpeta del backend, con su venv):
    python <ruta>/seed.py
Crea usuarios y torneos de prueba desde cero (idempotente: borra lo previo)."""
import os
import sys
from datetime import timedelta

sys.path.insert(0, os.getcwd())
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'e2e_settings')
import django  # noqa: E402

django.setup()
from django.utils import timezone  # noqa: E402
from quinielas.models import Equipo, Fase, Partido, Participante, Quiniela, Torneo, Usuario  # noqa: E402

Quiniela.objects.all().delete()
Usuario.objects.exclude(is_superuser=True).delete()
Torneo.objects.all().delete()

CLAVE = 'Clave1234x'


def usuario(username, **extra):
    u = Usuario.objects.create_user(username=username, email=f'{username}@e2e.test', password=CLAVE, **extra)
    return u


usuario('ana', first_name='Ana', last_name='Prueba')
usuario('beto', es_pro=True)
caro = usuario('caro', pass_temporal_flag=True)
caro.set_password('Temporal123')
caro.save()


def torneo(nombre, estado, jugados):
    t = Torneo.objects.create(nombre=nombre, formato='LIGA', temporada='2026', estado=estado)
    fase = Fase.objects.create(torneo=t, nombre='Jornada 1', orden=1, tipo='LIGA')
    a = Equipo.objects.create(torneo=t, nombre=f'{nombre} A')
    b = Equipo.objects.create(torneo=t, nombre=f'{nombre} B')
    ahora = timezone.now()
    if jugados:
        Partido.objects.create(torneo=t, fase=fase, equipo_local=a, equipo_visita=b,
                               fecha_hora=ahora - timedelta(days=2), goles_local=1, goles_visita=0,
                               estado='FINALIZADO')
    Partido.objects.create(torneo=t, fase=fase, equipo_local=b, equipo_visita=a,
                           fecha_hora=ahora + timedelta(days=3))
    return t


torneo('Liga E2E En Curso', 'ACTIVO', jugados=True)
torneo('Copa E2E Nueva', 'ACTIVO', jugados=False)
torneo('Borrador E2E', 'BORRADOR', jugados=False)
torneo('Clausura E2E', 'FINALIZADO', jugados=True)
print('seed ok')
