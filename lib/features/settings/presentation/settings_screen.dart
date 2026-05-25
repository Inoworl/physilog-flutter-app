import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:physi_log/app/theme/app_colors.dart';
import 'package:physi_log/app/theme/app_text_styles.dart';

const _docsBaseUrl = String.fromEnvironment(
  'DOCS_BASE_URL',
  defaultValue: 'https://physilog-dev.web.app',
);
const _privacyPolicyUrl = '$_docsBaseUrl/privacy.html';
const _termsUrl = '$_docsBaseUrl/terms.html';
const _usageGuideUrl = '$_docsBaseUrl/usage.html';
const _transferGuideUrl = '$_docsBaseUrl/transfer.html';
const _accountDeletionUrl = '$_docsBaseUrl/account-deletion.html';
const _measurementTipsUrl = '$_docsBaseUrl/measurement-tips.html';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.xxl,
          ),
          children: [
            _SettingsSection(
              title: 'アカウント',
              children: [
                _SettingsTile(
                  icon: Icons.mail_outline,
                  title: 'メールアドレス登録',
                  subtitle: '端末引き継ぎに使う連絡先を登録',
                  onTap: () => _showEmailRegistrationSheet(context),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            _SettingsSection(
              title: '規約・ポリシー',
              children: [
                _SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'プライバシーポリシー',
                  subtitle: '個人情報とデータの取り扱い',
                  onTap: () => _openHelp(
                    context,
                    title: 'プライバシーポリシー',
                    url: _privacyPolicyUrl,
                  ),
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.description_outlined,
                  title: '利用規約',
                  subtitle: 'アプリの利用条件',
                  onTap: () =>
                      _openHelp(context, title: '利用規約', url: _termsUrl),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            _SettingsSection(
              title: '端末引き継ぎ',
              children: [
                _SettingsTile(
                  icon: Icons.sync_alt,
                  title: '引き継ぎ方法を見る',
                  subtitle: '新しい端末で記録を復元する手順',
                  onTap: () => _openHelp(
                    context,
                    title: '端末引き継ぎ',
                    url: _transferGuideUrl,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            _SettingsSection(
              title: 'ヘルプ',
              children: [
                _SettingsTile(
                  icon: Icons.help_outline,
                  title: 'アプリの使い方',
                  subtitle: '動画計測から記録管理までの基本操作',
                  onTap: () =>
                      _openHelp(context, title: 'アプリの使い方', url: _usageGuideUrl),
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.timer_outlined,
                  title: '計測のコツ',
                  subtitle: '開始・終了フレームを合わせるポイント',
                  onTap: () => _openHelp(
                    context,
                    title: '計測のコツ',
                    url: _measurementTipsUrl,
                  ),
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.delete_outline,
                  title: 'アカウント削除方法',
                  subtitle: '削除対象データと手順',
                  onTap: () => _openHelp(
                    context,
                    title: 'アカウント削除方法',
                    url: _accountDeletionUrl,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            _SettingsSection(
              title: '危険な操作',
              children: [
                _SettingsTile(
                  icon: Icons.delete_forever_outlined,
                  title: 'アカウント削除',
                  subtitle: '記録・選手・種目を削除する前に確認します',
                  iconColor: AppColors.error,
                  titleColor: AppColors.error,
                  onTap: () => _showDeleteAccountDialog(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openHelp(
    BuildContext context, {
    required String title,
    required String url,
  }) {
    context.pushNamed(
      'settingsHelp',
      queryParameters: {'title': title, 'url': url},
    );
  }

  void _showEmailRegistrationSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.md,
            AppSpacing.xl,
            AppSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('メールアドレス登録', style: AppTextStyles.sectionTitle),
              const SizedBox(height: AppSpacing.md),
              Text(
                '端末引き継ぎに使うメールアドレス登録は次のステップで有効化します。',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('閉じる'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showDeleteAccountDialog(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('アカウントを削除しますか？'),
        content: const Text('記録、選手、種目が削除対象になります。この操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      messenger.showSnackBar(const SnackBar(content: Text('アカウント削除は準備中です')));
    }
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.sectionTitle),
        const SizedBox(height: AppSpacing.sm),
        Card(child: Column(children: children)),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
    this.titleColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? AppColors.primary),
      title: Text(
        title,
        style: AppTextStyles.cardTitle.copyWith(color: titleColor),
      ),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
