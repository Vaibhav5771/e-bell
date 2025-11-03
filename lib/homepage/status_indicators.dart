// widgets/home/status_indicators.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:e_bell/utils/app_text_styles.dart';
import 'package:e_bell/utils/theme_state.dart';

class StatusIndicators extends StatelessWidget {
  final bool loading;
  final bool error;
  final bool namazEnabled;
  final bool sunriseEnabled;
  final List<String> namazTimes;
  final List<String> poojaTimes;
  final VoidCallback onRefresh;

  const StatusIndicators({
    Key? key,
    required this.loading,
    required this.error,
    required this.namazEnabled,
    required this.sunriseEnabled,
    required this.namazTimes,
    required this.poojaTimes,
    required this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (error) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                'Failed to load status',
                style: AppTextStyles.body.copyWith(fontSize: 14, color: Colors.red),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: onRefresh,
              tooltip: 'Retry',
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildPrayerTimeIndicator(context,
              label: 'Namaz',
              enabled: namazEnabled,
              times: namazTimes.take(2).toList(),
            ),
            _buildPrayerTimeIndicator(context,
              label: 'Sunrise/Sunset',
              enabled: sunriseEnabled,
              times: poojaTimes.take(2).toList(),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: onRefresh,
              tooltip: 'Refresh',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrayerTimeIndicator(BuildContext context, {
    required String label,
    required bool enabled,
    List<String> times = const [],
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      margin: const EdgeInsets.only(right: 8),
      constraints: const BoxConstraints(minWidth: 80),
      decoration: BoxDecoration(
        color: enabled ? themeProvider.selectedColor.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: enabled ? themeProvider.selectedColor : Colors.grey,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            enabled ? Icons.check_circle : Icons.circle,
            color: enabled ? themeProvider.selectedColor : Colors.grey,
            size: 14,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.small.copyWith(
                    color: enabled ? themeProvider.selectedColor : Colors.grey,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (enabled && times.isNotEmpty)
                  ...times.map((t) => Text(
                    t,
                    style: AppTextStyles.small.copyWith(
                      color: Colors.black87,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}