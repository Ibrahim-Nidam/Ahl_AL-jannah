import uharfbuzz as hb

blob = open("assets/fonts/uthmanic-warsh-v21.ttf", "rb").read()
face = hb.Face(blob)
font = hb.Font(face)

def shape(text):
    buf = hb.Buffer()
    buf.add_str(text)
    buf.guess_segment_properties()
    hb.shape(font, buf)
    return buf.glyph_infos, buf.glyph_positions

for word in ["بِسْمِ", "تَعْبُدُونَ"]:
    infos, poss = shape(word)
    print(word, [(c, i.cluster, i.codepoint, p.x_advance) for c, i, p in zip(word, infos, poss)] if False else None)
    print(" chars:", list(enumerate(word)))
    print(" glyphs:", [(i.cluster, i.codepoint, p.x_advance) for i, p in zip(infos, poss)])
