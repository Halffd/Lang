import 'package:flutter/material.dart';
import 'package:lang/utils/screen_size.dart';

class SearchResponsiveLayout extends StatelessWidget {
  final Widget searchBar;
  final Widget results;
  final Widget? sidePanel;
  final bool showSidePanel;

  const SearchResponsiveLayout({
    super.key,
    required this.searchBar,
    required this.results,
    this.sidePanel,
    this.showSidePanel = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 800;

        if (isWide && showSidePanel && sidePanel != null) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _buildMainColumn(context)),
              const VerticalDivider(thickness: 1, width: 1),
              SizedBox(width: 320, child: sidePanel!),
            ],
          );
        }

        return _buildMainColumn(context);
      },
    );
  }

  Widget _buildMainColumn(BuildContext context) {
    return Column(
      children: [
        searchBar,
        const SizedBox(height: 8),
        Expanded(child: results),
      ],
    );
  }
}
