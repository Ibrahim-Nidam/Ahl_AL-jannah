/// Detects tajweed rules in a fully-voweled Uthmani Quran ayah.
///
/// The input is expected to be the raw `textAr` from the database (or the
/// basmala-stripped form produced by `QuranAyahSpanBuilder.formatAyahText`).
/// The analyzer walks the text letter-by-letter, reads the short-vowel
/// marks attached to each letter, and classifies the standard Hafs rules:
///
///   * madd tabee'i (natural, 2)           → [QuranTajweedRule.madd]
///   * madd sila sughra (2)                → [QuranTajweedRule.maddSilaSughra]
///   * madd wajib muttasil (4–5)           → [QuranTajweedRule.maddWajib]
///   * madd ja'iz munfasil (4)             → [QuranTajweedRule.maddJaiz]
///   * madd lazim (6)                      → [QuranTajweedRule.maddLazim]
///   * ghunnah (mushaddad / idgham letter) → [QuranTajweedRule.ghunnah]
///   * the unpronounced noon/tanween of    → [QuranTajweedRule.notPronounced]
///     idgham bighunnah and iqlab
///   * ikhfa                               → [QuranTajweedRule.ikhfa]
///   * qalqalah                            → [QuranTajweedRule.qalqalah]
///   * idgham bila ghunnah                 → [QuranTajweedRule.idghamBilaGhunnah]
///   * ikhfa shafawi                       → [QuranTajweedRule.ikhfaShafawi]
///
/// The madd classification and the two-part idgham/iqlab follow the Quran
/// Foundation tajweed engine (`quran/tajweed`, Quran.com): madd is split
/// by length and the noon/tanween of idgham bighunnah and iqlab is marked
/// as "not pronounced" (gray) while the merged letter keeps its color.
///
/// It intentionally skips izhar (clear pronunciation) and izhar shafawi,
/// which carry no color in the conventional colored mushaf. The algorithm
/// was validated against the app's bundled `assets/quran.db` text.
///
/// The same rule set is detected from the Warsh (Maghribi) QPC mushaf text
/// with no riwaya flag — the Warsh-only orthography is read straight off
/// the glyphs: the alif maqsura is written ے (U+06D2), the tanween as
/// ٗ / ٞ / ٖ (U+0657 / U+065E / U+0656), and the elided hamzat al-wasl as
/// اَ۬ (a vowel + U+06EC over a plain alef). Those code points never occur
/// in the Hafs bundle, so supporting them changes no Hafs behaviour.
///
/// Performance: results are memoized in a bounded LRU cache (results are
/// pure — a function of the input text only), and the hot loop operates on
/// integer code units to avoid per-character String allocations. This keeps
/// the analyzer cheap enough to run during widget builds.
library;

import 'quran_tajweed_rule.dart';

/// A contiguous run of an ayah assigned a single tajweed rule.
class TajweedMark {
  /// Start index in the ayah text (inclusive).
  final int start;

  /// End index in the ayah text (exclusive).
  final int end;

  /// The rule applied to `text[start..end]`.
  final QuranTajweedRule rule;

  const TajweedMark({
    required this.start,
    required this.end,
    required this.rule,
  });
}

abstract final class QuranTajweedAnalyzer {
  // ── Arabic orthography code units ──

  static const int _fatha = 0x064E;
  static const int _damma = 0x064F;
  static const int _kasra = 0x0650;
  static const int _shadda = 0x0651;
  static const int _sukun = 0x0652;
  static const int _tanweenFath = 0x064B;
  static const int _tanweenDam = 0x064C;
  static const int _tanweenKasr = 0x064D;
  static const int _maddah = 0x0653;
  static const int _daggerAlif = 0x0670;

  // Small high signs (U+06E1..U+06ED): sukun-like empty centre, iqlab
  // small-meem markers, small waw/yeh, etc. U+06E1 is treated as sukun.
  static const int _emptyCentreSukun = 0x06E1;
  static const int _smallMeemIsolated = 0x06E2;
  static const int _smallMeemLow = 0x06E3;
  static const int _smallMeemWaqfa = 0x06ED;

  static const int _alif = 0x0627;
  static const int _waslaAlef = 0x0671;
  static const int _baa = 0x0628;
  static const int _noon = 0x0646;
  static const int _meem = 0x0645;
  static const int _waw = 0x0648;
  static const int _alifMaqsura = 0x0649;
  static const int _yaa = 0x064A;

  // ── Warsh (Maghribi) orthography ──
  //   ے (U+06D2) — the alif maqsura / final ي in the Maghribi yeh-barree
  //     shape.
  //   ٗ (U+0657) — tanween fath written as an inverted damma.
  //   ٞ (U+065E) — tanween damm written as a fatha with two dots.
  //   ٖ (U+0656) — tanween kasr written as a subscript alif.
  //   ۬ (U+06EC) / ۪ (U+06EA) — the two small marks that write the
  //     hamzat al-wasl on a word-initial alef (اَ۬ / اِ۬ / اَ۪ / اِ۪);
  //     such a letter is elided in connected recitation. On non-alef
  //     letters ۪ is the waqf mark and carries no tajweed rule.
  //   ٕ (U+0655) — the hamza of a yeh seat written below (خَاطِـِٕينَ).
  //     It never directly follows a noon/tanween/meem-saakin and every
  //     maddah before it belongs to the madd-lazim word النَّبِيِّينَ,
  //     so it carries no tajweed rule of its own.
  static const int _alifMaqsuraWarsh = 0x06D2;
  static const int _waslaMark = 0x06EC;
  static const int _waslaMarkWarsh = 0x06EA;
  static const int _tanweenFathWarsh = 0x0657;
  static const int _tanweenDamWarsh = 0x065E;
  static const int _tanweenKasrWarsh = 0x0656;

  static const Set<int> _tanween = {
    _tanweenFath,
    _tanweenDam,
    _tanweenKasr,
    _tanweenFathWarsh,
    _tanweenDamWarsh,
    _tanweenKasrWarsh,
  };
  static const Set<int> _sukunMarks = {_sukun, _emptyCentreSukun};
  static const Set<int> _vowelMarks = {_fatha, _damma, _kasra};

  // ي ن م و — idgham with ghunnah
  static const Set<int> _idghamGhunnah = {_yaa, _noon, _meem, _waw};
  // ل ر — idgham without ghunnah
  static const Set<int> _idghamBila = {0x0644, 0x0631};
  // ت ث ج د ذ ز س ش ص ض ط ظ ف ق ك — ikhfa (the canonical 15 letters;
  // note د is ikhfa, while ح is an IZHAR letter and must not be here).
  static const Set<int> _ikhfa = {
    0x062A, 0x062B, 0x062C, 0x062F, 0x0630, 0x0632, 0x0633,
    0x0634, 0x0635, 0x0636, 0x0637, 0x0638, 0x0641, 0x0642,
    0x0643,
  };
  // ق ط ب ج د — qalqalah
  static const Set<int> _qalqalah = {0x0642, 0x0637, 0x0628, 0x062C, 0x062F};
  // ا ى ي و ے — the madd letters (ے is the Warsh alif maqsura).
  static const Set<int> _maddLetters = {
    _alif,
    _alifMaqsura,
    _yaa,
    _waw,
    _alifMaqsuraWarsh,
  };
  // ء أ ؤ إ ئ — the hamza letters that trigger muttasil/munfasil madd.
  static const Set<int> _hamzaLetters = {0x0621, 0x0623, 0x0624, 0x0625, 0x0626};

  /// Marks that attach to the preceding letter and are skipped while
  /// walking the text (short vowels, tanween, shadda, sukun, maddah,
  /// dagger alif, tatweel, and the small high signs).
  static const Set<int> _attachedMarks = {
    0x064B, 0x064C, 0x064D, 0x064E, 0x064F, 0x0650, 0x0651,
    0x0652, 0x0653, 0x0654, 0x0655, 0x0656, 0x0657, 0x065E,
    0x0670, 0x0640,
    0x06DF, 0x06E0, 0x06E1, 0x06E2, 0x06E3, 0x06E4, 0x06E5,
    0x06E6, 0x06E7, 0x06E8, 0x06EA, 0x06EB, 0x06EC, 0x06ED,
  };

  /// Bounded LRU cache of results, keyed by the ayah text. Results are
  /// pure and immutable, so reuse is safe. Capacity is sized so a typical
  /// reading session (a few pages in either orientation plus paging
  /// history) hits the cache while still bounding memory.
  static const int _cacheCapacity = 2048;
  static final Map<String, List<TajweedMark>> _cache = {};

  static List<TajweedMark> analyze(String text) {
    final cached = _cache[text];
    if (cached != null) {
      // Refresh LRU order.
      _cache.remove(text);
      _cache[text] = cached;
      return cached;
    }
    final result = _analyze(text);
    if (_cache.length >= _cacheCapacity) {
      _cache.remove(_cache.keys.first);
    }
    _cache[text] = result;
    return result;
  }

  static List<TajweedMark> _analyze(String text) {
    if (text.isEmpty) return const [];
    final n = text.length;
    final code = text.codeUnits;

    // 1. Tokenize into letters with their attached marks.
    final letters = <({int index, int ch, Set<int> marks, int end})>[];
    var i = 0;
    while (i < n) {
      final ch = code[i];
      if (_isArabicLetter(ch)) {
        final marks = <int>{};
        var j = i + 1;
        while (j < n && _attachedMarks.contains(code[j])) {
          marks.add(code[j]);
          j++;
        }
        letters.add((index: i, ch: ch, marks: marks, end: j));
        i = j;
      } else {
        i++;
      }
    }
    if (letters.isEmpty) return const [];

    // 2. Paint rules onto a per-index grid. Later paints win, so rules
    //    that involve a following letter (idgham/ikhfa/iqlab) override
    //    letter-local rules (qalqalah, madd) on shared letters.
    final ruleAt = List<QuranTajweedRule?>.filled(n, null);

    void paint(int start, int end, QuranTajweedRule rule) {
      for (var k = start; k < end && k < n; k++) {
        final c = code[k];
        if (c == 0x20 || c == 0x00A0) continue;
        if (c == _maddah || c == _daggerAlif) continue;
        ruleAt[k] = rule;
      }
    }

    // Pass A — letter-local rules.
    for (var idx = 0; idx < letters.length; idx++) {
      final L = letters[idx];
      final ch = L.ch;
      final marks = L.marks;

      // Madd tabee'i: a voweled letter followed by its matching madd
      // letter (ا / ى after fatha, ي after kasra, و after damma). The
      // Warsh ے is a madd letter after kasra (final ي) or fatha
      // (alif maqsura).
      final isMaddLetter = _maddLetters.contains(ch);
      if (isMaddLetter &&
          _isSilent(marks) &&
          !_isWaslaAlef(ch, marks) &&
          idx > 0) {
        final prev = letters[idx - 1];
        if (_hasVowel(prev.marks)) {
          // A madd letter belongs to the same word as its voweled letter.
          // A silent alef that opens a new word (Warsh drops the hamza of
          // أَمْوَال → اَمْوَال) is not a madd.
          var sameWord = true;
          for (var k = prev.end; k < L.index; k++) {
            if (code[k] == 0x20 || code[k] == 0x00A0 || code[k] == 0x200C) {
              sameWord = false;
              break;
            }
          }
          if (sameWord) {
            final vowel = _lastVowel(prev.marks);
            final isMadd = ch == _alif && vowel == _fatha ||
                ch == _alifMaqsura && vowel == _fatha ||
                ch == _alifMaqsuraWarsh &&
                    (vowel == _fatha || vowel == _kasra) ||
                ch == _yaa && vowel == _kasra ||
                ch == _waw && vowel == _damma;
            if (isMadd) paint(L.index, L.end, QuranTajweedRule.madd);
          }
        }
      }

      // Qalqalah: ق ط ب ج د carrying sukun, or the last letter of the
      // ayah (qalqalah kubra, any vowel). Mushaddad letters are
      // assimilation, not qalqalah. "Last letter of the ayah" means no
      // further Arabic letter follows — trailing short-vowel marks, waqf
      // signs (ۖ etc.) and other annotations are all treated as the end.
      var isAyahFinal = true;
      for (var k = L.end; k < n; k++) {
        final c = code[k];
        if (_isArabicLetter(c)) {
          isAyahFinal = false;
          break;
        }
      }
      if (_qalqalah.contains(ch) &&
          (marks.any(_sukunMarks.contains) || isAyahFinal)) {
        paint(L.index, L.end, QuranTajweedRule.qalqalah);
      }

      // Ghunnah: mushaddad noon / meem (نّ / مّ).
      if ((ch == _noon || ch == _meem) && marks.contains(_shadda)) {
        paint(L.index, L.end, QuranTajweedRule.ghunnah);
      }

      // Iqlab indicated by the small-meem signs (U+06E2 / U+06E3 / U+06ED).
      // At the end of the ayah the sign is a tanween-at-stop notation, not
      // an iqlab, so a qalqalah kubra letter keeps its own color.
      if (!isAyahFinal &&
          (marks.contains(_smallMeemIsolated) ||
              marks.contains(_smallMeemLow) ||
              marks.contains(_smallMeemWaqfa))) {
        paint(L.index, L.end, QuranTajweedRule.ghunnah);
      }

      // Madd sila sughra — the heh of هُ / هِ before a voweled letter is
      // written with a small waw (ۥ) or small yeh (ۦ) when it carries the
      // 2-count connected elongation.
      if (ch == 0x0647 && (marks.contains(0x06E5) || marks.contains(0x06E6))) {
        paint(L.index, L.end, QuranTajweedRule.maddSilaSughra);
      }

      // Maddah (ٓ) marks a non-natural madd. Classified after qalqalah /
      // ghunnah so the explicit-madd type wins over letter-local rules:
      //   * before a hamza in the same word  → wajib muttasil (4–5)
      //   * before a hamza opening the next word → ja'iz munfasil (4)
      //   * before a mushaddad letter, or on a huruf al-muqatta'at letter
      //     (الٓمٓ)                          → lazim (6)
      // Dagger alif (ٰ) alone is natural madd: on a madd letter the letter
      // is painted; on other letters only the sign (plus an adjacent
      // tatweel) is colored, so ghunnah/ikhfa keep the letter and both
      // rules can be shown together (e.g. the dagger of جَنَّـٰتٍ).
      final hasMaddah = marks.contains(_maddah);
      final hasDagger = marks.contains(_daggerAlif);
      if (hasMaddah) {
        // Next real letter, skipping silent support alifs (وٓا۟), wasla
        // alefs (ٱ and the Warsh اَ۬), and noting whether a word boundary
        // was crossed.
        var crossedSpace = false;
        var nextIdx = idx + 1;
        while (nextIdx < letters.length) {
          final nxt = letters[nextIdx];
          if (_isWaslaAlef(nxt.ch, nxt.marks)) {
            nextIdx++;
            continue;
          }
          if ((nxt.ch == _alif ||
                  nxt.ch == _alifMaqsura ||
                  nxt.ch == _alifMaqsuraWarsh) &&
              _isSilent(nxt.marks)) {
            nextIdx++;
            continue;
          }
          break;
        }
        if (nextIdx < letters.length) {
          for (var m = L.end; m < letters[nextIdx].index; m++) {
            final c = code[m];
            if (c == 0x20 || c == 0x00A0 || c == 0x200C || c == 0x06E9) {
              crossedSpace = true;
              break;
            }
          }
        }
        var rule = QuranTajweedRule.maddLazim;
        if (nextIdx < letters.length) {
          final nxt = letters[nextIdx];
          if (_hamzaLetters.contains(nxt.ch)) {
            rule =
                crossedSpace ? QuranTajweedRule.maddJaiz : QuranTajweedRule.maddWajib;
          } else if (nxt.marks.contains(_shadda)) {
            rule = QuranTajweedRule.maddLazim;
          }
        }
        paint(L.index, L.end, rule);
      } else if (hasDagger) {
        if (isMaddLetter && _isSilent(marks) && !_isWaslaAlef(ch, marks)) {
          paint(L.index, L.end, QuranTajweedRule.madd);
        }
        for (var k = L.index; k < L.end && k < n; k++) {
          if (code[k] == _daggerAlif) {
            final s = k > L.index && code[k - 1] == 0x0640 ? k - 1 : k;
            for (var m = s; m <= k; m++) {
              ruleAt[m] = QuranTajweedRule.madd;
            }
          }
        }
      }
    }

    // Pass B — rules that depend on the following letter. A letter claimed
    // as an idgham-bighunnah target (ي ن م و) must not then be re-processed
    // as a noon/meem-saakinah source: the idgham has already assimilated it
    // into a mushaddad nasal (e.g. فِتْنَةٌ ٱنقَلَبَ → the silent noon of
    // ٱنقَلَبَ is the idgham target, so it must not also trigger ikhfa on
    // the following ق).
    final claimedTargets = <int>{};
    for (var idx = 0; idx < letters.length; idx++) {
      if (claimedTargets.contains(idx)) continue;
      final L = letters[idx];
      final ch = L.ch;
      final marks = L.marks;

      // Warsh writes a tanween with the small-meem sign (ۢ, U+06E2): the
      // fath on a support alef (شَهِيدًا → شَهِيداَۢ) or the damm/kasr on
      // the consonant (أَلِيمٌ → اَلِيمُۢ). On a consonant with no vowel
      // the same sign marks the iqlab of a saakinah noon (مِنْ → مِنۢ),
      // which the noon-saakinah test below already covers.
      final hasSmallMeem = marks.contains(_smallMeemIsolated);
      final isTanweenFath =
          marks.contains(_tanweenFath) ||
          marks.contains(_tanweenFathWarsh) ||
          (ch == _alif && marks.contains(_fatha) && hasSmallMeem);
      final isTanween = marks.any(_tanween.contains) ||
          (hasSmallMeem && marks.any(_vowelMarks.contains));
      final isNoonSaakin =
          ch == _noon && (marks.any(_sukunMarks.contains) || _isSilent(marks));
      final isMeemSaakin =
          ch == _meem && (marks.any(_sukunMarks.contains) || _isSilent(marks));

      // Find the next real letter. Tanween-fath is written with a silent
      // support alif (ا / ى / ے) that is not the letter the rule applies
      // to (e.g. هُدًى مِّن → the tanween meets م, not the ى). A wasla
      // alef (ٱ, or the Warsh اَ۬ written with U+06EC) is likewise elided
      // in connected recitation (e.g. خَيْرًا ٱلْوَصِيَّةُ → the tanween
      // meets ل, not ٱ).
      var k = idx + 1;
      var skipSupport = isTanweenFath;
      while (k < letters.length) {
        final next = letters[k];
        if (_isWaslaAlef(next.ch, next.marks)) {
          k++;
          continue;
        }
        if (skipSupport &&
            (next.ch == _alif ||
                next.ch == _alifMaqsura ||
                next.ch == _alifMaqsuraWarsh) &&
            _isSilent(next.marks)) {
          skipSupport = false;
          k++;
          continue;
        }
        break;
      }
      if (k >= letters.length) continue;
      final next = letters[k];
      final nextCh = next.ch;

      // A word-initial saakin qalqalah letter (reached only through an
      // elided hamzat-wasl, e.g. عُزَيْرٌ ٱبْنُ) keeps its qalqalah
      // instead of receiving the preceding noon/tanween rule.
      if (_qalqalah.contains(nextCh) && next.marks.any(_sukunMarks.contains)) {
        continue;
      }

      if (isNoonSaakin || isTanween) {
        if (_idghamGhunnah.contains(nextCh)) {
          // Two-part (Quran Foundation): the noon/tanween is not
          // pronounced (gray); the merged letter carries the ghunnah.
          paint(L.index, L.end, QuranTajweedRule.notPronounced);
          paint(next.index, next.end, QuranTajweedRule.ghunnah);
          claimedTargets.add(k);
        } else if (_idghamBila.contains(nextCh)) {
          paint(L.index, next.end, QuranTajweedRule.idghamBilaGhunnah);
        } else if (nextCh == _baa) {
          // Iqlab — two-part: the noon/tanween converts to a nasal meem
          // (gray); the following ب is marked.
          paint(L.index, L.end, QuranTajweedRule.notPronounced);
          paint(next.index, next.end, QuranTajweedRule.iqlab);
        } else if (_ikhfa.contains(nextCh)) {
          paint(L.index, next.end, QuranTajweedRule.ikhfa);
        }
        // Izhar letters (ء ه ع ح غ خ) — no color.
      } else if (isMeemSaakin) {
        if (nextCh == _meem) {
          // Idgham shafawi — madd with ghunnah.
          paint(L.index, next.end, QuranTajweedRule.ghunnah);
        } else if (nextCh == _baa) {
          paint(L.index, next.end, QuranTajweedRule.ikhfaShafawi);
        }
        // Izhar shafawi — no color.
      }
    }

    // 3. Collapse contiguous same-rule indices into TajweedMarks.
    final marks = <TajweedMark>[];
    var p = 0;
    while (p < n) {
      final rule = ruleAt[p];
      if (rule == null) {
        p++;
        continue;
      }
      var q = p + 1;
      while (q < n && ruleAt[q] == rule) {
        q++;
      }
      marks.add(TajweedMark(start: p, end: q, rule: rule));
      p = q;
    }
    return marks;
  }

  static bool _isArabicLetter(int code) {
    return (code >= 0x0621 && code <= 0x063A) ||
        (code >= 0x0641 && code <= 0x064A) ||
        code == _waslaAlef ||
        code == _alifMaqsuraWarsh ||
        code == 0x06FB ||
        code == 0x06FD;
  }

  /// True when the letter carries none of vowel / sukun / tanween / shadda
  /// — i.e. an orthographically "silent" letter that stands for a saakinah
  /// in idgham/ikhfa contexts where Uthmani script omits the sukun sign.
  static bool _isSilent(Set<int> marks) {
    return !marks.any(
      (c) =>
          _vowelMarks.contains(c) ||
          _sukunMarks.contains(c) ||
          _tanween.contains(c) ||
          c == _shadda,
    );
  }

  static bool _hasVowel(Set<int> marks) => marks.any(_vowelMarks.contains);

  static int? _lastVowel(Set<int> marks) {
    int? result;
    for (final c in marks) {
      if (_vowelMarks.contains(c)) result = c;
    }
    return result;
  }

  /// True for a word-initial alef that writes the elided hamzat al-wasl:
  /// the Hafs wasla alef (ٱ), the Warsh rounded mark (اَ۬, U+06EC), or the
  /// Warsh empty-centre mark (اَ۪ / اِ۪, U+06EA). On non-alef letters the
  /// latter is the waqf mark and is not elided.
  static bool _isWaslaAlef(int ch, Set<int> marks) {
    return ch == _waslaAlef ||
        marks.contains(_waslaMark) ||
        (ch == _alif && marks.contains(_waslaMarkWarsh));
  }
}
