import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../services/meter_ocr_service.dart';
import '../../services/meter_reading_extractor.dart';
import 'widgets/meter_frame_overlay.dart';
import '../../core/l10n/l10n.dart';

/// What the camera screen hands back to Add reading.
class MeterScanOutcome {
  const MeterScanOutcome({required this.imagePath, required this.result});

  final String imagePath;
  final MeterReadResult result;
}

/// Full-screen live camera for photographing the meter display.
/// Pops with a [MeterScanOutcome], or null if the user gives up.
class MeterCameraScreen extends StatefulWidget {
  const MeterCameraScreen({super.key, this.lastReading, this.daysSinceLast = 30});

  final double? lastReading;
  final int daysSinceLast;

  @override
  State<MeterCameraScreen> createState() => _MeterCameraScreenState();
}

enum _CamState { starting, ready, noPermission, noCamera, failed }

class _MeterCameraScreenState extends State<MeterCameraScreen> with WidgetsBindingObserver {
  final _ocr = const MeterOcrService();
  CameraController? _controller;
  _CamState _state = _CamState.starting;
  String? _error;

  bool _torch = false;
  bool _reading = false;
  String? _hint;

  double _minZoom = 1;
  double _maxZoom = 1;
  double _zoom = 1;

  Offset? _focusPoint;
  Timer? _focusTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      if (c == null) return;
      _controller = null;
      _torch = false;
      c.dispose();
      if (mounted) setState(() => _state = _CamState.starting);
    } else if (state == AppLifecycleState.resumed && _controller == null && !_reading) {
      // Also retries after the user granted permission in Settings.
      _start();
    }
  }

  bool _starting = false;

  Future<void> _start() async {
    // The permission dialog pauses the app; don't start twice.
    if (_starting) return;
    _starting = true;
    setState(() {
      _state = _CamState.starting;
      _error = null;
    });
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _state = _CamState.noCamera);
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      // Flash glare on the meter glass hides digits: flash only as a torch,
      // and only when the user asks for it.
      await _try(() => controller.setFlashMode(FlashMode.off));
      await _try(() => controller.lockCaptureOrientation(DeviceOrientation.portraitUp));
      await _try(() => controller.setFocusMode(FocusMode.auto));
      _minZoom = await controller.getMinZoomLevel().catchError((_) => 1.0);
      _maxZoom = await controller.getMaxZoomLevel().catchError((_) => 1.0);
      // Meters are usually read from arm's length; a little zoom helps.
      _zoom = (_minZoom * 1.5).clamp(_minZoom, _maxZoom > 4 ? 4.0 : _maxZoom);
      await _try(() => controller.setZoomLevel(_zoom));

      setState(() {
        _controller = controller;
        _state = _CamState.ready;
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      final denied = e.code.startsWith('CameraAccess') || e.code.toLowerCase().contains('permission');
      setState(() {
        _state = denied ? _CamState.noPermission : _CamState.failed;
        _error = e.description ?? e.code;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _CamState.failed;
          _error = '$e';
        });
      }
    } finally {
      _starting = false;
    }
  }

  static Future<void> _try(Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      debugPrint('Camera option not supported: {0}'.trf({'0': e}));
    }
  }

  Future<void> _toggleTorch() async {
    final c = _controller;
    if (c == null) return;
    HapticFeedback.selectionClick();
    final next = !_torch;
    try {
      await c.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      setState(() => _torch = next);
    } catch (_) {
      _showHint('This phone has no flashlight'.tr);
    }
  }

  Future<void> _setZoom(double z) async {
    final c = _controller;
    if (c == null) return;
    setState(() => _zoom = z);
    await _try(() => c.setZoomLevel(z));
  }

  Future<void> _focusAt(Offset local, Size size) async {
    final c = _controller;
    if (c == null || size.isEmpty) return;
    final p = Offset((local.dx / size.width).clamp(0.0, 1.0), (local.dy / size.height).clamp(0.0, 1.0));
    HapticFeedback.selectionClick();
    setState(() => _focusPoint = local);
    _focusTimer?.cancel();
    _focusTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _focusPoint = null);
    });
    if (c.value.focusPointSupported) await _try(() => c.setFocusPoint(p));
    if (c.value.exposurePointSupported) await _try(() => c.setExposurePoint(p));
  }

  Future<void> _capture() async {
    final c = _controller;
    if (c == null || _reading || c.value.isTakingPicture) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _reading = true;
      _hint = null;
    });
    try {
      final file = await c.takePicture();
      await _analyse(file.path, framed: true);
    } on CameraException catch (e) {
      _showHint('Couldn\'t take the photo ({0}). Try again.'.trf({'0': e.description ?? e.code}));
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  Future<void> _fromGallery() async {
    if (_reading) return;
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
      maxWidth: 3000,
      requestFullMetadata: false,
    );
    if (file == null || !mounted) return;
    setState(() => _reading = true);
    try {
      await _analyse(file.path, framed: false);
    } finally {
      if (mounted) {
        setState(() => _reading = false);
        // The gallery paused the app and released the camera.
        if (_controller == null && _state == _CamState.starting) _start();
      }
    }
  }

  Future<void> _analyse(String path, {required bool framed}) async {
    try {
      final result = await _ocr.read(
        path,
        lastReading: widget.lastReading,
        daysSinceLast: widget.daysSinceLast,
        framed: framed,
      );
      if (!mounted) return;
      if (result.isEmpty) {
        HapticFeedback.heavyImpact();
        _showHint('Couldn\'t read the numbers. Move closer, fill the frame and avoid glare.'.tr);
        return;
      }
      HapticFeedback.lightImpact();
      if (_torch) await _try(() => _controller!.setFlashMode(FlashMode.off));
      if (!mounted) return;
      Navigator.of(context).pop(MeterScanOutcome(imagePath: path, result: result));
    } catch (e) {
      _showHint('Couldn\'t read the photo. Try again.'.tr);
      debugPrint('Meter OCR failed: {0}'.trf({'0': e}));
    }
  }

  void _showHint(String text) {
    if (mounted) setState(() => _hint = text);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Center(child: _preview()),
            _topBar(context),
            if (_state == _CamState.ready) _bottomBar(context),
            if (_reading) const _ReadingVeil(),
          ],
        ),
      ),
    );
  }

  Widget _preview() {
    final c = _controller;
    switch (_state) {
      case _CamState.starting:
        return const CircularProgressIndicator(color: AppColors.amber);
      case _CamState.noPermission:
        return _Problem(
          icon: Icons.no_photography_rounded,
          title: 'Camera permission needed'.tr,
          message: 'Allow camera access to scan your meter.\nIf you chose "Don\'t allow", turn it on in Settings → Apps → Bijli Hisaab → Permissions.'.tr,
          primaryLabel: 'Try again'.tr,
          onPrimary: _start,
          onGallery: _fromGallery,
        );
      case _CamState.noCamera:
        return _Problem(
          icon: Icons.videocam_off_rounded,
          title: 'No camera found'.tr,
          message: 'You can pick a photo of the meter from your gallery instead.'.tr,
          onGallery: _fromGallery,
        );
      case _CamState.failed:
        return _Problem(
          icon: Icons.error_outline_rounded,
          title: 'Camera didn\'t start'.tr,
          message: _error ?? 'Something went wrong.'.tr,
          primaryLabel: 'Try again'.tr,
          onPrimary: _start,
          onGallery: _fromGallery,
        );
      case _CamState.ready:
        if (c == null || !c.value.isInitialized) {
          return const CircularProgressIndicator(color: AppColors.amber);
        }
        return CameraPreview(
          c,
          child: LayoutBuilder(
            builder: (context, box) {
              final size = box.biggest;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => _focusAt(d.localPosition, size),
                child: MeterFrameOverlay(focusPoint: _focusPoint, hint: _hint),
              );
            },
          ),
        );
    }
  }

  Widget _topBar(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: Row(
            children: [
              _RoundButton(
                icon: Icons.close_rounded,
                tooltip: 'Close'.tr,
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Text(
                  'Scan meter'.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              if (_state == _CamState.ready)
                _RoundButton(
                  icon: _torch ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
                  tooltip: _torch ? 'Turn light off'.tr : 'Turn light on'.tr,
                  active: _torch,
                  onPressed: _toggleTorch,
                )
              else
                const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomBar(BuildContext context) {
    final canZoom = _maxZoom > _minZoom + 0.1;
    final zoomCap = _maxZoom > 6 ? 6.0 : _maxZoom;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: 0), Colors.black.withValues(alpha: 0.75)],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (canZoom)
                  Row(
                    children: [
                      const Icon(Icons.zoom_out_rounded, color: Colors.white70, size: 20),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: AppColors.amber,
                            inactiveTrackColor: Colors.white24,
                            thumbColor: AppColors.amber,
                            overlayColor: AppColors.amber.withValues(alpha: 0.2),
                            trackHeight: 3,
                          ),
                          child: Slider(
                            value: _zoom.clamp(_minZoom, zoomCap),
                            min: _minZoom,
                            max: zoomCap,
                            onChanged: _setZoom,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 44,
                        child: Text(
                          '${_zoom.toStringAsFixed(1)}×',
                          textAlign: TextAlign.end,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _RoundButton(
                      icon: Icons.photo_library_rounded,
                      tooltip: 'Pick from gallery'.tr,
                      onPressed: _fromGallery,
                      size: 52,
                    ),
                    _Shutter(onPressed: _reading ? null : _capture),
                    const SizedBox(width: 52),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Shutter extends StatelessWidget {
  const _Shutter({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Take photo'.tr,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 78,
          height: 78,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: onPressed == null ? Colors.white38 : AppColors.amber,
            ),
            child: const Icon(Icons.bolt_rounded, color: AppColors.navy, size: 30),
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
    this.size = 48,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? AppColors.amber : Colors.black.withValues(alpha: 0.45),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, color: active ? AppColors.navy : Colors.white, size: size * 0.48),
          ),
        ),
      ),
    );
  }
}

class _Problem extends StatelessWidget {
  const _Problem({
    required this.icon,
    required this.title,
    required this.message,
    required this.onGallery,
    this.primaryLabel,
    this.onPrimary,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.amber, size: 48),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 24),
          if (onPrimary != null) ...[
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.amber,
                foregroundColor: AppColors.navy,
                minimumSize: const Size(220, 50),
              ),
              onPressed: onPrimary,
              child: Text(primaryLabel ?? 'Try again'.tr),
            ),
            const SizedBox(height: 10),
          ],
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white38),
              minimumSize: const Size(220, 50),
            ),
            onPressed: onGallery,
            icon: const Icon(Icons.photo_library_rounded),
            label: Text('Pick from gallery'.tr),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Type it in instead'.tr, style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}

/// Dark veil with a spinner while ML Kit reads the photo.
class _ReadingVeil extends StatelessWidget {
  const _ReadingVeil();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(color: AppColors.amber, strokeWidth: 3.5),
            ),
            SizedBox(height: 16),
            Text(
              'Reading the meter…'.tr,
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
