import 'package:flutter/material.dart';
import 'package:lang/data/datasources/radical_data.dart';
import 'package:lang/data/datasources/kanji_decomposition_data.dart';
import 'package:lang/data/repositories/dictionary_service.dart';
import 'package:lang/data/repositories/radical_search_service.dart';
import 'package:lang/utils/screen_size.dart';

class RadicalSearchScreen extends StatefulWidget {
  const RadicalSearchScreen({super.key});

  @override
  State<RadicalSearchScreen> createState() => _RadicalSearchScreenState();
}

class _RadicalSearchScreenState extends State<RadicalSearchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DictionaryService _dictionaryService = DictionaryService();
  late RadicalSearchService _radicalSearchService;

  List<KangxiRadical> _selectedRadicals = [];
  List<RadicalSearchResult> _radicalResults = [];
  bool _isRadicalSearching = false;

  final TextEditingController _componentController = TextEditingController();
  List<RadicalSearchResult> _componentResults = [];
  bool _isComponentSearching = false;
  KanjiDecomposition? _currentDecomposition;
  List<String> _selectedComponents = [];

  int _selectedStrokeCount = 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _radicalSearchService = RadicalSearchService(_dictionaryService);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _componentController.dispose();
    super.dispose();
  }

  Future<void> _performRadicalSearch() async {
    if (_selectedRadicals.isEmpty) {
      setState(() => _radicalResults = []);
      return;
    }

    setState(() => _isRadicalSearching = true);
    try {
      final results = await _radicalSearchService.searchByRadicals(_selectedRadicals);
      setState(() {
        _radicalResults = results;
        _isRadicalSearching = false;
      });
    } catch (e) {
      setState(() => _isRadicalSearching = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search error: $e')),
        );
      }
    }
  }

  void _toggleRadical(KangxiRadical radical) {
    setState(() {
      if (_selectedRadicals.any((r) => r.number == radical.number)) {
        _selectedRadicals = _selectedRadicals.where((r) => r.number != radical.number).toList();
      } else {
        _selectedRadicals = [..._selectedRadicals, radical];
      }
    });
    _performRadicalSearch();
  }

  void _clearRadicalSelection() {
    setState(() {
      _selectedRadicals = [];
      _radicalResults = [];
    });
  }

  Future<void> _decomposeInput() async {
    final text = _componentController.text.trim();
    if (text.isEmpty) return;

    final char = text.characters.first;
    final decomp = KanjiDecompositionData.getDecomposition(char);
    setState(() {
      _currentDecomposition = decomp;
      _selectedComponents = decomp?.components.toList() ?? [];
    });

    if (_selectedComponents.isNotEmpty) {
      _performComponentSearch();
    }
  }

  Future<void> _performComponentSearch() async {
    if (_selectedComponents.isEmpty) {
      setState(() => _componentResults = []);
      return;
    }

    setState(() => _isComponentSearching = true);
    try {
      final results = await _radicalSearchService.searchByComponents(_selectedComponents);
      setState(() {
        _componentResults = results;
        _isComponentSearching = false;
      });
    } catch (e) {
      setState(() => _isComponentSearching = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search error: $e')),
        );
      }
    }
  }

  void _toggleComponent(String component) {
    setState(() {
      if (_selectedComponents.contains(component)) {
        _selectedComponents = _selectedComponents.where((c) => c != component).toList();
      } else {
        _selectedComponents = [..._selectedComponents, component];
      }
    });
    _performComponentSearch();
  }

  void _showKanjiDetail(RadicalSearchResult result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _KanjiDetailSheet(result: result),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Radical Search'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Radicals', icon: Icon(Icons.grid_view, size: 18)),
            Tab(text: 'Components', icon: Icon(Icons.widgets, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRadicalPickerTab(),
          _buildComponentDecompositionTab(),
        ],
      ),
    );
  }

  Widget _buildRadicalPickerTab() {
    final strokeCounts = RadicalData.strokeCounts;
    final radicalsByStroke = RadicalData.byStrokeCount;

    return Column(
      children: [
        if (_selectedRadicals.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Selected: ',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    Expanded(
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: _selectedRadicals.map((r) => _buildRadicalChip(r, isSelected: true)).toList(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.clear_all, size: 20),
                      onPressed: _clearRadicalSelection,
                      tooltip: 'Clear all',
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_radicalResults.length} kanji found',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: strokeCounts.length,
              separatorBuilder: (_, _) => const SizedBox(width: 4),
              itemBuilder: (context, index) {
                final sc = strokeCounts[index];
                final isSelected = sc == _selectedStrokeCount;
                return ChoiceChip(
                  label: Text('$sc'),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() => _selectedStrokeCount = sc);
                  },
                );
              },
            ),
          ),
        ),

        Expanded(
          flex: 1,
          child: _buildRadicalGrid(radicalsByStroke[_selectedStrokeCount] ?? []),
        ),

        Expanded(
          flex: 1,
          child: _buildResultsList(_radicalResults, _isRadicalSearching),
        ),
      ],
    );
  }

  Widget _buildRadicalGrid(List<KangxiRadical> radicals) {
    if (radicals.isEmpty) {
      return const Center(child: Text('No radicals for this stroke count'));
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: ScreenSize.isCompact(context) ? 8 : 10,
        childAspectRatio: 1,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: radicals.length,
      itemBuilder: (context, index) {
        final radical = radicals[index];
        final isSelected = _selectedRadicals.any((r) => r.number == radical.number);
        return _buildRadicalChip(radical, isSelected: isSelected);
      },
    );
  }

  Widget _buildRadicalChip(KangxiRadical radical, {required bool isSelected}) {
    return InkWell(
      onTap: () => _toggleRadical(radical),
      borderRadius: BorderRadius.circular(8),
      child: Tooltip(
        message: '${radical.number}. ${radical.nameEn} (${radical.nameJa}) ${radical.strokes} strokes',
        child: Container(
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Theme.of(context).unselectedWidgetColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(color: Theme.of(context).primaryColorDark, width: 2)
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            radical.displayChar,
            style: TextStyle(
              fontSize: ScreenSize.isCompact(context) ? 18 : 22,
              color: isSelected ? Colors.white : null,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildComponentDecompositionTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _componentController,
                  decoration: const InputDecoration(
                    hintText: 'Enter a kanji to decompose...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                  maxLength: 1,
                  onSubmitted: (_) => _decomposeInput(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                icon: const Icon(Icons.search),
                onPressed: _decomposeInput,
              ),
            ],
          ),
        ),

        if (_currentDecomposition != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _currentDecomposition!.character,
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '= ${_currentDecomposition!.components.join(' + ')}',
                            style: const TextStyle(fontSize: 18),
                          ),
                          if (_currentDecomposition!.description != null)
                            Text(
                              _currentDecomposition!.description!,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap components to search:',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _currentDecomposition!.components.map((comp) {
                    final isSelected = _selectedComponents.contains(comp);
                    return FilterChip(
                      label: Text(comp, style: const TextStyle(fontSize: 18)),
                      selected: isSelected,
                      onSelected: (_) => _toggleComponent(comp),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],

        Expanded(
          child: _buildResultsList(_componentResults, _isComponentSearching),
        ),
      ],
    );
  }

  Widget _buildResultsList(List<RadicalSearchResult> results, bool isLoading) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (results.isEmpty) {
      return Center(
        child: Text(
          'Select radicals above to find kanji',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).disabledColor,
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: ScreenSize.isCompact(context) ? 5 : 8,
        childAspectRatio: 0.75,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final result = results[index];
        return _buildResultCard(result);
      },
    );
  }

  Widget _buildResultCard(RadicalSearchResult result) {
    final meanings = result.kanjiEntry?.meanings ?? [];
    final onyomi = result.kanjiEntry?.onyomi ?? [];
    final kunyomi = result.kanjiEntry?.kunyomi ?? [];

    return InkWell(
      onTap: () => _showKanjiDetail(result),
      borderRadius: BorderRadius.circular(8),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                result.character,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              if (meanings.isNotEmpty)
                Text(
                  meanings.first,
                  style: const TextStyle(fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              if (onyomi.isNotEmpty)
                Text(
                  onyomi.join('・'),
                  style: TextStyle(
                    fontSize: 9,
                    color: Theme.of(context).primaryColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              if (kunyomi.isNotEmpty)
                Text(
                  kunyomi.join('・'),
                  style: TextStyle(
                    fontSize: 9,
                    color: Theme.of(context).hintColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              if (result.decomposition != null)
                Text(
                  result.decomposition!.components.join('+'),
                  style: TextStyle(
                    fontSize: 8,
                    color: Theme.of(context).disabledColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KanjiDetailSheet extends StatelessWidget {
  final RadicalSearchResult result;

  const _KanjiDetailSheet({required this.result});

  @override
  Widget build(BuildContext context) {
    final meanings = result.kanjiEntry?.meanings ?? [];
    final onyomi = result.kanjiEntry?.onyomi ?? [];
    final kunyomi = result.kanjiEntry?.kunyomi ?? [];
    final stats = result.kanjiEntry?.stats;

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    result.character,
                    style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (meanings.isNotEmpty)
                          Text(
                            meanings.join(', '),
                            style: const TextStyle(fontSize: 18),
                          ),
                        if (onyomi.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('音', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 6),
                              Text(onyomi.join('・'), style: const TextStyle(fontSize: 14)),
                            ],
                          ),
                        ],
                        if (kunyomi.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).hintColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('訓', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 6),
                              Text(kunyomi.join('・'), style: const TextStyle(fontSize: 14)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (result.decomposition != null) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Components',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: result.decomposition!.components.map((comp) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(comp, style: const TextStyle(fontSize: 24)),
                          if (result.decomposition!.description != null)
                            Text(
                              comp,
                              style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(context).disabledColor,
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                if (result.decomposition!.description != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    result.decomposition!.description!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).hintColor,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
              if (stats != null && stats.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Stats',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: stats.entries.map((e) {
                    return Chip(
                      label: Text('${e.key}: ${e.value}', style: const TextStyle(fontSize: 11)),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}
