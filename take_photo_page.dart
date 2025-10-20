import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class TakePhotoPage extends StatefulWidget {
  const TakePhotoPage({super.key});

  @override
  State<TakePhotoPage> createState() => _TakePhotoPageState();
}

class _TakePhotoPageState extends State<TakePhotoPage> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  late List<CameraDescription> _cameras;
  int _selectedCameraIndex = 0;
  FlashMode _flashMode = FlashMode.off;

  @override
  void initState() {
    super.initState();
    _initializeControllerFuture = _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    _controller = CameraController(
      _cameras[_selectedCameraIndex],
      ResolutionPreset.max,
      enableAudio: false,
    );

    await _controller.initialize();
    setState(() {});
  }

  void _switchCamera() async {
    if (_cameras.length > 1) {
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
      await _controller.dispose();
      await _initializeCamera();
    }
  }

  void _toggleFlash() async {
    if (_controller.value.isInitialized) {
      FlashMode newFlashMode;
      switch (_flashMode) {
        case FlashMode.off:
          newFlashMode = FlashMode.always;
          break;
        case FlashMode.always:
          newFlashMode = FlashMode.auto;
          break;
        case FlashMode.auto:
          newFlashMode = FlashMode.torch;
          break;
        case FlashMode.torch:
          newFlashMode = FlashMode.off;
          break;
      }

      await _controller.setFlashMode(newFlashMode);
      setState(() {
        _flashMode = newFlashMode;
      });
    }
  }

  // Future<void> _pickImageFromGallery() async {
  //   final picker = ImagePicker();
  //   final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);

  //   if (pickedFile != null && mounted) {
  //     Navigator.pop(context, pickedFile.path);
  //   }
  // }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                Container(color: Colors.black),

                Column(
                  children: [
                    Expanded(flex: 2, child: Container(color: Colors.black)),
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.6,
                      width: double.infinity,
                      child: CameraPreview(_controller),
                    ),
                    Expanded(flex: 2, child: Container(color: Colors.black)),
                  ],
                ),

                /* Positioned(
                  top: 40,
                  right: 20,
                  child: IconButton(
                    icon: Icon(
                      _flashMode == FlashMode.off
                          ? Icons.flash_off
                          : _flashMode == FlashMode.always
                              ? Icons.flash_on
                              : _flashMode == FlashMode.auto
                                  ? Icons.flash_auto
                                  : Icons.highlight,
                      color: Colors.white,
                      size: 32,
                    ),
                    onPressed: _toggleFlash,
                  ),
                ), */

                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(0, 0, 0, 0.7),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // IconButton(
                        //   icon: const Icon(Icons.photo_library, color: Colors.white, size: 32),
                        //   onPressed: _pickImageFromGallery,
                        // ),

                        IconButton(
                          icon: Icon(
                            _flashMode == FlashMode.off
                                ? Icons.flash_off
                                : _flashMode == FlashMode.always
                                    ? Icons.flash_on
                                    : _flashMode == FlashMode.auto
                                        ? Icons.flash_auto
                                        : Icons.highlight,
                            color: Colors.white,
                            size: 32,
                          ),
                          onPressed: _toggleFlash,
                        ),

                        FloatingActionButton(
                          onPressed: () async {
                            try {
                              await _initializeControllerFuture;
                              final image = await _controller.takePicture();
                              if (!mounted) return;
                              if (context.mounted) {
                                Navigator.pop(context, image.path);
                              }
                            } catch (e) {
                              debugPrint("Camera error: $e");
                            }
                          },
                          backgroundColor: Colors.white,
                          child: const Icon(Icons.camera, color: Colors.black, size: 42.0),
                        ),

                        IconButton(
                          icon: const Icon(
                            CupertinoIcons.camera_rotate_fill,
                            color: Colors.white,
                            size: 32,
                          ),
                          onPressed: _switchCamera,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}