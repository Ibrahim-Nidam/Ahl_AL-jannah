# Render a word/ayah exactly the way Flutter does: HarfBuzz shaping +
# FreeType rasterization. Saves a PNG so missing dots are visible.
import sys
import uharfbuzz as hb
import freetype
from PIL import Image

def render(text, ttf_path, out_png, px=110):
    blob = open(ttf_path, "rb").read()
    face = hb.Face(blob)
    hbfont = hb.Font(face)
    hbfont.scale = (px * 64, px * 64)

    buf = hb.Buffer()
    buf.add_str(text)
    buf.guess_segment_properties()
    hb.shape(hbfont, buf)
    infos = buf.glyph_infos
    positions = buf.glyph_positions

    ft = freetype.Face(ttf_path)
    ft.set_pixel_sizes(0, px)

    # measure
    total_w = 0
    max_above = 0
    max_below = 0
    placed = []
    x = 0
    for info, pos in zip(infos, positions):
        ft.load_glyph(info.codepoint, freetype.FT_LOAD_RENDER)
        slot = ft.glyph
        bitmap = slot.bitmap
        w, h, bl = bitmap.width, bitmap.rows, slot.bitmap_left
        top = slot.bitmap_top
        bearing_x = pos.x_offset / 64.0
        bearing_y = pos.y_offset / 64.0
        gx = x / 64.0 + bearing_x + bl
        gy = -bearing_y - top
        placed.append((info.codepoint, gx, gy, bitmap.buffer, w, h, bitmap.pitch))
        x += pos.x_advance
        max_above = max(max_above, top - bearing_y)
        max_below = max(max_below, h - top + bearing_y)
    total_w = int(x / 64.0) + 40
    height = int(max_above + max_below + 40)

    canvas = Image.new("L", (total_w, height), 255)
    px_canvas = canvas.load()
    origin_y = int(max_above + 20)
    for (gid, gx, gy, buf_data, w, h, pitch) in placed:
        gx = int(gx) + 20
        gy = int(gy) + origin_y
        for row in range(h):
            for col in range(w):
                v = buf_data[row * pitch + col]
                if v == 0:
                    continue
                X, Y = gx + col, gy + row
                if 0 <= X < canvas.width and 0 <= Y < canvas.height:
                    cur = px_canvas[X, Y]
                    # ink is dark; blend (FreeType uses coverage)
                    px_canvas[X, Y] = max(0, cur - v)
    # right-to-left: HarfBuzz returns visual LTR order already, so no flip
    canvas.save(out_png)
    print("saved", out_png, canvas.size)

if __name__ == "__main__":
    ttf = sys.argv[1]
    text = sys.argv[2]
    out = sys.argv[3]
    px = int(sys.argv[4]) if len(sys.argv) > 4 else 110
    render(text, ttf, out, px)
