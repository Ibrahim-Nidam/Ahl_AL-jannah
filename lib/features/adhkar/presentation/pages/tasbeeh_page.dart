/// Digital Tasbeeh counter page.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vibration/vibration.dart';

import 'package:ahl_jannah/core/theme/app_colors.dart';
import 'package:ahl_jannah/core/theme/app_text_styles.dart';
import 'package:ahl_jannah/l10n/generated/app_localizations.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/widgets/clear_text_suffix.dart';
import '../../../settings/domain/entities/settings_entities.dart';
import '../../../settings/presentation/bloc/settings_cubit.dart';
import '../../domain/entities/adhkar_entities.dart';
import '../../domain/usecases/adhkar_usecases.dart';
import '../bloc/tasbeeh_cubit.dart';

class TasbeehPage extends StatefulWidget {
  /// Optional catalog item to start with when opened from the Adhkar reader.
  final AdhkarItem? initialItem;

  /// When true, also ensure [initialItem] is saved into the collection.
  final bool addInitialToCollection;

  const TasbeehPage({
    super.key,
    this.initialItem,
    this.addInitialToCollection = false,
  });

  @override
  State<TasbeehPage> createState() => _TasbeehPageState();
}

class _TasbeehPageState extends State<TasbeehPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final TasbeehCubit _cubit;
  late final AnimationController _confettiController;
  Timer? _ticker;
  var _bootstrapped = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cubit = getIt<TasbeehCubit>();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _bootstrap();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _cubit.state.isTimingActive) setState(() {});
    });
  }

  Future<void> _bootstrap() async {
    await _cubit.loadSession();
    if (!mounted) return;

    final item = widget.initialItem;
    if (item != null) {
      if (widget.addInitialToCollection) {
        await _cubit.addToCollection(item);
      }
      _cubit.startWithCatalogDhikr(item);
    }

    _cubit.resumeTiming();
    _bootstrapped = true;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _cubit.pauseTiming();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_bootstrapped) return;
    if (state == AppLifecycleState.resumed) {
      _cubit.resumeTiming();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _cubit.pauseTiming();
    }
  }

  Future<void> _onTapIncrement(SettingsEntity settings) async {
    final justCompleted = await _cubit.increment();

    if (settings.tasbeehVibrateOnTap) {
      await _vibrateLight();
    }
    if (justCompleted) {
      await _vibrateStrong();
      if (mounted) {
        _confettiController.forward(from: 0.0);
        _cubit.clearJustCompleted();
      }
    }
  }

  Future<void> _vibrateLight() async {
    try {
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(duration: 40);
      }
    } catch (_) {}
  }

  Future<void> _vibrateStrong() async {
    try {
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(duration: 350, amplitude: 255);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final settingsState = context.read<SettingsCubit>().state;
    final arabicFontSize = settingsState is SettingsLoadSuccess
        ? settingsState.settings.arabicFontSize
        : 28.0;

    return BlocProvider.value(
      value: _cubit,
      child: BlocBuilder<TasbeehCubit, TasbeehState>(
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: Text(l10n.tasbeehPageTitle),
              actions: [
                IconButton(
                  tooltip: l10n.tasbeehStatsTitle,
                  icon: const Icon(Icons.bar_chart_rounded),
                  onPressed: () => _showStatsSheet(context, state),
                ),
                IconButton(
                  tooltip: l10n.tasbeehChooseDhikr,
                  icon: const Icon(Icons.menu_book_rounded),
                  onPressed: () => _showDhikrPicker(context),
                ),
              ],
            ),
            body: Stack(
              children: [
                state.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _TasbeehBody(
                        state: state,
                        isDark: isDark,
                        arabicFontSize: arabicFontSize,
                        elapsedMs: _cubit.liveElapsedMs(),
                        onIncrement: () {
                          final settingsState = context
                              .read<SettingsCubit>()
                              .state;
                          final settings = settingsState is SettingsLoadSuccess
                              ? settingsState.settings
                              : SettingsEntity.defaultSettings();
                          _onTapIncrement(settings);
                        },
                        onReset: _cubit.resetCount,
                        onSelectMode: (mode) {
                          if (mode == TasbeehCounterMode.custom) {
                            _promptCustomTarget(context, state.customTarget);
                          } else {
                            _cubit.setCounterMode(mode);
                          }
                        },
                      ),
                ConfettiWidget(animation: _confettiController),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _promptCustomTarget(BuildContext context, int current) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: '$current');
    try {
      final result = await showDialog<int>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text(l10n.tasbeehCustomTargetTitle),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.tasbeehCustomTargetLabel,
                suffixIcon: ClearTextSuffix(controller: controller),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () {
                  final parsed = int.tryParse(controller.text.trim());
                  if (parsed != null && parsed > 0) {
                    Navigator.pop(ctx, parsed);
                  }
                },
                child: Text(l10n.commonContinue),
              ),
            ],
          );
        },
      );
      if (result != null && result > 0) {
        _cubit.setCustomTarget(result);
      }
    } catch (e) {
      // Silently handle any dialog errors
    } finally {
      controller.dispose();
    }
  }

  void _showStatsSheet(BuildContext context, TasbeehState state) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            return _StatsSheetContent(
              scrollController: scrollController,
              state: state,
              cubit: _cubit,
              l10n: l10n,
            );
          },
        );
      },
    );
  }

  Future<void> _showDhikrPicker(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            return _DhikrPickerSheet(
              scrollController: scrollController,
              cubit: _cubit,
              l10n: l10n,
              onPicked: () => Navigator.pop(ctx),
            );
          },
        );
      },
    );
  }
}

class _TasbeehBody extends StatelessWidget {
  final TasbeehState state;
  final bool isDark;
  final double arabicFontSize;
  final int elapsedMs;
  final VoidCallback onIncrement;
  final VoidCallback onReset;
  final ValueChanged<TasbeehCounterMode> onSelectMode;

  const _TasbeehBody({
    required this.state,
    required this.isDark,
    required this.arabicFontSize,
    required this.elapsedMs,
    required this.onIncrement,
    required this.onReset,
    required this.onSelectMode,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final goal = state.goalCount;
    final remaining = state.remainingCount;

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              for (final mode in TasbeehCounterMode.values) ...[
                ChoiceChip(
                  label: Text(_modeLabel(l10n, mode, state.customTarget)),
                  selected: state.counterMode == mode,
                  showCheckmark: false,
                  onSelected: (_) => onSelectMode(mode),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Column(
              children: [
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: isDark
                          ? AppColors.surfaceDarkVariant
                          : AppColors.surfaceLightVariant,
                      border: Border.all(
                        color: isDark
                            ? AppColors.dividerDark
                            : AppColors.divider.withValues(alpha: 0.7),
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        state.hasDhikrText
                            ? state.dhikrText
                            : l10n.tasbeehEmptyCounterLabel,
                        textAlign: TextAlign.center,
                        textDirection: state.hasDhikrText
                            ? TextDirection.rtl
                            : null,
                        style: state.hasDhikrText
                            ? AppTextStyles.arabicBody(
                                fontSize: arabicFontSize,
                              ).copyWith(
                                height: 1.9,
                                color: isDark
                                    ? AppColors.onSurfaceDark
                                    : AppColors.onSurfaceLight,
                              )
                            : AppTextStyles.bodyMedium.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: state.currentCount == 0 ? null : onReset,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(l10n.tasbeehResetSession),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      l10n.tasbeehElapsedLabel(_formatDuration(elapsedMs)),
                      style: AppTextStyles.caption.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 120,
                  child: Material(
                    color: state.isCompleted
                        ? AppColors.success.withValues(alpha: 0.15)
                        : scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: onIncrement,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: CustomPaint(
                                painter: RoundedRectProgressPainter(
                                  progress: goal > 0 ? state.progress : 0.0,
                                  progressColor: state.isCompleted
                                      ? AppColors.success
                                      : scheme.primary,
                                  trackColor: scheme.surfaceContainerHighest
                                      .withValues(alpha: 0.4),
                                  strokeWidth: 6,
                                  borderRadius: 20,
                                ),
                              ),
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${state.currentCount}',
                                style: AppTextStyles.numberDisplay.copyWith(
                                  fontSize: 48,
                                  color: state.isCompleted
                                      ? AppColors.success
                                      : scheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                goal > 0
                                    ? l10n.tasbeehTargetLabel(goal)
                                    : l10n.tasbeehUnlimitedLabel,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              if (remaining != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  l10n.tasbeehRemainingLabel(remaining),
                                  style: AppTextStyles.caption.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _modeLabel(
    AppLocalizations l10n,
    TasbeehCounterMode mode,
    int customTarget,
  ) {
    switch (mode) {
      case TasbeehCounterMode.preset33:
        return '33';
      case TasbeehCounterMode.preset99:
        return '99';
      case TasbeehCounterMode.preset100:
        return '100';
      case TasbeehCounterMode.custom:
        return l10n.tasbeehModeCustom(customTarget);
      case TasbeehCounterMode.unlimited:
        return l10n.tasbeehModeUnlimited;
    }
  }

  String _formatDuration(int ms) {
    final totalSec = (ms / 1000).floor();
    final h = (totalSec ~/ 3600);
    final m = ((totalSec % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    if (h > 0) {
      return '$h:$m:$s';
    }
    return '$m:$s';
  }
}

class RoundedRectProgressPainter extends CustomPainter {
  final double progress;
  final Color progressColor;
  final Color trackColor;
  final double strokeWidth;
  final double borderRadius;

  RoundedRectProgressPainter({
    required this.progress,
    required this.progressColor,
    required this.trackColor,
    this.strokeWidth = 6.0,
    this.borderRadius = 20.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawRRect(rrect, trackPaint);

    if (progress <= 0) return;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final totalLength = metrics.first.length;
    final drawLength = totalLength * progress.clamp(0.0, 1.0);
    final extractPath = metrics.first.extractPath(0, drawLength);

    canvas.drawPath(extractPath, progressPaint);
  }

  @override
  bool shouldRepaint(covariant RoundedRectProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.trackColor != trackColor;
  }
}

class ConfettiParticle {
  double x;
  double y;
  final Color color;
  final double size;
  final double vx;
  final double vy;
  final double rotation;
  final double rotationSpeed;

  ConfettiParticle({
    required this.x,
    required this.y,
    required this.color,
    required this.size,
    required this.vx,
    required this.vy,
    required this.rotation,
    required this.rotationSpeed,
  });
}

class ConfettiWidget extends StatefulWidget {
  final Animation<double> animation;

  const ConfettiWidget({super.key, required this.animation});

  @override
  State<ConfettiWidget> createState() => _ConfettiWidgetState();
}

class _ConfettiWidgetState extends State<ConfettiWidget> {
  final List<ConfettiParticle> _particles = [];

  @override
  void initState() {
    super.initState();
    widget.animation.addListener(_updateParticles);
  }

  @override
  void dispose() {
    widget.animation.removeListener(_updateParticles);
    super.dispose();
  }

  void _generateParticles(Size size) {
    if (_particles.isNotEmpty) return;
    final random = math.Random();
    final colors = [
      Colors.redAccent,
      Colors.blueAccent,
      Colors.greenAccent,
      Colors.yellowAccent,
      Colors.orangeAccent,
      Colors.purpleAccent,
      Colors.pinkAccent,
      AppColors.accentGold,
      AppColors.primaryGreen,
    ];

    for (int i = 0; i < 90; i++) {
      _particles.add(
        ConfettiParticle(
          x: random.nextDouble() * size.width,
          y: -random.nextDouble() * size.height * 0.5,
          color: colors[random.nextInt(colors.length)],
          size: random.nextDouble() * 8 + 6,
          vx: (random.nextDouble() - 0.5) * 4,
          vy: random.nextDouble() * 5 + 4,
          rotation: random.nextDouble() * math.pi * 2,
          rotationSpeed: (random.nextDouble() - 0.5) * 0.2,
        ),
      );
    }
  }

  void _updateParticles() {
    if (!mounted) return;
    if (widget.animation.value == 0.0) {
      _particles.clear();
    } else {
      for (final p in _particles) {
        p.x += p.vx;
        p.y += p.vy;
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.animation.value == 0.0 || widget.animation.value == 1.0) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          _generateParticles(size);
          return CustomPaint(
            size: size,
            painter: _ConfettiPainter(particles: _particles),
          );
        },
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;

  _ConfettiPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      paint.color = p.color;
      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);
      if (p.size % 2 == 0) {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.6,
          ),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}

class _StatsSheetContent extends StatefulWidget {
  final ScrollController scrollController;
  final TasbeehState state;
  final TasbeehCubit cubit;
  final AppLocalizations l10n;

  const _StatsSheetContent({
    required this.scrollController,
    required this.state,
    required this.cubit,
    required this.l10n,
  });

  @override
  State<_StatsSheetContent> createState() => _StatsSheetContentState();
}

class _StatsSheetContentState extends State<_StatsSheetContent> {
  String? _selectedDate;
  int _selectedTab = 0; // 0 = Daily, 1 = Lifetime

  @override
  void initState() {
    super.initState();
    _selectedDate = TasbeehStats.todayKey();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return BlocBuilder<TasbeehCubit, TasbeehState>(
      bloc: widget.cubit,
      builder: (context, state) {
        final stats = state.stats;
        final selectedDate = _selectedDate ?? TasbeehStats.todayKey();
        final dayStats = stats.dayFor(selectedDate);
        final filteredDailyByDhikr = dayStats.byDhikr.entries
            .where((e) => e.key.trim().isNotEmpty)
            .toList();
        final filteredLifetimeByDhikr = stats.lifetimeByDhikr.entries
            .where((e) => e.key.trim().isNotEmpty)
            .toList();

        final allDays = stats.sortedDayKeys.contains(TasbeehStats.todayKey())
            ? stats.sortedDayKeys
            : [TasbeehStats.todayKey(), ...stats.sortedDayKeys];

        return Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.l10n.tasbeehStatsTitle,
                    style: AppTextStyles.headingSmall,
                  ),
                  IconButton(
                    tooltip: widget.l10n.commonClear,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                    ),
                    onPressed: () => _showClearStatsDialog(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Segmented selector: Daily vs Lifetime
              Container(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTab = 0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _selectedTab == 0
                                ? scheme.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.today_rounded,
                                size: 16,
                                color: _selectedTab == 0
                                    ? scheme.onPrimary
                                    : scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.l10n.tasbeehStatsDaily,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: _selectedTab == 0
                                      ? scheme.onPrimary
                                      : scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTab = 1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _selectedTab == 1
                                ? scheme.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.auto_graph_rounded,
                                size: 16,
                                color: _selectedTab == 1
                                    ? scheme.onPrimary
                                    : scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.l10n.tasbeehStatsLifetime,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: _selectedTab == 1
                                      ? scheme.onPrimary
                                      : scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (_selectedTab == 0) ...[
                // Date Chip Selector
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: allDays.length,
                    itemBuilder: (context, index) {
                      final dateKey = allDays[index];
                      final isToday = dateKey == TasbeehStats.todayKey();
                      final label = isToday
                          ? widget.l10n.tasbeehStatsToday
                          : _formatDate(dateKey);

                      return _DateChip(
                        date: dateKey,
                        label: label,
                        isSelected: selectedDate == dateKey,
                        onTap: () => setState(() => _selectedDate = dateKey),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                _SummaryCard(
                  title: selectedDate == TasbeehStats.todayKey()
                      ? widget.l10n.tasbeehStatsToday
                      : _formatDate(selectedDate),
                  stats: dayStats.totals,
                  l10n: widget.l10n,
                ),
                const SizedBox(height: 16),

                if (filteredDailyByDhikr.isNotEmpty) ...[
                  Text(
                    widget.l10n.tasbeehStatsByDhikr,
                    style: AppTextStyles.headingSmall,
                  ),
                  const SizedBox(height: 12),
                  ...filteredDailyByDhikr.map(
                    (entry) => _DhikrStatTile(
                      dhikrText: entry.key,
                      stats: entry.value,
                      l10n: widget.l10n,
                    ),
                  ),
                ] else
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: Text(
                        widget.l10n.tasbeehCollectionEmpty,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ] else ...[
                _SummaryCard(
                  title: widget.l10n.tasbeehStatsLifetime,
                  stats: stats.lifetime,
                  l10n: widget.l10n,
                ),
                const SizedBox(height: 16),

                if (filteredLifetimeByDhikr.isNotEmpty) ...[
                  Text(
                    widget.l10n.tasbeehStatsByDhikr,
                    style: AppTextStyles.headingSmall,
                  ),
                  const SizedBox(height: 12),
                  ...filteredLifetimeByDhikr.map(
                    (entry) => _DhikrStatTile(
                      dhikrText: entry.key,
                      stats: entry.value,
                      l10n: widget.l10n,
                    ),
                  ),
                ] else
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: Text(
                        widget.l10n.tasbeehCollectionEmpty,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _formatDate(String dateStr) {
    final parts = dateStr.split('-');
    if (parts.length != 3) return dateStr;
    final year = parts[0];
    final month = parts[1];
    final day = parts[2];
    return '$day/$month/$year';
  }

  Future<void> _showClearStatsDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(widget.l10n.commonClear),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.l10n.tasbeehClearToday),
              const SizedBox(height: 12),
              Text(widget.l10n.tasbeehClearAll),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(widget.l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(widget.l10n.tasbeehClearToday),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(widget.l10n.tasbeehClearAll),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await widget.cubit.clearAllStats();
    } else if (result == false) {
      await widget.cubit.clearStatsForDay(TasbeehStats.todayKey());
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final TasbeehAggregateStats stats;
  final AppLocalizations l10n;

  const _SummaryCard({
    required this.title,
    required this.stats,
    required this.l10n,
  });

  String _formatDuration(int ms) {
    final totalSec = (ms / 1000).floor();
    final h = (totalSec ~/ 3600);
    final m = ((totalSec % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final timeStr = _formatDuration(stats.totalTimeMs);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.headingSmall),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MetricItem(
                icon: Icons.repeat_rounded,
                value: '${stats.totalRepetitions}',
                label: l10n
                    .tasbeehStatRepetitions(stats.totalRepetitions)
                    .split(' ')
                    .last,
              ),
              _MetricItem(
                icon: Icons.timer_outlined,
                value: timeStr,
                label: l10n.tasbeehElapsedLabel('').replaceAll(':', '').trim(),
              ),
              if (stats.completedSessions > 0)
                _MetricItem(
                  icon: Icons.task_alt_rounded,
                  value: '${stats.completedSessions}',
                  label: l10n
                      .tasbeehStatSessions(stats.completedSessions)
                      .split(' ')
                      .last,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _MetricItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, color: AppColors.primaryGreen, size: 22),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.headingSmall.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _DateChip extends StatelessWidget {
  final String date;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DateChip({
    required this.date,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        showCheckmark: false,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primaryGreen.withValues(alpha: 0.2),
        labelStyle: TextStyle(
          color: isSelected ? AppColors.primaryGreen : scheme.onSurface,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

class _DhikrStatTile extends StatelessWidget {
  final String dhikrText;
  final TasbeehAggregateStats stats;
  final AppLocalizations l10n;

  const _DhikrStatTile({
    required this.dhikrText,
    required this.stats,
    required this.l10n,
  });

  String _formatDuration(int ms) {
    final totalSec = (ms / 1000).floor();
    final h = (totalSec ~/ 3600);
    final m = ((totalSec % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final timeStr = _formatDuration(stats.totalTimeMs);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            dhikrText,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.arabicBody(
              fontSize: 22,
            ).copyWith(color: scheme.onSurface, height: 1.6),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.repeat_rounded,
                    size: 16,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${stats.totalRepetitions}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: AppColors.accentGoldDark,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    timeStr,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (stats.completedSessions > 0)
                Row(
                  children: [
                    Icon(
                      Icons.task_alt_rounded,
                      size: 16,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${stats.completedSessions}',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DhikrPickerSheet extends StatefulWidget {
  final ScrollController scrollController;
  final TasbeehCubit cubit;
  final AppLocalizations l10n;
  final VoidCallback onPicked;

  const _DhikrPickerSheet({
    required this.scrollController,
    required this.cubit,
    required this.l10n,
    required this.onPicked,
  });

  @override
  State<_DhikrPickerSheet> createState() => _DhikrPickerSheetState();
}

class _DhikrPickerSheetState extends State<_DhikrPickerSheet> {
  final _searchController = TextEditingController();
  List<AdhkarItem> _catalogHits = const [];
  var _searching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _catalogHits = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    final results = await getIt<SearchAdhkarUseCase>()(q);
    if (!mounted) return;
    setState(() {
      _catalogHits = results.take(40).toList(growable: false);
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final collection = widget.cubit.state.collection;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        // ── Header ──
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    scheme.primary.withAlpha(40),
                    scheme.primary.withAlpha(15),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: scheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                l10n.tasbeehChooseDhikr,
                style: AppTextStyles.headingMedium.copyWith(
                  color: isDark
                      ? AppColors.onSurfaceDark
                      : AppColors.onSurfaceLight,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── Quick Actions Row ──
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.exposure_zero_rounded,
                label: l10n.tasbeehEmptyCounterOption,
                gradient: [
                  scheme.primary.withAlpha(25),
                  scheme.primary.withAlpha(8),
                ],
                iconColor: scheme.primary,
                borderColor: scheme.primary.withAlpha(60),
                isDark: isDark,
                onTap: () {
                  widget.cubit.startEmptyCounter();
                  widget.onPicked();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.edit_rounded,
                label: l10n.tasbeehCustomDhikrOption,
                gradient: [
                  AppColors.accentGold.withAlpha(25),
                  AppColors.accentGold.withAlpha(8),
                ],
                iconColor: AppColors.accentGoldDark,
                borderColor: AppColors.accentGold.withAlpha(60),
                isDark: isDark,
                onTap: () async {
                  final text = await _promptCustomDhikr(context);
                  if (text == null) return;
                  widget.cubit.startWithCustomDhikr(text);
                  widget.onPicked();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── Collection Section ──
        _SectionHeader(
          icon: Icons.bookmark_rounded,
          label: l10n.tasbeehCollectionSection,
          iconColor: AppColors.accentGoldDark,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        if (collection.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : AppColors.cardLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? AppColors.dividerDark
                    : AppColors.divider.withAlpha(80),
              ),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.bookmark_border_rounded,
                    color: isDark
                        ? AppColors.onSurfaceDarkVariant
                        : AppColors.onSurfaceLightVariant,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.tasbeehCollectionEmpty,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark
                          ? AppColors.onSurfaceDarkVariant
                          : AppColors.onSurfaceLightVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          ...collection.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: isDark ? AppColors.cardDark : AppColors.cardLight,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    widget.cubit.startWithCollectionItem(item);
                    widget.onPicked();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? AppColors.dividerDark
                            : AppColors.divider.withAlpha(80),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.accentGold,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            item.arabic,
                            textDirection: TextDirection.rtl,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.onSurfaceDark
                                  : AppColors.onSurfaceLight,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () async {
                              await widget.cubit.removeFromCollection(item);
                              setState(() {});
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                Icons.delete_outline_rounded,
                                color: AppColors.error.withAlpha(180),
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 24),

        // ── Catalog Search Section ──
        _SectionHeader(
          icon: Icons.search_rounded,
          label: l10n.tasbeehCatalogSearchSection,
          iconColor: scheme.primary,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? AppColors.dividerDark
                  : AppColors.divider.withAlpha(80),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 25 : 8),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearch,
            style: AppTextStyles.bodyLarge.copyWith(
              color: isDark
                  ? AppColors.onSurfaceDark
                  : AppColors.onSurfaceLight,
            ),
            decoration: InputDecoration(
              hintText: l10n.adhkarSearchHint,
              hintStyle: AppTextStyles.bodyMedium.copyWith(
                color: isDark
                    ? AppColors.onSurfaceDarkVariant
                    : AppColors.onSurfaceLightVariant,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: scheme.primary.withAlpha(180),
              ),
              suffixIcon: ClearTextSuffix(
                controller: _searchController,
                onClear: () => _onSearch(''),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_searching)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: scheme.primary,
                ),
              ),
            ),
          )
        else
          ..._catalogHits.map((item) {
            final isInCollection = widget.cubit.isInCollection(item);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: isDark ? AppColors.cardDark : AppColors.cardLight,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    widget.cubit.startWithCatalogDhikr(item);
                    widget.onPicked();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? AppColors.dividerDark
                            : AppColors.divider.withAlpha(80),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isInCollection
                                ? AppColors.accentGold
                                : scheme.primary.withAlpha(80),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.arabic,
                                textDirection: TextDirection.rtl,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppColors.onSurfaceDark
                                      : AppColors.onSurfaceLight,
                                ),
                              ),
                              if (item.translation.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  item.translation,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: isDark
                                        ? AppColors.onSurfaceDarkVariant
                                        : AppColors.onSurfaceLightVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () async {
                              await widget.cubit.addToCollection(item);
                              setState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isInCollection
                                    ? AppColors.accentGold.withAlpha(25)
                                    : scheme.primary.withAlpha(15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isInCollection
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_add_outlined,
                                color: isInCollection
                                    ? AppColors.accentGold
                                    : scheme.primary,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Future<String?> _promptCustomDhikr(BuildContext context) async {
    final l10n = widget.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = TextEditingController();
    try {
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            backgroundColor: isDark
                ? AppColors.surfaceDarkVariant
                : AppColors.cardLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.edit_rounded,
                  color: AppColors.accentGoldDark,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  l10n.tasbeehCustomDhikrOption,
                  style: AppTextStyles.headingSmall.copyWith(
                    color: isDark
                        ? AppColors.onSurfaceDark
                        : AppColors.onSurfaceLight,
                  ),
                ),
              ],
            ),
            content: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? AppColors.dividerDark
                      : AppColors.divider.withAlpha(80),
                ),
              ),
              child: TextField(
                controller: controller,
                autofocus: true,
                maxLines: 3,
                textDirection: TextDirection.rtl,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: isDark
                      ? AppColors.onSurfaceDark
                      : AppColors.onSurfaceLight,
                ),
                decoration: InputDecoration(
                  hintText: l10n.tasbeehCustomDhikrHint,
                  hintStyle: AppTextStyles.bodyMedium.copyWith(
                    color: isDark
                        ? AppColors.onSurfaceDarkVariant
                        : AppColors.onSurfaceLightVariant,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(14),
                  suffixIcon: ClearTextSuffix(controller: controller),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: Text(l10n.commonContinue),
              ),
            ],
          );
        },
      );
      if (result == null || result.isEmpty) return null;
      return result;
    } catch (e) {
      return null;
    } finally {
      controller.dispose();
    }
  }
}

// ── Supporting Widgets for _DhikrPickerSheet ──

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<Color> gradient;
  final Color iconColor;
  final Color borderColor;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.iconColor,
    required this.borderColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.onSurfaceDark
                      : AppColors.onSurfaceLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final bool isDark;

  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 10),
        Text(
          label,
          style: AppTextStyles.headingSmall.copyWith(
            color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
          ),
        ),
      ],
    );
  }
}
