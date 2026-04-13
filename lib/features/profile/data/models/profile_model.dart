class ProfileModel {
  final String id;
  final String fullName;
  final String phone;
  final String? email;
  final DateTime createdAt;
  final List<VehicleModel> vehicles;
  final List<PaymentMethodModel> paymentMethods;

  ProfileModel({
    required this.id,
    required this.fullName,
    required this.phone,
    this.email,
    required this.createdAt,
    required this.vehicles,
    required this.paymentMethods,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'],
      fullName: json['full_name'],
      phone: json['phone'],
      email: json['email'],
      createdAt: DateTime.parse(json['created_at']),
      vehicles: (json['vehicles'] as List)
          .map((v) => VehicleModel.fromJson(v))
          .toList(),
      paymentMethods: (json['payment_methods'] as List)
          .map((p) => PaymentMethodModel.fromJson(p))
          .toList(),
    );
  }
}

class VehicleModel {
  final String id;
  final String licensePlate;
  final String? make;
  final String? model;
  final bool isPrimary;
  final DateTime createdAt;

  VehicleModel({
    required this.id,
    required this.licensePlate,
    this.make,
    this.model,
    required this.isPrimary,
    required this.createdAt,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id'],
      licensePlate: json['license_plate'],
      make: json['make'],
      model: json['model'],
      isPrimary: json['is_primary'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class PaymentMethodModel {
  final String id;
  final String provider;
  final String maskedAccount;
  final bool isDefault;
  final DateTime createdAt;

  PaymentMethodModel({
    required this.id,
    required this.provider,
    required this.maskedAccount,
    required this.isDefault,
    required this.createdAt,
  });

  factory PaymentMethodModel.fromJson(Map<String, dynamic> json) {
    return PaymentMethodModel(
      id: json['id'],
      provider: json['provider'],
      maskedAccount: json['masked_account'],
      isDefault: json['is_default'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
