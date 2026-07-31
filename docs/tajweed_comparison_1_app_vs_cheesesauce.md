# Tajweed Comparison #1 — Ahl Jannah App vs CheeseWithSauce/TheHolyQuranJSONFormat

- **Date:** 2026-07-31
- **App side:** `lib/features/quran/domain/tajweed/quran_tajweed_analyzer.dart` + `quran_tajweed_rule.dart` + `TajweedColors` in `lib/core/theme/app_colors.dart`
- **Repo side:** https://github.com/CheeseWithSauce/TheHolyQuranJSONFormat (`tajweedsurahs/NNN.json`, `text_tajweed_html` + `tajweed_segments`)

## 1. Architectural difference

| | Ahl Jannah app | CheeseWithSauce |
|---|---|---|
| Data model | **Algorithmic.** `QuranTajweedAnalyzer.analyze(textAr)` walks the voweled Uthmani text at runtime and produces contiguous colored spans. | **Pre-computed.** Each verse ships ready-to-render `text_tajweed_html` (inline `<tajweed class=...>` spans) plus a `tajweed_segments` array. |
| Input text | `assets/quran.db` Uthmani text, fed through `QuranAyahSpanBuilder.formatAyahText` (basmala handling, U+06DF/U+06E0 strip). | Repo's own Uthmani text (`text_ar`) in the same JSON files. |
| Performance | Hot integer code-unit loop, LRU cache of 2048 (`_cache`), skips izhar. | No computation — rendering is trivial, but payload is large (HTML + segments per verse). |
| Localization of rules | Rules are a fixed 6-enum in Dart, single color each. | CSS classes are only meaningful if you ship the repo's CSS. |

## 2. Rule coverage matrix

| Tajweed rule | App rule (color) | CheeseWithSauce class | Notes |
|---|---|---|---|
| Madd tabee'i (natural) | `madd` (red) — **all madd collapsed into one color** | `madda_normal` | CheeseWithSauce also colors small-high marks (`ۥ`) as madda_normal; app does not color madd sila sughra |
| Madd wajib muttasil (4/5) | `madd` (red, same) | `madda_obligatory` | |
| Madd ja'iz munfasil (4) | `madd` (red, same) | `madda_permissible` | |
| Madd lazim (6) | `madd` (red, same) | `madda_necessary` | App cannot visually distinguish the 4 madd lengths |
| Dagger alif / maddah sign | `madd` (red) | `madda_normal` | Same coverage, different granularity |
| Ghunnah (نّ / مّ mushaddad) | `ghunnah` (green) | `ghunnah` | Match |
| Idgham bighunnah (يرملون) | `ghunnah` (green) | `idgham_ghunnah` | Match — both paint through the next letter |
| Idgham bila ghunnah (ل ر) | `idghamBilaGhunnah` (brown) | `idgham_wo_ghunnah` | Match |
| Idgham shafawi (م ساكنة + م) | `ghunnah` (green — no separate class) | `idgham_shafawi` | App merges into ghunnah; repo has its own class |
| Ikhfa | `ikhfa` (teal) | `ikhafa` | Match — both paint noon/tanween **and** the next letter |
| Ikhfa shafawi (م ساكنة + ب) | `ikhfaShafawi` (gray) | `ikhafa_shafawi` | Match |
| Iqlab | `ghunnah` (green — folded into ghunnah) | `iqlab` | App has **no distinct iqlab rule**; visually same as ghunnah |
| Qalqalah (incl. kubra at end of ayah) | `qalqalah` (blue) | `qalaqah` | Match |
| Hamzat wasl | **not highlighted** | `ham_wasl` | App misses this rule entirely |
| Laam shamsiyyah | **not highlighted** | `laam_shamsiyah` | App misses this rule entirely |
| Silent letter (slnt) | **stripped as display artifact** (U+06DF/U+06E0 removed in `QuranAyahSpanBuilder` per the "dots" fix) | `slnt` | **Direct conflict:** repo colors `أُو۟لَٰٓئِكَ`'s silent و as slnt; app deliberately removes the very dot the repo uses |

## 3. Segment semantics

- **App:** contiguous runs; a span is `[start, end)` over the text. Idgham/ikhfa spans include the following letter; qalqalah spans cover the letter + its sukun/marks; ghunnah covers letter + shadda.
- **CheeseWithSauce:** per-letter inline `<tajweed>` classes — richer (15 classes vs 6). However, the `tajweed_segments` field in the actual JSON contains a single element `{"rule": null, "text": "<entire html>"}` for typical verses, **not** the granular per-rule segments described in the README — so the structured segments API is not yet usable as a clean span source.

## 4. Text/font fidelity

- Both are Uthmani. The repo text includes the small-high marks (U+06DF etc.) that the app strips for its fonts; adopting the repo's HTML as-is would undo the "dot strip" fix and the classes depend on the repo's CSS.
- The app works off its own `quran.db`; the repo text would need to be imported/synced.

## 5. Headline findings

1. **Rule superset:** CheeseWithSauce covers **15 rules**, the app covers **6**. App is missing: hamzat wasl, laam shamsiyyah, silent letters, and it merges iqlab→ghunnah, idgham-shafawi→ghunnah, and all 4 madd types into single colors.
2. **Direct conflict on silent letters:** the app removes U+06DF/U+06E0 as artifacts; the repo uses them as `slnt` data.
3. **Madd granularity:** the repo distinguishes natural/necessary/permissible/obligatory madd; the app renders one red for everything.
4. **Segments not ready:** despite the README, `tajweed_segments` in the real data is `{rule:null}` — only the HTML classes are usable today.
