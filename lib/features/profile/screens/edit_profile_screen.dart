import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/l10n_extension.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/supabase_service.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _uploadingAvatar = false;
  String? _avatarUrl;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final uid = SupabaseService.userId;
    if (uid == null) { if (mounted) setState(() => _loading = false); return; }
    try {
      final data = await SupabaseService.client
          .from('profiles')
          .select('full_name, avatar_url')
          .eq('id', uid)
          .maybeSingle();
      if (mounted && data != null) {
        _nameCtrl.text = data['full_name'] as String? ?? '';
        _avatarUrl = data['avatar_url'] as String?;
      }
    } catch (e) {
      if (mounted) setState(() => _errorMsg = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final l = context.l10n;
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;

    setState(() => _uploadingAvatar = true);
    try {
      final uid = SupabaseService.userId!;
      final bytes = await File(file.path).readAsBytes();
      final ext = file.path.split('.').last.toLowerCase();
      final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';
      final storagePath = '$uid/avatar.$ext';

      await SupabaseService.client.storage
          .from('avatars')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: true,
            ),
          );

      final publicUrl = SupabaseService.client.storage
          .from('avatars')
          .getPublicUrl(storagePath);

      await SupabaseService.client
          .from('profiles')
          .update({'avatar_url': publicUrl})
          .eq('id', uid);

      if (mounted) {
        setState(() {
          _avatarUrl = publicUrl;
          _uploadingAvatar = false;
        });
        ref.invalidate(currentProfileProvider);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingAvatar = false);
        _showSnack(l.editProfileUploadError(e.toString()), isError: true);
      }
    }
  }

  Future<void> _save() async {
    final l = context.l10n;
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _errorMsg = l.editProfileNameEmpty);
      return;
    }
    setState(() { _saving = true; _errorMsg = null; });
    try {
      await SupabaseService.client
          .from('profiles')
          .update({'full_name': _nameCtrl.text.trim()})
          .eq('id', SupabaseService.userId!);
      ref.invalidate(currentProfileProvider);
      if (mounted) {
        _showSnack(l.editProfileSaved);
        context.pop();
      }
    } catch (e) {
      if (mounted) setState(() { _saving = false; _errorMsg = e.toString(); });
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.error : AppColors.statusConfirmed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: const Icon(Icons.arrow_forward_rounded, color: AppColors.textPrimary),
        ),
        title: Text(l.profileEditProfile,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  Center(
                    child: GestureDetector(
                      onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
                      child: Stack(
                        children: [
                          Container(
                            width: 96, height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary,
                              image: _avatarUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(_avatarUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: _uploadingAvatar
                                ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                : _avatarUrl == null
                                    ? Text(
                                        _nameCtrl.text.isNotEmpty ? _nameCtrl.text[0] : 'م',
                                        style: const TextStyle(
                                            fontSize: 36, fontWeight: FontWeight.w700, color: Colors.white),
                                      )
                                    : null,
                          ),
                          Positioned(
                            bottom: 0, right: 0,
                            child: Container(
                              width: 30, height: 30,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(Icons.camera_alt_rounded,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(l.editProfileChangePhoto,
                        style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
                  ),
                  const SizedBox(height: 28),

                  // Name field
                  Text(l.authFullName,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameCtrl,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: l.authFullNameHint,
                      hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
                      filled: true,
                      fillColor: AppColors.surface,
                      prefixIcon: const Icon(Icons.person_outline_rounded,
                          color: AppColors.textHint, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    ),
                  ),

                  if (_errorMsg != null) ...[
                    const SizedBox(height: 8),
                    Text(_errorMsg!,
                        style: const TextStyle(fontSize: 12, color: AppColors.error)),
                  ],

                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(l.editProfileSaveBtn,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
