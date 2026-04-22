import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class SwipeButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color? color;
  final VoidCallback onSwiped;
  final bool enabled;

  const SwipeButton({
    super.key,
    required this.label,
    required this.onSwiped,
    this.icon = Icons.arrow_forward_rounded,
    this.color,
    this.enabled = true,
  });

  @override
  State<SwipeButton> createState() => _SwipeButtonState();
}

class _SwipeButtonState extends State<SwipeButton>
    with SingleTickerProviderStateMixin {
  double _dragPosition = 0;
  bool _completed = false;
  late AnimationController _resetController;
  late Animation<double> _resetAnimation;

  static const double _thumbSize = 56;
  static const double _padding = 4;

  double get _maxDrag {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return 200;
    return renderBox.size.width - _thumbSize - _padding * 2;
  }

  Color get _activeColor => widget.color ?? AppColors.primaryOrange;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _resetAnimation =
        Tween<double>(begin: 0, end: 0).animate(CurvedAnimation(
      parent: _resetController,
      curve: Curves.easeOut,
    ));
    _resetController.addListener(() {
      setState(() => _dragPosition = _resetAnimation.value);
    });
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled || _completed) return;
    setState(() {
      _dragPosition =
          (_dragPosition + details.delta.dx).clamp(0.0, _maxDrag);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (!widget.enabled || _completed) return;
    if (_dragPosition >= _maxDrag * 0.85) {
      setState(() {
        _dragPosition = _maxDrag;
        _completed = true;
      });
      HapticFeedback.heavyImpact();
      widget.onSwiped();
      // Reset after callback
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _completed = false;
            _dragPosition = 0;
          });
        }
      });
    } else {
      _resetAnimation =
          Tween<double>(begin: _dragPosition, end: 0).animate(CurvedAnimation(
        parent: _resetController,
        curve: Curves.easeOut,
      ));
      _resetController
        ..reset()
        ..forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _maxDrag > 0 ? (_dragPosition / _maxDrag) : 0.0;

    return Container(
      height: _thumbSize + _padding * 2,
      decoration: BoxDecoration(
        color: widget.enabled
            ? _activeColor.withOpacity(0.12)
            : AppColors.borderGrey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.enabled
              ? _activeColor.withOpacity(0.3)
              : AppColors.borderGrey,
          width: 1.5,
        ),
      ),
      child: Stack(
        children: [
          // Label (fades out as you drag)
          Center(
            child: Opacity(
              opacity: (1.0 - progress * 1.5).clamp(0.0, 1.0),
              child: Padding(
                padding: const EdgeInsets.only(left: 60),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.label,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: widget.enabled
                            ? _activeColor
                            : AppColors.textHint,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.double_arrow_rounded,
                      color: widget.enabled
                          ? _activeColor.withOpacity(0.5)
                          : AppColors.textHint,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Drag thumb
          Positioned(
            left: _padding + _dragPosition,
            top: _padding,
            child: GestureDetector(
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: _onDragEnd,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 50),
                width: _thumbSize,
                height: _thumbSize,
                decoration: BoxDecoration(
                  color: widget.enabled ? _activeColor : AppColors.borderGrey,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: widget.enabled
                      ? [
                          BoxShadow(
                            color: _activeColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(2, 2),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  _completed ? Icons.check_rounded : widget.icon,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
