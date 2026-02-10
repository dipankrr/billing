class Customer {
  final String? id;
  final String name;
  final String phone;
  final String address;
  final double previousDue;

  Customer({
    this.id,
    required this.name,
    required this.phone,
    this.address = '',
    this.previousDue = 0.0,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id']?.toString(),
      name: json['name'],
      phone: json['phone'],
      address: json['address'] ?? '',
      previousDue: (json['previous_due'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'address': address,
      'previous_due': previousDue,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Customer && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
