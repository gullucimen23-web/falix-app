import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DailyRewardStatus {
  final bool canClaim;
  final int streak;
  final int todayReward;
  final String lastClaimDate;

  const DailyRewardStatus({
    required this.canClaim,
    required this.streak,
    required this.todayReward,
    required this.lastClaimDate,
  });
}

class DailyRewardResult {
  final bool success;
  final bool alreadyClaimedToday;
  final int reward;
  final int streak;
  final String message;

  const DailyRewardResult({
    required this.success,
    required this.alreadyClaimedToday,
    required this.reward,
    required this.streak,
    required this.message,
  });
}

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const List<int> _dailyRewards = [10, 12, 14, 18, 22, 26, 30];
  static const int _dailyAiLimit = 5;

  Future<Map<String, dynamic>> getUserProfileData() async {
  final user = _auth.currentUser;
  if (user == null) return {};

  final doc = await _firestore.collection('users').doc(user.uid).get();
  return doc.data() ?? {};
}

Future<void> saveUserProfileData({
  required String name,
  required String motherName,
  required int? birthYear,
  required int? motherBirthYear,
  required String relationshipStatus,
  String partnerName = '',
  String partnerMotherName = '',
  String partnerBirthDate = '',
}) async {
  final user = _auth.currentUser;
  if (user == null) return;

  final docRef = _firestore.collection('users').doc(user.uid);

  await docRef.set({
    'name': name,
    'motherName': motherName,
    'birthYear': birthYear,
    'motherBirthYear': motherBirthYear,
    'relationshipStatus': relationshipStatus,
    'partnerName': partnerName,
    'partnerMotherName': partnerMotherName,
    'partnerBirthDate': partnerBirthDate,
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}
  
  Future<void> createUserIfNotExists() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final docRef = _firestore.collection('users').doc(user.uid);
    final doc = await docRef.get();

    if (!doc.exists) {
      await docRef.set({
        'email': user.email,
        'coin': 100,
        'premiumCoin': 0,
        'premium': false,
        'streak': 0,
        'lastDailyClaimDate': '',
        'dailyUsage': 0,
        'lastUsageDate': '',
        'freeTarotCount': 0,
        'freeCoffeeCount': 0,
        'expertMessageCount': 0,
        'adFreeCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    final data = doc.data() ?? {};
    final Map<String, dynamic> updates = {};

    if (!data.containsKey('coin')) updates['coin'] = 100;
    if (!data.containsKey('premiumCoin')) updates['premiumCoin'] = 0;
    if (!data.containsKey('premium')) updates['premium'] = false;
    if (!data.containsKey('streak')) updates['streak'] = 0;
    if (!data.containsKey('lastDailyClaimDate')) {
      updates['lastDailyClaimDate'] = '';
    }
    if (!data.containsKey('dailyUsage')) updates['dailyUsage'] = 0;
    if (!data.containsKey('lastUsageDate')) updates['lastUsageDate'] = '';
    if (!data.containsKey('freeTarotCount')) updates['freeTarotCount'] = 0;
    if (!data.containsKey('freeCoffeeCount')) updates['freeCoffeeCount'] = 0;
    if (!data.containsKey('expertMessageCount')) updates['expertMessageCount'] = 0;
    if (!data.containsKey('adFreeCount')) updates['adFreeCount'] = 0;
    if (!data.containsKey('email')) updates['email'] = user.email;

    if (updates.isNotEmpty) {
      await docRef.update(updates);
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> userStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();
    return _firestore.collection('users').doc(user.uid).snapshots();
  }

  Future<int> getCurrentCoin() async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return 0;

    return (doc.data()?['coin'] ?? 0) as int;
  }

  Future<int> getCurrentPremiumCoin() async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return 0;

    return (doc.data()?['premiumCoin'] ?? 0) as int;
  }

  Future<bool> isPremium() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return false;

    return (doc.data()?['premium'] ?? false) as bool;
  }

  @Deprecated('AI coin harcamasını backend yapmalı. Bu methodu çağırma.')
  Future<bool> spendCoin(int amount) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final docRef = _firestore.collection('users').doc(user.uid);
    final coinHistoryRef = docRef.collection('coin_history').doc();

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return false;

      final currentCoin = (snapshot.data()?['coin'] ?? 0) as int;
      if (currentCoin < amount) return false;

      final newCoin = currentCoin - amount;

      transaction.update(docRef, {'coin': newCoin});
      transaction.set(coinHistoryRef, {
        'type': 'spend',
        'amount': -amount,
        'balanceAfter': newCoin,
        'createdAt': FieldValue.serverTimestamp(),
        'meta': {
          'reason': 'legacy_client_spend',
        },
      });

      return true;
    });
  }

  Future<void> addCoin(
    int amount, {
    String historyType = 'rewarded_ad',
    Map<String, dynamic>? meta,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final docRef = _firestore.collection('users').doc(user.uid);
    final historyRef = docRef.collection('coin_history').doc();

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final currentCoin = (snapshot.data()?['coin'] ?? 0) as int;
      final newCoin = currentCoin + amount;

      transaction.update(docRef, {'coin': newCoin});
      transaction.set(historyRef, {
        'type': historyType,
        'amount': amount,
        'balanceAfter': newCoin,
        'createdAt': FieldValue.serverTimestamp(),
        'meta': meta ?? {},
      });
    });
  }

  Future<void> addPremiumCoin(
    int amount, {
    String historyType = 'premium_coin_pack_test',
    Map<String, dynamic>? meta,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final docRef = _firestore.collection('users').doc(user.uid);
    final historyRef = docRef.collection('premium_coin_history').doc();

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final currentPremiumCoin = (snapshot.data()?['premiumCoin'] ?? 0) as int;
      final newPremiumCoin = currentPremiumCoin + amount;

      transaction.update(docRef, {'premiumCoin': newPremiumCoin});
      transaction.set(historyRef, {
        'type': historyType,
        'amount': amount,
        'balanceAfter': newPremiumCoin,
        'createdAt': FieldValue.serverTimestamp(),
        'meta': meta ?? {},
      });
    });
  }

  Future<void> saveReading({
    required String type,
    required String result,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('readings')
        .add({
      'type': type,
      'result': result,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> saveStructuredReading({
    required String type,
    required Map<String, dynamic> result,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('readings')
        .add({
      'type': type,
      'result': result,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> readingsStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('readings')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  DateTime _nowTr() => DateTime.now().toUtc().add(const Duration(hours: 3));

  String _formatDateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _todayKey() => _formatDateKey(_nowTr());
  String _yesterdayKey() =>
      _formatDateKey(_nowTr().subtract(const Duration(days: 1)));

  int _rewardForStreak(int streak) {
    final index = (streak - 1) % _dailyRewards.length;
    return _dailyRewards[index];
  }

  Future<DailyRewardStatus> getDailyRewardStatus() async {
    final user = _auth.currentUser;
    if (user == null) {
      return const DailyRewardStatus(
        canClaim: false,
        streak: 0,
        todayReward: 10,
        lastClaimDate: '',
      );
    }

    final doc = await _firestore.collection('users').doc(user.uid).get();
    final data = doc.data() ?? {};

    final lastClaimDate = (data['lastDailyClaimDate'] ?? '').toString();
    final storedStreak = (data['streak'] ?? 0) as int;
    final todayKey = _todayKey();
    final yesterdayKey = _yesterdayKey();

    int effectiveStreak = storedStreak;
    if (lastClaimDate.isEmpty) {
      effectiveStreak = 0;
    } else if (lastClaimDate == todayKey || lastClaimDate == yesterdayKey) {
      effectiveStreak = storedStreak;
    } else {
      effectiveStreak = 0;
    }

    return DailyRewardStatus(
      canClaim: lastClaimDate != todayKey,
      streak: effectiveStreak,
      todayReward: _rewardForStreak(effectiveStreak + 1),
      lastClaimDate: lastClaimDate,
    );
  }

  Future<DailyRewardResult> claimDailyReward() async {
    final user = _auth.currentUser;
    if (user == null) {
      return const DailyRewardResult(
        success: false,
        alreadyClaimedToday: false,
        reward: 0,
        streak: 0,
        message: 'Kullanıcı bulunamadı.',
      );
    }

    final docRef = _firestore.collection('users').doc(user.uid);
    final coinHistoryRef = docRef.collection('coin_history').doc();

    try {
      return await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);

        if (!snapshot.exists) {
          return const DailyRewardResult(
            success: false,
            alreadyClaimedToday: false,
            reward: 0,
            streak: 0,
            message: 'Kullanıcı verisi bulunamadı.',
          );
        }

        final data = snapshot.data() ?? {};
        final currentCoin = (data['coin'] ?? 0) as int;
        final currentStreak = (data['streak'] ?? 0) as int;
        final lastClaimDate = (data['lastDailyClaimDate'] ?? '').toString();

        final todayKey = _todayKey();
        final yesterdayKey = _yesterdayKey();

        if (lastClaimDate == todayKey) {
          return DailyRewardResult(
            success: false,
            alreadyClaimedToday: true,
            reward: 0,
            streak: currentStreak,
            message: 'Bugünkü günlük ödül zaten alındı.',
          );
        }

        int newStreak = 1;
        if (lastClaimDate == yesterdayKey) {
          newStreak = currentStreak + 1;
        }

        final reward = _rewardForStreak(newStreak);
        final newCoin = currentCoin + reward;

        transaction.update(docRef, {
          'coin': newCoin,
          'streak': newStreak,
          'lastDailyClaimDate': todayKey,
        });

        transaction.set(coinHistoryRef, {
          'type': 'daily_reward',
          'amount': reward,
          'balanceAfter': newCoin,
          'createdAt': FieldValue.serverTimestamp(),
          'meta': {
            'streak': newStreak,
            'claimDate': todayKey,
          },
        });

        return DailyRewardResult(
          success: true,
          alreadyClaimedToday: false,
          reward: reward,
          streak: newStreak,
          message: '+$reward coin günlük ödül alındı.',
        );
      });
    } catch (e) {
      return DailyRewardResult(
        success: false,
        alreadyClaimedToday: false,
        reward: 0,
        streak: 0,
        message: 'Günlük ödül alınamadı: $e',
      );
    }
  }

  @Deprecated('AI limit kontrolünü backend yapmalı. Güvenlik için buna güvenme.')
  Future<bool> canUseAI() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final docRef = _firestore.collection('users').doc(user.uid);
    final doc = await docRef.get();
    if (!doc.exists) return false;

    final data = doc.data() ?? {};
    final today = _todayKey();
    final lastUsageDate = (data['lastUsageDate'] ?? '').toString();
    final isPremiumUser = (data['premium'] ?? false) as bool;

    if (isPremiumUser) return true;

    if (lastUsageDate != today) {
      await docRef.update({
        'dailyUsage': 0,
        'lastUsageDate': today,
      });
      return true;
    }

    final dailyUsage = (data['dailyUsage'] ?? 0) as int;
    return dailyUsage < _dailyAiLimit;
  }

  @Deprecated('AI kullanım artışını backend yapmalı. Bu methodu çağırma.')
  Future<void> incrementDailyUsage() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final docRef = _firestore.collection('users').doc(user.uid);
    final today = _todayKey();

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final data = snapshot.data() ?? {};
      final lastUsageDate = (data['lastUsageDate'] ?? '').toString();
      final isPremiumUser = (data['premium'] ?? false) as bool;

      if (isPremiumUser) return;

      if (lastUsageDate != today) {
        transaction.update(docRef, {
          'dailyUsage': 1,
          'lastUsageDate': today,
        });
      } else {
        transaction.update(docRef, {
          'dailyUsage': FieldValue.increment(1),
        });
      }
    });
  }

  Future<String> createHumanExpertOrder({
    required String serviceKey,
    required String serviceTitle,
    required int premiumCoinCost,
    required int priceTl,
    required String whatsappLabel,
    String? note,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Oturum bulunamadı');
    }

    final userRef = _firestore.collection('users').doc(user.uid);
    final userOrderRef = userRef.collection('human_orders').doc();
    final orderRef = _firestore.collection('human_orders').doc(userOrderRef.id);
    final historyRef = userRef.collection('premium_coin_history').doc();

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      if (!snapshot.exists) {
        throw Exception('Kullanıcı kaydı bulunamadı');
      }

      final data = snapshot.data() ?? {};
      final currentPremiumCoin = (data['premiumCoin'] ?? 0) as int;

      if (currentPremiumCoin < premiumCoinCost) {
        throw Exception('Bu hizmet için yeterli Premium Coin yok');
      }

      final newPremiumCoin = currentPremiumCoin - premiumCoinCost;
      final userName = (user.displayName ?? '').trim().isNotEmpty
          ? user.displayName!.trim()
          : (data['email'] ?? user.email ?? 'Falix Kullanıcısı').toString();

      final orderData = {
        'orderId': userOrderRef.id,
        'userId': user.uid,
        'userEmail': user.email,
        'userName': userName,
        'serviceKey': serviceKey,
        'serviceTitle': serviceTitle,
        'whatsappLabel': whatsappLabel,
        'premiumCoinCost': premiumCoinCost,
        'priceTl': priceTl,
        'note': (note ?? '').trim(),
        'status': 'pending_whatsapp',
        'channel': 'whatsapp',
        'createdAt': FieldValue.serverTimestamp(),
      };

      transaction.update(userRef, {
        'premiumCoin': newPremiumCoin,
      });

      transaction.set(orderRef, orderData);
      transaction.set(userOrderRef, orderData);
      transaction.set(historyRef, {
        'type': 'human_expert_order',
        'amount': -premiumCoinCost,
        'balanceAfter': newPremiumCoin,
        'createdAt': FieldValue.serverTimestamp(),
        'meta': {
          'serviceKey': serviceKey,
          'serviceTitle': serviceTitle,
          'orderId': userOrderRef.id,
          'priceTl': priceTl,
          'channel': 'whatsapp',
        },
      });
    });

    return userOrderRef.id;
  }

  Future<void> consumeFreeTarotCount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final ref = _firestore.collection('users').doc(user.uid);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) return;

      final data = snapshot.data() ?? {};
      final current = (data['freeTarotCount'] ?? 0) as int;
      if (current <= 0) return;

      transaction.set(
        ref,
        {
          'freeTarotCount': current - 1,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> consumeFreeCoffeeCount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final ref = _firestore.collection('users').doc(user.uid);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) return;

      final data = snapshot.data() ?? {};
      final current = (data['freeCoffeeCount'] ?? 0) as int;
      if (current <= 0) return;

      transaction.set(
        ref,
        {
          'freeCoffeeCount': current - 1,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> consumeAdFreeCount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final ref = _firestore.collection('users').doc(user.uid);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) return;

      final data = snapshot.data() ?? {};
      final current = (data['adFreeCount'] ?? 0) as int;
      if (current <= 0) return;

      transaction.set(
        ref,
        {
          'adFreeCount': current - 1,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<Map<String, dynamic>> getSpinStatus() async {
    final user = _auth.currentUser;
    if (user == null) return {};

    final doc = await _firestore.collection('users').doc(user.uid).get();
    final data = doc.data() ?? {};

    final today = _todayKey();
    final lastSpinDate = (data['lastSpinDate'] ?? '').toString();
    final premium = data['premium'] == true;

    int spinCountToday = (data['spinCountToday'] ?? 0) as int;
    if (lastSpinDate != today) {
      spinCountToday = 0;
    }

    final freeLimit = premium ? 5 : 2;

    return {
      'coin': data['coin'] ?? 0,
      'premiumCoin': data['premiumCoin'] ?? 0,
      'premium': premium,
      'spinCountToday': spinCountToday,
      'freeLimit': freeLimit,
      'remainingFreeSpins': (freeLimit - spinCountToday).clamp(0, freeLimit),
      'freeTarotCount': data['freeTarotCount'] ?? 0,
      'freeCoffeeCount': data['freeCoffeeCount'] ?? 0,
      'expertMessageCount': data['expertMessageCount'] ?? 0,
      'adFreeCount': data['adFreeCount'] ?? 0,
    };
  }

  Future<Map<String, dynamic>> useSpinChance() async {
    final user = _auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum bulunamadı'};
    }

    final ref = _firestore.collection('users').doc(user.uid);
    final today = _todayKey();

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) {
        return {'success': false, 'message': 'Kullanıcı verisi bulunamadı'};
      }

      final data = snapshot.data() ?? {};
      final premium = data['premium'] == true;
      final freeLimit = premium ? 5 : 2;

      int spinCountToday = (data['spinCountToday'] ?? 0) as int;
      final lastSpinDate = (data['lastSpinDate'] ?? '').toString();
      int coin = (data['coin'] ?? 0) as int;

      if (lastSpinDate != today) {
        spinCountToday = 0;
      }

      if (spinCountToday < freeLimit) {
        transaction.set(
          ref,
          {
            'spinCountToday': spinCountToday + 1,
            'lastSpinDate': today,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        return {
          'success': true,
          'usedCoin': false,
          'remainingFreeSpins': freeLimit - (spinCountToday + 1),
        };
      }

      if (coin < 30) {
        return {
          'success': false,
          'message': 'Çarkı çevirmek için 30 coin gerekli',
        };
      }

      coin -= 30;

      transaction.set(
        ref,
        {
          'coin': coin,
          'spinCountToday': spinCountToday,
          'lastSpinDate': today,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      final historyRef = ref.collection('coin_history').doc();
      transaction.set(historyRef, {
        'type': 'spin_cost',
        'amount': -30,
        'balanceAfter': coin,
        'createdAt': FieldValue.serverTimestamp(),
        'meta': {'reason': 'spin_wheel_paid_spin'},
      });

      return {
        'success': true,
        'usedCoin': true,
        'coin': coin,
        'remainingFreeSpins': 0,
      };
    });
  }

  Future<void> applySpinReward({
    required String rewardType,
    required int rewardValue,
    required String rewardLabel,
    required bool usedCoinSpin,
    required int spinCost,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final ref = _firestore.collection('users').doc(user.uid);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) return;

      final data = snapshot.data() ?? {};

      int coin = (data['coin'] ?? 0) as int;
      int premiumCoin = (data['premiumCoin'] ?? 0) as int;
      int freeTarotCount = (data['freeTarotCount'] ?? 0) as int;
      int freeCoffeeCount = (data['freeCoffeeCount'] ?? 0) as int;
      int expertMessageCount = (data['expertMessageCount'] ?? 0) as int;
      int adFreeCount = (data['adFreeCount'] ?? 0) as int;

      switch (rewardType) {
        case 'coin':
          coin += rewardValue;
          break;
        case 'premiumCoin':
          premiumCoin += rewardValue;
          break;
        case 'freeTarot':
          freeTarotCount += rewardValue;
          break;
        case 'freeCoffee':
          freeCoffeeCount += rewardValue;
          break;
        case 'expertMessage':
          expertMessageCount += rewardValue;
          break;
        case 'adFree':
          adFreeCount += rewardValue;
          break;
        case 'miss':
          break;
      }

      transaction.set(
        ref,
        {
          'coin': coin,
          'premiumCoin': premiumCoin,
          'freeTarotCount': freeTarotCount,
          'freeCoffeeCount': freeCoffeeCount,
          'expertMessageCount': expertMessageCount,
          'adFreeCount': adFreeCount,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      final spinHistoryRef = ref.collection('spin_history').doc();
      transaction.set(spinHistoryRef, {
        'rewardType': rewardType,
        'rewardValue': rewardValue,
        'rewardLabel': rewardLabel,
        'usedCoinSpin': usedCoinSpin,
        'spinCost': spinCost,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (rewardType == 'coin' && rewardValue > 0) {
        final coinHistoryRef = ref.collection('coin_history').doc();
        transaction.set(coinHistoryRef, {
          'type': 'spin_reward',
          'amount': rewardValue,
          'balanceAfter': coin,
          'createdAt': FieldValue.serverTimestamp(),
          'meta': {
            'rewardType': rewardType,
            'rewardLabel': rewardLabel,
            'usedCoinSpin': usedCoinSpin,
          },
        });
      }

      if (rewardType == 'premiumCoin' && rewardValue > 0) {
        final premiumHistoryRef = ref.collection('premium_coin_history').doc();
        transaction.set(premiumHistoryRef, {
          'type': 'spin_reward',
          'amount': rewardValue,
          'balanceAfter': premiumCoin,
          'createdAt': FieldValue.serverTimestamp(),
          'meta': {
            'rewardType': rewardType,
            'rewardLabel': rewardLabel,
            'usedCoinSpin': usedCoinSpin,
          },
        });
      }
    });
  }

}
