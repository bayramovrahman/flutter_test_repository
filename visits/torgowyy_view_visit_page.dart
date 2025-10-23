import 'dart:io';
import 'package:dio/dio.dart';
import 'package:iconly/iconly.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shaylan_agent/logic/cubits/cubit_internet_connection/internet_connection_cubit.dart';
import 'package:shaylan_agent/models/visit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shaylan_agent/app/app_fonts.dart';
import 'package:shaylan_agent/methods/gridview.dart';
import 'package:shaylan_agent/models/merchandising.dart';
import 'package:shaylan_agent/models/orderforserver.dart';
import 'package:shaylan_agent/utilities/alert_utils.dart';
import 'package:shaylan_agent/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shaylan_agent/services/local_database.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shaylan_agent/database/functions/visit.dart';
import 'package:shaylan_agent/database/functions/customer.dart';
import 'package:shaylan_agent/screens/full_screen_image_view.dart';
import 'package:shaylan_agent/pages/items_list_page/items_list_view.dart';
import 'package:shaylan_agent/pages/trader_visits/bloc/trader_visit_bloc.dart';
import 'package:shaylan_agent/pages/trader_visits/bloc/trader_visit_event.dart';
import 'package:shaylan_agent/pages/trader_visits/bloc/trader_visit_state.dart';

class TorgowyyViewVisitPage extends StatefulWidget {
  final VisitModel visit;

  const TorgowyyViewVisitPage({super.key, required this.visit});

  @override
  State<TorgowyyViewVisitPage> createState() => _TorgowyyViewVisitPageState();
}

class _TorgowyyViewVisitPageState extends State<TorgowyyViewVisitPage> {
  // Just empty column

  final ValueNotifier<OrderForServer?> _orderNotifier = ValueNotifier(null);
  final ValueNotifier<String?> _orderStatusNotifier = ValueNotifier(null);
  final ValueNotifier<Merchandising?> _merchandisingNotifier = ValueNotifier(null);
  final ValueNotifier<String?> _imagePathNotifier = ValueNotifier(null);
  final ValueNotifier<String?> _withNoImagesNotifier = ValueNotifier(null);
  final ValueNotifier<bool> _isLoadingMerchandisingNotifier = ValueNotifier(true);
  final ValueNotifier<bool> _isSendingPhotosNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _isLoadingWithNoImagesNotifier = ValueNotifier(true);

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _orderNotifier.dispose();
    _orderStatusNotifier.dispose();
    _merchandisingNotifier.dispose();
    _imagePathNotifier.dispose();
    _withNoImagesNotifier.dispose();
    _isLoadingMerchandisingNotifier.dispose();
    _isSendingPhotosNotifier.dispose();
    _isLoadingWithNoImagesNotifier.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    await Future.wait([
      _loadImagePath(),
      _fetchOrder(),
      _fetchMerchandising(),
      _fetchWithNoImagesValue(),
    ]);
  }

  Future<void> _loadImagePath() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      _imagePathNotifier.value = directory.path;
    } catch (e) {
      debugPrint('Error loading image path: $e');
    }
  }

  Future<void> _fetchOrder() async {
    try {
      final result = await getOrder(widget.visit.id!);
      final status = await getOrderStatus(widget.visit.id!);
      _orderNotifier.value = result;
      _orderStatusNotifier.value = status;
    } catch (e) {
      debugPrint('Error fetching order: $e');
    }
  }

  double _calculateTotalSum(OrderForServer? order) {
    if (order == null || order.orderItems.isEmpty) return 0.0;
    final total = order.orderItems.fold(0.0, (sum, item) {
      return sum + (item.itemCountForOrder * double.parse(item.price));
    });
    return double.parse(total.toStringAsFixed(2));
  }

  Future<void> _fetchMerchandising() async {
    try {
      final result = await getMerchandising(widget.visit.id!, true);
      _merchandisingNotifier.value = result;
    } catch (e) {
      debugPrint('Error fetching merchandising: $e');
    } finally {
      _isLoadingMerchandisingNotifier.value = false;
    }
  }

  Future<void> _fetchWithNoImagesValue() async {
    try {
      final value = await getWithNoImagesValue(widget.visit.id!);
      _withNoImagesNotifier.value = value;
    } catch (e) {
      debugPrint('Error fetching withNoImages: $e');
    } finally {
      _isLoadingWithNoImagesNotifier.value = false;
    }
  }

  bool _shouldShowSendButton(String? withNoImagesValue) {
    if (withNoImagesValue == null) return false;
    final value = withNoImagesValue.trim().toLowerCase();
    return value == 'true' || value == 'ok';
  }

  bool _shouldShowMerchandisingTile(String? withNoImagesValue) {
    if (withNoImagesValue == null) return true;
    return withNoImagesValue.trim().isNotEmpty;
  }

  List<MerchandiserImage> _filterImages(Merchandising? merchandising, String beforeAfter) {
    if (merchandising?.merchandiserImages == null) return [];
    return merchandising!.merchandiserImages!
        .where((img) => img.beforeAfter == beforeAfter)
        .toList();
  }

  String _getPaymentOptionText(int groupNum, AppLocalizations lang) {
    return switch (groupNum) {
      -1 => lang.cashPayment,
      5 => lang.enumeration,
      1 => lang.sevenCredit,
      2 => lang.fourteenCredit,
      3 => lang.thirtyCredit,
      _ => 'Töleg görnüşi saýlanmady',
    };
  }

  @override
  Widget build(BuildContext context) {
    var lang = AppLocalizations.of(context)!;

    return BlocListener<TraderVisitBloc, TraderVisitState>(
      listener: _handleBlocState,
      child: Scaffold(
        appBar: _buildAppBar(lang),
        body: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOrderSection(lang),
                _buildMerchandisingSection(lang),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleBlocState(BuildContext context, TraderVisitState state) {
    if (state is ImageUploadSuccess) {
      _isSendingPhotosNotifier.value = false;
      AlertUtils.showSnackBarSuccess(
        context: context,
        message: 'Suratlar üstünlikli ugradyldy!',
        second: 5,
      );
      _fetchMerchandising();
    } else if (state is ImageUploadFailure) {
      _isSendingPhotosNotifier.value = false;
      AlertUtils.showSnackBarWarning(
        context: context,
        message: AppLocalizations.of(context)!.unsuccessfully,
        second: 3,
      );
    }
  }

  PreferredSizeWidget _buildAppBar(AppLocalizations lang) {
    return AppBar(
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
      actions: [
        ValueListenableBuilder<String?>(
          valueListenable: _orderStatusNotifier,
          builder: (context, orderStatus, _) {
            if (orderStatus != 'dont send') return const SizedBox.shrink();
            return IconButton(
              onPressed: () => _handleEditOrder(lang),
              icon: const Icon(Icons.edit_sharp),
              color: Colors.white,
            );
          },
        ),
      ],
      centerTitle: true,
      backgroundColor: Colors.blue,
    );
  }

  Future<void> _handleEditOrder(AppLocalizations lang) async {
    final order = _orderNotifier.value;
    if (order == null) return;

    try {
      final customer = await getCustomerByCardCode(widget.visit.cardCode);
      if (!mounted) return;

      final visitModel = widget.visit.copyWith(orderList: [order]);

      navigatorPushMethod(
        context,
        ItemListView(
          visit: visitModel,
          customer: customer,
          editingCurrentOrder: true,
          productGroup: order.orderItems.first.productGroupId,
          mmlList: [],
          editBeforeSend: true,
        ),
        false,
      );
    } catch (e) {
      debugPrint('Error handling edit order: $e');
    }
  }

  Widget _buildOrderSection(AppLocalizations lang) {
    return ValueListenableBuilder<OrderForServer?>(
      valueListenable: _orderNotifier,
      builder: (context, order, _) {
        if (order == null || order.orderItems.isEmpty) {
          return const SizedBox.shrink();
        }

        return ExpansionTile(
          title: Text(
            lang.ordersList,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: AppFonts.monserratBold,
            ),
          ),
          initiallyExpanded: true,
          children: [
            _buildOrderCard(order, lang),
            _buildOrderSummary(order, lang),
          ],
        );
      },
    );
  }

  Widget _buildOrderCard(OrderForServer order, AppLocalizations lang) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0.r),
      ),
      elevation: 4,
      child: Column(
        children: order.orderItems.map((item) => _buildOrderItem(item, lang)).toList(),
      ),
    );
  }

  Widget _buildOrderItem(dynamic item, AppLocalizations lang) {
    final totalPrice = item.itemCountForOrder * double.parse(item.price);
    
    return ValueListenableBuilder<String?>(
      valueListenable: _imagePathNotifier,
      builder: (context, imagePath, _) {
        return ListTile(
          leading: _buildItemImage(imagePath, item.picturName),
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
      },
    );
  }

  Widget _buildItemImage(String? imagePath, String pictureName) {
    if (imagePath == null) {
      return const Icon(Icons.image, size: 40);
    }

    return Image.file(
      File('$imagePath/$pictureName'),
      width: 50,
      height: 100,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return const Icon(Icons.no_photography, size: 40);
      },
    );
  }

  Widget _buildOrderSummary(OrderForServer order, AppLocalizations lang) {
    final totalSum = _calculateTotalSum(order);
    
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  "${lang.paymentOption}: ${_getPaymentOptionText(order.groupNum, lang)}",
                  style: TextStyle(
                    fontSize: 12.0.sp,
                    fontWeight: FontWeight.bold,
                    fontFamily: AppFonts.secondaryFont,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                "$totalSum TMT",
                style: TextStyle(
                  fontSize: 12.0.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(),
          Text(
            "${lang.comment}: ${order.comment}",
            style: TextStyle(
              fontSize: 12.0.sp,
              fontWeight: FontWeight.bold,
              fontFamily: AppFonts.secondaryFont,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMerchandisingSection(AppLocalizations lang) {
    return ValueListenableBuilder<String?>(
      valueListenable: _withNoImagesNotifier,
      builder: (context, withNoImagesValue, _) {
        return ValueListenableBuilder<Merchandising?>(
          valueListenable: _merchandisingNotifier,
          builder: (context, merchandising, _) {
            if (!_shouldShowMerchandisingTile(withNoImagesValue) ||
                merchandising == null ||
                merchandising.merchandiserImages == null ||
                merchandising.merchandiserImages!.isEmpty) {
              return const SizedBox.shrink();
            }

            final beforeImages = _filterImages(merchandising, 'before');
            if (beforeImages.isEmpty) return const SizedBox.shrink();

            return ExpansionTile(
              title: Text(
                lang.merchandising,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: AppFonts.monserratBold,
                ),
              ),
              initiallyExpanded: true,
              children: [
                _buildMerchandisingCard(merchandising, withNoImagesValue, lang),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMerchandisingCard(
    Merchandising merchandising,
    String? withNoImagesValue,
    AppLocalizations lang,
  ) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0.r),
      ),
      elevation: 4,
      child: Column(
        children: [
          SizedBox(height: 5.h),
          _buildImageSection(
            _filterImages(merchandising, 'before'),
            lang.beforeMerchandising,
            lang,
          ),
          _buildImageSection(
            _filterImages(merchandising, 'after'),
            lang.afterMerchandising,
            lang,
          ),
          if (_shouldShowSendButton(withNoImagesValue))
            _buildSendPhotosButton(lang),
        ],
      ),
    );
  }

  Widget _buildImageSection(
    List<MerchandiserImage> images,
    String title,
    AppLocalizations lang,
  ) {
    return Column(
      children: [
        SizedBox(height: 5.h),
        Text(
          title,
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
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8.0,
              mainAxisSpacing: 8.0,
            ),
            itemCount: images.length,
            itemBuilder: (context, index) => _buildImageTile(images[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildImageTile(MerchandiserImage image) {
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
                errorBuilder: (context, error, stackTrace) {
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
  }

  Widget _buildSendPhotosButton(AppLocalizations lang) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isSendingPhotosNotifier,
      builder: (context, isSending, _) {
        return BlocBuilder<InternetConnectionCubit, InternetConnectionState>(
          builder: (context, connectionState) {
            final hasInternet = connectionState is InternetConnectionConnected;
            return Padding(
              padding: EdgeInsets.only(left: 8.w, right: 8.w, bottom: 8.h),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (isSending || !hasInternet) ? null : _sendPhotos,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasInternet ? Colors.blue.shade500 : Colors.grey,
                    disabledBackgroundColor: Colors.grey,
                  ),
                  icon: isSending
                      ? SizedBox(
                          width: 20.w,
                          height: 20.h,
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(
                          hasInternet ? IconlyLight.send : Icons.wifi_off,
                          color: Colors.white,
                        ),
                  label: Text(
                    isSending 
                        ? '${lang.sending}...' 
                        : hasInternet 
                            ? lang.sendPhotos 
                            : lang.noIntConn,
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: AppFonts.monserratBold,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _sendPhotos() async {
    var lang = AppLocalizations.of(context)!;
    
    final connectionState = context.read<InternetConnectionCubit>().state;
    if (connectionState is !InternetConnectionConnected) {
      AlertUtils.noInternetConnection(
        context: context,
        message: lang.noIntConn,
        lang: lang,
      );
      return;
    }

    final merchandising = _merchandisingNotifier.value;
    
    if (merchandising == null ||
        merchandising.merchandiserImages == null ||
        merchandising.merchandiserImages!.isEmpty) {
      AlertUtils.showSnackBarWarning(
        context: context,
        message: 'Ugratmak üçin surat tapylmady!',
        second: 5,
      );
      return;
    }

    _isSendingPhotosNotifier.value = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken');

      if (token == null) {
        if (mounted) {
          AlertUtils.showSnackBarError(
            context: context,
            message: 'Ulgamdan çykyp täzeden giriň!',
            second: 5,
          );
        }
        _isSendingPhotosNotifier.value = false;
        return;
      }

      final data = await _prepareImageData(merchandising);

      if (data.isEmpty) {
        if (mounted) {
          AlertUtils.showSnackBarWarning(
            context: context,
            message: 'Ugratmak üçin dogry surat tapylmady!',
            second: 5,
          );
        }
        _isSendingPhotosNotifier.value = false;
        return;
      }

      if (mounted) {
        context.read<TraderVisitBloc>().add(
              UploadMerchImages(
                images: data,
                token: token,
                visit: widget.visit,
              ),
            );
      }
    } catch (e) {
      debugPrint("Error preparing photos: $e");
      if (mounted) {
        AlertUtils.showSnackBarError(
          context: context,
          message: AppLocalizations.of(context)!.unsuccessfully,
          second: 5,
        );
      }
      _isSendingPhotosNotifier.value = false;
    }
  }

  Future<List<Map<String, dynamic>>> _prepareImageData(
    Merchandising merchandising,
  ) async {
    final data = <Map<String, dynamic>>[];

    for (var image in merchandising.merchandiserImages!) {
      final file = File(image.imagePath!);
      if (!file.existsSync()) {
        debugPrint("File not found: ${file.path}");
        continue;
      }

      final multipartImage = await MultipartFile.fromFile(
        file.path,
        filename: image.imageName ?? 'image.jpg',
      );

      data.add({
        "MerchandiserImageId": image.merchandiserImageId ?? 0,
        "ImagePath": image.imagePath,
        "ImageName": image.imageName,
        "BeforeAfter": image.beforeAfter,
        "Merchandiser": null,
        "EncodedImage": multipartImage,
      });
    }

    return data;
  }

  // Just empty column
}
