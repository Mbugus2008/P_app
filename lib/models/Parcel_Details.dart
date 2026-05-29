class Parcel_Details {
  String? Key;
  String? Document_No;
  int? No_Of_Items;
  String? Description;
  double? Amount;
  String? Remarks;

  Parcel_Details({
    this.Key,
    this.Document_No,
    this.No_Of_Items,
    this.Description,
    this.Amount,
    this.Remarks,
  });

  // Factory constructor for creating an instance from JSON
  factory Parcel_Details.fromJson(Map<String, dynamic> json) {
    return Parcel_Details(
      Key: json['Key'],
      Document_No: json['Document_No'],
      No_Of_Items: json['No_Of_Items'],
      Description: json['Description'],
      Amount: json['Amount']?.toDouble(),
      Remarks: json['Remarks'],
    );
  }

  // Method for converting an instance to JSON
  Map<String, dynamic> toJson() {
    return {
      'Key': Key,
      'Document_No': Document_No,
      'No_Of_Items': No_Of_Items,
      'Description': Description,
      'Amount': Amount,
      'Remarks': Remarks,
    };
  }

  // Copy with method for creating a new instance with updated values
  Parcel_Details copyWith({
    String? Key,
    String? Document_No,
    int? No_Of_Items,
    String? Description,
    double? Amount,
    String? Remarks,
  }) {
    return Parcel_Details(
      Key: Key ?? this.Key,
      Document_No: Document_No ?? this.Document_No,
      No_Of_Items: No_Of_Items ?? this.No_Of_Items,
      Description: Description ?? this.Description,
      Amount: Amount ?? this.Amount,
      Remarks: Remarks ?? this.Remarks,
    );
  }

  @override
  String toString() {
    return 'Parcel_Details(Key: $Key, Document_No: $Document_No, No_Of_Items: $No_Of_Items, Description: $Description, Amount: $Amount, Remarks: $Remarks)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is Parcel_Details &&
      other.Key == Key &&
      other.Document_No == Document_No &&
      other.No_Of_Items == No_Of_Items &&
      other.Description == Description &&
      other.Amount == Amount &&
      other.Remarks == Remarks;
  }

  @override
  int get hashCode {
    return Key.hashCode ^
      Document_No.hashCode ^
      No_Of_Items.hashCode ^
      Description.hashCode ^
      Amount.hashCode ^
      Remarks.hashCode;
  }
}

