# Tajweed Comparison #2 — CheeseWithSauce/TheHolyQuranJSONFormat vs Quran Foundation (`quran/tajweed`)

- **Date:** 2026-07-31
- **Repo A:** https://github.com/CheeseWithSauce/TheHolyQuranJSONFormat (static per-verse HTML, 15 CSS classes)
- **Repo B:** https://github.com/quran/tajweed (Quran.com / Quran Foundation — "Tajweed Highlighting Experiments", Java, MADANI + NASKH modes)

## 1. Architectural difference

| | CheeseWithSauce | Quran Foundation |
|---|---|---|
| Data model | **Static markup** shipped per verse (`text_tajweed_html`, 15 CSS classes). Consumer just renders HTML. | **Runtime engine** (Java). `TajweedRules.MADANI_RULES` / `NASKH_RULES` are rule pipelines (7 rule classes: Ghunna, Idgham, Ikhfa, Iqlab, Meem, Qalqalah, Maad) that scan the text and emit `ResultType`s with offsets. |
| Output | `<tajweed class="...">` around the highlighted letters | `List<Result>` with `start/end` + `ResultType` — a proper span API |
| Rules granularity | 15 CSS classes, incl. non-articulation rules | 13 `ResultType`s in MADANI mode (some are split two-part results), no wasl/shamsiyya/slnt |
| Colors | Defined in repo CSS (not examined) | Hard-coded per result type per mode (see §4) |

## 2. Rule coverage matrix

| Tajweed rule | CheeseWithSauce | Quran Foundation (MADANI) | Match? |
|---|---|---|---|
| Ghunnah (نّ مّ) | `ghunnah` | `GHUNNA` (green) | ✅ |
| Idgham bighunnah | `idgham_ghunnah` (whole merge, one color) | **two-part:** `IDGHAM_NOT_PRONOUNCED` (noon/tanween, gray) + `IDGHAM_WITH_GHUNNA` (letter, green) | ⚠️ different visualization philosophy |
| Idgham bila ghunnah | `idgham_wo_ghunnah` | `IDGHAM_WITHOUT_GHUNNA` (gray) | ✅ (foundation marks only the letter, not the noon) |
| Idgham shafawi (م+م) | `idgham_shafawi` | `MEEM_IDGHAM` (green) | ✅ |
| Ikhfa | `ikhafa` (noon **and** next letter) | `IKHFA` (yellow — **only the noon/tanween**, "madani way") | ⚠️ different span extent |
| Ikhfa shafawi (م+ب) | `ikhafa_shafawi` | `MEEM_IKHFA` (yellow) | ✅ |
| Iqlab | `iqlab` (whole ن→م conversion) | **two-part:** `IQLAB` (green) + `IQLAB_NOT_PRONOUNCED` (gray) | ⚠️ |
| Qalqalah (incl. kubra) | `qalaqah` | `QALQALAH` (blue, letter + sukun only) | ✅ |
| Madd tabee'i (natural) | `madda_normal` (highlighted) | **NOT highlighted** (documented decision: tabee'i left uncolored in the madani mushaf) | ❌ |
| Madd wajib muttasil | `madda_obligatory` | `MAAD_MUNFASSIL_MUTASSIL` (red — same color as munfasil, documented inability to distinguish) | ⚠️ |
| Madd ja'iz munfasil | `madda_permissible` | `MAAD_MUNFASSIL_MUTASSIL` (red, same as above) | ⚠️ |
| Madd lazim | `madda_necessary` | `MAAD_LONG` (dark red) | ✅ |
| Madd sila sughra (ۥ/ۦ small waw/yeh) | folded into `madda_normal` | `MAAD_SILA_SUGHRA` (light orange — dedicated result) | ❌ |
| Madd li-s-sukun (هَمْزَ later) | — | `MAAD_SUKOON` (orange) | ❌ (repo A has no class) |
| Hamzat wasl | `ham_wasl` | **not handled** | ❌ |
| Laam shamsiyyah | `laam_shamsiyah` | **not handled** | ❌ |
| Silent letter | `slnt` | **not handled** | ❌ |

## 3. Visualization philosophy (important)

- **Quran Foundation MADANI** follows the **Dar Al-Maarifa "one-color-per-family"** scheme: green = ghunnah family, red = madd, yellow = ikhfa, blue = qalqalah, orange = madd sukoon, gray = "not pronounced" (the noon/tanween parts of idgham & iqlab are grayed out to show they're not sounded). It **deliberately does not color** hamzat wasl, lam shamsiyyah, silent letters, or natural madd — those are stylistic, not articulation rules.
- **NASKH mode** re-uses the same 7 rule classes but with a different palette (`GHUNNA_NASKH`, `GHUNNA_MEEM_IDGHAM` result types, orange ghunnah, purple iqlab, red qalqalah, blue ikhfa, pink meem-ikhfa).
- **CheeseWithSauce** aims for a **more exhaustive Dar Al-Maarifa-style coloring** that *also* marks wasl, shamsiyyah and silent letters, and subdivides madd into 4 classes. It is the closest to a full "tajweed mushaf" print-style rendering, but it's static HTML with an immature segments API (`rule: null` in real data).

## 4. Quran Foundation MADANI color reference

| ResultType | Color |
|---|---|
| GHUNNA, IDGHAM_WITH_GHUNNA, IQLAB, MEEM_IDGHAM | green `#43A047` |
| IDGHAM_NOT_PRONOUNCED, IQLAB_NOT_PRONOUNCED, IDGHAM_WITHOUT_GHUNNA | gray `#EEEEEE` |
| QALQALAH | blue `#0091EA` |
| IKHFA, MEEM_IKHFA | yellow `#EACE00` |
| MAAD_SUKOON | orange `#FB8C00` |
| MAAD_MUNFASSIL_MUTASSIL | red `#F44336` |
| MAAD_SILA_SUGHRA | light orange `#FFE0B2` |
| MAAD_LONG | dark red `#B71C1C` |

## 5. Maturity & licensing

- Quran Foundation repo is explicitly labeled **"work in progress"** (2016, Java) — it is the research/engine behind Quran.com's tajweed but is not a maintained API. No license file found in tree.
- CheeseWithSauce JSON has a defined schema + README, is widely mirrored, and is MIT-licensed (README) — but the structured `tajweed_segments` output is not actually granular yet.

## 6. Headline findings

1. **Quran Foundation = engine, not data.** Proper span API (`Result{start,end,type}`), two-part results for idgham/iqlab, documented rule decisions — but only **7 rule families**, no wasl/shamsiyya/slnt, and natural madd intentionally uncolored.
2. **CheeseWithSauce = data, richer taxonomy** (15 classes) that includes the "stylistic" rules the Foundation skips, plus a dedicated `madda_sila`-style treatment. But it's HTML-only; segments API is placeholder.
3. **They disagree on ikhfa extent** (Foundation: noon only; CheeseWithSauce: noon + next letter) and on **madd tabee'i** (Foundation: uncolored; CheeseWithSauce: colored).
4. **They agree** on all core articulation rules (ghunnah, idgham, iqlab, qalqalah, meem rules, madd wajib/jaiz/lazim).

## 7. Implementation status (Ahl Jannah)

The two Quran-Foundation "selectives" were implemented in the app's analyzer
(`lib/features/quran/domain/tajweed/quran_tajweed_analyzer.dart`):

- **Madd subtypes:** `madd` (tabee'i), `maddWajib` (muttasil), `maddJaiz`
  (munfasil), `maddLazim` (6), `maddSilaSughra` — new enum values + colors.
  Detection matches the Foundation model but is stricter than the engine's
  explicit-marker shortcut: a maddah letter before a mushaddad letter is
  correctly classified as `maddLazim` (e.g. ٱلضَّآلِّينَ), which the
  Foundation engine miscolors as muttasil/munfasil red.
- **Idgham/iqlab two-part:** the unpronounced noon/tanween of idgham
  bighunnah and iqlab is painted `notPronounced` (gray) while the merged
  letter / following ب keeps `ghunnah` / `iqlab` (green), matching
  `IDGHAM_NOT_PRONOUNCED`+`IDGHAM_WITH_GHUNNA` and `IQLAB_NOT_PRONOUNCED`+`IQLAB`.
- CheeseWithSauce was intentionally **not** adopted (no wasl/shamsiyya/slnt,
  natural madd stays colored, sila sughra uses small waw/yeh marks).
