/// The player's coin balance. All mutation goes through EconomyService,
/// which enforces the invariants (never negative, no unchecked spends).
class Wallet {
  final int coins;
  final int lifetimeEarned;

  const Wallet({required this.coins, required this.lifetimeEarned});

  Map<String, dynamic> toJson() =>
      {'coins': coins, 'lifetimeEarned': lifetimeEarned};

  factory Wallet.fromJson(Map<String, dynamic> json) => Wallet(
        coins: json['coins'] as int,
        lifetimeEarned: json['lifetimeEarned'] as int,
      );
}
