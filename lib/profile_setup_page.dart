import 'package:flutter/material.dart';

import 'services/live_analytics_service.dart';
import 'services/user_service.dart';

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _userService = UserService();

  final _nameController = TextEditingController();
  final _motherNameController = TextEditingController();
  final _birthYearController = TextEditingController();
  final _motherBirthYearController = TextEditingController();
  final _partnerNameController = TextEditingController();
  final _partnerMotherNameController = TextEditingController();
  final _partnerBirthDateController = TextEditingController();

  String _relationshipStatus = 'belirsiz';
  bool _isLoading = true;
  bool _isSaving = false;

  final List<DropdownMenuItem<String>> _relationshipItems = const [
    DropdownMenuItem(value: 'belirsiz', child: Text('Belirsiz')),
    DropdownMenuItem(value: 'bekar', child: Text('Bekar')),
    DropdownMenuItem(value: 'ilişkide', child: Text('İlişkide')),
    DropdownMenuItem(value: 'karışık', child: Text('Karışık')),
    DropdownMenuItem(value: 'evli', child: Text('Evli')),
  ];

  @override
  void initState() {
    super.initState();
    LiveAnalyticsService.instance.trackScreen(screenName: 'Profil Ayarları', screenKey: 'profile');
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _motherNameController.dispose();
    _birthYearController.dispose();
    _motherBirthYearController.dispose();
    _partnerNameController.dispose();
    _partnerMotherNameController.dispose();
    _partnerBirthDateController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await _userService.getUserProfileData();

    if (!mounted) return;

    _nameController.text = (profile['name'] ?? '').toString();
    _motherNameController.text = (profile['motherName'] ?? '').toString();
    _partnerNameController.text = (profile['partnerName'] ?? '').toString();
    _partnerMotherNameController.text =
        (profile['partnerMotherName'] ?? '').toString();
    _partnerBirthDateController.text =
        (profile['partnerBirthDate'] ?? '').toString();

    final birthYear = profile['birthYear'];
    final motherBirthYear = profile['motherBirthYear'];

    if (birthYear != null) {
      _birthYearController.text = birthYear.toString();
    }

    if (motherBirthYear != null) {
      _motherBirthYearController.text = motherBirthYear.toString();
    }

    final relationshipStatus = (profile['relationshipStatus'] ?? 'belirsiz').toString();
    _relationshipStatus = relationshipStatus.isEmpty ? 'belirsiz' : relationshipStatus;

    setState(() {
      _isLoading = false;
    });
  }

  String? _validateYear(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;

    final year = int.tryParse(text);
    if (year == null) return 'Geçerli bir yıl gir';
    if (year < 1930 || year > DateTime.now().year) return 'Yıl aralığı geçersiz';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    await _userService.saveUserProfileData(
      name: _nameController.text.trim(),
      motherName: _motherNameController.text.trim(),
      birthYear: _birthYearController.text.trim().isEmpty
          ? null
          : int.tryParse(_birthYearController.text.trim()),
      motherBirthYear: _motherBirthYearController.text.trim().isEmpty
          ? null
          : int.tryParse(_motherBirthYearController.text.trim()),
      relationshipStatus: _relationshipStatus,
      partnerName: _partnerNameController.text.trim(),
      partnerMotherName: _partnerMotherNameController.text.trim(),
      partnerBirthDate: _partnerBirthDateController.text.trim(),
    );

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profil tamamlandı. Falix yorumların artık daha kişisel hazırlanacak ✨'),
      ),
    );

    // Navigator.pop(context);
  }

  Widget _fieldCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.08),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: child,
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Icon(icon, color: Colors.white70),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFA98BFF)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      filled: true,
      fillColor: Colors.white.withOpacity(0.04),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090613),
      appBar: AppBar(
        title: const Text('Enerji Profilin'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF4C1D95),
                          Color(0xFF7C3AED),
                          Color(0xFFDB2777),
                        ],
                      ),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Falix Seni Daha İyi Tanısın',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Ne kadar çok bilgi verirsen Falix aşk, ilişki ve kader yorumlarını o kadar kişisel ve etkileyici hazırlar.',
                          style: TextStyle(
                            color: Colors.white70,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _fieldCard(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: _inputDecoration('Adın', Icons.person_rounded),
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _motherNameController,
                            decoration: _inputDecoration('Anne adı', Icons.favorite_rounded),
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _birthYearController,
                            keyboardType: TextInputType.number,
                            validator: _validateYear,
                            decoration: _inputDecoration('Doğum yılı', Icons.cake_rounded),
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _motherBirthYearController,
                            keyboardType: TextInputType.number,
                            validator: _validateYear,
                            decoration: _inputDecoration('Annenin doğum yılı', Icons.groups_rounded),
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _relationshipStatus,
                            dropdownColor: const Color(0xFF1B1228),
                            items: _relationshipItems,
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _relationshipStatus = value;
                              });
                            },
                            decoration: _inputDecoration(
                              'İlişki durumu',
                              Icons.favorite_border_rounded,
                            ),
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 18),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'İlişki Yaşadığın Kişi',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.86),
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _partnerNameController,
                            decoration: _inputDecoration(
                              'İlişki yaşadığın kişinin adı',
                              Icons.favorite_rounded,
                            ),
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _partnerMotherNameController,
                            decoration: _inputDecoration(
                              'İlişki yaşadığın kişinin anne adı',
                              Icons.person_rounded,
                            ),
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _partnerBirthDateController,
                            keyboardType: TextInputType.datetime,
                            decoration: _inputDecoration(
                              'İlişki yaşadığın kişinin doğum tarihi',
                              Icons.cake_rounded,
                            ),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(_isSaving ? 'Kaydediliyor...' : 'Profili Kaydet'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
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