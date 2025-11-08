import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/profile_service.dart';
import '../services/storage_service.dart';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const EditProfilePage(this.userData, {super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final profileService = ProfileSercice();
  final storageService = StorageService();

  late TextEditingController nameCtrl;
  late TextEditingController bioCtrl;
  late TextEditingController phoneCtrl;

  File? newImage;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.userData["name"] ?? "");
    bioCtrl = TextEditingController(text: widget.userData["bio"] ?? "");
    phoneCtrl = TextEditingController(text: widget.userData["phone"] ?? "");
  }

  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => newImage = File(picked.path));
  }

  Future<void> saveProfile() async {
    String imageUrl = widget.userData["imageUrl"] ?? "";

    if (newImage != null) {
      imageUrl = await storageService.uploadImage(
        newImage!,
        widget.userData["uid"] ?? "",
      );
    }

    await profileService.updateUserData({
      "name": nameCtrl.text,
      "bio": bioCtrl.text,
      "phone": phoneCtrl.text,
      "imageUrl": imageUrl,
    });

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    String currentImage = newImage != null
        ? ""
        : (widget.userData["imageUrl"] ?? "");

    return Scaffold(
      appBar: AppBar(title: const Text("Edit Profile")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            InkWell(
              onTap: pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundImage: newImage != null
                    ? FileImage(newImage!)
                    : (currentImage.isNotEmpty
                              ? NetworkImage(currentImage)
                              : null)
                          as ImageProvider?,
                child: currentImage.isEmpty && newImage == null
                    ? const Icon(Icons.camera_alt, size: 40)
                    : null,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: "Name"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: "Phone"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: bioCtrl,
              decoration: const InputDecoration(labelText: "Bio"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary, // Fill color
                foregroundColor: Theme.of(
                  context,
                ).colorScheme.onPrimary, // Text color
                padding: const EdgeInsets.symmetric(
                  horizontal: 60,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }
}
