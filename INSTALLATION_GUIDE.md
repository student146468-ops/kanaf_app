# 🚀 دليل التثبيت والتشغيل النهائي

## 📋 المتطلبات

### للمنظومة (Backend)
- Python 3.10 أو أحدث
- pip (مدير المكتبات)
- SQLite (مدمج في Python)

### للتطبيق (Frontend)
- Flutter SDK 3.0 أو أحدث
- Dart 3.0 أو أحدث
- محاكي Android أو iOS (أو جهاز فعلي)

---

## 🔧 خطوات التثبيت

### 1️⃣ تثبيت المنظومة (Backend)

#### الخطوة الأولى: الانتقال إلى مجلد المنظومة
```bash
cd orphan_care_complete/backend/orphan_care_backend
```

#### الخطوة الثانية: إنشاء بيئة افتراضية
```bash
# على Windows
python -m venv venv
venv\Scripts\activate

# على macOS/Linux
python3 -m venv venv
source venv/bin/activate
```

#### الخطوة الثالثة: تثبيت المكتبات
```bash
pip install -r requirements.txt
```

#### الخطوة الرابعة: تطبيق الهجرات
```bash
python manage.py migrate
```

#### الخطوة الخامسة: إنشاء مستخدم إداري (اختياري)
```bash
python manage.py createsuperuser
```

#### الخطوة السادسة: تشغيل الخادم
```bash
python manage.py runserver
```

**ستظهر الرسالة:**
```
Starting development server at http://127.0.0.1:8000/
```

---

### 2️⃣ تثبيت التطبيق (Frontend)

#### الخطوة الأولى: الانتقال إلى مجلد التطبيق
```bash
cd orphan_care_complete/frontend/orphan_care_app
```

#### الخطوة الثانية: تثبيت المكتبات
```bash
flutter pub get
```

#### الخطوة الثالثة: تشغيل التطبيق

**على محاكي Android:**
```bash
flutter run
```

**على محاكي iOS:**
```bash
flutter run -d iPhone
```

**على متصفح الويب:**
```bash
flutter run -d chrome
```

---

## 🔌 اختبار الاتصال بين التطبيق والمنظومة

### 1. التأكد من تشغيل المنظومة
```bash
# المنظومة يجب أن تكون تعمل على:
http://localhost:8000
```

### 2. اختبار API مباشرة (باستخدام Postman أو curl)

#### تسجيل دخول جديد
```bash
curl -X POST http://localhost:8000/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{
    "action": "login",
    "email": "user@example.com",
    "password": "password123"
  }'
```

#### التسجيل الجديد
```bash
curl -X POST http://localhost:8000/api/auth/register/ \
  -H "Content-Type: application/json" \
  -d '{
    "action": "register",
    "email": "newuser@example.com",
    "password": "password123",
    "password_confirm": "password123",
    "first_name": "أحمد",
    "last_name": "محمد",
    "role": "donor",
    "phone_number": "+218912345678"
  }'
```

#### جلب الأيتام
```bash
curl -X GET http://localhost:8000/api/orphans/ \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

---

## 🎯 الميزات الرئيسية

### بدون OTP ✅
- تسجيل دخول مباشر بالبريد الإلكتروني وكلمة المرور
- تسجيل جديد بسيط وسريع
- لا توجد خطوات تحقق معقدة

### SQLite فقط ✅
- قاعدة بيانات محلية سهلة الاستخدام
- لا توجد تقنيات مدفوعة
- جاهزة للإنتاج والتطوير

### تصميم احترافي ✅
- نمط Glassmorphism جميل
- ألوان متناسقة واحترافية
- خطوط عربية جميلة (Cairo, Tajawal)
- حركات انتقالية سلسة

### ربط كامل ✅
- التطبيق مرتبط بالمنظومة بشكل صحيح
- جميع العمليات تعمل بكفاءة
- معالجة الأخطاء والاستثناءات

---

## 📊 نقاط الوصول (APIs) المتاحة

### المصادقة
```
POST /api/auth/login/
POST /api/auth/register/
POST /api/auth/refresh/
```

### الأيتام
```
GET /api/orphans/
GET /api/orphans/{id}/
POST /api/orphans/
PUT /api/orphans/{id}/
DELETE /api/orphans/{id}/
GET /api/orphans/statistics/
```

### التبرعات
```
GET /api/donations/
POST /api/donations/
GET /api/donations/my-donations/
GET /api/donations/statistics/
```

### المتطوعين
```
GET /api/volunteers/
POST /api/volunteers/apply/
GET /api/volunteers/statistics/
```

### الإحصائيات
```
GET /api/stats/dashboard/
GET /api/reports/
```

---

## 🐛 استكشاف الأخطاء

### المشكلة: خطأ في الاتصال بالمنظومة

**الحل:**
1. تأكد من تشغيل المنظومة: `python manage.py runserver`
2. تحقق من عنوان الـ API في `api_service_professional.dart`
3. تأكد من أن الموقع `localhost:8000` متاح

### المشكلة: خطأ في قاعدة البيانات

**الحل:**
1. احذف ملف `db.sqlite3` القديم
2. قم بتطبيق الهجرات مجدداً: `python manage.py migrate`
3. أعد تشغيل الخادم

### المشكلة: خطأ في المكتبات

**الحل:**
```bash
# قم بإعادة تثبيت المكتبات
pip install --upgrade -r requirements.txt
flutter pub get
```

---

## 📱 بناء التطبيق للإنتاج

### بناء APK (Android)
```bash
flutter build apk --release
```

### بناء iOS
```bash
flutter build ios --release
```

### بناء تطبيق الويب
```bash
flutter build web --release
```

---

## 🔐 نصائح الأمان

1. **غيّر SECRET_KEY** في `settings_professional.py` قبل النشر
2. **استخدم HTTPS** في الإنتاج
3. **قم بتحديث المكتبات** بانتظام
4. **احفظ كلمات المرور** بشكل آمن

---

## 📞 الدعم والمساعدة

للأسئلة والدعم:
- 📧 البريد الإلكتروني: dev@kanaf.org
- 🌐 الموقع: www.kanaf.org
- 📱 الهاتف: +218 92 123 4567

---

**تم إعداد هذا الدليل بواسطة فريق كَنَفْ - 2026**

**الحالة: ✅ جاهز للاستخدام الفوري**
