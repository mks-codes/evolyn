import 'package:flutter/material.dart';

class EvolynBottomNavigation extends StatelessWidget {
  const EvolynBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  static const _items = <_NavigationItemData>[
    _NavigationItemData(Icons.home_rounded, 'Home'),
    _NavigationItemData(Icons.map_outlined, 'Roadmap'),
    _NavigationItemData(Icons.auto_awesome, 'Mentor'),
    _NavigationItemData(Icons.menu_book_outlined, 'Learn'),
    _NavigationItemData(Icons.bar_chart_rounded, 'Progress'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      decoration: BoxDecoration(
        color: const Color(0xFF08091A),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.08),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_items.length, (index) {
          final item = _items[index];
          final selected = selectedIndex == index;

          return Expanded(
            child: Semantics(
              button: true,
              selected: selected,
              label: item.label,
              child: InkWell(
                onTap: () => onItemSelected(index),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      item.icon,
                      size: 21,
                      color: selected
                          ? const Color(0xFFA78BFA)
                          : const Color(0xFF6F7185),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected
                            ? const Color(0xFFA78BFA)
                            : const Color(0xFF6F7185),
                        fontSize: 10,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _NavigationItemData {
  final IconData icon;
  final String label;

  const _NavigationItemData(this.icon, this.label);
}
