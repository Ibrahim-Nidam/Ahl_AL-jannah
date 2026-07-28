import 'package:flutter_test/flutter_test.dart';
import 'package:ahl_jannah/features/qibla/domain/usecases/qibla_usecases.dart';

void main() {
  group('Qibla Bearing Calculations', () {
    const calculateBearing = CalculateQiblaBearingUseCase();

    test('calculates correct bearing to Mecca from Mecca itself (returns 0 or 360)', () {
      final bearing = calculateBearing(21.422487, 39.826206);
      expect(bearing, closeTo(0.0, 0.01));
    });

    test('calculates correct Qibla bearing from Casablanca, Morocco (~93.7°)', () {
      final bearing = calculateBearing(33.5731, -7.5898);
      expect(bearing, closeTo(93.68, 0.05));
    });

    test('calculates correct Qibla bearing from London, UK (~119.0°)', () {
      final bearing = calculateBearing(51.5074, -0.1278);
      expect(bearing, closeTo(118.99, 0.05));
    });

    test('calculates correct Qibla bearing from Paris, France (~119.2°)', () {
      final bearing = calculateBearing(48.8566, 2.3522);
      expect(bearing, closeTo(119.16, 0.05));
    });

    test('calculates correct Qibla bearing from New York, USA (~58.5°)', () {
      final bearing = calculateBearing(40.7128, -74.0060);
      expect(bearing, closeTo(58.48, 0.05));
    });

    test('calculates correct Qibla bearing from Jakarta, Indonesia (~295.2°)', () {
      final bearing = calculateBearing(-6.2088, 106.8456);
      expect(bearing, closeTo(295.15, 0.05));
    });

    test('calculates correct Qibla bearing from Kuala Lumpur, Malaysia (~292.5°)', () {
      final bearing = calculateBearing(3.1390, 101.6869);
      expect(bearing, closeTo(292.54, 0.05));
    });

    test('calculates correct Qibla bearing from Sydney, Australia (~277.5°)', () {
      final bearing = calculateBearing(-33.8688, 151.2093);
      expect(bearing, closeTo(277.50, 0.05));
    });
  });
}
