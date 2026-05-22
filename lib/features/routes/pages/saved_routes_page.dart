import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cyclezen/domain/models/models.dart';
import 'package:cyclezen/data/repositories/route_repository.dart';

class SavedRoutesPage extends StatefulWidget {
  const SavedRoutesPage({super.key});

  @override
  State<SavedRoutesPage> createState() => _SavedRoutesPageState();
}

class _SavedRoutesPageState extends State<SavedRoutesPage> {
  final RouteRepository _routeRepository = RouteRepository();
  List<CyclingRoute>? _routes;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });
      final routes = await _routeRepository.getSavedRoutes();
      setState(() {
        _routes = routes;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _deleteRoute(CyclingRoute route) async {
    if (route.id == null) return;
    await _routeRepository.deleteRoute(route.id!);
    await _loadRoutes();
  }

  String _formatDistance(double km) {
    if (km >= 1.0) {
      return '${km.toStringAsFixed(1)} km';
    }
    return '${(km * 1000).round()} m';
  }

  String _formatDuration(double minutes) {
    final hours = minutes ~/ 60;
    final mins = (minutes % 60).round();
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '$mins min';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Routes'),
        backgroundColor: colorScheme.surface,
      ),
      body: _buildBody(colorScheme, theme),
    );
  }

  Widget _buildBody(ColorScheme colorScheme, ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 16),
            Text('Failed to load routes', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(_error!, style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadRoutes,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_routes == null || _routes!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.route, size: 64, color: colorScheme.onSurface.withAlpha(100)),
            const SizedBox(height: 16),
            Text(
              'No saved routes yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface.withAlpha(150),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Generated routes will appear here',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withAlpha(100),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRoutes,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _routes!.length,
        itemBuilder: (context, index) {
          final route = _routes![index];
          return _buildRouteCard(route, colorScheme, theme);
        },
      ),
    );
  }

  Widget _buildRouteCard(CyclingRoute route, ColorScheme colorScheme, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (route.id != null) {
            context.push('/route/${route.id}', extra: route);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      route.routeName ?? 'Unnamed Route',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: colorScheme.error),
                    onPressed: () => _confirmDelete(route),
                    tooltip: 'Delete route',
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: colorScheme.onSurface.withAlpha(100),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _statChip(
                    Icons.straighten,
                    _formatDistance(route.distanceKm),
                    colorScheme,
                    theme,
                  ),
                  const SizedBox(width: 16),
                  _statChip(
                    Icons.timer_outlined,
                    _formatDuration(route.estimatedTimeMin),
                    colorScheme,
                    theme,
                  ),
                  const SizedBox(width: 16),
                  _statChip(
                    Icons.terrain,
                    '${route.ascentM?.round() ?? 0} m',
                    colorScheme,
                    theme,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String text, ColorScheme colorScheme, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: colorScheme.onSurface.withAlpha(150)),
        const SizedBox(width: 4),
        Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withAlpha(180),
          ),
        ),
      ],
    );
  }

  void _confirmDelete(CyclingRoute route) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Route'),
        content: Text('Delete "${route.routeName ?? 'this route'}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _deleteRoute(route);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
