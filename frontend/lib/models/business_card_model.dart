class BusinessCardModel {
  final String id;
  final String originalImage;
  final String extractedText;
  final String processingStatus;
  final DateTime? createdAt;

  BusinessCardModel({
    required this.id,
    required this.originalImage,
    required this.extractedText,
    required this.processingStatus,
    this.createdAt,
  });

  factory BusinessCardModel.fromJson(Map<String, dynamic> json) {
    return BusinessCardModel(
      id: json['_id'] ?? json['id'] ?? '',
      originalImage: json['originalImage'] ?? '',
      extractedText: json['extractedText'] ?? '',
      processingStatus: json['processingStatus'] ?? 'completed',
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
    );
  }
}
