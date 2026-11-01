import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/utils/font_scale.dart';
import 'package:lang/utils/screen_size.dart';

/// Bottom bar for the app's top-level sections.
///
/// On narrow displays (mobile) the eleven destinations cannot fit side by
/// side, so they are laid out in a horizontally scrolling icon-only strip.
/// When there is enough room each destination shows its label under the
/// icon — but only when the effective UI font scale keeps the label inside
/// the slot, so zooming in degrades to icon-only instead of colliding text.
class BottomBar extends StatelessWidget {
  const BottomBar({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<DestinationEntry> destinations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: SizedBox(
          // compact height on mobile portrait, standard on desktop
          height: ScreenSize.isCompact(context) ? 56 : 68,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final perSlot = constraints.maxWidth / destinations.length;
              // label fits only when the slot is wide enough for the
              // longest label at the zoomed font size
              final showLabels = perSlot >= 96;
              if (showLabels) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    for (final entry in destinations)
                      Expanded(
                        child: _DestinationTile(
                          entry: entry,
                          selected: destinations.indexOf(entry) == currentIndex,
                          onTap: () => onDestinationSelected(
                            destinations.indexOf(entry),
                          ),
                        ),
                      ),
                  ],
                );
              }
              // Narrow: icon-only, horizontally scrollable.
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                itemCount: destinations.length,
                itemBuilder: (context, index) {
                  return SizedBox(
                    width: 56,
                    child: _DestinationTile(
                      entry: destinations[index],
                      selected: index == currentIndex,
                      onTap: () => onDestinationSelected(index),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Destination shown in [BottomBar].
class DestinationEntry {
  const DestinationEntry({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Single destination button inside [BottomBar].
class _DestinationTile extends StatelessWidget {
  const _DestinationTile({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final DestinationEntry entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effective = fs(context, 10).clamp(8.0, 22.0);
    // label only when the zoomed text still fits the slot
    final showLabel = effective <= 14;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            entry.icon,
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.55),
          ),
          if (showLabel && entry.label.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              entry.label,
              style: TextStyle(
                fontSize: effective,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
