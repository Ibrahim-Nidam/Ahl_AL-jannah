class SurahEntity {
  final int id;
  final String nameAr;
  final String nameEn;
  final String revelation;
  final int ayahCount;

  const SurahEntity({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.revelation,
    required this.ayahCount,
  });
}

class AyahEntity {
  final int id;
  final int surahId;
  final int number;
  final String textAr;
  final String? translationEn;
  final String? translationFr;
  final int juz;
  final int page;
  final int hizb;

  const AyahEntity({
    required this.id,
    required this.surahId,
    required this.number,
    required this.textAr,
    this.translationEn,
    this.translationFr,
    required this.juz,
    required this.page,
    required this.hizb,
  });
}
