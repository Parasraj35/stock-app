import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

/// A safe PDF file name from any label (party names can hold spaces or
/// symbols): letters/digits/underscore/dash only, always ending in .pdf.
String pdfFileName(String label) {
  final cleaned = label.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
  final base = cleaned.replaceAll(RegExp(r'^_+|_+$'), '');
  return '${base.isEmpty ? 'report' : base}.pdf';
}

/// Share + Print buttons for an app bar. Share hands the PDF to Android's
/// share sheet (WhatsApp, email, …); Print opens the print/save preview.
/// Both build the PDF on demand and show a spinner while it's being made.
class ReportActions extends StatefulWidget {
  const ReportActions({
    super.key,
    required this.buildPdf,
    required this.filename,
    this.enabled = true,
  });

  final Future<Uint8List> Function() buildPdf;
  final String filename;
  final bool enabled;

  @override
  State<ReportActions> createState() => _ReportActionsState();
}

class _ReportActionsState extends State<ReportActions> {
  bool _busy = false;

  Future<void> _run(Future<void> Function(Uint8List bytes) deliver) async {
    setState(() => _busy = true);
    try {
      final bytes = await widget.buildPdf();
      if (!mounted) return;
      await deliver(bytes);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not create the report')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 18),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Share PDF',
          icon: const Icon(Icons.share_outlined),
          onPressed: widget.enabled
              ? () => _run(
                  (bytes) => Printing.sharePdf(
                    bytes: bytes,
                    filename: widget.filename,
                  ),
                )
              : null,
        ),
        IconButton(
          tooltip: 'Print',
          icon: const Icon(Icons.print_outlined),
          onPressed: widget.enabled
              ? () => _run(
                  (bytes) => Printing.layoutPdf(
                    onLayout: (format) async => bytes,
                    name: widget.filename,
                  ),
                )
              : null,
        ),
      ],
    );
  }
}
