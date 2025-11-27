import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/custom_button.dart';
import '../utils/app_colors.dart';
import '../utils/app_styles.dart';
import '../services/auth_service.dart'; // Import Service
import 'package:supabase_flutter/supabase_flutter.dart'; // Thêm dòng này

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  /// If true the screen will send an OTP automatically when it opens.
  final bool autoSend;

  const OtpVerificationScreen({
    super.key,
    required this.email,
    this.autoSend = true,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final AuthService _authService = AuthService();
  
  bool _isLoading = false;
  // Accept 4-digit OTP (preferred)
  static const int _otpLength = 4;
  final List<TextEditingController> _controllers = List.generate(_otpLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(_otpLength, (_) => FocusNode());
  // Flexible full-code controller (accepts paste or typing of full code 4-8 digits)
  final TextEditingController _fullOtpController = TextEditingController();
  // Control whether to show the single-digit boxes. Hidden by default for now.
  final bool _showDigitBoxes = false;
  // Focus node for the full-code input when digit boxes are hidden
  final FocusNode _fullOtpFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Autofocus first field when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (_showDigitBoxes) {
          _focusNodes[0].requestFocus();
        } else {
          _fullOtpFocus.requestFocus();
        }
        // Send OTP automatically when the screen appears only if allowed
        if (widget.autoSend) {
          _handleVerification();
        }
      }
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _fullOtpFocus.dispose();
    _fullOtpController.dispose();
    super.dispose();
  }

  Future<void> _handleVerification() async {
    setState(() => _isLoading = true);
    try {
      // Send an email OTP (code)
      await _authService.sendEmailOtp(widget.email);
      if (!mounted) return;
      // Clear any previous digits and focus first input
      for (final c in _controllers) {
        c.clear();
      }
      if (_showDigitBoxes) {
        _focusNodes[0].requestFocus();
      } else {
        _fullOtpFocus.requestFocus();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP sent — check your email')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send OTP: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyCode() async {
    // 1. LẤY MÃ CODE TỪ GIAO DIỆN (Phần này đang bị thiếu gây ra lỗi 'code')
    final full = _fullOtpController.text.trim();
    String code;
    // Ưu tiên lấy từ ô nhập full nếu có, ngược lại lấy từ 4 ô nhỏ
    if (full.isNotEmpty && full.length >= 4 && full.length <= 8) {
      code = full;
    } else {
      code = _controllers.map((c) => c.text.trim()).join();
    }

    // Kiểm tra độ dài
    if (code.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đủ mã xác thực')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 2. GỌI API XÁC THỰC
      await _authService.verifyEmailOtp(widget.email, code);

      // 3. KIỂM TRA LẠI SESSION (Logic giữ đăng nhập)
      // Đợi một chút để Session kịp cập nhật vào bộ nhớ máy
      if (Supabase.instance.client.auth.currentSession == null) {
        // Thử refresh lại session nếu thấy null
        try {
          await Supabase.instance.client.auth.refreshSession();
        } catch (_) {}
      }

      // Kiểm tra lần cuối cùng
      if (Supabase.instance.client.auth.currentSession == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Xác thực đúng nhưng chưa lưu được phiên. Vui lòng thử lại.'),
              backgroundColor: Colors.orange,
            )
        );
        return;
      }

      // 4. THÀNH CÔNG -> VÀO HOME
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đăng nhập thành công!'))
      );
      Navigator.of(context).pushReplacementNamed('/home');

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi xác thực: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Xác thực', style: TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 60),
                const Text('Xác thực tài khoản', style: AppStyles.heading),
                const SizedBox(height: 8),
                Text(
                  'Vui lòng thực hiện xác thực tại email:\n${widget.email}',
                  textAlign: TextAlign.center,
                  style: AppStyles.subheading,
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? const CircularProgressIndicator(color: AppColors.primaryGreen)
                    : Column(
                        children: [
                          // Digit boxes are hidden by default; toggle `_showDigitBoxes` to show them.
                          _showDigitBoxes
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(_otpLength, (i) {
                                    return Container(
                                      width: 54,
                                      margin: const EdgeInsets.symmetric(horizontal: 6),
                                      child: TextField(
                                        controller: _controllers[i],
                                        focusNode: _focusNodes[i],
                                        autofocus: i == 0,
                                        textAlign: TextAlign.center,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(1)],
                                        onChanged: (v) {
                                          // Delay the focus change slightly to avoid
                                          // interfering with the current input event and
                                          // platform keyboard behavior which can cause
                                          // unexpected unfocus on some devices/emulators.
                                          if (v.isNotEmpty) {
                                            if (i < _otpLength - 1) {
                                              Future.delayed(const Duration(milliseconds: 120), () {
                                                if (!mounted) return;
                                                _focusNodes[i + 1].requestFocus();
                                              });
                                            } else {
                                              // Last digit entered — keep focus on the last
                                              // box to avoid the keyboard dismissing.
                                            }
                                          } else {
                                            if (i > 0) {
                                              Future.delayed(const Duration(milliseconds: 80), () {
                                                if (!mounted) return;
                                                _focusNodes[i - 1].requestFocus();
                                              });
                                            }
                                          }
                                        },
                                        decoration: const InputDecoration(border: OutlineInputBorder()),
                                      ),
                                    );
                                  }),
                                )
                              : const SizedBox.shrink(),
                            const SizedBox(height: 12),
                            // Flexible full-code input (accept pasted codes from Supabase)
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 24),
                              child: TextField(
                                controller: _fullOtpController,
                                focusNode: _fullOtpFocus,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
                                decoration: const InputDecoration(
                                  labelText: 'Hoặc dán mã đầy đủ tại đây',
                                  border: OutlineInputBorder(),
                                  hintText: 'Nhập mã xác thực',
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          CustomButton(text: 'Xác nhận', onPressed: _verifyCode),
                          TextButton(
                            onPressed: _isLoading ? null : _handleVerification,
                            child: const Text('Gửi lại mã xác thực'),
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}