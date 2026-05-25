import 'dart:math';
import 'package:flutter/material.dart';

import 'services/live_analytics_service.dart';

import 'services/user_service.dart';

class SpinWheelPage extends StatefulWidget {
  const SpinWheelPage({super.key});

  @override
  State<SpinWheelPage> createState() => _SpinWheelPageState();
}

class _SpinWheelPageState extends State<SpinWheelPage>
    with SingleTickerProviderStateMixin {
  final UserService _userService = UserService();
  final Random _random = Random();

  bool _isLoading = true;
  bool _isSpinning = false;
  String _resultText = '';
  Map<String, dynamic>? _status;

  late final AnimationController _spinController;

  static const int _paidSpinCost = 30;

  static const List<Map<String, dynamic>> _freeRewards = [
    {'label': '10 Coin', 'type': 'coin', 'value': 10, 'weight': 24},
    {'label': '20 Coin', 'type': 'coin', 'value': 20, 'weight': 22},
    {'label': '30 Coin', 'type': 'coin', 'value': 30, 'weight': 16},
    {'label': '50 Coin', 'type': 'coin', 'value': 50, 'weight': 10},
    {'label': 'Ücretsiz Tarot', 'type': 'freeTarot', 'value': 1, 'weight': 8},
    {'label': 'Ücretsiz Kahve', 'type': 'freeCoffee', 'value': 1, 'weight': 7},
    {'label': 'Reklamsız Fal Hakkı', 'type': 'adFree', 'value': 1, 'weight': 4},
    {'label': '25 Premium Coin', 'type': 'premiumCoin', 'value': 25, 'weight': 7},
    {'label': '50 Premium Coin', 'type': 'premiumCoin', 'value': 50, 'weight': 4},
    {'label': 'Uzman Mesaj Hakkı', 'type': 'expertMessage', 'value': 1, 'weight': 2},
    {'label': 'JACKPOT 100 Premium Coin', 'type': 'premiumCoin', 'value': 100, 'weight': 1},
    {'label': 'Boş Tur', 'type': 'miss', 'value': 0, 'weight': 6},
  ];

  static const List<Map<String, dynamic>> _paidRewards = [
    {'label': '5 Coin', 'type': 'coin', 'value': 5, 'weight': 20},
    {'label': '10 Coin', 'type': 'coin', 'value': 10, 'weight': 20},
    {'label': '20 Coin', 'type': 'coin', 'value': 20, 'weight': 18},
    {'label': '30 Coin', 'type': 'coin', 'value': 30, 'weight': 12},
    {'label': '40 Coin', 'type': 'coin', 'value': 40, 'weight': 8},
    {'label': 'Ücretsiz Tarot', 'type': 'freeTarot', 'value': 1, 'weight': 7},
    {'label': 'Ücretsiz Kahve', 'type': 'freeCoffee', 'value': 1, 'weight': 6},
    {'label': 'Reklamsız Fal Hakkı', 'type': 'adFree', 'value': 1, 'weight': 3},
    {'label': '10 Premium Coin', 'type': 'premiumCoin', 'value': 10, 'weight': 5},
    {'label': '25 Premium Coin', 'type': 'premiumCoin', 'value': 25, 'weight': 3},
    {'label': 'Uzman Mesaj Hakkı', 'type': 'expertMessage', 'value': 1, 'weight': 1},
    {'label': 'Boş Tur', 'type': 'miss', 'value': 0, 'weight': 6},
  ];

  @override
  void initState() {
    super.initState();
    LiveAnalyticsService.instance.trackScreen(screenName: 'Şans Çarkı', screenKey: 'spin_wheel');
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _loadStatus();
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    setState(() => _isLoading = true);
    final status = await _userService.getSpinStatus();
    if (!mounted) return;
    setState(() {
      _status = status;
      _isLoading = false;
    });
  }

  Map<String, dynamic> _pickWeightedReward(List<Map<String, dynamic>> rewards) {
    final totalWeight = rewards.fold<int>(
      0,
      (sum, reward) => sum + ((reward['weight'] as int?) ?? 0),
    );

    int pick = _random.nextInt(totalWeight);
    for (final reward in rewards) {
      final weight = (reward['weight'] as int?) ?? 0;
      if (pick < weight) return reward;
      pick -= weight;
    }
    return rewards.first;
  }

  Future<void> _spin() async {
    if (_isSpinning || _status == null) return;

    final spinAccess = await _userService.useSpinChance();
    if (!mounted) return;

    if (spinAccess['success'] != true) {
      final message = (spinAccess['message'] ?? 'Çark çevrilemedi').toString();
      setState(() {
        _resultText = message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }

    final usedCoin = spinAccess['usedCoin'] == true;
    final rewardPool = usedCoin ? _paidRewards : _freeRewards;
    final reward = _pickWeightedReward(rewardPool);

    setState(() {
      _isSpinning = true;
      _resultText = usedCoin
          ? '30 coin kullanıldı • Çark dönüyor...'
          : 'Ücretsiz hakkın kullanıldı • Çark dönüyor...';
    });

    await _spinController.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 350));

    await _userService.applySpinReward(
      rewardType: reward['type'].toString(),
      rewardValue: (reward['value'] as int?) ?? 0,
      rewardLabel: reward['label'].toString(),
      usedCoinSpin: usedCoin,
      spinCost: usedCoin ? _paidSpinCost : 0,
    );

    await _loadStatus();
    if (!mounted) return;

    final label = reward['label'].toString();
    setState(() {
      _isSpinning = false;
      _resultText = reward['type'] == 'miss'
          ? 'Bu tur büyük ödül kaçtı. Tekrar dene ✨'
          : 'Kazandın: $label';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_resultText)),
    );
  }

  String _spinInfoText() {
    if (_status == null) return '';
    final remaining = (_status!['remainingFreeSpins'] ?? 0) as int;
    final freeLimit = (_status!['freeLimit'] ?? 2) as int;
    if (remaining > 0) {
      return 'Bugün $freeLimit haktan $remaining ücretsiz çevirme kaldı';
    }
    return 'Ücretsiz hak bitti • Ekstra çevirme $_paidSpinCost coin';
  }

  Widget _statChip(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: Colors.white.withOpacity(0.06),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: color.withOpacity(0.16),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rewardLegendItem(Map<String, dynamic> reward) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Text(
        reward['label'].toString(),
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }


  Widget _ownedRightsCard() {
    final status = _status ?? {};
    final freeCoffee = (status['freeCoffeeCount'] ?? 0) as int;
    final freeTarot = (status['freeTarotCount'] ?? 0) as int;
    final expert = (status['expertMessageCount'] ?? 0) as int;
    final adFree = (status['adFreeCount'] ?? 0) as int;
    final total = freeCoffee + freeTarot + expert + adFree;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFC94D), Color(0xFFDB2777)],
                  ),
                ),
                child: const Icon(Icons.inventory_2_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kazanılmış Hakların',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Çarktan çıkan ücretsiz haklar burada kalıcı görünür.',
                      style: TextStyle(color: Colors.white60, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Text(
                '$total hak',
                style: const TextStyle(
                  color: Color(0xFFFFD166),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _rightPill('Kahve', freeCoffee, Icons.coffee_rounded, const Color(0xFFFF9966)),
              _rightPill('Tarot', freeTarot, Icons.auto_awesome_rounded, const Color(0xFFA78BFA)),
              _rightPill('Uzman', expert, Icons.psychology_alt_rounded, const Color(0xFFFF4FC3)),
              _rightPill('Reklamsız', adFree, Icons.block_rounded, const Color(0xFF22D3EE)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rightPill(String label, int value, IconData icon, Color color) {
    final active = value > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: active ? color.withOpacity(0.14) : Colors.white.withOpacity(0.05),
        border: Border.all(
          color: active ? color.withOpacity(0.35) : Colors.white.withOpacity(0.07),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: active ? color : Colors.white38),
          const SizedBox(width: 7),
          Text(
            '$label ×$value',
            style: TextStyle(
              color: active ? Colors.white : Colors.white.withOpacity(0.45),
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final coin = (status?['coin'] ?? 0).toString();
    final premiumCoin = (status?['premiumCoin'] ?? 0).toString();
    final remainingFreeSpins = (status?['remainingFreeSpins'] ?? 0) as int;
    final isPremium = status?['premium'] == true;

    return Scaffold(
      backgroundColor: const Color(0xFF090613),
      appBar: AppBar(
        title: const Text(
          'Şans Çarkı',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0A0812),
                    Color(0xFF140A26),
                    Color(0xFF25103F),
                    Color(0xFF090B18),
                  ],
                ),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _statChip(
                            'Coin',
                            coin,
                            Icons.monetization_on_rounded,
                            const Color(0xFFFFC94D),
                          ),
                          const SizedBox(width: 12),
                          _statChip(
                            'Premium',
                            premiumCoin,
                            Icons.diamond_rounded,
                            const Color(0xFFFA9BFF),
                          ),
                          const SizedBox(width: 12),
                          _statChip(
                            'Hak',
                            '$remainingFreeSpins',
                            Icons.casino_rounded,
                            const Color(0xFF8B5CF6),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _ownedRightsCard(),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF3B1361).withOpacity(0.95),
                              const Color(0xFF7C3AED).withOpacity(0.85),
                              const Color(0xFFDB2777).withOpacity(0.72),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7C3AED).withOpacity(0.22),
                              blurRadius: 30,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Çevir Kazan',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _spinInfoText(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.86),
                                fontSize: 13.5,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 18),
                            AnimatedBuilder(
                              animation: _spinController,
                              builder: (context, child) {
                                final turns = Tween<double>(begin: 0, end: 4.5)
                                    .evaluate(
                                  CurvedAnimation(
                                    parent: _spinController,
                                    curve: Curves.easeOutCubic,
                                  ),
                                );
                                return Transform.rotate(
                                  angle: turns * 2 * pi,
                                  child: child,
                                );
                              },
                              child: Container(
                                width: 220,
                                height: 220,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const SweepGradient(
                                    colors: [
                                      Color(0xFFFFC94D),
                                      Color(0xFF7C3AED),
                                      Color(0xFFDB2777),
                                      Color(0xFF22C55E),
                                      Color(0xFFFFC94D),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.18),
                                    width: 4,
                                  ),
                                ),
                                child: Center(
                                  child: Container(
                                    width: 94,
                                    height: 94,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF120D20),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.12),
                                        width: 3,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.auto_awesome_rounded,
                                      color: Colors.white,
                                      size: 40,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isSpinning ? null : _spin,
                                icon: _isSpinning
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.black,
                                        ),
                                      )
                                    : const Icon(Icons.casino_rounded),
                                label: Text(
                                  remainingFreeSpins > 0
                                      ? 'Ücretsiz Çevir'
                                      : '30 Coin ile Çevir',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                  elevation: 0,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _resultText.isEmpty
                                  ? (isPremium
                                      ? 'Premium kullanıcılar günde 5 ücretsiz çevirebilir'
                                      : 'Premium ile günlük ücretsiz çevirme hakkın artar')
                                  : _resultText,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13.5,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: Colors.white.withOpacity(0.06),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ödül Havuzu',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: (remainingFreeSpins > 0
                                      ? _freeRewards
                                      : _paidRewards)
                                  .map(_rewardLegendItem)
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
