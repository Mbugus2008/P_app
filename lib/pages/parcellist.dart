import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trimline_parcel/pages/addeditparcel.dart';
import 'package:trimline_parcel/pages/send.dart';
import 'package:trimline_parcel/pages/parcel_dashboard_page.dart';
import 'package:trimline_parcel/widgets/parcel_card.dart';
import '../models/parcel_model.dart';
import '../controllers/parcel_controller.dart';


class ParcelListPage extends StatefulWidget {
  const ParcelListPage({Key? key}) : super(key: key);

  @override
  _ParcelListPageState createState() => _ParcelListPageState();
}

class _ParcelListPageState extends State<ParcelListPage> {
  final ParcelController _parcelController = Get.find<ParcelController>();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _parcelController.setSearchQuery(_searchController.text);
  }

  void _showStatusFilterDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('Filter by Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusFilterOption(null, 'All Statuses'),
            ...ParcelStatus.values.map(
              (status) => _buildStatusFilterOption(
                status,
                _parcelController.statusLabel(status),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _buildStatusFilterOption(ParcelStatus? status, String label) {
    return Obx(() {
      final isSelected = _parcelController.statusFilter == status;
      return ListTile(
        title: Text(label),
        leading: Radio<ParcelStatus?>(
          value: status,
          groupValue: _parcelController.statusFilter,
          onChanged: (value) {
            _parcelController.setStatusFilter(value);
            Get.back();
          },
        ),
        onTap: () {
          _parcelController.setStatusFilter(status);
          Get.back();
        },
        tileColor: isSelected ? Colors.blue.withOpacity(0.1) : null,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parcel List'),
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard_customize_outlined),
            onPressed: () => Get.to(() => const ParcelDashboardPage()),
          ),
          IconButton(
            icon: const Icon(Icons.filter_alt),
            onPressed: _showStatusFilterDialog,
          ),
          Obx(
            () => IconButton(
              icon: const Icon(Icons.refresh),
              onPressed:
                  _parcelController.isLoading
                      ? null
                      : _parcelController.loadParcels,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: Card(
              color: Colors.blue,
              margin: const EdgeInsets.all(8.0),

              child: TextButton(
                onPressed: () => Get.to(() => Send()),
                child: const Text(
                  'Send Parcel',
                  style: TextStyle(color: Colors.white, fontSize: 24),
                ),
              ),
            ),
          ),

          SizedBox(
            width: double.infinity,
            child: Card(
              color: Colors.green,
              margin: const EdgeInsets.all(8.0),
              child: TextButton(
                onPressed: () => Get.to(() => ReceiveParcelListPage()),
                child: const Text(
                  'Receive Parcel',
                  style: TextStyle(color: Colors.white, fontSize: 24),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(1.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search parcels...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ),

          Obx(() {
            if (_parcelController.isLoading) {
              return const Expanded(
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (_parcelController.filteredParcels.isEmpty) {
              return const Expanded(
                child: Center(child: Text('No parcels found')),
              );
            }

            return Expanded(
              child: ListView.builder(
                itemCount: _parcelController.filteredParcels.length,
                itemBuilder: (context, index) {
                  final parcel = _parcelController.filteredParcels[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: ParcelCard(parcel: parcel),
                  );
                },
              ),
            );
          }),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          Get.snackbar(
            "Please wait",
            "Creating parcel...",
            showProgressIndicator: true,
            snackPosition: SnackPosition.BOTTOM,
          );
          Parcel parcel = await _parcelController.newparcel();
          Get.closeCurrentSnackbar();
          final result = await Get.to(() => AddEditParcelPage(parcel: parcel));
          if (result == true) {
            _parcelController.loadParcels();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}



