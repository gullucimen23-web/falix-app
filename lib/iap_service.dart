import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class IAPService {
  IAPService._();

  static final IAPService instance = IAPService._();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  static const String premiumCoin250 = 'premium_coin_250';
  static const String premiumCoin2000 = 'premium_coin_2000';
  static const String premiumCoin5000 = 'premium_coin_5000';

  static const String premiumMonthly = 'falix_premium_monthly';
  static const String premiumYearly = 'falix_premium_yearly';

  final Set<String> productIds = const {
    premiumCoin250,
    premiumCoin2000,
    premiumCoin5000,
    premiumMonthly,
    premiumYearly,
  };

  Future<bool> isAvailable() async {
    return _iap.isAvailable();
  }

  Future<List<ProductDetails>> loadProducts() async {
    final available = await _iap.isAvailable();
    if (!available) return [];

    final response = await _iap.queryProductDetails(productIds);

    if (response.error != null) {
      throw Exception(response.error!.message);
    }

    final products = response.productDetails.toList();

    products.sort((a, b) {
      final aPriority = _sortPriority(a.id);
      final bPriority = _sortPriority(b.id);

      if (aPriority != bPriority) return aPriority.compareTo(bPriority);
      return a.rawPrice.compareTo(b.rawPrice);
    });

    return products;
  }

  void listenPurchases({
    required String uid,
    void Function(String message)? onError,
    void Function(String productId)? onSuccess,
  }) {
    _purchaseSub?.cancel();

    _purchaseSub = _iap.purchaseStream.listen(
      (purchases) async {
        for (final purchase in purchases) {
          try {
            await _handlePurchase(
              purchase: purchase,
              uid: uid,
              onSuccess: onSuccess,
            );
          } catch (e) {
            onError?.call(e.toString());
          }
        }
      },
      onError: (e) {
        onError?.call(e.toString());
      },
      cancelOnError: false,
    );
  }

  Future<void> buy(ProductDetails product) async {
    final purchaseParam = PurchaseParam(productDetails: product);
    await _iap.buyConsumable(
      purchaseParam: purchaseParam,
      autoConsume: true,
    );
  }

  Future<void> buySubscription(ProductDetails product) async {
    final purchaseParam = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(
      purchaseParam: purchaseParam,
    );
  }

  Future<void> _handlePurchase({
    required PurchaseDetails purchase,
    required String uid,
    void Function(String productId)? onSuccess,
  }) async {
    if (purchase.status == PurchaseStatus.pending) {
      return;
    }

    if (purchase.status == PurchaseStatus.error) {
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
      throw Exception(purchase.error?.message ?? 'Satın alma hatası');
    }

    if (purchase.status == PurchaseStatus.canceled) {
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
      return;
    }

    if (purchase.status != PurchaseStatus.purchased &&
        purchase.status != PurchaseStatus.restored) {
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
      return;
    }

    if (purchase.productID == premiumMonthly ||
        purchase.productID == premiumYearly) {
      await _activatePremium(uid: uid, purchase: purchase);

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }

      onSuccess?.call(purchase.productID);
      return;
    }

    final premiumCoinAmount = _premiumCoinAmountForProduct(purchase.productID);

    if (premiumCoinAmount <= 0) {
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
      throw Exception('Bilinmeyen ürün: ${purchase.productID}');
    }

    await _grantPremiumCoins(
      uid: uid,
      purchase: purchase,
      premiumCoinAmount: premiumCoinAmount,
    );

    if (purchase.pendingCompletePurchase) {
      await _iap.completePurchase(purchase);
    }

    onSuccess?.call(purchase.productID);
  }

  Future<void> _activatePremium({
    required String uid,
    required PurchaseDetails purchase,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(uid);

    await userRef.set({
      'premium': true,
      'premiumSince': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final premiumHistoryRef = userRef.collection('premium_history').doc();

    await premiumHistoryRef.set({
      'type': 'premium_subscription_purchase',
      'productId': purchase.productID,
      'purchaseId': purchase.purchaseID,
      'transactionDate': purchase.transactionDate,
      'status': purchase.status.name,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _grantPremiumCoins({
    required String uid,
    required PurchaseDetails purchase,
    required int premiumCoinAmount,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(uid);

    final purchaseKey = purchase.purchaseID ??
        '${purchase.productID}_${purchase.transactionDate ?? DateTime.now().millisecondsSinceEpoch}';

    final purchaseRef = userRef.collection('iap_purchases').doc(purchaseKey);
    final historyRef = userRef.collection('premium_coin_history').doc();

    await firestore.runTransaction((tx) async {
      final purchaseSnap = await tx.get(purchaseRef);
      if (purchaseSnap.exists) return;

      final userSnap = await tx.get(userRef);

      final Map<String, dynamic> existingData =
          userSnap.data() as Map<String, dynamic>? ?? {};

      final currentPremiumCoin = _asInt(existingData['premiumCoin']);
      final currentCoin = _asInt(existingData['coin']);
      final currentDailyUsage = _asInt(existingData['dailyUsage']);
      final currentPremium = (existingData['premium'] ?? false) == true;

      final newPremiumCoin = currentPremiumCoin + premiumCoinAmount;

      if (!userSnap.exists) {
        tx.set(userRef, {
          'coin': currentCoin,
          'premiumCoin': newPremiumCoin,
          'premium': currentPremium,
          'dailyUsage': currentDailyUsage,
          'lastUsageDate': existingData['lastUsageDate'],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        tx.set(userRef, {
          'premiumCoin': newPremiumCoin,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      tx.set(historyRef, {
        'type': 'premium_coin_purchase',
        'amount': premiumCoinAmount,
        'balanceAfter': newPremiumCoin,
        'createdAt': FieldValue.serverTimestamp(),
        'meta': {
          'productId': purchase.productID,
          'purchaseId': purchase.purchaseID,
          'transactionDate': purchase.transactionDate,
          'status': purchase.status.name,
        },
      });

      tx.set(purchaseRef, {
        'productId': purchase.productID,
        'purchaseId': purchase.purchaseID,
        'transactionDate': purchase.transactionDate,
        'status': purchase.status.name,
        'premiumCoinGranted': premiumCoinAmount,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  int premiumCoinAmountOf(String productId) {
    return _premiumCoinAmountForProduct(productId);
  }

  int _premiumCoinAmountForProduct(String productId) {
    switch (productId) {
      case premiumCoin250:
        return 250;
      case premiumCoin2000:
        return 2000;
      case premiumCoin5000:
        return 5000;
      default:
        return 0;
    }
  }

  int _sortPriority(String productId) {
    switch (productId) {
      case premiumMonthly:
        return 0;
      case premiumYearly:
        return 1;
      case premiumCoin250:
        return 2;
      case premiumCoin2000:
        return 3;
      case premiumCoin5000:
        return 4;
      default:
        return 99;
    }
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  Future<void> dispose() async {
    await _purchaseSub?.cancel();
    _purchaseSub = null;
  }
}