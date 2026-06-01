import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'services/live_analytics_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';

import 'iap_service.dart';

class PaywallPage extends StatefulWidget {
  const PaywallPage({super.key});

  @override
  State<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends State<PaywallPage>
    with TickerProviderStateMixin {
  late final AnimationController _bgController;
  late final AnimationController _entryController;
  late final AnimationController _pulseController;

  final IAPService _iapService = IAPService.instance;

  bool _isActivatingPremium = false;
  bool _isBuyingCoins = false;
  bool _isStoreLoading = true;
  bool _isStoreAvailable = false;

  String _selectedPlan = 'yearly';
  String? _activeCoinProductId;

  List<ProductDetails> _products = [];
  String? _storeError;
  Set<String> _missingProductIds = const {};

  String get _storeName => _iapService.storeName;

  static const String _privacyPolicyUrl =
      'https://gullucimen23-web.github.io/gullucimen23.github.io/privacy.html';

  static const String _termsOfUseUrl =
      'https://gullucimen23-web.github.io/gullucimen23.github.io/terms.html';

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Link açılamadı: $url')),
      );
    }
  }

  String get _storeUnavailableText {
    if (_storeError != null && _storeError!.trim().isNotEmpty) {
      return '$_storeName mağazası şu anda yüklenemedi. Detay: $_storeError';
    }

    if (_missingProductIds.isNotEmpty) {
      return 'Premium ve coin paketleri şu anda App Store tarafından hazırlanıyor. Lütfen daha sonra tekrar deneyin.';
    }

    return 'Premium ve coin paketleri şu anda yüklenemedi. Lütfen daha sonra tekrar deneyin.';
  }

  @override
  void initState() {
    super.initState();
    LiveAnalyticsService.instance.trackScreen(screenName: 'Premium & Coin', screenKey: 'premium_coin');

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _initStore();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _pulseController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  Future<void> _initStore() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid == null) {
        if (!mounted) return;
        setState(() {
          _isStoreLoading = false;
          _isStoreAvailable = false;
          _products = [];
          _storeError = 'Kullanıcı oturumu bulunamadı.';
          _missingProductIds = const {};
        });
        return;
      }

      final available = await _iapService.isAvailable();
      List<ProductDetails> products = [];

      if (available) {
        products = await _iapService.loadProducts();
      }

      _iapService.listenPurchases(
        uid: uid,
        onSuccess: (productId) {
          if (!mounted) return;

          final isPremiumSubscription =
              productId == IAPService.premiumMonthly ||
              productId == IAPService.premiumYearly;

          setState(() {
            _isBuyingCoins = false;
            _isActivatingPremium = false;
            _activeCoinProductId = null;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isPremiumSubscription
                    ? 'Premium başarıyla aktif edildi 🎉'
                    : 'Satın alma başarılı: +${_iapService.premiumCoinAmountOf(productId)} Premium Coin',
              ),
            ),
          );
        },
        onError: (message) {
          if (!mounted) return;

          setState(() {
            _isBuyingCoins = false;
            _isActivatingPremium = false;
            _activeCoinProductId = null;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Satın alma hatası: $message'),
            ),
          );
        },
      );

      if (!mounted) return;
      setState(() {
        _isStoreAvailable = available && products.isNotEmpty;
        _products = products;
        _storeError = _iapService.lastStoreError;
        _missingProductIds = _iapService.lastNotFoundProductIds;
        _isStoreLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isStoreLoading = false;
        _isStoreAvailable = false;
        _products = [];
        _storeError = e.toString();
        _missingProductIds = const {};
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$_storeName mağazası yüklenemedi.'),
        ),
      );
    }
  }

  Future<void> _reloadStore() async {
    if (!mounted) return;

    setState(() {
      _isStoreLoading = true;
      _storeError = null;
      _missingProductIds = const {};
      _products = [];
    });

    await _initStore();
  }

  Future<void> _restorePurchases() async {
    try {
      await _iapService.restorePurchases();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Önceki satın alımlar kontrol ediliyor...'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Satın alımlar geri yüklenemedi: $e'),
        ),
      );
    }
  }

  ProductDetails? _productById(String productId) {
    try {
      return _products.firstWhere((p) => p.id == productId);
    } catch (_) {
      return null;
    }
  }

  ProductDetails? get _monthlyProduct =>
      _productById(IAPService.premiumMonthly);

  ProductDetails? get _yearlyProduct =>
      _productById(IAPService.premiumYearly);

  ProductDetails? get _selectedSubscriptionProduct {
    return _selectedPlan == 'yearly' ? _yearlyProduct : _monthlyProduct;
  }

  String _fallbackSubscriptionPrice(String plan) {
    switch (plan) {
      case 'monthly':
        return 'Fiyat App Store’dan yükleniyor';
      case 'yearly':
        return 'Fiyat App Store’dan yükleniyor';
      default:
        return '';
    }
  }

  Future<void> _buyPremiumCoinProduct(String productId) async {
    if (_isBuyingCoins) return;

    final product = _productById(productId);
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ürün mağazada bulunamadı.'),
        ),
      );
      return;
    }

    setState(() {
      _isBuyingCoins = true;
      _activeCoinProductId = productId;
    });

    try {
      await _iapService.buy(product);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isBuyingCoins = false;
        _activeCoinProductId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Satın alma başlatılamadı: $e'),
        ),
      );
    }
  }

  Future<void> activatePremium() async {
    if (_isActivatingPremium) return;

    final product = _selectedSubscriptionProduct;

    if (!_isStoreAvailable || product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Premium ürün şu anda mağazada alınamadı.'),
        ),
      );
      return;
    }

    setState(() {
      _isActivatingPremium = true;
    });

    try {
      await _iapService.buySubscription(product);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isActivatingPremium = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Premium satın alma başlatılamadı: $e'),
        ),
      );
    }
  }

  Future<void> addCoins(int amount) async {
    String productId;

    switch (amount) {
      case 250:
        productId = IAPService.premiumCoin250;
        break;
      case 2000:
        productId = IAPService.premiumCoin2000;
        break;
      case 5000:
        productId = IAPService.premiumCoin5000;
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Desteklenmeyen coin paketi.'),
          ),
        );
        return;
    }

    await _buyPremiumCoinProduct(productId);
  }

  Widget _glassCard({
    required Widget child,
    EdgeInsetsGeometry? padding,
    BorderRadius? radius,
  }) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: radius ?? BorderRadius.circular(28),
        color: Colors.white.withOpacity(0.08),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withOpacity(0.10),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildHero() {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0, 0.45, curve: Curves.easeOut),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _entryController,
            curve: const Interval(0, 0.45, curve: Curves.easeOutCubic),
          ),
        ),
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final glow = 0.84 + (_pulseController.value * 0.16);

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF4C1D95).withOpacity(glow),
                    const Color(0xFF7C3AED).withOpacity(glow),
                    const Color(0xFFDB2777).withOpacity(glow),
                  ],
                ),
                border: Border.all(color: Colors.white.withOpacity(0.14)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withOpacity(0.28),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: child,
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: Colors.white.withOpacity(0.14),
                    ),
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Falix Seni Zamanla Tanır ✨',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            height: 1.05,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Önceki fallarını hatırlayan, ilişki enerjini takip eden ve sana daha kişisel yorumlar açan özel deneyim.",
                          style: TextStyle(
                            color: Colors.white70,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: const [
                  _HeroChip(
                    icon: Icons.all_inclusive_rounded,
                    label: 'Kişisel Hafıza',
                  ),
                  _HeroChip(
                    icon: Icons.block_rounded,
                    label: 'Gizli Mesajlar',
                  ),
                  _HeroChip(
                    icon: Icons.auto_awesome_rounded,
                    label: 'Derin Yorum',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required String id,
    required String title,
    required String price,
    required String subtitle,
    required String badge,
    required bool highlighted,
  }) {
    final isSelected = _selectedPlan == id;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPlan = id;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: isSelected
              ? const LinearGradient(
                  colors: [
                    Color(0xFF7C3AED),
                    Color(0xFFDB2777),
                    Color(0xFFFFB703),
                  ],
                )
              : null,
          color: isSelected ? null : Colors.white.withOpacity(0.08),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: const Color(0xFF7C3AED).withOpacity(0.24),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            color: const Color(0xFF130E21),
            border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: highlighted
                            ? const Color(0xFFFFD166).withOpacity(0.16)
                            : Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          color: highlighted
                              ? const Color(0xFFFFD166)
                              : Colors.white70,
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                    const Spacer(),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFFFD166)
                              : Colors.white24,
                          width: 2,
                        ),
                        color: isSelected
                            ? const Color(0xFFFFD166)
                            : Colors.transparent,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.black,
                            )
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  price,
                  style: const TextStyle(
                    color: Color(0xFFFFD166),
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumSection() {
    final monthlyPrice =
        _monthlyProduct?.price ?? _fallbackSubscriptionPrice('monthly');
    final yearlyPrice =
        _yearlyProduct?.price ?? _fallbackSubscriptionPrice('yearly');

    final canBuyPremium =
        !_isStoreLoading && _isStoreAvailable && _selectedSubscriptionProduct != null;

    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.15, 0.65, curve: Curves.easeOut),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.07),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _entryController,
            curve: const Interval(0.15, 0.65, curve: Curves.easeOutCubic),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Premium’u Aç ve Falix’i Kişiselleştir',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: Colors.white.withOpacity(0.05),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.workspace_premium_rounded,
                    color: Color(0xFFFFD166),
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Premium ile Falix önceki fallarını hatırlar, gizli mesajları açar, daha uzun ilişki ve kader yorumları üretir.',
                      style: TextStyle(
                        color: Colors.white70,
                        height: 1.4,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildPlanCard(
              id: 'monthly',
              title: 'Aylık Premium',
              price: monthlyPrice,
              subtitle:
                  'Süre: 1 ay. Abonelik App Store üzerinden otomatik yenilenir.',
              badge: 'Esnek',
              highlighted: false,
            ),
            const SizedBox(height: 14),
            _buildPlanCard(
              id: 'yearly',
              title: 'Yıllık Premium',
              price: yearlyPrice,
              subtitle:
                  'Süre: 1 yıl. Abonelik App Store üzerinden otomatik yenilenir.',
              badge: 'En Popüler',
              highlighted: true,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    (_isActivatingPremium || !canBuyPremium) ? null : activatePremium,
                icon: _isActivatingPremium
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.workspace_premium_rounded),
                label: Text(
                  _isActivatingPremium
                      ? 'İşleniyor...'
                      : canBuyPremium
                          ? 'Premium’u Aç'
                          : _isStoreLoading
                              ? 'Mağaza Kontrol Ediliyor'
                              : 'Premium Şu Anda Kullanılamıyor',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.white24,
                  disabledForegroundColor: Colors.white70,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _isStoreLoading
                  ? 'Premium ürünleri yükleniyor...'
                  : _isStoreAvailable
                      ? 'Premium ile kişisel hafıza, gizli mesajlar, reklamsız kullanım ve daha derin yorumlar açılır.'
                      : _storeUnavailableText,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoinPack({
    required int amount,
    required String productId,
    required String title,
    required String subtitle,
    required String fallbackPrice,
    required Color accent,
  }) {
    final product = _productById(productId);
    final priceText = product?.price ?? fallbackPrice;
    final canBuy = !_isStoreLoading && _isStoreAvailable && product != null;
    final isThisLoading = _isBuyingCoins && _activeCoinProductId == productId;

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            accent.withOpacity(0.95),
            accent.withOpacity(0.35),
          ],
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: const Color(0xFF130E21),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: (_isBuyingCoins || !canBuy) ? null : () => addCoins(amount),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: accent.withOpacity(0.16),
                  ),
                  child: Icon(
                    Icons.monetization_on_rounded,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.4,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      priceText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (isThisLoading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Text(
                        canBuy
                            ? 'Satın Al'
                            : _isStoreLoading
                                ? 'Kontrol ediliyor'
                                : 'Kullanılamıyor',
                        style: TextStyle(
                          color: canBuy ? accent : Colors.white38,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoinsSection() {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.35, 1, curve: Curves.easeOut),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.07),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _entryController,
            curve: const Interval(0.35, 1, curve: Curves.easeOutCubic),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Uzman ve Derin Yorum Coinleri',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            _buildCoinPack(
              amount: 250,
              productId: IAPService.premiumCoin250,
              title: '250 Premium Coin',
              subtitle:
                  'İlk uzman mesajı veya derin yorum denemesi için ideal.',
              fallbackPrice: 'Paket',
              accent: const Color(0xFFFFC94D),
            ),
            const SizedBox(height: 12),
            _buildCoinPack(
              amount: 2000,
              productId: IAPService.premiumCoin2000,
              title: '2000 Premium Coin',
              subtitle:
                  'İlişki, kader ve gerçek uzman yorumları için en dengeli seçim.',
              fallbackPrice: 'Paket',
              accent: const Color(0xFFA98BFF),
            ),
            const SizedBox(height: 12),
            _buildCoinPack(
              amount: 5000,
              productId: IAPService.premiumCoin5000,
              title: '5000 Premium Coin',
              subtitle:
                  'Sık uzman desteği ve yoğun derin yorum kullanımı için güçlü bakiye.',
              fallbackPrice: 'Paket',
              accent: const Color(0xFFFA9BFF),
            ),
            const SizedBox(height: 10),
            Text(
              _isStoreLoading
                  ? 'Mağaza ürünleri yükleniyor...'
                  : _isStoreAvailable
                      ? 'Satın alımlar doğrudan $_storeName üzerinden güvenli şekilde gerçekleştirilir.'
                      : _storeUnavailableText,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isStoreLoading ? null : _reloadStore,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Tekrar Dene'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(0.25)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isStoreLoading ? null : _restorePurchases,
                    icon: const Icon(Icons.restore_rounded),
                    label: const Text('Geri Yükle'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(0.25)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomInfo() {
    return _glassCard(
      child: Column(
        children: [
          const Text(
            'Premium ve Abonelik Bilgileri',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Falix Premium Monthly: 1 aylık otomatik yenilenen abonelik.\n'
            'Falix Premium Yearly: 1 yıllık otomatik yenilenen abonelik.\n\n'
            'Fiyatlar satın alma işleminden önce App Store ödeme ekranında gösterilir. '
            'Abonelik iptal edilmediği sürece otomatik yenilenir. '
            'Abonelik yönetimi ve iptal işlemleri App Store hesap ayarlarından yapılır.\n\n'
            'Satın almadan önce Gizlilik Politikası ve Kullanım Koşulları linklerine erişebilirsiniz.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              height: 1.6,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: () => _openUrl(_termsOfUseUrl),
                child: const Text('Kullanım Koşulları'),
              ),
              TextButton(
                onPressed: () => _openUrl(_privacyPolicyUrl),
                child: const Text('Gizlilik Politikası'),
              ),
              TextButton(
                onPressed: _restorePurchases,
                child: const Text('Satın Alımları Geri Yükle'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090613),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Falix Premium',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, child) {
          return Container(
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
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _PaywallBackgroundPainter(
                      progress: _bgController.value,
                    ),
                  ),
                ),
                Positioned(
                  top: -40,
                  left: -30,
                  child: _GlowOrb(
                    size: 180,
                    color: const Color(0xFF7C3AED).withOpacity(0.24),
                  ),
                ),
                Positioned(
                  top: 120,
                  right: -20,
                  child: _GlowOrb(
                    size: 150,
                    color: const Color(0xFFDB2777).withOpacity(0.16),
                  ),
                ),
                Positioned(
                  bottom: 100,
                  left: -20,
                  child: _GlowOrb(
                    size: 160,
                    color: const Color(0xFFFFB703).withOpacity(0.10),
                  ),
                ),
                Positioned(
                  bottom: -40,
                  right: -30,
                  child: _GlowOrb(
                    size: 180,
                    color: const Color(0xFF2563EB).withOpacity(0.12),
                  ),
                ),
                SafeArea(
                  child: child!,
                ),
              ],
            ),
          );
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          child: Column(
            children: [
              _buildHero(),
              const SizedBox(height: 18),
              _buildPremiumSection(),
              const SizedBox(height: 14),
              _buildCoinsSection(),
              const SizedBox(height: 14),
              _buildBottomInfo(),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withOpacity(0.12),
        border: Border.all(
          color: Colors.white.withOpacity(0.14),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: 80,
              spreadRadius: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _PaywallBackgroundPainter extends CustomPainter {
  final double progress;

  _PaywallBackgroundPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final starsPaint = Paint()..style = PaintingStyle.fill;

    final starOffsets = <Offset>[
      Offset(size.width * 0.14, size.height * 0.12),
      Offset(size.width * 0.28, size.height * 0.20),
      Offset(size.width * 0.82, size.height * 0.14),
      Offset(size.width * 0.72, size.height * 0.28),
      Offset(size.width * 0.18, size.height * 0.46),
      Offset(size.width * 0.84, size.height * 0.56),
      Offset(size.width * 0.36, size.height * 0.72),
      Offset(size.width * 0.66, size.height * 0.82),
      Offset(size.width * 0.22, size.height * 0.88),
    ];

    for (var i = 0; i < starOffsets.length; i++) {
      final twinkle =
          0.25 + 0.75 * ((math.sin((progress * 2 * math.pi) + i) + 1) / 2);
      starsPaint.color = Colors.white.withOpacity(0.08 * twinkle);
      canvas.drawCircle(starOffsets[i], 1.3 + (twinkle * 1.2), starsPaint);
    }

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFFA98BFF).withOpacity(0.07);

    final path1 = Path();
    for (double x = 0; x <= size.width; x++) {
      final y = size.height * 0.22 +
          math.sin((x / 78) + (progress * 2 * math.pi)) * 9;
      if (x == 0) {
        path1.moveTo(x, y);
      } else {
        path1.lineTo(x, y);
      }
    }

    final path2 = Path();
    for (double x = 0; x <= size.width; x++) {
      final y = size.height * 0.68 +
          math.cos((x / 92) + (progress * 2 * math.pi)) * 11;
      if (x == 0) {
        path2.moveTo(x, y);
      } else {
        path2.lineTo(x, y);
      }
    }

    canvas.drawPath(path1, linePaint);
    canvas.drawPath(path2, linePaint);
  }

  @override
  bool shouldRepaint(covariant _PaywallBackgroundPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}