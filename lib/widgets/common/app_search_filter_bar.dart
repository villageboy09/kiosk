import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cropsync/theme/app_theme.dart';

/// Standardized, reusable search input and category chip selector bar
class AppSearchFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final String hintText;
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;
  final String Function(String category)? categoryLabelBuilder;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onClearSearch;

  const AppSearchFilterBar({
    super.key,
    required this.searchController,
    required this.hintText,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
    this.categoryLabelBuilder,
    this.onSearchChanged,
    this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Input Field
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF6B7280), size: 22),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF9CA3AF)),
                      onPressed: () {
                        searchController.clear();
                        onClearSearch?.call();
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
        if (categories.isNotEmpty) ...[
          const SizedBox(height: 12),
          // Horizontal Category Chips
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final isSelected = category == selectedCategory;
                final label = categoryLabelBuilder != null
                    ? categoryLabelBuilder!(category)
                    : category;

                return Padding(
                  padding: EdgeInsets.only(
                    right: 8,
                    left: index == 0 ? 0 : 0,
                  ),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onCategorySelected(category);
                    },
                    borderRadius: BorderRadius.circular(100),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primary : Colors.white,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: isSelected ? AppTheme.primary : const Color(0xFFE5E7EB),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
