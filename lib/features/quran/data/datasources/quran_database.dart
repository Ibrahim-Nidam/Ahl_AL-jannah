import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:injectable/injectable.dart';
import 'package:sqlite3/sqlite3.dart' show AllowedArgumentCount;

part 'quran_database.g.dart';

@DataClassName('Surah')
class Surahs extends Table {
  IntColumn get id => integer()();
  TextColumn get nameAr => text().named('name_ar')();
  TextColumn get nameEn => text().named('name_en')();
  TextColumn get revelation => text()();
  IntColumn get ayahCount => integer().named('ayah_count')();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Ayah')
class Ayahs extends Table {
  IntColumn get id => integer()();
  IntColumn get surahId => integer().named('surah_id').references(Surahs, #id)();
  IntColumn get number => integer()();
  TextColumn get textAr => text().named('text_ar')();
  TextColumn get translationEn => text().named('translation_en').nullable()();
  TextColumn get translationFr => text().named('translation_fr').nullable()();
  IntColumn get juz => integer()();
  IntColumn get page => integer()();
  IntColumn get hizb => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@singleton
@DriftDatabase(tables: [Surahs, Ayahs])
class QuranDatabase extends _$QuranDatabase {
  QuranDatabase() : super(_openConnection());

  @visibleForTesting
  QuranDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;
}

QueryExecutor _openConnection() {
  return LazyDatabase(() async {
    // Get application documents directory
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'quran.db'));

    // Check if db file already exists. If not, copy from assets.
    if (!await file.exists()) {
      try {
        final data = await rootBundle.load('assets/quran.db');
        final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await file.writeAsBytes(bytes);
      } catch (e) {
        // Fallback or error logging
        debugPrint("Error copying Quran database: $e");
      }
    }

    return NativeDatabase.createInBackground(
      file,
      setup: (db) {
        db.createFunction(
          functionName: 'remove_diacritics',
          argumentCount: const AllowedArgumentCount(1),
          function: (args) {
            final text = args.first as String?;
            if (text == null) return null;
            return _removeDiacritics(text);
          },
        );
      },
    );
  });
}

String _removeDiacritics(String text) {
  var normalized = text.replaceAll(RegExp(r'[\u064B-\u0652\u0670\u0640\u0653-\u0655\u06DF-\u06E8\u06EA-\u06EC]'), '');
  normalized = normalized.replaceAll(RegExp(r'[أإآٱ]'), 'ا');
  normalized = normalized.replaceAll('ة', 'ه');
  return normalized;
}

