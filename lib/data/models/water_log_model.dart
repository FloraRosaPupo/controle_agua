class WaterLogModel {
  final String id;
  final int amount;
  final DateTime date;

  WaterLogModel({required this.id, required this.amount, required this.date});

  factory WaterLogModel.fromJson(Map<String, dynamic> json) {
    return WaterLogModel(
      id: json['id'] ?? '',
      amount: json['amount'] ?? 0,
      date: DateTime.parse(json['date'].toString().replaceAll('Z', '')),
    );
  }
}
