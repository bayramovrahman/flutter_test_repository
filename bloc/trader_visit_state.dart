import 'package:shaylan_agent/models/visit.dart';

abstract class TraderVisitState {}

class VisitInitial extends TraderVisitState {}

class VisitLoading extends TraderVisitState {}

class VisitLoaded extends TraderVisitState {
  final List<VisitModel> sendVisits;
  final List<VisitModel> dontSendVisits;
  final List<VisitModel> notFinishedVisits;

  VisitLoaded(
      {required this.sendVisits,
      required this.dontSendVisits,
      required this.notFinishedVisits});
}

class VisitError extends TraderVisitState {
  final String message;

  VisitError(this.message);
}

class VisitUpdated extends TraderVisitState {}

class VisitVerificationWarning extends TraderVisitState {
  final String message;

  VisitVerificationWarning(this.message);
}

class ImageUploading extends TraderVisitState{}

class ImageUploadSuccess extends TraderVisitState{}

class ImageUploadFailure extends TraderVisitState{

  final String error;

  ImageUploadFailure(this.error);
}

class VisitSendSuccess extends TraderVisitState {
  final String message;
  VisitSendSuccess(this.message);
}

class VisitSending extends TraderVisitState {
  final int visitId;
  VisitSending(this.visitId);
}

class RecentVisitsLoaded extends TraderVisitState {
  final List<VisitModel> sendVisits;
  final List<VisitModel> dontSendVisits;
  final List<VisitModel> notFinishedVisits;

  RecentVisitsLoaded({
    required this.sendVisits,
    required this.dontSendVisits,
    required this.notFinishedVisits,
  });
}
