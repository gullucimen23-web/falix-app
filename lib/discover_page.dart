import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'discover_result_page.dart';
import 'human_expert_page.dart';
import 'paywall_page.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  static const int _dailyEnergyPremiumCoinCost = 5;
  static const int _dreamPremiumCoinCost = 15;
  static const int _relationshipPremiumCoinCost = 20;

  final _dreamController = TextEditingController();
  final _nameOneController = TextEditingController();
  final _nameTwoController = TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _dreamController.dispose();
    _nameOneController.dispose();
    _nameTwoController.dispose();
    super.dispose();
  }

  DocumentReference<Map<String, dynamic>>? get _userRef {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(uid);
  }

  String get _todayKey {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<Map<String, dynamic>> _loadUserData() async {
    final ref = _userRef;
    if (ref == null) throw Exception('Oturum bulunamadı.');
    final snap = await ref.get();
    return snap.data() ?? {};
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  bool _isPremium(Map<String, dynamic> userData) {
    return userData['premium'] == true || userData['isPremium'] == true;
  }

  Future<bool> _chargeOrAllow({
    required int premiumCoinCost,
    required String featureKey,
    required String featureTitle,
    bool dailyOneFreeForEveryone = false,
  }) async {
    final ref = _userRef;
    if (ref == null) {
      _showMessage('Oturum bulunamadı.');
      return false;
    }

    try {
      return await FirebaseFirestore.instance.runTransaction<bool>((tx) async {
        final snap = await tx.get(ref);
        final data = snap.data() ?? {};

        final premium = _isPremium(data);
        final premiumCoin = _asInt(data['premiumCoin']);
        final today = _todayKey;

        final usageField = '${featureKey}LastFreeDate';

        if (premium) {
          tx.set(ref, {
            'lastDiscoverFeature': featureKey,
            'lastDiscoverAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          return true;
        }

        if (dailyOneFreeForEveryone && data[usageField] != today) {
          tx.set(ref, {
            usageField: today,
            'lastDiscoverFeature': featureKey,
            'lastDiscoverAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          return true;
        }

        if (premiumCoin < premiumCoinCost) {
          return false;
        }

        tx.set(ref, {
          'premiumCoin': premiumCoin - premiumCoinCost,
          'lastDiscoverFeature': featureKey,
          'lastDiscoverAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        final historyRef = ref.collection('premium_coin_history').doc();
        tx.set(historyRef, {
          'type': 'discover_feature_spend',
          'featureKey': featureKey,
          'featureTitle': featureTitle,
          'amount': -premiumCoinCost,
          'balanceAfter': premiumCoin - premiumCoinCost,
          'createdAt': FieldValue.serverTimestamp(),
        });

        return true;
      });
    } catch (e) {
      _showMessage('Coin kontrol hatası: $e');
      return false;
    }
  }

  Future<void> _saveDiscoverHistory({
    required String type,
    required String title,
    required String input,
    required String result,
  }) async {
    final ref = _userRef;
    if (ref == null) return;

    final historyRef = ref.collection('readings').doc();

    await historyRef.set({
      'type': type,
      'title': title,
      'input': input,
      'result': result,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _openResult({
    required String title,
    required String subtitle,
    required String result,
    required String badge,
    required IconData icon,
    required Color accent,
    required String type,
    required String input,
  }) async {
    await _saveDiscoverHistory(
      type: type,
      title: title,
      input: input,
      result: result,
    );

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DiscoverResultPage(
          title: title,
          subtitle: subtitle,
          result: result,
          badge: badge,
          icon: icon,
          accent: accent,
        ),
      ),
    );
  }

  Future<void> _dailyEnergy() async {
    if (_loading) return;

    setState(() => _loading = true);

    try {
      final userData = await _loadUserData();
      final premium = _isPremium(userData);
      final today = _todayKey;
      final alreadyUsedFree = userData['daily_energyLastFreeDate'] == today;

      final allowed = await _chargeOrAllow(
        premiumCoinCost: _dailyEnergyPremiumCoinCost,
        featureKey: 'daily_energy',
        featureTitle: 'Günlük Enerji',
        dailyOneFreeForEveryone: true,
      );

      if (!allowed) {
        _openPaywall('Günlük Enerji için Premium Coin gerekli.');
        return;
      }

      final messages = [
        'Bugün sezgilerin normalden daha güçlü. Küçük işaretleri hafife alma; özellikle akşam saatlerinde içinden geçen bir konu netleşebilir.\n\nAşk tarafında beklemediğin bir mesaj veya içsel farkındalık oluşabilir. Para ve iş tarafında ise acele karar yerine sakin analiz daha kazançlı görünür.',
        'Bugünün enerjisi yenilenme ve arınma üzerine. Kafanı yoran bir konuya uzaktan bakarsan cevabı daha kolay bulacaksın.\n\nEski bir düşünce döngüsünü kapatıp yeni bir başlangıç için alan açıyorsun.',
        'Bugün kalp enerjin açık. İlişkilerde açık konuşmak, beklediğinden daha iyi bir kapı açabilir.\n\nKırgınlıkları büyütmek yerine, ne istediğini net söylemek sana iyi gelecek.',
        'Bugün maddi ve kişisel kararlar için dikkatli ama cesur bir enerji var. Acele etme; doğru fırsat kendini belli edecek.\n\nKendine güven ama her söze de hemen inanma.',
      ];

      final result = messages[DateTime.now().day % messages.length];

      final badge = premium
          ? 'Premium üye • ücretsiz'
          : alreadyUsedFree
              ? '$_dailyEnergyPremiumCoinCost Premium Coin kullanıldı'
              : 'Bugünkü ücretsiz hakkın kullanıldı';

      await _openResult(
        title: 'Günlük Enerjin ✨',
        subtitle: 'Bugünün ruhsal mesajı ve sezgisel yönlendirmesi.',
        result: result,
        badge: badge,
        icon: Icons.wb_twilight_rounded,
        accent: const Color(0xFF7C3AED),
        type: 'daily_energy',
        input: today,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _dreamInterpretation() async {
    if (_loading) return;

    final dream = _dreamController.text.trim();
    if (dream.isEmpty) {
      _showMessage('Rüyanı birkaç cümleyle yaz.');
      return;
    }

    setState(() => _loading = true);

    try {
      final userData = await _loadUserData();
      final premium = _isPremium(userData);

      final allowed = await _chargeOrAllow(
        premiumCoinCost: _dreamPremiumCoinCost,
        featureKey: 'dream_interpretation',
        featureTitle: 'Rüya Yorumu',
      );

      if (!allowed) {
        _openPaywall('Rüya Yorumu için Premium Coin gerekli.');
        return;
      }

      final result =
          'Rüyanda öne çıkan ana sembol, bilinçaltında cevap aradığın bir konunun artık yüzeye çıkmaya başladığını gösteriyor.\n\n'
          'Rüya içeriğin:\n“$dream”\n\n'
          'Bu rüya özellikle içsel karar, geçmişten gelen bir duygu veya ilişkisel bir bağ ile bağlantılı olabilir. '
          'Eğer rüyada su, karanlık, eski biri, yol, ev veya hayvan sembolleri varsa bu genellikle ruhsal geçiş ve sezgisel uyarı anlamına gelir.\n\n'
          'Falix mesajı: İçinde bastırdığın bir cevap var. Bu cevap dışarıdan değil, kendi sezginden gelecek. Bugün acele karar verme; ama hislerini de yok sayma.';

      await _openResult(
        title: 'Rüya Yorumu 🌙',
        subtitle: 'Rüyanın sembolleri ve bilinçaltı mesajı.',
        result: result,
        badge: premium
            ? 'Premium üye • ücretsiz'
            : '$_dreamPremiumCoinCost Premium Coin kullanıldı',
        icon: Icons.nightlight_round,
        accent: const Color(0xFF6366F1),
        type: 'dream',
        input: dream,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _relationshipAnalysis() async {
    if (_loading) return;

    final first = _nameOneController.text.trim();
    final second = _nameTwoController.text.trim();

    if (first.isEmpty || second.isEmpty) {
      _showMessage('İki isim de gerekli.');
      return;
    }

    setState(() => _loading = true);

    try {
      final userData = await _loadUserData();
      final premium = _isPremium(userData);

      final allowed = await _chargeOrAllow(
        premiumCoinCost: _relationshipPremiumCoinCost,
        featureKey: 'relationship_analysis',
        featureTitle: 'İlişki Uyumu',
      );

      if (!allowed) {
        _openPaywall('İlişki Uyumu için Premium Coin gerekli.');
        return;
      }

      final score = 62 + ((first.length * 7 + second.length * 11) % 34);

      final result =
          '$first ve $second arasında %$score civarında bir enerji uyumu görünüyor.\n\n'
          'Bu bağda ilk dikkat çeken şey çekim enerjisinin güçlü olması; fakat ilişkinin yönünü iletişim şekli belirliyor. '
          'Bir taraf daha sezgisel ve duygusal davranırken, diğer taraf kontrol etmeye veya geri çekilmeye meyilli olabilir.\n\n'
          'Güçlü taraf: Aranızdaki merak ve görünmez bağ kolay kolay kopmuyor.\n\n'
          'Zorlayıcı taraf: Beklenti ve gurur aynı anda yükselirse yanlış anlaşılmalar artabilir.\n\n'
          'Falix mesajı: Bu bağda netlik gelmeden karar vermek yerine, duyguların davranışla desteklenip desteklenmediğine bakmalısın.';

      await _openResult(
        title: 'İlişki Uyumu 💘',
        subtitle: '$first ve $second arasındaki enerji analizi.',
        result: result,
        badge: premium
            ? 'Premium üye • ücretsiz'
            : '$_relationshipPremiumCoinCost Premium Coin kullanıldı',
        icon: Icons.favorite_rounded,
        accent: const Color(0xFFFB7185),
        type: 'relationship',
        input: '$first & $second',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openPaywall(String message) {
    _showMessage(message);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PaywallPage()),
    );
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _openExpert() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HumanExpertPage()),
    );
  }

  void _openPaywallManual() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PaywallPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090613),
      appBar: AppBar(
        title: const Text(
          'Keşfet',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF090613), Color(0xFF140A26), Color(0xFF25103F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
              children: [
                _hero(),
                const SizedBox(height: 16),
                _moduleCard(
                  icon: Icons.wb_twilight_rounded,
                  title: 'Günlük Enerji',
                  subtitle: 'Premium üyeler ücretsiz. Standart kullanıcılar günde 1 kez ücretsiz, sonra $_dailyEnergyPremiumCoinCost Premium Coin.',
                  price: 'Günde 1 ücretsiz • sonra $_dailyEnergyPremiumCoinCost PC',
                  colorA: const Color(0xFF7C3AED),
                  colorB: const Color(0xFFDB2777),
                  onTap: _dailyEnergy,
                ),
                const SizedBox(height: 14),
                _inputCard(
                  icon: Icons.nightlight_round,
                  title: 'Rüya Yorumu',
                  subtitle: 'Premium üyeler ücretsiz. Standart kullanıcılar $_dreamPremiumCoinCost Premium Coin ile rüya yorumu alır.',
                  price: '$_dreamPremiumCoinCost Premium Coin',
                  controller: _dreamController,
                  hint: 'Örn: Rüyamda deniz ve eski sevgilimi gördüm...',
                  buttonText: 'Rüyamı Yorumla',
                  onTap: _dreamInterpretation,
                ),
                const SizedBox(height: 14),
                _relationshipCard(),
                const SizedBox(height: 16),
                _salesCard(),
              ],
            ),
          ),
          if (_loading)
            Container(
              color: Colors.black.withOpacity(0.32),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFFFFD166)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF4C1D95), Color(0xFFDB2777)],
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.explore_rounded, color: Colors.white, size: 34),
          SizedBox(height: 14),
          Text(
            'Bugün neyi keşfetmek istersin?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Günlük enerji, rüya yorumu ve ilişki uyumu. Premium üyeler tüm keşifleri ücretsiz kullanır.',
            style: TextStyle(color: Colors.white70, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _moduleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String price,
    required Color colorA,
    required Color colorB,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(colors: [colorA, colorB]),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 32),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 5),
                      Text(subtitle, style: const TextStyle(color: Colors.white70, height: 1.35)),
                      const SizedBox(height: 9),
                      _priceBadge(price),
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

  Widget _inputCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String price,
    required TextEditingController controller,
    required String hint,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return _glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: const Color(0xFFFFD166)),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))),
            _priceBadge(price),
          ]),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: Colors.white70, height: 1.4)),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            minLines: 3,
            maxLines: 5,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withOpacity(0.07),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _relationshipCard() {
    return _glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.favorite_rounded, color: Color(0xFFFB7185)),
            const SizedBox(width: 10),
            const Expanded(child: Text('İlişki Uyumu', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))),
            _priceBadge('$_relationshipPremiumCoinCost Premium Coin'),
          ]),
          const SizedBox(height: 8),
          const Text(
            'Premium üyeler ücretsiz. Standart kullanıcılar Premium Coin ile iki isim arasındaki enerji uyumunu görür.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _smallInput(_nameOneController, 'Sen')),
              const SizedBox(width: 10),
              Expanded(child: _smallInput(_nameTwoController, 'O')),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _relationshipAnalysis,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFB7185),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Uyumu Hesapla'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallInput(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Colors.white.withOpacity(0.07),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _salesCard() {
    return _glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Daha net cevap için gerçek uzmana bağlan', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('AI sana ilk işareti verir. Gerçek uzman ise ilişki, rüya ve özel enerji detaylarını canlı yorumlar.', style: TextStyle(color: Colors.white70, height: 1.45)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _openExpert,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14B8A6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Uzmana Bağlan'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: _openPaywallManual,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.18)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Coin Al'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _priceBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD166).withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFFFD166).withOpacity(0.24)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFFFD166),
          fontWeight: FontWeight.w900,
          fontSize: 11.5,
        ),
      ),
    );
  }

  Widget _glass({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: Colors.white.withOpacity(0.08),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: child,
    );
  }
}
