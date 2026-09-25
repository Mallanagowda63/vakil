import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/registration_data.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import '../widgets/step_progress_header.dart';
import 'advocate_verification_screen.dart';

class FaceVerificationScreen extends StatefulWidget {
  const FaceVerificationScreen({super.key});

  @override
  State<FaceVerificationScreen> createState() => _FaceVerificationScreenState();
}

enum _FaceState { idle, captured, verifying, verified }

class _FaceVerificationScreenState extends State<FaceVerificationScreen> {
  File? _photo;
  _FaceState _state = _FaceState.idle;

  Future<void> _capture(ImageSource source) async {
    final picker = ImagePicker();
    final img = await picker.pickImage(
      source: source,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.front,
    );
    if (img == null) return;
    setState(() {
      _photo = File(img.path);
      _state = _FaceState.captured;
    });
    _runVerification();
  }

  Future<void> _runVerification() async {
    setState(() => _state = _FaceState.verifying);
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    setState(() => _state = _FaceState.verified);
    context.read<RegistrationData>().saveFaceVerification(_photo!);
  }

  void _continue() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AdvocateVerificationScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final verified = _state == _FaceState.verified;
    final verifying = _state == _FaceState.verifying;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Column(
          children: [
            const StepProgressHeader(
              step: 2,
              totalSteps: 5,
              title: 'Face Verification',
              subtitle: 'Take a clear photo of your face to verify your identity '
                  'and help patients recognize you.',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 190,
                          height: 190,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: verified ? AppColors.success : AppColors.primary,
                              width: 3,
                            ),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: ClipOval(
                            child: _photo != null
                                ? Image.file(_photo!, fit: BoxFit.cover)
                                : Container(
                                    color: const Color(0xFFE9ECF3),
                                    child: const Icon(Icons.face_outlined, size: 70, color: AppColors.textSecondary),
                                  ),
                          ),
                        ),
                        if (verifying)
                          const SizedBox(
                            width: 190,
                            height: 190,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          ),
                        if (verified)
                          Positioned(
                            bottom: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check, color: Colors.white, size: 18),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      verifying
                          ? 'Verifying your identity...'
                          : verified
                              ? 'Face verified successfully'
                              : 'Position your face within the circle',
                      style: TextStyle(
                        color: verified ? AppColors.success : AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _tipRow('Make sure you are in a well-lit area'),
                    _tipRow('Remove glasses, masks, or hats'),
                    _tipRow('Look straight ahead and keep a neutral expression'),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                children: [
                  if (!verified)
                    PrimaryButton(
                      label: 'Take Photo',
                      loading: verifying,
                      onPressed: verifying ? null : () => _capture(ImageSource.camera),
                    )
                  else
                    PrimaryButton(label: 'Continue', onPressed: _continue),
                  if (!verified && !verifying) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => _capture(ImageSource.gallery),
                      child: const Text('Upload from Gallery'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tipRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 18, color: AppColors.success),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}
