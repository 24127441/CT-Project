import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final _supabase = Supabase.instance.client;
  late User _currentUser;
  bool _isLoading = true;
  bool _isEditing = false;
  List<String> _allEmails = [];

  late TextEditingController _fullNameController;

  @override
  void initState() {
    super.initState();
    
    // Check if user is logged in before accessing profile
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      // User is not logged in, navigate back to welcome screen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/welcome',
            (route) => false,
          );
        }
      });
      // Initialize with empty controller to prevent errors
      _fullNameController = TextEditingController();
      return;
    }
    
    _currentUser = currentUser;
    _fullNameController = TextEditingController();
    _loadUserData();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      setState(() => _isLoading = true);
      
      // Check if user is still logged in
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        debugPrint('[ProfileScreen] No user logged in, redirecting to welcome');
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/welcome',
            (route) => false,
          );
        }
        return;
      }
      
      // Reload user to get latest metadata
      try {
        await _supabase.auth.refreshSession();
      } catch (e) {
        debugPrint('[ProfileScreen] Session refresh failed (might be expected): $e');
      }
      
      // Get fresh user data
      final refreshedUser = _supabase.auth.currentUser;
      if (refreshedUser == null) {
        debugPrint('[ProfileScreen] User session expired, redirecting to welcome');
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/welcome',
            (route) => false,
          );
        }
        return;
      }
      
      _currentUser = refreshedUser;
      
      // Get full name from user metadata if available
      final fullName = _currentUser.userMetadata?['full_name'] as String? ?? '';
      _fullNameController.text = fullName;
      
      debugPrint('[ProfileScreen] Loaded user: ${_currentUser.email}');
      debugPrint('[ProfileScreen] Full name: $fullName');
      
      // Fetch all existing emails from Supabase auth.users
      await _fetchExistingEmails();
      
      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('[ProfileScreen] Error loading user data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải hồ sơ: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchExistingEmails() async {
    try {
      debugPrint('[ProfileScreen] Fetching existing emails from Supabase...');
      
      // Query the users table to get all existing emails
      final response = await _supabase
          .from('users')
          .select('email');
      
      final emails = <String>[];
      for (final user in response) {
        final email = user['email'];
        if (email != null && email.toString().isNotEmpty) {
          emails.add(email.toString());
        }
      }
      
      setState(() {
        _allEmails = emails;
      });
      
      debugPrint('[ProfileScreen] Found ${emails.length} existing emails in Supabase');
      debugPrint('[ProfileScreen] Emails: $emails');
    } catch (e) {
      debugPrint('[ProfileScreen] Error fetching emails: $e');
      // Don't show error to user, this is just for debugging
    }
  }

  Future<void> _updateProfile() async {
    try {
      final fullName = _fullNameController.text.trim();

      if (fullName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng nhập tên đầy đủ'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() => _isLoading = true);

      debugPrint('[ProfileScreen] Updating user metadata with full_name: $fullName');

      // Update user metadata in Supabase
      await _supabase.auth.updateUser(
        UserAttributes(
          data: {'full_name': fullName},
        ),
      );

      // Refresh to get updated data
      await _supabase.auth.refreshSession();
      _currentUser = _supabase.auth.currentUser!;

      debugPrint('[ProfileScreen] User metadata updated successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cập nhật hồ sơ thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _isEditing = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[ProfileScreen] Error updating profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi cập nhật hồ sơ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureCurrentPassword = true;
    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Đổi mật khẩu'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPasswordController,
                  obscureText: obscureCurrentPassword,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu hiện tại',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureCurrentPassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setDialogState(() {
                          obscureCurrentPassword = !obscureCurrentPassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPasswordController,
                  obscureText: obscureNewPassword,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu mới',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureNewPassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setDialogState(() {
                          obscureNewPassword = !obscureNewPassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Xác nhận mật khẩu mới',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setDialogState(() {
                          obscureConfirmPassword = !obscureConfirmPassword;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                currentPasswordController.dispose();
                newPasswordController.dispose();
                confirmPasswordController.dispose();
                Navigator.pop(context);
              },
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                final currentPassword = currentPasswordController.text.trim();
                final newPassword = newPasswordController.text.trim();
                final confirmPassword = confirmPasswordController.text.trim();

                if (currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Vui lòng điền đầy đủ thông tin'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (newPassword.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Mật khẩu mới phải có ít nhất 6 ký tự'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (newPassword != confirmPassword) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Mật khẩu mới không khớp'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                currentPasswordController.dispose();
                newPasswordController.dispose();
                confirmPasswordController.dispose();
                Navigator.pop(context);

                await _changePassword(newPassword);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF425E3C),
              ),
              child: const Text('Đổi mật khẩu', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changePassword(String newPassword) async {
    try {
      setState(() => _isLoading = true);

      await _supabase.auth.updateUser(
        UserAttributes(
          password: newPassword,
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đổi mật khẩu thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('[ProfileScreen] Error changing password: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi đổi mật khẩu: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _showHelpSupport() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Trợ giúp & Hỗ trợ',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.email_outlined, color: Color(0xFF425E3C)),
              title: const Text('Gửi Email'),
              subtitle: const Text('Liên hệ qua email'),
              onTap: () {
                Navigator.pop(context);
                _launchEmail();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.phone_outlined, color: Color(0xFF425E3C)),
              title: const Text('Gọi điện'),
              subtitle: const Text('Liên hệ qua điện thoại'),
              onTap: () {
                Navigator.pop(context);
                _launchPhone();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.info_outlined, color: Color(0xFF425E3C)),
              title: const Text('About Us'),
              subtitle: const Text('Tìm hiểu về Trek Guide'),
              onTap: () {
                Navigator.pop(context);
                _showAboutUs();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutUs() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    'FIVE-POINT CREW',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF425E3C),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'Cùng phát triển ứng dụng chúng tôi\nđạt những mục đích sau',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                
                // Five Points Grid
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  children: [
                    _buildAboutCard(
                      icon: Icons.favorite_outline,
                      title: 'Từ lòng chân thành',
                      subtitle: 'chuyến trekking mỗi cách bạn bắn',
                      color: const Color(0xFF425E3C),
                    ),
                    _buildAboutCard(
                      icon: Icons.access_time,
                      title: 'Tiết kiệm thời gian tìm\nthông tin lịch',
                      color: const Color(0xFF425E3C),
                    ),
                    _buildAboutCard(
                      icon: Icons.people_outline,
                      title: 'Giúp hiểu rõ và\ndu xuân hợp tác',
                      color: const Color(0xFF425E3C),
                    ),
                    _buildAboutCard(
                      icon: Icons.group,
                      title: 'Cả nhân hóa chuyến\nđi trekking',
                      color: const Color(0xFF425E3C),
                    ),
                  ],
                ),
                
                const SizedBox(height: 30),
                
                // App Version and Info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Thông tin ứng dụng',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('Phiên bản: ', style: TextStyle(color: Colors.grey)),
                          Text('1.0.0', style: TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Năm: ', style: TextStyle(color: Colors.grey)),
                          Text(
                            DateTime.now().year.toString(),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Phát triển bởi: ', style: TextStyle(color: Colors.grey)),
                          Text('Five-Point-Crew', style: TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAboutCard({
    required IconData icon,
    required String title,
    String? subtitle,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
                height: 1.2,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _launchEmail() {
    final email = 'support@trekguide.com';
    final subject = Uri.encodeComponent('Trek Guide Support');
    final body = Uri.encodeComponent('Xin chào,\n\nTôi cần trợ giúp với...\n\nEmail: ${_currentUser.email}');
    
    final mailtoLink = 'mailto:$email?subject=$subject&body=$body';
    
    launchUrl(Uri.parse(mailtoLink)).catchError((error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể mở ứng dụng email'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    });
  }

  void _launchPhone() {
    const phoneNumber = '+84123456789';
    final telLink = 'tel:$phoneNumber';
    
    launchUrl(Uri.parse(telLink)).catchError((error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể gọi điện'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    });
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _authService.signOut();
        if (mounted) {
          // Clear navigation stack and return to welcome screen
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/welcome',
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi đăng xuất: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final forestGreen = const Color(0xFF425E3C);

    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            color: forestGreen,
            padding: const EdgeInsets.only(top: 60, bottom: 40, left: 20, right: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Cài đặt',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Body
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // User Avatar Section
                        Center(
                          child: Column(
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: forestGreen.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: forestGreen,
                                    width: 3,
                                  ),
                                ),
                                child: Icon(
                                  Icons.person,
                                  size: 50,
                                  color: forestGreen,
                                ),
                              ),
                              const SizedBox(height: 16),
                              // User Name (from metadata)
                              Text(
                                _fullNameController.text.isNotEmpty 
                                    ? _fullNameController.text 
                                    : 'Chưa cập nhật tên',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: _fullNameController.text.isNotEmpty 
                                      ? Colors.black87 
                                      : Colors.grey[400],
                                ),
                              ),
                              const SizedBox(height: 8),
                              // User Email
                              Text(
                                _currentUser.email ?? 'No email',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Edit Profile Section
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.grey[50],
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Thông tin cá nhân',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (!_isEditing)
                                    GestureDetector(
                                      onTap: () {
                                        setState(() => _isEditing = true);
                                      },
                                      child: Text(
                                        'Chỉnh sửa',
                                        style: TextStyle(
                                          color: forestGreen,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              // Full Name Field
                              TextField(
                                controller: _fullNameController,
                                enabled: _isEditing,
                                decoration: InputDecoration(
                                  labelText: 'Tên đầy đủ',
                                  hintText: 'Nhập tên của bạn',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: forestGreen,
                                      width: 2,
                                    ),
                                  ),
                                  disabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Email Field (Read-only)
                              TextField(
                                controller: TextEditingController(
                                  text: _currentUser.email ?? '',
                                ),
                                enabled: false,
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                  disabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Account Info
                              Text(
                                'Tài khoản được tạo: ${_formatDate(DateTime.parse(_currentUser.createdAt.toString()))}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Action Buttons
                              if (_isEditing)
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () {
                                          setState(() => _isEditing = false);
                                          _loadUserData();
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.grey[300],
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: Text(
                                          'Hủy',
                                          style: TextStyle(
                                            color: Colors.grey[800],
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: _updateProfile,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: forestGreen,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: const Text(
                                          'Lưu',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),

                        // Additional Settings Section
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.grey[50],
                          ),
                          child: Column(
                            children: [
                              _buildSettingItem(
                                icon: Icons.lock_outline,
                                title: 'Đổi mật khẩu',
                                subtitle: 'Thay đổi mật khẩu tài khoản',
                                onTap: _showChangePasswordDialog,
                              ),
                              _buildDivider(),
                              _buildSettingItem(
                                icon: Icons.help_outline,
                                title: 'Trợ giúp & Hỗ trợ',
                                subtitle: 'Liên hệ với chúng tôi',
                                onTap: _showHelpSupport,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),

                        // Debug: Existing Emails Section
                        if (_allEmails.isNotEmpty)
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.orange[50],
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.info_outline, 
                                      color: Colors.orange[700], 
                                      size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Emails hiện có trong hệ thống',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: Colors.orange[900],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey[300]!),
                                  ),
                                  constraints: const BoxConstraints(maxHeight: 200),
                                  child: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: _allEmails
                                          .map((email) => Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 4),
                                            child: Text(
                                              '• $email',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                          ))
                                          .toList(),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tổng: ${_allEmails.length} emails',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 30),

                        // Logout Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _handleLogout,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[400],
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Đăng xuất',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF425E3C)),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: Colors.grey[300],
    );
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return 'Hôm nay';
    } else if (difference.inDays == 1) {
      return 'Hôm qua';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ngày trước';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()} tuần trước';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()} tháng trước';
    } else {
      return '${(difference.inDays / 365).floor()} năm trước';
    }
  }
}
