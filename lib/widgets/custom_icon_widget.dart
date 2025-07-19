import 'package:flutter/material.dart';

class CustomIconWidget extends StatelessWidget {
  final String iconName;
  final Color? color;
  final double? size;

  const CustomIconWidget({
    super.key,
    required this.iconName,
    this.color,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    IconData iconData = _getIconData(iconName);
    return Icon(
      iconData,
      color: color,
      size: size,
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'search':
        return Icons.search;
      case 'more_vert':
        return Icons.more_vert;
      case 'push_pin':
        return Icons.push_pin;
      case 'push_pin_outlined':
        return Icons.push_pin_outlined;
      case 'volume_off':
        return Icons.volume_off;
      case 'volume_up':
        return Icons.volume_up;
      case 'person':
        return Icons.person;
      case 'delete':
        return Icons.delete;
      case 'mark_email_read':
        return Icons.mark_email_read;
      case 'archive':
        return Icons.archive;
      case 'settings':
        return Icons.settings;
      case 'clear':
        return Icons.clear;
      default:
        return Icons.help_outline;
    }
  }
}
