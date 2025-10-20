// ignore_for_file: use_build_context_synchronously, no_leading_underscores_for_local_identifiers

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shaylan_agent/database/functions/user.dart';
import 'package:shaylan_agent/database/functions/visit.dart';
import 'package:shaylan_agent/models/connstring.dart';
import 'package:shaylan_agent/models/merchandising.dart';
import 'package:shaylan_agent/models/new_customer_model.dart';
import 'package:shaylan_agent/models/param.dart';
import 'package:shaylan_agent/models/program_error.dart';
import 'package:shaylan_agent/models/user.dart';
import 'package:shaylan_agent/pages/trader_visits/trader_visits.dart';
import 'package:shaylan_agent/pages/trader_visits/ui/utils/image_cleanup.dart';
import 'package:shaylan_agent/synchronization/synh.dart';
import 'package:shaylan_agent/services/local_database.dart';

class TraderVisitBloc extends Bloc<TraderVisitEvent, TraderVisitState> {
  final Dio dio;

  TraderVisitBloc({required this.dio}) : super(VisitInitial()) {
    Future<void> _uploadImages(
      UploadMerchImages event,
      Emitter<TraderVisitState> emit,
    ) async {
      emit(ImageUploading());

      try {
        Param ipAddress = await getIpAddressRoot();
        FormData formData = FormData();

        for (var image in event.images) {
          final file = File(image['ImagePath']);
          if (!file.existsSync()) {
            debugPrint("File not found: ${file.path}");
            continue;
          }

          final multipartFile = await MultipartFile.fromFile(
            file.path,
            filename: image['ImageName'],
          );

          formData.files.add(MapEntry("images", multipartFile));
        }

        final response = await dio.post(
          "https://${ipAddress.stringVal}/mobileapi/PkoPaymentMobile/merch_images",
          options: Options(headers: {"Authorization": event.token}),
          data: formData,
        );

        if (response.statusCode == 200) {
            List<String> imagePaths = event.images.map((img) => img['ImagePath'] as String).toList();
            await deleteCachedImages(imagePaths);
            
            if (event.visit != null) {
              await setWithNoImagesTo(event.visit!.id!, '');
            }
            emit(ImageUploadSuccess());
          } else {
          User user = await getUser();
          ProgramError programError = ProgramError(
            empId: user.empId,
            fromWhere: "Sending Image",
            happenedAt: DateTime.now().toIso8601String(),
            errorText: "${response.statusCode} cant send image",
          );
          ProgramError.sendOrSaveError(programError);

          emit(ImageUploadFailure("Image upload failed."));
        }
      } catch (error) {
        debugPrint("Upload error: $error");
        emit(ImageUploadFailure("Upload failed: ${error.toString()}"));
      }
    }

    on<LoadVisits>((event, emit) async {
      emit(VisitLoading());
      try {
        final visits = await getAllVisits(
          startTime: event.startTime,
          endTime: event.endTime,
        );

        final sendVisits = visits.where((visit) => visit.status == '' || visit.status == 'send').toList();
        final dontSendVisits = visits.where((visit) => visit.status == 'dont sent' && visit.endTime != '').toList();
        final notFinishedVisits = visits.where((visit) => visit.endTime == '').toList();

        emit(VisitLoaded(
          sendVisits: sendVisits,
          dontSendVisits: dontSendVisits,
          notFinishedVisits: notFinishedVisits,
        ));
      } catch (e) {
        debugPrint('the error is here!');
        emit(VisitError(e.toString()));
      }
    });

    on<LoadRecentVisits>((event, emit) async {
      emit(VisitLoading());
      try {
        final visits = await getRecentVisits(
          startTime: event.startTime,
          endTime: event.endTime,
          limit: event.limit,
        );
        
        final sendVisits = visits.where((visit) => visit.status == '' || visit.status == 'send').toList();
        final dontSendVisits = visits.where((visit) =>  visit.status == 'dont sent' && visit.endTime != '').toList();
        final notFinishedVisits = visits.where((visit) => visit.endTime == '').toList();
        
        emit(RecentVisitsLoaded(
          sendVisits: sendVisits,
          dontSendVisits: dontSendVisits,
          notFinishedVisits: notFinishedVisits,
        ));
      } catch (e) {
        debugPrint('LoadRecentVisits error: $e');
        emit(VisitError(e.toString()));
      }
    });

    on<SendVisit>((event, emit) async {
      try {
        emit(VisitLoading());

        SharedPreferences prefs = await SharedPreferences.getInstance();
        String? token = prefs.getString('authToken');

        final visitSendResult = await sendTraderVisit(event.visit, token!, event.context);
        User user = await getUser();

        //Uploading images
        Merchandising? merchandising =
            await getMerchandising(event.visit.id!, true);
        if (merchandising != null &&
            merchandising.merchandiserImages!.isNotEmpty) {
          String? token = prefs.getString('authToken');
          final data = [];

          for (MerchandiserImage image in merchandising.merchandiserImages!) {
            File imageFile = File(image.imagePath!);
            MultipartFile multipartImage = await MultipartFile.fromFile(
              imageFile.path,
              filename: image.imageName ?? 'image.jpg',
            );

            final jsonImage = {
              "MerchandiserImageId": image.merchandiserImageId ?? 0,
              "ImagePath": image.imagePath,
              "ImageName": image.imageName,
              "BeforeAfter": "before",
              "Merchandiser": null,
              "EncodedImage": multipartImage,
            };
            data.add(jsonImage);
          }
// uploading image with no Event

          if (event.withImage) {
            try {
              Param ipAddress = await getIpAddressRoot();
              FormData formData = FormData();

              for (var image in data) {
                final file = File(image['ImagePath']);
                if (!file.existsSync()) {
                  debugPrint("File not found: ${file.path}");
                  continue;
                }

                final multipartFile = await MultipartFile.fromFile(
                  file.path,
                  filename: image['ImageName'],
                );

                formData.files.add(MapEntry("images", multipartFile));
              }
              dio.interceptors
                  .add(LogInterceptor(requestBody: true, responseBody: true));

              final response = await dio.post(
                "https://${ipAddress.stringVal}/mobileapi/PkoPaymentMobile/merch_images",
                options: Options(
                  headers: {
                    "Authorization": token,
                    "Content-Type": "multipart/form-data",
                  },
                ),
                data: formData,
              );

              debugPrint("the images responce ${response.data}");
              debugPrint("the image responce $response");

                if (response.statusCode == 200) {
                  List<String> imagePaths = data.map((img) => img['ImagePath'] as String).toList();
                  
                  await deleteCachedImages(imagePaths);
                  await setWithNoImagesTo(event.visit.id!, '');
                } else {
                User user = await getUser();
                ProgramError programError = ProgramError(
                  empId: user.empId,
                  fromWhere: "Sending Image",
                  happenedAt: DateTime.now().toIso8601String(),
                  errorText: "${response.statusCode} cant send image",
                );
                ProgramError.sendOrSaveError(programError);

                // emit(ImageUploadFailure("Image upload failed."));
              }
            } catch (error) {
              debugPrint("Upload error: $error");
              // emit(ImageUploadFailure("Upload failed: ${error.toString()}"));
            }
          }

          // traderBloc.add(
          //   UploadMerchImages(
          //       images: data,
          //       token: token!,
          //       visit: visit),
          // );
        }

        debugPrint("visit responce $visitSendResult");

        if (visitSendResult['send'] && visitSendResult['order_created']) {
          String? merchandiserImageStatus = await getWithNoImagesValue(event.visit.id!);

          if (merchandiserImageStatus == 'ok') {
            await setWithNoImagesTo(event.visit.id!, 'true');
          }

          await setStatusToVisit(event.visit.id!, 'send');
          await setStatusToTable(event.visit.id!, 'return_item_body_table', 'send');
          await setStatusToTable(event.visit.id!, 'orders_in_visits', 'send');

          NewCustomer? isVerificationDone =
              await getUpdatedCustomer(event.visit.id!);

          if (!visitSendResult['verification'] && isVerificationDone != null) {
            emit(VisitVerificationWarning("Wizit gitdi! Werifikasiya üstünikli tamamlanmady"));
          } else {
            emit(VisitSendSuccess(visitSendResult['order_created']
                ? "Wizit üstünlikli ugradyldy!"
                : "Sargyt döremedi!!!"));
            add(LoadVisits());
          }
        } else if (!visitSendResult['order_created'] && visitSendResult['send']) {
          if ( event.visit.orderList == null || event.visit.orderList!.isEmpty) {
            await setStatusToVisit(event.visit.id!, 'send');
                    emit(VisitSendSuccess(
                "Sargyt döremedi!!!"));
          }else {
            emit(VisitError("Sargyt döremedi, täzeden ugradyp görüň!!!"));
          }
        } else if (visitSendResult['isTokenExpired']) {
          ProgramError programError = ProgramError(
            empId: user.empId,
            fromWhere: "Sending Visit",
            happenedAt: DateTime.now().toIso8601String(),
            errorText: "token Expired",
          );
          ProgramError.sendOrSaveError(programError);
          emit(VisitError("Ulgamdan çykyň we täzeden giriň"));
        } else if (visitSendResult['timeout']) {
          ProgramError programError = ProgramError(
            empId: user.empId,
            fromWhere: "Sending Visit",
            happenedAt: DateTime.now().toIso8601String(),
            errorText: "Sending TimeOut",
          );
          ProgramError.sendOrSaveError(programError);
          emit(VisitError(
            'Baglanyşyk wagty gutardy. Interneti barlaň.\nBu sahypa täzeden çykyp giriň',
          ));
        } else {
          ProgramError programError = ProgramError(
            empId: user.empId,
            fromWhere: "Sending Visit",
            happenedAt: DateTime.now().toIso8601String(),
            errorText: visitSendResult.toString(),
          );
          ProgramError.sendOrSaveError(programError);
          emit(VisitError("Wizit ugradyp bolmady. Gaýtadan synanyşyň."));
        }
      } catch (e) {
        emit(VisitError('Ulgamdan çykyň we täzeden giriň'));
        debugPrint("----- $e");
      }
    });

    on<UploadMerchImages>(_uploadImages);

    // ignore: unused_element
  }
}
