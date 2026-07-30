// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;

import '../../features/adhkar/data/datasources/adhkar_local_data_source.dart'
    as _i793;
import '../../features/adhkar/data/repositories/adhkar_repository_impl.dart'
    as _i537;
import '../../features/adhkar/domain/repositories/adhkar_repository.dart'
    as _i203;
import '../../features/adhkar/domain/usecases/adhkar_usecases.dart' as _i46;
import '../../features/adhkar/presentation/bloc/adhkar_cubit.dart' as _i171;
import '../../features/adhkar/presentation/bloc/tasbeeh_cubit.dart' as _i1057;
import '../../features/hadith/data/datasources/hadith_local_data_source.dart'
    as _i113;
import '../../features/hadith/data/repositories/hadith_repository_impl.dart'
    as _i570;
import '../../features/hadith/domain/repositories/hadith_repository.dart'
    as _i1050;
import '../../features/hadith/domain/usecases/hadith_usecases.dart' as _i664;
import '../../features/hadith/presentation/bloc/hadith_cubit.dart' as _i354;
import '../../features/prayer/data/repositories/adhan_audio_player.dart'
    as _i386;
import '../../features/prayer/data/repositories/prayer_notification_service.dart'
    as _i894;
import '../../features/prayer/data/repositories/prayer_repository_impl.dart'
    as _i251;
import '../../features/prayer/domain/repositories/prayer_repository.dart'
    as _i902;
import '../../features/prayer/domain/usecases/prayer_usecases.dart' as _i91;
import '../../features/prayer/presentation/bloc/prayer_cubit.dart' as _i762;
import '../../features/qibla/domain/usecases/qibla_usecases.dart' as _i722;
import '../../features/qibla/presentation/bloc/qibla_cubit.dart' as _i534;
import '../../features/quran/data/datasources/quran_database.dart' as _i900;
import '../../features/quran/data/datasources/quran_local_data_source.dart'
    as _i380;
import '../../features/quran/data/repositories/quran_repository_impl.dart'
    as _i82;
import '../../features/quran/domain/repositories/quran_repository.dart'
    as _i498;
import '../../features/quran/domain/usecases/quran_usecases.dart' as _i34;
import '../../features/quran/presentation/cubit/quran_cubit.dart' as _i431;
import '../../features/settings/data/datasources/settings_local_data_source.dart'
    as _i599;
import '../../features/settings/data/repositories/settings_repository_impl.dart'
    as _i955;
import '../../features/settings/domain/repositories/settings_repository.dart'
    as _i674;
import '../../features/settings/domain/usecases/settings_usecases.dart'
    as _i279;
import '../../features/settings/presentation/bloc/settings_cubit.dart' as _i819;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    gh.singleton<_i386.AdhanAudioPlayer>(() => _i386.AdhanAudioPlayer());
    gh.singleton<_i894.PrayerNotificationService>(
      () => _i894.PrayerNotificationService(),
    );
    gh.singleton<_i900.QuranDatabase>(() => _i900.QuranDatabase());
    gh.lazySingleton<_i722.CalculateQiblaBearingUseCase>(
      () => const _i722.CalculateQiblaBearingUseCase(),
    );
    gh.lazySingleton<_i599.SettingsLocalDataSource>(
      () => _i599.SettingsLocalDataSourceImpl(),
    );
    gh.lazySingleton<_i674.SettingsRepository>(
      () => _i955.SettingsRepositoryImpl(gh<_i599.SettingsLocalDataSource>()),
    );
    gh.lazySingleton<_i793.AdhkarLocalDataSource>(
      () => _i793.AdhkarLocalDataSourceImpl(),
    );
    gh.lazySingleton<_i113.HadithLocalDataSource>(
      () => _i113.HadithLocalDataSourceImpl(),
    );
    gh.lazySingleton<_i902.PrayerRepository>(
      () => _i251.PrayerRepositoryImpl(),
    );
    gh.lazySingleton<_i91.CalculatePrayerTimesUseCase>(
      () => _i91.CalculatePrayerTimesUseCase(gh<_i902.PrayerRepository>()),
    );
    gh.lazySingleton<_i91.GetPrayerSettingsUseCase>(
      () => _i91.GetPrayerSettingsUseCase(gh<_i902.PrayerRepository>()),
    );
    gh.lazySingleton<_i91.SavePrayerSettingsUseCase>(
      () => _i91.SavePrayerSettingsUseCase(gh<_i902.PrayerRepository>()),
    );
    gh.lazySingleton<_i91.GetUserLocationUseCase>(
      () => _i91.GetUserLocationUseCase(gh<_i902.PrayerRepository>()),
    );
    gh.lazySingleton<_i1050.HadithRepository>(
      () => _i570.HadithRepositoryImpl(gh<_i113.HadithLocalDataSource>()),
    );
    gh.lazySingleton<_i380.QuranLocalDataSource>(
      () => _i380.QuranLocalDataSourceImpl(gh<_i900.QuranDatabase>()),
    );
    gh.lazySingleton<_i534.QiblaCubit>(
      () => _i534.QiblaCubit(
        gh<_i91.GetUserLocationUseCase>(),
        gh<_i722.CalculateQiblaBearingUseCase>(),
      ),
    );
    gh.lazySingleton<_i279.GetSettingsUseCase>(
      () => _i279.GetSettingsUseCase(gh<_i674.SettingsRepository>()),
    );
    gh.lazySingleton<_i279.SaveSettingsUseCase>(
      () => _i279.SaveSettingsUseCase(gh<_i674.SettingsRepository>()),
    );
    gh.lazySingleton<_i279.ResetSettingsUseCase>(
      () => _i279.ResetSettingsUseCase(gh<_i674.SettingsRepository>()),
    );
    gh.lazySingleton<_i498.QuranRepository>(
      () => _i82.QuranRepositoryImpl(gh<_i380.QuranLocalDataSource>()),
    );
    gh.lazySingleton<_i34.GetSurahsUseCase>(
      () => _i34.GetSurahsUseCase(gh<_i498.QuranRepository>()),
    );
    gh.lazySingleton<_i34.GetAyahsBySurahUseCase>(
      () => _i34.GetAyahsBySurahUseCase(gh<_i498.QuranRepository>()),
    );
    gh.lazySingleton<_i34.SearchQuranUseCase>(
      () => _i34.SearchQuranUseCase(gh<_i498.QuranRepository>()),
    );
    gh.lazySingleton<_i34.GetAyahsByJuzUseCase>(
      () => _i34.GetAyahsByJuzUseCase(gh<_i498.QuranRepository>()),
    );
    gh.lazySingleton<_i34.GetAyahsByPageUseCase>(
      () => _i34.GetAyahsByPageUseCase(gh<_i498.QuranRepository>()),
    );
    gh.lazySingleton<_i203.AdhkarRepository>(
      () => _i537.AdhkarRepositoryImpl(gh<_i793.AdhkarLocalDataSource>()),
    );
    gh.factory<_i664.GetHadithCollections>(
      () => _i664.GetHadithCollections(gh<_i1050.HadithRepository>()),
    );
    gh.factory<_i664.GetHadithsByCollection>(
      () => _i664.GetHadithsByCollection(gh<_i1050.HadithRepository>()),
    );
    gh.factory<_i664.SearchHadith>(
      () => _i664.SearchHadith(gh<_i1050.HadithRepository>()),
    );
    gh.lazySingleton<_i819.SettingsCubit>(
      () => _i819.SettingsCubit(
        gh<_i279.GetSettingsUseCase>(),
        gh<_i279.SaveSettingsUseCase>(),
        gh<_i279.ResetSettingsUseCase>(),
      ),
    );
    gh.lazySingleton<_i762.PrayerCubit>(
      () => _i762.PrayerCubit(
        gh<_i91.GetUserLocationUseCase>(),
        gh<_i91.GetPrayerSettingsUseCase>(),
        gh<_i91.SavePrayerSettingsUseCase>(),
        gh<_i91.CalculatePrayerTimesUseCase>(),
        gh<_i894.PrayerNotificationService>(),
        gh<_i279.GetSettingsUseCase>(),
      ),
    );
    gh.lazySingleton<_i431.QuranCubit>(
      () => _i431.QuranCubit(
        gh<_i34.GetSurahsUseCase>(),
        gh<_i34.GetAyahsBySurahUseCase>(),
        gh<_i34.SearchQuranUseCase>(),
        gh<_i34.GetAyahsByJuzUseCase>(),
        gh<_i34.GetAyahsByPageUseCase>(),
      ),
    );
    gh.lazySingleton<_i46.GetAdhkarCategoriesUseCase>(
      () => _i46.GetAdhkarCategoriesUseCase(gh<_i203.AdhkarRepository>()),
    );
    gh.lazySingleton<_i46.GetAdhkarByCategoryUseCase>(
      () => _i46.GetAdhkarByCategoryUseCase(gh<_i203.AdhkarRepository>()),
    );
    gh.lazySingleton<_i46.SearchAdhkarUseCase>(
      () => _i46.SearchAdhkarUseCase(gh<_i203.AdhkarRepository>()),
    );
    gh.lazySingleton<_i46.ToggleFavoriteAdhkarUseCase>(
      () => _i46.ToggleFavoriteAdhkarUseCase(gh<_i203.AdhkarRepository>()),
    );
    gh.lazySingleton<_i46.GetFavoriteKeysUseCase>(
      () => _i46.GetFavoriteKeysUseCase(gh<_i203.AdhkarRepository>()),
    );
    gh.lazySingleton<_i46.GetAdhkarSettingsUseCase>(
      () => _i46.GetAdhkarSettingsUseCase(gh<_i203.AdhkarRepository>()),
    );
    gh.lazySingleton<_i46.SaveAdhkarSettingsUseCase>(
      () => _i46.SaveAdhkarSettingsUseCase(gh<_i203.AdhkarRepository>()),
    );
    gh.lazySingleton<_i46.GetTasbeehStatsUseCase>(
      () => _i46.GetTasbeehStatsUseCase(gh<_i203.AdhkarRepository>()),
    );
    gh.lazySingleton<_i46.RecordTasbeehProgressUseCase>(
      () => _i46.RecordTasbeehProgressUseCase(gh<_i203.AdhkarRepository>()),
    );
    gh.lazySingleton<_i46.ClearTasbeehStatsDayUseCase>(
      () => _i46.ClearTasbeehStatsDayUseCase(gh<_i203.AdhkarRepository>()),
    );
    gh.lazySingleton<_i46.ClearAllTasbeehStatsUseCase>(
      () => _i46.ClearAllTasbeehStatsUseCase(gh<_i203.AdhkarRepository>()),
    );
    gh.lazySingleton<_i46.GetSavedTasbeehSessionUseCase>(
      () => _i46.GetSavedTasbeehSessionUseCase(gh<_i203.AdhkarRepository>()),
    );
    gh.lazySingleton<_i46.SaveTasbeehSessionUseCase>(
      () => _i46.SaveTasbeehSessionUseCase(gh<_i203.AdhkarRepository>()),
    );
    gh.lazySingleton<_i46.GetTasbeehCollectionUseCase>(
      () => _i46.GetTasbeehCollectionUseCase(gh<_i203.AdhkarRepository>()),
    );
    gh.lazySingleton<_i46.SaveTasbeehCollectionUseCase>(
      () => _i46.SaveTasbeehCollectionUseCase(gh<_i203.AdhkarRepository>()),
    );
    gh.lazySingleton<_i46.GetAllAdhkarUseCase>(
      () => _i46.GetAllAdhkarUseCase(gh<_i203.AdhkarRepository>()),
    );
    gh.factory<_i354.HadithCubit>(
      () => _i354.HadithCubit(
        gh<_i664.GetHadithCollections>(),
        gh<_i664.GetHadithsByCollection>(),
        gh<_i664.SearchHadith>(),
      ),
    );
    gh.lazySingleton<_i1057.TasbeehCubit>(
      () => _i1057.TasbeehCubit(
        gh<_i46.GetTasbeehStatsUseCase>(),
        gh<_i46.RecordTasbeehProgressUseCase>(),
        gh<_i46.ClearTasbeehStatsDayUseCase>(),
        gh<_i46.ClearAllTasbeehStatsUseCase>(),
        gh<_i46.GetSavedTasbeehSessionUseCase>(),
        gh<_i46.SaveTasbeehSessionUseCase>(),
        gh<_i46.GetTasbeehCollectionUseCase>(),
        gh<_i46.SaveTasbeehCollectionUseCase>(),
      ),
    );
    gh.lazySingleton<_i171.AdhkarCubit>(
      () => _i171.AdhkarCubit(
        gh<_i46.GetAdhkarCategoriesUseCase>(),
        gh<_i46.GetAdhkarByCategoryUseCase>(),
        gh<_i46.SearchAdhkarUseCase>(),
        gh<_i46.ToggleFavoriteAdhkarUseCase>(),
        gh<_i46.GetFavoriteKeysUseCase>(),
        gh<_i46.GetAdhkarSettingsUseCase>(),
        gh<_i46.SaveAdhkarSettingsUseCase>(),
        gh<_i46.GetAllAdhkarUseCase>(),
      ),
    );
    return this;
  }
}
