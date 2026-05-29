import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/parcel_controller.dart';
import '../models/parcel_model.dart';
import '../utilities/status_color.dart';
import '../pages/addeditparcel.dart';

class ParcelCard extends StatelessWidget {
  const ParcelCard({super.key, required this.parcel});

  final Parcel parcel;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ParcelController>();
    final theme = Theme.of(context);
    final status = parcel.Status ?? ParcelStatus.pending;
    final statusColor = getStatusColor(status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          if (status == ParcelStatus.pending) {
            Get.to(() => AddEditParcelPage(parcel: parcel));
          } else {
            Get.snackbar(
              'Locked',
              'Only parcels that are still pending can be edited.',
              snackPosition: SnackPosition.BOTTOM,
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          parcel.Document_No ?? 'Unknown Document',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('dd MMM yyyy').format(
                            parcel.Date_sent ?? DateTime.now(),
                          ),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (parcel.receiptPrinted != true)
                    PopupMenuButton<ParcelStatus>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (newStatus) => controller.updateParcelStatus(parcel, newStatus),
                      itemBuilder: (context) {
                        return controller.supportedStatuses
                            .map(
                              (option) => PopupMenuItem<ParcelStatus>(
                                value: option,
                                enabled: option != status,
                                child: Text(controller.statusLabel(option)),
                              ),
                            )
                            .toList();
                      },
                    )
                  else
                    const Icon(Icons.lock, size: 18, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      controller.statusLabel(status),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'KES ',
                    style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildLocationChip(
                      context,
                      label: 'From',
                      value: parcel.From ?? '-',
                      icon: Icons.call_made,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildLocationChip(
                      context,
                      label: 'To',
                      value: parcel.To ?? '-',
                      icon: Icons.call_received,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildContactColumn(
                    context,
                    title: 'Sender',
                    name: parcel.Sender_Name,
                    phone: parcel.Sender_Phone,
                  ),
                  const SizedBox(width: 16),
                  _buildContactColumn(
                    context,
                    title: 'Receiver',
                    name: parcel.Receiver_Name,
                    phone: parcel.Receiver_Phone,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (parcel.Driver?.isNotEmpty == true)
                Row(
                  children: [
                    const Icon(Icons.local_shipping_outlined, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ' • ',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationChip(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactColumn(
    BuildContext context, {
    required String title,
    String? name,
    String? phone,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              name?.isNotEmpty == true ? name! : '-',
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              phone?.isNotEmpty == true ? phone! : '-',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}


