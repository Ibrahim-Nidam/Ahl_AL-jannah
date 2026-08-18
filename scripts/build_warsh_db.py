"""Builds assets/quran_warsh.db from the QPC (QuranPedia) Warsh bundle.

The QPC Warsh dataset (https://fonts.quran.ws/bundles/uthmanic-warsh-v21/quran.json)
provides raw Warsh-riwaya Uthmani text without basmala, without hizb, and with
26 rows whose juz is 0 (the extra ayahs Warsh splits beyond the Hafs count).

This script produces a DB mirroring the Hafs assets/quran.db structure so the
app can treat both riwayat identically:

  warsh_ayahs(id, surah_id, number, text_ar, juz, page, hizb)

  * basmala is embedded in every surah's ayah 1 except At-Tawbah (9), using
    the exact basmala string from the Hafs DB (the printed bismillah is the
    same calligraphic element in both Madani mushafs);
  * juz/hizb are taken from the Hafs DB by (surah, number) when the ayah also
    exists in Hafs, falling back to the first ayah's juz/hizb on the same page
    for the Warsh-only extra ayahs (this also repairs the juz=0 rows);
  * the page structure is kept exactly as the QPC bundle provides it
    (604 pages), so Hafs and Warsh line up 1:1 for page-based bookmarks.

Run:  python scripts/build_warsh_db.py [--source <quran.json>] [--out <quran_warsh.db>]
"""

import argparse
import json
import os
import sqlite3


def load_hafs_metadata(hafs_db):
    conn = sqlite3.connect(hafs_db)
    cur = conn.cursor()

    hafs_juz = {}
    hafs_hizb = {}
    page_first_juz = {}
    page_first_hizb = {}

    for row in cur.execute(
        "SELECT surah_id, number, juz, hizb, page FROM ayahs ORDER BY surah_id, number"
    ):
        surah_id, number, juz, hizb, page = row
        hafs_juz[(surah_id, number)] = juz
        hafs_hizb[(surah_id, number)] = hizb
        if page not in page_first_juz:
            page_first_juz[page] = juz
            page_first_hizb[page] = hizb

    basmala = cur.execute(
        "SELECT text_ar FROM ayahs WHERE surah_id = 1 AND number = 1"
    ).fetchone()[0]
    conn.close()
    return hafs_juz, hafs_hizb, page_first_juz, page_first_hizb, basmala


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--source",
        default=os.path.join(os.path.dirname(__file__), "..", "warsh_src", "quran.json"),
        help="Path to the QPC Warsh quran.json bundle",
    )
    parser.add_argument(
        "--out",
        default=os.path.join(os.path.dirname(__file__), "..", "assets", "quran_warsh.db"),
        help="Output sqlite database path",
    )
    args = parser.parse_args()

    source_path = os.path.abspath(args.source)
    out_path = os.path.abspath(args.out)
    hafs_db = os.path.join(os.path.dirname(out_path), "quran.db")

    print(f"Source : {source_path}")
    print(f"Output : {out_path}")

    with open(source_path, encoding="utf-8") as f:
        data = json.load(f)

    ayat = data["ayat"]
    print(f"Bundle total : {data['total']} ({data['source']}, riwaya={data['riwaya']})")

    hafs_juz, hafs_hizb, page_first_juz, page_first_hizb, basmala = load_hafs_metadata(
        hafs_db
    )
    print(f"Basmala    : {basmala}")

    if os.path.exists(out_path):
        os.remove(out_path)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)

    conn = sqlite3.connect(out_path)
    cur = conn.cursor()
    cur.execute(
        """
        CREATE TABLE warsh_ayahs (
          id        INTEGER PRIMARY KEY,
          surah_id  INTEGER NOT NULL,
          number    INTEGER NOT NULL,
          text_ar   TEXT NOT NULL,
          juz       INTEGER NOT NULL,
          page      INTEGER NOT NULL,
          hizb      INTEGER NOT NULL
        );
        """
    )
    cur.execute("CREATE INDEX idx_warsh_page ON warsh_ayahs(page);")
    cur.execute("CREATE INDEX idx_warsh_surah ON warsh_ayahs(surah_id, number);")
    cur.execute("CREATE INDEX idx_warsh_juz ON warsh_ayahs(juz);")
    conn.commit()

    basmala_added = 0
    juz_fixed = 0
    juz_from_hafs = 0
    juz_from_page = 0
    hizb_from_hafs = 0
    hizb_from_page = 0
    seen = set()

    for i, item in enumerate(ayat, start=1):
        surah_id = int(item["surah"])
        number = int(item["ayah"])
        text = item["text"]
        page = int(item["page"])
        src_juz = int(item["juz"])

        key = (surah_id, number)
        if key in seen:
            raise SystemExit(f"Duplicate source ayah: {key}")
        seen.add(key)

        if surah_id != 9 and number == 1:
            text = basmala + " " + text
            basmala_added += 1

        if src_juz >= 1:
            juz = src_juz
        else:
            juz_fixed += 1
            if key in hafs_juz:
                juz = hafs_juz[key]
                juz_from_hafs += 1
            else:
                juz = page_first_juz.get(page, 1)
                juz_from_page += 1

        if key in hafs_hizb:
            hizb = hafs_hizb[key]
            hizb_from_hafs += 1
        else:
            hizb = page_first_hizb.get(page, 1)
            hizb_from_page += 1

        cur.execute(
            "INSERT INTO warsh_ayahs (id, surah_id, number, text_ar, juz, page, hizb) "
            "VALUES (?, ?, ?, ?, ?, ?, ?)",
            (i, surah_id, number, text, juz, page, hizb),
        )

    conn.commit()

    # ── Diagnostics ──
    total = cur.execute("SELECT COUNT(*) FROM warsh_ayahs").fetchone()[0]
    pages = cur.execute("SELECT COUNT(DISTINCT page) FROM warsh_ayahs").fetchone()[0]
    pages_range = cur.execute("SELECT MIN(page), MAX(page) FROM warsh_ayahs").fetchone()
    missing_pages = [
        p
        for p in range(1, 605)
        if cur.execute(
            "SELECT COUNT(*) FROM warsh_ayahs WHERE page = ?", (p,)
        ).fetchone()[0]
        == 0
    ]
    juz_zero = cur.execute(
        "SELECT COUNT(*) FROM warsh_ayahs WHERE juz = 0 OR juz > 30"
    ).fetchone()[0]
    hizb_bad = cur.execute(
        "SELECT COUNT(*) FROM warsh_ayahs WHERE hizb < 1 OR hizb > 60"
    ).fetchone()[0]
    empty_text = cur.execute(
        "SELECT COUNT(*) FROM warsh_ayahs WHERE text_ar IS NULL OR text_ar = ''"
    ).fetchone()[0]
    per_surah = cur.execute(
        "SELECT surah_id, COUNT(*) FROM warsh_ayahs GROUP BY surah_id ORDER BY surah_id"
    ).fetchall()
    noncontig = []
    for surah_id, cnt in per_surah:
        max_num = cur.execute(
            "SELECT MAX(number) FROM warsh_ayahs WHERE surah_id = ?", (surah_id,)
        ).fetchone()[0]
        if max_num != cnt:
            noncontig.append((surah_id, cnt, max_num))

    print("=" * 60)
    print("  WASH DATABASE BUILD — DIAGNOSTICS")
    print("=" * 60)
    print(f"Rows                : {total}")
    print(f"Pages (distinct)    : {pages}  range {pages_range[0]}-{pages_range[1]}")
    print(f"Missing pages       : {missing_pages if missing_pages else 'none'}")
    print(f"Basmala embedded    : {basmala_added}")
    print(f"juz=0 repaired      : {juz_fixed} "
          f"(from Hafs={juz_from_hafs}, from page={juz_from_page})")
    print(f"hizb from Hafs      : {hizb_from_hafs}")
    print(f"hizb from page      : {hizb_from_page}")
    print(f"Bad juz (0 or >30)  : {juz_zero}")
    print(f"Bad hizb            : {hizb_bad}")
    print(f"Empty text          : {empty_text}")
    print(f"Non-contiguous surahs (surah, rows, max_num): {noncontig if noncontig else 'none'}")
    print("Per-surah counts (first 10):", per_surah[:10])
    print("=" * 60)

    conn.close()
    print("Done.")


if __name__ == "__main__":
    main()