/* طبقة ربط تُحقن بعد تحميل المنصة الأصلية دون تعديل ملف index.html.
   تعالج ما لا يعمل داخل WebView أندرويد: التحميل عبر Blob، والطباعة. */
(function () {
  if (window.__exam6ShimInstalled) return;
  window.__exam6ShimInstalled = true;

  var pending = {};
  var seq = 0;
  var blobs = {};

  function toast(msg, type) {
    try { if (typeof showToast === 'function') showToast(msg, type || 'success'); } catch (e) {}
  }

  var Native = {
    call: function (action, payload) {
      return new Promise(function (resolve) {
        var id = 'r' + (++seq);
        pending[id] = resolve;
        try {
          Exam6Channel.postMessage(JSON.stringify({ id: id, action: action, payload: payload || {} }));
        } catch (e) {
          delete pending[id];
          resolve({ ok: false, error: 'تعذر الاتصال بالتطبيق' });
        }
      });
    },
    _resolve: function (id, result) {
      var r = pending[id];
      if (!r) return;
      delete pending[id];
      try { r(JSON.parse(result)); } catch (e) { r({ ok: false, error: 'نتيجة غير صالحة' }); }
    },
    exportPdf: function () {
      return Native.call('exportPdf', collectPrintPayload());
    }
  };
  window.Exam6Native = Native;

  function collectPrintPayload() {
    var clone = document.documentElement.cloneNode(true);
    var scripts = clone.querySelectorAll('script');
    for (var i = 0; i < scripts.length; i++) scripts[i].parentNode.removeChild(scripts[i]);
    var sheet = clone.querySelector('#exam-paper-sheet');   // الطباعة بالمقاس الحقيقي لا بمقاس الشاشة
    if (sheet) sheet.style.zoom = '';
    var title = 'Exam';
    try { title = currentExam.meta.title || currentExam.meta.subject || 'Exam'; } catch (e) {}
    return { html: '<!DOCTYPE html>' + clone.outerHTML, title: String(title) };
  }

  /* الطباعة: window.print() لا تعمل في WebView، فنرسل الصفحة إلى Flutter */
  window.print = function () {
    Native.call('print', collectPrintPayload()).then(function (res) {
      if (!res || !res.ok) toast((res && res.error) || 'تعذرت الطباعة', 'error');
    });
  };

  /* التحميل: نحتفظ بنسخة من كل Blob لأن المنصة تلغي الرابط مباشرة بعد النقر */
  var origCreate = URL.createObjectURL.bind(URL);
  URL.createObjectURL = function (obj) {
    var u = origCreate(obj);
    if (obj instanceof Blob) blobs[u] = obj;
    return u;
  };
  var origRevoke = URL.revokeObjectURL.bind(URL);
  URL.revokeObjectURL = function (u) {
    setTimeout(function () { delete blobs[u]; }, 60000);
    return origRevoke(u);
  };

  function sendBlob(blob, name) {
    var reader = new FileReader();
    reader.onload = function () {
      var data = String(reader.result || '');
      var comma = data.indexOf(',');
      Native.call('saveFile', { name: name, data: comma >= 0 ? data.slice(comma + 1) : '' })
        .then(function (res) {
          if (res && res.ok) toast(res.message || 'تمت العملية بنجاح', 'success');
          else if (res && res.cancelled) { /* ألغى المستخدم */ }
          else toast((res && res.error) || 'تعذر حفظ الملف', 'error');
        });
    };
    reader.onerror = function () { toast('تعذر قراءة الملف', 'error'); };
    reader.readAsDataURL(blob);
  }

  var origClick = HTMLAnchorElement.prototype.click;
  HTMLAnchorElement.prototype.click = function () {
    var href = this.href || '';
    if (this.hasAttribute('download') && /^(blob|data):/.test(href)) {
      var name = this.getAttribute('download') || 'file';
      if (blobs[href]) { sendBlob(blobs[href], name); return; }
      fetch(href).then(function (r) { return r.blob(); })
        .then(function (b) { sendBlob(b, name); })
        .catch(function () { toast('تعذر تجهيز الملف', 'error'); });
      return;
    }
    return origClick.apply(this, arguments);
  };

  /* ===== المرحلة 4: تخزين دائم =====
     IndexedDB يبقى المصدر الأصلي، وكل حفظ/حذف يُنسخ إلى ملفات داخل التطبيق.
     عند الإقلاع نكمل أي نقص في الاتجاهين، ونسترجع آخر مسودة غير محفوظة. */
  var ENABLE_DRAFT = true;

  var queue = Promise.resolve();
  function enqueue(fn) {
    queue = queue.then(fn).catch(function () {});
    return queue;
  }

  var origSave = window.dbSaveExam;
  var origDelete = window.dbDeleteExam;

  if (typeof origSave === 'function') {
    window.dbSaveExam = async function (exam) {
      var r = await origSave.apply(this, arguments);
      try {
        var json = JSON.stringify(exam);
        enqueue(function () { return Native.call('dbSave', { id: exam.id, json: json }); });
      } catch (e) {}
      return r;
    };
  }
  if (typeof origDelete === 'function') {
    window.dbDeleteExam = async function (id) {
      var r = await origDelete.apply(this, arguments);
      enqueue(function () { return Native.call('dbDelete', { id: id }); });
      return r;
    };
  }

  async function syncStores() {
    if (typeof origSave !== 'function' || typeof dbGetAllExams !== 'function') return;
    var local = await dbGetAllExams();
    var res = await Native.call('dbList');
    if (!res || !res.ok) return;
    var nativeIds = {};
    (res.ids || []).forEach(function (i) { nativeIds[i] = true; });
    var localIds = {};
    for (var i = 0; i < local.length; i++) {
      var ex = local[i];
      localIds[ex.id] = true;
      if (!nativeIds[ex.id]) await Native.call('dbSave', { id: ex.id, json: JSON.stringify(ex) });
    }
    var restored = 0;
    for (var id in nativeIds) {
      if (localIds[id]) continue;
      var g = await Native.call('dbGet', { id: id });
      if (g && g.ok && g.json) {
        try { await origSave(JSON.parse(g.json)); restored++; } catch (e) {}
      }
    }
    if (restored) {
      toast('تم استرجاع ' + restored + ' اختبار من النسخة الداخلية', 'success');
      try { renderSavedExamsList(); } catch (e) {}
    }
  }

  function snapshot() {
    try { syncMeta(); } catch (e) {}
    try { return JSON.stringify(currentExam); } catch (e) { return ''; }
  }

  var lastDraft = '';
  var draftTimer = null;
  function flushDraft() {
    clearTimeout(draftTimer);
    var s = snapshot();
    if (s && s !== lastDraft) {
      lastDraft = s;
      Native.call('draftSave', { json: s });
    }
  }
  function scheduleDraft() {
    clearTimeout(draftTimer);
    draftTimer = setTimeout(flushDraft, 3000);
  }

  async function restoreDraft() {
    var g = await Native.call('draftGet');
    if (!g || !g.ok || !g.json) return;
    try {
      var d = JSON.parse(g.json);
      if (!d || !d.meta || !d.design || !d.visibility || !Array.isArray(d.questions)) return;
      currentExam = d;
      applyDesignVariables();
      populateEditorFromState();
      renderLivePreview();
      toast('تم استرجاع آخر مسودة غير محفوظة', 'success');
    } catch (e) {}
  }

  (async function initDurability() {
    try { await syncStores(); } catch (e) {}
    if (!ENABLE_DRAFT) return;
    try { await restoreDraft(); } catch (e) {}
    lastDraft = snapshot();
    ['input', 'change', 'click'].forEach(function (ev) {
      document.addEventListener(ev, scheduleDraft, true);
    });
    document.addEventListener('visibilitychange', function () {
      if (document.hidden) flushDraft();
    });
  })();

  /* ===== خطوط إضافية في قائمة «الخط» (قسم القوالب) =====
     الخطوط نفسها مسجّلة في fonts.css. اجعل ADD_FONT_OPTIONS = false لإبقاء القائمة كما في الأصل. */
  var ADD_FONT_OPTIONS = true;
  (function addFontOptions() {
    if (!ADD_FONT_OPTIONS) return;
    var sel = document.getElementById('tpl-font');
    if (!sel) return;
    var extra = [
      ["'Cairo', 'Tahoma', sans-serif", 'Cairo'],
      ["'Amiri', 'Traditional Arabic', serif", 'Amiri'],
      ["'Mohammad Bold Normal', 'Tahoma', sans-serif", 'Mohammad Bold Normal'],
      ["'Mohammad Head', 'Tahoma', sans-serif", 'Mohammad Head'],
      ["'Mohammad Laha', 'Tahoma', sans-serif", 'Mohammad Laha'],
      ["'Montserrat', 'Arial', sans-serif", 'Montserrat (إنجليزي)']
    ];
    extra.forEach(function (o) {
      var exists = false;
      for (var i = 0; i < sel.options.length; i++) if (sel.options[i].value === o[0]) exists = true;
      if (exists) return;
      var opt = document.createElement('option');
      opt.value = o[0]; opt.textContent = o[1];
      sel.appendChild(opt);
    });
    try { populateDesignControls(); } catch (e) {}
  })();

  /* ===== غلاف أصلي: طلبات الانتقال إلى الرئيسية/المحفوظة/الإعدادات تُنفَّذ في Flutter ===== */
  var origNav = window.navigateTo;
  if (typeof origNav === 'function') {
    window.navigateTo = function (view) {
      if (window.__nativeShell && (view === 'home' || view === 'saved' || view === 'settings')) {
        Native.call('nav', { view: view });
        return;
      }
      return origNav.apply(this, arguments);
    };
  }

  /* ===== داخل الغلاف الأصلي: الإشعارات والتأكيدات تُعرض بواجهة Flutter ===== */
  var origToast = window.showToast;
  var origConfirm = window.showConfirm;
  window.showToast = function (msg, type) {
    if (window.__nativeShell) { Native.call('toast', { msg: String(msg), type: type || 'success' }); return; }
    return origToast.apply(this, arguments);
  };
  window.showConfirm = function (title, message, onConfirm) {
    if (window.__nativeShell) {
      Native.call('confirm', { title: String(title), message: String(message) }).then(function (r) {
        if (r && r.ok && r.yes) onConfirm();
      });
      return;
    }
    return origConfirm.apply(this, arguments);
  };
})();
