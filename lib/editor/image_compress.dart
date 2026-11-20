import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// أكبر بُعد للصورة داخل الاختبار (نفس حد المنصة الأصلية).
const int kMaxImageSide = 850;

/// يصغّر الصورة ويضغطها ويعيدها كـ data URL. يعيد null إن تعذر قراءتها.
String? compressToDataUrl(Uint8List bytes) {
  try {
    final im = img.decodeImage(bytes);
    if (im == null) return null;
    var r = im;
    if (im.width > kMaxImageSide || im.height > kMaxImageSide) {
      r = im.width >= im.height
          ? img.copyResize(im, width: kMaxImageSide)
          : img.copyResize(im, height: kMaxImageSide);
    }
    final alpha = r.numChannels == 4;
    final out = alpha ? img.encodePng(r) : img.encodeJpg(r, quality: 85);
    return 'data:image/${alpha ? 'png' : 'jpeg'};base64,${base64Encode(out)}';
  } catch (_) {
    return null;
  }
}

Future<String?> compressImageAsync(Uint8List bytes) => compute(compressToDataUrl, bytes);
