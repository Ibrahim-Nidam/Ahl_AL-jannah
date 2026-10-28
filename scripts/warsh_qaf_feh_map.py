# For each occurrence of ق and ف in the DB, record the shaped gid and
# whether that glyph has a real dot (3+ contours: body + head counter + dot,
# or body + dot when the head has no counter).
import sqlite3
from collections import Counter, defaultdict
import uharfbuzz as hb
import freetype

TTF = "assets/fonts/uthmanic-warsh-v21.ttf"
DB = "assets/quran_warsh.db"

blob = open(TTF, "rb").read()
face = hb.Face(blob)
hbfont = hb.Font(face)
ft = freetype.Face(TTF)

def contours_of(gid):
    cs = []
    def mv(a, u=None): cs.append([(a.x, a.y)])
    def ln(a, u=None): cs[-1].append((a.x, a.y))
    def cq(c, a, u=None): cs[-1].extend([(c.x, c.y), (a.x, a.y)])
    def cu(c1, c2, a, u=None): cs[-1].extend([(c1.x, c1.y), (c2.x, c2.y), (a.x, a.y)])
    try:
        ft.load_glyph(gid, freetype.FT_LOAD_NO_SCALE | freetype.FT_LOAD_NO_BITMAP)
        ft.glyph.outline.decompose(move_to=mv, line_to=ln, conic_to=cq, cubic_to=cu)
    except Exception:
        return []
    return cs

ccache = {}
def ncontours(gid):
    if gid not in ccache:
        ccache[gid] = len(contours_of(gid))
    return ccache[gid]

con = sqlite3.connect(DB)
cur = con.cursor()
cur.execute("SELECT surah_id, number, text_ar FROM warsh_ayahs")

stats = defaultdict(Counter)
examples = {}
for surah, number, text in cur.fetchall():
    for word in text.split(" "):
        if not word:
            continue
        buf = hb.Buffer()
        buf.add_str(word)
        buf.guess_segment_properties()
        hb.shape(hbfont, buf)
        byc = defaultdict(list)
        for info, pos in zip(buf.glyph_infos, buf.glyph_positions):
            byc[info.cluster].append((info.codepoint, pos.x_advance))
        for i, ch in enumerate(word):
            if ch not in "قف":
                continue
            gids = byc.get(i)
            if not gids:
                continue
            base = max(gids, key=lambda t: t[1])[0]
            n = ncontours(base)
            key = (ch, base, n)
            stats[ch][key] += 1
            examples.setdefault(key, []).append(f"{surah}:{number} {word}")

for ch in "قف":
    print(f"\n=== {ch} ===")
    for (c, gid, n), cnt in sorted(stats[ch].items(), key=lambda kv: -kv[1]):
        print(f"  gid={gid:4d} contours={n} count={cnt:5d} dotted={'YES' if n >= 3 else 'no'} e.g. {examples[(c, gid, n)][:3]}")
