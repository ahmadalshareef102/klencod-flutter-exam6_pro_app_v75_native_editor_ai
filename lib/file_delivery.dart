import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'bridge_logic.dart';

/// يسأل المستخدم: حفظ في الجهاز أم مشاركة، ثم ينفذ.
Future<Map<String, dynamic>> deliverFile(
    BuildContext context, Uint8List bytes, String name) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(name, textDirection: TextDirection.ltr),
            ),
            ListTile(
              leading: const Icon(Icons.save_alt),
              title: const Text('حفظ في الجهاز'),
              onTap: () => Navigator.pop(ctx, 'save'),
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('مشاركة'),
              onTap: () => Navigator.pop(ctx, 'share'),
            ),
          ],
        ),
      ),
    ),
  );
  if (choice == null) return {'ok': false, 'cancelled': true};

  if (choice == 'save') {
    final path = await FilePicker.platform
        .saveFile(dialogTitle: 'حفظ الملف', fileName: name, bytes: bytes);
    if (path == null) return {'ok': false, 'cancelled': true};
    return {'ok': true, 'message': 'تم حفظ الملف'};
  }

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$name');
  await file.writeAsBytes(bytes, flush: true);
  await Share.shareXFiles(
    [XFile(file.path, mimeType: mimeForFileName(name))],
    subject: name,
  );
  return {'ok': true, 'message': 'تمت المشاركة'};
}
