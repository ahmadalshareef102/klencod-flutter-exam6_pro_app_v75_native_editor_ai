/* واجهة برمجية للواجهة الأصلية (Flutter) فوق دوال المنصة الأصلية.
   المحرك (JS) يبقى مصدر الحقيقة لحالة الاختبار؛ Flutter يقرأ ويكتب عبر هذه الدوال. */
(function () {
  if (window.Exam6Api) return;

  var META = ['republic', 'ministry', 'governorate', 'directorate', 'school', 'grade', 'subject',
              'semester', 'year', 'title', 'duration', 'teacher', 'maxscore', 'notes'];
  var VIS = { studentBar: 'vis-student-bar', officialHeader: 'vis-official-header', bismillah: 'vis-bismillah',
              logo: 'vis-logo', govDir: 'vis-gov-dir', tableHead: 'vis-table-head', footer: 'vis-footer' };
  var DES = { lang: 'tpl-lang', tableMode: 'tpl-tablemode', fontFamily: 'tpl-font', fontWeight: 'tpl-fontweight',
              lineHeight: 'tpl-lineheight', pageFrame: 'tpl-pageframe', borderColor: 'tpl-bordercolor' };

  function $(id) { return document.getElementById(id); }
  function plain(html) {
    var d = document.createElement('div');
    d.innerHTML = html || '';
    return (d.textContent || '').replace(/\s+/g, ' ').trim();
  }
  function sums() {
    var r = recalculateScores();
    return { sum: r.sum, target: r.target, match: r.isMatch };
  }
  function focusedIndex() {
    return currentExam.questions.findIndex(function (q) { return 'rich_ed_' + q.id === activeEditorId; });
  }
  function fileFrom(item, i) {
    var bin = atob(item.b64);
    var u = new Uint8Array(bin.length);
    for (var k = 0; k < bin.length; k++) u[k] = bin.charCodeAt(k);
    return new File([u], 'image' + i, { type: item.mime || 'image/jpeg' });
  }

  /* آخر موضع للمؤشر داخل المحرر النشط (يبقى محفوظاً أثناء فتح لوحات Flutter) */
  var lastRange = null;
  document.addEventListener('selectionchange', function () {
    var sel = window.getSelection();
    if (!sel || !sel.rangeCount || !activeEditorId) return;
    var ed = $(activeEditorId);
    if (ed && ed.contains(sel.anchorNode)) lastRange = sel.getRangeAt(0).cloneRange();
  });

  /* ينفّذ أمراً على التحديد المحفوظ داخل المحرر النشط ثم يزامن الحالة */
  function withSel(fn) {
    var ed = activeEditorId ? $(activeEditorId) : null;
    if (!ed) return false;
    ed.focus();
    var sel = window.getSelection();
    if (lastRange && ed.contains(lastRange.startContainer)) {
      sel.removeAllRanges(); sel.addRange(lastRange);
    }
    fn(ed);
    ed.dispatchEvent(new Event('input'));
    var s2 = window.getSelection();
    if (s2.rangeCount && ed.contains(s2.anchorNode)) lastRange = s2.getRangeAt(0).cloneRange();
    return true;
  }


  /* ================= الاستيراد الذكي: نص منظم (من الذكاء الاصطناعي) ← اختبار كامل ================= */
  var aiState = null;
  var AI_TYPE_LABEL = { essay: 'مقالي', mcq: 'اختيار متعدد', tf: 'صح وخطأ', fill: 'أكمل الفراغات',
                        match: 'توصيل', table: 'جدول' };
  var AI_SUBTITLE = {
    ar: { essay: 'أجب عن الأسئلة الآتية:', mcq: 'اختر الإجابة الصحيحة مما يلي:',
          tf: 'ضع علامة (✓) أمام العبارة الصحيحة وعلامة (✕) أمام العبارة الخطأ:',
          fill: 'أكمل الفراغات الآتية بما يناسبها:', match: 'صل من العمود (أ) ما يناسبه من العمود (ب):',
          table: 'أكمل الجدول الآتي:' },
    en: { essay: 'Answer the following questions:', mcq: 'Choose the correct answer:',
          tf: 'Put (✓) for True or (✕) for False:', fill: 'Fill in the blanks:',
          match: 'Match Column (A) with Column (B):', table: 'Complete the table:' }
  };
  var AI_TYPES = [
    ['mcq', /(اختيار|اختر|متعدد|mcq|multiple|choice)/i],
    ['tf', /(صح|صواب|\btf\b|true|false)/i],
    ['fill', /(أكمل|اكمل|فراغ|املأ|املا|fill|blank)/i],
    ['match', /(توصيل|صل|مطابق|match)/i],
    ['table', /(جدول|table)/i],
    ['essay', /(مقال|essay|مفتوح|open)/i]
  ];
  var AI_HEAD = {
    'المادة': 'subject', 'مادة': 'subject', 'subject': 'subject',
    'الصف': 'grade', 'صف': 'grade', 'grade': 'grade', 'class': 'grade',
    'الفصل الدراسي': 'semester', 'الفصل': 'semester', 'semester': 'semester', 'term': 'semester',
    'العام الدراسي': 'year', 'العام': 'year', 'السنة الدراسية': 'year', 'year': 'year',
    'عنوان الاختبار': 'title', 'العنوان': 'title', 'title': 'title',
    'الزمن': 'duration', 'المدة': 'duration', 'duration': 'duration', 'time': 'duration',
    'الدرجة النهائية': 'maxscore', 'الدرجة الكلية': 'maxscore', 'الدرجة': 'maxscore', 'المجموع': 'maxscore',
    'total': 'maxscore', 'score': 'maxscore', 'total score': 'maxscore',
    'المدرسة': 'school', 'school': 'school', 'المعلم': 'teacher', 'مدرس المادة': 'teacher', 'teacher': 'teacher',
    'ملاحظات': 'notes', 'notes': 'notes', 'الوزارة': 'ministry', 'المحافظة': 'governorate', 'المديرية': 'directorate'
  };
  var AI_NUM = /^\s*\(?\s*(\d+|[٠-٩]+)\s*[\)\.\-–:]\s*(.*)$/;
  var AI_OPT = /^\s*\(?\s*([أبجدهـوزحطيa-hA-H])\s*[\)\-\.:]\s*(.+)$/;
  var AI_SEC_HASH = /^\s*#{1,6}\s*(?:سؤال|السؤال|question|q)(?=\s|[|:：\-–(]|$)\s*(.*)$/i;
  var AI_SEC_PLAIN = /^\s*(?:السؤال\s+(?:ال[ء-ي]+|\d+|[٠-٩]+)|س\s*[\d٠-٩]+|question\s*\d+|q\s*\d+)\s*(?:[:：\-–]|\(|\||$)\s*(.*)$/i;
  var AI_ANS = /^\s*#{0,6}\s*(?:(?:ال)?[إا]جابات|نموذج (?:ال)?[إا]جابة|answers?)\s*[:：]?\s*$/i;
  var AI_BLANK = /_{2,}|…|\.{3,}|\[\s*\]/;

  function aiDigits(s) {
    return String(s).replace(/[٠-٩]/g, function (d) { return '٠١٢٣٤٥٦٧٨٩'.indexOf(d); }).replace(/٫/g, '.').replace(',', '.');
  }
  function aiNum(s) { var v = parseFloat(aiDigits(s)); return isNaN(v) ? null : v; }
  function aiEsc(s) { return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); }
  function aiTypeFrom(v) {
    v = String(v || '').replace(/[_\-]/g, ' ');
    for (var i = 0; i < AI_TYPES.length; i++) if (AI_TYPES[i][1].test(v)) return AI_TYPES[i][0];
    return null;
  }
  function aiNormalize(text) {
    return String(text || '').replace(/\r/g, '')
      .replace(/^\s*```[a-z]*\s*$/gmi, '')
      .replace(/\*\*/g, '')
      .replace(/^\s*>\s?/gm, '')
      .replace(/[\u200e\u200f\u202a-\u202e]/g, '');
  }
  function aiParseAttrs(rest) {
    var a = { type: null, score: null, title: '' };
    var s = String(rest || '');
    var m = s.match(/(\d+(?:[.,٫]\d+)?|[٠-٩]+(?:[.,٫][٠-٩]+)?)\s*(?:درجات|درجة|marks?|points?|pts)/i);
    if (m) { a.score = aiNum(m[1]); s = s.replace(m[0], ' '); }
    s = s.replace(/[()\[\]]/g, ' ');
    var parts = s.split('|');
    parts.forEach(function (p, i) {
      p = p.trim();
      if (!p) return;
      var kv = p.match(/^([^=:：]{1,20})\s*[=:：]\s*(.+)$/);
      if (kv) {
        var k = kv[1].trim().toLowerCase();
        if (/^(نوع|type)$/.test(k)) a.type = aiTypeFrom(kv[2]);
        else if (/^(درجة|الدرجة|score|marks?|points?)$/.test(k)) { var n = aiNum(kv[2]); if (n !== null) a.score = n; }
        else if (/^(عنوان|العنوان|title|تعليمات|التعليمات)$/.test(k)) a.title = kv[2].trim();
        else if (!a.title) a.title = p;
        return;
      }
      if (/^[\d٠-٩]+$/.test(p)) return;                 // رقم السؤال
      var t = aiTypeFrom(p);
      if (t && p.length < 22 && !a.type) { a.type = t; return; }
      if (!a.title) a.title = p.replace(/^[:：\-–\s]+/, '');
    });
    return a;
  }
  function aiHasOptions(lines) {
    var c = 0;
    lines.forEach(function (l) { if (AI_OPT.test(l) || aiSplitInline(l)) c++; });
    return c >= 2;
  }
  /* "أ) س ب) ص ج) ع" في سطر واحد */
  function aiSplitInline(line) {
    var re = /(?:^|\s)\(?([أبجدهـوa-dA-D])[\)\-]\s+/g, hits = [], m;
    while ((m = re.exec(line)) !== null) hits.push({ i: m.index, end: re.lastIndex });
    if (hits.length < 2) return null;
    var q = line.slice(0, hits[0].i).trim(), opts = [];
    for (var k = 0; k < hits.length; k++) {
      opts.push(line.slice(hits[k].end, k + 1 < hits.length ? hits[k + 1].i : line.length).trim());
    }
    return { q: q, opts: opts };
  }
  function aiDetectType(lines) {
    var ne = lines.map(function (l) { return l.trim(); }).filter(Boolean);
    if (!ne.length) return 'essay';
    if (aiHasOptions(ne)) return 'mcq';
    var pipes = ne.filter(function (l) { return l.indexOf('|') >= 0 && !/^[\s|:\-]+$/.test(l); }).length;
    var pairs = ne.filter(function (l) { return /\s=\s|↔|⟷|->|→|::/.test(l); }).length;
    if (pairs >= 2 && pairs >= ne.length / 2) return 'match';
    if (pipes >= 2) return 'table';
    var tf = ne.filter(function (l) { return /\(\s*\)|\(\s*(صح|خطأ)|صح\s*أم\s*خطأ|\btrue\b|\bfalse\b|[✓✗✕]/i.test(l); }).length;
    if (tf >= ne.length / 2) return 'tf';
    var bl = ne.filter(function (l) { return AI_BLANK.test(l); }).length;
    if (bl >= ne.length / 2) return 'fill';
    return 'essay';
  }
  function aiItems(lines) {
    var items = [], cur = null, hasNum = lines.some(function (l) { return AI_NUM.test(l); });
    lines.forEach(function (raw) {
      var l = raw.trim();
      if (!l) return;
      var n = l.match(AI_NUM);
      if (n) { cur = n[2].trim(); items.push(cur); return; }
      if (hasNum && cur !== null) { items[items.length - 1] += ' ' + l; return; }
      var b = l.replace(/^[•\-\*]\s+/, '');
      items.push(b); cur = b;
    });
    return items;
  }
  function aiMcq(lines) {
    var items = [], cur = null;
    lines.forEach(function (raw) {
      var l = raw.trim();
      if (!l) return;
      var n = l.match(AI_NUM);
      if (n) {
        cur = { q: n[2].trim(), options: [] };
        var inl = aiSplitInline(cur.q);
        if (inl) { cur.q = inl.q; cur.options = inl.opts; }
        items.push(cur); return;
      }
      var inl2 = aiSplitInline(l);
      if (inl2 && !inl2.q) { if (!cur) { cur = { q: '', options: [] }; items.push(cur); } cur.options = cur.options.concat(inl2.opts); return; }
      var o = l.match(AI_OPT);
      if (o) { if (!cur) { cur = { q: '', options: [] }; items.push(cur); } cur.options.push(o[2].trim()); return; }
      if (!cur) { cur = { q: l, options: [] }; items.push(cur); }
      else if (!cur.options.length) cur.q += ' ' + l;
      else cur.options[cur.options.length - 1] += ' ' + l;
    });
    return items;
  }
  function aiMatchPairs(lines) {
    var pairs = [];
    aiItems(lines).forEach(function (it) {
      var m = it.split(/\s=\s|↔|⟷|->|→|::|\|/);
      if (m.length >= 2 && m[0].trim() && m[1].trim()) pairs.push([m[0].trim(), m.slice(1).join(' ').trim()]);
    });
    return pairs;
  }
  function aiTableRows(lines) {
    var rows = [];
    lines.forEach(function (l) {
      l = l.trim();
      if (!l || /^[\s|:\-]+$/.test(l)) return;
      l = l.replace(/^\|/, '').replace(/\|$/, '');
      rows.push(l.split('|').map(function (c) { return c.trim(); }));
    });
    return rows;
  }
  /* بناء بنية السؤال (items) من أسطره حسب نوعه */
  function aiBuildItems(sec) {
    var t = sec.type;
    if (t === 'mcq') return aiMcq(sec.lines);
    if (t === 'match') return aiMatchPairs(sec.lines);
    if (t === 'table') return aiTableRows(sec.lines);
    return aiItems(sec.lines);
  }
  function aiParseText(text) {
    var lines = aiNormalize(text).split('\n');
    var meta = {}, sections = [], cur = null, ignored = 0, inAnswers = false, sawHeader = false;
    lines.forEach(function (raw) {
      if (inAnswers) { if (raw.trim()) ignored++; return; }
      if (AI_ANS.test(raw)) { inAnswers = true; return; }
      var hm = raw.match(AI_SEC_HASH), pm = hm ? null : raw.match(AI_SEC_PLAIN);
      if (hm || pm) {
        var rest = (hm ? hm[1] : (pm[1] || ''));
        cur = { attrs: aiParseAttrs(rest), lines: [] };
        // عنوان بعد النقطتين في العنوان العادي: "السؤال الأول: اختر ..."
        if (!hm && !cur.attrs.title && rest.trim() && rest.indexOf('|') < 0) cur.attrs.title = rest.replace(/^[:：\-–\s]+/, '').trim();
        sections.push(cur); return;
      }
      if (!cur) {
        if (/^\s*#\s*(اختبار|exam)\s*$/i.test(raw)) { sawHeader = true; return; }
        var h = raw.match(/^\s*[-•*]?\s*([^:：]{1,24})\s*[:：]\s*(.+)$/);
        if (h) {
          var key = AI_HEAD[h[1].trim().toLowerCase()] || AI_HEAD[h[1].trim()];
          if (key) { meta[key] = h[2].trim(); sawHeader = true; return; }
        }
        (aiState_body || (aiState_body = [])).push(raw);
        return;
      }
      cur.lines.push(raw);
    });
    var body = aiState_body || []; aiState_body = null;

    // نص بلا عناوين أسئلة: نوزّع الفقرات تلقائياً على أنواعها ونجمع المتجاورة
    if (!sections.length && body.some(function (l) { return AI_NUM.test(l); })) {
      var units = [], u = null;
      body.forEach(function (l) {
        if (AI_NUM.test(l)) { u = [l]; units.push(u); }
        else if (u && l.trim()) u.push(l);
      });
      units.forEach(function (ul) {
        var t = aiDetectType(ul);
        var last = sections[sections.length - 1];
        if (last && last.attrs.type === t && !last.attrs.explicit) last.lines = last.lines.concat(ul);
        else sections.push({ attrs: { type: t, score: null, title: '' }, lines: ul.slice() });
      });
    }

    var qs = [];
    sections.forEach(function (sec) {
      var type = sec.attrs.type || aiDetectType(sec.lines);
      var q = { type: type, title: sec.attrs.title, score: sec.attrs.score, lines: sec.lines };
      q.items = aiBuildItems({ type: type, lines: sec.lines });
      if (type === 'match' && q.items.length < 2) { q.type = 'essay'; q.items = aiItems(sec.lines); }
      if (type === 'table' && q.items.length < 2) { q.type = 'essay'; q.items = aiItems(sec.lines); }
      if (!q.items.length) return;
      qs.push(q);
    });
    return { meta: meta, questions: qs, ignored: ignored, sawHeader: sawHeader };
  }
  var aiState_body = null;

  function aiSplitUnits(total, weights) {
    var units = Math.round(total * 2), sw = weights.reduce(function (a, b) { return a + b; }, 0) || 1;
    var base = weights.map(function (w) { return Math.floor(units * w / sw); });
    var rem = units - base.reduce(function (a, b) { return a + b; }, 0);
    var order = weights.map(function (w, i) { return { i: i, f: units * w / sw - base[i] }; })
      .sort(function (a, b) { return b.f - a.f; });
    for (var k = 0; k < rem; k++) base[order[k % order.length].i]++;
    return base.map(function (b) { return b / 2; });
  }
  function aiWeight(q) { return Math.max(1, q.type === 'table' ? q.items.length - 1 : q.items.length); }
  function aiScores(qs, target, auto) {
    var given = qs.map(function (q) { return q.score !== null && q.score !== undefined ? q.score : null; });
    var all = given.every(function (g) { return g !== null; });
    var sum = given.reduce(function (a, g) { return a + (g || 0); }, 0);
    if (auto) {
      if (all && Math.abs(sum - target) < 0.01) return given;
      return aiSplitUnits(target, qs.map(aiWeight));
    }
    if (all) return given;
    var missing = [];
    qs.forEach(function (q, i) { if (given[i] === null) missing.push(i); });
    var fill = aiSplitUnits(Math.max(0, target - sum), missing.map(function (i) { return aiWeight(qs[i]); }));
    missing.forEach(function (i, k) { given[i] = fill[k]; });
    return given;
  }

  function aiDots(n) { return new Array(n + 1).join('.'); }
  function aiFillText(t) {
    var s = aiEsc(t).replace(/_{2,}|…+|\.{3,}|\[\s*\]/g, aiDots(28));
    return s;
  }
  function aiTfText(t) {
    return aiEsc(t.replace(/[\(\[]?\s*(صح|خطأ|صواب|✓|✗|✕|true|false)\s*[\)\]]?\s*$/i, '').replace(/^\s*[\(\[]\s*(✓|✗|✕)?\s*[\)\]]\s*/, '').trim());
  }
  function aiShuffle(arr) {                      // إزاحة ثابتة تضمن عدم بقاء أي عنصر في موضعه الصحيح (n ≥ 2)
    var n = arr.length, shift = Math.floor(n / 2) + 1;
    if (n < 2) return arr.slice();
    if (shift % n === 0) shift = 1;
    return arr.map(function (_, i) { return arr[(i + shift) % n]; });
  }
  function aiHtml(q, opts, isEn) {
    var out = [], i;
    var AR_L = ['أ', 'ب', 'جـ', 'د', 'هـ', 'و', 'ز', 'ح'], EN_L = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
    var L = isEn ? EN_L : AR_L;
    switch (q.type) {
      case 'mcq':
        q.items.forEach(function (it, n) {
          var cols = Math.min(Math.max(it.options.length, 1), 4);
          var html = '<table class="borderless-table"><tr><td colspan="' + cols + '">' + (n + 1) + '- ' + aiEsc(it.q) + '</td></tr>';
          for (var r = 0; r < it.options.length; r += cols) {
            html += '<tr>';
            for (var c = 0; c < cols; c++) {
              var k = r + c;
              html += k < it.options.length ? '<td>' + L[k] + ') ' + aiEsc(it.options[k]) + '</td>' : '<td></td>';
            }
            html += '</tr>';
          }
          out.push(html + '</table>');
        });
        return out.join('');
      case 'tf':
        return q.items.map(function (t, n) { return '<div>' + (n + 1) + '- ( &nbsp;&nbsp;&nbsp; ) ' + aiTfText(t) + '</div>'; }).join('');
      case 'fill':
        return q.items.map(function (t, n) {
          var h = aiFillText(t);
          if (!AI_BLANK.test(t)) h += ' ' + aiDots(28);
          return '<div>' + (n + 1) + '- ' + h + '</div>';
        }).join('');
      case 'match': {
        var right = aiShuffle(q.items.map(function (p) { return p[1]; }));
        var th = isEn ? ['Column (A)', 'Column (B)'] : ['العمود (أ)', 'العمود (ب)'];
        var html = '<table class="borderless-table"><tr><th style="width:42%; border-bottom:1px solid #000 !important;">' + th[0] +
          '</th><th style="width:16%;"></th><th style="width:42%; border-bottom:1px solid #000 !important;">' + th[1] + '</th></tr>';
        for (i = 0; i < q.items.length; i++) {
          html += '<tr><td>' + (i + 1) + '- ' + aiEsc(q.items[i][0]) + '</td><td style="text-align:center;">( &nbsp;&nbsp;&nbsp; )</td><td>' +
            L[i] + '- ' + aiEsc(right[i]) + '</td></tr>';
        }
        return html + '</table>';
      }
      case 'table': {
        var cols2 = Math.max.apply(null, q.items.map(function (r) { return r.length; }));
        var h2 = '<table>';
        q.items.forEach(function (row, ri) {
          h2 += '<tr>';
          for (var c = 0; c < cols2; c++) {
            var cell = row[c] === undefined || row[c] === '' ? '&nbsp;' : aiEsc(row[c]);
            h2 += ri === 0 ? '<th>' + cell + '</th>' : '<td>' + cell + '</td>';
          }
          h2 += '</tr>';
        });
        return h2 + '</table>';
      }
      default:
        return q.items.map(function (t, n) {
          return '<div>' + (n + 1) + '- ' + aiEsc(t) + '</div>' + (opts.essayLines ? '<div>' + aiDots(84) + '</div>' : '');
        }).join('');
    }
  }
  function aiSummary(P) {
    var target = aiNum(P.meta.maxscore || '') || parseFloat(currentExam.meta.maxScore) || 0;
    return {
      meta: P.meta, target: target, ignored: P.ignored, hasHeader: P.sawHeader,
      questions: P.questions.map(function (q) {
        return { type: q.type, label: AI_TYPE_LABEL[q.type] || q.type, title: q.title, score: q.score,
                 items: q.type === 'table' ? Math.max(0, q.items.length - 1) : q.items.length,
                 sample: String(q.type === 'mcq' ? q.items[0].q : (q.type === 'match' ? q.items[0][0] :
                          (q.type === 'table' ? (q.items[0] || []).join(' | ') : q.items[0]))).slice(0, 90) };
      })
    };
  }


  /* ============ محوّل نص السؤال: HTML <-> كتل (يخدم المحرر الأصلي بلا واجهة ويب) ============ */
  var Q_FONT = { sm: '0.85em', lg: '1.25em', xl: '1.6em' };
  var Q_INLINE_OK = { SPAN: 1, B: 1, STRONG: 1, I: 1, EM: 1, U: 1, S: 1, STRIKE: 1, DEL: 1, SUB: 1, SUP: 1, FONT: 1, MARK: 1, SMALL: 1, BIG: 1, A: 1 };

  function qHex(c) {
    if (!c) return '';
    var m = String(c).match(/rgba?\(\s*(\d+)[,\s]+(\d+)[,\s]+(\d+)/);
    if (m) return '#' + [m[1], m[2], m[3]].map(function (v) { return ('0' + parseInt(v, 10).toString(16)).slice(-2); }).join('');
    return String(c).toLowerCase();
  }
  function qEsc(t) {
    return String(t).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      .replace(/\u00a0/g, '&nbsp;').replace(/ {2,}/g, function (m) { return ' ' + new Array(m.length).join('&nbsp;'); })
      .replace(/\n/g, '<br>');
  }
  function qSizeOf(el) {
    var fs = el.style && el.style.fontSize;
    if (el.tagName === 'FONT' && el.getAttribute('size')) {
      var n = parseInt(el.getAttribute('size'), 10);
      return n <= 2 ? 'sm' : (n <= 4 ? '' : (n === 5 ? 'lg' : 'xl'));
    }
    if (!fs) return '';
    if (/^(x-small|xx-small|small|smaller)$/.test(fs)) return 'sm';
    if (/^(large|larger)$/.test(fs)) return 'lg';
    if (/^(x-large|xx-large)$/.test(fs)) return 'xl';
    var m = fs.match(/^([\d.]+)(em|%)$/);
    if (m) { var v = parseFloat(m[1]) / (m[2] === '%' ? 100 : 1); return v < 0.95 ? 'sm' : (v < 1.4 ? (v > 1.05 ? 'lg' : '') : 'xl'); }
    return '';
  }
  function qIsImgBox(n) { return n.nodeType === 1 && n.classList && n.classList.contains('img-wrap-box'); }
  function qIsAtom(n) {
    if (n.tagName === 'IMG' || qIsImgBox(n)) return true;
    if (!Q_INLINE_OK[n.tagName]) return n.tagName !== 'BR';
    var d = n.style && n.style.display;
    if (d === 'inline-block' || d === 'block' || d === 'inline-table') return true;
    // عناصر بحدود (جذر، خط فوق، مربعات…) تُحفظ كما هي ولا تُفكَّك
    if (n.style && (n.style.borderTopStyle || n.style.borderBottomStyle || n.style.borderLeftStyle || n.style.borderRightStyle)) return true;
    if (n.querySelector && n.querySelector('[style*="border"]')) return true;
    if (n.classList && (n.classList.contains('img-arrow-marker'))) return true;
    return false;
  }
  function qFlags(st) {
    var o = {};
    ['b', 'i', 'u', 's', 'sup', 'sub'].forEach(function (k) { if (st[k]) o[k] = 1; });
    if (st.c) o.c = st.c; if (st.bg) o.bg = st.bg; if (st.sz) o.sz = st.sz;
    return o;
  }
  function qSame(a, b) {
    if (a.atom || b.atom) return false;
    var ka = Object.keys(a).filter(function (k) { return k !== 'x'; }).sort().join(), kb = Object.keys(b).filter(function (k) { return k !== 'x'; }).sort().join();
    if (ka !== kb) return false;
    return Object.keys(a).every(function (k) { return k === 'x' || a[k] === b[k]; });
  }
  function qPush(out, run) {
    var last = out[out.length - 1];
    if (last && run.x !== undefined && last.x !== undefined && qSame(last, run)) last.x += run.x;
    else out.push(run);
  }
  function qInline(node, st, out) {
    if (node.nodeType === 3) { var tv = node.nodeValue.replace(/[ \t\r\n\f]+/g, ' '); if (tv) qPush(out, Object.assign({ x: tv }, qFlags(st))); return; }
    if (node.nodeType !== 1) return;
    if (node.tagName === 'BR') { qPush(out, Object.assign({ x: '\n' }, qFlags(st))); return; }
    if (qIsAtom(node)) {
      var lbl = node.tagName === 'IMG' || qIsImgBox(node) ? '🖼' : (node.textContent || '').replace(/\s+/g, ' ').trim().slice(0, 24) || '▣';
      out.push({ atom: node.outerHTML, label: lbl });
      return;
    }
    var s2 = Object.assign({}, st), t = node.tagName, css = node.style || {};
    if (t === 'B' || t === 'STRONG') s2.b = 1;
    if (t === 'I' || t === 'EM') s2.i = 1;
    if (t === 'U') s2.u = 1;
    if (t === 'S' || t === 'STRIKE' || t === 'DEL') s2.s = 1;
    if (t === 'SUP') s2.sup = 1;
    if (t === 'SUB') s2.sub = 1;
    if (t === 'MARK') s2.bg = '#fff176';
    if (css.fontWeight && (css.fontWeight === 'bold' || parseInt(css.fontWeight, 10) >= 600)) s2.b = 1;
    if (css.fontStyle === 'italic') s2.i = 1;
    var dec = (css.textDecorationLine || css.textDecoration || '');
    if (/underline/.test(dec)) s2.u = 1;
    if (/line-through/.test(dec)) s2.s = 1;
    if (css.verticalAlign === 'super') s2.sup = 1;
    if (css.verticalAlign === 'sub') s2.sub = 1;
    var col = css.color || (t === 'FONT' ? node.getAttribute('color') : '');
    if (col) s2.c = qHex(col);
    if (css.backgroundColor) s2.bg = qHex(css.backgroundColor);
    var sz = qSizeOf(node); if (sz) s2.sz = sz;
    Array.prototype.forEach.call(node.childNodes, function (ch) { qInline(ch, s2, out); });
  }
  function qHasContent(runs) { return runs.some(function (r) { return r.atom || (r.x && r.x.replace(/[\s\u00a0]/g, '') !== ''); }); }
  function qAlign(el) {
    var a = (el.style && el.style.textAlign) || el.getAttribute && el.getAttribute('align') || '';
    return /^(right|left|center|justify)$/.test(a) ? a : '';
  }
  function qTrim(runs) {          // مسافات التنسيق في أطراف الفقرة لا تُعرض في HTML فلا نحتفظ بها
    while (runs.length && runs[0].x !== undefined && /^ +$/.test(runs[0].x)) runs.shift();
    if (runs.length && runs[0].x !== undefined) runs[0].x = runs[0].x.replace(/^ +/, '');
    while (runs.length && runs[runs.length - 1].x !== undefined && /^ +$/.test(runs[runs.length - 1].x)) runs.pop();
    var l = runs[runs.length - 1];
    if (l && l.x !== undefined) l.x = l.x.replace(/ +$/, '');
    return runs.filter(function (r) { return r.atom || r.x !== ''; });
  }
  function qNewPara(runs, el) {
    var p = { t: 'p', runs: qTrim(runs) };
    var a = el ? qAlign(el) : ''; if (a) p.align = a;
    if (el && el.style && el.style.borderTopStyle && el.style.borderTopStyle !== 'none') p.box = 1;
    return p;
  }
  function qCleanRuns(runs) {            // يحذف فراغات طرفية ناتجة عن تنسيق HTML فقط
    return runs;
  }
  function qImage(box) {
    var img = box.tagName === 'IMG' ? box : box.querySelector('img');
    if (!img) return { t: 'raw', html: box.outerHTML, label: 'عنصر' };
    var b = { t: 'img', src: img.getAttribute('src') || '' };
    var wrap = 'wrap-center', shape = 'img-borderless';
    if (box !== img) Array.prototype.forEach.call(box.classList, function (c) { if (/^wrap-/.test(c)) wrap = c; });
    Array.prototype.forEach.call(img.classList, function (c) { if (/^img-(borderless|square|rounded|circle|double|dashed)$/.test(c)) shape = c; });
    b.wrap = wrap; b.shape = shape;
    b.w = (box !== img ? box.style.width : img.style.width) || '40%';
    if (wrap === 'wrap-front') { b.top = box.style.top || '15px'; b.left = box.style.left || '25%'; }
    b.arrows = [];
    if (box !== img) Array.prototype.forEach.call(box.querySelectorAll('.img-arrow-marker'), function (a) {
      var lab = a.querySelector('span');
      var dir = '';
      Array.prototype.forEach.call(a.childNodes, function (n) { if (n.nodeType === 3) dir += n.nodeValue; });
      b.arrows.push({ dir: dir.trim() || '⬅️', color: qHex(a.style.color) || '#dc2626',
                      x: parseFloat(a.style.left) || 45, y: parseFloat(a.style.top) || 45, label: lab ? lab.textContent : '' });
    });
    return b;
  }
  function qOnlyImages(nodes) {
    var imgs = [], other = false;
    nodes.forEach(function (n) {
      if (n.nodeType === 3) { if (n.nodeValue.replace(/[\s\u00a0]/g, '')) other = true; return; }
      if (qIsImgBox(n) || n.tagName === 'IMG') imgs.push(n);
      else if (n.tagName === 'BR') return;
      else other = true;
    });
    return { imgs: imgs, other: other };
  }
  function qParaFrom(el, depthInfo) {
    var nodes = Array.prototype.slice.call(el.childNodes), blocks = [];
    // صور عائمة في مقدمة الفقرة (التفاف مشدود) ← كتلة صورة + فقرة
    var lead = [];
    while (nodes.length && qIsImgBox(nodes[0]) && /wrap-tight/.test(nodes[0].className)) lead.push(nodes.shift());
    lead.forEach(function (n) { blocks.push(qImage(n)); });
    var chk = qOnlyImages(nodes);
    if (!lead.length && chk.imgs.length && !chk.other) {
      chk.imgs.forEach(function (n) { blocks.push(qImage(n)); });
      return blocks;
    }
    var runs = [];
    nodes.forEach(function (n) { qInline(n, {}, runs); });
    if (runs.length === 1 && runs[0].x === '\n') runs = [];          // <div><br></div>
    if (qHasContent(runs) || !lead.length) blocks.push(qNewPara(runs, el));
    return blocks;
  }
  function qCell(cell, depth) {
    var blocks = qBlocks(cell, depth + 1);
    if (!blocks.length) blocks.push({ t: 'p', runs: [] });
    var c = { blocks: blocks };
    if (cell.tagName === 'TH') c.th = 1;
    if (cell.colSpan > 1) c.colspan = cell.colSpan;
    if (cell.rowSpan > 1) c.rowspan = cell.rowSpan;
    var st = cell.getAttribute('style'); if (st) c.style = st;
    return c;
  }
  function qTable(tbl, depth) {
    var t = { t: 'table', rows: [], cls: Array.prototype.filter.call(tbl.classList, function (c) { return c !== 'ProseMirror'; }).join(' ') };
    var st = tbl.getAttribute('style'); if (st) t.style = st;
    Array.prototype.forEach.call(tbl.rows, function (row) {
      t.rows.push(Array.prototype.map.call(row.cells, function (c) { return qCell(c, depth); }));
    });
    t.complex = t.rows.some(function (r) { return r.some(function (c) { return c.colspan || c.rowspan; }); }) ||
                t.rows.some(function (r) { return r.length !== t.rows[0].length; });
    return t;
  }
  function qList(list, depth, level, out) {
    var kind = list.tagName === 'OL' ? 'ol' : 'ul';
    Array.prototype.forEach.call(list.children, function (li) {
      if (li.tagName !== 'LI') return;
      var runs = [], nested = [];
      Array.prototype.forEach.call(li.childNodes, function (n) {
        if (n.nodeType === 1 && (n.tagName === 'UL' || n.tagName === 'OL')) nested.push(n); else qInline(n, {}, runs);
      });
      var p = qNewPara(runs, li); p.list = kind; if (level) p.indent = level;
      out.push(p);
      nested.forEach(function (n) { qList(n, depth, level + 1, out); });
    });
  }
  function qBlocks(container, depth) {
    depth = depth || 0;
    var blocks = [], pending = null;
    function flush() { if (pending) { pending.runs = qTrim(pending.runs); if (qHasContent(pending.runs) || pending.runs.length) blocks.push(pending); } pending = null; }
    Array.prototype.forEach.call(container.childNodes, function (n) {
      if (n.nodeType === 3) {
        if (!n.nodeValue.replace(/[\s\u00a0]/g, '') && !pending) return;
        pending = pending || { t: 'p', runs: [] }; qInline(n, {}, pending.runs); return;
      }
      if (n.nodeType !== 1) return;
      var t = n.tagName;
      if (t === 'DIV' || t === 'P' || /^H[1-6]$/.test(t)) {
        flush();
        var hasBlock = n.querySelector(':scope > table, :scope > ul, :scope > ol, :scope > div, :scope > p, :scope > blockquote, :scope > hr');
        if (hasBlock && !(n.style && n.style.borderTopStyle && n.style.borderTopStyle !== 'none')) {
          var inner = qBlocks(n, depth), al = qAlign(n);
          inner.forEach(function (b) { if (b.t === 'p' && al && !b.align) b.align = al; blocks.push(b); });
        } else {
          var made = qParaFrom(n);
          if (/^H[1-6]$/.test(t)) made.forEach(function (b) { if (b.t === 'p') b.runs.forEach(function (r) { r.b = 1; }); });
          made.forEach(function (b) { blocks.push(b); });
        }
        return;
      }
      if (t === 'TABLE') { flush(); blocks.push(depth >= 1 ? { t: 'raw', html: n.outerHTML, label: 'جدول متداخل' } : qTable(n, depth)); return; }
      if (t === 'UL' || t === 'OL') { flush(); qList(n, depth, 0, blocks); return; }
      if (t === 'BLOCKQUOTE') {
        flush();
        qBlocks(n, depth).forEach(function (b) { if (b.t === 'p') b.indent = (b.indent || 0) + 1; blocks.push(b); });
        return;
      }
      if (t === 'HR') { flush(); blocks.push({ t: 'raw', html: n.outerHTML, label: 'خط أفقي', kind: 'hr' }); return; }
      if (qIsImgBox(n) || t === 'IMG') {
        if (!pending || !qHasContent(pending.runs)) { flush(); blocks.push(qImage(n)); return; }
      }
      if (qIsAtom(n) && !Q_INLINE_OK[t] && t !== 'IMG' && !qIsImgBox(n)) {
        flush(); blocks.push({ t: 'raw', html: n.outerHTML, label: 'عنصر متقدم' }); return;
      }
      pending = pending || { t: 'p', runs: [] }; qInline(n, {}, pending.runs);
    });
    flush();
    return blocks;
  }
  function qParse(html) {
    var box = document.createElement('div');
    box.innerHTML = html || '';
    var blocks = qBlocks(box, 0);
    return blocks.length ? blocks : [{ t: 'p', runs: [] }];
  }

  // ---------- التسلسل إلى HTML ----------
  function qRunHtml(r) {
    if (r.atom) return r.atom;
    var h = qEsc(r.x);
    if (r.sup) h = '<sup>' + h + '</sup>';
    if (r.sub) h = '<sub>' + h + '</sub>';
    if (r.s) h = '<s>' + h + '</s>';
    if (r.u) h = '<u>' + h + '</u>';
    if (r.i) h = '<i>' + h + '</i>';
    if (r.b) h = '<b>' + h + '</b>';
    var st = [];
    if (r.c) st.push('color:' + r.c);
    if (r.bg) st.push('background-color:' + r.bg);
    if (r.sz && Q_FONT[r.sz]) st.push('font-size:' + Q_FONT[r.sz]);
    if (st.length) h = '<span style="' + st.join(';') + '">' + h + '</span>';
    return h;
  }
  function qRunsHtml(runs) { return (runs || []).map(qRunHtml).join(''); }
  function qParaStyle(p) {
    var st = [];
    if (p.align) st.push('text-align:' + p.align);
    if (p.indent && !p.list) st.push('margin-right:' + (p.indent * 30) + 'px');
    if (p.box) st.push('border:1.5px solid #000;padding:8px;margin:6px 0;min-height:34px');
    return st.length ? ' style="' + st.join(';') + '"' : '';
  }
  function qParaHtml(p, prefix) {
    var inner = (prefix || '') + qRunsHtml(p.runs);
    if (!inner) inner = '<br>';
    return '<div' + qParaStyle(p) + '>' + inner + '</div>';
  }
  function qImgHtml(b) {
    var st = 'width:' + (b.w || '40%') + ';';
    if (b.wrap === 'wrap-front') st += 'position:absolute;top:' + (b.top || '15px') + ';left:' + (b.left || '25%') + ';';
    else st += 'position:relative;';
    var arrows = (b.arrows || []).map(function (a) {
      var lab = a.label ? '<span style="font-size:12px; background:#fff; padding:0 3px; border:1px solid ' + a.color + '; border-radius:3px; margin-inline-start:2px;">' + qEsc(a.label) + '</span>' : '';
      return '<span class="img-arrow-marker" style="left:' + a.x + '%;top:' + a.y + '%;color:' + a.color + ';">' + (a.dir || '') + lab + '</span>';
    }).join('');
    return '<span class="img-wrap-box ' + (b.wrap || 'wrap-center') + '" contenteditable="false" style="' + st + '">' +
      '<img src="' + b.src + '" class="exam-img ' + (b.shape || 'img-borderless') + '" alt="صورة">' +
      '<span class="img-resize-handle" title="اسحب لتغيير الحجم"></span>' + arrows + '</span>';
  }
  function qListHtml(items) {
    var kind = items[0].list, h = '<' + kind + ' style="margin:4px 0;padding-inline-start:28px">';
    items.forEach(function (p) {
      var st = [];
      if (p.align) st.push('text-align:' + p.align);
      if (p.indent) st.push('margin-inline-start:' + (p.indent * 24) + 'px');
      h += '<li' + (st.length ? ' style="' + st.join(';') + '"' : '') + '>' + (qRunsHtml(p.runs) || '<br>') + '</li>';
    });
    return h + '</' + kind + '>';
  }
  function qTableHtml(t) {
    var h = '<table' + (t.cls ? ' class="' + t.cls + '"' : '') + (t.style ? ' style="' + t.style + '"' : '') + '>';
    t.rows.forEach(function (row) {
      h += '<tr>';
      row.forEach(function (c) {
        var tag = c.th ? 'th' : 'td';
        h += '<' + tag + (c.colspan ? ' colspan="' + c.colspan + '"' : '') + (c.rowspan ? ' rowspan="' + c.rowspan + '"' : '') +
          (c.style ? ' style="' + c.style + '"' : '') + '>';
        var inner = qSerialize(c.blocks || []);
        // خلية ذات فقرة واحدة بسيطة: نكتب محتواها مباشرة كما في الأصل
        var m = inner.match(/^<div><br><\/div>$/);
        if (m) inner = '&nbsp;';
        else if (c.blocks && c.blocks.length === 1 && c.blocks[0].t === 'p' && !c.blocks[0].align && !c.blocks[0].list && !c.blocks[0].box) inner = qRunsHtml(c.blocks[0].runs) || '&nbsp;';
        h += inner + '</' + tag + '>';
      });
      h += '</tr>';
    });
    return h + '</table>';
  }
  function qSerialize(blocks) {
    var out = '', i = 0;
    while (i < blocks.length) {
      var b = blocks[i];
      if (b.t === 'img') {
        var h = qImgHtml(b), nx = blocks[i + 1];
        if (/wrap-tight/.test(b.wrap || '') && nx && nx.t === 'p' && !nx.list && !nx.box) { out += qParaHtml(nx, h); i += 2; continue; }
        out += '<div>' + h + '</div>';
      } else if (b.t === 'p' && b.list) {
        var items = [b];
        while (blocks[i + 1] && blocks[i + 1].t === 'p' && blocks[i + 1].list === b.list) { items.push(blocks[i + 1]); i++; }
        out += qListHtml(items);
      } else if (b.t === 'p') out += qParaHtml(b);
      else if (b.t === 'table') out += qTableHtml(b);
      else if (b.t === 'raw') out += b.html;
      i++;
    }
    return out;
  }

  window.Exam6Api = {
    /* ---------- قراءة الحالة ---------- */
    state: function () {
      var e = currentExam, m = e.meta, d = e.design;
      var meta = {};
      META.forEach(function (k) {
        var v = k === 'maxscore' ? m.maxScore : m[k];
        meta[k] = v === undefined || v === null ? '' : String(v);
      });
      var vis = {};
      Object.keys(VIS).forEach(function (k) { vis[k] = !(e.visibility && e.visibility[k] === false); });
      return {
        id: e.id, meta: meta, visibility: vis,
        design: { lang: d.lang || 'ar', tableMode: d.tableMode || 'mode-grid',
                  fontSize: parseFloat(d.fontSize) || 13.5, pageFit: d.pageFit || 'custom' },
        questions: e.questions.map(function (q) {
          var h = q.content || '';
          return { id: q.id, name: q.name || '', subtitle: q.subtitle || '', score: parseFloat(q.score) || 0,
                   text: plain(h).slice(0, 140), hasImage: /<img/i.test(h), hasTable: /<table/i.test(h) };
        }),
        sums: sums()
      };
    },
    designState: function () {
      var d = currentExam.design;
      var fonts = [];
      var sel = $('tpl-font');
      for (var i = 0; i < sel.options.length; i++) fonts.push({ value: sel.options[i].value, label: sel.options[i].textContent });
      return {
        lang: d.lang || 'ar', tableMode: d.tableMode || 'mode-grid', fontFamily: d.fontFamily,
        fontSize: parseFloat(d.fontSize) || 13.5, fontWeight: String(d.fontWeight || '700'),
        lineHeight: String(d.lineHeight || '1.45'), pageFrame: d.pageFrame || 'none',
        borderColor: d.borderColor || '#000000',
        wmOpacity: d.watermarkOpacity || 8, wmScale: d.watermarkScale || 75,
        logo: d.customLogo || '', watermark: d.watermarkImg || '', fonts: fonts
      };
    },
    sums: function () { return sums(); },

    /* ---------- بيانات الرأس والإظهار ---------- */
    setMeta: function (k, v) {
      var el = $('meta-' + k);
      if (!el) return null;
      el.value = v;
      syncMeta();
      return sums();
    },
    setVisibility: function (k, on) {
      var id = VIS[k];
      if (!id) return false;
      $(id).checked = !!on;
      syncHeaderVisibility();
      return true;
    },



    /* ---------- خدمة تحويل نص السؤال للمحرر الأصلي ---------- */
    qGet: function (idx) {
      var q = currentExam.questions[idx];
      return q ? { id: q.id, name: q.name, blocks: qParse(q.content || '') } : null;
    },
    qSet: function (idx, model, render) {
      var q = currentExam.questions[idx];
      if (!q || !model || !model.blocks) return false;
      var html = qSerialize(model.blocks);
      q.content = html;
      var h = questionHistory[q.id] || (questionHistory[q.id] = { stack: [html], index: 0 });
      if (h.stack[h.index] !== html) {
        h.stack = h.stack.slice(0, h.index + 1); h.stack.push(html);
        if (h.stack.length > 60) h.stack.shift();
        h.index = h.stack.length - 1;
      }
      var ed = $('rich_ed_' + q.id); if (ed) ed.innerHTML = html;
      recalculateScores();
      if (render !== false) renderLivePreview();
      return true;
    },
    htmlToBlocks: function (html) { return { blocks: qParse(html) }; },
    blocksToHtml: function (model) { return qSerialize(model.blocks || []); },

    /* ---------- الاستيراد الذكي ---------- */
    aiParse: function (text) {
      aiState = aiParseText(text);
      return aiSummary(aiState);
    },
    aiImport: function (opts) {
      var P = aiState;
      if (!P || !P.questions.length) return null;
      opts = opts || {};
      var isEn = currentExam.design.lang === 'en';
      if (opts.fillMeta !== false) {
        Object.keys(P.meta).forEach(function (k) {
          var el = $('meta-' + k);
          if (!el) return;
          var v = P.meta[k];
          if (k === 'maxscore') { var n = aiNum(v); if (n === null) return; v = String(n); }
          if (k === 'duration' && /^[\d٠-٩]+$/.test(v.trim())) v = v.trim() + (isEn ? ' minutes' : ' دقيقة');
          el.value = v;
        });
        syncMeta();
      }
      if (opts.replace !== false) currentExam.questions = [];
      var existing = currentExam.questions.reduce(function (a, q) { return a + (parseFloat(q.score) || 0); }, 0);
      var maxScore = parseFloat(currentExam.meta.maxScore) || aiNum(P.meta.maxscore || '') || 40;
      var target = opts.replace !== false ? maxScore : Math.max(maxScore - existing, P.questions.length);
      var scores = aiScores(P.questions, target, opts.autoScores !== false);
      var sub = AI_SUBTITLE[isEn ? 'en' : 'ar'];
      P.questions.forEach(function (q, i) {
        var content = aiHtml(q, { essayLines: opts.essayLines !== false }, isEn);
        var id = 'q_' + Date.now() + '_' + i + '_' + Math.random().toString(36).substr(2, 4);
        currentExam.questions.push({
          id: id, name: getNextQuestionName(currentExam.questions.length),
          subtitle: q.title || sub[q.type] || '', content: content, score: scores[i]
        });
        questionHistory[id] = { stack: [content], index: 0 };
      });
      renderQuestionsEditor(); recalculateScores(); renderLivePreview();
      var r = sums();
      return { added: P.questions.length, sum: r.sum, target: r.target, match: r.match };
    },

    /* ---------- القوالب والتنسيق ---------- */
    setDesign: function (k, v) {
      var id = DES[k];
      if (!id) return false;
      populateDesignControls();           // مزامنة حقول الواجهة مع الحالة قبل التعديل
      $(id).value = v;
      updateDesignSettings();
      if (k === 'lang') { try { updateLangButtonLabel(); } catch (e) {} }
      return true;
    },
    fontSize: function (v) { changeCustomFontSize(v); populateDesignControls(); return true; },
    syncTableMode: function (v) { syncQuickTableMode(v); populateDesignControls(); return true; },
    pageFit: function (mode) { applyPageFitPreset(mode); populateDesignControls(); return true; },
    presetBold: function () { applyPresetBold135(); populateDesignControls(); return true; },
    presetWatermark: function () { applyPresetWatermark(); populateDesignControls(); return true; },
    toggleLang: function () { toggleExamLanguage(); return true; },
    wmOpacity: function (v) { updateWatermarkOpacity(v); return true; },
    wmScale: function (v) { updateWatermarkScale(v); return true; },
    removeLogo: function () { removeCustomLogo(); return true; },
    removeWatermark: function () { removeWatermark(); return true; },
    setLogo: function (item) { handleLogoUpload({ target: { files: [fileFrom(item, 0)] } }); return true; },
    setWatermark: function (item) { handleWatermarkUpload({ target: { files: [fileFrom(item, 0)] } }); return true; },

    /* ---------- الأسئلة ---------- */
    addQuestion: function (type) { addQuestionByType(type); return true; },
    move: function (idx, dir) { moveQuestion(idx, dir); return true; },
    duplicate: function (idx) { duplicateQuestion(idx); return true; },
    remove: function (idx) {
      if (idx < 0 || idx >= currentExam.questions.length) return false;
      currentExam.questions.splice(idx, 1);
      renderQuestionsEditor(); recalculateScores(); renderLivePreview();
      return true;
    },
    setQuestion: function (idx, field, val) {
      if (!currentExam.questions[idx]) return null;
      if (field === 'score') val = parseFloat(val) || 0;
      updateQuestionField(idx, field, val);
      return sums();
    },
    newExam: function () {
      currentExam = getDefaultExamState();
      populateEditorFromState(); applyDesignVariables(); renderLivePreview();
      return true;
    },

    /* ---------- اللصق الجماعي ---------- */
    analyzePaste: function (text) {
      $('bulk-paste-input').value = text;
      analyzeBulkPaste();
      return parsedBulkQuestions.map(function (q) {
        return { name: q.name, subtitle: q.subtitle, lines: q.bodyLines.length };
      });
    },
    confirmPaste: function () { confirmBulkImport(); return true; },

    /* ---------- وضع تحرير نص سؤال واحد ---------- */
    focus: function (qid) {
      navigateTo('editor');
      renderQuestionsEditor();
      var ed = $('rich_ed_' + qid);
      if (!ed) return false;
      document.querySelectorAll('.exam6-focused').forEach(function (x) { x.classList.remove('exam6-focused'); });
      ed.classList.add('exam6-focused');
      activeEditorId = ed.id;
      lastRange = null;
      return true;
    },
    unfocus: function () {
      document.querySelectorAll('.exam6-focused').forEach(function (x) { x.classList.remove('exam6-focused'); });
      var a = document.activeElement;
      if (a && a.blur) a.blur();
      return true;
    },
    selection: function () { return { img: !!selectedImageEl, table: !!selectedTableEl }; },
    undo: function () { var i = focusedIndex(); if (i >= 0) undoQuestionChange(i); return true; },
    redo: function () { var i = focusedIndex(); if (i >= 0) redoQuestionChange(i); return true; },
    /* إدراج HTML (رموز رياضية وقوالب) عند موضع المؤشر المحفوظ */
    insertHtml: function (html) {
      var ed = activeEditorId ? $(activeEditorId) : null;
      if (!ed) return false;
      ed.focus();
      var sel = window.getSelection();
      var range;
      if (lastRange && ed.contains(lastRange.startContainer)) {
        range = lastRange.cloneRange();
      } else {
        range = document.createRange();
        range.selectNodeContents(ed); range.collapse(false);
      }
      // إدراج يدوي: execCommand('insertHTML') يمزّق العناصر block داخل الكسور ويحذف أنماطها
      var tpl = document.createElement('template');
      tpl.innerHTML = html;
      var frag = tpl.content;
      var last = frag.lastChild;
      range.deleteContents();
      range.insertNode(frag);
      if (last) {
        var after = document.createRange();
        after.setStartAfter(last); after.collapse(true);
        sel.removeAllRanges(); sel.addRange(after);
        lastRange = after.cloneRange();
      }
      ed.dispatchEvent(new Event('input'));
      return true;
    },
    cmd: function (name) {
      return withSel(function () {
        document.execCommand('styleWithCSS', false, false);
        document.execCommand(name, false, null);
      });
    },
    cmdVal: function (name, val) {
      return withSel(function () {
        document.execCommand('styleWithCSS', false, true);
        document.execCommand(name, false, val);
      });
    },
    color: function (hex) {
      return withSel(function () { applyTextColor(activeEditorId, hex); });
    },
    /* حالة التنسيق عند المؤشر (لتظليل الأزرار النشطة) */
    formatState: function () {
      if (!activeEditorId) return null;
      function q(c) { try { return document.queryCommandState(c); } catch (e) { return false; } }
      return { bold: q('bold'), italic: q('italic'), underline: q('underline'), strike: q('strikeThrough'),
               ol: q('insertOrderedList'), ul: q('insertUnorderedList'),
               right: q('justifyRight'), center: q('justifyCenter'), left: q('justifyLeft'), full: q('justifyFull') };
    },
    answerLine: function () { if (activeEditorId) insertAnswerLine(activeEditorId); return true; },
    insertTable: function (rows, cols, style) {
      if (!activeEditorId) return false;
      $('tb-rows').value = rows; $('tb-cols').value = cols; $('tb-border-style').value = style;
      confirmInsertCustomTable();
      return true;
    },
    insertImages: function (items, mode) {
      if (!activeEditorId) return false;
      imageInsertMode = mode || 'single';
      handleQuestionImageSelected({ target: { files: items.map(fileFrom) } });
      return true;
    },
    imgWrap: function (v) { setSelectedImageWrap(v); return true; },
    imgSize: function (v) { resizeSelectedImage(v); return true; },
    imgShape: function (v) { setSelectedImageShape(v); return true; },
    imgDelete: function () { deleteSelectedImage(); return true; },
    imgClearArrows: function () { clearArrowsOnSelectedImage(); return true; },
    imgArrow: function (dir, color, x, y, label) {
      if (!selectedImageEl) return false;
      $('arrow-dir-select').value = dir; $('arrow-color-input').value = color;
      $('arrow-pos-x').value = x; $('arrow-pos-y').value = y; $('arrow-label-text').value = label || '';
      confirmInsertArrow();
      return true;
    },
    tableBorder: function (mode) { setSubTableBorder(mode); return true; },
    tableOp: function (action) { modifySubTable(action); return true; },

    /* ---------- الورقة A4 ---------- */
    fitPaper: function () {
      var sheet = $('exam-paper-sheet');
      if (!sheet) return false;
      sheet.style.zoom = '';
      var w = sheet.offsetWidth, avail = document.documentElement.clientWidth - 16;
      if (w > 0 && w > avail) sheet.style.zoom = String(avail / w);
      return true;
    },
    print: function () { triggerPrint(); return true; },
    exportWord: function () { exportToWordHTML(); return true; }
  };
})();
