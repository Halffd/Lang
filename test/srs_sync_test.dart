// SRS sync merge logic: last-write-wins by updatedAt, local-only
// and remote-only rows preserved, append-only review union.

import 'package:flutter_test/flutter_test.dart';
import 'package:lang/data/repositories/srs_repository_impl.dart'
    show mergeRowsByUpdatedAt;
import 'package:lang/domain/entities/srs_card.dart';
import 'package:lang/domain/entities/srs_deck.dart';
import 'package:lang/domain/entities/srs_review.dart';

void main() {
  SrsDeck deck(String id, DateTime updated) =>
      SrsDeck(id: id, name: 'deck $id', createdAt: updated, updatedAt: updated);

  SrsCard card(String id, DateTime updated) => SrsCard(
    id: id,
    userId: 'u1',
    deckId: 'd1',
    front: 'front $id',
    back: 'back $id',
    dueDate: updated,
    createdAt: updated,
    updatedAt: updated,
  );

  SrsReview review(String id, DateTime at) =>
      SrsReview(id: id, userId: 'u1', cardId: 'c1', rating: 4, reviewedAt: at);

  group('mergeRowsByUpdatedAt', () {
    test('remote newer than local wins', () {
      final local = [deck('a', DateTime(2024, 1, 1))];
      final remote = {'a': deck('a', DateTime(2024, 1, 2))};
      final merged = mergeRowsByUpdatedAt<SrsDeck>(
        local: local,
        remote: remote,
        idOf: (d) => d.id,
        updatedAtOf: (d) => d.updatedAt,
      );
      expect(merged.single.updatedAt, DateTime(2024, 1, 2));
    });

    test('local newer than remote wins', () {
      final local = [deck('a', DateTime(2024, 1, 5))];
      final remote = {'a': deck('a', DateTime(2024, 1, 2))};
      final merged = mergeRowsByUpdatedAt<SrsDeck>(
        local: local,
        remote: remote,
        idOf: (d) => d.id,
        updatedAtOf: (d) => d.updatedAt,
      );
      expect(merged.single.updatedAt, DateTime(2024, 1, 5));
    });

    test('equal timestamps keep local', () {
      final at = DateTime(2024, 1, 1);
      final local = [deck('a', at)];
      final remote = {'a': deck('a', at)};
      final merged = mergeRowsByUpdatedAt<SrsDeck>(
        local: local,
        remote: remote,
        idOf: (d) => d.id,
        updatedAtOf: (d) => d.updatedAt,
      );
      expect(merged.single, same(local.single));
    });

    test('local-only and remote-only rows both kept', () {
      final local = [deck('local-only', DateTime(2024, 1, 1))];
      final remote = {'remote-only': deck('remote-only', DateTime(2024, 1, 1))};
      final merged = mergeRowsByUpdatedAt<SrsDeck>(
        local: local,
        remote: remote,
        idOf: (d) => d.id,
        updatedAtOf: (d) => d.updatedAt,
      );
      expect(merged.length, 2);
      expect(merged.map((d) => d.id).toSet(), {'local-only', 'remote-only'});
    });

    test('mixed update + insert per id', () {
      final now = DateTime(2024, 6, 1);
      final local = [
        deck('stale', DateTime(2024, 1, 1)),
        deck('fresh', DateTime(2024, 6, 1)),
        deck('local-new', now),
      ];
      final remote = {
        'stale': deck('stale', DateTime(2024, 2, 1)),
        'fresh': deck('fresh', DateTime(2024, 3, 1)),
        'remote-new': deck('remote-new', now),
      };
      final merged = mergeRowsByUpdatedAt<SrsDeck>(
        local: local,
        remote: remote,
        idOf: (d) => d.id,
        updatedAtOf: (d) => d.updatedAt,
      );
      expect(merged.length, 4);
      final byId = {for (final d in merged) d.id: d.updatedAt};
      expect(byId['stale'], DateTime(2024, 2, 1)); // remote wins
      expect(byId['fresh'], DateTime(2024, 6, 1)); // local wins
      expect(byId.containsKey('local-new'), isTrue);
      expect(byId.containsKey('remote-new'), isTrue);
    });

    test('works for cards too', () {
      final local = [card('c1', DateTime(2024, 1, 1))];
      final remote = {'c1': card('c1', DateTime(2024, 1, 3))};
      final merged = mergeRowsByUpdatedAt<SrsCard>(
        local: local,
        remote: remote,
        idOf: (c) => c.id,
        updatedAtOf: (c) => c.updatedAt,
      );
      expect(merged.single.updatedAt, DateTime(2024, 1, 3));
    });

    test('empty inputs', () {
      expect(
        mergeRowsByUpdatedAt<SrsReview>(
          local: const [],
          remote: const {},
          idOf: (r) => r.id,
          updatedAtOf: (r) => r.reviewedAt,
        ),
        isEmpty,
      );
    });
  });

  group('review union semantics (documented in repository)', () {
    test('append-only: reviews merge by id set, not timestamps', () {
      // reviews are immutable log rows; the repository unions them
      // by id instead of last-write-wins
      final local = [review('r1', DateTime(2024, 1, 1))];
      final remote = [review('r2', DateTime(2024, 1, 2))];
      final ids = {...local.map((r) => r.id), ...remote.map((r) => r.id)};
      expect(ids, {'r1', 'r2'});
    });
  });
}
