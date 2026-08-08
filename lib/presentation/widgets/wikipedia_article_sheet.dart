import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import '../../../data/datasources/remote/wikipedia_service.dart';

class WikipediaArticleSheet extends StatefulWidget {
  final String term;
  final String languageCode;

  const WikipediaArticleSheet({
    required this.term,
    this.languageCode = 'ja',
    super.key,
  });

  @override
  State<WikipediaArticleSheet> createState() => _WikipediaArticleSheetState();
}

class _WikipediaArticleSheetState extends State<WikipediaArticleSheet> {
  final WikipediaService _wikipediaService = WikipediaService();
  WikipediaArticle? _article;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadArticle();
  }

  Future<void> _loadArticle() async {
    try {
      final article = await WikipediaService().fetchArticle(widget.term, languageCode: widget.languageCode);
      if (mounted) {
        setState(() {
          _article = article;
          _isLoading = false;
          if (article == null) {
            _error = 'Article not found';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load article: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        if (_isLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (_error != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                        _error = null;
                      });
                      _loadArticle();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        if (_article == null || _article!.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No content available'),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scrollController,
            children: [
              // Title
              Text(
                _article!.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              // Image
              if (_article!.imageUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _article!.imageUrl!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Infobox
              if (_article!.infoboxHtml != null) ...[
                Html(data: _article!.infoboxHtml!),
                const SizedBox(height: 16),
              ],

              // Lead section
              if (_article!.leadHtml.isNotEmpty) ...[
                Html(data: _article!.leadHtml),
                const SizedBox(height: 16),
              ],

              // Sections
              for (final section in _article!.sections) ...[
                if (section.content.isNotEmpty) ...[
                  Text(
                    section.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 18 + (4 - section.level) * 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Html(data: section.content),
                  const SizedBox(height: 16),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Helper to show Wikipedia article in a bottom sheet
Future<void> showWikipediaArticle(BuildContext context, String term, {String languageCode = 'ja'}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => WikipediaArticleSheet(
      term: term,
      languageCode: languageCode,
    ),
  );
}