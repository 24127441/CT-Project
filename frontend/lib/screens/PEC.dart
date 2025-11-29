import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A complete screen for displaying the Personal Equipment Checklist.
class PECScreen extends StatelessWidget {
  // Optional: Accept planData if you want to highlight specific items later
  final Map<String, dynamic>? planData;

  const PECScreen({super.key, this.planData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F2), // Off-white background
      body: SafeArea(
        child: PECContent(planData: planData),
      ),
    );
  }
}

class PECContent extends StatefulWidget {
  final Map<String, dynamic>? planData;
  const PECContent({super.key, this.planData});

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
    this.selected = false, // Default unchecked
    this.quantity = 1,
  });

  factory _EquipmentItem.fromMap(Map<String, dynamic> map) {
    return _EquipmentItem(
      id: map['id'].toString(),
      name: map['name'] as String,
      category: map['category'] as String,
      price: (map['price'] as num).toDouble(),
      imageUrl: map['image_url'] as String? ?? '',
      weightGrams: map['weight_grams'] as int? ?? 0,
    );
  }
}

enum _SortOption { none, lowToHigh, highToLow }

// ----------------- STATE -----------------

class _PECContentState extends State<PECContent> {
  // --- UI Colors from Figma ---
  final Color _primaryGreen = const Color(0xFF4CD964); // Bright Green
  final Color _textBlack = const Color(0xFF1D1D1D);
  final Color _textGray = const Color(0xFF8E8E93);
  final Color _priceRed = const Color(0xFFE02020);
  final Color _bgGray = const Color(0xFFF2F2F7);

  // --- State ---
  late Future<List<_EquipmentItem>> _itemsFuture;
  List<_EquipmentItem> _allEquipment = []; // Stores ALL items across ALL categories
  
  // Hardcoded categories to match Figma Tabs
  final List<String> _categories = <String>[
    'Quần áo',
    'Phụ kiện',
    'Dụng cụ',
    'Thực phẩm',
  ];
  
  int _currentCategoryIndex = 2; // Default to "Dụng cụ"
  _SortOption _sortOption = _SortOption.none;
  
  // Filter State
  double _maxPriceLimit = 5000000; 
  RangeValues _currentPriceRange = const RangeValues(0, 5000000);

  @override
  void initState() {
    super.initState();
    _itemsFuture = _fetchEquipment();
  }

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
            double maxP = loadedItems.map((e) => e.price).reduce(max);
            _maxPriceLimit = maxP;
            _currentPriceRange = RangeValues(0, maxP);
          }
        });
      }
      return loadedItems;
    } catch (e) {
      debugPrint('Error fetching equipment: $e');
      return [];
    }
  }

  // --- UPDATED LOGIC 1: Total Money Calculation ---
  // Calculate based on _allEquipment, NOT just visible items.
  double get _totalMoney => _allEquipment.fold(0, (sum, e) => e.selected ? sum + (e.price * e.quantity) : sum);

  // --- UPDATED LOGIC 2: Select All Logic ---
  // Check if ALL items in the ENTIRE list are selected
  bool get _isAllSelected => _allEquipment.isNotEmpty && _allEquipment.every((e) => e.selected);

  // Toggle ALL items in the ENTIRE list
  void _toggleSelectAll(bool? value) {
    setState(() {
      for (var item in _allEquipment) {
        item.selected = value ?? false;
      }
    });
  }

  // --- Filtering Logic for Display (Keep as is, only affects what user SEES) ---
  List<_EquipmentItem> get _visibleItems {
    if (_allEquipment.isEmpty) return [];
    final String currentCat = _categories[_currentCategoryIndex];
    
    // Filter by Category
    List<_EquipmentItem> filtered = _allEquipment.where((e) {
      bool catMatch = false;
      // Simple string matching logic
      if (currentCat == 'Quần áo') catMatch = e.category.contains('Quần áo') || e.category.contains('Clothing');
      else if (currentCat == 'Phụ kiện') catMatch = e.category.contains('Phụ kiện') || e.category.contains('Accessories');
      else if (currentCat == 'Dụng cụ') catMatch = e.category.contains('Dụng cụ') || e.category.contains('Gear') || e.category.contains('Tools');
      else if (currentCat == 'Thực phẩm') catMatch = e.category.contains('Thực phẩm') || e.category.contains('Food');
      else catMatch = true; 

      // Filter by Price Range
      bool priceMatch = e.price >= _currentPriceRange.start && e.price <= _currentPriceRange.end;
      
      return catMatch && priceMatch;
    }).toList();

    // Sort Logic
    if (_sortOption == _SortOption.lowToHigh) {
      filtered.sort((a, b) => a.price.compareTo(b.price));
    } else if (_sortOption == _SortOption.highToLow) {
      filtered.sort((a, b) => b.price.compareTo(a.price));
    }

    return filtered;
  }

  String _formatCurrency(double value) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0).format(value);
  }

  // ----------------- UI BUILDER -----------------

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
        const SizedBox(height: 10),
        _buildCategoryList(),
        const SizedBox(height: 12),
        _buildFilterBar(),
        const SizedBox(height: 10),
        Expanded(
          // Use FutureBuilder to handle loading state
          child: FutureBuilder<List<_EquipmentItem>>(
            future: _itemsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text("Error: ${snapshot.error}"));
              } else {
                return _buildProductList();
              }
            }
          ),
        ),
        _buildBottomBar(),
      ],
    );
  }

  // ... (Keep _buildHeader, _buildCategoryList, _buildFilterBar same as before) ...

  // 1. HEADER
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Danh sách đồ dùng',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
              ),
            ),
          ),
          const SizedBox(width: 40), 
        ],
      ),
    );
  }

  // 2. CATEGORY TABS
  Widget _buildCategoryList() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final isSelected = index == _currentCategoryIndex;
          return GestureDetector(
            onTap: () => setState(() => _currentCategoryIndex = index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? Colors.black : _bgGray,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                _categories[index],
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // 3. FILTER BAR
  Widget _buildFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: _showPriceFilterModal,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _primaryGreen,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Xem theo giá',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildSortChip('Giá Thấp - Cao', _SortOption.lowToHigh),
          const SizedBox(width: 8),
          _buildSortChip('Giá Cao - Thấp', _SortOption.highToLow),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, _SortOption option) {
    final isSelected = _sortOption == option;
    return GestureDetector(
      onTap: () => setState(() => _sortOption = isSelected ? _SortOption.none : option),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _primaryGreen.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? _primaryGreen : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? _primaryGreen : _textGray,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // 4. PRODUCT LIST
  Widget _buildProductList() {
    final items = _visibleItems; // Get filtered list for display
    
    if (items.isEmpty) {
      return const Center(child: Text("Chưa có sản phẩm nào trong mục này"));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100), 
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))
            ],
          ),
          child: Row(
            children: [
              // Checkbox
              Transform.scale(
                scale: 1.2,
                child: Checkbox(
                  value: item.selected,
                  activeColor: Colors.orange,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  onChanged: (val) {
                    // Changing ONE item updates the total calculation which uses _allEquipment
                    setState(() => item.selected = val!); 
                  },
                ),
              ),
              
              // Image
              Container(
                width: 70,
                height: 70,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade100,
                ),
                child: item.imageUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(item.imageUrl, fit: BoxFit.cover),
                      )
                    : const Center(child: Text("IMG", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
              ),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textBlack)),
                    const SizedBox(height: 4),
                    Text('${item.weightGrams}g', style: TextStyle(fontSize: 13, color: _textGray)),
                    const SizedBox(height: 4),
                    Text(_formatCurrency(item.price), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _priceRed)),
                  ],
                ),
              ),

              // Vertical Quantity Counter
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => setState(() => item.quantity++), // Updates total
                    child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.add, size: 20)),
                  ),
                  Text(
                    '${item.quantity}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  InkWell(
                    onTap: () => setState(() { if(item.quantity > 1) item.quantity--; }), // Updates total
                    child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.remove, size: 20)),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  // 5. BOTTOM SUMMARY BAR
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: Row(
        children: [
          // Select All
          GestureDetector(
            onTap: () => _toggleSelectAll(!_isAllSelected),
            child: Row(
              children: [
                Transform.scale(
                  scale: 1.2,
                  child: Checkbox(
                    value: _isAllSelected, // Checks ALL items status
                    activeColor: Colors.orange,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (val) => _toggleSelectAll(val),
                  ),
                ),
                const Text("Tất cả", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Spacer(),

          // Price Column
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Display Global Total
              Text(_formatCurrency(_totalMoney), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _priceRed)),
            ],
          ),
          const SizedBox(width: 12),

          // Confirm Button
          ElevatedButton(
            onPressed: () {
              // Filter ONLY selected items to save
              final selectedItems = _allEquipment.where((e) => e.selected).toList();
              // Use this list to save to Supabase later
              print("Selected ${selectedItems.length} items for checkout");
              
              // TODO: Navigation to next screen or saving logic
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              elevation: 0,
            ),
            child: const Text("Xác nhận", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
      ),
    );
  }

  // 6. PRICE FILTER MODAL (Keep as is)
  void _showPriceFilterModal() {
    RangeValues tempRange = _currentPriceRange;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Khoảng giá", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _priceBox(_formatCurrency(tempRange.start)),
                    const Text("-", style: TextStyle(fontSize: 20, color: Colors.grey)),
                    _priceBox(_formatCurrency(tempRange.end)),
                  ],
                ),
                const SizedBox(height: 20),
                RangeSlider(
                  values: tempRange,
                  min: 0,
                  max: _maxPriceLimit,
                  activeColor: _primaryGreen,
                  inactiveColor: Colors.grey.shade200,
                  onChanged: (values) {
                    setModalState(() => tempRange = values);
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text("Đóng", style: TextStyle(color: Colors.black)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() => _currentPriceRange = tempRange);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        child: const Text("Xem kết quả", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                )
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _priceBox(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _bgGray,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}