import 'package:flutter/material.dart';
import '../widgets/document_reader.dart';

class DocumentReaderScreen extends StatefulWidget {
  final String filePath;
  final String fileType; // 'pdf', 'epub', or 'txt'

  const DocumentReaderScreen({
    Key? key,
    required this.filePath,
    required this.fileType,
  }) : super(key: key);

  @override
  State<DocumentReaderScreen> createState() => _DocumentReaderScreenState();
}

class _DocumentReaderScreenState extends State<DocumentReaderScreen> {
  final GlobalKey<_DocumentReaderState> _documentReaderKey = GlobalKey<_DocumentReaderState>();
  final TextEditingController _pageController = TextEditingController();
  int _currentPage = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _pageController.text = '1';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Document Reader'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (String result) {
              if (result == 'open') {
                // Open file picker to select a new document
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'open',
                child: Text('Open Document'),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          // Document content
          Positioned.fill(
            child: DocumentReader(
              key: _documentReaderKey,
              filePath: widget.filePath,
              fileType: widget.fileType,
              onPageChanged: (currentPage, totalPages) {
                setState(() {
                  _currentPage = currentPage;
                  _totalPages = totalPages;
                  _pageController.text = currentPage.toString();
                });
              },
            ),
          ),
          // Overlay for navigation controls
          if (widget.fileType != 'txt') // Only show navigation for PDF and EPUB
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () {
                            // Call the document reader's previous page method
                            final state = _documentReaderKey.currentState;
                            if (state != null) {
                              state.goToPreviousPage();
                            }
                          },
                        ),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: TextFormField(
                              controller: _pageController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(
                                hintText: 'Page',
                                border: OutlineInputBorder(),
                              ),
                              onFieldSubmitted: (value) {
                                int? page = int.tryParse(value);
                                if (page != null && page >= 1 && page <= _totalPages) {
                                  // Call the document reader's goToPage method
                                  final state = _documentReaderKey.currentState;
                                  if (state != null) {
                                    state.goToPage(page);
                                  }
                                }
                              },
                            ),
                          ),
                        ),
                        const Text('/'),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '$_totalPages', // Display the actual total pages
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () {
                            // Call the document reader's next page method
                            final state = _documentReaderKey.currentState;
                            if (state != null) {
                              state.goToNextPage();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}