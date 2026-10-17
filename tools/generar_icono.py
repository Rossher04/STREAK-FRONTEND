"""Genera el logo y los íconos de STREAK a partir del logo fuente (design/logo_fuente.jpg).

Separa el balón y las estelas del fondo azul del logo fuente y los vuelve a montar sobre el
azul de marca (#124E73) en cada tamaño, para que los bordes queden limpios.

Uso (desde la raíz del repo, con Pillow instalado):
    python tools/generar_icono.py [carpeta_salida_tienda]

Escribe:
    assets/logo/streak_logo.png          logo de la app (cuadro redondeado, fondo transparente)
    assets/icons/icon.png                ícono base del launcher (Android antiguo e iOS)
    assets/icons/icon_foreground.png     primer plano del ícono adaptativo de Android
    <carpeta_salida_tienda>/play_icono_512.png        ícono de Google Play (512x512)
    <carpeta_salida_tienda>/play_grafico_1024x500.png gráfico destacado de Google Play
Después: dart run flutter_launcher_icons
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

RAIZ = Path(__file__).resolve().parent.parent
FUENTE = RAIZ / 'design' / 'logo_fuente.jpg'
AZUL = (18, 78, 115)        # brand  #124E73
FONDO_APP = (9, 26, 37)     # bg     #091A25
CREMA = (242, 240, 206)     # cream  #F2F0CE
AMARILLO = (242, 184, 7)    # accent #F2B807
GRIS = (159, 180, 196)      # muted  #9FB4C4


def recortar_cuadro(im):
    """Devuelve el cuadro azul del logo fuente (sin el margen negro)."""
    px = im.load()
    ancho, alto = im.size

    def es_azul(p):
        return abs(p[0] - 18) < 30 and abs(p[1] - 78) < 30 and abs(p[2] - 115) < 30

    xs = [x for x in range(ancho) if es_azul(px[x, alto // 2]) or es_azul(px[x, int(alto * 0.75)])]
    ys = [y for y in range(alto) if es_azul(px[int(ancho * 0.2), y])]
    return im.crop((min(xs), min(ys), max(xs) + 1, max(ys) + 1))


def separar_dibujo(cuadro):
    """Balón y estelas con transparencia donde estaba el fondo azul (bordes suaves)."""
    rgba = cuadro.convert('RGBA')
    datos = []
    for r, g, b, _ in rgba.getdata():
        d = ((r - AZUL[0]) ** 2 + (g - AZUL[1]) ** 2 + (b - AZUL[2]) ** 2) ** 0.5
        alfa = 0 if d < 28 else 255 if d > 70 else int((d - 28) / 42 * 255)
        datos.append((r, g, b, alfa))
    rgba.putdata(datos)
    # Limpia el ruido de la compresión JPG que queda en el borde del cuadro.
    margen = int(min(rgba.size) * 0.04)
    limpio = Image.new('RGBA', rgba.size, (0, 0, 0, 0))
    limpio.paste(rgba.crop((margen, margen, rgba.width - margen, rgba.height - margen)), (margen, margen))
    return limpio.crop(limpio.getbbox())


def montar(dibujo, lado, ocupacion, fondo, radio=0):
    """Centra el dibujo en un lienzo cuadrado ocupando `ocupacion` del lado."""
    lienzo = Image.new('RGBA', (lado, lado), (0, 0, 0, 0))
    if fondo is not None:
        ImageDraw.Draw(lienzo).rounded_rectangle((0, 0, lado - 1, lado - 1), radius=radio, fill=fondo + (255,))
    escala = ocupacion * lado / max(dibujo.size)
    dib = dibujo.resize((round(dibujo.width * escala), round(dibujo.height * escala)), Image.LANCZOS)
    lienzo.alpha_composite(dib, ((lado - dib.width) // 2, (lado - dib.height) // 2))
    return lienzo


def fuente(nombre, tam):
    return ImageFont.truetype(str(RAIZ / 'assets' / 'fonts' / nombre), tam)


def grafico_tienda(dibujo):
    ancho, alto = 1024, 500
    g = Image.new('RGBA', (ancho, alto), FONDO_APP + (255,))
    # Halo azul detrás del logo.
    halo = Image.new('RGBA', (ancho, alto), (0, 0, 0, 0))
    ImageDraw.Draw(halo).ellipse((20, 20, 480, 480), fill=AZUL + (110,))
    g.alpha_composite(halo.filter(ImageFilter.GaussianBlur(60)))
    logo = montar(dibujo, 300, 0.78, AZUL, radio=48)
    g.alpha_composite(logo, (100, (alto - 300) // 2))
    d = ImageDraw.Draw(g)
    x = 460
    d.text((x, 150), 'STREAK', font=fuente('Sora-700.ttf', 112), fill=CREMA)
    lema = 'NO ROMPAS LA RACHA'
    f_lema = fuente('Sora-600.ttf', 26)
    cx = x + 4
    for letra in lema:  # espaciado amplio como en la marca
        d.text((cx, 290), letra, font=f_lema, fill=AMARILLO)
        cx += d.textlength(letra, font=f_lema) + 6
    d.text((x + 2, 345), 'Quinielas de fútbol por puntos entre amigos', font=fuente('Inter-Regular.otf', 26), fill=GRIS)
    return g.convert('RGB')


def main():
    salida_tienda = Path(sys.argv[1]) if len(sys.argv) > 1 else RAIZ / 'build' / 'tienda'
    salida_tienda.mkdir(parents=True, exist_ok=True)
    dibujo = separar_dibujo(recortar_cuadro(Image.open(FUENTE).convert('RGB')))

    montar(dibujo, 1024, 0.78, AZUL, radio=160).save(RAIZ / 'assets' / 'logo' / 'streak_logo.png')
    montar(dibujo, 1024, 0.76, AZUL).convert('RGB').save(RAIZ / 'assets' / 'icons' / 'icon.png')
    # Zona segura del ícono adaptativo: el contenido debe caber en el 66 % central.
    montar(dibujo, 1024, 0.56, None).save(RAIZ / 'assets' / 'icons' / 'icon_foreground.png')
    montar(dibujo, 512, 0.76, AZUL).convert('RGB').save(salida_tienda / 'play_icono_512.png')
    grafico_tienda(dibujo).save(salida_tienda / 'play_grafico_1024x500.png')
    print('Listo:', salida_tienda)


if __name__ == '__main__':
    main()
