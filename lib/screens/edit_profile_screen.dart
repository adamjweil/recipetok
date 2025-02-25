import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../utils/custom_cache_manager.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EditProfileScreen({
    super.key,
    required this.userData,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _bioController;
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  String? _gender;
  DateTime? _birthDate;
  bool _isLoading = false;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _bioController = TextEditingController(text: widget.userData['bio'] ?? '');
    _firstNameController = TextEditingController(text: widget.userData['firstName'] ?? '');
    _lastNameController = TextEditingController(text: widget.userData['lastName'] ?? '');
    _gender = widget.userData['gender'];
    _birthDate = widget.userData['birthDate'] != null 
        ? DateTime.parse(widget.userData['birthDate'])
        : null;
  }

  @override
  void dispose() {
    _bioController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    await showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 300,
          color: Colors.white,
          child: Column(
            children: [
              Container(
                height: 50,
                color: const Color(0xFFF9F9F9),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    CupertinoButton(
                      child: const Text('OK'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: _birthDate ?? DateTime.now(),
                  onDateTimeChanged: (DateTime newDate) {
                    setState(() {
                      _birthDate = newDate;
                    });
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveProfile() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Create display name from first and last name
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final displayName = '$firstName $lastName'.trim();

      // Update Firestore user data
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'bio': _bioController.text,
        'firstName': firstName,
        'lastName': lastName,
        'displayName': displayName,
        'gender': _gender,
        'birthDate': _birthDate?.toIso8601String(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              top: 20,
              right: 20,
              left: 20,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(
              top: 20,
              right: 20,
              left: 20,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateProfilePhoto() async {
    final ImagePicker picker = ImagePicker();
    
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (image == null) return;

      setState(() => _isUploadingImage = true);

      final user = FirebaseAuth.instance.currentUser;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('user_avatars')
          .child('${user?.uid ?? 'unknown'}.jpg');

      await storageRef.putFile(File(image.path));
      final downloadUrl = await storageRef.getDownloadURL();

      // Update Firebase Auth photo URL
      await user?.updatePhotoURL(downloadUrl);
      
      // Update Firestore user avatar URL
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .update({
        'avatarUrl': downloadUrl,
      });

      if (mounted) {
        setState(() => _isUploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated successfully'),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              top: 20,
              right: 20,
              left: 20,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploadingImage = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile photo: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(
              top: 20,
              right: 20,
              left: 20,
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteProfile() async {
    // Show confirmation dialog
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Profile'),
          content: const Text(
            'Are you sure you want to delete your profile? This action cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmDelete != true) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Re-authenticate user
      try {
        // Show re-authentication dialog
        final credentials = await showDialog<AuthCredential>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            final passwordController = TextEditingController();
            return AlertDialog(
              title: const Text('Confirm Your Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'For security, please enter your password to continue.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    onSubmitted: (value) {
                      Navigator.of(context).pop(
                        EmailAuthProvider.credential(
                          email: user.email!,
                          password: value,
                        ),
                      );
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: const Text('Confirm'),
                  onPressed: () {
                    Navigator.of(context).pop(
                      EmailAuthProvider.credential(
                        email: user.email!,
                        password: passwordController.text,
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );

        if (credentials == null) {
          setState(() => _isLoading = false);
          return;
        }

        // Re-authenticate
        await user.reauthenticateWithCredential(credentials);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Incorrect password. Please try again.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() => _isLoading = false);
        }
        return;
      }

      // Delete user's profile photo from storage if it exists
      if (user.photoURL != null) {
        try {
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('user_avatars')
              .child('${user.uid}.jpg');
          await storageRef.delete();
        } catch (e) {
          // Ignore storage deletion errors
          print('Error deleting profile photo: $e');
        }
      }

      // Delete user document from Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .delete();

      // Delete Firebase Auth user
      await user.delete();

      // Sign out the user
      await FirebaseAuth.instance.signOut();

      if (mounted) {
        // Navigate to login or home screen
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login', // Replace with your login route name
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting profile: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(
              top: 20,
              right: 20,
              left: 20,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveProfile,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Photo Section
          Center(
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.grey[300]!,
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: user?.photoURL != null
                        ? NetworkImage(user!.photoURL!)
                        : null,
                    child: user?.photoURL == null
                        ? const Icon(Icons.person, size: 50)
                        : null,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                    child: _isUploadingImage
                        ? const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(
                              Icons.camera_alt,
                              size: 20,
                              color: Colors.white,
                            ),
                            onPressed: _updateProfilePhoto,
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // First Name field
          TextField(
            controller: _firstNameController,
            decoration: const InputDecoration(
              labelText: 'First Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          // Last Name field
          TextField(
            controller: _lastNameController,
            decoration: const InputDecoration(
              labelText: 'Last Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          // Birthday field
          GestureDetector(
            onTap: () => _selectDate(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Text(
                    _birthDate == null
                        ? 'Select Birthday'
                        : '${_birthDate!.month}/${_birthDate!.day}/${_birthDate!.year}',
                    style: TextStyle(
                      color: _birthDate == null ? Colors.grey[600] : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Gender selection
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'Gender',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
              ...['Man', 'Woman', 'Prefer not to say'].map((option) {
                return RadioListTile<String>(
                  title: Text(option),
                  value: option,
                  groupValue: _gender,
                  onChanged: (value) {
                    setState(() {
                      _gender = value;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                  visualDensity: const VisualDensity(
                    horizontal: VisualDensity.minimumDensity,
                    vertical: VisualDensity.minimumDensity,
                  ),
                );
              }).toList(),
            ],
          ),
          const SizedBox(height: 16),
          // Bio field
          TextField(
            controller: _bioController,
            decoration: const InputDecoration(
              labelText: 'Bio',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 32),
          // Delete Profile Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextButton(
              onPressed: _isLoading ? null : _deleteProfile,
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Colors.red),
                ),
              ),
              child: const Text(
                'Delete Profile',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
} 