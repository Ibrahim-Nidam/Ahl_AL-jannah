import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:ahl_jannah/l10n/generated/app_localizations.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/extensions.dart';
import '../bloc/qibla_cubit.dart';

class QiblaPage extends StatefulWidget {
  const QiblaPage({super.key});

  @override
  State<QiblaPage> createState() => _QiblaPageState();
}

class _QiblaPageState extends State<QiblaPage>
    with AutomaticKeepAliveClientMixin<QiblaPage>, TickerProviderStateMixin {
  late final QiblaCubit _cubit;

  @override
  bool get wantKeepAlive => true;

  // Shortest-angle interpolation tracking
  double _lastDirection = 0.0;
  double _unwrappedDirection = 0.0;

  // Alignment glow animation
  late final AnimationController _glowController;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _cubit = getIt<QiblaCubit>();
    _cubit.initQibla();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _glowAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _glowController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  /// Calculates the unwrapped direction angle to ensure the needle rotates
  /// through the shortest path (preventing full 360-degree spins).
  double _getUnwrappedDirection(double target) {
    final diff = target - _lastDirection;
    // Map difference to range (-180, 180]
    final mappedDiff = ((diff + 180) % 360) - 180;
    _unwrappedDirection += mappedDiff;
    _lastDirection = target;
    return _unwrappedDirection;
  }

  bool _isLowAccuracy(double? accuracy) {
    if (accuracy == null) return false;
    // On Android, sensor accuracy is 0.0 (unreliable) or 1.0 (low).
    // On iOS, accuracy is heading deviation in degrees (lower is better, >15 is poor).
    return accuracy == 0.0 || accuracy == 1.0 || accuracy > 15.0;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = context.isDarkMode;
    final l10n = AppLocalizations.of(context);

    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.qiblaPageTitle),
          titleTextStyle: AppTextStyles.arabicHeading(fontSize: 22).copyWith(
            color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => _cubit.refreshLocation(),
              tooltip: l10n.commonRefreshLocation,
            ),
          ],
        ),
        body: BlocBuilder<QiblaCubit, QiblaState>(
          builder: (context, state) {
            if (state is QiblaInitial || state is QiblaLoadInProgress) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        color: AppColors.primaryGreen,
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.qiblaPageTitle,
                      style: AppTextStyles.headingMedium.copyWith(
                        color: isDark
                            ? AppColors.onSurfaceDark
                            : AppColors.onSurfaceLight,
                      ),
                    ),
                  ],
                ),
              );
            }

            if (state is QiblaError) {
              return _buildErrorView(context, state, isDark, l10n);
            }

            if (state is QiblaUnsupported) {
              return _buildUnsupportedView(context, state, isDark, l10n);
            }

            if (state is QiblaReady) {
              return _buildCompassView(context, state, isDark, l10n);
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildErrorView(
    BuildContext context,
    QiblaError state,
    bool isDark,
    AppLocalizations l10n,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.error.withAlpha(20),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 56,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.qiblaErrorLoading,
              style: AppTextStyles.headingMedium.copyWith(
                color: isDark
                    ? AppColors.onSurfaceDark
                    : AppColors.onSurfaceLight,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              state.message,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark
                    ? AppColors.onSurfaceDarkVariant
                    : AppColors.onSurfaceLightVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => _cubit.initQibla(),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.commonRetry),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnsupportedView(
    BuildContext context,
    QiblaUnsupported state,
    bool isDark,
    AppLocalizations l10n,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryGreen.withAlpha(20),
            ),
            child: Icon(
              Icons.sensors_off_rounded,
              size: 56,
              color: AppColors.primaryGreen.withAlpha(150),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.qiblaCompassUnavailable,
            style: AppTextStyles.headingMedium.copyWith(
              color: isDark
                  ? AppColors.onSurfaceDark
                  : AppColors.onSurfaceLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _compassIssueMessage(l10n, state),
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark
                  ? AppColors.onSurfaceDarkVariant
                  : AppColors.onSurfaceLightVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),

          // Static bearing card
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : AppColors.cardLight,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? AppColors.dividerDark
                    : AppColors.divider.withAlpha(100),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 40 : 10),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Kaaba icon
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/kaaba_icon.png',
                    width: 64,
                    height: 64,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.qiblaDirectionLabel,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.accentGoldDark,
                    letterSpacing: 2.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${state.qiblaBearing.toStringAsFixed(1)}°',
                  style: AppTextStyles.numberDisplay.copyWith(
                    color: AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.qiblaDegreesFromNorth(
                    state.cityName ?? l10n.qiblaYourLocation,
                  ),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark
                        ? AppColors.onSurfaceDarkVariant
                        : AppColors.onSurfaceLightVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: () => _cubit.refreshLocation(),
            icon: const Icon(Icons.location_searching_rounded),
            label: Text(l10n.commonRefreshLocation),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _compassIssueMessage(AppLocalizations l10n, QiblaUnsupported state) {
    switch (state.issue) {
      case QiblaCompassIssue.unavailable:
        return l10n.qiblaSensorUnavailableMessage;
      case QiblaCompassIssue.notEmitting:
        return l10n.qiblaSensorNotEmittingMessage;
      case QiblaCompassIssue.nullReadings:
        return l10n.qiblaSensorNullReadingsMessage;
      case QiblaCompassIssue.readError:
        return l10n.qiblaSensorReadErrorMessage(state.errorDetail ?? '');
    }
  }

  Widget _buildCompassView(
    BuildContext context,
    QiblaReady state,
    bool isDark,
    AppLocalizations l10n,
  ) {
    final unwrapped = _getUnwrappedDirection(state.direction);

    // Dynamic rotation angles
    final dialRotation = -unwrapped * pi / 180;
    final qiblaRotation = state.qiblaBearing * pi / 180;

    // Determine if the device is pointing close to the Qibla (within 5 degrees)
    final diff = (state.direction - state.qiblaBearing).abs() % 360;
    final isAligned = diff < 5 || diff > 355;

    final compassSize = MediaQuery.of(context).size.width * 0.78;
    final clampedSize = compassSize.clamp(260.0, 340.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 16),

          // ── Location & Bearing Header ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : AppColors.cardLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? AppColors.dividerDark
                    : AppColors.divider.withAlpha(80),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  color: AppColors.accentGold,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    state.cityName ?? l10n.qiblaYourLocation,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.onSurfaceDark
                          : AppColors.onSurfaceLight,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  width: 1.5,
                  height: 20,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: isDark
                      ? AppColors.dividerDark
                      : AppColors.divider.withAlpha(120),
                ),
                Text(
                  '${state.qiblaBearing.toStringAsFixed(1)}°',
                  style: AppTextStyles.headingSmall.copyWith(
                    color: AppColors.accentGoldDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Live Interactive Compass Stack ──
          AnimatedBuilder(
            animation: _glowAnimation,
            builder: (context, child) {
              return TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                tween: Tween<double>(begin: 0.0, end: dialRotation),
                builder: (context, rotation, _) {
                  return SizedBox(
                    width: clampedSize + 40,
                    height: clampedSize + 40,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // ── Outer alignment ring ──
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          width: clampedSize + 24,
                          height: clampedSize + 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isAligned
                                  ? AppColors.primaryGreen.withAlpha(
                                      (200 * _glowAnimation.value).round(),
                                    )
                                  : (isDark
                                      ? AppColors.dividerDark
                                      : AppColors.divider.withAlpha(80)),
                              width: isAligned ? 3.5 : 1.5,
                            ),
                            boxShadow: isAligned
                                ? [
                                    BoxShadow(
                                      color: AppColors.primaryGreen.withAlpha(
                                        (60 * _glowAnimation.value).round(),
                                      ),
                                      blurRadius: 24,
                                      spreadRadius: 4,
                                    ),
                                  ]
                                : null,
                          ),
                        ),

                        // ── Compass dial background ──
                        Container(
                          width: clampedSize,
                          height: clampedSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark
                                ? AppColors.surfaceDarkVariant
                                : AppColors.surfaceLightVariant,
                            border: Border.all(
                              color: isDark
                                  ? AppColors.dividerDark
                                  : AppColors.divider.withAlpha(100),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withAlpha(isDark ? 50 : 15),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                        ),

                        // ── Rotating Compass Dial ──
                        Transform.rotate(
                          angle: rotation,
                          child: SizedBox(
                            width: clampedSize,
                            height: clampedSize,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Painted dial
                                CustomPaint(
                                  size: Size(
                                    clampedSize - 10,
                                    clampedSize - 10,
                                  ),
                                  painter: _CompassDialPainter(
                                    primaryColor: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                    accentColor: AppColors.accentGold,
                                    north: l10n.qiblaNorth,
                                    east: l10n.qiblaEast,
                                    south: l10n.qiblaSouth,
                                    west: l10n.qiblaWest,
                                  ),
                                ),

                                // ── Kaaba needle ──
                                Transform.rotate(
                                  angle: qiblaRotation,
                                  child: SizedBox(
                                    width: clampedSize - 10,
                                    height: clampedSize - 10,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        // Needle line from center outward
                                        Positioned(
                                          top: 14,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // Kaaba icon at the tip
                                              AnimatedContainer(
                                                duration: const Duration(
                                                  milliseconds: 400,
                                                ),
                                                padding: const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: isAligned
                                                      ? AppColors.primaryGreen
                                                          .withAlpha((200 * _glowAnimation.value).round())
                                                      : AppColors.accentGold
                                                          .withAlpha(40),
                                                  border: Border.all(
                                                    color: isAligned
                                                        ? AppColors.primaryGreen
                                                        : AppColors.accentGold,
                                                    width: isAligned ? 2.5 : 1.5,
                                                  ),
                                                  boxShadow: isAligned
                                                      ? [
                                                          BoxShadow(
                                                            color: AppColors
                                                                .primaryGreen
                                                                .withAlpha(100),
                                                            blurRadius: 12,
                                                            spreadRadius: 2,
                                                          ),
                                                        ]
                                                      : null,
                                                ),
                                                child: ClipOval(
                                                  child: Image.asset(
                                                    'assets/kaaba_icon.png',
                                                    width: 28,
                                                    height: 28,
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              // Needle stem
                                              Container(
                                                width: 2.5,
                                                height: clampedSize * 0.22,
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topCenter,
                                                    end: Alignment.bottomCenter,
                                                    colors: isAligned
                                                        ? [
                                                            AppColors.primaryGreen,
                                                            AppColors.primaryGreen
                                                                .withAlpha(40),
                                                          ]
                                                        : [
                                                            AppColors.accentGold,
                                                            AppColors.accentGold
                                                                .withAlpha(40),
                                                          ],
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(2),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // ── Fixed device heading indicator at top ──
                        Positioned(
                          top: 0,
                          child: Container(
                            width: 3,
                            height: 18,
                            decoration: BoxDecoration(
                              color: isAligned
                                  ? AppColors.primaryGreen
                                  : Colors.redAccent,
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: [
                                BoxShadow(
                                  color: (isAligned
                                          ? AppColors.primaryGreen
                                          : Colors.redAccent)
                                      .withAlpha(100),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // ── Center hub ──
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.accentGoldLight,
                                AppColors.accentGoldDark,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accentGold.withAlpha(80),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),

          // ── Calibration Warning ──
          if (_isLowAccuracy(state.accuracy)) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: Colors.amber.withAlpha(isDark ? 25 : 30),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.amber.withAlpha(100),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.amber.withAlpha(40),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.amber,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.qiblaCalibrateHint,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isDark ? Colors.amber[200] : Colors.amber[900],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // ── Alignment Status Banner ──
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(
              horizontal: 28,
              vertical: 20,
            ),
            decoration: BoxDecoration(
              gradient: isAligned
                  ? LinearGradient(
                      colors: [
                        AppColors.primaryGreen.withAlpha(25),
                        AppColors.primaryGreen.withAlpha(10),
                      ],
                    )
                  : null,
              color: isAligned
                  ? null
                  : (isDark ? AppColors.cardDark : AppColors.cardLight),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isAligned
                    ? AppColors.primaryGreen.withAlpha(150)
                    : (isDark
                        ? AppColors.dividerDark
                        : AppColors.divider.withAlpha(80)),
                width: isAligned ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    isAligned
                        ? Icons.check_circle_rounded
                        : Icons.explore_rounded,
                    key: ValueKey(isAligned),
                    color: isAligned
                        ? AppColors.primaryGreen
                        : AppColors.accentGoldDark,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          isAligned
                              ? l10n.qiblaAligned
                              : l10n.qiblaRotateDevice,
                          key: ValueKey(isAligned),
                          style: AppTextStyles.headingSmall.copyWith(
                            color: isAligned
                                ? AppColors.primaryGreen
                                : (isDark
                                    ? AppColors.onSurfaceDark
                                    : AppColors.onSurfaceLight),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isAligned
                            ? l10n.qiblaFacingKaaba
                            : l10n.qiblaAlignMarkerHint,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isDark
                              ? AppColors.onSurfaceDarkVariant
                              : AppColors.onSurfaceLightVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

/// Custom Painter drawing a clean compass face dial with tick marks,
/// cardinal labels, and a subtle central Islamic star motif.
class _CompassDialPainter extends CustomPainter {
  final Color primaryColor;
  final Color accentColor;
  final String north;
  final String east;
  final String south;
  final String west;

  _CompassDialPainter({
    required this.primaryColor,
    required this.accentColor,
    required this.north,
    required this.east,
    required this.south,
    required this.west,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // ── Inner bezel ring ──
    final paintRing = Paint()
      ..color = primaryColor.withAlpha(25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius - 18, paintRing);

    // ── Tick marks ──
    for (int i = 0; i < 360; i += 6) {
      final angle = (i - 90) * pi / 180; // -90 so 0° = top
      final isMajor = i % 90 == 0;
      final isMinor = i % 30 == 0;
      final startLen = radius - 18;
      final double endLen;
      if (isMajor) {
        endLen = radius - 38;
      } else if (isMinor) {
        endLen = radius - 30;
      } else {
        endLen = radius - 23;
      }

      final start = Offset(
        center.dx + startLen * cos(angle),
        center.dy + startLen * sin(angle),
      );
      final end = Offset(
        center.dx + endLen * cos(angle),
        center.dy + endLen * sin(angle),
      );

      final paintTick = Paint()
        ..color = isMajor
            ? primaryColor
            : isMinor
                ? primaryColor.withAlpha(140)
                : primaryColor.withAlpha(50)
        ..strokeWidth = isMajor
            ? 2.5
            : isMinor
                ? 1.5
                : 0.8
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(start, end, paintTick);
    }

    // ── Cardinal direction labels ──
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Trigonometric: top (N) is -90°, right (E) is 0°, etc.
    final directions = <int, String>{
      0: north,   // top
      90: east,   // right
      180: south, // bottom
      270: west,  // left
    };

    directions.forEach((deg, label) {
      final angle = (deg - 90) * pi / 180;
      final isNorth = deg == 0;
      textPainter.text = TextSpan(
        text: label,
        style: TextStyle(
          color: isNorth ? Colors.red : primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: isNorth ? 20 : 16,
        ),
      );
      textPainter.layout();

      final labelOffset = Offset(
        center.dx + (radius - 42) * cos(angle) - textPainter.width / 2,
        center.dy + (radius - 42) * sin(angle) - textPainter.height / 2,
      );
      textPainter.paint(canvas, labelOffset);
    });

    // ── Degree markers at 30° intervals ──
    for (int i = 0; i < 360; i += 30) {
      if (i % 90 == 0) continue; // Skip cardinal directions
      final angle = (i - 90) * pi / 180;
      textPainter.text = TextSpan(
        text: '$i°',
        style: TextStyle(
          color: primaryColor.withAlpha(100),
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      );
      textPainter.layout();

      final labelOffset = Offset(
        center.dx + (radius - 34) * cos(angle) - textPainter.width / 2,
        center.dy + (radius - 34) * sin(angle) - textPainter.height / 2,
      );
      textPainter.paint(canvas, labelOffset);
    }

    // ── Central Islamic Star (8-point geometric design) ──
    final starPath = Path();
    final starRadius = radius * 0.2;
    for (int i = 0; i < 8; i++) {
      final angle1 = i * pi / 4;
      final angle2 = (i + 0.5) * pi / 4;
      final p1 = Offset(
        center.dx + starRadius * cos(angle1),
        center.dy + starRadius * sin(angle1),
      );
      final p2 = Offset(
        center.dx + (starRadius * 0.5) * cos(angle2),
        center.dy + (starRadius * 0.5) * sin(angle2),
      );

      if (i == 0) {
        starPath.moveTo(p1.dx, p1.dy);
      } else {
        starPath.lineTo(p1.dx, p1.dy);
      }
      starPath.lineTo(p2.dx, p2.dy);
    }
    starPath.close();

    final paintStarFill = Paint()
      ..color = accentColor.withAlpha(15)
      ..style = PaintingStyle.fill;
    canvas.drawPath(starPath, paintStarFill);

    final paintStarBorder = Paint()
      ..color = accentColor.withAlpha(80)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(starPath, paintStarBorder);
  }

  @override
  bool shouldRepaint(covariant _CompassDialPainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.north != north ||
        oldDelegate.east != east ||
        oldDelegate.south != south ||
        oldDelegate.west != west;
  }
}
