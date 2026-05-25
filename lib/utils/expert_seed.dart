import 'package:cloud_firestore/cloud_firestore.dart';

class ExpertSeed {
  static Future<void> seedExperts() async {
    final experts = FirebaseFirestore.instance.collection('experts');

    final snapshot = await experts.get();
    if (snapshot.docs.isNotEmpty) return; // zaten varsa tekrar ekleme

    await experts.doc('expert_1').set({
      "name": "Oguzhan",
      "isActive": true,
      "whatsapp": "905534236441",
      "priority": 1,
      "services": [
        "real_coffee",
        "real_tarot",
        "relationship",
        "destiny",
        "material_spiritual",
        "nlp_guidance"
      ]
    });

    await experts.doc('expert_2').set({
      "name": "Ayse",
      "isActive": true,
      "whatsapp": "905321112233",
      "priority": 2,
      "services": [
        "relationship",
        "destiny",
        "nlp_guidance"
      ]
    });

    await experts.doc('expert_3').set({
      "name": "Elif",
      "isActive": false,
      "whatsapp": "905554445566",
      "priority": 3,
      "services": [
        "material_spiritual",
        "relationship",
        "real_tarot"
      ]
    });
  }
}