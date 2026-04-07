import 'package:flutter/material.dart';

class AppChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool compact;
  final int? selectionOrder; // shows badge number when selected

  const AppChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.compact = false,
    this.selectionOrder,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: Material(
            color: isSelected ? Colors.black : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(compact ? 12 : 24),
              side: const BorderSide(color: Colors.black, width: 1),
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(compact ? 12 : 24),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 12 : 16,
                  vertical: compact ? 6 : 10,
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: compact ? 12 : 14,
                  ),
                ),
              ),
            ),
          ),
        ),
        // Selection order badge
        if (isSelected && selectionOrder != null)
          Positioned(
            top: -6,
            right: -6,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 1.5),
              ),
              child: Center(
                child: Text(
                  '$selectionOrder',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
