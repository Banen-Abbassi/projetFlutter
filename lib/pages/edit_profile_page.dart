import 'dart:io';
import 'dart:convert'; 
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/profile_service.dart';
import 'loading_page.dart';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const EditProfilePage(this.userData, {super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final profileService = ProfileSercice();

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
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );
    if (picked != null) {
      setState(() => newImage = File(picked.path));
    }
  }

  Future<void> saveProfile() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoadingPage()),
    );

    Map<String, dynamic> dataToUpdate = {
      "name": nameCtrl.text,
      "bio": bioCtrl.text,
      "phone": phoneCtrl.text,
    };

    if (newImage != null) {
      final imageBytes = await newImage!.readAsBytes();
      
      String base64String = base64Encode(imageBytes);

      dataToUpdate['imageUrlBase64'] = base64String;
    }

    await profileService.updateUserData(dataToUpdate);

    await Future.delayed(const Duration(milliseconds: 100));

    Navigator.pop(context); 
    Navigator.pop(context); 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile", style: TextStyle(color: Colors.white)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              InkWell(
                onTap: pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: newImage != null ? FileImage(newImage!) : null,
                  child: newImage == null
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
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text("Save"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}