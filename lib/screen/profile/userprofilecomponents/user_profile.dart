import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class UserProfile extends StatefulWidget {
  const UserProfile({super.key});

  @override
  State<UserProfile> createState() => _UserProfileState();
}

class _UserProfileState extends State<UserProfile> {
  String userId = '';
  String profileImageUrl = '';
  String username = '';
  String mobileNumber = '';
  String email = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeUserId();
  }

  Future<void> _initializeUserId() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      setState(() {
        userId = currentUser.uid;
      });
      _fetchUserProfile();
    } else {
      print('No user logged in!');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _fetchUserProfile() async {
    if (userId.isEmpty) {
      print('UserId is empty!');
      return;
    }

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        setState(() {
          profileImageUrl = userDoc['profileImageUrl'] ?? '';
          username = userDoc['fullName'] ?? '';
          mobileNumber = userDoc['phone'] ?? '';
          email = userDoc['email'] ?? '';
          isLoading = false;
        });
      } else {
        print('User document does not exist!');
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching user profile: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _updateUserProfile(String field, String value) async {
    if (userId.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({field: value});
      print('$field updated successfully!');
    } catch (e) {
      print('Error updating $field: $e');
    }
  }

  Future<String?> _uploadImageToCloudinary(File image) async {
    String cloudName = 'dm0brovfk';
    String apiKey = '996164835147661';
    String apiSecret = '6unpohh6GYqJYW027mDU2vgl03E';

    final url =
        Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    String auth = base64Encode(utf8.encode('$apiKey:$apiSecret'));

    var request = http.MultipartRequest('POST', url)
      ..headers['Authorization'] = 'Basic $auth'
      ..fields['upload_preset'] = 'lginmk6z'
      ..files.add(await http.MultipartFile.fromPath('file', image.path));

    var response = await request.send();

    if (response.statusCode == 200) {
      final responseData = await response.stream.bytesToString();
      final jsonResponse = jsonDecode(responseData);
      return jsonResponse['secure_url'];
    } else {
      print('Failed to upload image: ${response.statusCode}');
      print(await response.stream.bytesToString());
      return null;
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      String? imageUrl = await _uploadImageToCloudinary(File(image.path));
      if (imageUrl != null) {
        setState(() {
          profileImageUrl = imageUrl;
        });
        _updateUserProfile('profileImageUrl', imageUrl);
      }
    }
  }

  void _editProfileField(String title, String initialValue, String field) {
    showDialog(
      context: context,
      builder: (context) {
        TextEditingController controller =
            TextEditingController(text: initialValue);
        return AlertDialog(
          title: Text('Edit $title'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: 'Enter new $title'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  switch (field) {
                    case 'username':
                      username = controller.text;
                      break;
                    case 'mobileNumber':
                      mobileNumber = controller.text;
                      break;
                    case 'email':
                      email = controller.text;
                      break;
                  }
                });
                _updateUserProfile(field, controller.text);
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text(
          'Profile Settings',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildSection([
              _buildSettingItem(
                'Account Type',
                'T-CASH Premium',
                showArrow: false,
                isBlue: true,
              ),
              _buildSettingItem(
                'Profile Picture',
                '',
                showArrow: true,
                leading: CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.grey,
                  backgroundImage: profileImageUrl.isNotEmpty
                      ? NetworkImage(profileImageUrl)
                      : null,
                  child: profileImageUrl.isEmpty
                      ? const Icon(Icons.person, size: 40, color: Colors.white)
                      : null,
                ),
                onTap: _pickImage,
              ),
              _buildSettingItem(
                'Username',
                username,
                showArrow: true,
                isBlue: true,
                onTap: () =>
                    _editProfileField('Username', username, 'username'),
              ),
              _buildSettingItem(
                'Mobile Number',
                mobileNumber,
                showArrow: true,
                onTap: () => _editProfileField(
                    'Mobile Number', mobileNumber, 'mobileNumber'),
              ),
              _buildSettingItem(
                'Email Address',
                email,
                showArrow: true,
                onTap: () => _editProfileField('Email Address', email, 'email'),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingItem(String title, String value,
      {bool showArrow = true,
      Widget? leading,
      bool isBlue = false,
      VoidCallback? onTap}) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: ListTile(
        leading: leading,
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: isBlue ? Colors.blue : Colors.grey[600],
              ),
            ),
            if (showArrow)
              const Icon(
                Icons.chevron_right,
                color: Colors.grey,
              ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
