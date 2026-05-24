import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      setState(() { _loading = true; _error = null; });
      final routes = await _routeRepository.getSavedRoutes();
      if (mounted) setState(() { _routes = routes; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _deleteRoute(CyclingRoute route) async {
    if (route.id == null) return;
    await _routeRepository.deleteRoute(route.id!);
    await _loadRoutes();
    HapticFeedback.lightImpact();
  }

  Future<void> _renameRoute(CyclingRoute route) async {
    final controller = TextEditingController(text: route.routeName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Route'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Route name',
            prefixIcon: Icon(Icons.edit),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Save')),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty && route.id != null) {
      route = route.copyWith(routeName: newName);
      await _routeRepository.saveRoute(route, routeName: newName);
      await _loadRoutes();
      HapticFeedback.lightImpact();
    }
  }

  String _formatDistance(double km) => km >= 1.0 ? '${km.toStringAsFixed(1)} km' : '${(km * 1000).round()} m';
  String _formatDuration(double minutes) {
    final h = minutes ~/ 60, m = (minutes % 60).round();
    return h > 0 ? '${h}h ${m}m' : '$m min';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Routes')),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
        const SizedBox(height: 16),
        Text('Failed to load routes', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        FilledButton.icon(onPressed: _loadRoutes, icon: const Icon(Icons.refresh), label: const Text('Retry')),
      ]));
    }
    if (_routes == null || _routes!.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.route, size: 64, color: theme.colorScheme.onSurface.withAlpha(100)),
        const SizedBox(height: 16),
        Text('No saved routes yet', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurface.withAlpha(150))),
      ]));
    }
    return RefreshIndicator(
      onRefresh: _loadRoutes,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _routes!.length,
        itemBuilder: (context, index) {
          final route = _routes![index];
          return TweenAnimationBuilder<double>(
            duration: Duration(milliseconds: 350 + (index * 60)),
            tween: Tween(begin: 0.0, end: 1.0),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 30 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: _buildRouteCard(route, theme),
          );
        },
      ),
    );
  }

  Widget _buildRouteCard(CyclingRoute route, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (route.id != null) context.push('/route/${route.id}', extra: route);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(route.routeName ?? 'Unnamed Route',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              IconButton(
                icon: Icon(Icons.edit_outlined, color: colorScheme.onSurface.withAlpha(120)),
                onPressed: () => _renameRoute(route),
                tooltip: 'Rename',
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: colorScheme.error),
                onPressed: () => _confirmDelete(route),
                tooltip: 'Delete',
                visualDensity: VisualDensity.compact,
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _statChip(Icons.straighten, _formatDistance(route.distanceKm), theme),
              const SizedBox(width: 16),
              _statChip(Icons.timer_outlined, _formatDuration(route.estimatedTimeMin), theme),
              const SizedBox(width: 16),
              _statChip(Icons.terrain, '${route.ascentM?.round() ?? 0} m', theme),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String text, ThemeData theme) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16, color: theme.colorScheme.onSurface.withAlpha(150)),
      const SizedBox(width: 4),
      Text(text, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withAlpha(180))),
    ]);
  }

  void _confirmDelete(CyclingRoute route) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Route'),
        content: Text('Delete "${route.routeName ?? 'this route'}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () { Navigator.pop(ctx); _deleteRoute(route); },
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
