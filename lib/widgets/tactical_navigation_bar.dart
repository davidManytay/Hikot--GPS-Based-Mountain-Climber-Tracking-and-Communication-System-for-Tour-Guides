import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TacticalNavItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  TacticalNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

class TacticalNavigationBar extends StatelessWidget {
  final List<TacticalNavItem> items;
  final int currentIndex;

  const TacticalNavigationBar({
    super.key,
    required this.items,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: HikotColors.surface.withOpacity(0.85),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.08),
            width: 1,
          ),
        ),
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: SafeArea(
            top: false,
            child: Container(
              height: 72,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(items.length, (index) {
                  return _buildItem(context, items[index], index == currentIndex);
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, TacticalNavItem item, bool isActive) {
    final color = isActive ? HikotColors.accentTeal : HikotColors.textMuted;
    
    return Expanded(
      child: InkWell(
        onTap: item.onTap,
        splashColor: HikotColors.accentTeal.withOpacity(0.1),
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? HikotColors.accentTeal.withOpacity(0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                item.icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.label.toUpperCase(),
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w900 : FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            if (isActive) ...[
              const SizedBox(height: 4),
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: HikotColors.accentTeal,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: HikotColors.accentTeal,
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ] else 
              const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
