"""Acciones de administrador para las e2e, sin tocar el repo del backend (se ejecuta con su venv).

    python admin.py preparar-recorrido
    python admin.py finalizar "<torneo>" "<equipo local>" "<equipo visita>" <goles local> <goles visita>

`finalizar` hace lo mismo que el admin de Django: pone el partido en FINALIZADO con su marcador y lo guarda;
las señales del backend recalculan los puntos de todos los pronósticos.
"""
import os
import sys
from datetime import timedelta

sys.path.insert(0, os.getcwd())
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'e2e_settings')
import django  # noqa: E402

django.setup()
from django.utils import timezone  # noqa: E402
from quinielas.models import Partido, Quiniela, Torneo  # noqa: E402


def partido(torneo, local, visita):
    return Partido.objects.get(torneo__nombre=torneo, equipo_local__nombre=local, equipo_visita__nombre=visita)


def main(argv):
    comando = argv[0]
    if comando == 'preparar-recorrido':
        # Deja el torneo como recién sembrado para poder repetir el recorrido sin reiniciar el backend.
        torneo = Torneo.objects.get(nombre='Torneo Recorrido E2E')
        Quiniela.objects.filter(torneo=torneo).delete()
        for dias, p in enumerate(torneo.partidos.order_by('id'), start=2):
            p.estado, p.goles_local, p.goles_visita = 'PROGRAMADO', None, None
            p.fecha_hora = timezone.now() + timedelta(days=dias)
            p.save()
    elif comando == 'finalizar':
        torneo, local, visita, gl, gv = argv[1:6]
        p = partido(torneo, local, visita)
        p.estado, p.goles_local, p.goles_visita = 'FINALIZADO', int(gl), int(gv)
        # Un partido que se finaliza ya empezó: así los pronósticos ajenos dejan de estar ocultos (RN-39).
        p.fecha_hora = timezone.now() - timedelta(hours=3)
        p.save()
    else:
        raise SystemExit(f'comando desconocido: {comando}')
    print('ok')


main(sys.argv[1:])
