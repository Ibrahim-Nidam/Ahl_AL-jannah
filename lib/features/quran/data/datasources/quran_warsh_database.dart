import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// A single Warsh-riwaya ayah row from `assets/quran_warsh.db`.
///
/// Mirrors the shape of the Hafs [Ayah] drift rows (minus translations,
/// which the Warsh bundle does not ship) so the reader can treat both
/// riwayat identically.
class WarshAyahRow {
  final int id;
  final int surahId;
  final int number;
  final String textAr;
  final int juz;
  final int page;
  final int hizb;

  const WarshAyahRow({
    required this.id,
    required this.surahId,
    required this.number,
    required this.textAr,
    required this.juz,
    required this.page,
    required this.hizb,
  });
}

/// Read-only access to the bundled Warsh Quran database.
///
/// Warsh lives in its own `assets/quran_warsh.db` (copied to the app
/// documents directory on first use, exactly like `quran.db`) so the Hafs
/// drift schema and its bundled asset never have to change. Queries run on
/// the same background-executor model the Hafs database uses.
@singleton
class WarshQuranDatabase {
  static final QueryExecutorUser _openUser = _WarshExecutorUser();

  final DatabaseOpener? _customOpener;
  QueryExecutor? _executor;

  @visibleForTesting
  WarshQuranDatabase.forTesting(QueryExecutor executor)
    : _customOpener = null,
      _executor = executor;

  /// Creates the database. [opener] is only used by tests to supply a
  /// database file without going through path_provider / rootBundle.
  @visibleForTesting
  WarshQuranDatabase.withOpener(DatabaseOpener opener) : _customOpener = opener;

  WarshQuranDatabase() : _customOpener = null;

  QueryExecutor get _connection => _executor ??= _open();

  QueryExecutor _open() {
    final opener = _customOpener ?? _bundleOpener;
    return LazyDatabase(opener);
  }

  Future<QueryExecutor> _bundleOpener() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'quran_warsh.db'));

    if (!await file.exists()) {
      try {
        final data = await rootBundle.load('assets/quran_warsh.db');
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        await file.writeAsBytes(bytes);
      } catch (e) {
        debugPrint('Error copying Warsh database: $e');
      }
    }

    return NativeDatabase.createInBackground(file);
  }

  Future<List<WarshAyahRow>> getAyahsByPage(int page) {
    return _run('WHERE page = ? ORDER BY surah_id, number', [page]);
  }

  /// Every ayah in reading order. Used by tests and whole-Quran audits.
  Future<List<WarshAyahRow>> getAllAyahs() {
    return _run('ORDER BY surah_id, number', const []);
  }

  /// Per-surah ayah counts for the Warsh edition. The counts differ from
  /// Hafs in many surahs, so they cannot be taken from the Hafs surah
  /// table when reading Warsh.
  Future<Map<int, int>> getSurahAyahCounts() async {
    await _connection.ensureOpen(_openUser);
    final rows = await _connection.runSelect(
      'SELECT surah_id, COUNT(*) AS cnt FROM warsh_ayahs GROUP BY surah_id',
      const [],
    );
    return {for (final row in rows) row['surah_id'] as int: row['cnt'] as int};
  }

  Future<List<WarshAyahRow>> getAyahsBySurah(int surahId) {
    return _run('WHERE surah_id = ? ORDER BY number', [surahId]);
  }

  Future<List<WarshAyahRow>> getAyahsByJuz(int juz) {
    return _run('WHERE juz = ? ORDER BY surah_id, number', [juz]);
  }

  /// Releases the underlying executor. Safe to call before the database was
  /// ever opened (the lazy opener is never invoked in that case).
  Future<void> close() async {
    await _executor?.close();
    _executor = null;
  }

  Future<List<WarshAyahRow>> _run(String where, List<Object?> args) async {
    // LazyDatabase does NOT open itself when runSelect is called — it reads
    // its `late final _delegate` directly, so a first query on an unopened
    // database throws `LateInitializationError: Field '_delegate …' has not
    // been initialized`. Open explicitly before every query batch (drift's
    // generated databases do this automatically; a bare QueryExecutor does
    // not). ensureOpen is idempotent.
    await _connection.ensureOpen(_openUser);
    final rows = await _connection.runSelect(
      'SELECT id, surah_id, number, text_ar, juz, page, hizb '
      'FROM warsh_ayahs $where',
      args,
    );
    return rows.map((row) {
      return WarshAyahRow(
        id: row['id'] as int,
        surahId: row['surah_id'] as int,
        number: row['number'] as int,
        textAr: row['text_ar'] as String,
        juz: row['juz'] as int,
        page: row['page'] as int,
        hizb: row['hizb'] as int,
      );
    }).toList();
  }
}

/// Minimal [QueryExecutorUser] for the raw Warsh executor. The Warsh
/// database is a fully built, read-only file so no schema migration is
/// needed.
class _WarshExecutorUser implements QueryExecutorUser {
  @override
  int get schemaVersion => 1;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {
    // No migrations — the bundled database is already in its final schema.
  }
}
