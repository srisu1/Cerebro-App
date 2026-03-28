// Unified upload-notes modal — file pick, metadata form, multipart upload.
library;

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:cerebro_app/config/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/auth_provider.dart';


bool get _darkMode =>
    CerebroTheme.brightnessNotifier.value == Brightness.dark;

Color get _outline => _darkMode ? const Color(0xFFAD7F58) : const Color(0xFF6E5848);
Color get _brown => _darkMode ? const Color(0xFFF2E1CA) : const Color(0xFF4E3828);
Color get _brownLt => _darkMode ? const Color(0xFFDBB594) : const Color(0xFF7A5840);
Color get _brownSoft => _darkMode ? const Color(0xFFBD926C) : const Color(0xFF9A8070);
Color get _cream => _darkMode ? const Color(0xFF1E1A17) : const Color(0xFFFDEFDB);
Color get _creamWarm => _darkMode ? const Color(0xFF29221D) : const Color(0xFFFFF8F4);
Color get _cardFill  => _darkMode ? const Color(0xFF29221D) : const Color(0xFFFFF8F4);
Color get _olive => const Color(0xFF98A869);
Color get _oliveDk => const Color(0xFF58772F);
Color get _mTerra => const Color(0xFFD9B5A6);
Color get _mSage => const Color(0xFFB5C4A0);
const _bitroad   = 'Bitroad';

// Nullable `color` + in-body fallback — `_brown` is a mode-aware getter now.
TextStyle _gaegu({
  double size = 14,
  FontWeight weight = FontWeight.w600,
  Color? color,
  double? h,
}) =>
    GoogleFonts.gaegu(fontSize: size, fontWeight: weight, color: color ?? _brown, height: h);

/// Description of a selectable subject for the modal's subject dropdown.
class UploadModalSubject {
  final String id;
  final String name;
  final IconData icon;
  const UploadModalSubject({required this.id, required this.name, this.icon = Icons.book_rounded});
}

/// The result returned on a successful upload — callers can use it to
/// navigate into the freshly-created material, or to refresh their list.
class UploadModalResult {
  final String? materialId;
  final String? subjectId;
  final String title;
  final Map<String, dynamic>? rawResponse;
  const UploadModalResult({
    required this.title,
    this.materialId,
    this.subjectId,
    this.rawResponse,
  });
}

class UploadNotesModal extends ConsumerStatefulWidget {
  final List<UploadModalSubject> subjects;
  final String? preselectedSubjectId;
  final List<String> defaultTopics;
  final void Function(UploadModalResult result)? onUploaded;

  /// Raw file info — the caller runs `FilePicker` and hands us what it picked.
  final PlatformFile file;

  const UploadNotesModal._({
    required this.file,
    required this.subjects,
    this.preselectedSubjectId,
    this.defaultTopics = const [],
    this.onUploaded,
  });

  /// Run the upload flow. Picks a file if none supplied.
  static Future<bool?> show(
    BuildContext context, {
    required WidgetRef ref,
    required List<UploadModalSubject> subjects,
    PlatformFile? file,
    String? preselectedSubjectId,
    List<String> defaultTopics = const [],
    void Function(UploadModalResult result)? onUploaded,
  }) async {
    // Step 1 — pick a file if the caller didn't already
    PlatformFile? picked = file;
    if (picked == null) {
      final result = await FilePicker.platform
          .pickFiles(type: FileType.any, allowMultiple: false);
      if (result == null || result.files.isEmpty) return null;
      picked = result.files.first;
    }
    if (picked.path == null) return null;

    // Step 2 — validate extension
    final ext = picked.extension?.toLowerCase() ?? '';
    const allowed = ['pdf', 'png', 'jpg', 'jpeg', 'txt', 'md'];
    if (!allowed.contains(ext)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Unsupported file type: .$ext\nAllowed: PDF, PNG, JPG, TXT, MD',
              style: GoogleFonts.nunito()),
          backgroundColor: Colors.red.shade400,
        ));
      }
      return false;
    }

    // Step 3 — run the dialog + upload pipeline via a dedicated widget
    if (!context.mounted) return null;
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black45,
      builder: (ctx) => UploadNotesModal._(
        file: picked!,
        subjects: subjects,
        preselectedSubjectId: preselectedSubjectId,
        defaultTopics: defaultTopics,
        onUploaded: onUploaded,
      ),
    );
    return ok;
  }

  @override
  ConsumerState<UploadNotesModal> createState() => _UploadNotesModalState();
}

class _UploadNotesModalState extends ConsumerState<UploadNotesModal> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _topicsCtrl;
  String? _pickedSubjectId;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl =
        TextEditingController(text: widget.file.name.split('.').first);
    _topicsCtrl = TextEditingController(text: widget.defaultTopics.join(', '));
    _pickedSubjectId = widget.preselectedSubjectId;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _topicsCtrl.dispose();
    super.dispose();
  }

  Future<void> _runUpload() async {
    setState(() => _uploading = true);
    final api = ref.read(apiServiceProvider);
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(widget.file.path!,
            filename: widget.file.name),
        'title': _titleCtrl.text.trim().isEmpty
            ? widget.file.name
            : _titleCtrl.text.trim(),
        if (_pickedSubjectId != null && _pickedSubjectId!.isNotEmpty)
          'subject_id': _pickedSubjectId,
        'topics': _topicsCtrl.text.trim(),
      });
      final resp = await api.post('/study/materials/upload', data: formData);
      final data = (resp.data is Map<String, dynamic>)
          ? resp.data as Map<String, dynamic>
          : <String, dynamic>{};
      final result = UploadModalResult(
        materialId: data['id']?.toString(),
        subjectId: data['subject_id']?.toString() ?? _pickedSubjectId,
        title: _titleCtrl.text.trim().isEmpty
            ? widget.file.name
            : _titleCtrl.text.trim(),
        rawResponse: data,
      );
      widget.onUploaded?.call(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('File uploaded & text extracted!',
              style: GoogleFonts.nunito()),
          backgroundColor: _mSage,
        ));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('[UploadNotesModal] upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('Upload failed: $e', style: GoogleFonts.nunito()),
          backgroundColor: _mTerra,
        ));
        Navigator.of(context).pop(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 560,
          decoration: BoxDecoration(
            color: _creamWarm,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _outline, width: 2),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black, offset: Offset(6, 6), blurRadius: 0),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(26, 24, 26, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text('UPLOAD NOTES',
                          style: TextStyle(
                              fontFamily: _bitroad,
                              fontSize: 13,
                              color: _oliveDk,
                              letterSpacing: 1.8)),
                    ),
                    GestureDetector(
                      onTap: _uploading
                          ? null
                          : () => Navigator.of(context).pop(null),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: _cardFill,
                          shape: BoxShape.circle,
                          border: Border.all(color: _outline, width: 1.5),
                        ),
                        child: Icon(Icons.close_rounded,
                            size: 17, color: _brown),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: _olive,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _outline, width: 2),
                        boxShadow: const [
                          BoxShadow(
                              color: Colors.black,
                              offset: Offset(3, 3),
                              blurRadius: 0),
                        ],
                      ),
                      child: const Icon(Icons.upload_file_rounded,
                          size: 32, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.file.name,
                                style: TextStyle(
                                    fontFamily: _bitroad,
                                    fontSize: 22,
                                    color: _brown,
                                    height: 1.1),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 6),
                            Text('extract the text & save it under a subject.',
                                style: _gaegu(size: 14, color: _brownLt)),
                          ]),
                    )),
                  ]),
                  const SizedBox(height: 22),

                  _ModalInput(
                      ctrl: _titleCtrl,
                      hint: 'note title',
                      icon: Icons.title_rounded),
                  const SizedBox(height: 14),
                  _ModalDropdown<String?>(
                    value: _pickedSubjectId,
                    hint: 'link to a subject (optional)',
                    icon: Icons.folder_rounded,
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text('no subject (general)',
                            style: TextStyle(
                                fontFamily: 'Gaegu', color: _brownSoft)),
                      ),
                      ...widget.subjects.map((s) => DropdownMenuItem<String?>(
                            value: s.id,
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(s.icon, size: 16, color: _brown),
                              const SizedBox(width: 8),
                              Flexible(
                                  child: Text(s.name,
                                      style: GoogleFonts.gaegu(
                                          fontSize: 16,
                                          color: _brown,
                                          fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis)),
                            ]),
                          )),
                    ],
                    onChanged: _uploading
                        ? null
                        : (v) => setState(() => _pickedSubjectId = v),
                  ),
                  const SizedBox(height: 14),
                  _ModalInput(
                      ctrl: _topicsCtrl,
                      hint: 'topics, comma-separated (optional)',
                      icon: Icons.label_rounded),
                  const SizedBox(height: 24),

                  Row(children: [
                    Expanded(
                        flex: 2,
                        child: _SoftButton(
                          label: 'cancel',
                          fill: _cream,
                          onTap: _uploading
                              ? () {}
                              : () => Navigator.of(context).pop(null),
                        )),
                    const SizedBox(width: 10),
                    Expanded(
                        flex: 3,
                        child: _SoftButton(
                          label: _uploading ? 'uploading…' : 'upload & extract',
                          fill: _olive,
                          textColor: Colors.white,
                          onTap: _uploading ? () {} : _runUpload,
                        )),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class _ModalInput extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final IconData icon;
  const _ModalInput(
      {required this.ctrl, required this.hint, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: _cardFill,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _outline, width: 2),
          boxShadow: const [
            BoxShadow(
                color: Colors.black, offset: Offset(3, 3), blurRadius: 0),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _olive,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _outline, width: 1.5),
            ),
            child: Icon(icon, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: TextField(
            controller: ctrl,
            style: _gaegu(size: 16, weight: FontWeight.w600, color: _brown),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: _gaegu(size: 16, color: _brownSoft),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          )),
        ]),
      );
}

class _ModalDropdown<T> extends StatelessWidget {
  final T? value;
  final String hint;
  final IconData icon;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  const _ModalDropdown({
    required this.value,
    required this.hint,
    required this.icon,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: _cardFill,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _outline, width: 2),
          boxShadow: const [
            BoxShadow(
                color: Colors.black, offset: Offset(3, 3), blurRadius: 0),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _olive,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _outline, width: 1.5),
            ),
            child: Icon(icon, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              icon: Icon(Icons.expand_more_rounded, color: _brownLt),
              hint: Text(hint, style: _gaegu(size: 16, color: _brownSoft)),
              style: _gaegu(size: 16, weight: FontWeight.w600, color: _brown),
              dropdownColor: Colors.white,
              items: items,
              onChanged: onChanged,
            ),
          )),
        ]),
      );
}

class _SoftButton extends StatelessWidget {
  final String label;
  final Color fill;
  // Nullable + in-body fallback — `_brown` is a mode-aware runtime getter.
  final Color? textColor;
  final VoidCallback onTap;
  _SoftButton(
      {required this.label,
      required this.fill,
      required this.onTap,
      this.textColor});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _outline, width: 2),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black, offset: Offset(3, 3), blurRadius: 0),
            ],
          ),
          child: Text(label,
              style:
                  _gaegu(size: 18, weight: FontWeight.w700, color: textColor)),
        ),
      );
}
