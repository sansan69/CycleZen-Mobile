import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cyclezen/core/theme/app_theme.dart';
import 'package:cyclezen/core/di/injection.dart';
import 'package:cyclezen/data/repositories/route_repository.dart';
import 'package:cyclezen/features/auth/bloc/auth_bloc.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _nameController = TextEditingController();
  final _weightController = TextEditingController();
  bool _backingUp = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthBloc>().state;
    if (auth is AuthStateAuthenticated) {
      _nameController.text = auth.user.displayName ?? '';
      _weightController.text = auth.user.weightKg?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _backupToCloud() async {
    if (!mounted) return;
    setState(() => _backingUp = true);
    try {
      final result = await RouteRepository().syncLocalToCloud();
      if (mounted) {
        setState(() => _backingUp = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup complete — ${result['routes']} routes, ${result['rides']} rides synced'),
            backgroundColor: AppTheme.greenAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _backingUp = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is AuthStateAuthenticated) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: AppTheme.greenAccent,
                    child: Icon(Icons.person, size: 50, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(state.user.email ?? '', style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 32),

                  // Theme toggle
                  _ThemeSelector(),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Display Name', prefixIcon: Icon(Icons.badge)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _weightController,
                    decoration: const InputDecoration(labelText: 'Weight (kg)', prefixIcon: Icon(Icons.monitor_weight)),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      final weight = double.tryParse(_weightController.text);
                      context.read<AuthBloc>().add(AuthEventUpdateProfile(
                            displayName: _nameController.text, weightKg: weight));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profile updated!'), backgroundColor: Colors.green),
                      );
                    },
                    child: const Text('Save Profile'),
                  ),
                  const SizedBox(height: 20),

                  // ── Manual Backup ──
                  OutlinedButton.icon(
                    onPressed: _backingUp ? null : _backupToCloud,
                    icon: _backingUp
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.cloud_upload),
                    label: Text(_backingUp ? 'Backing up...' : 'Backup to Google Account'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  const SizedBox(height: 12),

                  OutlinedButton.icon(
                    onPressed: () => context.read<AuthBloc>().add(const AuthEventSignOut()),
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text('Sign Out', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
          }
          if (state is AuthStateUnauthenticated) {
            return Center(
              child: ElevatedButton(
                onPressed: () => context.pushNamed('auth'),
                child: const Text('Sign In'),
              ),
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}

class _ThemeSelector extends StatefulWidget {
  @override
  State<_ThemeSelector> createState() => _ThemeSelectorState();
}

class _ThemeSelectorState extends State<_ThemeSelector> {
  late ThemeModeNotifier _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = getIt<ThemeModeNotifier>();
    _notifier.addListener(_onChange);
  }

  @override
  void dispose() {
    _notifier.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() { if (mounted) setState(() {}); }

  @override
  Widget build(BuildContext context) {
    final mode = _notifier.value;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Theme', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 10),
      SegmentedButton<ThemeMode>(
        segments: const [
          ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.settings_brightness), label: Text('System')),
          ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode), label: Text('Light')),
          ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode), label: Text('Dark')),
        ],
        selected: {mode},
        onSelectionChanged: (s) => _notifier.setMode(s.first),
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        ),
      ),
    ]);
  }
}
