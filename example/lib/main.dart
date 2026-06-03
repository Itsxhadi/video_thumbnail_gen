import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'dart:io';

import 'package:video_thumbnail_gen/video_thumbnail_gen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:open_filex/open_filex.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────

const Color _bg = Color(0xFF080808);
const Color _surface = Color(0xFF111111);
const Color _card = Color(0xFF161616);
const Color _border = Color(0xFF242424);
const Color _accent = Color(0xFF818CF8); // indigo-400
const Color _muted = Color(0xFF6B7280);
const Color _dim = Color(0xFF9CA3AF);
const Color _errClr = Color(0xFFEF4444);

// ─── Localization ─────────────────────────────────────────────────────────────

enum AppLanguage { english, arabic, spanish }

class Localization {
  static const Map<AppLanguage, Map<String, String>> _v = {
    AppLanguage.english: {
      'title': 'Thumbnail Plus',
      'video_uri': 'Video URL or file path',
      'max_height': 'Height  {}px',
      'original_height': 'Height  Auto',
      'max_width': 'Width  {}px',
      'original_width': 'Width  Auto',
      'time_ms': 'Position  {}ms',
      'beginning_video': 'Position  Start',
      'quality': 'Quality  {}%',
      'format': 'Format',
      'data_btn': 'Get Data',
      'file_btn': 'Save',
      'settings': 'Settings',
      'error': 'Error: {}',
      'image_data_size': '{} · {}×{}px',
      'image_file_size': '{} · {}×{}px',
      'toast_saved': 'Thumbnail saved',
      'empty_title': 'No thumbnail yet',
      'empty_hint':
          'Paste a video URL above, then tap\nGet Data (memory) or Save (file).',
    },
    AppLanguage.arabic: {
      'title': 'مصمم المصغرات بلس',
      'video_uri': 'رابط الفيديو أو المسار المحلي',
      'max_height': 'الارتفاع  {} بكسل',
      'original_height': 'الارتفاع  تلقائي',
      'max_width': 'العرض  {} بكسل',
      'original_width': 'العرض  تلقائي',
      'time_ms': 'الموضع  {} مللي ثانية',
      'beginning_video': 'الموضع  البداية',
      'quality': 'الجودة  {}%',
      'format': 'الصيغة',
      'data_btn': 'جلب',
      'file_btn': 'حفظ',
      'settings': 'الإعدادات',
      'error': 'خطأ: {}',
      'image_data_size': '{} · {}×{}بكسل',
      'image_file_size': '{} · {}×{}بكسل',
      'toast_saved': 'تم الحفظ',
      'empty_title': 'لا توجد صورة مصغرة',
      'empty_hint':
          'الصق رابط الفيديو أعلاه، ثم اضغط\nجلب (ذاكرة) أو حفظ (ملف).',
    },
    AppLanguage.spanish: {
      'title': 'Miniaturas Plus',
      'video_uri': 'URL de video o ruta de archivo',
      'max_height': 'Altura  {}px',
      'original_height': 'Altura  Auto',
      'max_width': 'Ancho  {}px',
      'original_width': 'Ancho  Auto',
      'time_ms': 'Posición  {}ms',
      'beginning_video': 'Posición  Inicio',
      'quality': 'Calidad  {}%',
      'format': 'Formato',
      'data_btn': 'Obtener',
      'file_btn': 'Guardar',
      'settings': 'Ajustes',
      'error': 'Error: {}',
      'image_data_size': '{} · {}×{}px',
      'image_file_size': '{} · {}×{}px',
      'toast_saved': 'Miniatura guardada',
      'empty_title': 'Sin miniatura aún',
      'empty_hint':
          'Pega una URL de video arriba, luego\ntoca Obtener (memoria) o Guardar (archivo).',
    },
  };

  static String getText(String key, AppLanguage lang, [List<dynamic>? args]) {
    String t = _v[lang]?[key] ?? _v[AppLanguage.english]![key]!;
    if (args != null)
      for (final a in args) t = t.replaceFirst('{}', a.toString());
    return t;
  }

  static TextDirection getDir(AppLanguage lang) =>
      lang == AppLanguage.arabic ? TextDirection.rtl : TextDirection.ltr;
}

// ─── Entry point ──────────────────────────────────────────────────────────────

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  AppLanguage _lang = AppLanguage.english;
  bool _initialized = false;
  bool _showOnboarding = true;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shown = prefs.getBool('onboarding_shown') ?? false;
      if (mounted) {
        setState(() {
          _showOnboarding = !shown;
          _initialized = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _initialized = true;
        });
      }
    }
  }

  Future<void> _completeOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_shown', true);
    } catch (_) {}
    if (mounted) {
      setState(() {
        _showOnboarding = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return MaterialApp(
        title: 'Thumbnail Plus',
        debugShowCheckedModeBanner: false,
        theme: _theme(),
        home: const Scaffold(body: _LoadingCard()),
      );
    }

    return MaterialApp(
      title: 'Thumbnail Plus',
      debugShowCheckedModeBanner: false,
      theme: _theme(),
      home: _showOnboarding
          ? OnboardingScreen(onComplete: _completeOnboarding)
          : DemoHome(
              language: _lang,
              onChangeLang: (l) => setState(() => _lang = l),
            ),
    );
  }

  static ThemeData _theme() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _bg,
        colorScheme: const ColorScheme.dark(
          primary: _accent,
          surface: _surface,
          onSurface: Colors.white,
          error: _errClr,
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: _accent,
          inactiveTrackColor: _border,
          thumbColor: _accent,
          overlayColor: Color(0x1A818CF8),
          trackHeight: 2,
        ),
        radioTheme: RadioThemeData(
          fillColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? _accent : _muted,
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        drawerTheme: const DrawerThemeData(backgroundColor: _surface),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: _card,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: _border),
          ),
        ),
      );
}

// ─── Data models ──────────────────────────────────────────────────────────────

class ThumbnailRequest {
  final String video;
  final String? thumbnailPath;
  final ImageFormat imageFormat;
  final int maxHeight;
  final int maxWidth;
  final int timeMs;
  final int quality;
  final AppLanguage language;

  const ThumbnailRequest({
    required this.video,
    this.thumbnailPath,
    required this.imageFormat,
    required this.maxHeight,
    required this.maxWidth,
    required this.timeMs,
    required this.quality,
    required this.language,
  });
}

class ThumbnailResult {
  final Image image;
  final int dataSize;
  final int height;
  final int width;
  final String? filePath; // non-null only when saved to disk

  const ThumbnailResult({
    required this.image,
    required this.dataSize,
    required this.height,
    required this.width,
    this.filePath,
  });
}

Future<ThumbnailResult> genThumbnail(ThumbnailRequest r) async {
  Uint8List? bytes;
  String? savedPath;
  final completer = Completer<ThumbnailResult>();

  if (r.thumbnailPath != null) {
    // ── Save to file ──────────────────────────────────────────────────────────
    final path = await VideoThumbnail.thumbnailFile(
      video: r.video,
      thumbnailPath: r.thumbnailPath,
      imageFormat: r.imageFormat,
      maxHeight: r.maxHeight,
      maxWidth: r.maxWidth,
      timeMs: r.timeMs,
      quality: r.quality,
    );
    if (path == null) {
      completer.completeError('Failed to generate thumbnail file');
      return completer.future;
    }
    savedPath = path;
    bytes = File(path).readAsBytesSync();
  } else {
    // ── Load in-memory ────────────────────────────────────────────────────────
    bytes = await VideoThumbnail.thumbnailData(
      video: r.video,
      imageFormat: r.imageFormat,
      maxHeight: r.maxHeight,
      maxWidth: r.maxWidth,
      timeMs: r.timeMs,
      quality: r.quality,
    );
  }

  if (bytes == null) {
    completer.completeError('Failed to generate thumbnail');
    return completer.future;
  }

  final size = bytes.length;
  final img = Image.memory(bytes);
  img.image.resolve(const ImageConfiguration()).addListener(
        ImageStreamListener(
          (info, _) {
            completer.complete(ThumbnailResult(
              image: img,
              dataSize: size,
              height: info.image.height,
              width: info.image.width,
              filePath: savedPath,
            ));
          },
          onError: (exception, stackTrace) {
            completer.completeError(exception);
          },
        ),
      );
  return completer.future;
}

// ─── GenThumbnailImage ────────────────────────────────────────────────────────

class GenThumbnailImage extends StatefulWidget {
  final ThumbnailRequest thumbnailRequest;
  // Called once when thumbnail is saved to disk, with the full file path.
  final Function(String filePath)? onFileSaved;

  const GenThumbnailImage({
    Key? key,
    required this.thumbnailRequest,
    this.onFileSaved,
  }) : super(key: key);

  @override
  State<GenThumbnailImage> createState() => _GenThumbnailImageState();
}

class _GenThumbnailImageState extends State<GenThumbnailImage> {
  bool _notified = false;

  @override
  void didUpdateWidget(GenThumbnailImage old) {
    super.didUpdateWidget(old);
    if (!identical(old.thumbnailRequest, widget.thumbnailRequest)) {
      _notified = false;
    }
  }

  static String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.thumbnailRequest.language;
    return FutureBuilder<ThumbnailResult>(
      future: genThumbnail(widget.thumbnailRequest),
      builder: (_, snap) {
        if (snap.hasError) {
          return _ErrorCard(
            message:
                Localization.getText('error', lang, [snap.error.toString()]),
          );
        }
        if (!snap.hasData) return const _LoadingCard();

        final r = snap.data!;

        // Fire the saved callback exactly once per file save
        if (!_notified && r.filePath != null) {
          _notified = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onFileSaved?.call(r.filePath!);
          });
        }

        final isFile = r.filePath != null;
        final label = isFile
            ? Localization.getText('image_file_size', lang,
                [r.filePath!.split('/').last, r.width, r.height])
            : Localization.getText('image_data_size', lang,
                [_fmtSize(r.dataSize), r.width, r.height]);

        return _ThumbnailCard(image: r.image, label: label, isFile: isFile);
      },
    );
  }
}

// ─── Reusable card widgets ────────────────────────────────────────────────────

class _ThumbnailCard extends StatelessWidget {
  final Image image;
  final String label;
  final bool isFile;

  const _ThumbnailCard(
      {required this.image, required this.label, required this.isFile});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Info strip
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  isFile
                      ? Icons.insert_drive_file_outlined
                      : Icons.memory_outlined,
                  size: 13,
                  color: _accent,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                        color: _dim, fontSize: 11, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: _border, height: 1),
          // Image
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: Center(child: image),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _errClr.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _errClr.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: _errClr, size: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: _errClr, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 72),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(_accent),
              ),
            ),
            SizedBox(height: 14),
            Text('Generating…', style: TextStyle(color: _muted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String hint;
  const _EmptyState({required this.title, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child:
                const Icon(Icons.video_file_outlined, color: _muted, size: 26),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(hint,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 12, height: 1.7)),
        ],
      ),
    );
  }
}

// ─── Main screen ──────────────────────────────────────────────────────────────

class DemoHome extends StatefulWidget {
  final AppLanguage language;
  final ValueChanged<AppLanguage> onChangeLang;

  const DemoHome({Key? key, required this.language, required this.onChangeLang})
      : super(key: key);

  @override
  State<DemoHome> createState() => _DemoHomeState();
}

class _DemoHomeState extends State<DemoHome> {
  final _editNode = FocusNode();
  final _video = TextEditingController(
    text:
        'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
  );

  ImageFormat _format = ImageFormat.JPEG;
  int _quality = 75;
  int _sizeH = 0;
  int _sizeW = 0;
  int _timeMs = 0;

  GenThumbnailImage? _thumbnail;
  String? _saveDir;
  int _reqKey = 0; // incremented on each new request to force fresh state

  @override
  void initState() {
    super.initState();
    _initSaveDir();
  }

  Future<void> _initSaveDir() async {
    // Prefer external storage (no permission needed on Android 10+).
    // Falls back to app documents directory.
    try {
      final ext = await getExternalStorageDirectory();
      if (ext != null && mounted) {
        setState(() => _saveDir = ext.path);
        return;
      }
    } catch (_) {}
    final docs = await getApplicationDocumentsDirectory();
    if (mounted) setState(() => _saveDir = docs.path);
  }

  @override
  void dispose() {
    _editNode.dispose();
    _video.dispose();
    super.dispose();
  }

  // ── Thumbnail clearing ────────────────────────────────────────────────────

  void _clearThumbnail() {
    if (_thumbnail != null) setState(() => _thumbnail = null);
  }

  // ── Request builders ──────────────────────────────────────────────────────

  void _getDataRequest() {
    _editNode.unfocus();
    setState(() {
      _reqKey++;
      _thumbnail = GenThumbnailImage(
        key: ValueKey(_reqKey),
        thumbnailRequest: ThumbnailRequest(
          video: _video.text.trim(),
          thumbnailPath: null,
          imageFormat: _format,
          maxHeight: _sizeH,
          maxWidth: _sizeW,
          timeMs: _timeMs,
          quality: _quality,
          language: widget.language,
        ),
      );
    });
  }

  void _saveFileRequest() {
    _editNode.unfocus();
    setState(() {
      _reqKey++;
      _thumbnail = GenThumbnailImage(
        key: ValueKey(_reqKey),
        thumbnailRequest: ThumbnailRequest(
          video: _video.text.trim(),
          thumbnailPath: _saveDir,
          imageFormat: _format,
          maxHeight: _sizeH,
          maxWidth: _sizeW,
          timeMs: _timeMs,
          quality: _quality,
          language: widget.language,
        ),
        onFileSaved: (path) {
          if (!mounted) return;
          // Show SnackBar with the full saved path
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              content: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(Icons.check_circle_rounded,
                        color: _accent, size: 15),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Localization.getText('toast_saved', widget.language),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          path,
                          style: const TextStyle(color: _muted, fontSize: 10),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              action: SnackBarAction(
                label: widget.language == AppLanguage.arabic
                    ? 'فتح'
                    : (widget.language == AppLanguage.spanish
                        ? 'Abrir'
                        : 'Open'),
                textColor: _accent,
                onPressed: () async {
                  try {
                    await OpenFilex.open(path);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error opening file: $e')),
                      );
                    }
                  }
                },
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        },
      );
    });
  }

  // ── Settings builder — NEW list each call (fixes duplicate-widget-in-tree bug)

  List<Widget> _buildSettings(AppLanguage lang) {
    return [
      _LabeledSlider(
        label: _sizeH == 0
            ? Localization.getText('original_height', lang)
            : Localization.getText('max_height', lang, [_sizeH]),
        value: _sizeH.toDouble(),
        max: 512,
        divisions: 512,
        onChanged: (v) => setState(() {
          _editNode.unfocus();
          _sizeH = v.toInt();
        }),
      ),
      _LabeledSlider(
        label: _sizeW == 0
            ? Localization.getText('original_width', lang)
            : Localization.getText('max_width', lang, [_sizeW]),
        value: _sizeW.toDouble(),
        max: 512,
        divisions: 512,
        onChanged: (v) => setState(() {
          _editNode.unfocus();
          _sizeW = v.toInt();
        }),
      ),
      _LabeledSlider(
        label: _timeMs == 0
            ? Localization.getText('beginning_video', lang)
            : Localization.getText('time_ms', lang, [_timeMs]),
        value: _timeMs.toDouble(),
        max: 10000,
        divisions: 1000,
        onChanged: (v) => setState(() {
          _editNode.unfocus();
          _timeMs = v.toInt();
        }),
      ),
      _LabeledSlider(
        label: Localization.getText('quality', lang, [_quality]),
        value: _quality.toDouble(),
        max: 100,
        divisions: 100,
        onChanged: (v) => setState(() {
          _editNode.unfocus();
          _quality = v.toInt();
        }),
      ),
      const SizedBox(height: 12),
      Text(
        Localization.getText('format', lang),
        style: const TextStyle(
            color: _muted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4),
      ),
      const SizedBox(height: 6),
      RadioGroup<ImageFormat>(
        groupValue: _format,
        onChanged: (v) => setState(() {
          if (v != null) {
            _format = v;
            _editNode.unfocus();
          }
        }),
        child: Wrap(
          spacing: 4,
          runSpacing: 0,
          children: [
            _RadioOpt(value: ImageFormat.JPEG, label: 'JPEG'),
            _RadioOpt(value: ImageFormat.PNG, label: 'PNG'),
            _RadioOpt(value: ImageFormat.WEBP, label: 'WebP'),
            _RadioOpt(value: ImageFormat.HEIC, label: 'HEIC'),
          ],
        ),
      ),
      const SizedBox(height: 24),
      const Divider(color: _border, height: 1),
      const SizedBox(height: 20),
      OutlinedButton.icon(
        icon: const Icon(Icons.help_outline_rounded, size: 14),
        label: Text(
          lang == AppLanguage.arabic
              ? 'دليل الاستخدام'
              : (lang == AppLanguage.spanish
                  ? 'Guía de ayuda'
                  : 'Show Guidance'),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OnboardingScreen(
                isModal: true,
                onComplete: () => Navigator.pop(context),
              ),
            ),
          );
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: _accent,
          side: const BorderSide(color: _border),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ];
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final lang = widget.language;

    return Directionality(
      textDirection: Localization.getDir(lang),
      child: Scaffold(
        backgroundColor: _bg,
        appBar: _buildAppBar(lang),
        endDrawer: _buildDrawer(lang),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(color: _border, height: 1),

            // ── URL input ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _video,
                focusNode: _editNode,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                maxLines: 1,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                onEditingComplete: () => _editNode.unfocus(),
                // Clear the thumbnail whenever the URL changes
                onChanged: (_) => _clearThumbnail(),
                decoration: InputDecoration(
                  hintText: Localization.getText('video_uri', lang),
                  hintStyle: const TextStyle(color: _muted, fontSize: 13),
                  filled: true,
                  fillColor: _surface,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  prefixIcon:
                      const Icon(Icons.link_rounded, color: _muted, size: 16),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 40, minHeight: 40),
                  suffixIcon: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _video,
                    builder: (_, val, __) => val.text.isEmpty
                        ? const SizedBox.shrink()
                        : IconButton(
                            icon: const Icon(Icons.close_rounded,
                                size: 14, color: _muted),
                            onPressed: () {
                              _video.clear();
                              _clearThumbnail();
                            },
                          ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _accent, width: 1.5),
                  ),
                ),
              ),
            ),

            // ── Thumbnail / empty area ─────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: _thumbnail != null
                    ? _thumbnail!
                    : _EmptyState(
                        title: Localization.getText('empty_title', lang),
                        hint: Localization.getText('empty_hint', lang),
                      ),
              ),
            ),
          ],
        ),

        // ── Bottom action bar ──────────────────────────────────────────────
        bottomNavigationBar: _BottomBar(
          lang: lang,
          onCamera: () async {
            final v = await ImagePicker().pickVideo(source: ImageSource.camera);
            if (v != null && mounted) {
              setState(() => _video.text = v.path);
              _clearThumbnail();
            }
          },
          onGallery: () async {
            final v =
                await ImagePicker().pickVideo(source: ImageSource.gallery);
            if (v != null && mounted) {
              setState(() => _video.text = v.path);
              _clearThumbnail();
            }
          },
          onGetData: _getDataRequest,
          onSave: _saveFileRequest,
        ),
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(AppLanguage lang) => AppBar(
        title: Text(
          Localization.getText('title', lang),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 17,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          // Language picker
          PopupMenuButton<AppLanguage>(
            color: _surface,
            icon: const Icon(Icons.language_rounded, color: _muted, size: 19),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: _border),
            ),
            onSelected: widget.onChangeLang,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: AppLanguage.english,
                child: Text('English 🇬🇧',
                    style: TextStyle(color: Colors.white, fontSize: 13)),
              ),
              PopupMenuItem(
                value: AppLanguage.arabic,
                child: Text('العربية 🇦🇪',
                    style: TextStyle(color: Colors.white, fontSize: 13)),
              ),
              PopupMenuItem(
                value: AppLanguage.spanish,
                child: Text('Español 🇪🇸',
                    style: TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ],
          ),
          // Settings (opens endDrawer)
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.tune_rounded, color: _muted, size: 19),
              tooltip: Localization.getText('settings', lang),
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
            ),
          ),
          const SizedBox(width: 4),
        ],
      );

  // ── Settings drawer (builds fresh — no shared widget instances) ───────────

  Widget _buildDrawer(AppLanguage lang) => Drawer(
        width: 300,
        backgroundColor: _surface,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  children: [
                    Text(
                      Localization.getText('settings', lang),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: _muted, size: 18),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(color: _border, height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: _buildSettings(lang),
                ),
              ),
            ],
          ),
        ),
      );
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _LabeledSlider extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: _dim, fontSize: 12, fontWeight: FontWeight.w500)),
            Slider(
                value: value,
                max: max,
                divisions: divisions,
                onChanged: onChanged),
          ],
        ),
      );
}

class _RadioOpt extends StatelessWidget {
  final ImageFormat value;
  final String label;

  const _RadioOpt({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<ImageFormat>(value: value),
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      );
}

// ─── Bottom action bar ────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final AppLanguage lang;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onGetData;
  final VoidCallback onSave;

  const _BottomBar({
    required this.lang,
    required this.onCamera,
    required this.onGallery,
    required this.onGetData,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _border)),
      ),
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottom),
      child: Row(
        children: [
          // Media pick
          _GhostBtn(icon: Icons.videocam_outlined, onTap: onCamera),
          const SizedBox(width: 8),
          _GhostBtn(icon: Icons.photo_library_outlined, onTap: onGallery),
          const Spacer(),
          // Actions
          _OutlinedAction(
            label: Localization.getText('data_btn', lang),
            onTap: onGetData,
          ),
          const SizedBox(width: 8),
          _FilledAction(
            label: Localization.getText('file_btn', lang),
            onTap: onSave,
          ),
        ],
      ),
    );
  }
}

class _GhostBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GhostBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _bg,
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _muted, size: 19),
        ),
      );
}

class _OutlinedAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _OutlinedAction({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: _bg,
          side: const BorderSide(color: _border),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(label),
      );
}

class _FilledAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _FilledAction({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(label),
      );
}

// ─── Onboarding Screen ────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  final bool isModal;

  const OnboardingScreen({
    Key? key,
    required this.onComplete,
    this.isModal = false,
  }) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentSlide = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slides = [
      const _OnboardingSlide(
        icon: Icons.video_collection_outlined,
        title: 'Welcome to Thumbnail Plus',
        description:
            'A professional and fast tool to generate and extract video thumbnails from files and URLs on Android and iOS.',
      ),
      const _OnboardingSlide(
        icon: Icons.tune_outlined,
        title: 'Configure Your Thumbnail',
        description:
            'Easily customize dimensions (width and height), capture frames at specific timestamps, adjust quality, and choose formats (JPEG, PNG, WebP, HEIC).',
      ),
      const _OnboardingSlide(
        icon: Icons.speed_outlined,
        title: 'High Performance',
        description:
            'Speeds up frame extraction by opening the video encoder once. Uses intelligent cache limits to preserve device memory.',
      ),
    ];

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: widget.onComplete,
                child: const Text('Skip', style: TextStyle(color: _muted)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (idx) => setState(() => _currentSlide = idx),
                itemCount: slides.length,
                itemBuilder: (_, i) => slides[i],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                slides.length,
                (idx) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 6,
                  width: _currentSlide == idx ? 18 : 6,
                  decoration: BoxDecoration(
                    color: _currentSlide == idx ? _accent : _border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  if (_currentSlide > 0)
                    TextButton(
                      onPressed: () => _controller.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      ),
                      child:
                          const Text('Back', style: TextStyle(color: _muted)),
                    )
                  else
                    const SizedBox(width: 60),
                  const Spacer(),
                  _FilledAction(
                    label: _currentSlide == slides.length - 1
                        ? (widget.isModal ? 'Close' : 'Get Started')
                        : 'Next',
                    onTap: () {
                      if (_currentSlide == slides.length - 1) {
                        widget.onComplete();
                      } else {
                        _controller.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlide extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _surface,
              shape: BoxShape.circle,
              border: Border.all(color: _border, width: 1.5),
            ),
            child: Icon(icon, color: _accent, size: 48),
          ),
          const SizedBox(height: 40),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: const TextStyle(
              color: _muted,
              fontSize: 13,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
