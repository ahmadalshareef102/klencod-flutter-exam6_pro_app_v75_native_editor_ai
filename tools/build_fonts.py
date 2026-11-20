"""يولّد assets/web/fonts.css من الخطوط في fonts_src/ (خطوط مضمّنة Base64 بصيغة WOFF).
التشغيل: python3 tools/build_fonts.py   (يتطلب fonttools)"""
import base64, io, os
from fontTools.ttLib import TTFont

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = os.path.join(root, 'fonts_src')

def data_url(name):
    t = TTFont(os.path.join(src, name))
    t.flavor = 'woff'
    buf = io.BytesIO(); t.save(buf)
    return 'data:font/woff;base64,' + base64.b64encode(buf.getvalue()).decode()

cairo_r, cairo_b = data_url('Cairo-Regular.ttf'), data_url('Cairo-Bold.ttf')

def face(family, url, weight, local=None):
    s = (f"local('{local}'), " if local else '') + f"url({url}) format('woff')"
    return f"@font-face{{font-family:'{family}';font-weight:{weight};font-style:normal;font-display:swap;src:{s};}}\n"

css = '/* مولَّد بواسطة tools/build_fonts.py - لا تعدّله يدوياً */\n'
css += face('Cairo', cairo_r, 400) + face('Cairo', cairo_b, 700)
# Tahoma غير موجود في أندرويد: نستخدم الخط الأصلي إن وُجد وإلا Cairo
css += face('Tahoma', cairo_r, 400, 'Tahoma') + face('Tahoma', cairo_b, 700, 'Tahoma Bold')
# Amiri متوفر بوزن Bold فقط؛ نغطي به كل الأوزان
css += face('Amiri', data_url('Amiri-Bold.ttf'), '100 900')
for fam, f in [('Mohammad Bold Normal', 'Mohammad_Bold_normal.ttf'),
               ('Mohammad Head', 'Mohammad_Head.ttf'),
               ('Mohammad Laha', 'Mohammad_Laha.ttf'),
               ('Montserrat', 'Montserrat-Medium.ttf')]:
    css += face(fam, data_url(f), '100 900')   # وزن واحد: مدى كامل لمنع التثخين الاصطناعي

out = os.path.join(root, 'assets/web/fonts.css')
open(out, 'w', encoding='utf-8').write(css)
print(out, round(len(css) / 1024), 'KB')
