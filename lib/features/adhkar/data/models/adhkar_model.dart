/// JSON model for Adhkar catalog items.
library;

import '../../domain/entities/adhkar_entities.dart';

class AdhkarItemModel extends AdhkarItem {
  const AdhkarItemModel({
    super.id,
    required super.category,
    super.categoryEn,
    super.categoryAr,
    super.segment,
    super.order,
    required super.arabic,
    super.transliteration,
    super.translation,
    super.reference,
    super.book,
    super.hadithNumber,
    super.authenticity,
    super.narrator,
    super.benefits,
    super.benefitsAr,
    super.count,
    super.search,
  });

  factory AdhkarItemModel.fromJson(Map<String, dynamic> json) {
    // Support both the new catalog schema and the legacy azkar-db shape.
    final arabic = (json['arabic'] as String?) ??
        (json['zekr'] as String?) ??
        '';
    final benefits = (json['benefits'] as String?) ??
        (json['description'] as String?) ??
        '';
    final benefitsAr = json['benefitsAr'] as String? ?? '';
    final transliteration = (json['transliteration'] as String?) ??
        (json['latin'] as String?) ??
        '';
    final translation = json['translation'] as String? ?? '';
    final category = json['category'] as String? ?? '';
    final categoryEn = json['categoryEn'] as String? ?? '';
    final categoryAr = json['categoryAr'] as String? ?? '';
    final reference = (json['reference'] as String?) ??
        (json['source'] as String?) ??
        '';
    final searchBlob = json['search'] as String? ??
        [
          category,
          categoryEn,
          categoryAr,
          arabic,
          transliteration,
          translation,
          reference,
          benefits,
          benefitsAr,
        ].where((s) => s.trim().isNotEmpty).join(' ');

    final rawCount = json['count'];
    final count = rawCount is int
        ? rawCount
        : int.tryParse(rawCount?.toString() ?? '') ?? 1;

    final rawId = json['id'];
    final id = rawId is int
        ? rawId
        : int.tryParse(rawId?.toString() ?? '');

    return AdhkarItemModel(
      id: id,
      category: category,
      categoryEn: categoryEn,
      categoryAr: categoryAr,
      segment: json['segment'] as String? ?? '',
      order: (json['order'] is int)
          ? json['order'] as int
          : int.tryParse(json['order']?.toString() ?? '') ?? 0,
      arabic: arabic,
      transliteration: transliteration,
      translation: translation,
      reference: reference,
      book: json['book'] as String? ?? '',
      hadithNumber: (json['hadithNumber'] as String?) ??
          (json['hadith_number'] as String?) ??
          '',
      authenticity: json['authenticity'] as String? ?? '',
      narrator: json['narrator'] as String? ?? '',
      benefits: benefits,
      benefitsAr: benefitsAr,
      count: count < 1 ? 1 : count,
      search: searchBlob,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'category': category,
        'categoryEn': categoryEn,
        'categoryAr': categoryAr,
        'segment': segment,
        'order': order,
        'arabic': arabic,
        'transliteration': transliteration,
        'translation': translation,
        'reference': reference,
        'book': book,
        'hadithNumber': hadithNumber,
        'authenticity': authenticity,
        'narrator': narrator,
        'benefits': benefits,
        'benefitsAr': benefitsAr,
        'count': count,
        'search': search,
      };
}
