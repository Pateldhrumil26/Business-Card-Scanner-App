class DetectedPerson {
  final String name;
  final String designation;
  final String phone;
  final String email;

  DetectedPerson({
    required this.name,
    this.designation = '',
    this.phone = '',
    this.email = '',
  });

  factory DetectedPerson.fromJson(Map<String, dynamic> json) {
    return DetectedPerson(
      name: json['name'] ?? '',
      designation: json['designation'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'designation': designation,
      'phone': phone,
      'email': email,
    };
  }
}

class ContactModel {
  final String id;
  final String? businessCardId;
  final String? cardImageUrl;
  final String? backImageUrl;
  final String personName;
  final String companyName;
  final String designation;
  final String phone;
  final String alternativePhone;
  final String email;
  final String website;
  final String address;
  final String city;
  final String state;
  final String country;
  final String gstNumber;
  final String category;
  final String servicesOffered;
  final String notes;
  final bool hasMultiplePersons;
  final List<DetectedPerson> detectedPersons;
  final DateTime? createdAt;

  ContactModel({
    required this.id,
    this.businessCardId,
    this.cardImageUrl,
    this.backImageUrl,
    required this.personName,
    this.companyName = '',
    this.designation = '',
    this.phone = '',
    this.alternativePhone = '',
    this.email = '',
    this.website = '',
    this.address = '',
    this.city = '',
    this.state = '',
    this.country = 'India',
    this.gstNumber = '',
    this.category = 'Business',
    this.servicesOffered = '',
    this.notes = '',
    this.hasMultiplePersons = false,
    this.detectedPersons = const [],
    this.createdAt,
  });

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    String? cardImg;
    String? backImg;
    String? cardId;

    if (json['businessCardId'] != null) {
      if (json['businessCardId'] is Map<String, dynamic>) {
        cardImg = json['businessCardId']['originalImage'];
        backImg = json['businessCardId']['backImage'];
        cardId = json['businessCardId']['_id'] ?? json['businessCardId']['id'];
      } else if (json['businessCardId'] is String) {
        cardId = json['businessCardId'];
      }
    }

    final List<DetectedPerson> persons = [];
    if (json['detectedPersons'] != null && json['detectedPersons'] is List) {
      for (final p in json['detectedPersons']) {
        if (p is Map<String, dynamic>) {
          persons.add(DetectedPerson.fromJson(p));
        }
      }
    }

    return ContactModel(
      id: json['_id'] ?? json['id'] ?? '',
      businessCardId: cardId,
      cardImageUrl: cardImg ?? json['cardImageUrl'],
      backImageUrl: backImg ?? json['backImageUrl'],
      personName: json['personName'] ?? '',
      companyName: json['companyName'] ?? '',
      designation: json['designation'] ?? '',
      phone: json['phone'] ?? '',
      alternativePhone: json['alternativePhone'] ?? '',
      email: json['email'] ?? '',
      website: json['website'] ?? '',
      address: json['address'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      country: json['country'] ?? 'India',
      gstNumber: json['gstNumber'] ?? '',
      category: json['category'] ?? 'Business',
      servicesOffered: json['servicesOffered'] ?? '',
      notes: json['notes'] ?? '',
      hasMultiplePersons: json['hasMultiplePersons'] == true || persons.length >= 2,
      detectedPersons: persons,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'personName': personName,
      'companyName': companyName,
      'designation': designation,
      'phone': phone,
      'alternativePhone': alternativePhone,
      'email': email,
      'website': website,
      'address': address,
      'city': city,
      'state': state,
      'country': country,
      'gstNumber': gstNumber,
      'category': category,
      'servicesOffered': servicesOffered,
      'notes': notes,
      if (businessCardId != null) 'businessCardId': businessCardId,
    };
  }

  ContactModel copyWith({
    String? id,
    String? businessCardId,
    String? cardImageUrl,
    String? backImageUrl,
    String? personName,
    String? companyName,
    String? designation,
    String? phone,
    String? alternativePhone,
    String? email,
    String? website,
    String? address,
    String? city,
    String? state,
    String? country,
    String? gstNumber,
    String? category,
    String? servicesOffered,
    String? notes,
    bool? hasMultiplePersons,
    List<DetectedPerson>? detectedPersons,
    DateTime? createdAt,
  }) {
    return ContactModel(
      id: id ?? this.id,
      businessCardId: businessCardId ?? this.businessCardId,
      cardImageUrl: cardImageUrl ?? this.cardImageUrl,
      backImageUrl: backImageUrl ?? this.backImageUrl,
      personName: personName ?? this.personName,
      companyName: companyName ?? this.companyName,
      designation: designation ?? this.designation,
      phone: phone ?? this.phone,
      alternativePhone: alternativePhone ?? this.alternativePhone,
      email: email ?? this.email,
      website: website ?? this.website,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      gstNumber: gstNumber ?? this.gstNumber,
      category: category ?? this.category,
      servicesOffered: servicesOffered ?? this.servicesOffered,
      notes: notes ?? this.notes,
      hasMultiplePersons: hasMultiplePersons ?? this.hasMultiplePersons,
      detectedPersons: detectedPersons ?? this.detectedPersons,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
