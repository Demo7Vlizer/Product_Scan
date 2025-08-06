class StockBarcode {
  int? id;
  String? barcode;
  String? stockCode;
  String? detail;

  StockBarcode({
    this.id,
    this.barcode,
    this.stockCode,
    this.detail,
  });

  StockBarcode.fromJson(Map<String, dynamic> json) {
    id = json['Id'];
    barcode = json['Barcode'];
    stockCode = json['StockCode'];
    detail = json['Detail'];
  }

  Map<String, dynamic> toJson() => {
        'Id': id ?? 0,
        'Barcode': barcode ?? "",
        'StockCode': stockCode ?? "",
        'Detail': detail ?? "",
      };
}
