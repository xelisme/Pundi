import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../utils/app_colors.dart';

/// Compact "METODE PEMBAYARAN" selector.
///
/// Shared by the income form, the expense form and the Riwayat edit dialog so
/// all three stay visually identical and stay in sync with [paymentMethods].
/// Adding a method to that list is the only change needed to surface it
/// everywhere.
class PaymentMethodField extends StatelessWidget {
  /// Current value. Must be one of [paymentMethods], otherwise the dropdown
  /// asserts — callers pass `defaultPaymentMethod` when unset.
  final String value;
  final ValueChanged<String> onChanged;

  const PaymentMethodField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // A method imported from a CSV may be something this build doesn't know
    // about. Surface it as-is instead of silently rewriting it to the default
    // and dropping it from the list (which would also trip DropdownButton's
    // value-must-be-an-item assertion).
    final options = paymentMethods.contains(value)
        ? paymentMethods
        : [...paymentMethods, value];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 20),
          items: options
              .map((method) => DropdownMenuItem(
                    value: method,
                    child: Text(
                      method,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                    ),
                  ))
              .toList(),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ),
    );
  }
}

/// The "METODE PEMBAYARAN" label that sits above [PaymentMethodField].
class PaymentMethodLabel extends StatelessWidget {
  const PaymentMethodLabel({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'METODE PEMBAYARAN',
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.textTertiary,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w500,
          ),
    );
  }
}