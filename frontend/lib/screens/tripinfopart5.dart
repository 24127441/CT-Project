// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// debugPrint is provided by material.dart; no separate foundation import needed
import 'package:provider/provider.dart';
import 'package:frontend/utils/notification.dart';
import 'package:frontend/utils/logger.dart';
import '../providers/trip_provider.dart';
import '../services/supabase_db_service.dart';
import '../screens/home_screen.dart';
import 'trip_info_waiting_screen.dart';

class TripConfirmScreen extends StatefulWidget {
  const TripConfirmScreen({super.key});
  @override
  State<TripConfirmScreen> createState() => _TripConfirmScreenState();
}

class _TripConfirmScreenState extends State<TripConfirmScreen> {
  final TextEditingController _tripNameController = TextEditingController();

  // Màu sắc theo thiết kế cũ của bạn
  final Color primaryGreen = const Color(0xFF425E3C);
  final Color darkGreen = const Color(0xFF425E3C);
  final Color cardBackground = const Color(0xFFC8D7C8);

  @override
  void initState() {
    super.initState();
    final tripData = context.read<TripProvider>();
    _tripNameController.text = tripData.tripName;
  }
  @override
  void dispose() { _tripNameController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final tripData = context.watch<TripProvider>();
    String displayDate = 'Chưa chọn';
    if (tripData.startDate != null && tripData.endDate != null) {
      String start = DateFormat('dd/MM/yyyy').format(tripData.startDate!);
      String end = DateFormat('dd/MM/yyyy').format(tripData.endDate!);
      displayDate = '$start - $end (${tripData.durationDays} ngày)';
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () async {
            print('🟢 [TripConfirmScreen] Back button pressed, canceling draft plan if exists...');
            final tripProvider = Provider.of<TripProvider>(context, listen: false);
            await tripProvider.cancelDraftPlan();
            print('🟢 [TripConfirmScreen] ✅ Draft plan canceled, navigating to home');
            if (context.mounted) {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const HomePage()));
            }
          },
        ),
        title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Thông tin chuyến đi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              Text('Bước 5/5', style: TextStyle(color: Colors.white70, fontSize: 14))
            ]
        ),
        backgroundColor: darkGreen, elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 10),
            const Text('Xác nhận thông tin', style: TextStyle(color: Colors.redAccent, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Hãy kiểm tra lại kĩ thông tin trước khi xác nhận!', style: TextStyle(color: Colors.black54, fontSize: 14)),
            const SizedBox(height: 24),

            Align(alignment: Alignment.centerLeft, child: const Text('Đặt tên cho chuyến đi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            const SizedBox(height: 8),
            TextField(
              controller: _tripNameController,
              onChanged: (value) => context.read<TripProvider>().setTripName(value),
              decoration: InputDecoration(
                hintText: 'Ví dụ: Chuyến đi săn mây Tà Xùa',
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.green)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.green)),
                filled: true,
                fillColor: const Color(0xFFF9FFF9),
              ),
            ),

            const SizedBox(height: 24),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: cardBackground, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade400)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryItem('Địa điểm', tripData.searchLocation.isEmpty ? 'Chưa chọn' : tripData.searchLocation),
                  _buildSummaryItem('Thời gian', displayDate),
                  _buildSummaryItem('Loại hình ngủ nghỉ', tripData.accommodation ?? 'Chưa chọn'),
                  _buildSummaryItem('Số người', tripData.paxGroup ?? 'Chưa chọn'),
                  _buildSummaryItem('Độ khó', tripData.difficultyLevel ?? 'Chưa chọn'),
                  if (tripData.selectedInterests.isNotEmpty)
                    Padding(padding: const EdgeInsets.only(top: 8.0), child: _buildSummaryItem('Sở thích', tripData.selectedInterests.join(', '))),
                  if (tripData.note.isNotEmpty)
                    Padding(padding: const EdgeInsets.only(top: 8.0), child: _buildSummaryItem('Ghi chú', tripData.note)),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),

      // --- PHẦN NÀY ĐÃ ĐƯỢC QUAY VỀ GIAO DIỆN CŨ ---
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // 1. Nút Back nhỏ bên trái
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0,1))]),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.black87),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(width: 12),

            // 2. Nút "Lưu mẫu này" (Màu trắng, chữ đen) - ĐÃ GẮN LOGIC MỚI
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  try {
                    // Lấy tên từ ô nhập liệu
                    String tName = _tripNameController.text.isEmpty ? "Mẫu mới" : _tripNameController.text;

                    // Check if template name already exists
                    final supabaseDb = SupabaseDbService();
                    final exists = await supabaseDb.checkHistoryInputNameExists(tName);
                    
                    if (exists && context.mounted) {
                      // Show warning dialog
                      final shouldOverwrite = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Tên mẫu đã tồn tại'),
                          content: Text('Mẫu "$tName" đã tồn tại. Bạn có muốn tạo mẫu khác với tên này không?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Hủy'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('Tiếp tục lưu'),
                            ),
                          ],
                        ),
                      );
                      
                      if (shouldOverwrite != true) return;
                    }

                    // Hiện thông báo đang xử lý
                    if (context.mounted) {
                      NotificationService.showInfo('Đang lưu mẫu...', duration: const Duration(milliseconds: 800));
                    }

                    // GỌI PROVIDER (Logic đúng đã fix)
                    if (context.mounted) {
                      await context.read<TripProvider>().saveHistoryInput(tName);
                    }

                    // Thông báo thành công
                    if (context.mounted) {
                      NotificationService.showSuccess('✅ Đã lưu mẫu thành công!');
                    }
                  } catch (e) {
                    if (context.mounted) {
                      NotificationService.showError('Lỗi: $e');
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
                    elevation: 1
                ),
                child: const Text('Lưu mẫu này', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),

            const SizedBox(width: 12),

            // 3. Nút "Xác nhận" (Màu xanh) - CHỈ CHUYỂN TRANG
            Expanded(
              child: ElevatedButton(
                  onPressed: () async {
                    try {
                      print('\n🟢🟢🟢 [TripConfirmScreen] === "Xác nhận" button pressed ===');
                      final isMounted = mounted;
                      AppLogger.d('TripConfirmScreen', '=== "Xác nhận" button pressed ===');
                      
                      // Get trip provider
                      final tripProvider = Provider.of<TripProvider>(context, listen: false);
                      
                      // Validate all required fields
                      print('🟢 [TripConfirmScreen] Validating required fields...');
                      
                      // 1. Check trip name
                      if (tripProvider.tripName.isEmpty) {
                        print('🟢 [TripConfirmScreen] ❌ Trip name is empty');
                        if (isMounted) NotificationService.showError('Vui lòng đặt tên cho chuyến đi');
                        return;
                      }
                      print('🟢 [TripConfirmScreen] ✅ Trip name: ${tripProvider.tripName}');
                      
                      // 2. Check location
                      if (tripProvider.searchLocation.isEmpty) {
                        print('🟢 [TripConfirmScreen] ❌ Location is empty');
                        if (isMounted) NotificationService.showError('Vui lòng chọn điểm đến (Bước 1)');
                        return;
                      }
                      print('🟢 [TripConfirmScreen] ✅ Location: ${tripProvider.searchLocation}');
                      
                      // 3. Check dates
                      if (tripProvider.startDate == null || tripProvider.endDate == null) {
                        print('🟢 [TripConfirmScreen] ❌ Dates are missing');
                        if (isMounted) NotificationService.showError('Vui lòng chọn thời gian chuyến đi (Bước 2)');
                        return;
                      }
                      print('🟢 [TripConfirmScreen] ✅ Dates: ${tripProvider.startDate} - ${tripProvider.endDate}');
                      
                      // 4. Check difficulty level
                      if (tripProvider.difficultyLevel == null || tripProvider.difficultyLevel!.isEmpty) {
                        print('🟢 [TripConfirmScreen] ❌ Difficulty level is missing');
                        if (isMounted) NotificationService.showError('Vui lòng chọn cấp độ (Bước 3)');
                        return;
                      }
                      print('🟢 [TripConfirmScreen] ✅ Difficulty: ${tripProvider.difficultyLevel}');
                      
                      // 5. Check accommodation
                      if (tripProvider.accommodation == null || tripProvider.accommodation!.isEmpty) {
                        print('🟢 [TripConfirmScreen] ❌ Accommodation is missing');
                        if (isMounted) NotificationService.showError('Vui lòng chọn loại chỗ nghỉ (Bước 1)');
                        return;
                      }
                      print('🟢 [TripConfirmScreen] ✅ Accommodation: ${tripProvider.accommodation}');
                      
                      // 6. Check group size
                      if (tripProvider.paxGroup == null || tripProvider.paxGroup!.isEmpty) {
                        print('🟢 [TripConfirmScreen] ❌ Group size is missing');
                        if (isMounted) NotificationService.showError('Vui lòng chọn số lượng người (Bước 1)');
                        return;
                      }
                      print('🟢 [TripConfirmScreen] ✅ Group size: ${tripProvider.paxGroup}');
                      
                      print('🟢 [TripConfirmScreen] ✅ All validations passed!');
                      AppLogger.d('TripConfirmScreen', 'All required fields are valid');

                      // Check if plan name already exists
                      AppLogger.d('TripConfirmScreen', 'Checking if plan name exists: ${tripProvider.tripName}');
                      final supabaseDb = SupabaseDbService();
                      final exists = await supabaseDb.checkPlanNameExists(tripProvider.tripName);
                      AppLogger.d('TripConfirmScreen', 'Plan name exists check result: $exists');
                      
                      if (exists) {
                        AppLogger.d('TripConfirmScreen', 'Plan with this name already exists');
                        if (!isMounted) return;
                        // Show warning dialog
                        final shouldContinue = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Tên chuyến đi đã tồn tại'),
                            content: const Text('Bạn có muốn tạo chuyến đi khác với tên này không?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: const Text('Hủy'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                child: const Text('Tiếp tục tạo'),
                              ),
                            ],
                          ),
                        );
                        
                        // If user cancels or closes dialog, don't proceed
                        if (shouldContinue != true) {
                          AppLogger.d('TripConfirmScreen', 'User cancelled dialog or selected "Hủy"');
                          return;
                        }
                        AppLogger.d('TripConfirmScreen', 'User selected "Tiếp tục tạo"');
                      }

                      // Save draft plan BEFORE navigating to WaitingScreen
                      print('🟢 [TripConfirmScreen] Saving draft plan before route selection...');
                      AppLogger.d('TripConfirmScreen', 'Saving draft plan before route selection...');
                      
                      await tripProvider.saveTripRequest();
                      
                      print('🟢 [TripConfirmScreen] Draft plan saved successfully');
                      AppLogger.d('TripConfirmScreen', 'Draft plan saved successfully');

                      // Capture mounted before async gap
                      final isMountedAfterDialogs = mounted;
                      
                      // Navigate to route selection
                      if (!isMountedAfterDialogs) return;
                      
                      print('🟢 [TripConfirmScreen] Navigating to WaitingScreen...');
                      AppLogger.d('TripConfirmScreen', 'Navigating to WaitingScreen...');
                      
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const WaitingScreen()),
                      );
                      
                      print('🟢 [TripConfirmScreen] Returned from WaitingScreen, result: $result');
                      AppLogger.d('TripConfirmScreen', 'Returned from WaitingScreen');
                      
                      // Check if route was confirmed
                      if (tripProvider.routeConfirmed) {
                        print('🟢 [TripConfirmScreen] ✅ Route was confirmed, draft plan kept');
                      } else {
                        print('🟢 [TripConfirmScreen] ⚠️ User returned without confirming route (draft plan kept for now)');
                      }
                    } catch (e) {
                      AppLogger.e('TripConfirmScreen', 'Error in onPressed: ${e.toString()}');
                      if (mounted) NotificationService.showError('Không thể bắt đầu tìm lộ trình: $e');
                    }
                  },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen, // Đảm bảo biến primaryGreen đã được import/khai báo
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 2,
                ),
                child: const Text(
                  'Xác nhận',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Padding(padding: const EdgeInsets.only(bottom: 12.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 15)), const SizedBox(height: 2), Text(value, style: TextStyle(color: Colors.grey.shade700, fontSize: 15, height: 1.3))]));
  }
}