import 'package:flutter/material.dart';

class CustomNavigationItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isSelected;

  const CustomNavigationItem({
    Key? key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isSelected = false,
  }) : super(key: key);

  @override
  State<CustomNavigationItem> createState() => _CustomNavigationItemState();
}

class _CustomNavigationItemState extends State<CustomNavigationItem> {
  bool _isTapped = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isSelected ? Colors.blue : Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell( // Gunakan InkWell
        onTap: () {
          setState(() {
            _isTapped = !_isTapped;
          });
          widget.onTap();
        },
        borderRadius: BorderRadius.circular(50.0),
        splashColor: Colors.grey.withOpacity(0.3),
        highlightColor: Colors.transparent,
        radius: 150,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: color, size: 24),
              Text(
                widget.label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
