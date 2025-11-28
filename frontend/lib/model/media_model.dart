// lib/model/media_model.dart (신규 생성)

class MediaUploadResponse {
  final int imageId;
  final String imageUrl; // 예: "/media/1/orig"
  final String thumbUrl; // 예: "/media/1/thumb"

  MediaUploadResponse({
    required this.imageId,
    required this.imageUrl,
    required this.thumbUrl,
  });

  factory MediaUploadResponse.fromJson(Map<String, dynamic> json) {
    return MediaUploadResponse(
      imageId: json['image_id'],
      imageUrl: json['image_url'],
      thumbUrl: json['thumb_url'],
      // 참고: 백엔드가 content_type, width, height도 보내지만 지금 당장 필요하진 않음
    );
  }
}