import 'package:flutter/widgets.dart';
import 'package:shaylan_agent/models/visit.dart';

abstract class TraderVisitEvent {}

class LoadVisits extends TraderVisitEvent {
  final DateTime? startTime;
  final DateTime? endTime;
  final String? statusFilter;

  LoadVisits({
    this.endTime,
    this.startTime,
    this.statusFilter,
  });
}

class LoadRecentVisits extends TraderVisitEvent {
  final DateTime? startTime;
  final DateTime? endTime;
  final int limit;
  
  LoadRecentVisits({
    this.endTime,
    this.startTime,
    this.limit = 50,
  });
}

class UpdateVisitStatus extends TraderVisitEvent {
  final int visitId;

  UpdateVisitStatus(this.visitId);
}

class SendVisit extends TraderVisitEvent {
  final bool withImage;
  final VisitModel visit;
  final BuildContext context;

  SendVisit(this.withImage, this.visit, this.context);
}

class UploadMerchImages extends TraderVisitEvent {
  final List<dynamic> images;
  final String token;
  final VisitModel? visit;

  UploadMerchImages({
    required this.images,
    required this.token,
    required this.visit,
  });

  @override
  // ignore: override_on_non_overriding_member
  List<Object> get props => [images, token];
}
