"""Erzeugt assets/models/wordmark.glb: 3D-Wortmarke STEIGER-SYSTEMS mit Logo-Ring.

Geometrie entsteht direkt aus der Schrift der Website (Inter Tight) und aus dem
Logo-Pfad von Bilder/logo-steiger-systems.svg. Zwei Materialien: "Ink" (Buchstaben
und Ring) und "Accent" (Bindestrich und Logo-Kern) — die Namen erwartet das Skript
im Hero, um im Dunkelmodus die Farben zu tauschen.

Aufruf: python build_wordmark.py <font.ttf> <out.glb>
Braucht: trimesh, shapely, matplotlib, mapbox_earcut (pip install trimesh shapely matplotlib mapbox-earcut)

Die Schrift ist Inter Tight im Schnitt 600. Die variable Schriftdatei liegt unter
https://github.com/google/fonts/raw/main/ofl/intertight/InterTight%5Bwght%5D.ttf
und wird einmalig auf den Schnitt festgelegt:

    from fontTools.ttLib import TTFont
    from fontTools.varLib import instancer
    f = TTFont("InterTight[wght].ttf")
    instancer.instantiateVariableFont(f, {"wght": 600}, inplace=True)
    f.save("InterTight-600.ttf")
"""
import sys
import numpy as np
import shapely
from shapely.geometry import Polygon, Point, box
from shapely.ops import unary_union
import trimesh
from matplotlib.textpath import TextPath
import matplotlib.font_manager as fm

FONT, OUT = sys.argv[1], sys.argv[2]

TEXT = "STEIGER-SYSTEMS"
SIZE = 2000.0         # Schriftgrösse in Pfadeinheiten (hoch = feine Kurven)
TRACKING = 0.16       # Sperrung wie im Logo (letter-spacing: .16em)
DEPTH_RATIO = 0.22    # Tiefe im Verhältnis zur Versalhöhe
INK = [0x16, 0x18, 0x1B, 255]
ACCENT = [0x1F, 0x5F, 0xD0, 255]


def rings_to_polygon(path):
    """TextPath -> shapely-Polygon.

    Konturen, die sich selbst berühren (z. B. der Schenkel des R am Bauch),
    werden mit buffer(0) repariert. Ob eine Kontur Loch oder Fläche ist,
    entscheidet die Schachtelungstiefe, nicht die Reihenfolge im Pfad.
    """
    polys = []
    for ring in path.to_polygons(closed_only=True):
        if len(ring) < 3:
            continue
        p = Polygon(ring).buffer(0)          # repariert Selbstüberschneidungen
        if not p.is_empty:
            polys.append(p)

    outers, holes = [], []
    for i, p in enumerate(polys):
        probe = p.representative_point()
        # Nur grössere Konturen können eine kleinere umschliessen — sonst hält sich
        # das O für sein eigenes Loch.
        depth = sum(1 for j, q in enumerate(polys)
                    if j != i and q.area > p.area and q.contains(probe))
        (holes if depth % 2 else outers).append(p)

    if not outers:
        return None
    shape = unary_union(outers)
    if holes:
        shape = shape.difference(unary_union(holes))
    return shape


def text_shapes(font_path):
    """Buchstaben einzeln setzen, damit die Sperrung stimmt. Gibt (geom, is_accent)."""
    prop = fm.FontProperties(fname=font_path)
    ft = fm.get_font(font_path)
    out, x = [], 0.0
    for ch in TEXT:
        # TextPath setzt die Grösse des gemeinsamen Font-Objekts zurück (FONT_SCALE),
        # darum vor jedem Vorschub neu setzen.
        ft.set_size(SIZE, 72)
        glyph = ft.load_char(ord(ch))
        advance = glyph.linearHoriAdvance / 65536.0
        if ch != " ":
            geom = rings_to_polygon(TextPath((x, 0), ch, size=SIZE, prop=prop))
            if geom and not geom.is_empty:
                out.append((geom, ch == "-"))
        x += advance + TRACKING * SIZE
    return out, x - TRACKING * SIZE


def logo_mark(height):
    """Ring mit eckiger Ecke unten links + Kern, aus dem Logo-SVG (24x24, y nach unten)."""
    body = unary_union([
        Point(12, 12).buffer(11, quad_segs=64),
        box(1, 12, 12, 23).buffer(-2, join_style=1).buffer(2, join_style=1),
    ])
    ring = body.buffer(1, quad_segs=32).difference(body.buffer(-1, quad_segs=32))
    core = Point(12, 12).buffer(3.2, quad_segs=48)
    s = height / 22.0                                  # Ring auf Versalhöhe bringen
    flip = [s, 0, 0, -s, 0, 0]                         # SVG-y zeigt nach unten
    return (shapely.affinity.affine_transform(ring, flip),
            shapely.affinity.affine_transform(core, flip))


def main():
    glyphs, text_width = text_shapes(FONT)
    cap = max(g.bounds[3] for g, _ in glyphs)          # Versalhöhe aus dem "S"
    depth = cap * DEPTH_RATIO

    ring, core = logo_mark(cap)
    gap = cap * 0.55
    mark_w = ring.bounds[2] - ring.bounds[0]
    shift = mark_w + gap                               # Text hinter die Marke schieben
    ring = shapely.affinity.translate(ring, yoff=cap)   # Marke auf die Grundlinie
    core = shapely.affinity.translate(core, yoff=cap)

    ink = [shapely.affinity.translate(g, xoff=shift) for g, acc in glyphs if not acc] + [ring]
    accent = [shapely.affinity.translate(g, xoff=shift) for g, acc in glyphs if acc] + [core]

    meshes = {}
    for name, parts, color in (("Ink", ink, INK), ("Accent", accent, ACCENT)):
        singles = [s for p in parts if not p.is_empty
                   for s in (p.geoms if p.geom_type == "MultiPolygon" else [p])]
        solids = [trimesh.creation.extrude_polygon(p, depth, engine="earcut")
                  for p in singles if p.geom_type == "Polygon" and p.area > 0]
        mesh = trimesh.util.concatenate(solids)
        mesh.visual = trimesh.visual.TextureVisuals(
            material=trimesh.visual.material.PBRMaterial(
                name=name, baseColorFactor=color, metallicFactor=0.0, roughnessFactor=0.38))
        meshes[name] = mesh

    # Alles gemeinsam auf den Ursprung zentrieren (x/y/z), damit es um die Mitte dreht
    whole = trimesh.util.concatenate(list(meshes.values()))
    center = whole.bounds.mean(axis=0)
    scale = 1.0 / cap                                  # Versalhöhe = 1 Einheit
    scene = trimesh.Scene()
    for name, mesh in meshes.items():
        mesh.apply_translation(-center)
        mesh.apply_scale(scale)
        scene.add_geometry(mesh, geom_name=name, node_name=name)

    scene.export(OUT)
    b = scene.bounds
    print(f"{OUT}: {sum(len(m.faces) for m in meshes.values())} Dreiecke, "
          f"Breite {b[1][0]-b[0][0]:.2f}, Hoehe {b[1][1]-b[0][1]:.2f}, Tiefe {b[1][2]-b[0][2]:.2f}")


main()
