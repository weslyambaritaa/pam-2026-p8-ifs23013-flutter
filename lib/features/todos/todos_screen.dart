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

// Enum untuk status filter
enum TodoFilter { all, done, pending }

class TodosScreen extends StatefulWidget {
  const TodosScreen({super.key});

  @override
  State<TodosScreen> createState() => _TodosScreenState();
}

class _TodosScreenState extends State<TodosScreen> {
  // State untuk filter dan scroll
  TodoFilter _currentFilter = TodoFilter.all;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Tambahkan listener untuk mendeteksi scroll mentok ke bawah
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    // Pastikan membuang controller untuk mencegah memory leak
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Cek apakah scroll sudah mencapai 90% dari total panjang konten bawah
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.9) {
      final token = context.read<AuthProvider>().authToken;
      if (token != null) {
        // Panggil loadTodos untuk memuat data selanjutnya (tanpa mereset list)
        context.read<TodoProvider>().loadTodos(authToken: token, isRefresh: false);
      }
    }
  }

  void _loadData() {
    final token = context.read<AuthProvider>().authToken;
    if (token != null) {
      // Memuat ulang data dari halaman 1
      context.read<TodoProvider>().loadTodos(authToken: token, isRefresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TodoProvider>();
    final token    = context.read<AuthProvider>().authToken ?? '';

    // Logika filter lokal berdasarkan state UI
    var displayTodos = provider.todos;
    if (_currentFilter == TodoFilter.done) {
      displayTodos = displayTodos.where((t) => t.isDone).toList();
    } else if (_currentFilter == TodoFilter.pending) {
      displayTodos = displayTodos.where((t) => !t.isDone).toList();
    }

    return Scaffold(
      appBar: TopAppBarWidget(
        title: 'Todo Saya',
        withSearch: true,
        searchHint: 'Cari todo...',
        onSearchChanged: (query) {
          context.read<TodoProvider>().updateSearchQuery(query);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context
            .push(RouteConstants.todosAdd)
            .then((_) => _loadData()),
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadData(),
        // Jika sedang initial loading dan data kosong, tampilkan layar loading
        child: (provider.status == TodoStatus.loading || provider.status == TodoStatus.initial) && provider.todos.isEmpty
            ? const LoadingWidget(message: 'Memuat todo...')
            : (provider.status == TodoStatus.error && provider.todos.isEmpty)
            ? AppErrorWidget(message: provider.errorMessage, onRetry: _loadData)
            : Column(
          children: [
            // ── Filter SegmentedButton ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<TodoFilter>(
                  segments: const [
                    ButtonSegment(
                      value: TodoFilter.all,
                      label: Text('Semua'),
                    ),
                    ButtonSegment(
                      value: TodoFilter.done,
                      label: Text('Selesai'),
                    ),
                    ButtonSegment(
                      value: TodoFilter.pending,
                      label: Text('Belum'),
                    ),
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
                    Icon(Icons.inbox_outlined,
                        size: 64,
                        color: Theme.of(context).colorScheme.outline),
                    const SizedBox(height: 16),
                    Text(
                      _currentFilter == TodoFilter.all
                          ? 'Belum ada todo.\nKetuk + untuk menambahkan.'
                          : 'Tidak ada todo yang sesuai dengan filter ini.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
                  : ListView.separated(
                controller: _scrollController, // Pasang controller untuk paginasi
                padding: const EdgeInsets.all(16),
                // Tambah 1 item slot di paling bawah jika masih ada data (hasMore)
                itemCount: displayTodos.length + (provider.hasMore ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  // Jika index mencapai panjang data displayTodos, tampilkan indikator loading
                  if (i == displayTodos.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
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
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: GestureDetector(
          onTap: onToggle,
          child: Icon(
            todo.isDone
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: todo.isDone ? Colors.green : colorScheme.outline,
            size: 28,
          ),
        ),
        title: Text(
          todo.title,
          style: TextStyle(
            decoration: todo.isDone ? TextDecoration.lineThrough : null,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          todo.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
      ),
    );
  }
}