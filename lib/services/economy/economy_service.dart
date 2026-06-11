import '../../domain/models/difficulty.dart';
import '../../domain/models/wallet.dart';

/// Hint types with their coin costs.
enum HintType {
  letter(15),
  direction(20),
  highlight(30),
  imagePreview(40),
  smart(25);

  final int cost;
  const HintType(this.cost);
}

/// Pure coin-economy rules. All wallet math goes through here so the
/// invariants (never negative, no unchecked spends) hold everywhere.
class EconomyService {
  /// Longer words pay more.
  int wordReward(String word) => word.length * 2;

  int puzzleCompletionBonus(Difficulty difficulty) =>
      20 + difficulty.index * 10;

  static const int imageCompletionBonus = 100;
  static const int collectionCompletionBonus = 250;

  /// First-launch grant so a new player can afford early hints.
  static const int startingCoins = 120;

  Wallet earn(Wallet wallet, int amount) {
    if (amount < 0) throw ArgumentError('Earn amount must be >= 0.');
    return Wallet(
      coins: wallet.coins + amount,
      lifetimeEarned: wallet.lifetimeEarned + amount,
    );
  }

  /// Returns the new wallet, or null if [wallet] cannot afford [amount].
  /// A null return is the only refusal path - balances never go negative.
  Wallet? spend(Wallet wallet, int amount) {
    if (amount < 0) throw ArgumentError('Spend amount must be >= 0.');
    if (wallet.coins < amount) return null;
    return Wallet(
      coins: wallet.coins - amount,
      lifetimeEarned: wallet.lifetimeEarned,
    );
  }
}
