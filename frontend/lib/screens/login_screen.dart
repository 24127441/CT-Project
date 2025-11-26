import 'package:flutter/material.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_button.dart';
import '../utils/app_colors.dart';
import '../utils/app_styles.dart';
import '../services/auth_service.dart';
import 'signup_screen.dart';
import 'otp_verification_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Vui lòng điền đầy đủ thông tin'),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // BƯỚC 1: Kiểm tra Email và Mật khẩu trước
      // (Hàm này trả về true nếu đăng nhập thành công)
      final isLoggedIn = await _authService.login(email, password);

      if (isLoggedIn) {
        // BƯỚC 2: Mật khẩu đúng -> Đăng xuất ngay lập tức
        // Mục đích: Chỉ dùng mật khẩu để xác minh sơ bộ, buộc phải có OTP mới lấy được session cuối cùng.
        await _authService.signOut();

        // BƯỚC 3: Gửi OTP xác thực
        await _authService.sendEmailOtp(email);

        if (!mounted) return;

        // BƯỚC 4: Chuyển sang màn hình nhập OTP
        // (Màn hình OTP sẽ lo việc xác thực và chuyển vào Home)
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => OtpVerificationScreen(email: email)),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mật khẩu đúng. Vui lòng nhập OTP đã gửi về email.')),
        );
      } else {
        // Trường hợp login trả về false (ít gặp nếu có try-catch, nhưng cứ xử lý)
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đăng nhập không thành công. Vui lòng kiểm tra lại.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      // Bắt lỗi sai mật khẩu hoặc lỗi mạng
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Lỗi: Email hoặc mật khẩu không chính xác ($e)'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                
                const Text('Chào mừng trở lại!', style: AppStyles.heading),
                const SizedBox(height: 8),
                const Text('Đăng nhập để tiếp tục hành trình.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 40),
                
                CustomTextField(
                  hintText: 'Email',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                
                CustomTextField(
                  hintText: 'Mật khẩu',
                  controller: _passwordController,
                  obscureText: true,
                ),
                const SizedBox(height: 32),
                
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
                      : CustomButton(text: 'Đăng nhập', onPressed: _handleLogin),
                ),
                
                const SizedBox(height: 40), 
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Chưa có tài khoản? ', style: TextStyle(color: AppColors.textDark)),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SignupScreen()),
                        );
                      },
                      child: const Text(
                        'Đăng ký ngay',
                        style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}