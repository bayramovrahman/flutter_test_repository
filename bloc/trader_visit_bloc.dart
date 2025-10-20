// Business Logic Component (BLoC) for managing trader visits
// Handles all business logic for loading, sending, and uploading visit data

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
import 'package:shaylan_agent/synchronization/synh.dart';
import 'package:shaylan_agent/services/local_database.dart';

class TraderVisitBloc extends Bloc<TraderVisitEvent, TraderVisitState> {
  final Dio dio; // HTTP client for API requests

  // Initialize the BLoC with VisitInitial state
  TraderVisitBloc({required this.dio}) : super(VisitInitial()) {
    
    // Handler for uploading merchandising images to server
    Future<void> _uploadImages(
      UploadMerchImages event,
      Emitter<TraderVisitState> emit,
    ) async {
      // Emit loading state to show progress indicator
      emit(ImageUploading());

      try {
        // Get server IP address from database
        Param ipAddress = await getIpAddressRoot();
        
        // Create FormData for multipart/form-data upload
        FormData formData = FormData();

        // Loop through each image and add to FormData
        for (var image in event.images) {
          // Get the file from the path stored in database
          final file = File(image['ImagePath']);
          
          // Check if file actually exists on device
          if (!file.existsSync()) {
            debugPrint("File not found: ${file.path}");
            continue; // Skip this image if not found
          }

          // Convert file to MultipartFile for upload
          final multipartFile = await MultipartFile.fromFile(
            file.path,
            filename: image['ImageName'],
          );

          // Add to form data with key "images"
          formData.files.add(
            MapEntry("images", multipartFile)
          );
        }

        // Send POST request to upload images
        final response = await dio.post(
          "https://${ipAddress.stringVal}/mobileapi/PkoPaymentMobile/merch_images",
          options: Options(
            headers: {"Authorization": event.token} // Auth token for security
          ),
          data: formData,
        );

        // Check if upload was successful
        if (response.statusCode == 200) {
          // Clear the "withNoImages" flag in database if visit provided
          if (event.visit != null) {
            await setWithNoImagesTo(event.visit!.id!, '');
          }
          // Emit success state
          emit(ImageUploadSuccess());
        } else {
          // Upload failed - log error to database
          User user = await getUser();
          ProgramError programError = ProgramError(
            empId: user.empId,
            fromWhere: "Sending Image",
            happenedAt: DateTime.now().toIso8601String(),
            errorText: "${response.statusCode} cant send image",
          );
          ProgramError.sendOrSaveError(programError);

          // Emit failure state
          emit(ImageUploadFailure("Image upload failed."));
        }
      } catch (error) {
        // Handle any exceptions during upload
        debugPrint("Upload error: $error");
        emit(ImageUploadFailure("Upload failed: ${error.toString()}"));
      }
    }

    // Handler for loading all visits from database
    on<LoadVisits>((event, emit) async {
      // Show loading indicator
      emit(VisitLoading());
      
      try {
        // Fetch all visits from database with optional date filters
        final visits = await getAllVisits(
          startTime: event.startTime,
          endTime: event.endTime,
        );

        // Filter visits into three categories:
        // 1. Sent visits (status is empty or 'send')
        final sendVisits = visits
            .where((visit) => 
              visit.status == '' || 
              visit.status == 'send'
            )
            .toList();
        
        // 2. Not sent visits (status is 'dont sent' and has end time)
        final dontSendVisits = visits
            .where((visit) => 
              visit.status == 'dont sent' && 
              visit.endTime != ''
            )
            .toList();
        
        // 3. Unfinished visits (no end time set)
        final notFinishedVisits = visits
            .where((visit) => 
              visit.endTime == ''
            )
            .toList();

        // Emit loaded state with categorized visits
        emit(VisitLoaded(
          sendVisits: sendVisits,
          dontSendVisits: dontSendVisits,
          notFinishedVisits: notFinishedVisits,
        ));
      } catch (e) {
        // Handle errors during visit loading
        debugPrint('the error is here!');
        emit(VisitError(e.toString()));
      }
    });

    // Handler for loading recent visits with limit
    on<LoadRecentVisits>((event, emit) async {
      emit(VisitLoading());
      
      try {
        // Fetch limited number of recent visits
        final visits = await getRecentVisits(
          startTime: event.startTime,
          endTime: event.endTime,
          limit: event.limit, // Default is 50 visits
        );
        
        // Categorize visits same as LoadVisits
        final sendVisits = visits
            .where((visit) => 
              visit.status == '' || 
              visit.status == 'send'
            )
            .toList();
        
        final dontSendVisits = visits
            .where((visit) => 
              visit.status == 'dont sent' && 
              visit.endTime != ''
            )
            .toList();
        
        final notFinishedVisits = visits
            .where((visit) => 
              visit.endTime == ''
            )
            .toList();
        
        // Emit with different state to distinguish from LoadVisits
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

    // Main handler for sending visits to server
    on<SendVisit>((event, emit) async {
      try {
        emit(VisitLoading());

        // Get authentication token from SharedPreferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        String? token = prefs.getString('authToken');

        // Send visit data to server
        final visitSendResult = await sendTraderVisit(
          event.visit, 
          token!, 
          event.context
        );
        
        // Get current user for error logging
        User user = await getUser();

        // Handle image uploading if visit includes merchandising
        Merchandising? merchandising = await getMerchandising(
          event.visit.id!, 
          true // Load with images
        );
        
        // If merchandising has images, prepare them for upload
        if (merchandising != null &&
            merchandising.merchandiserImages!.isNotEmpty) {
          
          String? token = prefs.getString('authToken');
          final data = [];

          // Convert each image to MultipartFile
          for (MerchandiserImage image in merchandising.merchandiserImages!) {
            File imageFile = File(image.imagePath!);
            
            MultipartFile multipartImage = await MultipartFile.fromFile(
              imageFile.path,
              filename: image.imageName ?? 'image.jpg',
            );

            // Create JSON structure for each image
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

          // Upload images directly if withImage flag is true
          if (event.withImage) {
            try {
              // Get server IP
              Param ipAddress = await getIpAddressRoot();
              FormData formData = FormData();

              // Add all images to FormData
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

                formData.files.add(
                  MapEntry("images", multipartFile)
                );
              }
              
              // Add logging interceptor for debugging
              dio.interceptors.add(
                LogInterceptor(
                  requestBody: true, 
                  responseBody: true
                )
              );

              // Upload images to server
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

              // Handle upload response
              if (response.statusCode == 200) {
                // Clear image flag on success
                await setWithNoImagesTo(event.visit.id!, '');
              } else {
                // Log error on failure
                ProgramError programError = ProgramError(
                  empId: user.empId,
                  fromWhere: "Sending Image",
                  happenedAt: DateTime.now().toIso8601String(),
                  errorText: "${response.statusCode} cant send image",
                );
                ProgramError.sendOrSaveError(programError);
              }
            } catch (error) {
              debugPrint("Upload error: $error");
            }
          }
        }

        debugPrint("visit responce $visitSendResult");

        // Process visit send result and update database accordingly
        if (visitSendResult['send'] && visitSendResult['order_created']) {
          // Visit and order sent successfully
          
          // Check merchandiser image status
          String? merchandiserImageStatus = await getWithNoImagesValue(
            event.visit.id!
          );

          // Set flag if images need to be uploaded separately
          if (merchandiserImageStatus == 'ok') {
            await setWithNoImagesTo(event.visit.id!, 'true');
          }

          // Update visit status to 'send' in database
          await setStatusToVisit(event.visit.id!, 'send');
          
          // Update related tables status
          await setStatusToTable(
            event.visit.id!, 
            'return_item_body_table', 
            'send'
          );
          await setStatusToTable(
            event.visit.id!, 
            'orders_in_visits', 
            'send'
          );

          // Check if customer verification was included
          NewCustomer? isVerificationDone = await getUpdatedCustomer(
            event.visit.id!
          );

          // Show appropriate message based on verification status
          if (!visitSendResult['verification'] && isVerificationDone != null) {
            emit(VisitVerificationWarning(
              "Wizit gitdi! Werifikasiya üstünikli tamamlanmady"
            ));
          } else {
            emit(VisitSendSuccess(
              visitSendResult['order_created']
                ? "Wizit üstünlikli ugradyldy!"
                : "Sargyt döremedi!!!"
            ));
            // Reload visits to refresh UI
            add(LoadVisits());
          }
        } 
        // Visit sent but order not created
        else if (!visitSendResult['order_created'] && visitSendResult['send']) {
          // If no order was supposed to be created, mark as sent
          if (event.visit.orderList == null || 
              event.visit.orderList!.isEmpty) {
            await setStatusToVisit(event.visit.id!, 'send');
            emit(VisitSendSuccess("Sargyt döremedi!!!"));
          } else {
            // Order should have been created but failed
            emit(VisitError("Sargyt döremedi, täzeden ugradyp görüň!!!"));
          }
        } 
        // Token expired error
        else if (visitSendResult['isTokenExpired']) {
          ProgramError programError = ProgramError(
            empId: user.empId,
            fromWhere: "Sending Visit",
            happenedAt: DateTime.now().toIso8601String(),
            errorText: "token Expired",
          );
          ProgramError.sendOrSaveError(programError);
          emit(VisitError("Ulgamdan çykyň we täzeden giriň"));
        } 
        // Network timeout error
        else if (visitSendResult['timeout']) {
          ProgramError programError = ProgramError(
            empId: user.empId,
            fromWhere: "Sending Visit",
            happenedAt: DateTime.now().toIso8601String(),
            errorText: "Sending TimeOut",
          );
          ProgramError.sendOrSaveError(programError);
          emit(VisitError(
            'Baglanyşyk wagty gutardy. Interneti barlaň.\n'
            'Bu sahypa täzeden çykyp giriň',
          ));
        } 
        // General error
        else {
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
        // Catch any unexpected errors
        emit(VisitError('Ulgamdan çykyň we täzeden giriň'));
        debugPrint("----- $e");
      }
    });

    // Register the upload images handler
    on<UploadMerchImages>(_uploadImages);
  }
}