// lib/features/home/home_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/route_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/todo_provider.dart';
import '../../providers/theme_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final token = context.read<AuthProvider>().authToken;
      if (token != null) {
        context.read<TodoProvider>().loadTodos(authToken: token);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme  = Theme.of(context).colorScheme;
    final user         = context.watch<AuthProvider>().user;
    final provider     = context.watch<TodoProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final isDark       = themeProvider.isDark;

    final total = provider.totalTodos;
    final done = provider.doneTodos;
    final pending = provider.pendingTodos;

    final donePercent = total == 0 ? 0.0 : (done / total);
    final pendingPercent = total == 0 ? 0.0 : (pending / total);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Halo, ${user?.name ?? '—'} 👋',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
            ),
            Text(
              'Kelola todo-mu hari ini',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.6)
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              ),
              onPressed: () => themeProvider.toggleTheme(),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final token = context.read<AuthProvider>().authToken;
          if (token != null) {
            await context.read<TodoProvider>().loadTodos(authToken: token);
          }
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            // ── Statistik Card ──
            Row(
              children: [
                _StatCard(
                  label: 'Total',
                  value: total,
                  bgColor: colorScheme.primaryContainer,
                  textColor: colorScheme.onPrimaryContainer,
                  icon: Icons.list_alt_rounded,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: 'Selesai',
                  value: done,
                  bgColor: isDark ? Colors.green.withOpacity(0.2) : Colors.green.shade50,
                  textColor: Colors.green,
                  icon: Icons.check_circle_rounded,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: 'Belum',
                  value: pending,
                  bgColor: isDark ? Colors.orange.withOpacity(0.2) : Colors.orange.shade50,
                  textColor: Colors.orange,
                  icon: Icons.pending_rounded,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ── Indikator Progres ──
            Text(
              'Progres Todo',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ]
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bar Selesai
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
                            const SizedBox(width: 8),
                            Text('Selesai', style: TextStyle(fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
                          ],
                        ),
                        Text('${(donePercent * 100).toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: donePercent,
                        backgroundColor: Colors.green.withOpacity(0.15),
                        color: Colors.green,
                        minHeight: 10,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Bar Belum Selesai
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.pending_rounded, color: Colors.orange, size: 18),
                            const SizedBox(width: 8),
                            Text('Belum Selesai', style: TextStyle(fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
                          ],
                        ),
                        Text('${(pendingPercent * 100).toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: pendingPercent,
                        backgroundColor: Colors.orange.withOpacity(0.15),
                        color: Colors.orange,
                        minHeight: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // ── Shortcut ke Todos ──
            Text(
              'Akses Cepat',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _QuickAccessCard(
              icon: Icons.checklist_rounded,
              title: 'Daftar Todo',
              subtitle: 'Lihat dan kelola semua todo-mu',
              color: colorScheme.primary,
              onTap: () => context.go(RouteConstants.todos),
            ),
            const SizedBox(height: 12),
            _QuickAccessCard(
              icon: Icons.add_task_rounded,
              title: 'Todo Baru',
              subtitle: 'Tambahkan todo baru',
              color: colorScheme.tertiary,
              onTap: () => context.push(RouteConstants.todosAdd),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.bgColor,
    required this.textColor,
    required this.icon,
  });

  final String label;
  final int value;
  final Color bgColor;
  final Color textColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: textColor, size: 28),
            const SizedBox(height: 12),
            Text(
              '$value',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
                label,
                style: TextStyle(
                  color: textColor.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                )
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  const _QuickAccessCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(isDark ? 0.1 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ]
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 24, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}