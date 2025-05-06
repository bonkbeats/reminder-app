import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_cropper/image_cropper.dart';
import '../services/ocr.dart';
import '../services/notification.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  File? _image;
  String _extractedDate = 'No date detected';
  final ImagePicker _picker = ImagePicker();
  final List<Map<String, dynamic>> _savedProducts = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    NotificationService.initializeNotifications();
    _requestNotificationPermission();

    // Load saved products
    _loadProductsFromPreferences();

    // Set up a timer to rebuild the widget every day
    _timer = Timer.periodic(const Duration(hours: 24), (timer) {
      setState(() {}); // Rebuild the widget to update expiration statuses
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // Cancel the timer when the widget is disposed
    super.dispose();
  }

  Future<void> _requestNotificationPermission() async {
    final status = await Permission.notification.status;
    print('Notification permission status: $status');
    final requestStatus = await Permission.notification.request();
    if (requestStatus.isDenied || requestStatus.isPermanentlyDenied) {
      debugPrint('Notification permission denied.');
    }
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.camera);
    if (picked != null) {
      // Crop the image
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: Colors.teal,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Crop Image',
          ),
        ],
      );

      if (croppedFile != null) {
        setState(() => _image =
            File(croppedFile.path)); // Update the image with the cropped file
        final expiryDate =
            await OcrService.processImage(File(croppedFile.path));
        if (expiryDate != null) {
          setState(() => _extractedDate = "Expiry: ${expiryDate.toString()}");
          NotificationService.scheduleReminder(
              expiryDate); // Schedule a notification
        } else {
          setState(() => _extractedDate = "No valid expiration date found.");
        }
      }
    }
  }

  Future<void> _saveProductsToPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final productsJson = jsonEncode(
      _savedProducts.map((product) {
        return {
          'image': product['image'].path, // Save the image path
          'expiryDate': product['expiryDate'],
        };
      }).toList(),
    );
    await prefs.setString('savedProducts', productsJson);
    print('Products saved to SharedPreferences.');
  }

  Future<void> _loadProductsFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final productsJson = prefs.getString('savedProducts');
    if (productsJson != null) {
      setState(() {
        _savedProducts.clear();
        _savedProducts.addAll(
          List<Map<String, dynamic>>.from(jsonDecode(productsJson))
              .map((product) {
            return {
              'image': File(product['image']), // Recreate the File object
              'expiryDate': product['expiryDate'],
            };
          }),
        );
      });
      print('Products loaded from SharedPreferences.');
    }
  }

  void _deleteProduct(int index) {
    setState(() {
      _savedProducts.removeAt(index);
    });
    _saveProductsToPreferences();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Product deleted!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.teal,
              ),
              child: const Text(
                'Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              onTap: () {
                Navigator.pop(context); // Close the drawer
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: const Text('Expiry Reminder App'),
      ),
      body: _savedProducts.isEmpty
          ? const Center(
              child: Text('No products saved yet.'),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // Number of columns
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _savedProducts.length,
              itemBuilder: (context, index) {
                final product = _savedProducts[index];
                final expiryDate = DateTime.tryParse(
                    product['expiryDate'].replaceFirst('Expiry: ', ''));
                final now = DateTime.now();

                // Check if the product is expiring in less than or equal to 30 days
                final isExpiringSoon = expiryDate != null &&
                    expiryDate.difference(now).inDays <= 30 &&
                    expiryDate.isAfter(now);

                return Card(
                  color: isExpiringSoon
                      ? Colors.orange[100]
                      : Colors.white, // Change background color
                  elevation: 4,
                  child: Column(
                    children: [
                      Expanded(
                        child: Image.file(
                          product['image'],
                          fit: BoxFit.cover,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          product['expiryDate'],
                          style: TextStyle(
                            fontSize: 14,
                            color: isExpiringSoon
                                ? Colors.orange
                                : Colors.black, // Change text color
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          _deleteProduct(index); // Call the delete method
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await _pickImage(); // Open the camera and take a picture
          if (_image != null) {
            _showDialog(context); // Show the dialog if an image is taken
          }
        },
        child: const Icon(Icons.add), // Plus icon
        tooltip: 'Capture Expiry Label',
      ),
    );
  }

  void _showDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Center(child: Text('Product Details')),
          content: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _image != null
                  ? Image.file(_image!, height: 150)
                  : const Icon(Icons.image, size: 100, color: Colors.grey),
              const SizedBox(height: 10),
              Text(
                _extractedDate,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context); // Close the dialog
                      setState(() {
                        _image = null;
                        _extractedDate = 'No date detected';
                      });
                    },
                    child: const Text('Delete'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      // Save the product to the list
                      setState(() {
                        _savedProducts.add({
                          'image': _image,
                          'expiryDate': _extractedDate,
                        });
                      });

                      // Save to SharedPreferences
                      _saveProductsToPreferences();

                      // Schedule a reminder with the extracted expiration date
                      final expiryDate = DateTime.tryParse(
                          _extractedDate.replaceFirst('Expiry: ', ''));
                      if (expiryDate != null) {
                        NotificationService.scheduleReminder(expiryDate);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text('Reminder scheduled for $expiryDate!')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Invalid expiration date. Reminder not scheduled.')),
                        );
                      }

                      Navigator.pop(context); // Close the dialog
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Product saved!')),
                      );
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
