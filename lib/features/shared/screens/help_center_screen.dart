import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/l10n_extension.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../l10n/app_localizations.dart';

class HelpCenterScreen extends StatefulWidget {
  final String? initialTab; // 'contact' | 'privacy' | 'terms'

  const HelpCenterScreen({super.key, this.initialTab});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    final initial = switch (widget.initialTab) {
      'privacy' => 1,
      'terms' => 2,
      _ => 0,
    };
    _tabs = TabController(length: 3, vsync: this, initialIndex: initial);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
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
        title: Text(l.profileHelpCenter,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textHint,
          indicatorColor: AppColors.primary,
          indicatorWeight: 2.5,
          labelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: [
            Tab(text: l.helpContactTab),
            Tab(text: l.profilePrivacyPolicy),
            Tab(text: l.helpTermsTab),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _ContactTab(),
          _TextTab(content: l.privacyPolicyContent),
          _TextTab(content: l.termsContent),
        ],
      ),
    );
  }
}

// ── Contact tab ───────────────────────────────────────────────────────────────

class _ContactTab extends ConsumerWidget {
  const _ContactTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final supportPhone = ref.watch(supportPhoneProvider).asData?.value ?? '';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      children: [
        // Hero
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1B6B7A), Color(0xFF114F5B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.support_agent_rounded,
                    color: Colors.white, size: 32),
              ),
              const SizedBox(height: 12),
              Text(l.helpHeroTitle,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
              const SizedBox(height: 6),
              Text(l.helpHeroSub,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Colors.white70, height: 1.5)),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Contact options
        if (supportPhone.isNotEmpty) ...[
          _ContactOption(
            icon: Icons.phone_rounded,
            color: const Color(0xFF16A34A),
            label: l.helpCallUs,
            value: supportPhone,
            onTap: () => _copyToClipboard(context, l, supportPhone, l.helpCallUs),
          ),
          const SizedBox(height: 12),
        ],
        _ContactOption(
          icon: Icons.email_rounded,
          color: AppColors.primary,
          label: l.helpEmailUs,
          value: 'ahmedelkentawi@gmail.com',
          onTap: () => _copyToClipboard(context, l, 'ahmedelkentawi@gmail.com', l.helpEmailUs),
        ),
        const SizedBox(height: 32),

        // FAQ section
        _SectionTitle(l.helpFaqTitle),
        const SizedBox(height: 12),
        _FaqItem(question: l.faqQ1, answer: l.faqA1),
        _FaqItem(question: l.faqQ2, answer: l.faqA2),
        _FaqItem(question: l.faqQ3, answer: l.faqA3),
        _FaqItem(question: l.faqQ4, answer: l.faqA4),
      ],
    );
  }

  void _copyToClipboard(BuildContext context, AppLocalizations l, String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.helpCopied(label)),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _ContactOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _ContactOption({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
                color: AppColors.shadow, blurRadius: 4, offset: const Offset(0, 1))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textHint)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                ],
              ),
            ),
            const Icon(Icons.copy_rounded, size: 18, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}

class _FaqItem extends StatefulWidget {
  final String question;
  final String answer;

  const _FaqItem({required this.question, required this.answer});

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _open = !_open),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: _open ? AppColors.primary : AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(widget.question,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                  ),
                  Icon(
                    _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: AppColors.textHint,
                    size: 20,
                  ),
                ],
              ),
            ),
            if (_open)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Text(widget.answer,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.6)),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary));
  }
}

// ── Scrollable text tab (Privacy / Terms) ────────────────────────────────────

class _TextTab extends ConsumerWidget {
  final String content;
  const _TextTab({required this.content});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final supportPhone = ref.watch(supportPhoneProvider).asData?.value ?? '';
    final sections = content.split('\n\n');
    final showPhone = supportPhone.isNotEmpty;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      itemCount: sections.length + (showPhone ? 1 : 0),
      itemBuilder: (_, i) {
        // Phone contact banner appended after all content
        if (showPhone && i == sections.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1B6B7A), Color(0xFF114F5B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.support_agent_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.helpCallUs,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white70)),
                        const SizedBox(height: 2),
                        Text(supportPhone,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final s = sections[i].trim();
        if (s.startsWith('# ')) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(s.substring(2),
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
          );
        }
        if (s.startsWith('## ')) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 12),
            child: Text(s.substring(3),
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(s,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.7)),
        );
      },
    );
  }
}
