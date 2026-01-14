import 'package:flutter/material.dart';

/// Responsive layout widget that adapts to screen size
/// Shows side-by-side layout on desktop and stacked layout on mobile
class SearchResponsiveLayout extends StatelessWidget {
  final Widget searchBar;
  final Widget resultsList;
  final Widget? detailsPanel;

  const SearchResponsiveLayout({
    Key? key,
    required this.searchBar,
    required this.resultsList,
    this.detailsPanel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 900;

        if (isDesktop && detailsPanel != null) {
          // Desktop: Side-by-side
          return Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  children: [searchBar, Expanded(child: resultsList)],
                ),
              ),
              Expanded(
                flex: 3,
                child: detailsPanel!,
              ),
            ],
          );
        }

        // Mobile: Stacked
        return Column(
          children: [
            searchBar,
            Expanded(child: resultsList),
          ],
        );
      },
    );
  }
}