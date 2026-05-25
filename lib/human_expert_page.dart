import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'services/live_analytics_service.dart';

import 'expert_chat_page.dart';
import 'paywall_page.dart';

class HumanExpertPage extends StatefulWidget {
  const HumanExpertPage({super.key});

  @override
  State<HumanExpertPage> createState() => _HumanExpertPageState();
}

class _HumanExpertPageState extends State<HumanExpertPage> with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  bool _isProcessing = false;
  _SelectedExpert? _selectedExpert;
  _ExpertService? _selectedService;

  final List<_ExpertService> _services = const [
    _ExpertService(keyName: 'real_coffee', title: 'Derin Kahve Açılımı', shortTitle: 'Kahve', subtitle: 'Fincandaki işaretleri gerçek rehber yorumlasın.', description: 'Fincan enerjini gerçek bir uzman uygulama içinde yorumlar.', premiumCoinPrice: 2000, priceTl: 200, icon: Icons.local_cafe_rounded, colors: [Color(0xFF8B5E3C), Color(0xFFC08457)], suggestedPrompt: 'Kahve falım için gerçek yorum almak istiyorum. Özellikle aşk ve yakın dönem enerjime odaklanılmasını rica ediyorum.'),
    _ExpertService(keyName: 'real_tarot', title: 'Derin Tarot Açılımı', shortTitle: 'Tarot', subtitle: 'Kartların gizli mesajını gerçek rehber açsın.', description: 'Tarot kartlarının enerjisi kişisel ve canlı sohbetle açılır.', premiumCoinPrice: 2000, priceTl: 200, icon: Icons.style_rounded, colors: [Color(0xFF4C1D95), Color(0xFFDB2777)], suggestedPrompt: 'Gerçek tarot yorumu almak istiyorum. Özellikle ilişki ve yakın gelecekteki karar enerjim hakkında yorum istiyorum.'),
    _ExpertService(keyName: 'relationship', title: 'İlişki Analizi', shortTitle: 'İlişki', subtitle: 'Bu bağın yönünü gerçek uzmanla öğren.', description: 'Duygusal mesafe, geri dönüş ihtimali ve ilişkinin yönü yorumlanır.', premiumCoinPrice: 5000, priceTl: 500, icon: Icons.favorite_rounded, colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)], suggestedPrompt: 'İlişkimde son dönemde uzaklaşma var. Karşı tarafın niyeti ve bu bağın geleceği hakkında yorum almak istiyorum.'),
    _ExpertService(keyName: 'destiny', title: 'Bu İnsan Kaderinde mi?', shortTitle: 'Kader', subtitle: 'Ruh bağı ve kader çizgisi yorumu.', description: 'Karmik bağlar, kader çizgisi ve bu kişinin hayatındaki rolü yorumlanır.', premiumCoinPrice: 5000, priceTl: 500, icon: Icons.auto_awesome_rounded, colors: [Color(0xFFF59E0B), Color(0xFFEF4444)], suggestedPrompt: 'Hayatımdaki bu kişinin kaderimde olup olmadığını öğrenmek istiyorum. Aramızdaki bağın neden geldiğini ve uzun vadeli anlamını yorumlar mısın?'),
  ];

  @override
  void initState() { super.initState();
    LiveAnalyticsService.instance.trackScreen(screenName: 'Canlı Uzman', screenKey: 'live_expert'); _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat(reverse: true); }
  @override
  void dispose() { _pulseController.dispose(); super.dispose(); }

  List<_SelectedExpert> _parseExperts(QuerySnapshot<Map<String, dynamic>> snap) {
    final list = snap.docs.map((doc) {
      final d = doc.data();
      final services = d['services'] is List ? List<String>.from((d['services'] as List).map((e) => e.toString())) : <String>[];
      final specs = d['specialties'] is List ? List<String>.from((d['specialties'] as List).map((e) => e.toString())) : <String>[];
      return _SelectedExpert(
        id: doc.id,
        name: (d['name'] ?? d['displayName'] ?? d['email'] ?? 'Falix Uzmanı').toString(),
        email: (d['email'] ?? '').toString(),
        title: (d['title'] ?? 'Spiritüel Uzman').toString(),
        bio: (d['bio'] ?? '').toString(),
        photoUrl: (d['photoUrl'] ?? '').toString(),
        online: d['online'] == true,
        active: d['active'] != false,
        rating: double.tryParse((d['rating'] ?? 5.0).toString()) ?? 5.0,
        reviewCount: int.tryParse((d['reviewCount'] ?? 0).toString()) ?? 0,
        services: services,
        specialties: specs,
      );
    }).where((e) => e.active).toList();
    list.sort((a, b) { if (a.online != b.online) return a.online ? -1 : 1; return a.name.compareTo(b.name); });
    return list;
  }

  bool _expertCanDo(_SelectedExpert expert, _ExpertService service) => expert.services.isEmpty || expert.services.contains(service.keyName);

  Future<void> _startChat() async {
    if (_isProcessing) return;
    final expert = _selectedExpert; final service = _selectedService;
    if (expert == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Önce bir uzman seç.'))); return; }
    if (service == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Önce hizmet seç.'))); return; }
    if (!_expertCanDo(expert, service)) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bu uzman seçilen hizmet için uygun değil.'))); return; }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen önce giriş yap.'))); return; }
    setState(() => _isProcessing = true);

    final db = FirebaseFirestore.instance;
    final userRef = db.collection('users').doc(user.uid);
    final chatRef = db.collection('chats').doc();
    final userChatRef = userRef.collection('expert_chats').doc(chatRef.id);
    final messageRef = chatRef.collection('messages').doc();
    final now = FieldValue.serverTimestamp();
    bool usedFreeExpertMessage = false; int spentPremiumCoin = service.premiumCoinPrice;

    try {
      await db.runTransaction((tx) async {
        final userSnap = await tx.get(userRef);
        if (!userSnap.exists) throw Exception('Kullanıcı bulunamadı.');
        final data = userSnap.data() ?? {};
        final currentPremiumCoin = (data['premiumCoin'] ?? 0) as int;
        final expertMessageCount = (data['expertMessageCount'] ?? 0) as int;

        if (expertMessageCount > 0) {
          usedFreeExpertMessage = true; spentPremiumCoin = 0;
          tx.update(userRef, {'expertMessageCount': expertMessageCount - 1, 'updatedAt': now});
          tx.set(userRef.collection('expert_message_history').doc(chatRef.id), {'type': 'free_expert_chat_used', 'amount': -1, 'balanceAfter': expertMessageCount - 1, 'serviceKey': service.keyName, 'serviceTitle': service.title, 'expertId': expert.id, 'expertName': expert.name, 'chatId': chatRef.id, 'createdAt': now});
        } else {
          if (currentPremiumCoin < service.premiumCoinPrice) throw Exception('Yetersiz Premium Coin.');
          final newBalance = currentPremiumCoin - service.premiumCoinPrice;
          tx.update(userRef, {'premiumCoin': newBalance, 'updatedAt': now});
          tx.set(userRef.collection('premium_coin_history').doc(chatRef.id), {'type': 'expert_chat_purchase', 'amount': -service.premiumCoinPrice, 'balanceAfter': newBalance, 'serviceKey': service.keyName, 'serviceTitle': service.title, 'expertId': expert.id, 'expertName': expert.name, 'chatId': chatRef.id, 'createdAt': now});
        }
        final userName = (user.displayName ?? '').trim().isNotEmpty ? user.displayName!.trim() : (data['email'] ?? user.email ?? 'Falix Kullanıcısı').toString();
        final chatData = {'chatId': chatRef.id, 'userId': user.uid, 'userEmail': user.email, 'userName': userName, 'expertId': expert.id, 'expertName': expert.name, 'expertEmail': expert.email, 'expertPhotoUrl': expert.photoUrl, 'serviceKey': service.keyName, 'serviceTitle': service.title, 'premiumCoinSpent': spentPremiumCoin, 'usedFreeExpertMessage': usedFreeExpertMessage, 'status': 'waiting', 'channel': 'in_app_chat', 'lastMessage': service.suggestedPrompt, 'lastMessageSenderRole': 'user', 'unreadForExpert': 1, 'unreadForUser': 0, 'createdAt': now, 'updatedAt': now, 'lastMessageAt': now};
        tx.set(chatRef, chatData); tx.set(userChatRef, chatData);
        tx.set(messageRef, {'messageId': messageRef.id, 'chatId': chatRef.id, 'senderId': user.uid, 'senderRole': 'user', 'senderName': userName, 'text': service.suggestedPrompt, 'seen': false, 'createdAt': now});
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(usedFreeExpertMessage ? 'Ücretsiz uzman hakkın kullanıldı. ${expert.name} ile sohbet açıldı.' : '$spentPremiumCoin Premium Coin kullanıldı. ${expert.name} ile sohbet açıldı.')));
      await Navigator.push(context, MaterialPageRoute(builder: (_) => ExpertChatPage(chatId: chatRef.id, serviceTitle: service.title, expertName: expert.name)));
    } catch (e) {
      final insufficient = e.toString().contains('Yetersiz Premium Coin');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(insufficient ? 'Bu hizmet için bakiyen yetersiz. Premium Coin paketlerine yönlendiriliyorsun.' : 'İşlem sırasında hata oluştu: $e')));
      if (insufficient) await Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallPage()));
    } finally { if (mounted) setState(() => _isProcessing = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090613),
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF090613), Color(0xFF140A26), Color(0xFF25103F), Color(0xFF090B18)])),
        child: SafeArea(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('experts').snapshots(),
            builder: (context, snapshot) {
              final experts = snapshot.hasData ? _parseExperts(snapshot.data!) : <_SelectedExpert>[];
              if (_selectedExpert == null && experts.isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted && _selectedExpert == null) setState(() => _selectedExpert = experts.first); });
              final visibleServices = _selectedExpert == null ? _services : _services.where((s) => _expertCanDo(_selectedExpert!, s)).toList();
              return ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 28), children: [
                _hero(), const SizedBox(height: 18), _myChats(), const SizedBox(height: 18), _sectionTitle('Online Uzmanını Seç'), const SizedBox(height: 10),
                if (snapshot.connectionState == ConnectionState.waiting) const Center(child: Padding(padding: EdgeInsets.all(18), child: CircularProgressIndicator(color: Color(0xFFFFD166)))) else if (experts.isEmpty) _emptyExperts() else ...experts.map(_expertCard),
                const SizedBox(height: 18), _sectionTitle('Hizmetini Seç'), const SizedBox(height: 10), ...visibleServices.map(_serviceCard), const SizedBox(height: 18), _buyBar(),
              ]);
            },
          ),
        ),
      ),
    );
  }

  Widget _hero() => AnimatedBuilder(animation: _pulseController, builder: (context, child) { final glow = 0.84 + (_pulseController.value * 0.16); return Container(width: double.infinity, padding: const EdgeInsets.all(24), decoration: BoxDecoration(borderRadius: BorderRadius.circular(32), gradient: LinearGradient(colors: [const Color(0xFF4C1D95).withOpacity(glow), const Color(0xFF7C3AED).withOpacity(glow), const Color(0xFFDB2777).withOpacity(glow)]), boxShadow: [BoxShadow(color: const Color(0xFF7C3AED).withOpacity(0.28), blurRadius: 40, offset: const Offset(0, 16))]), child: child); }, child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.support_agent_rounded, color: Colors.white, size: 34), SizedBox(height: 14), Text('Canlı Uzman Rehberliği', style: TextStyle(color: Colors.white, fontSize: 29, fontWeight: FontWeight.w900, height: 1.05)), SizedBox(height: 10), Text('Uzmanını profiline bakarak seç, hizmetini belirle ve uygulama içinden güvenli canlı sohbete başla.', style: TextStyle(color: Colors.white70, height: 1.5))]));
  Widget _sectionTitle(String text) => Text(text, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900));

  Widget _myChats() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('chats').snapshots(),
      builder: (context, snapshot) {
        final docs = (snapshot.data?.docs ?? []).where((d) => (d.data()['userId'] ?? '') == user.uid).toList();
        docs.sort((a, b) => _timeValue(b.data()).compareTo(_timeValue(a.data())));
        final active = docs.where((d) => ['waiting','active','pending','created'].contains((d.data()['status'] ?? '').toString())).toList();
        if (active.isEmpty) return const SizedBox.shrink();
        return Container(padding: const EdgeInsets.all(16), decoration: _boxDecoration(), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Uzman Sohbetlerim', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)), const SizedBox(height: 10),
          ...active.take(3).map((doc) { final d=doc.data(); final status=(d['status']??'waiting').toString(); final expert=(d['expertName']??'Uzman').toString(); final service=(d['serviceTitle']??'Uzman Yorumu').toString(); return ListTile(contentPadding: EdgeInsets.zero, leading: CircleAvatar(backgroundColor: const Color(0xFF7C3AED).withOpacity(.25), child: Icon(status=='active'?Icons.chat_bubble_rounded:Icons.hourglass_top_rounded, color: Colors.white)), title: Text('$expert • $service', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)), subtitle: Text(status=='active'?'Aktif görüşme':'Bekleyen görüşme', style: const TextStyle(color: Colors.white60)), trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 16), onTap: ()=>Navigator.push(context, MaterialPageRoute(builder: (_) => ExpertChatPage(chatId: doc.id, serviceTitle: service, expertName: expert)))); }),
        ]));
      },
    );
  }
  int _timeValue(Map<String,dynamic> d){ final v=d['updatedAt']??d['lastMessageAt']??d['createdAt']; return v is Timestamp ? v.millisecondsSinceEpoch : 0; }
  Widget _emptyExperts() => Container(padding: const EdgeInsets.all(18), decoration: _boxDecoration(), child: const Text('Şu an online uzman görünmüyor. Uzman uygulamasından giriş yapınca burada listelenir.', style: TextStyle(color: Colors.white70, height: 1.45)));

  Widget _expertCard(_SelectedExpert expert) { final selected = _selectedExpert?.id == expert.id; final photo=expert.photoUrl.trim(); return GestureDetector(onTap: () => setState(() { _selectedExpert = expert; if (_selectedService != null && !_expertCanDo(expert, _selectedService!)) _selectedService = null; }), child: AnimatedContainer(duration: const Duration(milliseconds: 220), margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(2), decoration: BoxDecoration(borderRadius: BorderRadius.circular(26), gradient: selected ? const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFFDB2777), Color(0xFFFFD166)]) : null, color: selected ? null : Colors.white.withOpacity(0.08)), child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), color: const Color(0xFF120D20)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [CircleAvatar(radius: 28, backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null, backgroundColor: const Color(0xFF7C3AED).withOpacity(0.28), child: photo.isEmpty ? Text(expert.name.isEmpty?'?':expert.name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)) : null), const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(expert.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)), const SizedBox(height: 3), Text(expert.title, style: const TextStyle(color: Color(0xFFFFD166), fontWeight: FontWeight.w700, fontSize: 12.5)), const SizedBox(height: 3), Text(expert.online ? 'Online • Sohbete uygun' : 'Offline • Talep bırakılabilir', style: TextStyle(color: expert.online ? const Color(0xFF86EFAC) : Colors.white54, fontWeight: FontWeight.w700, fontSize: 12.5))])), Icon(selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: selected ? const Color(0xFFFFD166) : Colors.white38)]), if(expert.bio.isNotEmpty)...[const SizedBox(height:10), Text(expert.bio, maxLines:2, overflow:TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, height:1.35, fontSize:12.5))], const SizedBox(height:10), Wrap(spacing:6, runSpacing:6, children:[_chip('★ ${expert.rating.toStringAsFixed(1)}'), ...expert.specialties.take(4).map(_chip)] )])))); }
  Widget _chip(String t)=>Container(padding: const EdgeInsets.symmetric(horizontal:9, vertical:6), decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), color: Colors.white.withOpacity(.07)), child: Text(t, style: const TextStyle(color: Colors.white70, fontSize:11.5, fontWeight: FontWeight.w700)));

  Widget _serviceCard(_ExpertService service) { final selected = _selectedService?.keyName == service.keyName; return GestureDetector(onTap: () => setState(() => _selectedService = service), child: Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(2), decoration: BoxDecoration(borderRadius: BorderRadius.circular(26), gradient: LinearGradient(colors: service.colors)), child: Container(padding: const EdgeInsets.all(17), decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), color: const Color(0xFF120D20)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(width: 50, height: 50, decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: service.colors.first.withOpacity(0.18)), child: Icon(service.icon, color: Colors.white)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(service.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)), const SizedBox(height: 4), Text(service.subtitle, style: const TextStyle(color: Colors.white70, height: 1.35, fontSize: 13))])), Icon(selected ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded, color: selected ? const Color(0xFFFFD166) : Colors.white54)]), const SizedBox(height: 12), Text(service.description, style: const TextStyle(color: Colors.white70, height: 1.45, fontSize: 13.3)), const SizedBox(height: 10), Text('${service.premiumCoinPrice} Premium Coin', style: const TextStyle(color: Color(0xFFFFD166), fontSize: 16, fontWeight: FontWeight.w900))])))); }
  Widget _buyBar() { final expert = _selectedExpert; final service = _selectedService; return Container(padding: const EdgeInsets.all(16), decoration: _boxDecoration(), child: Column(children: [Text(expert == null || service == null ? 'Uzman ve hizmet seçerek devam et.' : '${expert.name} • ${service.title}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)), const SizedBox(height: 12), SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _isProcessing ? null : _startChat, icon: _isProcessing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.chat_bubble_rounded), label: Text(_isProcessing ? 'Bağlantı kuruluyor...' : 'Canlı Sohbeti Başlat'), style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)))))])); }
  BoxDecoration _boxDecoration() => BoxDecoration(borderRadius: BorderRadius.circular(24), color: Colors.white.withOpacity(0.08), border: Border.all(color: Colors.white.withOpacity(0.09)));
}

class _SelectedExpert { final String id,name,email,title,bio,photoUrl; final bool online,active; final double rating; final int reviewCount; final List<String> services,specialties; const _SelectedExpert({required this.id, required this.name, required this.email, required this.title, required this.bio, required this.photoUrl, required this.online, required this.active, required this.rating, required this.reviewCount, required this.services, required this.specialties}); }
class _ExpertService { final String keyName,title,shortTitle,subtitle,description; final int premiumCoinPrice,priceTl; final IconData icon; final List<Color> colors; final String suggestedPrompt; const _ExpertService({required this.keyName, required this.title, required this.shortTitle, required this.subtitle, required this.description, required this.premiumCoinPrice, required this.priceTl, required this.icon, required this.colors, required this.suggestedPrompt}); }
