# ⚙️ إعدادات المشروع الموحدة

هذا الملف يحتوي على جميع الإعدادات والتكوينات المهمة للمشروع.

---

## 🌐 إعدادات الخادم (Backend)

### عنوان الخادم الأساسي

```
التطوير: http://localhost:8000
الإنتاج: https://api.kanaf.org
```

### قاعدة البيانات

```
النوع: SQLite (للتطوير) / PostgreSQL (للإنتاج)
الموقع: backend/orphan_care_backend/db.sqlite3
```

### المصادقة

```
النوع: JWT (JSON Web Tokens)
مدة صلاحية التوكن: 24 ساعة
مدة صلاحية التحديث: 7 أيام
```

### CORS المسموح

```
http://localhost:3000
http://localhost:8000
http://localhost:8080
http://127.0.0.1:3000
http://127.0.0.1:8000
http://127.0.0.1:8080
```

---

## 📱 إعدادات التطبيق (Frontend)

### عنوان الـ API

```dart
// في lib/services/api_service.dart
static const String baseUrl = 'http://localhost:8000/api';
```

### إعدادات التطبيق

```dart
// اسم التطبيق
title: 'تطبيق كَــنَـــفْ'

// الإصدار
version: 1.0.0+1

// اللغة الافتراضية
language: 'ar'

// الاتجاه النصي
textDirection: RTL
```

### المكتبات الرئيسية

```yaml
# الاتصال بالـ API
dio: ^5.3.0

# إدارة الحالة
provider: ^6.0.0

# التخزين المحلي
shared_preferences: ^2.2.0

# الرسوم البيانية
fl_chart: ^0.63.0
```

---

## 🎨 إعدادات التصميم

### الألوان الأساسية

| اللون | الكود | الاستخدام |
| :--- | :--- | :--- |
| البرتقالي الرئيسي | `#FF9500` | الأزرار والأيقونات الرئيسية |
| الأسود الداكن | `#131313` | الخلفية الرئيسية |
| الأبيض | `#FFFFFF` | النصوص الأساسية |
| الأخضر الزمردي | `#10B981` | الحالات الإيجابية |
| الأحمر | `#EF4444` | التنبيهات والأخطاء |

### الخطوط

| الخط | الاستخدام |
| :--- | :--- |
| Cairo | العناوين والنصوص الرئيسية |
| Tajawal | النصوص الثانوية والتفاصيل |

### أحجام الخط

```dart
// العناوين الكبيرة
fontSize: 22, fontWeight: FontWeight.w900

// العناوين المتوسطة
fontSize: 16, fontWeight: FontWeight.bold

// النصوص العادية
fontSize: 14, fontWeight: FontWeight.normal

// النصوص الصغيرة
fontSize: 12, fontWeight: FontWeight.w500
```

---

## 📊 إعدادات قاعدة البيانات

### الجداول الرئيسية

```sql
-- جدول الأيتام
CREATE TABLE management_orphan (
    id INTEGER PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    age INTEGER NOT NULL,
    status VARCHAR(100) DEFAULT 'ينتظر كفالة',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- جدول التبرعات
CREATE TABLE management_donation (
    id INTEGER PRIMARY KEY,
    donor_name VARCHAR(100) NOT NULL,
    item_type VARCHAR(100) NOT NULL,
    status VARCHAR(50) DEFAULT 'قيد التنفيذ',
    amount DECIMAL(10, 2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- جدول المتطوعين
CREATE TABLE management_volunteer (
    id INTEGER PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    specialty VARCHAR(100) NOT NULL,
    points INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- جدول الكفلاء
CREATE TABLE management_sponsor (
    id INTEGER PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    orphan_name VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- جدول المخزن
CREATE TABLE management_inventoryitem (
    id INTEGER PRIMARY KEY,
    item_name VARCHAR(100) NOT NULL,
    quantity INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

---

## 🔐 إعدادات الأمان

### متغيرات البيئة

```bash
# في backend/.env
SECRET_KEY=your-secret-key-here
DEBUG=False
ALLOWED_HOSTS=localhost,127.0.0.1,yourdomain.com
DATABASE_URL=postgresql://user:password@localhost/kanaf_db
JWT_SECRET=your-jwt-secret-here
```

### قواعد الأمان

*   ✅ استخدام HTTPS في الإنتاج
*   ✅ تشفير كلمات المرور
*   ✅ التحقق من الصلاحيات على كل طلب
*   ✅ تحديد معدل الطلبات (Rate Limiting)
*   ✅ تنظيف المدخلات (Input Validation)

---

## 📈 إعدادات الأداء

### التخزين المؤقت (Caching)

```python
# في settings.py
CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.redis.RedisCache',
        'LOCATION': 'redis://127.0.0.1:6379/1',
    }
}
```

### ضغط البيانات

```python
MIDDLEWARE = [
    'django.middleware.gzip.GZipMiddleware',
    # ...
]
```

### تحسين الاستعلامات

```python
# استخدام select_related و prefetch_related
orphans = Orphan.objects.select_related('sponsor').prefetch_related('donations')
```

---

## 🚀 إعدادات النشر

### المتطلبات للإنتاج

*   خادم ويب: Nginx أو Apache
*   خادم التطبيق: Gunicorn أو uWSGI
*   قاعدة البيانات: PostgreSQL
*   التخزين المؤقت: Redis
*   CDN: Cloudflare أو AWS CloudFront

### ملف Docker

```dockerfile
FROM python:3.10

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .

CMD ["gunicorn", "core.wsgi:application", "--bind", "0.0.0.0:8000"]
```

### ملف docker-compose.yml

```yaml
version: '3.8'

services:
  db:
    image: postgres:15
    environment:
      POSTGRES_DB: kanaf_db
      POSTGRES_USER: kanaf_user
      POSTGRES_PASSWORD: kanaf_password
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7

  web:
    build: .
    command: python manage.py runserver 0.0.0.0:8000
    volumes:
      - .:/app
    ports:
      - "8000:8000"
    depends_on:
      - db
      - redis

volumes:
  postgres_data:
```

---

## 📝 ملاحظات مهمة

*   تأكد من تحديث جميع المكتبات بانتظام
*   قم بعمل نسخ احتياطية من قاعدة البيانات
*   راقب أداء التطبيق والخادم
*   حدّث سياسات الأمان بشكل دوري

---

**تم إعداد هذا الملف بواسطة فريق كَنَفْ - 2026**
