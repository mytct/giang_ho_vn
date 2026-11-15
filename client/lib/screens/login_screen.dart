import 'package:flutter/material.dart';

import '../api.dart';
import '../controller.dart';
import '../theme.dart';
import '../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.controller});

  final GameController controller;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _name = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _enter() async {
    final name = _name.text.trim();
    if (name.length < 2) {
      showToast(context, 'Tên gì ngắn vậy cha, ít nhất 2 ký tự', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      await widget.controller.login(name);
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _demo() async {
    setState(() => _loading = true);
    try {
      await widget.controller.demoLogin();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF120815), Color(0xFF0A0B10)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'GIANG HỒ',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: GH.pink,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      shadows: [
                        Shadow(color: GH.pink, blurRadius: 26),
                      ],
                    ),
                  ),
                  const Text(
                    'BỤI ĐỜI',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: GH.gold,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 12,
                      shadows: [Shadow(color: GH.gold, blurRadius: 18)],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Từ con đỏ giữ xe tới ông trùm quận.\nNuôi quân, chiếm địa bàn, thu tiền thiên hạ.',
                    textAlign: TextAlign.center,
                    style: labelStyle(size: 12.5),
                  ),
                  const SizedBox(height: 34),
                  NeonPanel(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                    child: TextField(
                      controller: _name,
                      maxLength: 20,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _enter(),
                      style: const TextStyle(
                          color: GH.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w700),
                      decoration: const InputDecoration(
                        counterText: '',
                        border: InputBorder.none,
                        hintText: 'Tên giang hồ của mày...',
                        hintStyle: TextStyle(color: GH.muted, fontSize: 15),
                        prefixIcon: Icon(Icons.badge_rounded,
                            color: GH.cyan, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: _loading ? 'ĐANG MỞ CỬA...' : 'NHẬP HỘI',
                    icon: Icons.local_fire_department_rounded,
                    enabled: !_loading,
                    onTap: _enter,
                    height: 52,
                  ),
                  const SizedBox(height: 10),
                  PrimaryButton(
                    label: _loading ? 'ĐANG MỞ...' : 'VÀO BẢN DEMO',
                    icon: Icons.science_rounded,
                    color: GH.cyan,
                    enabled: !_loading,
                    onTap: _demo,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Server: ${widget.controller.api.baseUrl}',
                    textAlign: TextAlign.center,
                    style: labelStyle(size: 10.5, color: GH.muted.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
