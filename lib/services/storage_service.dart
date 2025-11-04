import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  Future<String> uploadImage(File imageFile, String userId) async {
    final ref = FirebaseStorage.instance
        .ref()
        .child('user_images')
        .child('$userId.jpg');
    await ref.putFile(imageFile);
    return await ref.getDownloadURL();
  }
}
