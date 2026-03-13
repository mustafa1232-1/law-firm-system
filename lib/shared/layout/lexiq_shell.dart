import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/localization/app_translations.dart';
import '../../theme/lexiq_colors.dart';
import '../widgets/glass_panel.dart';
import 'nav_items.dart';

class LexiqShell extends StatelessWidget {
  const LexiqShell({
    super.key,
    required this.child,
    required this.title,
  });

  final Widget child;
  final String title;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final isWide = MediaQuery.sizeOf(context).width >= 1080;

    return Scaffold(
      body: Stack(
        children: [
          const _Backdrop(),
          SafeArea(
            child: Row(
              children: [
                if (isWide)
                  _SideRail(currentLocation: location)
                      .animate()
                      .fade(duration: 500.ms)
                      .slideX(begin: 0.1),
                Expanded(
                  child: Column(
                    children: [
                      _TopBar(title: title, currentLocation: location),
                      Expanded(child: child),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      drawer: isWide ? null : _DrawerMenu(currentLocation: location),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            LexiqColors.obsidianBlack,
            LexiqColors.deepNavy,
            Color(0xFF0F1A34),
          ],
        ),
      ),
      child: CustomPaint(painter: _GridPainter()),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = LexiqColors.brassGold.withValues(alpha: 0.06)
      ..strokeWidth = 1;

    for (double x = 0; x <= size.width; x += 36) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y <= size.height; y += 36) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.title, required this.currentLocation});

  final String title;
  final String currentLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = MediaQuery.sizeOf(context).width >= 1080;
    final session = ref.watch(authControllerProvider).session;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            if (!isWide)
              Builder(
                builder: (context) {
                  return IconButton(
                    icon: const Icon(Icons.menu_rounded),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  );
                },
              ),
            Expanded(
              child: Text(
                context.tr(title),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              onPressed: () => context.go('/research'),
              icon: const Icon(Icons.search_rounded, color: LexiqColors.slateGray),
              tooltip: context.tr('Research'),
            ),
            IconButton(
              onPressed: () => context.go('/notifications'),
              icon: const Icon(Icons.notifications_none_rounded, color: LexiqColors.slateGray),
              tooltip: context.tr('Notifications'),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.account_circle_rounded, color: LexiqColors.slateGray),
              onSelected: (value) async {
                if (value == 'settings') {
                  context.go('/settings');
                  return;
                }
                if (value == 'logout') {
                  await ref.read(authControllerProvider.notifier).logout();
                  if (context.mounted) {
                    context.go('/auth/login');
                  }
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'profile',
                  enabled: false,
                  child: Text(
                    session?.user.email ?? context.tr('User'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'settings',
                  child: Text(context.tr('Settings')),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Text(context.tr('Logout')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SideRail extends StatelessWidget {
  const _SideRail({required this.currentLocation});

  final String currentLocation;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 290,
      padding: const EdgeInsets.all(16),
      child: GlassPanel(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Text(context.tr('LexIQ Iraq'), style: Theme.of(context).textTheme.headlineSmall),
            Text(
              context.tr('Iraqi Legal Intelligence'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            Expanded(
              child: ListView.separated(
                itemCount: appNavItems.length,
                separatorBuilder: (context, index) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final item = appNavItems[index];
                  final selected = currentLocation.startsWith(item.path);

                  return _NavButton(item: item, selected: selected);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerMenu extends StatelessWidget {
  const _DrawerMenu({required this.currentLocation});

  final String currentLocation;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: LexiqColors.deepNavy,
      child: SafeArea(
        child: ListView(
          children: [
            ListTile(
              title: Text(
                context.tr('LexIQ Iraq'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              subtitle: Text(context.tr('Iraqi Legal Intelligence Platform')),
            ),
            const Divider(height: 24),
            ...appNavItems.map((item) {
              final selected = currentLocation.startsWith(item.path);
              return _NavButton(item: item, selected: selected, isDrawer: true);
            }),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    this.isDrawer = false,
  });

  final AppNavItem item;
  final bool selected;
  final bool isDrawer;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      selected: selected,
      selectedTileColor: LexiqColors.imperialBlue.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Icon(item.icon, color: selected ? LexiqColors.brassGold : LexiqColors.slateGray),
      title: Text(
        context.tr(item.label),
        style: TextStyle(
          color: selected ? LexiqColors.ivoryText : LexiqColors.slateGray,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      onTap: () {
        if (isDrawer) {
          Navigator.of(context).pop();
        }
        context.go(item.path);
      },
    );
  }
}
