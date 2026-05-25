import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import 'services/live_analytics_service.dart';
import 'package:image_picker/image_picker.dart';

import 'services/chat_notification_service.dart';

class ExpertChatPage extends StatefulWidget {
  final String chatId;
  final String serviceTitle;
  final String expertName;

  const ExpertChatPage({
    super.key,
    required this.chatId,
    required this.serviceTitle,
    required this.expertName,
  });

  @override
  State<ExpertChatPage> createState() => _ExpertChatPageState();
}

class _ExpertChatPageState extends State<ExpertChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();
  bool _isSending = false;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    LiveAnalyticsService.instance.trackScreen(screenName: 'Uzman Sohbeti', screenKey: 'expert_chat');
    ChatNotificationService.instance.init(role: 'user');
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    await _sendMessagePayload(type: 'text', text: text);
    _messageController.clear();
  }

  Future<void> _sendMessagePayload({
    required String type,
    String text = '',
    String imageUrl = '',
  }) async {
    final user = _auth.currentUser;
    if (user == null || _isSending) return;

    setState(() => _isSending = true);

    try {
      final chatRef = _firestore.collection('chats').doc(widget.chatId);
      final messageRef = chatRef.collection('messages').doc();
      final now = FieldValue.serverTimestamp();
      final preview = type == 'image' ? '📷 Fotoğraf gönderildi' : text;

      await _firestore.runTransaction((transaction) async {
        final chatSnap = await transaction.get(chatRef);
        if (!chatSnap.exists) throw Exception('Sohbet bulunamadı.');

        final chatData = chatSnap.data() ?? {};
        final status = (chatData['status'] ?? '').toString();
        if (status == 'completed' || status == 'cancelled') {
          throw Exception('Bu sohbet artık aktif değil.');
        }

        transaction.set(messageRef, {
          'messageId': messageRef.id,
          'chatId': widget.chatId,
          'senderId': user.uid,
          'senderRole': 'user',
          'senderName': user.displayName ?? user.email ?? 'Falix Kullanıcısı',
          'type': type,
          'text': text,
          'imageUrl': imageUrl,
          'seen': false,
          'createdAt': now,
        });

        transaction.set(chatRef, {
          'lastMessage': preview,
          'lastMessageSenderRole': 'user',
          'lastMessageAt': now,
          'updatedAt': now,
          'unreadForExpert': FieldValue.increment(1),
          'notifyExpert': true,
          'lastNotificationTitle': 'Yeni danışan mesajı 🔮',
          'lastNotificationBody': preview,
        }, SetOptions(merge: true));
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mesaj gönderilemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    final user = _auth.currentUser;
    if (user == null || _isUploadingImage) return;

    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1600,
      );
      if (picked == null) return;

      setState(() => _isUploadingImage = true);

      final file = File(picked.path);
      final ext = picked.path.split('.').last.toLowerCase();
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('chat_images')
          .child(widget.chatId)
          .child('${DateTime.now().millisecondsSinceEpoch}_${user.uid}.$ext');

      await storageRef.putFile(file);
      final imageUrl = await storageRef.getDownloadURL();

      await _sendMessagePayload(
        type: 'image',
        text: 'Kahve falı görseli',
        imageUrl: imageUrl,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fotoğraf gönderilemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _showImageSourceSheet() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF120D20),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_rounded, color: Color(0xFFFFD166)),
                  title: const Text('Kamera ile çek'),
                  subtitle: const Text('Kahve fincanını şimdi çek'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded, color: Color(0xFFFFD166)),
                  title: const Text('Galeriden seç'),
                  subtitle: const Text('Önceden çektiğin görseli gönder'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source != null) await _pickAndSendImage(source);
  }

  Widget _messageBubble(Map<String, dynamic> data) {
    final role = (data['senderRole'] ?? '').toString();
    final isUser = role == 'user';
    final type = (data['type'] ?? 'text').toString();
    final text = (data['text'] ?? '').toString();
    final imageUrl = (data['imageUrl'] ?? '').toString();

    final bubbleChild = type == 'image' && imageUrl.isNotEmpty
        ? GestureDetector(
            onTap: () => _openImage(imageUrl),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                imageUrl,
                width: 230,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const SizedBox(
                    width: 230,
                    height: 160,
                    child: Center(child: CircularProgressIndicator()),
                  );
                },
              ),
            ),
          )
        : Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14.5,
              height: 1.42,
              fontWeight: FontWeight.w500,
            ),
          );

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 310),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          gradient: isUser
              ? const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFFDB2777)])
              : null,
          color: isUser ? null : Colors.white.withOpacity(0.08),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: bubbleChild,
      ),
    );
  }

  void _openImage(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black),
          body: Center(child: InteractiveViewer(child: Image.network(url))),
        ),
      ),
    );
  }

  Widget _statusCard(Map<String, dynamic>? chatData) {
    final status = (chatData?['status'] ?? 'waiting').toString();
    String title = 'Uzman bekleniyor';
    String subtitle = 'Talebin uzman ekranına düştü. Uzmanın cevap verdiğinde burada görünecek.';
    IconData icon = Icons.hourglass_top_rounded;
    Color accent = const Color(0xFFFFD166);

    if (status == 'active') {
      title = 'Sohbet aktif';
      subtitle = '${widget.expertName} seninle görüşmede.';
      icon = Icons.chat_bubble_rounded;
      accent = const Color(0xFF22C55E);
    } else if (status == 'completed') {
      title = 'Sohbet tamamlandı';
      subtitle = 'Bu uzman görüşmesi tamamlandı. Yeni bir hizmet için tekrar talep oluşturabilirsin.';
      icon = Icons.check_circle_rounded;
      accent = const Color(0xFF60A5FA);
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withOpacity(0.07),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: accent.withOpacity(0.16),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15.5)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.white70, height: 1.35, fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatRef = _firestore.collection('chats').doc(widget.chatId);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF090613), Color(0xFF140A26), Color(0xFF25103F)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.serviceTitle, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              Text(widget.expertName, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: chatRef.snapshots(),
          builder: (context, chatSnapshot) {
            final chatData = chatSnapshot.data?.data();
            final status = (chatData?['status'] ?? 'waiting').toString();
            final canSend = status != 'completed' && status != 'cancelled';

            return Column(
              children: [
                _statusCard(chatData),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: chatRef.collection('messages').orderBy('createdAt', descending: false).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Sohbet başlatıldı. İlk mesajını yazabilir, kahve görselini gönderebilir veya uzmanın dönüşünü bekleyebilirsin.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white70, height: 1.45),
                            ),
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                        itemCount: docs.length,
                        itemBuilder: (context, index) => _messageBubble(docs[index].data()),
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF120D20).withOpacity(0.96),
                      border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: canSend && !_isUploadingImage ? _showImageSourceSheet : null,
                          icon: _isUploadingImage
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.add_photo_alternate_rounded, color: Color(0xFFFFD166)),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            enabled: canSend,
                            minLines: 1,
                            maxLines: 4,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: canSend ? 'Mesajını yaz...' : 'Bu sohbet tamamlandı',
                              hintStyle: const TextStyle(color: Colors.white38),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.07),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: canSend ? const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFFDB2777)]) : null,
                            color: canSend ? null : Colors.white12,
                          ),
                          child: IconButton(
                            onPressed: canSend && !_isSending ? _sendMessage : null,
                            icon: _isSending
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.send_rounded, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
