import urllib.request
import json
import sqlite3
import os
import math

def download_json(url):
    print(f"Downloading {url}...")
    req = urllib.request.Request(
        url, 
        headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'}
    )
    with urllib.request.urlopen(req) as response:
        return json.loads(response.read().decode('utf-8'))

def main():
    # Make sure assets folder exists
    os.makedirs('../assets', exist_ok=True)
    db_path = '../assets/quran.db'
    
    # Remove existing db if any
    if os.path.exists(db_path):
        os.remove(db_path)
        
    print("Connecting to database...")
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Create tables
    cursor.execute("""
    CREATE TABLE surahs (
      id            INTEGER PRIMARY KEY,
      name_ar       TEXT NOT NULL,
      name_en       TEXT NOT NULL,
      revelation    TEXT NOT NULL,
      ayah_count    INTEGER NOT NULL
    );
    """)
    
    cursor.execute("""
    CREATE TABLE ayahs (
      id            INTEGER PRIMARY KEY,
      surah_id      INTEGER NOT NULL REFERENCES surahs(id),
      number        INTEGER NOT NULL,
      text_ar       TEXT NOT NULL,
      translation_en TEXT,
      translation_fr TEXT,
      juz           INTEGER NOT NULL,
      page          INTEGER NOT NULL,
      hizb          INTEGER NOT NULL
    );
    """)
    
    conn.commit()
    
    # Fetch datasets
    arabic_data = download_json("https://api.alquran.cloud/v1/quran/quran-uthmani")
    english_data = download_json("https://api.alquran.cloud/v1/quran/en.sahih")
    french_data = download_json("https://api.alquran.cloud/v1/quran/fr.hamidullah")
    
    # Insert Surahs
    print("Processing surahs...")
    surahs = arabic_data['data']['surahs']
    for s in surahs:
        cursor.execute(
            "INSERT INTO surahs (id, name_ar, name_en, revelation, ayah_count) VALUES (?, ?, ?, ?, ?)",
            (
                s['number'],
                s['name'],
                s['englishName'],
                s['revelationType'].lower(),
                len(s['ayahs'])
            )
        )
    
    # Insert Ayahs
    print("Processing ayahs...")
    arabic_surahs = arabic_data['data']['surahs']
    english_surahs = english_data['data']['surahs']
    french_surahs = french_data['data']['surahs']
    
    for surah_idx in range(114):
        ar_surah = arabic_surahs[surah_idx]
        en_surah = english_surahs[surah_idx]
        fr_surah = french_surahs[surah_idx]
        
        surah_id = ar_surah['number']
        print(f"Surah {surah_id}: {ar_surah['englishName']}")
        
        for ayah_idx in range(len(ar_surah['ayahs'])):
            ar_ayah = ar_surah['ayahs'][ayah_idx]
            en_ayah = en_surah['ayahs'][ayah_idx]
            fr_ayah = fr_surah['ayahs'][ayah_idx]
            
            # Global ID
            global_id = ar_ayah['number']
            number_in_surah = ar_ayah['numberInSurah']
            text_ar = ar_ayah['text']
            
            translation_en = en_ayah['text']
            translation_fr = fr_ayah['text']
            
            juz = ar_ayah['juz']
            page = ar_ayah['page']
            
            # Hizb is calculated from hizbQuarter (which represents quarter of a hizb)
            # there are 4 quarters in 1 hizb, so hizb = ceil(hizbQuarter / 4)
            hizb_quarter = ar_ayah['hizbQuarter']
            hizb = math.ceil(hizb_quarter / 4.0)
            
            cursor.execute(
                "INSERT INTO ayahs (id, surah_id, number, text_ar, translation_en, translation_fr, juz, page, hizb) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
                (
                    global_id,
                    surah_id,
                    number_in_surah,
                    text_ar,
                    translation_en,
                    translation_fr,
                    juz,
                    page,
                    hizb
                )
            )
            
    conn.commit()
    conn.close()
    print("Database build complete!")

if __name__ == "__main__":
    main()
