import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:flutter_compass/flutter_compass.dart';

import '../../domain/usecases/qibla_usecases.dart';
import '../../../../features/prayer/domain/usecases/prayer_usecases.dart';

part 'qibla_state.dart';

@lazySingleton
class QiblaCubit extends Cubit<QiblaState> {
  final GetUserLocationUseCase _getUserLocationUseCase;
  final CalculateQiblaBearingUseCase _calculateQiblaBearingUseCase;
  
  StreamSubscription? _compassSubscription;
  Timer? _timeoutTimer;

  QiblaCubit(
    this._getUserLocationUseCase,
    this._calculateQiblaBearingUseCase,
  ) : super(QiblaInitial());

  /// Loads location, calculates Kaaba bearing, and starts listening to the device compass sensor.
  Future<void> initQibla() async {
    emit(QiblaLoadInProgress());
    _compassSubscription?.cancel();
    _timeoutTimer?.cancel();

    try {
      final location = await _getUserLocationUseCase();
      final qiblaBearing = _calculateQiblaBearingUseCase(
        location.latitude,
        location.longitude,
      );

      final compassEvents = FlutterCompass.events;
      if (compassEvents == null) {
        emit(QiblaUnsupported(
          issue: QiblaCompassIssue.unavailable,
          qiblaBearing: qiblaBearing,
          cityName: location.cityName,
        ));
        return;
      }

      bool hasEmitted = false;
      _timeoutTimer = Timer(const Duration(seconds: 2), () {
        if (!hasEmitted && !isClosed) {
          emit(QiblaUnsupported(
            issue: QiblaCompassIssue.notEmitting,
            qiblaBearing: qiblaBearing,
            cityName: location.cityName,
          ));
        }
      });

      _compassSubscription = compassEvents.listen(
        (event) {
          hasEmitted = true;
          _timeoutTimer?.cancel();
          final heading = event.heading;
          if (heading == null) {
            emit(QiblaUnsupported(
              issue: QiblaCompassIssue.nullReadings,
              qiblaBearing: qiblaBearing,
              cityName: location.cityName,
            ));
          } else {
            emit(QiblaReady(
              qiblaBearing: qiblaBearing,
              direction: heading,
              accuracy: event.accuracy,
              cityName: location.cityName,
            ));
          }
        },
        onError: (err) {
          hasEmitted = true;
          _timeoutTimer?.cancel();
          emit(QiblaUnsupported(
            issue: QiblaCompassIssue.readError,
            errorDetail: err.toString(),
            qiblaBearing: qiblaBearing,
            cityName: location.cityName,
          ));
        },
      );
    } catch (e) {
      _timeoutTimer?.cancel();
      emit(QiblaError(e.toString()));
    }
  }

  /// Refreshes GPS location coordinates and updates Qibla bearing.
  Future<void> refreshLocation() async {
    _compassSubscription?.cancel();
    _timeoutTimer?.cancel();
    emit(QiblaLoadInProgress());
    try {
      await _getUserLocationUseCase(forceRefresh: true);
      // Restart compass listening
      await initQibla();
    } catch (e) {
      emit(QiblaError(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _compassSubscription?.cancel();
    _timeoutTimer?.cancel();
    return super.close();
  }
}
