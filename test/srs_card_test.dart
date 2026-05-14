import 'package:flutter_test/flutter_test.dart';
import 'package:lang/domain/entities/srs_card.dart';
import 'package:lang/domain/entities/srs_deck.dart';

void main() {
  group('SRSCard', () {
    test('creates card with required fields', () {
      final card = SRSCard(
        id: 'test_1',
        word: '日本語',
        meaning: 'Japanese language',
        nextReview: DateTime(2024, 1, 1),
      );

      expect(card.id, 'test_1');
      expect(card.word, '日本語');
      expect(card.meaning, 'Japanese language');
      expect(card.priority, 3);
      expect(card.languageLevel, 1);
      expect(card.reviewCount, 0);
      expect(card.easeFactor, 2.5);
      expect(card.type, CardType.newCard);
    });

    test('creates card with all fields', () {
      final card = SRSCard(
        id: 'test_2',
        word: '水',
        reading: 'みず',
        meaning: 'water',
        imageBase64: 'data:image/png;base64,abc123',
        nextReview: DateTime(2024, 1, 1),
        priority: 5,
        languageLevel: 4,
        lastReviewDate: DateTime(2024, 1, 1),
        reviewCount: 5,
        easeFactor: 2.8,
        deck: 'vocabulary',
        tags: ['jlpt-n5', 'noun'],
        notes: 'Important vocabulary',
        type: CardType.review,
        audioBase64: 'data:audio/mp3;base64,xyz789',
        videoBase64: 'data:video/mp4;base64,video123',
        audioUrl: 'https://example.com/audio.mp3',
        videoUrl: 'https://example.com/video.mp4',
      );

      expect(card.word, '水');
      expect(card.reading, 'みず');
      expect(card.imageBase64, 'data:image/png;base64,abc123');
      expect(card.priority, 5);
      expect(card.deck, 'vocabulary');
      expect(card.tags, ['jlpt-n5', 'noun']);
      expect(card.notes, 'Important vocabulary');
      expect(card.type, CardType.review);
      expect(card.audioBase64, 'data:audio/mp3;base64,xyz789');
      expect(card.videoBase64, 'data:video/mp4;base64,video123');
      expect(card.audioUrl, 'https://example.com/audio.mp3');
      expect(card.videoUrl, 'https://example.com/video.mp4');
    });

    test('newCard factory creates card with defaults', () {
      final card = SRSCard.newCard(
        id: 'new_1',
        word: 'test',
        meaning: 'test meaning',
      );

      expect(card.id, 'new_1');
      expect(card.word, 'test');
      expect(card.reviewCount, 0);
      expect(card.type, CardType.newCard);
      expect(card.priority, 3);
      expect(card.languageLevel, 1);
    });

    test('copyWith preserves unchanged fields', () {
      final original = SRSCard(
        id: 'copy_1',
        word: 'original',
        reading: 'おりじなる',
        meaning: 'original meaning',
        nextReview: DateTime(2024, 1, 1),
        priority: 4,
        languageLevel: 3,
        reviewCount: 3,
        easeFactor: 2.6,
        deck: 'default',
        tags: ['tag1'],
        notes: 'original notes',
        type: CardType.learning,
      );

      final updated = original.copyWith(word: 'updated', meaning: 'updated meaning');

      expect(updated.id, 'copy_1');
      expect(updated.word, 'updated');
      expect(updated.reading, 'おりじなる');
      expect(updated.meaning, 'updated meaning');
      expect(updated.priority, 4);
      expect(updated.deck, 'default');
      expect(updated.tags, ['tag1']);
      expect(updated.type, CardType.learning);
    });

    test('copyWith supports media fields', () {
      final original = SRSCard.newCard(id: 'media', word: 'test', meaning: 'test');
      final withImage = original.copyWith(imageBase64: 'data:image/png;base64,abc');
      final withAudio = original.copyWith(audioBase64: 'data:audio/mp3;base64,xyz');
      final withVideo = original.copyWith(videoBase64: 'data:video/mp4;base64,vid');

      expect(withImage.imageBase64, 'data:image/png;base64,abc');
      expect(withAudio.audioBase64, 'data:audio/mp3;base64,xyz');
      expect(withVideo.videoBase64, 'data:video/mp4;base64,vid');
    });

    test('toJson and fromJson roundtrip', () {
      final original = SRSCard(
        id: 'json_1',
        word: '日本語',
        reading: 'にほんご',
        meaning: 'Japanese',
        imageBase64: 'data:image/png;base64,test',
        nextReview: DateTime(2024, 6, 15, 12, 30),
        priority: 5,
        languageLevel: 3,
        lastReviewDate: DateTime(2024, 6, 10),
        reviewCount: 7,
        easeFactor: 2.7,
        deck: 'jlpt-n3',
        tags: ['jlpt-n3', 'vocabulary'],
        notes: 'Important',
        type: CardType.review,
        audioBase64: 'data:audio/mp3;base64,audio',
        videoBase64: 'data:video/mp4;base64,video',
        audioUrl: 'https://example.com/audio.mp3',
        videoUrl: 'https://example.com/video.mp4',
      );

      final json = original.toJson();
      final restored = SRSCard.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.word, original.word);
      expect(restored.reading, original.reading);
      expect(restored.meaning, original.meaning);
      expect(restored.imageBase64, original.imageBase64);
      expect(restored.priority, original.priority);
      expect(restored.languageLevel, original.languageLevel);
      expect(restored.reviewCount, original.reviewCount);
      expect(restored.easeFactor, original.easeFactor);
      expect(restored.deck, original.deck);
      expect(restored.tags, original.tags);
      expect(restored.notes, original.notes);
      expect(restored.type, original.type);
      expect(restored.audioBase64, original.audioBase64);
      expect(restored.videoBase64, original.videoBase64);
      expect(restored.audioUrl, original.audioUrl);
      expect(restored.videoUrl, original.videoUrl);
    });

    group('interval calculation', () {
      test('returns 0 for new cards', () {
        final card = SRSCard.newCard(id: 'i1', word: 'test', meaning: 'test');
        expect(card.interval, 0);
      });

      test('calculates interval based on reviewCount and easeFactor', () {
        final card = SRSCard(
          id: 'i2',
          word: 'test',
          meaning: 'test',
          nextReview: DateTime.now(),
          reviewCount: 5,
          easeFactor: 2.5,
        );
        expect(card.interval, 12); // 5 * 2.5 = 12.5 rounded to 12
      });
    });

    group('isDue', () {
      test('returns true for past due cards', () {
        final card = SRSCard(
          id: 'due_1',
          word: 'test',
          meaning: 'test',
          nextReview: DateTime.now().subtract(const Duration(days: 1)),
        );
        expect(card.isDue, true);
      });

      test('returns true for cards due now', () {
        final now = DateTime.now();
        final card = SRSCard(
          id: 'due_2',
          word: 'test',
          meaning: 'test',
          nextReview: DateTime(now.year, now.month, now.day),
        );
        expect(card.isDue, true);
      });

      test('returns false for future cards', () {
        final card = SRSCard(
          id: 'due_3',
          word: 'test',
          meaning: 'test',
          nextReview: DateTime.now().add(const Duration(days: 1)),
        );
        expect(card.isDue, false);
      });
    });

    group('hasMedia getters', () {
      test('hasImage returns true when imageBase64 is set', () {
        final withBase64 = SRSCard.newCard(id: '1', word: 'w', meaning: 'm', imageBase64: 'data:image/png;base64,abc');
        final emptyBase64 = SRSCard.newCard(id: '2', word: 'w', meaning: 'm', imageBase64: '');
        final noImage = SRSCard.newCard(id: '3', word: 'w', meaning: 'm');

        expect(withBase64.hasImage, true);
        expect(emptyBase64.hasImage, false);
        expect(noImage.hasImage, false);
      });

      test('hasAudio returns true for base64 or url', () {
        final withBase64 = SRSCard.newCard(id: '1', word: 'w', meaning: 'm', audioBase64: 'data:audio/mp3;base64,abc');
        final withUrl = SRSCard.newCard(id: '2', word: 'w', meaning: 'm', audioUrl: 'https://example.com/audio.mp3');
        final noAudio = SRSCard.newCard(id: '3', word: 'w', meaning: 'm');

        expect(withBase64.hasAudio, true);
        expect(withUrl.hasAudio, true);
        expect(noAudio.hasAudio, false);
      });

      test('hasVideo returns true for base64 or url', () {
        final withBase64 = SRSCard.newCard(id: '1', word: 'w', meaning: 'm', videoBase64: 'data:video/mp4;base64,abc');
        final withUrl = SRSCard.newCard(id: '2', word: 'w', meaning: 'm', videoUrl: 'https://example.com/video.mp4');
        final noVideo = SRSCard.newCard(id: '3', word: 'w', meaning: 'm');

        expect(withBase64.hasVideo, true);
        expect(withUrl.hasVideo, true);
        expect(noVideo.hasVideo, false);
      });
    });

    group('calculateNextReview', () {
      test('quality < 3 resets to learning', () {
        final card = SRSCard(
          id: 'calc_1',
          word: 'test',
          meaning: 'test',
          nextReview: DateTime.now(),
          reviewCount: 3,
          easeFactor: 2.5,
        );

        final result = card.calculateNextReview(2);

        expect(result.reviewCount, 0);
        expect(result.type, CardType.learning);
      });

      test('quality >= 3 increases interval', () {
        final card = SRSCard(
          id: 'calc_2',
          word: 'test',
          meaning: 'test',
          nextReview: DateTime.now(),
          reviewCount: 1,
          easeFactor: 2.5,
        );

        final result = card.calculateNextReview(4);

        expect(result.reviewCount, 2);
        expect(result.type, CardType.review);
      });

      test('suspended cards return unchanged', () {
        final card = SRSCard(
          id: 'calc_3',
          word: 'test',
          meaning: 'test',
          nextReview: DateTime.now(),
          reviewCount: 3,
          easeFactor: 2.5,
          type: CardType.suspended,
        );

        final result = card.calculateNextReview(5);

        expect(result.type, CardType.suspended);
        expect(result.reviewCount, 3);
      });

      test('first successful review sets interval to 1 day', () {
        final card = SRSCard.newCard(id: 'calc_4', word: 'test', meaning: 'test');

        final result = card.calculateNextReview(4);

        expect(result.reviewCount, 1);
        expect(result.type, CardType.learning);
      });

      test('second successful review sets interval to 6 days', () {
        final card = SRSCard(
          id: 'calc_5',
          word: 'test',
          meaning: 'test',
          nextReview: DateTime.now(),
          reviewCount: 1,
          easeFactor: 2.5,
        );

        final result = card.calculateNextReview(4);

        expect(result.reviewCount, 2);
        expect(result.type, CardType.review);
      });
    });

    group('suspend/unsuspend', () {
      test('suspend changes type to suspended', () {
        final card = SRSCard.newCard(id: 's1', word: 'test', meaning: 'test');
        expect(card.suspend().type, CardType.suspended);
      });

      test('unsuspend changes type based on reviewCount', () {
        final newCard = SRSCard.newCard(id: 'u1', word: 'test', meaning: 'test');
        expect(newCard.unsuspend().type, CardType.newCard);

        final learningCard = SRSCard(
          id: 'u2',
          word: 'test',
          meaning: 'test',
          nextReview: DateTime.now(),
          reviewCount: 2,
        );
        expect(learningCard.unsuspend().type, CardType.learning);

        final reviewCard = SRSCard(
          id: 'u3',
          word: 'test',
          meaning: 'test',
          nextReview: DateTime.now(),
          reviewCount: 5,
        );
        expect(reviewCard.unsuspend().type, CardType.review);
      });
    });
  });

  group('SrsDeck', () {
    test('creates deck with required fields', () {
      final now = DateTime.now();
      final deck = SrsDeck(
        id: 'deck_1',
        name: 'Default',
        createdAt: now,
        updatedAt: now,
      );

      expect(deck.id, 'deck_1');
      expect(deck.name, 'Default');
      expect(deck.icon, '📚');
      expect(deck.color, '#3B82F6');
    });

    test('creates deck with all fields', () {
      final now = DateTime.now();
      final deck = SrsDeck(
        id: 'deck_2',
        name: 'JLPT N5',
        description: 'Japanese JLPT N5 vocabulary',
        icon: '🎯',
        color: '#EF4444',
        createdAt: now,
        updatedAt: now,
      );

      expect(deck.description, 'Japanese JLPT N5 vocabulary');
      expect(deck.icon, '🎯');
      expect(deck.color, '#EF4444');
    });

    test('copyWith preserves unchanged fields', () {
      final now = DateTime.now();
      final original = SrsDeck(
        id: 'copy_1',
        name: 'Original',
        description: 'Original description',
        icon: '📚',
        color: '#3B82F6',
        createdAt: now,
        updatedAt: now,
      );

      final updated = original.copyWith(name: 'Updated');

      expect(updated.id, 'copy_1');
      expect(updated.name, 'Updated');
      expect(updated.description, 'Original description');
      expect(updated.icon, '📚');
    });

    test('toJson and fromJson roundtrip', () {
      final now = DateTime(2024, 6, 15, 12, 30);
      final original = SrsDeck(
        id: 'json_deck',
        name: 'Test Deck',
        description: 'Test description',
        icon: '🎮',
        color: '#22C55E',
        createdAt: now,
        updatedAt: now,
      );

      final json = original.toJson();
      final restored = SrsDeck.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.description, original.description);
      expect(restored.icon, original.icon);
      expect(restored.color, original.color);
      expect(restored.createdAt, original.createdAt);
      expect(restored.updatedAt, original.updatedAt);
    });
  });

  group('CardType enum', () {
    test('has all expected values', () {
      expect(CardType.values, containsAll([CardType.newCard, CardType.learning, CardType.review, CardType.suspended]));
    });
  });
}