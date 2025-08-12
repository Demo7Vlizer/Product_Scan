class ProductLocation {
  int? id;
  String? productName;
  String? locationName;
  String? imagePath;
  List<String>? imagePaths; // Support for multiple images
  String? notes;
  String? createdDate;
  String? updatedDate;

  ProductLocation({
    this.id,
    this.productName,
    this.locationName,
    this.imagePath,
    this.imagePaths,
    this.notes,
    this.createdDate,
    this.updatedDate,
  });

  ProductLocation.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    productName = json['product_name'];
    locationName = json['location_name'];
    imagePath = json['image_path'];
    // Handle multiple images
    if (json['image_paths'] != null) {
      imagePaths = List<String>.from(json['image_paths']);
    } else if (json['image_path'] != null) {
      imagePaths = [json['image_path']];
    }
    notes = json['notes'];
    createdDate = json['created_date'];
    updatedDate = json['updated_date'];
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'product_name': productName,
    'location_name': locationName,
    'image_path': imagePath,
    'image_paths': imagePaths,
    'notes': notes,
    'created_date': createdDate,
    'updated_date': updatedDate,
  };

  Map<String, dynamic> toCreateJson() => {
    'product_name': productName,
    'location_name': locationName,
    'notes': notes,
  };
}

class ProductLocationResponse {
  List<ProductLocation>? locations;
  int? totalCount;
  int? page;
  int? perPage;
  int? totalPages;

  ProductLocationResponse({
    this.locations,
    this.totalCount,
    this.page,
    this.perPage,
    this.totalPages,
  });

  ProductLocationResponse.fromJson(Map<String, dynamic> json) {
    if (json['Result'] != null) {
      locations = <ProductLocation>[];
      json['Result'].forEach((v) {
        locations!.add(ProductLocation.fromJson(v));
      });
    }
    totalCount = json['total_count'];
    page = json['page'];
    perPage = json['per_page'];
    totalPages = json['total_pages'];
  }
}
