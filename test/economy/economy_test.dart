import 'package:flutter_test/flutter_test.dart';
import 'package:word_reveal/domain/models/difficulty.dart';
import 'package:word_reveal/domain/models/wallet.dart';
import 'package:word_reveal/services/economy/economy_service.dart';

void main() {
  final economy = EconomyService();

  test('longer words earn more, all rewards positive', () {
    expect(economy.wordReward('FOX'), 6);
    expect(economy.wordReward('BUTTERFLY'), 18);
    expect(economy.wordReward('BUTTERFLY'),
        greaterThan(economy.wordReward('FOX')));
  });

  test('puzzle bonus scales with difficulty', () {
    var previous = -1;
    for (final d in Difficulty.values) {
      final bonus = economy.puzzleCompletionBonus(d);
      expect(bonus, greaterThan(previous));
      previous = bonus;
    }
  });

  test('earn accumulates coins and lifetime earnings', () {
    var wallet = const Wallet(coins: 0, lifetimeEarned: 0);
    wallet = economy.earn(wallet, 10);
    wallet = economy.earn(wallet, 5);
    expect(wallet.coins, 15);
    expect(wallet.lifetimeEarned, 15);
  });

  test('spend succeeds when affordable and never goes negative', () {
    const wallet = Wallet(coins: 20, lifetimeEarned: 20);
    final after = economy.spend(wallet, 20);
    expect(after, isNotNull);
    expect(after!.coins, 0);
    expect(after.lifetimeEarned, 20, reason: 'spending is not negative earning');
  });

  test('spend refuses when balance is insufficient', () {
    const wallet = Wallet(coins: 14, lifetimeEarned: 100);
    expect(economy.spend(wallet, 15), isNull);
    expect(wallet.coins, 14, reason: 'refused spend changes nothing');
  });

  test('negative amounts are programming errors, not silent paths', () {
    const wallet = Wallet(coins: 10, lifetimeEarned: 10);
    expect(() => economy.earn(wallet, -1), throwsArgumentError);
    expect(() => economy.spend(wallet, -1), throwsArgumentError);
  });

  test('every hint type costs an affordable, positive amount', () {
    for (final hint in HintType.values) {
      expect(hint.cost, greaterThan(0));
      expect(hint.cost, lessThanOrEqualTo(EconomyService.startingCoins),
          reason: 'a new player must be able to afford any single hint');
    }
  });

  test('fuzz: random earn/spend sequences never produce a negative balance',
      () {
    var wallet = const Wallet(coins: 0, lifetimeEarned: 0);
    var expected = 0;
    final amounts = [3, 50, 7, 120, 1, 999, 14, 40, 15, 30];
    for (var i = 0; i < 2000; i++) {
      final amount = amounts[i % amounts.length];
      if (i.isEven) {
        wallet = economy.earn(wallet, amount);
        expected += amount;
      } else {
        final result = economy.spend(wallet, amount);
        if (expected >= amount) {
          expected -= amount;
          expect(result, isNotNull);
          wallet = result!;
        } else {
          expect(result, isNull);
        }
      }
      expect(wallet.coins, expected);
      expect(wallet.coins, greaterThanOrEqualTo(0));
    }
  });
}
