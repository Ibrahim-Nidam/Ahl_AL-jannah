/// The tajweed rules detected and colorized by [QuranTajweedAnalyzer].
///
/// These are the core recitation rules that can be inferred from the
/// fully-voweled Uthmani text. Colors are applied in the presentation
/// layer (see [TajweedColors] in `core/theme/app_colors.dart`) so this
/// domain enum stays Flutter-free.
///
/// The madd subtyping and the two-part idgham/iqlab follow the scheme of
/// the Quran Foundation tajweed engine (`quran/tajweed`, used by
/// Quran.com): madd is split by length (sila sughra 2, tabee'i 2, jaiz 4,
/// wajib 4–5, lazim 6) and the noon/tanween of idgham bighunnah and iqlab
/// is marked as "not pronounced" while the merged letter carries the
/// color.
library;

enum QuranTajweedRule {
  /// Madd tabee'i — the natural 2-count elongation of the madd letters
  /// (ا / و / ي / ى) after their matching vowel, plus the dagger-alif
  /// (ٰ) signs.
  madd,

  /// Madd wajib muttasil — 4/5-count elongation of a maddah-marked madd
  /// letter directly before a hamza in the same word (e.g. سَآءَ).
  maddWajib,

  /// Madd ja'iz munfasil — 4-count elongation of a word-final maddah-
  /// marked madd letter before a hamza opening the next word (e.g.
  /// وَمَآ أُنزِلَ).
  maddJaiz,

  /// Madd lazim — 6-count elongation: a maddah-marked letter before a
  /// mushaddad letter, or the maddah-marked letters of the huruf
  /// al-muqatta'at (e.g. الٓمٓ, الضَّآلِّينَ).
  maddLazim,

  /// Madd sila sughra — 2-count elongation of the heh of هُ / هِ before a
  /// voweled letter, written with a small waw (ۥ) or small yeh (ۦ).
  maddSilaSughra,

  /// Ghunnah — nasalization: mushaddad noon/meem, the merged letter of
  /// idgham bighunnah (ي ن م و), and idgham shafawi (م + م).
  ghunnah,

  /// Ikhfa — concealment of noon saakinah / tanween before the 15 ikhfa
  /// letters (ت ث ج د ذ ز س ش ص ض ط ظ ف ق ك).
  ikhfa,

  /// Qalqalah — the echoing letters ق ط ب ج د when saakinah or at the end
  /// of the ayah.
  qalqalah,

  /// Idgham bila ghunnah — merging noon saakinah / tanween into ل ر
  /// without nasalization.
  idghamBilaGhunnah,

  /// Ikhfa shafawi — concealment of meem saakinah before ب.
  ikhfaShafawi,

  /// Iqlab — the ب that follows a converted noon/tanween (recited as a
  /// nasal meem); the noon/tanween itself is painted [notPronounced].
  iqlab,

  /// The noon/tanween that is not pronounced in idgham bighunnah and
  /// iqlab, shown in the Foundation "not pronounced" gray.
  notPronounced,
}
