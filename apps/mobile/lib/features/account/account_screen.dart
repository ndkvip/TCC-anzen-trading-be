import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/animated_reveal.dart';
import '../auth/auth_controller.dart';
import '../auth/login_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key, required this.auth});
  final AuthController auth;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: auth,
    builder: (context, _) => Scaffold(
      key: const ValueKey('account-screen-scaffold'),
      backgroundColor: context.appStatusColors.canvas,
      appBar: AppBar(
        backgroundColor: context.appStatusColors.canvas,
        surfaceTintColor: Colors.transparent,
        leading: const BackButton(),
        title: const Text('Tài khoản & bảo mật'),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            18,
            20,
            AppLayout.bottomContentPadding(context),
          ),
          children: [
            Text(
              'TÀI KHOẢN',
              style: TextStyle(
                color: context.appStatusColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Không gian cá nhân.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            if (!auth.isAuthenticated)
              AnimatedReveal(child: _GuestCard(auth: auth))
            else ...[
              AnimatedReveal(
                child: Container(
                  padding: const EdgeInsets.all(19),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        context.appStatusColors.primary,
                        context.appStatusColors.dark,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: AppColors.lime,
                        foregroundColor: context.appStatusColors.dark,
                        child: Text(
                          auth.user!.name.characters.first.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              auth.user!.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              auth.user!.email,
                              style: const TextStyle(
                                color: Color(0xFFD7E7F0),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .13),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                auth.user!.tierLabel.toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.lime,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: .7,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const AnimatedReveal(
                delay: Duration(milliseconds: 90),
                child: _ProgressCard(),
              ),
              const SizedBox(height: 20),
              AnimatedReveal(
                delay: const Duration(milliseconds: 140),
                child: _MenuGroup(
                  children: [
                    _MenuItem(
                      icon: Icons.edit_outlined,
                      title: 'Chỉnh sửa hồ sơ',
                      subtitle: 'Cập nhật họ và tên',
                      onTap: () => _editProfile(context),
                    ),
                    _MenuItem(
                      icon: Icons.check_circle_outline_rounded,
                      title: 'Lịch sử học tập',
                      subtitle: 'Theo dõi bài đã đọc',
                      onTap: () {},
                    ),
                    _MenuItem(
                      icon: Icons.lock_outline_rounded,
                      title: 'Đổi mật khẩu',
                      subtitle: 'Cập nhật bảo mật tài khoản',
                      onTap: () => _changePassword(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              AnimatedReveal(
                delay: const Duration(milliseconds: 180),
                child: _MenuGroup(
                  children: [
                    _MenuItem(
                      icon: Icons.help_outline_rounded,
                      title: 'Trợ giúp',
                      subtitle: 'Câu hỏi thường gặp',
                      onTap: () {},
                    ),
                    _MenuItem(
                      icon: Icons.info_outline_rounded,
                      title: 'Về ANZEN TRADING',
                      subtitle: 'Phiên bản 1.0.0',
                      onTap: () {},
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              AnimatedReveal(
                delay: const Duration(milliseconds: 220),
                child: OutlinedButton.icon(
                  onPressed: auth.loading ? null : () => auth.logout(),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    foregroundColor: AppColors.coral,
                    side: const BorderSide(color: AppColors.coral),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text(
                    'Đăng xuất',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  Future<void> _editProfile(BuildContext context) async {
    if (auth.user == null) return;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => EditProfileSheet(auth: auth),
    );
    if (result == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã cập nhật hồ sơ.')));
    }
  }

  Future<void> _changePassword(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ChangePasswordSheet(auth: auth),
    );
    if (result == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã cập nhật mật khẩu.')));
    }
  }
}

class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({super.key, required this.auth});

  final AuthController auth;

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final String _email;

  @override
  void initState() {
    super.initState();
    final user = widget.auth.user!;
    _nameController = TextEditingController(text: user.name);
    _email = user.email;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.auth.loading || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final success = await widget.auth.updateProfile(_nameController.text);
    if (success && mounted) Navigator.pop(context, true);
  }

  Future<void> _changePassword() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ChangePasswordSheet(auth: widget.auth),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã cập nhật mật khẩu.')));
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.auth,
    builder: (context, _) => SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        22,
        24,
        22,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Chỉnh sửa hồ sơ',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Đóng',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextFormField(
              key: const ValueKey('profile-name-field'),
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              maxLength: 100,
              decoration: const InputDecoration(
                labelText: 'Họ và tên',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (value) {
                final normalized = value?.trim() ?? '';
                if (normalized.length < 2) {
                  return 'Họ và tên phải có ít nhất 2 ký tự.';
                }
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _email,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Email đăng nhập',
                prefixIcon: Icon(Icons.mail_outline_rounded),
                helperText: 'Email không thể thay đổi trong hồ sơ.',
              ),
            ),
            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 18),
            Text('Bảo mật', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            const Text(
              'Đổi mật khẩu đăng nhập để bảo vệ tài khoản.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey('change-password-entry'),
              onPressed: widget.auth.loading ? null : _changePassword,
              icon: const Icon(Icons.lock_reset_rounded),
              label: const Text('Thay đổi mật khẩu'),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const ValueKey('save-profile-button'),
              onPressed: widget.auth.loading ? null : _submit,
              icon: widget.auth.loading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(widget.auth.loading ? 'Đang lưu...' : 'Lưu thay đổi'),
            ),
            if (widget.auth.error != null) ...[
              const SizedBox(height: 10),
              Text(
                widget.auth.error!,
                style: const TextStyle(color: AppColors.coral),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class ChangePasswordSheet extends StatefulWidget {
  const ChangePasswordSheet({super.key, required this.auth});

  final AuthController auth;

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.auth.loading || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final success = await widget.auth.changePassword(
      _currentController.text,
      _newController.text,
    );
    if (success && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.auth,
    builder: (context, _) => SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        22,
        24,
        22,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Thay đổi mật khẩu',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Đóng',
                  onPressed: widget.auth.loading
                      ? null
                      : () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Mật khẩu mới phải có ít nhất 8 ký tự.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 18),
            TextFormField(
              key: const ValueKey('current-password-field'),
              controller: _currentController,
              obscureText: !_showCurrent,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Mật khẩu hiện tại',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _showCurrent ? 'Ẩn mật khẩu' : 'Hiện mật khẩu',
                  onPressed: () => setState(() => _showCurrent = !_showCurrent),
                  icon: Icon(
                    _showCurrent
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
              validator: (value) => (value?.isEmpty ?? true)
                  ? 'Vui lòng nhập mật khẩu hiện tại.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('new-password-field'),
              controller: _newController,
              obscureText: !_showNew,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'Mật khẩu mới',
                prefixIcon: const Icon(Icons.password_rounded),
                suffixIcon: IconButton(
                  tooltip: _showNew ? 'Ẩn mật khẩu' : 'Hiện mật khẩu',
                  onPressed: () => setState(() => _showNew = !_showNew),
                  icon: Icon(
                    _showNew
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
              validator: (value) => (value?.length ?? 0) < 8
                  ? 'Mật khẩu mới phải có ít nhất 8 ký tự.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('confirm-password-field'),
              controller: _confirmController,
              obscureText: !_showConfirm,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'Nhập lại mật khẩu mới',
                prefixIcon: const Icon(Icons.verified_user_outlined),
                suffixIcon: IconButton(
                  tooltip: _showConfirm ? 'Ẩn mật khẩu' : 'Hiện mật khẩu',
                  onPressed: () => setState(() => _showConfirm = !_showConfirm),
                  icon: Icon(
                    _showConfirm
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
              validator: (value) => value != _newController.text
                  ? 'Mật khẩu nhập lại chưa khớp.'
                  : null,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const ValueKey('submit-password-button'),
              onPressed: widget.auth.loading ? null : _submit,
              icon: widget.auth.loading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lock_reset_rounded),
              label: Text(
                widget.auth.loading ? 'Đang cập nhật...' : 'Cập nhật mật khẩu',
              ),
            ),
            if (widget.auth.error != null) ...[
              const SizedBox(height: 10),
              Text(
                widget.auth.error!,
                style: const TextStyle(color: AppColors.coral),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _GuestCard extends StatelessWidget {
  const _GuestCard({required this.auth});
  final AuthController auth;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(25),
      border: Border.all(color: AppColors.line),
    ),
    child: Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: AppColors.lime,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Icon(
            Icons.person_outline_rounded,
            size: 36,
            color: context.appStatusColors.dark,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Đăng nhập để học cùng ANZEN TRADING',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Truy cập khóa học và xây nhật ký giao dịch của riêng bạn.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => LoginScreen(auth: auth))),
          child: const Text('Đăng nhập'),
        ),
      ],
    ),
  );
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard();
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Tiến độ học tập',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              Text(
                '38%',
                style: TextStyle(
                  color: context.appStatusColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: .38),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: AppColors.line,
                color: context.appStatusColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 11),
          const Text(
            '5/13 bài cơ bản đã hoàn thành',
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    ),
  );
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: AppColors.line),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(children: children),
  );
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    leading: Container(
      width: 39,
      height: 39,
      decoration: BoxDecoration(
        color: const Color(0xFFE7EFF4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: context.appStatusColors.primary, size: 20),
    ),
    title: Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
    ),
    subtitle: Text(
      subtitle,
      style: const TextStyle(color: AppColors.muted, fontSize: 11),
    ),
    trailing: Icon(
      Icons.arrow_forward_ios_rounded,
      size: 14,
      color: AppColors.muted,
    ),
  );
}
