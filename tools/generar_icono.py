"""Genera el ícono de STREAK (assets/icons/icon.png 1024x1024 y icon_foreground.png).

Fondo #124E73, balón blanco y estela amarillo/naranja. Uso (desde streak_mobile/):
    python tools/generar_icono.py
Requiere Pillow. Luego: dart run flutter_launcher_icons
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw

AZUL = (0x12, 0x4E, 0x73, 255)
AMARILLO = (0xF2, 0xB8, 0x07, 255)
NARANJA = (0xD9, 0x42, 0x0B, 255)
BLANCO = (255, 255, 255, 255)
OSCURO = (0x1A, 0x20, 0x2C, 255)

SS = 4  # supersampling para bordes suaves
N = 1024 * SS


def pentagono(cx, cy, r, rot):
    return [(cx + r * math.cos(rot + i * 2 * math.pi / 5), cy + r * math.sin(rot + i * 2 * math.pi / 5)) for i in range(5)]


def dibujar_arte(lienzo: Image.Image, escala: float):
    """Dibuja estela + balón centrados en el lienzo; `escala` reduce todo (zona segura adaptativa)."""
    c = N / 2
    u = N * escala / 1024  # unidades de diseño (1024 = lienzo completo)

    # Estela: franjas diagonales que salen del balón hacia arriba a la izquierda.
    capa = Image.new('RGBA', lienzo.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(capa)
    bx, by = c + 70 * u, c + 50 * u  # centro del balón
    dx, dy = -math.cos(math.radians(38)), -math.sin(math.radians(38))  # dirección de la estela
    nx, ny = -dy, dx
    franjas = [(AMARILLO, -150, 1.00, 520), (NARANJA, -20, 1.00, 600), (AMARILLO, 110, 0.9, 470)]
    for color, desp, grosor, largo in franjas:
        x0, y0 = bx + nx * desp * u, by + ny * desp * u
        ancho = 78 * u * grosor
        x1, y1 = x0 + dx * largo * u, y0 + dy * largo * u
        # cuerpo que se afina hacia la cola
        d.polygon(
            [
                (x0 + nx * ancho / 2, y0 + ny * ancho / 2),
                (x0 - nx * ancho / 2, y0 - ny * ancho / 2),
                (x1, y1),
            ],
            fill=color,
        )
    lienzo.alpha_composite(capa)

    # Balón.
    r = 215 * u
    balon = Image.new('RGBA', lienzo.size, (0, 0, 0, 0))
    b = ImageDraw.Draw(balon)
    b.ellipse([bx - r, by - r, bx + r, by + r], fill=BLANCO)
    rot = -math.pi / 2
    central = pentagono(bx, by, r * 0.36, rot)
    b.polygon(central, fill=OSCURO)
    for i in range(5):
        a = rot + i * 2 * math.pi / 5
        # costura del vértice al borde
        b.line([(bx + r * 0.36 * math.cos(a), by + r * 0.36 * math.sin(a)), (bx + r * 0.72 * math.cos(a), by + r * 0.72 * math.sin(a))],
               fill=OSCURO, width=int(9 * u))
        # pentágono parcial entre costuras (se recorta con el círculo)
        a2 = a + math.pi / 5
        px, py = bx + r * 0.98 * math.cos(a2), by + r * 0.98 * math.sin(a2)
        b.polygon(pentagono(px, py, r * 0.30, a2 + math.pi), fill=OSCURO)
        b.line([(bx + r * 0.72 * math.cos(a), by + r * 0.72 * math.sin(a)), (px, py)], fill=OSCURO, width=int(9 * u))
    mascara = Image.new('L', lienzo.size, 0)
    ImageDraw.Draw(mascara).ellipse([bx - r, by - r, bx + r, by + r], fill=255)
    recortado = Image.new('RGBA', lienzo.size, (0, 0, 0, 0))
    recortado.paste(balon, (0, 0), mascara)
    # aro oscuro fino para separar el balón de la estela
    aro = Image.new('RGBA', lienzo.size, (0, 0, 0, 0))
    ImageDraw.Draw(aro).ellipse([bx - r, by - r, bx + r, by + r], outline=OSCURO, width=int(10 * u))
    lienzo.alpha_composite(recortado)
    lienzo.alpha_composite(aro)


def main():
    destino = Path(__file__).resolve().parent.parent / 'assets' / 'icons'
    destino.mkdir(parents=True, exist_ok=True)

    completo = Image.new('RGBA', (N, N), AZUL)
    dibujar_arte(completo, 1.0)
    completo.resize((1024, 1024), Image.LANCZOS).convert('RGB').save(destino / 'icon.png')

    # Primer plano del ícono adaptativo: transparente y dentro de la zona segura (~66 %).
    frente = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    dibujar_arte(frente, 0.62)
    frente.resize((1024, 1024), Image.LANCZOS).save(destino / 'icon_foreground.png')
    print('ok', destino)


if __name__ == '__main__':
    main()
