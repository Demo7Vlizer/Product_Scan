class OrderDetail {
  int? id;
  int? orderId;
  int? sequence;
  String? stockCode;
  String? stockName;
  int? amount;
  String? status;

  OrderDetail({
    this.id,
    this.orderId,
    this.sequence,
    this.stockCode,
    this.stockName,
    this.amount,
    this.status,
  });

  OrderDetail.fromJson(Map<String, dynamic> json) {
    id = json['Id'];
    orderId = json['OrderId'];
    sequence = json['Sequence'];
    stockCode = json['StockCode'];
    stockName = json['StockName'];
    amount = json['Amount'];
    status = json['Status'];
  }

  Map<String, dynamic> toJson() => {
        'Id': id ?? 0,
        'OrderId': orderId ?? 0,
        'Sequence': sequence ?? 0,
        'StockCode': stockCode ?? "",
        'StockName': stockName ?? "",
        'Amount': amount ?? 0,
        'Status': status ?? "",
      };
}
