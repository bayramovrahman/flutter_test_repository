part of 'internet_connection_cubit.dart';

abstract class InternetConnectionState {}

class InternetConnectionInitial extends InternetConnectionState {}

class InternetConnectionConnected extends InternetConnectionState {}

class InternetConnectionDisconnected extends InternetConnectionState {}
