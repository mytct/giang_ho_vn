import 'package:flutter/material.dart';

import 'controller.dart';
import 'screens/crew_screen.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/ranking_screen.dart';
import 'screens/shop_screen.dart';
import 'theme.dart';
import 'widgets/common.dart';

class Shell extends StatefulWidget {
  const Shell({super.key, required this.controller});

  final GameController controller;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(controller: widget.controller),
      MapScreen(controller: widget.controller),
      CrewScreen(controller: widget.controller),
      ShopScreen(controller: widget.controller),
      RankingScreen(controller: widget.controller),
    ];
    widget.controller.loadMap().catchError((Object _) {});
    widget.controller.loadRanking().catchError((Object _) {});
    widget.controller.loadCampaign().catchError((Object _) {});
    widget.controller.loadGangs().catchError((Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: PixelGrid()),
          SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: IndexedStack(index: _index, children: _screens),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: GH.panel,
          border: Border(top: BorderSide(color: GH.ink, width: 2)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 58,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Row(
                  children: [
                    _NavItem(
                      icon: Icons.storefront_rounded,
                      label: 'Bang',
                      active: _index == 0,
                      onTap: () => _go(0),
                    ),
                    _NavItem(
                      icon: Icons.map_rounded,
                      label: 'Bản đồ',
                      active: _index == 1,
                      onTap: () => _go(1),
                    ),
                    _NavItem(
                      icon: Icons.groups_rounded,
                      label: 'Quân',
                      active: _index == 2,
                      onTap: () => _go(2),
                    ),
                    _NavItem(
                      icon: Icons.local_fire_department_rounded,
                      label: 'Chợ đen',
                      active: _index == 3,
                      onTap: () => _go(3),
                    ),
                    _NavItem(
                      icon: Icons.military_tech_rounded,
                      label: 'Băng',
                      active: _index == 4,
                      onTap: () => _go(4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _go(int index) {
    setState(() => _index = index);
    if (index == 1) widget.controller.loadMap().catchError((Object _) {});
    if (index == 4) {
      widget.controller.loadRanking().catchError((Object _) {});
    widget.controller.loadCampaign().catchError((Object _) {});
    widget.controller.loadGangs().catchError((Object _) {});
      widget.controller.loadGangs().catchError((Object _) {});
    }
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? GH.pink : GH.muted;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.fromLTRB(3, 4, 3, 4),
          decoration: BoxDecoration(
            color: active ? GH.pink.withValues(alpha: 0.10) : Colors.transparent,
            border: Border(
              top: BorderSide(
                  color: active ? GH.pink : Colors.transparent, width: 2),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 3),
              Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: GH.pixelFont,
                  color: color,
                  fontSize: 8.5,
                  fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
