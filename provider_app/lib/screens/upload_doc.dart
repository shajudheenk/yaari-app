import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:yaari_ui/yaari_ui.dart';

import '../apply.dart';

/// Sending one credential in.
///
/// Three ways in, because the documents genuinely arrive three ways: a Gas
/// Safe card is in your wallet, a DBS certificate is in a drawer, and an
/// insurance schedule is a PDF in your email. Forcing all three through a
/// camera is how you end up chasing people by telephone.
///
/// Nothing here can mark a document valid. The app sends it; an operator
/// checks it against the issuing register.
Future<bool> showUploadSheet(BuildContext context, RequiredDoc doc) async {
  final done = await showYaariSheet<bool>(
    context,
    expand: true,
    child: _UploadSheet(doc: doc),
  );
  return done ?? false;
}

class _UploadSheet extends StatefulWidget {
  const _UploadSheet({required this.doc});

  final RequiredDoc doc;

  @override
  State<_UploadSheet> createState() => _UploadSheetState();
}

class _UploadSheetState extends State<_UploadSheet> {
  final _reference = TextEditingController();
  Uint8List? _bytes;
  String _extension = 'jpg';
  String? _fileLabel;
  DateTime? _expires;
  bool _busy = false;
  String? _error;

  /// Some credentials genuinely never expire; asking for a date on those
  /// only invites a made-up one.
  bool get _wantsExpiry => widget.doc.docType != 'right_to_work';

  /// Insurance and registrations carry a number that makes an operator's
  /// check against the register far quicker.
  bool get _wantsReference => const {
        'public_liability_insurance',
        'treatment_insurance',
        'gas_safe',
        'part_p',
        'dbs_basic',
        'special_treatment_licence',
      }.contains(widget.doc.docType);

  bool get _ready => _bytes != null && (!_wantsExpiry || _expires != null);

  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  Future<void> _take(ImageSource source) async {
    try {
      final shot = await ImagePicker().pickImage(
        source: source,
        // Large enough for a certificate number to stay readable, small
        // enough to send from a van on mobile data.
        maxWidth: 2000,
        imageQuality: 82,
      );
      if (shot == null) return;
      final b = await shot.readAsBytes();
      if (!mounted) return;
      Buzz.pick();
      setState(() {
        _bytes = b;
        _extension = 'jpg';
        _fileLabel = source == ImageSource.camera
            ? 'Photo just taken'
            : 'Photo from your library';
        _error = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not open the camera.');
    }
  }

  Future<void> _pickFile() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );
      final f = res?.files.firstOrNull;
      if (f == null || f.bytes == null) return;
      if (!mounted) return;
      Buzz.pick();
      setState(() {
        _bytes = f.bytes;
        _extension = (f.extension ?? 'pdf').toLowerCase();
        _fileLabel = f.name;
        _error = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not open that file.');
    }
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expires ?? DateTime(now.year + 1, now.month, now.day),
      // Backdated certificates are a red flag, and nothing in this trade is
      // issued more than a decade ahead.
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: DateTime(now.year + 10),
      helpText: 'Expiry date on the document',
    );
    if (picked != null && mounted) {
      Buzz.tap();
      setState(() => _expires = picked);
    }
  }

  Future<void> _send() async {
    if (!_ready) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await DocsApi.submit(
        docType: widget.doc.docType,
        bytes: _bytes!,
        extension: _extension,
        reference: _reference.text,
        expiresOn: _expires,
      );
      if (!mounted) return;
      Buzz.commit();
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        Buzz.reject();
        setState(() {
          _error = DocsApi.explain(e);
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetHead(
          title: widget.doc.label,
          subtitle: widget.doc.note ??
              'For your ${widget.doc.tradeName.toLowerCase()} work',
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.xl),
            children: [
              if (_bytes == null) ...[
                _Source(
                  icon: Icons.photo_camera_rounded,
                  title: 'Take a photo',
                  body: 'Best for a card or a certificate you have with you',
                  onTap: () => _take(ImageSource.camera),
                ),
                const SizedBox(height: Gap.md),
                _Source(
                  icon: Icons.photo_library_rounded,
                  title: 'From your photos',
                  body: 'If you have already photographed it',
                  onTap: () => _take(ImageSource.gallery),
                ),
                const SizedBox(height: Gap.md),
                _Source(
                  icon: Icons.picture_as_pdf_rounded,
                  title: 'Choose a PDF',
                  body: 'Insurance schedules usually arrive as a PDF',
                  onTap: _pickFile,
                ),
              ] else ...[
                _Chosen(
                  label: _fileLabel ?? 'Selected',
                  bytes: _bytes!,
                  isPdf: _extension == 'pdf',
                  onReplace: () => setState(() {
                    _bytes = null;
                    _fileLabel = null;
                  }),
                ),
                const SizedBox(height: Gap.xl),

                if (_wantsReference) ...[
                  Text('POLICY OR REGISTRATION NUMBER', style: Txt.label),
                  const SizedBox(height: Gap.sm),
                  TextField(
                    controller: _reference,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                        hintText: 'Speeds up our check. Optional.'),
                  ),
                  const SizedBox(height: Gap.xl),
                ],

                if (_wantsExpiry) ...[
                  Text('EXPIRY DATE', style: Txt.label),
                  const SizedBox(height: Gap.sm),
                  Pressable(
                    onTap: _pickExpiry,
                    scale: 0.99,
                    child: Container(
                      padding: const EdgeInsets.all(Gap.lg),
                      decoration: BoxDecoration(
                        color: Surface.raised,
                        borderRadius: BorderRadius.circular(Radii.button),
                        border: Border.all(
                            color: _expires == null ? Coal.c200 : Brand.c500,
                            width: 1.5),
                      ),
                      child: Row(children: [
                        Icon(Icons.event_rounded,
                            size: 17,
                            color: _expires == null ? Coal.c500 : Brand.c600),
                        const SizedBox(width: Gap.md),
                        Expanded(
                          child: Text(
                            _expires == null
                                ? 'Tap to choose'
                                : _fmt(_expires!),
                            style: Txt.cardTitle.copyWith(
                              fontSize: 14,
                              color:
                                  _expires == null ? Coal.c400 : Coal.c900,
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: Gap.md),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 14, color: Coal.c500),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: Text(
                          'We will remind you before this runs out. If it '
                          'lapses you stop receiving work that day.',
                          style: Txt.meta),
                    ),
                  ]),
                ],
              ],

              if (_error != null) ...[
                const SizedBox(height: Gap.lg),
                Panel(
                  colour: Signal.dangerSoft,
                  shadow: const [],
                  padding: const EdgeInsets.all(Gap.lg),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 17, color: Signal.danger),
                    const SizedBox(width: Gap.md),
                    Expanded(
                        child: Text(_error!,
                            style: Txt.body.copyWith(
                                fontSize: 13,
                                color: Brand.c700))),
                  ]),
                ),
              ],

              const SizedBox(height: Gap.xl),
              Btn('Send for checking',
                  busy: _busy, onTap: _ready && !_busy ? _send : null),
              const SizedBox(height: Gap.md),
              Row(children: [
                const Icon(Icons.lock_rounded, size: 13, color: Coal.c500),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                      'Stored privately. Only our verification team can open '
                      'it, and we check it against the issuing register.',
                      style: Txt.meta),
                ),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  static String _fmt(DateTime d) {
    const m = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }
}

class _Source extends StatelessWidget {
  const _Source({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Panel(
      onTap: onTap,
      padding: const EdgeInsets.all(Gap.lg),
      shadow: Shade.sm,
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: Brand.c50,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 18, color: Brand.c600),
        ),
        const SizedBox(width: Gap.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Txt.cardTitle.copyWith(fontSize: 14.5)),
              const SizedBox(height: 2),
              Text(body, style: Txt.meta),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, size: 19, color: Coal.c400),
      ]),
    );
  }
}

/// What they picked, so they can see it is the right page before sending.
class _Chosen extends StatelessWidget {
  const _Chosen({
    required this.label,
    required this.bytes,
    required this.isPdf,
    required this.onReplace,
  });

  final String label;
  final Uint8List bytes;
  final bool isPdf;
  final VoidCallback onReplace;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.all(Gap.md),
      shadow: Shade.sm,
      border: Border.all(color: Signal.success.withValues(alpha: 0.4), width: 1.5),
      child: Row(children: [
        Container(
          width: 62,
          height: 62,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Coal.c50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: isPdf
              ? const Icon(Icons.picture_as_pdf_rounded,
                  size: 24, color: Signal.danger)
              : Image.memory(bytes, fit: BoxFit.cover),
        ),
        const SizedBox(width: Gap.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Txt.cardTitle.copyWith(fontSize: 13.5)),
              const SizedBox(height: 3),
              Text('${(bytes.lengthInBytes / 1024).round()} KB',
                  style: Txt.meta),
            ],
          ),
        ),
        Btn('Change',
            kind: BtnKind.ghost, full: false, onTap: onReplace),
      ]),
    );
  }
}
