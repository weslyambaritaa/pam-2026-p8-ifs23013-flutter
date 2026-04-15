// lib/providers/todo_provider.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../data/models/todo_model.dart';
import '../data/models/api_response_model.dart';
import '../data/services/todo_repository.dart';

enum TodoStatus { initial, loading, success, error, loadingMore }

class TodoProvider extends ChangeNotifier {
  TodoProvider({TodoRepository? repository})
      : _repository = repository ?? TodoRepository();

  final TodoRepository _repository;

  // ── State ────────────────────────────────────
  TodoStatus _status = TodoStatus.initial;
  List<TodoModel> _todos = [];
  TodoModel? _selectedTodo;
  String _errorMessage = '';
  String _searchQuery = '';

  // ── State Paginasi ───────────────────────────
  int _currentPage = 1;
  final int _perPage = 10;
  bool _hasMore = true;

  // ── Getters ──────────────────────────────────
  TodoStatus get status       => _status;
  TodoModel? get selectedTodo => _selectedTodo;
  String get errorMessage     => _errorMessage;
  bool get hasMore            => _hasMore;

  List<TodoModel> get todos {
    if (_searchQuery.isEmpty) return List.unmodifiable(_todos);
    return _todos
        .where((t) =>
        t.title.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  int get totalTodos   => _todos.length;
  int get doneTodos    => _todos.where((t) => t.isDone).length;
  int get pendingTodos => _todos.where((t) => !t.isDone).length;

  // ── Load All Todos (Dengan Paginasi) ─────────
  Future<void> loadTodos({
    required String authToken,
    bool isRefresh = true,
  }) async {
    // Jika refresh, reset semua data ke awal
    if (isRefresh) {
      _status = TodoStatus.loading;
      _currentPage = 1;
      _hasMore = true;
      _todos = [];
    } else {
      // Jika memuat data berikutnya dan sedang loading atau sudah tidak ada data, batalkan
      if (_status == TodoStatus.loadingMore || !_hasMore) return;
      _status = TodoStatus.loadingMore;
      _currentPage++;
    }

    notifyListeners();

    final result = await _repository.getTodos(
      authToken: authToken,
      page: _currentPage,
      perPage: _perPage,
    );

    if (result.success && result.data != null) {
      final List<TodoModel> newTodos = result.data!;

      if (isRefresh) {
        _todos = newTodos;
      } else {
        _todos.addAll(newTodos);
      }

      // Jika data yang datang kurang dari perPage, berarti sudah habis
      if (newTodos.length < _perPage) {
        _hasMore = false;
      }

      _setStatus(TodoStatus.success);
    } else {
      _errorMessage = result.message;
      _setStatus(TodoStatus.error);
    }
  }

  // ── Load Single Todo ──────────────────────────
  Future<void> loadTodoById({
    required String authToken,
    required String todoId,
  }) async {
    _setStatus(TodoStatus.loading);
    final result = await _repository.getTodoById(
        authToken: authToken, todoId: todoId);
    if (result.success && result.data != null) {
      _selectedTodo = result.data;
      _setStatus(TodoStatus.success);
    } else {
      _errorMessage = result.message;
      _setStatus(TodoStatus.error);
    }
  }

  // ── Create Todo ───────────────────────────────
  Future<bool> addTodo({
    required String authToken,
    required String title,
    required String description,
  }) async {
    _setStatus(TodoStatus.loading);
    final result = await _repository.createTodo(
      authToken:   authToken,
      title:       title,
      description: description,
    );
    if (result.success) {
      // Ambil ulang data sebanyak item yang sudah di-load agar list tidak terpotong
      final listResult = await _repository.getTodos(
        authToken: authToken,
        page: 1,
        perPage: _currentPage * _perPage,
      );
      if (listResult.success && listResult.data != null) {
        _todos = listResult.data!;
      }
      _setStatus(TodoStatus.success);
      return true;
    }
    _errorMessage = result.message;
    _setStatus(TodoStatus.error);
    return false;
  }

  // ── Update Todo ───────────────────────────────
  Future<bool> editTodo({
    required String authToken,
    required String todoId,
    required String title,
    required String description,
    required bool isDone,
  }) async {
    _setStatus(TodoStatus.loading);
    final result = await _repository.updateTodo(
      authToken:   authToken,
      todoId:      todoId,
      title:       title,
      description: description,
      isDone:      isDone,
    );
    if (result.success) {
      // Fetch keduanya dulu, baru notify sekali
      final results = await Future.wait([
        _repository.getTodoById(authToken: authToken, todoId: todoId),
        _repository.getTodos(
          authToken: authToken,
          page: 1,
          perPage: _currentPage * _perPage,
        ),
      ]);

      final detailResult = results[0];
      final listResult   = results[1] as ApiResponse<List<TodoModel>>;

      if (detailResult.success && detailResult.data != null) {
        _selectedTodo = detailResult.data as TodoModel;
      }
      if (listResult.success && listResult.data != null) {
        _todos = listResult.data!;
      }

      // Notify hanya sekali setelah semua data siap
      _setStatus(TodoStatus.success);
      return true;
    }
    _errorMessage = result.message;
    _setStatus(TodoStatus.error);
    return false;
  }

  // ── Update Cover ──────────────────────────────
  Future<bool> updateCover({
    required String authToken,
    required String todoId,
    File? imageFile,
    Uint8List? imageBytes,
    String imageFilename = 'cover.jpg',
  }) async {
    _setStatus(TodoStatus.loading);
    final result = await _repository.updateTodoCover(
      authToken:     authToken,
      todoId:        todoId,
      imageFile:     imageFile,
      imageBytes:    imageBytes,
      imageFilename: imageFilename,
    );
    if (result.success) {
      // Fetch keduanya dulu, baru notify sekali
      final results = await Future.wait([
        _repository.getTodoById(authToken: authToken, todoId: todoId),
        _repository.getTodos(
          authToken: authToken,
          page: 1,
          perPage: _currentPage * _perPage,
        ),
      ]);

      final detailResult = results[0];
      final listResult   = results[1] as ApiResponse<List<TodoModel>>;

      if (detailResult.success && detailResult.data != null) {
        _selectedTodo = detailResult.data as TodoModel;
      }
      if (listResult.success && listResult.data != null) {
        _todos = listResult.data!;
      }

      // Notify hanya sekali setelah semua data siap
      _setStatus(TodoStatus.success);
      return true;
    }
    _errorMessage = result.message;
    _setStatus(TodoStatus.error);
    return false;
  }

  // ── Delete Todo ───────────────────────────────
  Future<bool> removeTodo({
    required String authToken,
    required String todoId,
  }) async {
    _setStatus(TodoStatus.loading);
    final result = await _repository.deleteTodo(
        authToken: authToken, todoId: todoId);
    if (result.success) {
      // Hapus dari list lokal langsung tanpa fetch ulang
      _todos.removeWhere((t) => t.id == todoId);
      _selectedTodo = null;
      _setStatus(TodoStatus.success);
      return true;
    }
    _errorMessage = result.message;
    _setStatus(TodoStatus.error);
    return false;
  }

  // ── Search ────────────────────────────────────
  void updateSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearSelectedTodo() {
    _selectedTodo = null;
    notifyListeners();
  }

  void _setStatus(TodoStatus status) {
    if (_status != status) {
      _status = status;
      notifyListeners();
    }
  }
}