import 'package:freezed_annotation/freezed_annotation.dart';

part 'response_wrapper.g.dart';

@JsonSerializable(genericArgumentFactories: true)
class ResponseWrapper<T> {
  final String code;
  final String message;
  final T? data;
  // final MetaInfo? meta; // TODO: Implement MetaInfo if needed
  // final List<ErrorItem>? errors; // TODO: Implement ErrorItem if needed

  ResponseWrapper({
    required this.code,
    required this.message,
    this.data,
  });

  factory ResponseWrapper.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) =>
      _$ResponseWrapperFromJson(json, fromJsonT);
}
