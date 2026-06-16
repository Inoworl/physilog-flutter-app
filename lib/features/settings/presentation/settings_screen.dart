import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:physi_log/app/theme/app_colors.dart';
import 'package:physi_log/app/theme/app_text_styles.dart';
import 'package:physi_log/providers/app_providers.dart';

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

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final authUser = ref
        .watch(authStateProvider)
        .maybeWhen(data: (user) => user, orElse: () => null);
    final registeredEmail = authUser?.email?.trim();
    final hasRegisteredEmail =
        registeredEmail != null && registeredEmail.isNotEmpty;

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
                _AccountEmailStatus(email: registeredEmail),
                const Divider(height: 1),
                if (hasRegisteredEmail) ...[
                  _SettingsTile(
                    icon: Icons.alternate_email,
                    title: 'メールアドレス変更',
                    subtitle: '確認メールを送って変更する',
                    onTap: () => _openAccountAuth(
                      context,
                      AccountEmailAuthMode.changeEmail,
                    ),
                  ),
                  const Divider(height: 1),
                  _SettingsTile(
                    icon: Icons.lock_outline,
                    title: 'パスワード変更',
                    subtitle: '現在のパスワードで確認して変更する',
                    onTap: () => _openAccountAuth(
                      context,
                      AccountEmailAuthMode.changePassword,
                    ),
                  ),
                ] else ...[
                  _SettingsTile(
                    icon: Icons.mail_outline,
                    title: 'メールとパスワードを設定',
                    subtitle: 'この端末で使うログイン情報を作成',
                    onTap: () => _openAccountAuth(
                      context,
                      AccountEmailAuthMode.register,
                    ),
                  ),
                  const Divider(height: 1),
                  _SettingsTile(
                    icon: Icons.login_outlined,
                    title: '別端末から引き継ぐ',
                    subtitle: '別端末で設定済みの情報を使用',
                    onTap: () => _openAccountAuth(
                      context,
                      AccountEmailAuthMode.transfer,
                    ),
                  ),
                ],
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

  void _openAccountAuth(BuildContext context, AccountEmailAuthMode mode) {
    context.pushNamed(
      'settingsAccountAuth',
      pathParameters: {'mode': mode.routeSegment},
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
      try {
        await ref.read(authServiceProvider).deleteAccount();
        if (!context.mounted) {
          return;
        }
        messenger.showSnackBar(const SnackBar(content: Text('アカウントを削除しました')));
      } catch (error) {
        if (!context.mounted) {
          return;
        }
        final message = ref
            .read(authServiceProvider)
            .messageForAuthError(error);
        messenger.showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }
}

enum AccountEmailAuthMode { register, transfer, changeEmail, changePassword }

AccountEmailAuthMode? accountEmailAuthModeFromRoute(String? value) {
  return switch (value) {
    'register' => AccountEmailAuthMode.register,
    'transfer' => AccountEmailAuthMode.transfer,
    'change-email' => AccountEmailAuthMode.changeEmail,
    'change-password' => AccountEmailAuthMode.changePassword,
    _ => null,
  };
}

extension AccountEmailAuthModeRoute on AccountEmailAuthMode {
  String get routeSegment {
    return switch (this) {
      AccountEmailAuthMode.register => 'register',
      AccountEmailAuthMode.transfer => 'transfer',
      AccountEmailAuthMode.changeEmail => 'change-email',
      AccountEmailAuthMode.changePassword => 'change-password',
    };
  }

  String get title {
    return switch (this) {
      AccountEmailAuthMode.register => 'メールとパスワードを設定',
      AccountEmailAuthMode.transfer => '別端末から引き継ぐ',
      AccountEmailAuthMode.changeEmail => 'メールアドレス変更',
      AccountEmailAuthMode.changePassword => 'パスワード変更',
    };
  }
}

class AccountEmailAuthScreen extends StatelessWidget {
  const AccountEmailAuthScreen({super.key, required this.mode});

  final AccountEmailAuthMode mode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(mode.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.xxl,
          ),
          children: [_EmailAuthForm(mode: mode)],
        ),
      ),
    );
  }
}

class _AccountEmailStatus extends StatelessWidget {
  const _AccountEmailStatus({required this.email});

  final String? email;

  @override
  Widget build(BuildContext context) {
    final value = email == null || email!.isEmpty ? '未登録' : email!;
    return ListTile(
      leading: const Icon(
        Icons.account_circle_outlined,
        color: AppColors.primary,
      ),
      title: const Text('メールアドレス', style: AppTextStyles.cardTitle),
      subtitle: Text(
        value,
        style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

class _EmailAuthForm extends ConsumerStatefulWidget {
  const _EmailAuthForm({required this.mode});

  final AccountEmailAuthMode mode;

  @override
  ConsumerState<_EmailAuthForm> createState() => _EmailAuthFormState();
}

class _EmailAuthFormState extends ConsumerState<_EmailAuthForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  bool _isSubmitting = false;
  bool _obscurePasswords = true;

  bool get _isTransferMode => widget.mode == AccountEmailAuthMode.transfer;
  bool get _isRegisterMode => widget.mode == AccountEmailAuthMode.register;
  bool get _isChangeEmailMode =>
      widget.mode == AccountEmailAuthMode.changeEmail;
  bool get _isChangePasswordMode =>
      widget.mode == AccountEmailAuthMode.changePassword;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _currentPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _description,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (_isTransferMode) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'ログイン後は、この端末の未登録状態で作成したデータは表示されなくなります。',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            if (_isRegisterMode || _isTransferMode || _isChangeEmailMode)
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: _emailLabel),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                enabled: !_isSubmitting,
                validator: _validateEmail,
              ),
            if (_isRegisterMode || _isTransferMode || _isChangeEmailMode)
              const SizedBox(height: AppSpacing.md),
            if (_isChangeEmailMode || _isChangePasswordMode) ...[
              _passwordField(
                controller: _currentPasswordController,
                labelText: '現在のパスワード',
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (_isRegisterMode || _isTransferMode)
              _passwordField(
                controller: _passwordController,
                labelText: 'パスワード',
                textInputAction: _isRegisterMode
                    ? TextInputAction.next
                    : TextInputAction.done,
              ),
            if (_isRegisterMode || _isTransferMode)
              const SizedBox(height: AppSpacing.md),
            if (_isChangePasswordMode) ...[
              _passwordField(
                controller: _passwordController,
                labelText: '新しいパスワード',
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (_isRegisterMode || _isChangePasswordMode) ...[
              _passwordField(
                controller: _confirmPasswordController,
                labelText: _isChangePasswordMode ? '新しいパスワード再入力' : 'パスワード再入力',
                textInputAction: TextInputAction.done,
                validator: _validateConfirmPassword,
              ),
              const SizedBox(height: AppSpacing.lg),
            ] else
              const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: Text(_submitLabel),
            ),
          ],
        ),
      ),
    );
  }

  String get _description {
    switch (widget.mode) {
      case AccountEmailAuthMode.register:
        return 'この端末のデータを別端末でも使えるようにします。';
      case AccountEmailAuthMode.transfer:
        return '登録済みのメールアドレスで以前の端末のデータを読み込みます。';
      case AccountEmailAuthMode.changeEmail:
        return '現在のパスワードで確認して、新しいメールアドレスへ確認メールを送ります。';
      case AccountEmailAuthMode.changePassword:
        return '現在のパスワードで確認して、新しいパスワードへ変更します。';
    }
  }

  String get _emailLabel {
    if (_isChangeEmailMode) {
      return '新しいメールアドレス';
    }
    return 'メールアドレス';
  }

  String get _submitLabel {
    switch (widget.mode) {
      case AccountEmailAuthMode.register:
        return '設定する';
      case AccountEmailAuthMode.transfer:
        return 'データを引き継ぐ';
      case AccountEmailAuthMode.changeEmail:
        return '確認メールを送る';
      case AccountEmailAuthMode.changePassword:
        return 'パスワードを変更する';
    }
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String labelText,
    required TextInputAction textInputAction,
    FormFieldValidator<String>? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        suffixIcon: IconButton(
          tooltip: _obscurePasswords ? 'パスワードを表示' : 'パスワードを隠す',
          icon: Icon(
            _obscurePasswords
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          onPressed: _isSubmitting
              ? null
              : () => setState(() => _obscurePasswords = !_obscurePasswords),
        ),
      ),
      obscureText: _obscurePasswords,
      enabled: !_isSubmitting,
      textInputAction: textInputAction,
      validator: validator ?? _validatePassword,
    );
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'メールアドレスを入力してください';
    if (!email.contains('@')) return 'メールアドレスの形式が正しくありません';
    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').length < 6) {
      return 'パスワードは6文字以上で入力してください';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    final password = _passwordController.text;
    if ((value ?? '').length < 6) {
      return 'パスワードは6文字以上で入力してください';
    }
    if (value != password) {
      return 'パスワードが一致しません';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final authService = ref.read(authServiceProvider);
    try {
      switch (widget.mode) {
        case AccountEmailAuthMode.register:
          await authService.linkEmailAndPassword(
            email: _emailController.text,
            password: _passwordController.text,
          );
        case AccountEmailAuthMode.transfer:
          await authService.signInWithEmailAndPassword(
            email: _emailController.text,
            password: _passwordController.text,
          );
        case AccountEmailAuthMode.changeEmail:
          await authService.changeEmail(
            currentPassword: _currentPasswordController.text,
            newEmail: _emailController.text,
          );
        case AccountEmailAuthMode.changePassword:
          await authService.changePassword(
            currentPassword: _currentPasswordController.text,
            newPassword: _passwordController.text,
          );
      }

      _emailController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
      _currentPasswordController.clear();

      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text(_successMessage)));
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(authService.messageForAuthError(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String get _successMessage {
    switch (widget.mode) {
      case AccountEmailAuthMode.register:
        return '引き継ぎ設定を保存しました';
      case AccountEmailAuthMode.transfer:
        return 'データを引き継ぎました';
      case AccountEmailAuthMode.changeEmail:
        return '新しいメールアドレスへ確認メールを送信しました';
      case AccountEmailAuthMode.changePassword:
        return 'パスワードを変更しました';
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
