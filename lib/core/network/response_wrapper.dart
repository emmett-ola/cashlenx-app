import 'package:freezed_annotation/freezed_annotation.dart';

part 'response_wrapper.g.dart';

@JsonSerializable(genericArgumentFactories: true)
class ResponseWrapper<T> {
  final String code;
  final String message;
  final T? data;
  final Map<String, dynamic>? meta;
  final List<dynamic>? errors;
  final Map<String, dynamic>? extra;

  ResponseWrapper({
    required this.code,
    required this.message,
    this.data,
    this.meta,
    this.errors,
    this.extra,
  });

  factory ResponseWrapper.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) =>
      _$ResponseWrapperFromJson(json, fromJsonT);
}
