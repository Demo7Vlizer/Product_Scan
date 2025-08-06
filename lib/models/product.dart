class Product {
  int? id;
  String? barcode;
  String? name;
  String? imagePath;
  double? mrp;
  int? quantity;
  String? createdDate;

  Product({
    this.id,
    this.barcode,
    this.name,
    this.imagePath,
    this.mrp,
    this.quantity,
    this.createdDate,
  });

  Product.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    barcode = json['barcode'];
    name = json['name'];
    imagePath = json['image_path'];
    mrp = json['mrp']?.toDouble();
    quantity = json['quantity'];
    createdDate = json['created_date'];
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'barcode': barcode,
    'name': name,
    'image_path': imagePath,
    'mrp': mrp,
    'quantity': quantity,
    'created_date': createdDate,
  };
}
