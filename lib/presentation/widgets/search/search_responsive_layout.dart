import 'package:flutter/material.dart';
import '../../../utils/screen_size.dart';

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
        final screenType = ScreenSize.type(context);
        final width = constraints.maxWidth;

        if (width > 900 && detailsPanel != null) {
          return Row(
            children: [
              Expanded(
                flex: screenType == ScreenType.compact ? 3 : 2,
                child: Column(
                  children: [searchBar, Expanded(child: resultsList)],
                ),
              ),
              Expanded(
                flex: screenType == ScreenType.compact ? 2 : 3,
                child: detailsPanel!,
              ),
            ],
          );
        }

        if (width > 600 && detailsPanel != null) {
          return Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  children: [searchBar, Expanded(child: resultsList)],
                ),
              ),
              Expanded(
                flex: 2,
                child: detailsPanel!,
              ),
            ],
          );
        }

        final pad = ScreenSize.adaptivePadding(context);

        return Padding(
          padding: EdgeInsets.only(left: pad.left, right: pad.right),
          child: Column(
            children: [
              searchBar,
              Expanded(child: resultsList),
            ],
          ),
        );
      },
    );
  }
}
