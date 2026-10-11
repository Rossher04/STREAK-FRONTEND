"""Ajustes locales SOLO para las pruebas e2e: copia los del backend y sube los límites
de peticiones (10/min por IP se agotaría con decenas de logins de prueba).
No modifica el repo del backend: se usa con PYTHONPATH."""
from core.settings import *  # noqa: F401,F403

REST_FRAMEWORK = {**REST_FRAMEWORK, 'DEFAULT_THROTTLE_RATES': {  # noqa: F405
    'auth': '100000/min', 'password_reset': '100000/hour',
}}
