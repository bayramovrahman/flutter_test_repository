import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shaylan_agent/app/app_fonts.dart';
import 'package:shaylan_agent/app/app_colors.dart';
import 'package:shaylan_agent/database/functions/user.dart';
import 'package:shaylan_agent/database/functions/visit_step.dart';
import 'package:shaylan_agent/methods/gridview.dart';
import 'package:shaylan_agent/models/customer.dart';
import 'package:shaylan_agent/models/merchandising.dart';
import 'package:shaylan_agent/models/program_error.dart';
import 'package:shaylan_agent/models/user.dart';
import 'package:shaylan_agent/models/visit.dart';
import 'package:shaylan_agent/models/visit_step.dart';
import 'package:shaylan_agent/screens/full_screen_image_view.dart';
import 'package:shaylan_agent/screens/take_photo_page.dart';
import 'package:shaylan_agent/utilities/alert_utils.dart';
import 'package:shaylan_agent/utilities/photo_utils.dart';
import 'package:shaylan_agent/l10n/app_localizations.dart';
import 'package:shaylan_agent/pages/merchandising/steps/finish_step_page.dart';

class AfterTakePhotoStep extends StatefulWidget {
  final VisitModel visit;
  final Customer customer;
  final Merchandising merchandising;
  final List<ProductGroups>? productGroups;

  const AfterTakePhotoStep({
    super.key,
    required this.visit,
    required this.customer,
    required this.productGroups,
    required this.merchandising,
  });

  @override
  State<AfterTakePhotoStep> createState() => _AfterTakePhotoStepState();
}

class _AfterTakePhotoStepState extends State<AfterTakePhotoStep> {
  // Just empty column

  // final ImagePicker _picker = ImagePicker();
  List<MerchandiserImage> uploadedFiles = [];
  late Merchandising afterMerchandising;

  String visitName = "photosAfterMerchandising";
  String visitDescription = "Merçandaýzingde soňky suratlar";

  @override
  void initState() {
    super.initState();
    afterMerchandising = widget.merchandising;
    _saveDatabase();
  }

  @override
  void dispose() {
    super.dispose();
    _updateDatabase();
  }

  @override
  Widget build(BuildContext context) {
    var lang = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          lang.merchandising,
          style: TextStyle(
            fontFamily: AppFonts.secondaryFont,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 80,
              backgroundColor: Colors.grey,
              backgroundImage: AssetImage('assets/logo/dovran.png'),
            ),
            SizedBox(height: 20.0),
            Text(
              lang.photoAfterMerchandising,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18.0,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
                fontFamily: AppFonts.secondaryFont,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 24.0),
            GestureDetector(
              onTap: () => _takePhotoWithCameraPackage(),
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.grey,
                    style: BorderStyle.solid,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      CupertinoIcons.camera,
                      size: 60.0,
                      color: Colors.grey,
                    ),
                    TextButton(
                      onPressed: () => _takePhotoWithCameraPackage(),
                      child: Text(
                        lang.takePhoto,
                        style: TextStyle(
                          fontFamily: AppFonts.secondaryFont,
                          fontWeight: FontWeight.bold,
                          fontSize: 18.0,
                          color: Colors.blue,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: uploadedFiles.length,
                itemBuilder: (context, index) {
                  final file = uploadedFiles[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              FullScreenImageView(File(file.imagePath!)),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Image.file(
                            File(file.imagePath!),
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  PhotoUtils.getFileName(File(file.imagePath!)),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                FutureBuilder<String>(
                                  future: PhotoUtils.getFileSize(
                                      File(file.imagePath!)),
                                  builder: (context, snapshot) {
                                    return Text('${snapshot.data}');
                                  },
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _onRemoveImage(index),
                            icon: const Icon(Icons.close, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 48.0,
              vertical: 12.0,
            ),
          ),
          onPressed: () {
            if (uploadedFiles.isNotEmpty) {
              navigatorPushMethod(
                context,
                FinishStepPage(
                  visit: widget.visit,
                  customer: widget.customer,
                  productGroups: widget.productGroups,
                  merchandising: afterMerchandising,
                ),
                false,
              );
            } else {
              AlertUtils.showWarningAlert(
                context: context,
                message: "Indiki sahypa geçmezden ozal surata almaly",
                lang: lang,
              );
            }
          },
          child: Text(
            lang.done,
            style: TextStyle(
              fontSize: 18.0,
              color: Colors.white,
              fontFamily: AppFonts.monserratBold,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _takePhotoWithCameraPackage() async {
    User user = await getUser();
    try {
      final photo = await Navigator.push(
        // ignore: use_build_context_synchronously
        context,
        MaterialPageRoute(builder: (context) => TakePhotoPage()),
      );

      if (photo != null) {
        final File photoFile = File(photo);
        final File? compressedPhoto = await PhotoUtils.compressImage(
          photoFile,
          widget.merchandising.empId!,
          widget.merchandising.cardCode!,
        );

        if (compressedPhoto != null) {
          // int compressedSize = await compressedPhoto.length();
          // debugPrint("Compressed Photo Size: ${compressedSize / 1024} KB");
          // final String base64String = await PhotoUtils.getBase64FromFile(compressedPhoto);
          setState(() {
            final newImage = MerchandiserImage(
              merchandiserImageId: 0,
              imagePath: compressedPhoto.path,
              imageName: compressedPhoto.uri.pathSegments.last,
              // encodedImage: base64String,
              beforeAfter: 'after',
            );
            uploadedFiles.add(newImage);
            final updatedMerchandiserImages = List<MerchandiserImage>.from(
                afterMerchandising.merchandiserImages ?? [])
              ..add(newImage);
            afterMerchandising = afterMerchandising.copyWith(
              merchandiserImages: updatedMerchandiserImages,
            );
          });
        }
      }
    } catch (e) {
      ProgramError programError = ProgramError(
          empId: user.empId,
          fromWhere: "Taking 'after' foto",
          happenedAt: DateTime.now().toIso8601String(),
          errorText: "$e");

      ProgramError.sendOrSaveError(programError);
      debugPrint('Error after taking photo: $e');
    }
  }

  /* Future<void> _takePhotoWithImagePicker() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        final File? compressedPhoto = await PhotoUtils.compressImage(
          File(photo.path),
          widget.merchandising.empId!,
          widget.merchandising.cardCode!,
        );
        if (compressedPhoto != null) {
          final bytes = await compressedPhoto.readAsBytes();
          final String base64String = base64Encode(bytes);
          setState(() {
            photoTaken = true;
            final newImage = MerchandiserImage(
              merchandiserImageId: 0,
              imagePath: compressedPhoto.path,
              imageName: compressedPhoto.uri.pathSegments.last,
              encodedImage: base64String,
              beforeAfter: 'after',
            );
            uploadedFiles.add(newImage);

            debugPrint(base64String);

            final updatedMerchandiserImages = List<MerchandiserImage>.from(
                afterMerchandising.merchandiserImages ?? [])
              ..add(newImage);

            afterMerchandising = afterMerchandising.copyWith(
              merchandiserImages: updatedMerchandiserImages,
            );
          });
        }
      }
    } catch (e) {
      debugPrint('Error after taking photo: $e');
    }
  } */

  void _onRemoveImage(int index) {
    setState(() {
      final removedImage = uploadedFiles.removeAt(index);
      afterMerchandising = afterMerchandising.copyWith(
        merchandiserImages: afterMerchandising.merchandiserImages
            ?.where((img) => img.imagePath != removedImage.imagePath)
            .toList(),
      );
    });
  }

  void _saveDatabase() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? visitId = prefs.getInt('visitID');
    int? parentStepId = prefs.getInt('parentStepId');

    VisitStepModel setOrdersStepStarted = VisitStepModel(
      startTime: DateTime.now().toIso8601String(),
      name: visitName,
      visitID: visitId!,
      description: visitDescription,
      parentStepId: parentStepId,
    );
    createVisitStep(setOrdersStepStarted);
  }

  void _updateDatabase() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? visitId = prefs.getInt('visitID');
    String currentTime = DateTime.now().toIso8601String();
    await setEndTimeToVisitStep(visitId!, visitName, currentTime);
  }

  // Just empty column
}
