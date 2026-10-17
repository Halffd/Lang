import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'dart:io';

import 'package:lang/core/services/whisper_subs_service.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/presentation/screens/document_reader_screen.dart';

/// Browse a whisper-subs server: Library (finished transcriptions),
/// Channels (per-channel video lists) and Live (running tasks).
///
/// Tapping a library item with media hands it to the video tab through
/// AppState (videoLoadRequest + readerTabRequest) — the reader switches
/// there and playback starts with the server's SRT side-loaded, so the
/// transcript/dictionary machinery works on it like any other video.
class WhisperSubsTab extends StatefulWidget {
  const WhisperSubsTab({super.key});

  @override
  State<WhisperSubsTab> createState() => _WhisperSubsTabState();
}

class _WhisperSubsTabState extends State<WhisperSubsTab> {
  static const _videoTabIndex = 4;

  int _section = 0; // 0 library, 1 channels, 2 live
  String? _channel; // drill-down channel in the channels section
  bool _loading = false;
  String? _error;

  List<Map<String, dynamic>> _library = const [];
  List<Map<String, dynamic>> _channels = const [];
  List<Map<String, dynamic>> _channelVideos = const [];
  List<Map<String, dynamic>> _live = const [];
  List<Map<String, dynamic>> _subs = const [];

  /// Status strip (the Kotlin app's Home screen equivalent): who the
  /// key belongs to, how many models the server offers.
  Map<String, dynamic>? _homeInfo;

  WhisperSubsService? _service;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  void _bootstrap() {
    final appState = context.read<AppState>();
    final url = appState.whisperSubsUrl.trim();
    if (url.isEmpty) {
      setState(() => _error = 'Set the WhisperSubs server URL in Settings.');
      return;
    }
    _service = WhisperSubsService(
      baseUrl: url,
      apiKey: appState.whisperSubsApiKey,
    );
    _reload();
    () async {
      try {
        final me = await _service!.authMe();
        final models = await _service!.models();
        if (!mounted) return;
        setState(() {
          _homeInfo = {'username': me['username'], 'models': models.length};
        });
      } catch (_) {
        // the status strip stays hidden when the key is wrong
      }
    }();
  }

  void _reload() {
    final service = _service;
    if (service == null || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    () async {
      try {
        final List<Map<String, dynamic>> items;
        switch (_section) {
          case 0:
            items = await service.library();
          case 1:
            if (_channel != null) {
              items = await service.channelVideos(_channel!);
            } else {
              items = await service.channels();
            }
          case 2:
            items = await service.liveTasks();
          default:
            items = await service.subtitleList();
        }
        if (!mounted) return;
        setState(() {
          _loading = false;
          switch (_section) {
            case 0:
              _library = items;
            case 1:
              if (_channel != null) {
                _channelVideos = items;
              } else {
                _channels = items;
              }
            case 2:
              _live = items;
            default:
              _subs = items;
          }
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = '$e';
        });
      }
    }();
  }

  void _switchSection(int index) {
    if (_section == index) return;
    _channel = null;
    setState(() => _section = index);
    final cached = switch (index) {
      0 => _library,
      1 => _channels,
      2 => _live,
      _ => _subs,
    };
    if (cached.isEmpty) {
      _reload();
    }
  }

  void _openChannel(String name) {
    setState(() => _channel = name);
    _reload();
  }

  /// Hand the video tab a source and make the reader switch to it.
  void _playInVideoTab(Map<String, dynamic> request, {String title = ''}) {
    final appState = context.read<AppState>();
    appState.videoLoadRequest.value = request;
    appState.readerTabRequest.value = _videoTabIndex;
    if (title.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening in video tab: $title'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Map<String, dynamic>? _mediaUrlOf(Map<String, dynamic> item) {
    final media = item['urls']?['media'];
    if (media is List && media.isNotEmpty) {
      final first = media.first;
      if (first is Map && first['url'] is String) {
        return Map<String, dynamic>.from(first);
      }
    }
    return null;
  }

  void _openLibraryItem(Map<String, dynamic> item) {
    final service = _service;
    if (service == null) return;
    final title = '${item['title'] ?? 'untitled'}';
    final media = _mediaUrlOf(item);
    final srtUrl = item['urls']?['srt'];
    if (media != null && srtUrl is String) {
      _playInVideoTab({
        'kind': 'direct',
        'mediaUrl': service.resolveUrl(media['url'] as String),
        'srtUrl': service.resolveUrl(srtUrl),
        'title': title,
      }, title: title);
      return;
    }
    final sourceUrl = item['source_url'];
    if (sourceUrl is String && sourceUrl.isNotEmpty) {
      _playInVideoTab({
        'kind': 'youtube',
        'url': sourceUrl,
        'title': title,
      }, title: title);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('The server kept no media for this item')),
    );
  }

  void _openChannelVideo(Map<String, dynamic> video) {
    final sourceUrl = video['source_url'];
    if (sourceUrl is String && sourceUrl.isNotEmpty) {
      _playInVideoTab({
        'kind': 'youtube',
        'url': sourceUrl,
        'title': '${video['title'] ?? ''}',
      }, title: '${video['title'] ?? ''}');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No playable source for this entry')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_error != null && _service == null) {
      return Center(
        child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              _sectionChip(0, 'Library', Icons.video_library),
              const SizedBox(width: 6),
              _sectionChip(1, 'Channels', Icons.folder),
              const SizedBox(width: 6),
              _sectionChip(2, 'Live', Icons.podcasts),
              const SizedBox(width: 6),
              _sectionChip(3, 'Subs', Icons.subtitles),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Reload',
                onPressed: _loading ? null : _reload,
              ),
            ],
          ),
        ),
        if (_homeInfo != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'server ok · ${_homeInfo!['username']} · ${_homeInfo!['models']} models',
              style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        if (_channel != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 18),
                  onPressed: () {
                    setState(() => _channel = null);
                    _reload();
                  },
                ),
                Expanded(
                  child: Text(_channel!, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator())),
        if (!_loading)
          Expanded(
            child: switch (_section) {
              0 => _buildLibrary(),
              1 => _buildChannels(),
              2 => _buildLive(),
              _ => _buildSubs(),
            },
          ),
      ],
    );
  }

  Widget _sectionChip(int index, String label, IconData icon) {
    final selected = _section == index;
    return InputChip(
      avatar: Icon(
        icon,
        size: 16,
        color: selected ? null : Theme.of(context).colorScheme.outline,
      ),
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onPressed: () => _switchSection(index),
    );
  }

  Widget _buildLibrary() {
    if (_library.isEmpty) return _empty('No transcriptions on the server');
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: ListView.builder(
        itemCount: _library.length,
        itemBuilder: (context, i) => _libraryTile(_library[i]),
      ),
    );
  }

  Widget _libraryTile(Map<String, dynamic> item) {
    final theme = Theme.of(context);
    final service = _service;
    final thumb = item['urls']?['thumbnail'];
    final hasMedia = _mediaUrlOf(item) != null;
    return ListTile(
      leading: (thumb is String && thumb.isNotEmpty && service != null)
          ? ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                service.resolveUrl(thumb),
                width: 80,
                height: 45,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const SizedBox(width: 80, height: 45),
              ),
            )
          : const SizedBox(
              width: 80,
              height: 45,
              child: Icon(Icons.subtitles_outlined),
            ),
      title: Text(
        '${item['title'] ?? 'untitled'}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          if (item['channel'] != null) '${item['channel']}',
          if (item['has_video'] == true) 'video',
          if (item['has_audio'] == true) 'audio',
          if (!hasMedia && item['source_url'] == null) 'subs only',
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: theme.colorScheme.outline),
      ),
      onTap: () => _openLibraryItem(item),
    );
  }

  Widget _buildChannels() {
    if (_channel != null) {
      if (_channelVideos.isEmpty) {
        return _empty('No videos listed for this channel');
      }
      return RefreshIndicator(
        onRefresh: () async => _reload(),
        child: ListView.builder(
          itemCount: _channelVideos.length,
          itemBuilder: (context, i) {
            final v = _channelVideos[i];
            final transcribed = v['transcribed'] == true;
            return ListTile(
              leading: Icon(
                transcribed
                    ? Icons.closed_caption
                    : Icons.closed_caption_disabled,
                size: 20,
                color: transcribed
                    ? null
                    : Theme.of(context).colorScheme.outline,
              ),
              title: Text(
                '${v['title'] ?? 'untitled'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                transcribed ? 'transcribed' : 'not transcribed yet',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
              onTap: () => _openChannelVideo(v),
            );
          },
        ),
      );
    }
    if (_channels.isEmpty) return _empty('No channels on the server');
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: ListView.builder(
        itemCount: _channels.length,
        itemBuilder: (context, i) {
          final c = _channels[i];
          final transcribed = c['transcribed'];
          return ListTile(
            leading: const Icon(Icons.folder),
            title: Text('${c['name'] ?? c['channel'] ?? '?'}'),
            subtitle: transcribed == null
                ? null
                : Text(
                    '$transcribed transcribed',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
            onTap: () => _openChannel('${c['name'] ?? c['channel']}'),
          );
        },
      ),
    );
  }

  Widget _buildLive() {
    if (_live.isEmpty) return _empty('No live or running transcription tasks');
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: ListView.builder(
        itemCount: _live.length,
        itemBuilder: (context, i) {
          final t = _live[i];
          return ListTile(
            leading: const Icon(Icons.podcasts),
            title: Text(
              '${t['source'] ?? '?'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              [
                if (t['status'] != null) '${t['status']}',
                if (t['model_name'] != null) '${t['model_name']}',
              ].join(' · '),
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          );
        },
      ),
    );
  }

  /// Every subtitle file the server kept, browsable like a directory.
  /// Opening one downloads it and hands it to the document reader, so
  /// dictionary lookups work on the transcript text.
  Widget _buildSubs() {
    if (_subs.isEmpty) return _empty('No subtitle files on the server');
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: ListView.builder(
        itemCount: _subs.length,
        itemBuilder: (context, i) {
          final s = _subs[i];
          return ListTile(
            leading: const Icon(Icons.subtitles_outlined),
            title: Text(
              '${s['filename'] ?? s['path'] ?? '?'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${s['created'] ?? ''}',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
            onTap: () => _openSubsEntry(s),
          );
        },
      ),
    );
  }

  Future<void> _openSubsEntry(Map<String, dynamic> entry) async {
    final service = _service;
    final path = entry['path'];
    if (service == null || path is! String || path.isEmpty) return;
    setState(() => _loading = true);
    try {
      final text = await service.fetchSubtitle(path);
      final file = File(
        '${Directory.systemTemp.path}/whispersubs-${DateTime.now().millisecondsSinceEpoch}.txt',
      );
      await file.writeAsString(text, flush: true);
      if (!mounted) return;
      setState(() => _loading = false);
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              DocumentReaderScreen(filePath: file.path, fileType: 'txt'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Widget _empty(String message) => LayoutBuilder(
    builder: (context, constraints) => ListView(
      children: [
        SizedBox(
          height: constraints.maxHeight,
          child: Center(
            child: Text(
              message,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
        ),
      ],
    ),
  );
}
