import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import 'auth_controller.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.auth});
  final AuthController auth;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _otp = TextEditingController();
  Timer? _timer;
  bool _obscure = true;
  bool _otpStep = false;
  int _resendRemaining = 0;
  String? _debugOtp;

  @override
  void dispose() {
    _timer?.cancel();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    if (name.length < 2 ||
        !_validEmail(email) ||
        _password.text.length < 8 ||
        _password.text != _confirm.text) {
      _showMessage('Nhập họ tên, email hợp lệ và mật khẩu tối thiểu 8 ký tự.');
      return;
    }
    try {
      final result = await widget.auth.requestRegistrationOtp(
        name,
        email,
        _password.text,
      );
      if (!mounted) return;
      // Hide the password keyboard before switching to the OTP form.
      // Otherwise iOS keeps the keyboard open and covers the confirmation button.
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() {
        _otpStep = true;
        _debugOtp = result.debugOtp;
        // In local development the API returns the same OTP that was sent
        // by email, so prefill it for a one-tap confirmation. Tapping the
        // field selects all text, allowing a manual code to replace it.
        _otp.text = result.debugOtp ?? '';
        _otp.selection = TextSelection.collapsed(offset: _otp.text.length);
      });
      _startCountdown(result.resendAfterSeconds);
      _showMessage(result.message);
    } catch (_) {
      if (mounted) _showMessage(widget.auth.error ?? 'Gửi OTP thất bại.');
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otp.text.replaceAll(RegExp(r'\s+'), '');
    if (otp.length != 6) {
      _showMessage('Nhập đủ mã OTP gồm 6 chữ số.');
      return;
    }
    final success = await widget.auth.verifyRegistrationOtp(
      _email.text.trim(),
      otp,
    );
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop(true);
    } else {
      _showMessage(widget.auth.error ?? 'OTP không đúng.');
    }
  }

  Future<void> _resendOtp() async {
    if (_resendRemaining > 0 || widget.auth.loading) return;
    try {
      final result = await widget.auth.resendRegistrationOtp(_email.text);
      if (!mounted) return;
      setState(() {
        _debugOtp = result.debugOtp;
        _otp.text = result.debugOtp ?? '';
        _otp.selection = TextSelection.collapsed(offset: _otp.text.length);
      });
      _startCountdown(result.resendAfterSeconds);
      _showMessage(result.message);
    } catch (_) {
      if (mounted) _showMessage(widget.auth.error ?? 'Gửi lại OTP thất bại.');
    }
  }

  void _startCountdown(int seconds) {
    _timer?.cancel();
    setState(() => _resendRemaining = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _resendRemaining <= 1) {
        timer.cancel();
        if (mounted) setState(() => _resendRemaining = 0);
      } else {
        setState(() => _resendRemaining -= 1);
      }
    });
  }

  bool _validEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.lime,
              borderRadius: BorderRadius.circular(21),
            ),
            child: Icon(
              _otpStep
                  ? Icons.mark_email_read_rounded
                  : Icons.person_add_alt_1_rounded,
              color: context.appStatusColors.dark,
              size: 30,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            _otpStep ? 'Nhập mã xác thực\nemail.' : 'Tạo tài khoản\nmiễn phí.',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 10),
          Text(
            _otpStep
                ? 'Mã 6 số đã được gửi tới ${_email.text.trim()}. Mã có hiệu lực trong 10 phút.'
                : 'Đăng ký bằng email. Tài khoản mới mặc định là Tài khoản thường.',
            style: const TextStyle(color: AppColors.muted, height: 1.45),
          ),
          const SizedBox(height: 28),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            child: _otpStep ? _buildOtpForm() : _buildRegistrationForm(),
          ),
        ],
      ),
    ),
  );

  Widget _buildRegistrationForm() => Column(
    key: const ValueKey('registration-form'),
    children: [
      TextField(
        controller: _name,
        keyboardType: TextInputType.name,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.name],
        decoration: const InputDecoration(
          labelText: 'Họ và tên',
          prefixIcon: Icon(Icons.badge_outlined),
        ),
      ),
      const SizedBox(height: 14),
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
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: 'Mật khẩu',
          helperText: 'Tối thiểu 8 ký tự',
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
      const SizedBox(height: 14),
      TextField(
        controller: _confirm,
        obscureText: _obscure,
        textInputAction: TextInputAction.done,
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        onSubmitted: (_) => _requestOtp(),
        decoration: const InputDecoration(
          labelText: 'Nhập lại mật khẩu',
          prefixIcon: Icon(Icons.verified_user_outlined),
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        'Sau khi xác thực email, bạn được trải nghiệm 4 bài học miễn phí theo quyền tài khoản.',
        style: TextStyle(color: AppColors.muted, fontSize: 11),
      ),
      const SizedBox(height: 20),
      _primaryButton('Gửi mã OTP', _requestOtp),
    ],
  );

  Widget _buildOtpForm() => Column(
    key: const ValueKey('otp-form'),
    children: [
      TextField(
        controller: _otp,
        autofocus: false,
        onTap: () {
          if (_otp.text.isNotEmpty) {
            _otp.selection = TextSelection(
              baseOffset: 0,
              extentOffset: _otp.text.length,
            );
          }
        },
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        keyboardType: TextInputType.number,
        autofillHints: const [AutofillHints.oneTimeCode],
        enableSuggestions: false,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _verifyOtp(),
        maxLength: 6,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          letterSpacing: 8,
        ),
        decoration: const InputDecoration(
          counterText: '',
          labelText: 'Mã OTP 6 số',
          prefixIcon: Icon(Icons.password_rounded),
        ),
      ),
      if (_debugOtp != null) ...[
        const SizedBox(height: 10),
        Text(
          'Mã thử nghiệm local: $_debugOtp',
          style: const TextStyle(color: AppColors.coral, fontSize: 12),
        ),
      ],
      const SizedBox(height: 16),
      _primaryButton('Xác thực và tạo tài khoản', _verifyOtp),
      const SizedBox(height: 8),
      TextButton(
        onPressed: _resendRemaining == 0 ? _resendOtp : null,
        child: Text(
          _resendRemaining == 0
              ? 'Gửi lại mã OTP'
              : 'Gửi lại sau ${_resendRemaining}s',
        ),
      ),
      TextButton(
        onPressed: widget.auth.loading
            ? null
            : () => setState(() => _otpStep = false),
        child: const Text('Đổi thông tin đăng ký'),
      ),
    ],
  );

  Widget _primaryButton(String label, VoidCallback onPressed) =>
      AnimatedBuilder(
        animation: widget.auth,
        builder: (context, _) => FilledButton(
          onPressed: widget.auth.loading ? null : onPressed,
          child: widget.auth.loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(label),
        ),
      );
}
