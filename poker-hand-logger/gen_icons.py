"""Generate PWA icons: felt-green tile with a gold spade. Run: python3 gen_icons.py"""
from PIL import Image, ImageDraw

SS = 4  # supersample factor


def spade_points(S):
    cx = S / 2
    return {
        "left": (cx - 0.16 * S, 0.50 * S, 0.18 * S),   # (x, y, r)
        "right": (cx + 0.16 * S, 0.50 * S, 0.18 * S),
        "triangle": [(cx, 0.16 * S), (cx - 0.345 * S, 0.55 * S), (cx + 0.345 * S, 0.55 * S)],
        "stem": [(cx - 0.035 * S, 0.50 * S), (cx + 0.035 * S, 0.50 * S),
                 (cx + 0.145 * S, 0.80 * S), (cx - 0.145 * S, 0.80 * S)],
    }


def draw_icon(size, maskable=False):
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Felt background (full-bleed; OS handles rounding). Subtle vertical gradient.
    top, bot = (29, 74, 62), (14, 36, 29)
    for y in range(S):
        t = y / S
        r = int(top[0] + (bot[0] - top[0]) * t)
        g = int(top[1] + (bot[1] - top[1]) * t)
        b = int(top[2] + (bot[2] - top[2]) * t)
        d.line([(0, y), (S, y)], fill=(r, g, b, 255))

    # Inset the glyph for maskable safe-zone.
    inset = 0.14 if maskable else 0.0
    gx = inset * S
    gw = S * (1 - 2 * inset)
    pts = spade_points(gw)
    gold = (201, 162, 39, 255)

    def off(p):
        return (p[0] + gx, p[1] + gx + 0.02 * gw)

    lx, ly, lr = pts["left"]
    rx, ry, rr = pts["right"]
    d.ellipse([off((lx - lr, ly - lr)), off((lx + lr, ly + lr))], fill=gold)
    d.ellipse([off((rx - rr, ry - rr)), off((rx + rr, ry + rr))], fill=gold)
    d.polygon([off(p) for p in pts["triangle"]], fill=gold)
    d.polygon([off(p) for p in pts["stem"]], fill=gold)

    return img.resize((size, size), Image.LANCZOS)


for size in (192, 512):
    draw_icon(size).save(f"public/icon-{size}.png")
draw_icon(512, maskable=True).save("public/icon-512-maskable.png")
draw_icon(180).save("public/apple-touch-icon.png")
print("icons written to public/")
