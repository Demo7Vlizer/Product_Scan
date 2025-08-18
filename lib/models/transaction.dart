class Transaction {
  int? id;
  String? barcode;
  String? transactionType; // 'IN' or 'OUT'
  int? quantity;
  String? recipientName;
  String? recipientPhone;
  String? recipientPhoto;
  String? transactionDate;
  String? notes;
  String? productName;
  String? customerNotes; // Customer notes from customers table

  Transaction({
    this.id,
    this.barcode,
    this.transactionType,
    this.quantity,
    this.recipientName,
    this.recipientPhone,
    this.recipientPhoto,
    this.transactionDate,
    this.notes,
    this.productName,
    this.customerNotes,
  });

  Transaction.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    barcode = json['barcode'];
    transactionType = json['transaction_type'];
    quantity = json['quantity'];
    recipientName = json['recipient_name'];
    recipientPhone = json['recipient_phone'];
    recipientPhoto = json['recipient_photo'];
    transactionDate = json['transaction_date'];
    notes = json['notes'];
    productName = json['product_name'];
    customerNotes = json['customer_notes'];
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'barcode': barcode,
    'transaction_type': transactionType,
    'quantity': quantity,
    'recipient_name': recipientName,
    'recipient_phone': recipientPhone,
    'recipient_photo': recipientPhoto,
    'transaction_date': transactionDate,
    'notes': notes,
    'product_name': productName,
    'customer_notes': customerNotes,
  };
}
