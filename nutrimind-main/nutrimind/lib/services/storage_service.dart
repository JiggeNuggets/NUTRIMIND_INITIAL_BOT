import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  Future<XFile?> pickImage(ImageSource source) {
    return _picker.pickImage(
      source: source,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 85,
    );
  }

  Future<String> uploadProfileImage(String uid, XFile file) async {
    final ref = _storage.ref('profile_images/$uid/profile.jpg');
    final bytes = await file.readAsBytes();
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  Future<String> uploadPostImage(String uid, String imageId, XFile file) async {
    final ref = _storage.ref('post_images/$uid/$imageId.jpg');
    final bytes = await file.readAsBytes();
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }
}
