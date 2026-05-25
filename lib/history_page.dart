import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'services/live_analytics_service.dart';

import 'services/user_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage>
    with TickerProviderStateMixin {
  final UserService _userService = UserService();

  late final AnimationController _bgController;
  late final AnimationController _entryController;
  late final AnimationController _pulseController;

  late final Animation<double> _heroFade;
  late final Animation<Offset> _heroSlide;
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;

  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    LiveAnalyticsService.instance.trackScreen(screenName: 'Geçmiş Fallarım', screenKey: 'history');

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _heroFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.42, curve: Curves.easeOut),
    );

    _heroSlide = Tween<Offset>(
      begin: const Offset(0, 0.10),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.42, curve: Curves.easeOutCubic),
      ),
    );

    _contentFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.18, 1, curve: Curves.easeOut),
    );

    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.18, 1, curve: Curves.easeOutCubic),
      ),
    );
  }

  @override
  void dispose() {
    _bgController.dispose();
    _pulseController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  bool _matchesFilter(String type) {
    if (_selectedFilter == 'all') return true;
    return type == _selectedFilter;
  }

  String _typeTitle(String type) {
    switch (type) {
      case 'coffee':
        return 'Kahve Falı';
      case 'tarot':
        return 'Tarot';
      default:
        return 'Fal';
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'coffee':
        return Icons.local_cafe_rounded;
      case 'tarot':
        return Icons.auto_awesome_rounded;
      default:
        return Icons.stars_rounded;
    }
  }

  List<Color> _typeGradient(String type) {
    switch (type) {
      case 'coffee':
        return const [
          Color(0xFF6F4E37),
          Color(0xFF8B5E3C),
          Color(0xFFC08457),
        ];
      case 'tarot':
        return const [
          Color(0xFF4C1D95),
          Color(0xFF7C3AED),
          Color(0xFFDB2777),
        ];
      default:
        return const [
          Color(0xFF243B55),
          Color(0xFF141E30),
        ];
    }
  }

  Color _typeAccent(String type) {
    switch (type) {
      case 'coffee':
        return const Color(0xFFFFD39A);
      case 'tarot':
        return const Color(0xFFFFD978);
      default:
        return const Color(0xFFA98BFF);
    }
  }

  String _formatResult(dynamic raw) {
    if (raw is String) {
      return raw.trim();
    }

    if (raw is Map<String, dynamic>) {
      final greeting = (raw['greeting'] ?? '').toString().trim();
      final overall = (raw['overall'] ?? '').toString().trim();
      final love = (raw['love'] ?? '').toString().trim();
      final career = (raw['career'] ?? '').toString().trim();
      final money = (raw['money'] ?? '').toString().trim();
      final advice = (raw['advice'] ?? '').toString().trim();
      final closing = (raw['closing'] ?? '').toString().trim();

      return [
        if (greeting.isNotEmpty) greeting,
        if (overall.isNotEmpty) '\nGenel Enerji\n$overall',
        if (love.isNotEmpty) '\nAşk\n$love',
        if (career.isNotEmpty) '\nKariyer\n$career',
        if (money.isNotEmpty) '\nPara\n$money',
        if (advice.isNotEmpty) '\nTavsiye\n$advice',
        if (closing.isNotEmpty) '\nKapanış\n$closing',
      ].join('\n');
    }

    return raw?.toString().trim() ?? '';
  }

  String _previewText(String text) {
    final cleaned = text.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length <= 120) return cleaned;
    return '${cleaned.substring(0, 120)}...';
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Tarih bekleniyor';

    final dt = timestamp.toDate().toLocal();
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final yyyy = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');

    return '$dd.$mm.$yyyy • $hh:$min';
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
        borderRadius: radius ?? BorderRadius.circular(26),
        color: Colors.white.withOpacity(0.08),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8E44FF).withOpacity(0.10),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildHero() {
    return FadeTransition(
      opacity: _heroFade,
      child: SlideTransition(
        position: _heroSlide,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final glow = 0.82 + (_pulseController.value * 0.18);

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF4C1D95).withOpacity(glow),
                    const Color(0xFF7C3AED).withOpacity(glow),
                    const Color(0xFFDB2777).withOpacity(glow),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withOpacity(0.26),
                    blurRadius: 40,
                    spreadRadius: 2,
                    offset: const Offset(0, 14),
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withOpacity(0.14),
                ),
              ),
              child: child,
            );
          },
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fal Geçmişin',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Tüm yorumların burada büyülü bir arşiv gibi saklanıyor.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return _glassCard(
      padding: const EdgeInsets.all(10),
      radius: BorderRadius.circular(22),
      child: Row(
        children: [
          Expanded(
            child: _FilterChipButton(
              label: 'Tümü',
              isSelected: _selectedFilter == 'all',
              onTap: () => setState(() => _selectedFilter = 'all'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _FilterChipButton(
              label: 'Tarot',
              isSelected: _selectedFilter == 'tarot',
              onTap: () => setState(() => _selectedFilter = 'tarot'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _FilterChipButton(
              label: 'Kahve',
              isSelected: _selectedFilter == 'coffee',
              onTap: () => setState(() => _selectedFilter = 'coffee'),
            ),
          ),
        ],
      ),
    );
  }

  void _showReadingDetail({
    required String type,
    required String result,
    required Timestamp? createdAt,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final accent = _typeAccent(type);
        final gradients = _typeGradient(type);

        return Container(
          height: MediaQuery.of(context).size.height * 0.84,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF140A26),
                Color(0xFF2A1244),
                Color(0xFF090B18),
              ],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              child: Column(
                children: [
                  Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.24),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: gradients,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: gradients.first.withOpacity(0.24),
                          blurRadius: 26,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            _typeIcon(type),
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _typeTitle(type),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(createdAt),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        color: Colors.white.withOpacity(0.08),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withOpacity(0.12),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          result.isEmpty ? 'Yorum bulunamadı.' : result,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 15.2,
                            height: 1.75,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        'Kapat',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final text = _selectedFilter == 'all'
        ? 'Henüz kayıtlı falın yok.'
        : _selectedFilter == 'tarot'
            ? 'Henüz tarot geçmişin yok.'
            : 'Henüz kahve falı geçmişin yok.';

    return _glassCard(
      radius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 26),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
              child: const Icon(
                Icons.auto_stories_rounded,
                color: Colors.white70,
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Arşiv Şu An Sessiz',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadingCard(DocumentSnapshot<Map<String, dynamic>> doc, int index) {
    final data = doc.data() ?? {};
    final type = (data['type'] ?? 'unknown').toString();
    final createdAt = data['createdAt'] as Timestamp?;
    final formattedResult = _formatResult(data['result']);
    final preview = _previewText(formattedResult);
    final accent = _typeAccent(type);
    final gradients = _typeGradient(type);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + (index * 70)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 18 * (1 - value)),
          child: Opacity(
            opacity: value.clamp(0, 1),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () => _showReadingDetail(
          type: type,
          result: formattedResult,
          createdAt: createdAt,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                gradients.first.withOpacity(0.90),
                gradients.last.withOpacity(0.35),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: gradients.first.withOpacity(0.18),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              color: const Color(0xFF120F1E).withOpacity(0.92),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: gradients,
                          ),
                        ),
                        child: Icon(
                          _typeIcon(type),
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _typeTitle(type),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDate(createdAt),
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: accent.withOpacity(0.14),
                          border: Border.all(color: accent.withOpacity(0.18)),
                        ),
                        child: Text(
                          type == 'tarot' ? 'Tarot' : type == 'coffee' ? 'Kahve' : 'Fal',
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.white.withOpacity(0.04),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Text(
                      preview.isEmpty ? 'Yorum metni boş.' : preview,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.55,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(
                        Icons.visibility_rounded,
                        size: 18,
                        color: accent,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Detayı aç',
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white54,
                        size: 16,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _userService.readingsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _glassCard(
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return _glassCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Geçmiş yüklenirken hata oluştu:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final filteredDocs = docs.where((doc) {
          final type = (doc.data()['type'] ?? '').toString();
          return _matchesFilter(type);
        }).toList();

        if (filteredDocs.isEmpty) {
          return _buildEmptyState();
        }

        return Column(
          children: [
            _glassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              radius: BorderRadius.circular(22),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFFFFD978),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${filteredDocs.length} kayıt bulundu',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ListView.builder(
              itemCount: filteredDocs.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                return _buildReadingCard(filteredDocs[index], index);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF140A26),
            Color(0xFF2A1244),
            Color(0xFF090B18),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _bgController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _HistoryBackgroundPainter(
                        progress: _bgController.value,
                      ),
                    );
                  },
                ),
              ),
            ),
            SafeArea(
              child: FadeTransition(
                opacity: _contentFade,
                child: SlideTransition(
                  position: _contentSlide,
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    icon: const Icon(
                                      Icons.arrow_back_ios_new_rounded,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(999),
                                      color: Colors.white.withOpacity(0.08),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.08),
                                      ),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(
                                          Icons.library_books_rounded,
                                          color: Color(0xFFFFD978),
                                          size: 16,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Geçmiş Arşivi',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _buildHero(),
                              const SizedBox(height: 16),
                              _buildFilterChips(),
                              const SizedBox(height: 16),
                              _buildContent(),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isSelected
              ? const LinearGradient(
                  colors: [
                    Color(0xFF7C3AED),
                    Color(0xFFDB2777),
                  ],
                )
              : null,
          color: isSelected ? null : Colors.white.withOpacity(0.04),
          border: Border.all(
            color: isSelected
                ? Colors.white.withOpacity(0.14)
                : Colors.white.withOpacity(0.06),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withOpacity(0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(isSelected ? 1 : 0.82),
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
          ),
        ),
      ),
    );
  }
}

class _HistoryBackgroundPainter extends CustomPainter {
  final double progress;

  _HistoryBackgroundPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 18; i++) {
      final x =
          (size.width / 18) * i + math.sin((progress * 2 * math.pi) + i) * 12;
      final y = (size.height * ((i % 6) / 6)) +
          math.cos((progress * 2 * math.pi) + i) * 20;

      paint.color = Colors.white.withOpacity(0.028);
      canvas.drawCircle(
        Offset(x, y.abs() % size.height),
        1.4 + (i % 3).toDouble(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HistoryBackgroundPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}