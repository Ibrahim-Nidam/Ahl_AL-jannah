class QuranHistoryItem {
  final int surahId;
  final String surahNameEn;
  final String surahNameAr;
  final int page;
  final DateTime updatedAt;

  const QuranHistoryItem({
    required this.surahId,
    required this.surahNameEn,
    required this.surahNameAr,
    required this.page,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'surahId': surahId,
        'surahNameEn': surahNameEn,
        'surahNameAr': surahNameAr,
        'page': page,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory QuranHistoryItem.fromJson(Map<String, dynamic> json) =>
      QuranHistoryItem(
        surahId: json['surahId'] as int,
        surahNameEn: json['surahNameEn'] as String? ?? '',
        surahNameAr: json['surahNameAr'] as String? ?? '',
        page: json['page'] as int,
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.now(),
      );
}
