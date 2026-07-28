import 'dart:math';
import 'package:injectable/injectable.dart';

@lazySingleton
class CalculateQiblaBearingUseCase {
  const CalculateQiblaBearingUseCase();

  /// Calculates the mathematical bearing in degrees (0-360) from user coordinates
  /// to the Kaaba in Mecca (21.422487° N, 39.826206° E).
  double call(double userLat, double userLng) {
    const kaabLat = 21.422487 * pi / 180;
    const kaabLng = 39.826206 * pi / 180;
    final lat = userLat * pi / 180;
    final lng = userLng * pi / 180;
    final dLng = kaabLng - lng;

    final y = sin(dLng) * cos(kaabLat);
    final x = cos(lat) * sin(kaabLat) - sin(lat) * cos(kaabLat) * cos(dLng);

    // Get angle in degrees, map from (-180, 180) to (0, 360)
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }
}
