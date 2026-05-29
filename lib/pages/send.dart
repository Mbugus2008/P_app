import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trimline_parcel/controllers/parcel_controller.dart';
import 'package:trimline_parcel/widgets/parcel_card.dart';

class Send extends StatelessWidget {
   Send({Key? key}) : super(key: key);
final ParcelController _parcelController = Get.find<ParcelController>();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ListView.builder(
          itemCount: _parcelController.parcels.length,
          itemBuilder: (context, index) {
            return ParcelCard(
              parcel: _parcelController.parcels[index],
            );
          },
        ),
      ),
    );
  }
} 
class ReceiveParcelListPage extends StatelessWidget {
   ReceiveParcelListPage({Key? key}) : super(key: key);
final ParcelController _parcelController = Get.find<ParcelController>();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ListView.builder(
          itemCount: _parcelController.parcels.length,
          itemBuilder: (context, index) {
            return ParcelCard(
              parcel: _parcelController.parcels[index],
            );
          },
        ),
      ),
    );
  }
}
