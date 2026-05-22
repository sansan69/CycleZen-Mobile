import 'package:flutter/material.dart';
import 'package:cyclezen/data/repositories/ride_repository.dart';
import 'package:cyclezen/data/services/achievement_service.dart';
import 'package:cyclezen/data/services/training_service.dart';
import 'package:cyclezen/data/services/ride_share_service.dart';
import 'package:cyclezen/domain/models/models.dart';
import 'package:cyclezen/domain/models/achievement.dart';
import 'package:cyclezen/domain/models/training.dart';
import 'package:cyclezen/features/achievements/widgets/achievements_grid.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final RideRepository _rideRepo = RideRepository();
  final AchievementService _achievementService = AchievementService();
  final TrainingService _trainingService = TrainingService();
  List<RideRecording>? _rides;
  TrainingMetrics? _metrics;
  List<Achievement>? _achievements;
  Map<String, double>? _achievementProgress;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final rides = await _rideRepo.getCompletedRides();
      final achievements = _achievementService.calculateAchievements(rides);
      final progress = _achievementService.getProgress(rides);
      final metrics = _trainingService.calculateMetrics(rides);
      setState(() {
        _rides = rides;
        _achievements = achievements;
        _achievementProgress = progress;
        _metrics = metrics;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _resetAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Everything?'),
        content: const Text(
          'This will permanently delete ALL your ride history, achievements, and stats. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final count = await _rideRepo.deleteAllRides();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted $count rides. Starting fresh! 🚴'), backgroundColor: Colors.green),
        );
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalDist = _rides?.fold<double>(0, (sum, r) => sum + r.actualDistanceKm) ?? 0;
    final totalTime = _rides?.fold<double>(0, (sum, r) => sum + r.actualDurationSec) ?? 0;
    final totalTimeH = totalTime / 3600;
    final totalAscent = _rides?.fold<double>(0, (sum, r) => sum + (r.route.ascentM ?? 0)) ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          if (_rides != null && _rides!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_forever),
              tooltip: 'Reset all data',
              onPressed: _resetAll,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Stats cards
                  Row(
                    children: [
                      Expanded(child: _StatCard(icon: Icons.straighten, label: 'Distance', value: '${totalDist.toStringAsFixed(1)} km')),
                      const SizedBox(width: 12),
                      Expanded(child: _StatCard(icon: Icons.timer, label: 'Time', value: '${totalTimeH.toStringAsFixed(1)} h')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _StatCard(icon: Icons.directions_bike, label: 'Rides', value: '${_rides?.length ?? 0}')),
                      const SizedBox(width: 12),
                      Expanded(child: _StatCard(icon: Icons.speed, label: 'Avg Speed',
                        value: totalDist > 0 && totalTimeH > 0 ? '${(totalDist / totalTimeH).toStringAsFixed(1)} km/h' : '--',
                      )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _StatCard(icon: Icons.terrain, label: 'Ascent', value: '${totalAscent.round()} m')),
                      const SizedBox(width: 12),
                      Expanded(child: _StatCard(icon: Icons.local_fire_department, label: 'Calories',
                        value: totalDist > 0 ? '${(totalDist * 70 * 0.5 + totalAscent * 0.15 * 0.7).round()} kcal' : '--',
                      )),
                    ],
                  ),

                  // Reset button
                  if (_rides != null && _rides!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _resetAll,
                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                        label: const Text('Reset All Data', style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],

                  // Training Metrics
                  if (_metrics != null && _metrics!.totalRides > 0) ...[
                    const SizedBox(height: 24),
                    Text('Training Load', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _TrainingMetric(label: 'TSS', value: '${_metrics!.tss}', color: Colors.blue),
                                _TrainingMetric(label: 'CTL', value: _metrics!.ctl.toStringAsFixed(1), color: Colors.green, subtitle: 'Fitness'),
                                _TrainingMetric(label: 'ATL', value: _metrics!.atl.toStringAsFixed(1), color: Colors.orange, subtitle: 'Fatigue'),
                                _TrainingMetric(label: 'TSB', value: _metrics!.tsb.toStringAsFixed(1),
                                  color: _metrics!.tsb > 0 ? Colors.green : Colors.red, subtitle: 'Form'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Form: ${_metrics!.formLabel}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: _metrics!.tsb > 0 ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Achievements
                  const SizedBox(height: 24),
                  AchievementsGrid(
                    achievements: _achievements,
                    progress: _achievementProgress,
                    rides: _rides,
                  ),

                  // Recent Rides
                  const SizedBox(height: 24),
                  Text('Recent Rides', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),

                  if (_rides == null || _rides!.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: Text('No rides yet.\nStart riding to see your stats!', textAlign: TextAlign.center)),
                      ),
                    ),

                  ...(_rides?.map((ride) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.directions_bike, color: Colors.green),
                          title: Text(ride.route.routeName ?? 'Ride'),
                          subtitle: Text(
                            '${ride.actualDistanceKm.toStringAsFixed(1)} km · '
                            '${(ride.actualDurationSec / 60).round()} min · '
                            '${ride.avgSpeedKmh.toStringAsFixed(1)} km/h',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.share, size: 20),
                            tooltip: 'Share ride',
                            onPressed: () => RideShareService.shareRide(ride),
                          ),
                          onTap: () => RideShareService.shareRide(ride),
                        ),
                      )) ?? []),
                ],
              ),
            ),
    );
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatCard({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _TrainingMetric extends StatelessWidget {
  final String label, value;
  final Color color;
  final String? subtitle;
  const _TrainingMetric({required this.label, required this.value, required this.color, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
        if (subtitle != null) Text(subtitle!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey, fontSize: 10)),
      ],
    );
  }
}
