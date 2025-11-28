import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A complete screen for displaying the Personal Equipment Checklist.
/// Use it like this:
/// Navigator.push(context, MaterialPageRoute(builder: (_) => const PECScreen()));
class PECScreen extends StatelessWidget {
  const PECScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF8F6F2),
      body: SafeArea(child: PECContent()),
    );
  }
}

/// The main content widget for the PEC screen.
/// Can be embedded in an existing Scaffold.
class PECContent extends StatefulWidget {
  const PECContent({super.key});

  @override
  State<PECContent> createState() => _PECContentState();
}

// ----------------- MODEL -----------------

class _EquipmentItem {
  final String id;
  final String name;
  final String category;
  final double price;
  final String imageUrl;
  final int weightGrams;
  bool selected;
  int quantity;

  _EquipmentItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.imageUrl,
    required this.weightGrams,
    this.selected = false,
    this.quantity = 1,
  });

  factory _EquipmentItem.fromMap(Map<String, dynamic> map) {
    return _EquipmentItem(
      id: map['id'].toString(),
      name: map['name'] as String,
      category: map['category'] as String,
      // Safely handle price as num (int or double) and convert to double
      price: (map['price'] as num).toDouble(),
      imageUrl: map['image_url'] as String? ?? '', // Handle potential null
      weightGrams: map['weight_grams'] as int? ?? 0, // Handle potential null
    );
  }
}

enum _SortOption { none, lowToHigh, highToLow }

// ----------------- STATE -----------------

class _PECContentState extends State<PECContent> {
  // --- UI Constants & Theme ---
  final Color _primaryGreen = const Color(0xFF35C759);
  final Color _scaffoldBg = const Color(0xFFF8F6F2);
  final Color _chipBg = const Color(0xFFEFEFEF);
  final Color _redPrice = const Color(0xFFE53935);

  // --- State Variables ---
  late Future<List<_EquipmentItem>> _itemsFuture;
  List<_EquipmentItem> _allEquipment = [];
  final List<String> _categories = <String>[
    'Quần áo',
    'Phụ kiện',
    'Dụng cụ',
    'Thực phẩm',
  ];
  int _currentCategory = 0;
  _SortOption _sortOption = _SortOption.none;
  bool _isPriceFilterVisible = false;
  double _maxPrice = 1000000; // Default max, will be updated
  late RangeValues _priceRange;
  late RangeValues _tempPriceRange;

  @override
  void initState() {
    super.initState();
    _priceRange = RangeValues(0, _maxPrice);
    _tempPriceRange = RangeValues(0, _maxPrice);
    _itemsFuture = _fetchEquipment();
  }

  // --- Data Fetching ---
  Future<List<_EquipmentItem>> _fetchEquipment() async {
    try {
      final response = await Supabase.instance.client.from('equipment').select();
      final List<_EquipmentItem> loadedItems = response
          .map<_EquipmentItem>((item) => _EquipmentItem.fromMap(item))
          .toList();
      
      if (mounted) {
        setState(() {
          _allEquipment = loadedItems;
          if (loadedItems.isNotEmpty) {
            // Dynamically set the max price for the slider
            final maxPriceFromData = loadedItems.map((e) => e.price).reduce(max);
            _maxPrice = maxPriceFromData > 0 ? maxPriceFromData : _maxPrice;
            _priceRange = RangeValues(0, _maxPrice);
            _tempPriceRange = RangeValues(0, _maxPrice);
          }
        });
      }
      return loadedItems;
    } catch (e) {
      if (mounted) {
        debugPrint('Error fetching equipment: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải dữ liệu: $e')),
        );
      }
      return [];
    }
  }

  // --- Calculation Getters ---
  List<_EquipmentItem> get _visibleItems {
    final String cat = _categories[_currentCategory];
    final double min = _priceRange.start;
    final double max = _priceRange.end;

    final List<_EquipmentItem> list = _allEquipment
        .where((e) => e.category == cat && e.price >= min && e.price <= max)
        .toList();

    if (_sortOption == _SortOption.lowToHigh) {
      list.sort((a, b) => a.price.compareTo(b.price));
    } else if (_sortOption == _SortOption.highToLow) {
      list.sort((a, b) => b.price.compareTo(a.price));
    }
    return list;
  }

  double get _totalMoney {
    return _allEquipment.fold(0.0, (sum, item) {
      return item.selected ? sum + (item.price * item.quantity) : sum;
    });
  }

  int get _saving => (_totalMoney * 0.12).round(); // Demo saving

  bool get _allSelected {
    final visible = _visibleItems;
    if (visible.isEmpty) return false;
    return visible.every((e) => e.selected);
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      for (final _EquipmentItem e in _visibleItems) {
        e.selected = value ?? false;
      }
    });
  }

  String _formatCurrency(num value) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(value);
  }

  // ----------------- UI BUILD -----------------
  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _buildHeader(context),
        const SizedBox(height: 12),
        _buildCategoryTabs(),
        const SizedBox(height: 12),
        _buildFilterRow(),
        if (_isPriceFilterVisible) _buildPriceFilterCard(),
        const SizedBox(height: 8),
        Expanded(
          child: FutureBuilder<List<_EquipmentItem>>(
            future: _itemsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && _allEquipment.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Lỗi: ${snapshot.error}'));
              } else if (_visibleItems.isEmpty) {
                return const Center(child: Text('Không có vật dụng nào phù hợp.'));
              }

              return Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 110),
                      itemCount: _visibleItems.length,
                      itemBuilder: (BuildContext context, int index) {
                        return _buildEquipmentTile(_visibleItems[index]);
                      },
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: _buildBottomBar(),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // ----------------- UI WIDGETS -----------------

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: <Widget>[
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () {
              if (Navigator.of(context).canPop()) Navigator.of(context).pop();
            },
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            ),
          ),
          const Expanded(
            child: Text(
              'Danh sách đồ dùng',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 44), // To balance the back button
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final bool selected = index == _currentCategory;
          return GestureDetector(
            onTap: () => setState(() => _currentCategory = index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? Colors.black : _chipBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  _categories[index],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: <Widget>[
          _primaryChip(
            label: 'Xem theo giá',
            onTap: () => setState(() {
              _isPriceFilterVisible = !_isPriceFilterVisible;
              if (_isPriceFilterVisible) _tempPriceRange = _priceRange;
            }),
          ),
          const SizedBox(width: 8),
          _secondaryChip(
            label: 'Giá Thấp - Cao',
            selected: _sortOption == _SortOption.lowToHigh,
            onTap: () => setState(() => _sortOption = _SortOption.lowToHigh),
          ),
          const SizedBox(width: 8),
          _secondaryChip(
            label: 'Giá Cao - Thấp',
            selected: _sortOption == _SortOption.highToLow,
            onTap: () => setState(() => _sortOption = _SortOption.highToLow),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPriceFilterCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _priceDisplayBox(_formatCurrency(_tempPriceRange.start))),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Text('-', style: TextStyle(fontSize: 18)),
              ),
              Expanded(child: _priceDisplayBox(_formatCurrency(_tempPriceRange.end))),
            ],
          ),
          const SizedBox(height: 8),
          RangeSlider(
            values: _tempPriceRange,
            min: 0,
            max: _maxPrice,
            activeColor: _primaryGreen,
            onChanged: (values) => setState(() => _tempPriceRange = values),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _secondaryChip(
                  label: 'Đóng',
                  selected: false,
                  onTap: () => setState(() => _isPriceFilterVisible = false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _primaryChip(
                  label: 'Xem kết quả',
                  onTap: () => setState(() {
                    _priceRange = _tempPriceRange;
                    _isPriceFilterVisible = false;
                  }),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
  
  Widget _priceDisplayBox(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: _scaffoldBg,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  Widget _primaryChip({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: _primaryGreen,
          borderRadius: BorderRadius.circular(22),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
    );
  }

  Widget _secondaryChip({required String label, required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? _primaryGreen.withOpacity(0.1) : _chipBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: selected ? _primaryGreen : Colors.grey.shade300),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? _primaryGreen : Colors.black87,
            fontWeight: FontWeight.w600, fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildEquipmentTile(_EquipmentItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Checkbox(
            value: item.selected,
            onChanged: (bool? value) => setState(() => item.selected = value ?? false),
            activeColor: Colors.orange,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            visualDensity: VisualDensity.standard,
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: item.imageUrl.isNotEmpty
                          ? Image.network(
                              item.imageUrl,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                              },
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
                              ),
                            )
                          : Container(
                              color: _primaryGreen.withOpacity(0.1),
                              alignment: Alignment.center,
                              child: const Text('PNG', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('${item.weightGrams}g', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                        const SizedBox(height: 6),
                        Text(_formatCurrency(item.price), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _redPrice)),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      InkWell(child: const Icon(Icons.add), onTap: () => setState(() => item.quantity++)),
                      Text(item.quantity.toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      InkWell(child: const Icon(Icons.remove), onTap: () => setState(() {
                        if (item.quantity > 1) item.quantity--;
                      })),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Checkbox(
            value: _allSelected,
            onChanged: _toggleSelectAll,
            activeColor: Colors.orange,
          ),
          const Text('Tất cả', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const Spacer(),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatCurrency(_totalMoney),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _redPrice),
              ),
              if (_saving > 0)
                Text(
                  'Tiết kiệm ${_formatCurrency(_saving)}',
                  style: TextStyle(fontSize: 13, color: _primaryGreen, fontWeight: FontWeight.w600),
                ),
            ],
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () { /* TODO: Handle confirmation */ },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Xác nhận', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
