// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Tambahkan import ini
import 'app_router.dart';
import 'providers/auth_provider.dart';
import 'providers/todo_provider.dart';
import 'providers/theme_provider.dart';

// Ubah main menjadi async
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ambil instance SharedPreferences sebelum aplikasi berjalan
  final prefs = await SharedPreferences.getInstance();

  runApp(
    MultiProvider(
      providers: [
        // Masukkan prefs ke dalam ThemeProvider
        ChangeNotifierProvider(create: (_) => ThemeProvider(prefs)),
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider(create: (_) => TodoProvider()),
      ],
      child: const DelcomTodosApp(),
    ),
  );
}

class DelcomTodosApp extends StatefulWidget {
  const DelcomTodosApp({super.key});

  @override
  State<DelcomTodosApp> createState() => _DelcomTodosAppState();
}

class _DelcomTodosAppState extends State<DelcomTodosApp> {
  late final _router = buildRouter(context);

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp.router(
      title: 'Delcom Todos',
      debugShowCheckedModeBanner: false,
      // Terapkan mode tema dan properti temanya
      themeMode: themeProvider.themeMode,
      theme: themeProvider.lightTheme,
      darkTheme: themeProvider.darkTheme,
      routerConfig: _router,
    );
  }
}