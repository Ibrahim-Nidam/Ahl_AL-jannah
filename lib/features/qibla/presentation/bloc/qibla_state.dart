part of 'qibla_cubit.dart';

enum QiblaCompassIssue {
  unavailable,
  notEmitting,
  nullReadings,
  readError,
}

abstract class QiblaState {
  const QiblaState();
}

class QiblaInitial extends QiblaState {}

class QiblaLoadInProgress extends QiblaState {}

class QiblaReady extends QiblaState {
  final double qiblaBearing;
  final double direction; // Heading angle of the device relative to true North (0-360)
  final double? accuracy;
  final String? cityName;

  const QiblaReady({
    required this.qiblaBearing,
    required this.direction,
    this.accuracy,
    this.cityName,
  });

  QiblaReady copyWith({
    double? qiblaBearing,
    double? direction,
    double? accuracy,
    String? cityName,
  }) {
    return QiblaReady(
      qiblaBearing: qiblaBearing ?? this.qiblaBearing,
      direction: direction ?? this.direction,
      accuracy: accuracy ?? this.accuracy,
      cityName: cityName ?? this.cityName,
    );
  }
}

class QiblaUnsupported extends QiblaState {
  final QiblaCompassIssue issue;
  final String? errorDetail;
  final double qiblaBearing; // Static calculated bearing
  final String? cityName;

  const QiblaUnsupported({
    required this.issue,
    required this.qiblaBearing,
    this.errorDetail,
    this.cityName,
  });
}

class QiblaError extends QiblaState {
  final String message;

  const QiblaError(this.message);
}
