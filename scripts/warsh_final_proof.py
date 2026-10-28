# -*- coding: utf-8 -*-
"""Final proof: take real Warsh DB words, apply the Dart-mirror rewrite,
shape with HarfBuzz, and render side-by-side (original vs rewritten) to PNG."""
import sqlite3
import uharfbuzz as hb
import freetype
from PIL import Image
import sys

sys.path.insert(0, r"C:\Users\Ibrahim\Desktop\Ahl Jannah - Copy\ahl_jannah\scripts")
from warsh_dart_parity import dart_rewrite_correct  # reuse validated logic

DB = r"C:\Users\Ibrahim\Desktop\Ahl Jannah - Copy\ahl_jannah\assets\quran_warsh.db"
FONT = r"C:\Users\Ibrahim\Desktop\Ahl Jannah - Copy\ahl_jannah\assets\fonts\uthmanic-warsh-v21.ttf"
OUT = r"C:\Users\Ibrahim\AppData\Local\Temp"

blob = hb.Blob.from_file_path(FONT)
face = hb.Face(blob)
font = hb.Font(face)
font.scale = (face.upem, face.upem)
ft = freetype.Face(FONT)
SIZE = 160
ft.set_pixel_sizes(0, SIZE)


def render_line(text, canvas_w, canvas_h, baseline):
    buf = hb.Buffer()
    buf.add_str(text)
    buf.guess_segment_properties()
    hb.shape(font, buf, {"calt": True, "init": True, "medi": True, "fina": True, "isol": True})
    infos, poss = buf.glyph_infos, buf.glyph_positions
    canvas = Image.new("L", (canvas_w, canvas_h), 255)
    x = 10
    for info, pos in zip(infos, poss):
        ft.load_glyph(info.codepoint, freetype.FT_LOAD_RENDER)
        bmp = ft.glyph.bitmap
        w, h = bmp.width, bmp.rows
        if w and h:
            bufb = bytearray()
            for r in range(h):
                bufb.extend(bmp.buffer[r * bmp.pitch: r * bmp.pitch + w])
            gimg = Image.frombytes("L", (w, h), bytes(bufb))
            y = baseline - ft.glyph.bitmap_top
            canvas.paste(gimg, (x, max(0, y)))
        x += int(pos.x_advance / face.upem * SIZE)
    return canvas


# Pick a few real words containing final qaf/feh
words = ["صِدْقٍ", "كَيْفَ", "سَوْفَ", "حَقَّ"]
conn = sqlite3.connect(DB)
cur = conn.cursor()
cur.execute("SELECT text_ar FROM warsh_ayahs LIMIT 50")
allrows = [r[0] for r in cur.fetchall()]

W = int(SIZE * 6)
H = int(SIZE * 1.4)
baseline = int(SIZE * 1.0)
strips = []
for wd in words:
    orig = wd
    rew = dart_rewrite_correct(wd)
    c1 = render_line(orig, W, H, baseline)
    c2 = render_line(rew, W, H, baseline)
    strip = Image.new("L", (W * 2 + 20, H), 255)
    strip.paste(c1, (0, 0))
    strip.paste(c2, (W + 20, 0))
    strips.append(strip)
    print(f"{wd} -> rewritten={[hex(ord(c)) for c in rew if ord(c) >= 0xFEC0]}")

# stack strips vertically
total_h = sum(s.height + 10 for s in strips)
max_w = max(s.width for s in strips)
combo = Image.new("L", (max_w, total_h), 255)
y = 0
for s in strips:
    combo.paste(s, (0, y))
    y += s.height + 10
combo.save(f"{OUT}\\warsh_final_proof.png")
print("saved warsh_final_proof.png  (LEFT=original, RIGHT=rewritten/dotted)")
