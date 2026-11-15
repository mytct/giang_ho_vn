import 'package:flutter/material.dart';

import 'api.dart';
import 'controller.dart';
import 'screens/login_screen.dart';
import 'shell.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GiangHoApp());
}

class GiangHoApp extends StatefulWidget {
  const GiangHoApp({super.key});

  @override
  State<GiangHoApp> createState() => _GiangHoAppState();
}

class _GiangHoAppState extends State<GiangHoApp> {
  late final GameController _controller;

  @override
  void initState() {
    super.initState();
    _controller = GameController(ApiClient());
    _controller.tryRestore();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Giang Hồ Bụi Đời',
      debugShowCheckedModeBanner: false,
      theme: GH.theme(),
      home: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.booting) return const _BootScreen();
          if (!_controller.loggedIn) {
            return LoginScreen(controller: _controller);
          }
          return Shell(controller: _controller);
        },
      ),
    );
  }
}

class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF120815), Color(0xFF0A0B10)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'GIANG HỒ',
                style: TextStyle(
                  color: GH.pink,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
              SizedBox(height: 18),
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: GH.cyan,
                  strokeWidth: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
