// lib/features/todos/todos_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/route_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/todo_provider.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/error_widget.dart';
import '../../shared/widgets/loading_widget.dart';
import '../../shared/widgets/top_app_bar_widget.dart';

enum TodoFilter { all, done, pending }

class TodosScreen extends StatefulWidget {
  const TodosScreen({super.key});

  @override
  State<TodosScreen> createState() => _TodosScreenState();
}

class _TodosScreenState extends State<TodosScreen> {
  TodoFilter _currentFilter = TodoFilter.all;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.9) {
      final token = context.read<AuthProvider>().authToken;
      if (token != null) {
        context.read<TodoProvider>().loadTodos(authToken: token, isRefresh: false);
      }
    }
  }

  void _loadData() {
    final token = context.read<AuthProvider>().authToken;
    if (token != null) {
      context.read<TodoProvider>().loadTodos(authToken: token, isRefresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TodoProvider>();
    final token    = context.read<AuthProvider>().authToken ?? '';
    final colorScheme = Theme.of(context).colorScheme;

    var displayTodos = provider.todos;
    if (_currentFilter == TodoFilter.done) {
      displayTodos = displayTodos.where((t) => t.isDone).toList();
    } else if (_currentFilter == TodoFilter.pending) {
      displayTodos = displayTodos.where((t) => !t.isDone).toList();
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: TopAppBarWidget(
        title: 'Todo Saya',
        withSearch: true,
        searchHint: 'Cari todo...',
        onSearchChanged: (query) {
          context.read<TodoProvider>().updateSearchQuery(query);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () => context
            .push(RouteConstants.todosAdd)
            .then((_) => _loadData()),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah Todo', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadData(),
        child: (provider.status == TodoStatus.loading || provider.status == TodoStatus.initial) && provider.todos.isEmpty
            ? const LoadingWidget(message: 'Memuat todo...')
            : (provider.status == TodoStatus.error && provider.todos.isEmpty)
            ? AppErrorWidget(message: provider.errorMessage, onRetry: _loadData)
            : Column(
          children: [
            // ── Filter SegmentedButton ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<TodoFilter>(
                  segments: const [
                    ButtonSegment(value: TodoFilter.all, label: Text('Semua')),
                    ButtonSegment(value: TodoFilter.done, label: Text('Selesai')),
                    ButtonSegment(value: TodoFilter.pending, label: Text('Belum')),
                  ],
                  selected: {_currentFilter},
                  onSelectionChanged: (Set<TodoFilter> newSelection) {
                    setState(() {
                      _currentFilter = newSelection.first;
                    });
                  },
                ),
              ),
            ),

            // ── Daftar Todo ──
            Expanded(
              child: displayTodos.isEmpty
                  ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.inbox_rounded,
                          size: 64,
                          color: colorScheme.primary.withOpacity(0.7)),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _currentFilter == TodoFilter.all
                          ? 'Belum ada todo hari ini.'
                          : 'Pencarian tidak ditemukan.',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currentFilter == TodoFilter.all
                          ? 'Ketuk tombol + di bawah untuk memulai.'
                          : 'Coba ubah kata kunci atau filter.',
                      style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
                    )
                  ],
                ),
              )
                  : ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100), // Padding bawah utk FAB
                itemCount: displayTodos.length + (provider.hasMore ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  if (i == displayTodos.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final todo = displayTodos[i];
                  return _TodoCard(
                    todo: todo,
                    onTap: () => context
                        .push(RouteConstants.todosDetail(todo.id))
                        .then((_) => _loadData()),
                    onToggle: () async {
                      final success = await provider.editTodo(
                        authToken:   token,
                        todoId:      todo.id,
                        title:       todo.title,
                        description: todo.description,
                        isDone:      !todo.isDone,
                      );
                      if (!success && mounted) {
                        showAppSnackBar(context,
                            message: provider.errorMessage,
                            type: SnackBarType.error);
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodoCard extends StatelessWidget {
  const _TodoCard({
    required this.todo,
    required this.onTap,
    required this.onToggle,
  });

  final todo; // Menggunakan tipe dynamic/var
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
          color: todo.isDone ? (isDark ? Colors.green.withOpacity(0.05) : Colors.green.shade50) : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: todo.isDone ? Colors.green.withOpacity(0.3) : colorScheme.outlineVariant.withOpacity(0.5),
          ),
          boxShadow: [
            if (!todo.isDone)
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.1 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
          ]
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: GestureDetector(
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: todo.isDone ? Colors.green : Colors.transparent,
                border: Border.all(
                    color: todo.isDone ? Colors.green : colorScheme.outline,
                    width: 2
                )
            ),
            child: Icon(
              Icons.check_rounded,
              color: todo.isDone ? Colors.white : Colors.transparent,
              size: 20,
            ),
          ),
        ),
        title: Text(
          todo.title,
          style: TextStyle(
            decoration: todo.isDone ? TextDecoration.lineThrough : null,
            decorationColor: Colors.green,
            decorationThickness: 2,
            color: todo.isDone ? colorScheme.onSurface.withOpacity(0.5) : colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
              todo.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: todo.isDone ? colorScheme.onSurface.withOpacity(0.4) : colorScheme.onSurfaceVariant,
              )
          ),
        ),
      ),
    );
  }
}