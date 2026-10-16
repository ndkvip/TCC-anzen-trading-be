import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/brand_logo.dart';
import 'auth_controller.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.auth});
  final AuthController auth;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (widget.auth.loginInFlight) return;
    if (!_validEmail(_email.text.trim()) || _password.text.length < 8) {
      _showMessage('Nhập email hợp lệ và mật khẩu tối thiểu 8 ký tự.');
      return;
    }
    final success = await widget.auth.login(_email.text, _password.text);
    if (success && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _openRegistration() async {
    final registered = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => RegisterScreen(auth: widget.auth)),
    );
    // Registration verifies the email and creates an authenticated session.
    // Close this login route as well so the app shell is immediately visible.
    if (registered == true && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _forgotPassword() async {
    final email = TextEditingController(text: _email.text);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quên mật khẩu',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Nhập email đã đăng ký để nhận mã OTP đặt lại mật khẩu.',
            ),
            const SizedBox(height: 18),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => Navigator.pop(context, email.text),
              child: const Text('Gửi mã OTP'),
            ),
          ],
        ),
      ),
    );
    if (result == null || result.trim().isEmpty || !mounted) {
      return;
    }
    if (!_validEmail(result.trim())) {
      _showMessage('Vui lòng nhập email hợp lệ.');
      return;
    }

    try {
      final otpResponse = await widget.auth.requestPasswordResetOtp(result);
      if (!mounted) return;
      final otp = TextEditingController();
      final password = TextEditingController();
      final confirm = TextEditingController();
      final reset = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (context) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                'Xác thực và đặt lại',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Mã OTP đã gửi tới ${result.trim()}. Mã có hiệu lực trong 10 phút.',
              ),
              if (otpResponse.debugOtp != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Mã thử nghiệm local: ${otpResponse.debugOtp}',
                  style: const TextStyle(color: AppColors.coral),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: otp,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 6,
                decoration: const InputDecoration(labelText: 'Mã OTP 6 số'),
              ),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu mới (ít nhất 8 ký tự)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirm,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Nhập lại mật khẩu mới',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  if (password.text.length < 8 ||
                      password.text != confirm.text) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Mật khẩu mới chưa hợp lệ.'),
                      ),
                    );
                    return;
                  }
                  final success = await widget.auth.resetPasswordWithOtp(
                    result,
                    otp.text,
                    password.text,
                  );
                  if (context.mounted && success) Navigator.pop(context, true);
                },
                child: const Text('Đặt lại mật khẩu'),
              ),
              if (widget.auth.error != null) ...[
                const SizedBox(height: 8),
                Text(
                  widget.auth.error!,
                  style: const TextStyle(color: AppColors.coral),
                ),
              ],
            ],
          ),
        ),
      );
      otp.dispose();
      password.dispose();
      confirm.dispose();
      if (reset == true && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã đặt lại mật khẩu.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is ApiException
                  ? error.message
                  : 'Chưa thể gửi OTP. Vui lòng thử lại.',
            ),
          ),
        );
      }
    }
  }

  bool _validEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.auth,
      builder: (context, _) => Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton.filledTonal(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
              const SizedBox(height: 30),
              const SizedBox(width: 88, height: 88, child: AnzenLogo()),
              const SizedBox(height: 22),
              Text(
                'Chào mừng\ntrở lại.',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 10),
              const Text(
                'Đăng nhập để tiếp tục khóa học và nhật ký giao dịch của bạn.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _password,
                obscureText: _obscure,
                onSubmitted: (_) => _login(),
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _forgotPassword,
                  child: const Text('Quên mật khẩu?'),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (child, animation) => SizeTransition(
                  sizeFactor: animation,
                  axisAlignment: -1,
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: widget.auth.error == null
                    ? const SizedBox.shrink(key: ValueKey('no-login-error'))
                    : Container(
                        key: ValueKey(widget.auth.error),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.coral.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.auth.error!,
                          style: const TextStyle(
                            color: AppColors.coral,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
              ),
              FilledButton.icon(
                onPressed: widget.auth.loading ? null : _login,
                icon: widget.auth.loginInFlight
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login_rounded),
                label: widget.auth.loginInFlight
                    ? const Text('Đang đăng nhập...')
                    : const Text('Đăng nhập'),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Chưa có tài khoản?',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: widget.auth.loading ? null : _openRegistration,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Đăng ký miễn phí bằng email'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
