enum AppLanguage { ne, en }

enum PaymentMethod { cash, digital }

enum EnrollmentStatus {
  draft,
  submitting,
  submitted,
  uncertain,
  rejected,
  winner,
  notSelected
}

class UserProfile {
  const UserProfile(
      {required this.name, required this.mobile, required this.address});

  final String name;
  final String mobile;
  final String address;

  Map<String, Object?> toMap() =>
      {'name': name, 'mobile': mobile, 'address': address};

  factory UserProfile.fromMap(Map<String, Object?> map) => UserProfile(
        name: map['name']! as String,
        mobile: map['mobile']! as String,
        address: map['address']! as String,
      );
}

class BillEntry {
  const BillEntry({
    this.id,
    required this.billNumber,
    required this.sellerPan,
    required this.billDate,
    required this.amount,
    required this.paymentMethod,
    required this.imagePath,
    required this.status,
    this.coupon,
    this.serverMessage,
    required this.createdAt,
  });

  final int? id;
  final String billNumber;
  final String sellerPan;
  final DateTime billDate;
  final double amount;
  final PaymentMethod paymentMethod;
  final String imagePath;
  final EnrollmentStatus status;
  final String? coupon;
  final String? serverMessage;
  final DateTime createdAt;

  bool get isActive => status == EnrollmentStatus.submitted;

  BillEntry copyWith({
    int? id,
    EnrollmentStatus? status,
    String? coupon,
    String? serverMessage,
  }) =>
      BillEntry(
        id: id ?? this.id,
        billNumber: billNumber,
        sellerPan: sellerPan,
        billDate: billDate,
        amount: amount,
        paymentMethod: paymentMethod,
        imagePath: imagePath,
        status: status ?? this.status,
        coupon: coupon ?? this.coupon,
        serverMessage: serverMessage ?? this.serverMessage,
        createdAt: createdAt,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'bill_number': billNumber,
        'seller_pan': sellerPan,
        'bill_date': billDate.toIso8601String().substring(0, 10),
        'amount': amount,
        'payment_method': paymentMethod.name,
        'image_path': imagePath,
        'status': status.name,
        'coupon': coupon,
        'server_message': serverMessage,
        'created_at': createdAt.toIso8601String(),
      };

  factory BillEntry.fromMap(Map<String, Object?> map) => BillEntry(
        id: map['id'] as int,
        billNumber: map['bill_number']! as String,
        sellerPan: map['seller_pan']! as String,
        billDate: DateTime.parse(map['bill_date']! as String),
        amount: (map['amount']! as num).toDouble(),
        paymentMethod:
            PaymentMethod.values.byName(map['payment_method']! as String),
        imagePath: map['image_path']! as String,
        status: EnrollmentStatus.values.byName(map['status']! as String),
        coupon: map['coupon'] as String?,
        serverMessage: map['server_message'] as String?,
        createdAt: DateTime.parse(map['created_at']! as String),
      );
}

class IrdEnrollmentResult {
  const IrdEnrollmentResult(
      {required this.success,
      this.coupon,
      this.message,
      this.fieldErrors = const {}});

  final bool success;
  final String? coupon;
  final String? message;
  final Map<String, String> fieldErrors;
}
