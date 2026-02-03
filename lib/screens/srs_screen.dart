import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../models/srs_card.dart';
import '../services/srs_service.dart';
import '../widgets/dictionary_entry_card.dart';

class SRSScreen extends StatefulWidget {
  const SRSScreen({super.key});

  @override
  State<SRSScreen> createState() => _SRSScreenState();
}

class _SRSScreenState extends State<SRSScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController!.addListener(_handleTabSelection);
  }

  void _handleTabSelection() {
    if (_tabController!.index != _selectedIndex) {
      setState(() {
        _selectedIndex = _tabController!.index;
      });
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spaced Repetition'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Study'),
            Tab(text: 'Cards'),
            Tab(text: 'Stats'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _StudyTab(srsService: context.watch<SRSService>()),
          _CardsTab(srsService: context.watch<SRSService>()),
          _StatsTab(srsService: context.watch<SRSService>()),
        ],
      ),
    );
  }
}

class _StudyTab extends StatefulWidget {
  final SRSService srsService;

  const _StudyTab({required this.srsService});

  @override
  State<_StudyTab> createState() => _StudyTabState();
}

class _StudyTabState extends State<_StudyTab> {
  SRSCard? _currentCard;
  bool _showAnswer = false;
  int _currentCardIndex = 0;
  List<SRSCard> _dueCards = [];

  @override
  void initState() {
    super.initState();
    _loadDueCards();
  }

  void _loadDueCards() {
    setState(() {
      _dueCards = widget.srsService.dueCards;
      if (_dueCards.isNotEmpty) {
        _currentCard = _dueCards[0];
      }
    });
  }

  void _nextCard() {
    if (_currentCardIndex < _dueCards.length - 1) {
      setState(() {
        _currentCardIndex++;
        _currentCard = _dueCards[_currentCardIndex];
        _showAnswer = false;
      });
    }
  }

  void _previousCard() {
    if (_currentCardIndex > 0) {
      setState(() {
        _currentCardIndex--;
        _currentCard = _dueCards[_currentCardIndex];
        _showAnswer = false;
      });
    }
  }

  void _rateCard(int quality) {
    if (_currentCard != null) {
      widget.srsService.reviewCard(_currentCard!.id, quality);
      _nextCard();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dueCards.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No cards due for review',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'Come back later or add more cards',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Progress indicator
          LinearProgressIndicator(
            value: (_currentCardIndex + 1) / _dueCards.length,
            backgroundColor: Colors.grey[300],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
          const SizedBox(height: 8),
          Text(
            '${_currentCardIndex + 1} of ${_dueCards.length}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),

          // Card content
          Expanded(
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Word/term
                    Text(
                      _currentCard?.word ?? '',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Reading
                    if ((_currentCard?.reading ?? '').isNotEmpty)
                      Text(
                        _currentCard?.reading ?? '',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Answer button
                    Visibility(
                      visible: !_showAnswer,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _showAnswer = true;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                        child: const Text('Show Answer'),
                      ),
                    ),

                    // Meaning/definition
                    Visibility(
                      visible: _showAnswer,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _currentCard?.meaning ?? '',
                              style: const TextStyle(
                                fontSize: 18,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Rating buttons
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              _buildRatingButton(1, 'Again', Colors.red),
                              _buildRatingButton(2, 'Hard', Colors.orange),
                              _buildRatingButton(3, 'Good', Colors.green),
                              _buildRatingButton(4, 'Easy', Colors.lightBlue),
                              _buildRatingButton(5, 'Perfect', Colors.blue),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Navigation buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _currentCardIndex > 0 ? _previousCard : null,
                child: const Text('Previous'),
              ),
              TextButton(
                onPressed: _currentCardIndex < _dueCards.length - 1 ? _nextCard : null,
                child: const Text('Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRatingButton(int rating, String label, Color color) {
    return ElevatedButton(
      onPressed: () => _rateCard(rating),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      child: Text(label),
    );
  }
}

class _CardsTab extends StatefulWidget {
  final SRSService srsService;

  const _CardsTab({required this.srsService});

  @override
  State<_CardsTab> createState() => _CardsTabState();
}

class _CardsTabState extends State<_CardsTab> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  int _viewMode = 0; // 0 = all, 1 = due, 2 = upcoming

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SRSCard> _filterCards() {
    List<SRSCard> cards = [];
    
    switch (_viewMode) {
      case 0: // All cards
        cards = widget.srsService.allCards;
        break;
      case 1: // Due cards
        cards = widget.srsService.dueCards;
        break;
      case 2: // Upcoming cards
        cards = widget.srsService.upcomingCards;
        break;
    }

    if (_searchQuery.isNotEmpty) {
      cards = cards.where((card) => 
        card.word.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        card.meaning.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    return cards;
  }

  @override
  Widget build(BuildContext context) {
    final filteredCards = _filterCards();

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search cards...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),

        // View mode selector
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(label: Text('All'), value: 0),
                    ButtonSegment(label: Text('Due'), value: 1),
                    ButtonSegment(label: Text('Upcoming'), value: 2),
                  ],
                  selected: {_viewMode},
                  onSelectionChanged: (Set<int> newSelection) {
                    setState(() {
                      _viewMode = newSelection.first;
                    });
                  },
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Cards list
        Expanded(
          child: filteredCards.isEmpty
              ? const Center(
                  child: Text('No cards found'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: filteredCards.length,
                  itemBuilder: (context, index) {
                    final card = filteredCards[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(card.word),
                        subtitle: Text(
                          card.meaning,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          card.isDue ? 'Due' : 'Later',
                          style: TextStyle(
                            color: card.isDue ? Colors.red : Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () {
                          _showCardDetailDialog(card);
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showCardDetailDialog(SRSCard card) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(card.word),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                Text('Reading: ${card.reading}'),
                const SizedBox(height: 8),
                Text('Meaning: ${card.meaning}'),
                const SizedBox(height: 8),
                Text('Created: ${card.createdAt.toLocal()}'),
                const SizedBox(height: 8),
                Text('Next Review: ${card.nextReview.toLocal()}'),
                const SizedBox(height: 8),
                Text('Interval: ${card.interval} days'),
                const SizedBox(height: 8),
                Text('Repetitions: ${card.repetition}'),
                const SizedBox(height: 8),
                Text('Ease Factor: ${card.easeFactor.toStringAsFixed(2)}'),
                const SizedBox(height: 8),
                Text('Priority: ${card.priority}/5'),
                const SizedBox(height: 8),
                Text('Difficulty: ${card.languageLevel}/5'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () async {
                await widget.srsService.resetCard(card.id);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Card reset')),
                );
              },
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
  }
}

class _StatsTab extends StatelessWidget {
  final SRSService srsService;

  const _StatsTab({required this.srsService});

  @override
  Widget build(BuildContext context) {
    final stats = srsService.getReviewStats();
    final dueCards = srsService.dueCards;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stats summary
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    'Review Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatItem(
                        label: 'Due',
                        value: stats['due'].toString(),
                        color: Colors.red,
                      ),
                      _StatItem(
                        label: 'Total',
                        value: stats['total'].toString(),
                        color: Colors.blue,
                      ),
                      _StatItem(
                        label: 'New',
                        value: stats['new'].toString(),
                        color: Colors.green,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Progress chart
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Learning Progress',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ProgressBar(
                    label: 'New Cards',
                    value: stats['new']?.toDouble() ?? 0.0,
                    total: stats['total']?.toDouble() ?? 1.0,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 8),
                  _ProgressBar(
                    label: 'Learning',
                    value: stats['learning']?.toDouble() ?? 0.0,
                    total: stats['total']?.toDouble() ?? 1.0,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 8),
                  _ProgressBar(
                    label: 'Reviewed',
                    value: stats['review']?.toDouble() ?? 0.0,
                    total: stats['total']?.toDouble() ?? 1.0,
                    color: Colors.blue,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Due cards preview
          if (dueCards.isNotEmpty)
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cards Due Today',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...dueCards.take(5).map((card) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(
                        '• ${card.word}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    )),
                    if (dueCards.length > 5)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          '+${dueCards.length - 5} more cards',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final String label;
  final double value;
  final double total;
  final Color color;

  const _ProgressBar({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = total > 0 ? (value / total * 100).round() : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text('$percentage%'),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: total > 0 ? value / total : 0,
          minHeight: 8,
          valueColor: AlwaysStoppedAnimation<Color>(color),
          backgroundColor: Colors.grey[300],
        ),
      ],
    );
  }
}