// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:trimline_parcel/models/Parcel_Details.dart';
// import '../models/parcel_model.dart';
// import '../controllers/parcel_controller.dart';
// import 'package:intl/intl.dart';

// typedef PaymentResponsibility = WhoToPay;

// class AddEditParcelPage extends StatelessWidget {
//   final Parcel? parcel;
//   late final ParcelController controller = Get.find<ParcelController>();

//   AddEditParcelPage({super.key, this.parcel}) {
//     controller.parcel = parcel;
//     if (parcel != null) {
//       controller.PopulateFormWithParcel(parcel!);
//     }
//   }

//   void _showSnackBar(
//     String title,
//     String message, {
//     Color backgroundColor = Colors.green,
//   }) {
//     Get.snackbar(
//       title,
//       message,
//       snackPosition: SnackPosition.BOTTOM,
//       backgroundColor: backgroundColor,
//       duration: const Duration(seconds: 3),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: _buildAppBar(),
//       floatingActionButton: _buildFloatingActionButton(context),
//       body: SafeArea(
//         child: LayoutBuilder(
//           builder: (context, constraints) => SingleChildScrollView(
//             padding: EdgeInsets.only(
//               left: 2,
//               right: 2,
//               top: 2,
//               bottom: MediaQuery.of(context).viewInsets.bottom + 2,
//             ),
//             child: ConstrainedBox(
//               constraints: BoxConstraints(minHeight: constraints.maxHeight),
//               child: Form(
//                 key: controller.formKey,
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.stretch,
//                   children: [
//                     Obx(() => _buildStepper()),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   AppBar _buildAppBar() {
//     return AppBar(
//       title: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             controller.documentNoController.text,
//             style: const TextStyle(
//               fontSize: 16,
//               fontWeight: FontWeight.bold,
//               color: Colors.blue,
//             ),
//           ),
//           Text(
//             DateFormat('dd-MMM-yyyy').format(controller.selectedDate),
//             style: const TextStyle(fontSize: 14, color: Colors.blue),
//           ),
//         ],
//       ),
//     );
//   }

//   FloatingActionButton _buildFloatingActionButton(BuildContext context) {
//     return FloatingActionButton.extended(
//       onPressed: () {
//         if (controller.formKey.currentState!.validate()) {
//           _submitForm();
//         }
//       },
//       label: Text(controller.parcel != null ? 'Update' : 'Save'),
//       icon: Icon(controller.parcel != null ? Icons.update : Icons.save),
//       backgroundColor: Theme.of(context).primaryColor,
//     );
//   }

//   Widget _buildStepper() {
//     return Stepper(
//       type: StepperType.vertical,
//       currentStep: controller.currentStep.value,
//       onStepTapped: (step) => controller.currentStep.value = step,
//       onStepContinue: _onStepContinue,
//       steps: [
//         _buildParcelInformationStep(),
//         _buildSenderStep(),
//         _buildReceiverStep(),
//         _buildDeliveryStep(),
//         _buildDetailsStep(),
//       ],
//     );
//   }

//   void _onStepContinue() {
//     if (controller.currentStep.value < 4) {
//       controller.currentStep.value++;
//     } else {
//       if (controller.formKey.currentState!.validate()) {
//         _submitForm();
//       }
//     }
//   }

//   Step _buildParcelInformationStep() {
//     return Step(
//       title: const Text(
//         'Parcel Information',
//         style: TextStyle(
//           color: Colors.blue,
//           fontSize: 24,
//         ),
//       ),
//       subtitle: Obx(() => _buildParcelInformationSubtitle()),
//       content: Column(
//         children: [
//           Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Expanded(
//                 child: _buildTextField(
//                   controller: controller.amountPaidController,
//                   label: 'Amount Paid',
//                   isRequired: true,
//                   error: controller.parcelinformationError,
//                   keyboardType: TextInputType.number,
//                   decoration: const InputDecoration(prefixText: 'Ksh '),
//                 ),
//               ),
//               const SizedBox(width: 16),
//               Transform.scale(
//                 scale: 2.0,
//                 child: Checkbox(
//                   value: controller.paid,
//                   onChanged: (bool? newValue) {
//                     controller.paid = newValue ?? false;
//                   },
//                 ),
//               ),
//               const Text('Paid'),
//             ],
//           ),
//           _buildTextField(
//             controller: controller.fromController,
//             label: 'From (Location)',
//             prefixIcon: Icons.location_on,
//             isRequired: true,
//             error: controller.parcelinformationError,
//           ),
//           const SizedBox(height: 8),
//           _buildTextField(
//             controller: controller.toController,
//             label: 'To (Destination)',
//             error: controller.parcelinformationError,
//             prefixIcon: Icons.location_on,
//             isRequired: true,
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildParcelInformationSubtitle() {
//     if (controller.parcelinformationError?.value != null) {
//       return Text(
//         controller.parcelinformationError?.value ?? '',
//         style: const TextStyle(color: Colors.red),
//       );
//     }
    
//     return Row(
//       children: [
//         Text(
//           controller.paid ? 'Paid' : 'Not Paid',
//           style: const TextStyle(
//             fontSize: 16,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         const Spacer(),
//         Text(
//           'Ksh ${controller.amountPaidController.text ?? 0}',
//           style: const TextStyle(
//             fontSize: 16,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         const Spacer(),
//         Text(
//           controller.toController.text,
//           style: const TextStyle(
//             fontSize: 16,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//       ],
//     );
//   }

//   Step _buildSenderStep() {
//     return Step(
//       title: const Text(
//         'Sender',
//         style: TextStyle(
//           color: Colors.blue,
//           fontSize: 24,
//         ),
//       ),
//       subtitle: Obx(() => _buildSenderSubtitle()),
//       content: Column(
//         crossAxisAlignment: CrossAxisAlignment.stretch,
//         children: [
//           const SizedBox(height: 2),
//           _buildTextField(
//             controller: controller.senderNameController,
//             error: controller.senderinformationError,
//             label: 'Sender Name',
//             prefixIcon: Icons.person,
//             isRequired: true,
//           ),
//           Row(
//             children: [
//               Expanded(
//                 child: _buildTextField(
//                   controller: controller.senderPhoneController,
//                   label: 'Sender Phone',
//                   isRequired: true,
//                   prefixIcon: Icons.phone,
//                 ),
//               ),
//               const SizedBox(width: 8),
//               Expanded(
//                 child: _buildTextField(
//                   controller: controller.senderIdController,
//                   label: 'ID No',
//                   prefixIcon: Icons.person,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//         ],
//       ),
//     );
//   }

//   Widget _buildSenderSubtitle() {
//     if (controller.senderinformationError?.value != null) {
//       return Text(
//         controller.senderinformationError!.value,
//         style: const TextStyle(color: Colors.red),
//       );
//     }
    
//     return Row(
//       children: [
//         Text(
//           ' ${controller.parcel?.Sender_Name ?? ''}',
//           style: const TextStyle(
//             fontSize: 16,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         const Spacer(),
//         Text(
//           controller.parcel?.Sender_Phone ?? '',
//           style: const TextStyle(
//             fontSize: 16,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//       ],
//     );
//   }

//   Step _buildReceiverStep() {
//     return Step(
//       title: const Text(
//         'Receiver',
//         style: TextStyle(
//           color: Colors.blue,
//           fontSize: 24,
//         ),
//       ),
//       subtitle: Obx(() => _buildReceiverSubtitle()),
//       content: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             const SizedBox(height: 8),
//             _buildTextField(
//               controller: controller.receiverNameController,
//               error: controller.receiverinformationError,
//               label: 'Receiver Name',
//               prefixIcon: Icons.person,
//               isRequired: true,
//             ),
//             const SizedBox(height: 8),
//             Row(
//               children: [
//                 Expanded(
//                   child: _buildTextField(
//                     controller: controller.receiverPhoneController,
//                     label: 'Receiver Phone',
//                     prefixIcon: Icons.phone,
//                     isRequired: true,
//                     keyboardType: TextInputType.phone,
//                   ),
//                 ),
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: _buildTextField(
//                     controller: controller.receiverIdController,
//                     label: 'ID No',
//                     prefixIcon: Icons.person,
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 8),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildReceiverSubtitle() {
//     if (controller.receiverinformationError?.value != null) {
//       return Text(
//         controller.receiverinformationError!.value,
//         style: const TextStyle(color: Colors.red),
//       );
//     }
    
//     return Row(
//       children: [
//         Text(
//           ' ${controller.parcel?.Receiver_Name ?? ''}',
//           style: const TextStyle(
//             fontSize: 16,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         const Spacer(),
//         Text(
//           controller.parcel?.Receiver_Phone ?? '',
//           style: const TextStyle(
//             fontSize: 16,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//       ],
//     );
//   }

//   Step _buildDeliveryStep() {
//     return Step(
//       title: const Text(
//         'Delivery',
//         style: TextStyle(
//           color: Colors.blue,
//           fontSize: 24,
//         ),
//       ),
//       subtitle: Obx(() => _buildDeliverySubtitle()),
//       content: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             const SizedBox(height: 8),
//             _buildTextField(
//               controller: controller.vehicleController,
//               error: controller.deliveryinformationError,
//               label: 'Vehicle Number *',
//               prefixIcon: Icons.directions_car,
//               isRequired: true,
//             ),
//             const SizedBox(height: 20),
//             _buildTextField(
//               controller: controller.driverController,
//               label: 'Driver',
//               prefixIcon: Icons.person,
//               isRequired: true,
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildDeliverySubtitle() {
//     if (controller.deliveryinformationError?.value != null) {
//       return Text(
//         controller.deliveryinformationError!.value,
//         style: const TextStyle(color: Colors.red),
//       );
//     }
    
//     return Row(
//       children: [
//         Text(
//           ' ${controller.parcel?.Driver ?? ''}',
//           style: const TextStyle(
//             fontSize: 16,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         const Spacer(),
//         Text(
//           controller.parcel?.Vehicle ?? '',
//           style: const TextStyle(
//             fontSize: 16,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//       ],
//     );
//   }

//   Step _buildDetailsStep() {
//     return Step(
//       title: const Text(
//         'Details',
//         style: TextStyle(
//           color: Colors.blue,
//           fontSize: 24,
//         ),
//       ),
//       subtitle: Obx(() => _buildDetailsSubtitle()),
//       content: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const SizedBox(height: 20),
//           IconButton(
//             onPressed: () {
//               controller.addParcelDetail();
//             },
//             icon: const Icon(Icons.add),
//             color: Colors.blue,
//           ),
//           _buildParcelDetailsList(),
//         ],
//       ),
//     );
//   }

//   Widget _buildDetailsSubtitle() {
//     if (controller.deliveryinformationError?.value != null) {
//       return Text(
//         controller.deliveryinformationError!.value,
//         style: const TextStyle(color: Colors.red),
//       );
//     }
    
//     final itemCount = controller.parcel?.parcelDetails?.length ?? 0;
//     final totalAmount = controller.parcel?.parcelDetails?.fold(
//           0.0, 
//           (sum, parcel) => sum + (parcel.Amount ?? 0.0)
//         ) ?? 0.0;
    
//     return Row(
//       children: [
//         Text(
//           '$itemCount item(s)',
//           style: const TextStyle(
//             fontSize: 16,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         const Spacer(),
//         Text(
//           'KES $totalAmount',
//           style: const TextStyle(
//             fontSize: 16,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildParcelDetailsList() {
//     final details = controller.parcel?.parcelDetails;
//     if (details == null || details.isEmpty) {
//       return const Center(
//         child: Text('No parcel details added'),
//       );
//     }
    
//     return SizedBox(
//       height: 300,
//       child: ListView.builder(
//         itemCount: details.length,
//         itemBuilder: (context, index) {
//           final parcelDetail = details[index];
//           return _buildParcelDetailCard(context, parcelDetail, index);
//         },
//       ),
//     );
//   }

//   Widget _buildParcelDetailCard(BuildContext context, Parcel_Details parcelDetail, int index) {
//     return Card(
//       elevation: 2,
//       child: ListTile(
//         title: Row(
//           children: [
//             SizedBox(
//               height: 80,
//               width: MediaQuery.of(context).size.width * 0.4,
//               child: SingleChildScrollView(
//                 scrollDirection: Axis.vertical,
//                 child: Text(
//                   parcelDetail.Description ?? "No Description",
//                   style: const TextStyle(fontSize: 16),
//                 ),
//               ),
//             ),
//             const Spacer(),
//             Text(parcelDetail.Amount?.toString() ?? "0.0"),
//             const Spacer(),
//           ],
//         ),
//         trailing: IconButton(
//           icon: const Icon(Icons.delete, color: Colors.red),
//           onPressed: () {
//             //controller.removeParcelDetail(index);
//           },
//         ),
//         onTap: () => _showEditParcelDetailDialog(context, parcelDetail, index),
//       ),
//     );
//   }

//   Future<void> _showEditParcelDetailDialog(
//       BuildContext context, Parcel_Details parcelDetail, int index) async {
//     final descCtrl = TextEditingController(text: parcelDetail.Description);
//     final amountCtrl = TextEditingController(text: parcelDetail.Amount?.toString());
//     final remarksCtrl = TextEditingController(text: parcelDetail.Remarks);

//     await showDialog(
//       context: context,
//       builder: (ctx) => Dialog(
//         insetPadding: EdgeInsets.zero,
//         child: SizedBox(
//           width: MediaQuery.of(context).size.width,
//           height: MediaQuery.of(context).size.height,
//           child: Scaffold(
//             appBar: AppBar(title: const Text("Edit Parcel Detail")),
//             body: Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: SingleChildScrollView(
//                 child: Column(
//                   children: [
//                     TextField(
//                       controller: descCtrl,
//                       maxLines: null,
//                       minLines: 3,
//                       decoration: const InputDecoration(labelText: "Description"),
//                     ),
//                     TextField(
//                       controller: amountCtrl,
//                       decoration: const InputDecoration(labelText: "Amount"),
//                       keyboardType: TextInputType.number,
//                     ),
//                     TextField(
//                       controller: remarksCtrl,
//                       decoration: const InputDecoration(labelText: "Remarks"),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//             bottomNavigationBar: Padding(
//               padding: const EdgeInsets.all(8.0),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.end,
//                 children: [
//                   TextButton(
//                     onPressed: () => Navigator.pop(ctx),
//                     child: const Text("Cancel"),
//                   ),
//                   ElevatedButton(
//                     onPressed: () {
//                       // controller.updateParcelDetail(
//                       //   index,
//                       //   descCtrl.text,
//                       //   double.tryParse(amountCtrl.text) ?? 0.0,
//                       //   remarksCtrl.text,
//                       // );
//                       Navigator.pop(ctx);
//                     },
//                     child: const Text("Save"),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildTextField({
//     required TextEditingController controller,
//     required String label,
//     bool isRequired = false,
//     TextInputType keyboardType = TextInputType.text,
//     bool readOnly = false,
//     InputDecoration? decoration,
//     IconData? prefixIcon,
//     RxString? error,
//   }) {
//     final fieldKey = GlobalKey<FormFieldState>();
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 8.0),
//       child: ValueListenableBuilder<TextEditingValue>(
//         valueListenable: controller,
//         builder: (context, value, _) {
//           final bool isEmpty = value.text.isEmpty;
//           final Color borderColor = isEmpty && isRequired
//               ? Colors.red.shade300
//               : Colors.green.shade300;
//           final Color iconColor = isEmpty && isRequired ? Colors.red : Colors.green;
//           final Color labelColor = isEmpty && isRequired
//               ? Colors.red.shade800
//               : Colors.green.shade800;

//           return TextFormField(
//             key: fieldKey,
//             textAlign: TextAlign.center,
//             controller: controller,
//             keyboardType: keyboardType,
//             readOnly: readOnly,
//             decoration: decoration ??
//                 InputDecoration(
//                   labelText: label,
//                   labelStyle: TextStyle(color: labelColor),
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(8),
//                     borderSide: BorderSide(color: borderColor, width: 1.5),
//                   ),
//                   prefixIcon: Icon(prefixIcon, color: iconColor),
//                   suffix: isRequired
//                       ? const Text('*', style: TextStyle(color: Colors.red))
//                       : null,
//                   enabledBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(8),
//                     borderSide: BorderSide(color: borderColor, width: 1.5),
//                   ),
//                 ),
//             onEditingComplete: () {
//               fieldKey.currentState?.validate();
//             },
//             validator: isRequired
//                 ? (value) {
//                     error?.value = "";
//                     if (value?.isEmpty ?? true) {
//                       error?.value = '$label field is required';
//                       return '$label field is required';
//                     }
//                     return null;
//                   }
//                 : null,
//           );
//         },
//       ),
//     );
//   }

//   void _submitForm() async {
//     try {
//       final parcel = Parcel(
//         Document_No: controller.documentNoController.text,
//         Date_sent: controller.selectedDate,
//         Sender_Name: controller.senderNameController.text,
//         Sender_ID: controller.senderIdController.text,
//         Sender_Phone: controller.senderPhoneController.text,
//         From: controller.fromController.text,
//         To: controller.toController.text,
//         Receiver_Name: controller.receiverNameController.text,
//         Receiver_ID: controller.receiverIdController.text,
//         Receiver_Phone: controller.receiverPhoneController.text,
//         Status: controller.selectedStatus,
//         Driver: controller.driverController.text,
//         Vehicle: controller.vehicleController.text,
//         Who_to_Pay: controller.paymentResponsibility,
//         Amount_Paid: double.tryParse(controller.amountPaidController.text) ?? 0.0,
//         Paid: controller.paid,
//         Date_Collected: controller.parcel?.Date_Collected,
//         Date_Delivered: controller.parcel?.Date_Delivered,
//         parcelDetails: controller.parcel?.parcelDetails,
//       );

//       if (controller.parcel != null) {
//         controller.updateParcel(parcel);
//         _showSnackBar('Success', 'Parcel updated successfully!');
//       } else {
//         controller.addParcel(parcel);
//         _showSnackBar('Success', 'Parcel added successfully!');
//         controller.formKey.currentState?.reset();
//       }

//       await Future.delayed(const Duration(seconds: 1));
//       Get.back();
//     } catch (e) {
//       _showSnackBar(
//         'Error',
//         'Failed to save parcel: $e',
//         backgroundColor: Colors.red,
//       );
//     }
//   }
// }
