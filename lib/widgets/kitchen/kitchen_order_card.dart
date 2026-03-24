import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kompak_pos/core/database/app_database.dart';
import 'package:kompak_pos/core/theme/app_colors.dart';
import 'package:kompak_pos/core/theme/app_spacing.dart';
import 'package:kompak_pos/models/enums.dart';

/// A kitchen display card that shows an order's details, its items, elapsed
/// time since creation, and an action button to advance the order status.
///
/// The card header colour depends on the current status:
/// - **confirmed** -- blue ([AppColors.infoBlue])
/// - **preparing** -- amber ([AppColors.warningAmber])
/// - **ready**     -- green ([AppColors.successGreen])
class KitchenOrderCard extends StatefulWidget {
  /// The order record.
  final Order order;

  /// Items belonging to this order.
  final List<OrderItem> items;

  /// Called when the kitchen staff taps the action button, providing the
  /// next [OrderStatus] the order should transition to.
  final ValueChanged<OrderStatus> onStatusUpdate;

  const KitchenOrderCard({
    super.key,
    required this.order,
    required this.items,
    required this.onStatusUpdate,
  });

  @override
  State<KitchenOrderCard> createState() => _KitchenOrderCardState();
}

class _KitchenOrderCardState extends State<KitchenOrderCard> {
  late Timer _elapsedTimer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateElapsed();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _updateElapsed();
    });
  }

  @override
  void didUpdateWidget(covariant KitchenOrderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.createdAt != widget.order.createdAt) {
      _updateElapsed();
    }
  }

  void _updateElapsed() {
    setState(() {
      _elapsed = DateTime.now().difference(widget.order.createdAt);
    });
  }

  @override
  void dispose() {
    _elapsedTimer.cancel();
    super.dispose();
  }

  OrderStatus get _currentStatus {
    for (final status in OrderStatus.values) {
      if (status.name == widget.order.status) return status;
    }
    return OrderStatus.confirmed;
  }

  Color get _headerColor {
    switch (_currentStatus) {
      case OrderStatus.confirmed:
        return AppColors.infoBlue;
      case OrderStatus.preparing:
        return AppColors.warningAmber;
      case OrderStatus.ready:
        return AppColors.successGreen;
      default:
        return AppColors.textSecondary;
    }
  }

  OrderStatus? get _nextStatus {
    switch (_currentStatus) {
      case OrderStatus.confirmed:
        return OrderStatus.preparing;
      case OrderStatus.preparing:
        return OrderStatus.ready;
      case OrderStatus.ready:
        return OrderStatus.completed;
      default:
        return null;
    }
  }

  String get _actionLabel {
    switch (_currentStatus) {
      case OrderStatus.confirmed:
        return 'Start Preparing';
      case OrderStatus.preparing:
        return 'Mark Ready';
      case OrderStatus.ready:
        return 'Complete';
      default:
        return '';
    }
  }

  String _formatElapsed(Duration d) {
    final minutes = d.inMinutes;
    if (minutes < 1) return 'Just now';
    if (minutes < 60) return '${minutes}m ago';
    final hours = d.inHours;
    final remainingMinutes = minutes % 60;
    return '${hours}h ${remainingMinutes}m ago';
  }

  @override
  Widget build(BuildContext context) {
    final nextStatus = _nextStatus;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(15, 0, 0, 0),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Coloured header
          Container(
            color: _headerColor,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                // Order number
                Expanded(
                  child: Text(
                    widget.order.orderNumber,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(50, 255, 255, 255),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _currentStatus.label,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Elapsed time
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.md,
              top: AppSpacing.sm,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  _formatElapsed(_elapsed),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _elapsed.inMinutes > 15
                        ? AppColors.errorRed
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Items list
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.items.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quantity
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceGrey,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${item.quantity}x',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      // Product name and optional notes
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.productName,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (item.notes != null &&
                                item.notes!.isNotEmpty) ...[
                              Text(
                                item.notes!,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                  color: AppColors.textHint,
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          // Order notes
          if (widget.order.notes != null &&
              widget.order.notes!.isNotEmpty) ...[
            const Divider(
              height: 1,
              color: AppColors.dividerGrey,
              indent: AppSpacing.md,
              endIndent: AppSpacing.md,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.note_alt_outlined,
                    size: 14,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      widget.order.notes!,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Action button
          if (nextStatus != null) ...[
            const Divider(height: 1, color: AppColors.dividerGrey),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => widget.onStatusUpdate(nextStatus),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _headerColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm + 2,
                    ),
                  ),
                  child: Text(
                    _actionLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
