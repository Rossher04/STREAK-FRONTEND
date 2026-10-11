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
from quinielas.models import Equipo, Fase, Partido, Participante, Pronostico, Quiniela, Torneo, Usuario  # noqa: E402

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
clausura = torneo('Clausura E2E', 'FINALIZADO', jugados=True)

# ana participa en una quiniela de un torneo ya finalizado (para probar /quinielas/historial/).
ana = Usuario.objects.get(username='ana')
q = Quiniela.objects.create(nombre='Quiniela Clausura', torneo=clausura, creador=ana,
                            codigo_unico='CLAU25', max_participantes=10)
Participante.objects.create(quiniela=q, usuario=ana)

# ---- B5: torneo con fechas relativas a now() para probar cierre, puntos, tabla y ocultos ----
usuario('dani')
beto = Usuario.objects.get(username='beto')
dani = Usuario.objects.get(username='dani')
ahora = timezone.now()
t5 = Torneo.objects.create(nombre='Torneo B5 E2E', formato='GRUPOS_ELIMINATORIA', temporada='2026', estado='ACTIVO')
grupos = Fase.objects.create(torneo=t5, nombre='Fase de grupos', orden=1, tipo='GRUPOS')
semis = Fase.objects.create(torneo=t5, nombre='Semifinales', orden=2, tipo='ELIMINATORIA')
leones, tigres, aguilas, lobos = [Equipo.objects.create(torneo=t5, nombre=n) for n in ('Leones', 'Tigres', 'Aguilas', 'Lobos')]


def partido(fase, local, visita, delta, estado='PROGRAMADO', goles=None):
    return Partido.objects.create(
        torneo=t5, fase=fase, equipo_local=local, equipo_visita=visita, fecha_hora=ahora + delta,
        estado=estado, goles_local=goles[0] if goles else None, goles_visita=goles[1] if goles else None)


cierre = partido(grupos, leones, tigres, timedelta(minutes=4))          # dentro de la ventana de 5 min
futuro = partido(grupos, aguilas, lobos, timedelta(days=2))
semi = partido(semis, leones, aguilas, timedelta(days=3))
vencido = partido(grupos, lobos, aguilas, timedelta(hours=-1))           # PROGRAMADO ya iniciado (el backend lo cierra)
en_juego = partido(grupos, lobos, tigres, timedelta(minutes=-10), 'EN_JUEGO')
fin_exacto = partido(grupos, tigres, lobos, timedelta(days=-3), 'FINALIZADO', (2, 1))
fin_dif = partido(grupos, lobos, leones, timedelta(days=-2), 'FINALIZADO', (1, 1))
fin_fallo = partido(grupos, tigres, aguilas, timedelta(days=-2), 'FINALIZADO', (3, 0))
fin_res = partido(grupos, leones, lobos, timedelta(days=-1), 'FINALIZADO', (2, 0))
susp = partido(grupos, aguilas, tigres, timedelta(days=-1), 'SUSPENDIDO')

qb5 = Quiniela.objects.create(nombre='Quiniela B5', torneo=t5, creador=ana, codigo_unico='B5TEST', max_participantes=10)
pa, pb, pd = [Participante.objects.create(quiniela=qb5, usuario=u) for u in (ana, beto, dani)]
for part, partido_, gl, gv in [
    (pa, fin_exacto, 2, 1), (pa, fin_dif, 0, 0), (pa, fin_res, 1, 0), (pa, fin_fallo, 0, 1), (pa, susp, 1, 1),
    (pb, fin_exacto, 3, 0), (pb, fin_fallo, 3, 0), (pb, futuro, 2, 2),
    (pd, fin_exacto, 2, 1), (pd, fin_res, 1, 0),
]:
    Pronostico.objects.create(participante=part, partido=partido_, goles_local_pred=gl, goles_visita_pred=gv)
# Puntos esperados: ana 5+4+3+0 = 12; beto 3+5 = 8; dani 5+3 = 8 (empate en el 2.º puesto).
print('seed ok')
