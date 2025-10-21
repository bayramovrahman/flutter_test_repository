import 'dart:io';
import 'package:dio/dio.dart';
import 'package:iconly/iconly.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shaylan_agent/app/app_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shaylan_agent/database/functions/visit.dart';
import 'package:shaylan_agent/l10n/app_localizations.dart';
import 'package:shaylan_agent/database/functions/customer.dart';
import 'package:shaylan_agent/methods/gridview.dart';
import 'package:shaylan_agent/models/customer.dart';
import 'package:shaylan_agent/models/merchandising.dart';
import 'package:shaylan_agent/models/orderforserver.dart';
import 'package:shaylan_agent/models/visit.dart';
import 'package:shaylan_agent/pages/items_list_page/items_list_view.dart';
import 'package:shaylan_agent/pages/trader_visits/bloc/trader_visit_bloc.dart';
import 'package:shaylan_agent/pages/trader_visits/bloc/trader_visit_event.dart';
import 'package:shaylan_agent/pages/trader_visits/bloc/trader_visit_state.dart';
import 'package:shaylan_agent/screens/full_screen_image_view.dart';
import 'package:shaylan_agent/services/local_database.dart';

class TorgowyyViewVisitPage extends StatefulWidget {
  final VisitModel visit;

  const TorgowyyViewVisitPage({super.key, required this.visit});

  @override
  State<TorgowyyViewVisitPage> createState() => _TorgowyyViewVisitPageState();
}

class _TorgowyyViewVisitPageState extends State<TorgowyyViewVisitPage> {
  OrderForServer? order;
  Merchandising? merchandising;
  String? imagePath;
  int selectedTabIndex = 0;
  String? orderStatus;
  bool isLoadingMerchandising = true;
  bool isSendingPhotos = false;

  @override
  void initState() {
    super.initState();
    _loadImagePath();
    _fetchOrder();
    _fetchMerchandising();
  }

  Future<void> _loadImagePath() async {
    final directory = await getApplicationDocumentsDirectory();
    setState(() {
      imagePath = directory.path;
    });
  }

  Future<void> _fetchOrder() async {
    final result = await getOrder(widget.visit.id!);
    final status = await getOrderStatus(widget.visit.id!);
    setState(() {
      order = result;
      orderStatus = status;
    });
  }

  double calculateTotalSum() {
    if (order == null || order!.orderItems.isEmpty) return 0.0;
    double total = order!.orderItems.fold(0.0, (sum, item) {
      return sum + (item.itemCountForOrder * double.parse(item.price));
    });

    return double.parse(total.toStringAsFixed(2));
  }

  Future<void> _fetchMerchandising() async {
    try {
      final result = await getMerchandising(widget.visit.id!, true);
      setState(() {
        merchandising = result;
        isLoadingMerchandising = false;
      });
    } catch (e) {
      debugPrint('Error fetching merchandising: $e');
      setState(() {
        isLoadingMerchandising = false;
      });
    }
  }

  Future<void> _sendPhotos() async {
    if (merchandising == null || merchandising!.merchandiserImages == null || merchandising!.merchandiserImages!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No photos to send')),
      );
      return;
    }

    setState(() {
      isSendingPhotos = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('authToken');

      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Authentication token not found')),
        );
        setState(() {
          isSendingPhotos = false;
        });
        return;
      }

      final data = [];
      for (MerchandiserImage image in merchandising!.merchandiserImages!) {
        File imageFile = File(image.imagePath!);
        if (!imageFile.existsSync()) {
          debugPrint("File not found: ${image.imagePath}");
          continue;
        }

        MultipartFile multipartImage = await MultipartFile.fromFile(
          imageFile.path,
          filename: image.imageName ?? 'image.jpg',
        );

        final jsonImage = {
          "MerchandiserImageId": image.merchandiserImageId ?? 0,
          "ImagePath": image.imagePath,
          "ImageName": image.imageName,
          "BeforeAfter": image.beforeAfter ?? "before",
          "Merchandiser": null,
          "EncodedImage": multipartImage,
        };
        data.add(jsonImage);
      }

      if (data.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No valid images found')),
        );
        setState(() {
          isSendingPhotos = false;
        });
        return;
      }

      // Trigger the upload event
      context.read<TraderVisitBloc>().add(
        UploadMerchImages(
          images: data,
          token: token,
          visit: widget.visit,
        ),
      );
    } catch (e) {
      debugPrint('Error preparing photos for upload: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error preparing photos: $e')),
      );
      setState(() {
        isSendingPhotos = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var lang = AppLocalizations.of(context)!;

    return BlocListener<TraderVisitBloc, TraderVisitState>(
      listener: (context, state) {
        if (state is ImageUploadSuccess) {
          setState(() {
            isSendingPhotos = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Photos uploaded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh merchandising data
          _fetchMerchandising();
        } else if (state is ImageUploadFailure) {
          setState(() {
            isSendingPhotos = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error),
              backgroundColor: Colors.red,
            ),
          );
        } else if (state is ImageUploading) {
          setState(() {
            isSendingPhotos = true;
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              IconlyLight.arrow_left_circle,
              size: 28.0.r,
              color: Colors.white,
            ),
          ),
          title: Text(
            lang.informationVisit,
            style: TextStyle(
              fontSize: 18.0.sp,
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontFamily: AppFonts.monserratBold,
            ),
          ),
          actions: orderStatus == 'dont send'
              ? [
                  IconButton(
                    onPressed: () async {
                      Customer customer =
                          await getCustomerByCardCode(widget.visit.cardCode);
                      List<OrderForServer> orderList = [];
                      orderList.add(order!);
                      VisitModel visitModel =
                          widget.visit.copyWith(orderList: orderList);
                      navigatorPushMethod(
                        context,
                        ItemListView(
                          visit: visitModel,
                          customer: customer,
                          editingCurrentOrder: true,
                          productGroup: order!.orderItems.first.productGroupId,
                          mmlList: [],
                          editBeforeSend: true,
                        ),
                        false,
                      );
                    },
                    icon: Icon(Icons.edit_sharp),
                    color: Colors.white,
                  )
                ]
              : [],
          centerTitle: true,
          backgroundColor: Colors.blue,
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (order != null && order!.orderItems.isNotEmpty)
                  ExpansionTile(
                    title: Text(
                      lang.ordersList,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: AppFonts.monserratBold,
                      ),
                    ),
                    initiallyExpanded: true,
                    children: [
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0.r),
                        ),
                        elevation: 4,
                        child: Column(
                          children: [
                            ...order!.orderItems.map((item) {
                              final totalPrice = item.itemCountForOrder *
                                  double.parse(item.price);
                              return ListTile(
                                leading: imagePath != null
                                    ? Image.file(
                                        File('$imagePath/${item.picturName}'),
                                        width: 50,
                                        height: 100,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Icon(
                                            Icons.no_photography,
                                            size: 40,
                                          );
                                        },
                                      )
                                    : const Icon(Icons.image, size: 40),
                                title: Text(
                                  item.itemName,
                                  maxLines: 2,
                                  style: TextStyle(
                                    fontSize: 10.0.sp,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: AppFonts.monserratBold,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "${lang.orderhistoryitemprice}: ${item.price} ${lang.manat}",
                                      style: TextStyle(
                                        fontSize: 10.0.sp,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: AppFonts.secondaryFont,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      "${lang.total}: ${item.itemCountForOrder} ${lang.quantityforItems}",
                                      style: TextStyle(
                                        fontSize: 10.0.sp,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: AppFonts.secondaryFont,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Text(
                                  "${totalPrice.toStringAsFixed(2)}\n${lang.manat}",
                                  style: TextStyle(
                                    fontSize: 10.0.sp,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: AppFonts.secondaryFont,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              );
                            })
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                order == null
                                    ? SizedBox.shrink()
                                    : Flexible(
                                      child: Text(
                                          "${lang.paymentOption}: ${switch (order!.groupNum) {
                                            -1 => lang.cashPayment,
                                            5 => lang.enumeration,
                                            1 => lang.sevenCredit,
                                            2 => lang.fourteenCredit,
                                            3 => lang.thirtyCredit,
                                            _ => 'Töleg görnüşi saýlanmady',
                                          }}",
                                          style: TextStyle(
                                            fontSize: 12.0.sp,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: AppFonts.secondaryFont,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ),
                                Text(
                                  "${calculateTotalSum()} TMT",
                                  style: TextStyle(
                                      fontSize: 12.0.sp,
                                      fontWeight: FontWeight.bold),
                                )
                              ],
                            ),
                            Divider(),
                            Text(
                              "${lang.comment}: ${order?.comment}",
                              style: TextStyle(
                                fontSize: 12.0.sp,
                                fontWeight: FontWeight.bold,
                                fontFamily: AppFonts.secondaryFont,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                if (merchandising != null && merchandising!.merchandiserImages != null && merchandising!.merchandiserImages!.isNotEmpty) ...[
                  if (getBeforeImages().isNotEmpty)
                    ExpansionTile(
                      title: Text(
                        lang.merchandising,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: AppFonts.monserratBold,
                        ),
                      ),
                      initiallyExpanded: true,
                      children: [
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0.r),
                          ),
                          elevation: 4,
                          child: Column(
                            spacing: 5.h,
                            children: [
                              SizedBox(height: 5.h),
                              Text(
                                lang.beforeMerchandising,
                                style: TextStyle(
                                  fontSize: 14.0.sp,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: AppFonts.secondaryFont,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: GridView.builder(
                                  shrinkWrap: true,
                                  physics: NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 8.0,
                                    mainAxisSpacing: 8.0,
                                  ),
                                  itemCount: getBeforeImages().length,
                                  itemBuilder: (context, index) {
                                    final image = getBeforeImages()[index];
                                    return GestureDetector(
                                      onTap: () {
                                        if (image.imagePath != null) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => FullScreenImageView(File(image.imagePath!)),
                                            ),
                                          );
                                        }
                                      },
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8.0),
                                        child: image.imagePath != null
                                            ? Image.file(
                                                File(image.imagePath!),
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (context, error, stackTrace) {
                                                  return Container(
                                                    color: Colors.grey[300],
                                                    child: Icon(
                                                      Icons.broken_image,
                                                      size: 40,
                                                      color: Colors.grey[600],
                                                    ),
                                                  );
                                                },
                                              )
                                            : Container(
                                                color: Colors.grey[300],
                                                child: Icon(
                                                  Icons.image_not_supported,
                                                  size: 40,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              Text(
                                lang.afterMerchandising,
                                style: TextStyle(
                                  fontSize: 14.0.sp,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: AppFonts.secondaryFont,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: GridView.builder(
                                  shrinkWrap: true,
                                  physics: NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 8.0,
                                    mainAxisSpacing: 8.0,
                                  ),
                                  itemCount: getAfterImages().length,
                                  itemBuilder: (context, index) {
                                    final image = getAfterImages()[index];
                                    return GestureDetector(
                                      onTap: () {
                                        if (image.imagePath != null) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => FullScreenImageView(File(image.imagePath!)),
                                            ),
                                          );
                                        }
                                      },
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8.0),
                                        child: image.imagePath != null
                                            ? Image.file(
                                                File(image.imagePath!),
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (context, error, stackTrace) {
                                                  return Container(
                                                    color: Colors.grey[300],
                                                    child: Icon(
                                                      Icons.broken_image,
                                                      size: 40,
                                                      color: Colors.grey[600],
                                                    ),
                                                  );
                                                },
                                              )
                                            : Container(
                                                color: Colors.grey[300],
                                                child: Icon(
                                                  Icons.image_not_supported,
                                                  size: 40,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                      ),
                                    );
                                  },
                                ),
                              ),

                              if (orderStatus != 'dont send')
                                Padding(
                                  padding: EdgeInsets.only(left: 8.w, right: 8.w, bottom: 8.h),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: isSendingPhotos ? null : _sendPhotos,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue.shade500,
                                        disabledBackgroundColor: Colors.grey,
                                      ),
                                      icon: isSendingPhotos
                                          ? SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Icon(Icons.send, color: Colors.white),
                                      label: Text(
                                        isSendingPhotos ? 'Sending...' : lang.sendPhotos,
                                        style: TextStyle(
                                          fontSize: 16.sp,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: AppFonts.monserratBold,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                            ],
                          ),
                        ),
                      ],
                    ),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<MerchandiserImage> getBeforeImages() {
    if (merchandising?.merchandiserImages == null) return [];
    return merchandising!.merchandiserImages!
        .where((img) => img.beforeAfter == 'before')
        .toList();
  }

  List<MerchandiserImage> getAfterImages() {
    if (merchandising?.merchandiserImages == null) return [];
    return merchandising!.merchandiserImages!
        .where((img) => img.beforeAfter == 'after')
        .toList();
  }
}