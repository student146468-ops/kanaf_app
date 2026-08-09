# 📚 دليل التطوير والتخصيص

هذا الدليل يوضح كيفية تطوير وتخصيص مشروع كَنَفْ لاحتياجاتك الخاصة.

---

## 🎯 المحتويات

1. [بنية المشروع](#بنية-المشروع)
2. [إضافة ميزة جديدة](#إضافة-ميزة-جديدة)
3. [تخصيص التصميم](#تخصيص-التصميم)
4. [الاختبار والنشر](#الاختبار-والنشر)

---

## 🏗️ بنية المشروع

### المنظومة (Backend)

```
backend/orphan_care_backend/
├── core/                      # إعدادات المشروع الرئيسية
│   ├── settings.py           # إعدادات Django
│   ├── urls.py               # المسارات الرئيسية
│   ├── urls_api.py           # مسارات الـ API
│   └── views.py              # المتحكمات الرئيسية
│
├── management/               # تطبيق إدارة البيانات
│   ├── models.py             # نماذج قاعدة البيانات
│   ├── serializers.py        # محولات البيانات
│   ├── views_api.py          # ViewSets للـ API
│   └── admin.py              # لوحة الإدارة
│
├── templates/                # قوالب الويب
│   ├── base.html             # القالب الأساسي
│   ├── dashboard.html        # لوحة التحكم
│   └── ...
│
└── manage.py                 # أداة إدارة Django
```

### التطبيق (Frontend)

```
frontend/orphan_care_app/
├── lib/
│   ├── main.dart             # نقطة الدخول الرئيسية
│   │
│   ├── models/               # نماذج البيانات
│   │   ├── orphan_model.dart
│   │   ├── donation_model.dart
│   │   └── volunteer_model.dart
│   │
│   ├── services/             # خدمات الاتصال
│   │   ├── api_service.dart  # خدمة الـ API
│   │   └── database_helper.dart
│   │
│   ├── providers/            # إدارة الحالة
│   │   └── app_provider.dart
│   │
│   ├── views/                # الواجهات
│   │   ├── splash_screen.dart
│   │   ├── login_screen.dart
│   │   ├── donor/
│   │   ├── volunteer/
│   │   ├── care_home_views/
│   │   └── ...
│   │
│   ├── widgets/              # المكونات المعاد استخدامها
│   │   └── glass_container.dart
│   │
│   └── utils/                # الأدوات المساعدة
│       ├── app_colors.dart
│       └── app_theme.dart
│
└── pubspec.yaml              # ملف المكتبات
```

---

## ➕ إضافة ميزة جديدة

### مثال: إضافة نظام الرسائل (Messaging)

#### 1️⃣ في المنظومة (Backend)

**الخطوة 1: إنشاء النموذج**

```python
# في management/models.py
class Message(models.Model):
    sender = models.ForeignKey(User, on_delete=models.CASCADE, related_name='sent_messages')
    recipient = models.ForeignKey(User, on_delete=models.CASCADE, related_name='received_messages')
    content = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)
    is_read = models.BooleanField(default=False)
    
    class Meta:
        ordering = ['-created_at']
    
    def __str__(self):
        return f"من {self.sender} إلى {self.recipient}"
```

**الخطوة 2: إنشاء Serializer**

```python
# في management/serializers.py
class MessageSerializer(serializers.ModelSerializer):
    class Meta:
        model = Message
        fields = '__all__'
```

**الخطوة 3: إنشاء ViewSet**

```python
# في management/views_api.py
class MessageViewSet(viewsets.ModelViewSet):
    queryset = Message.objects.all()
    serializer_class = MessageSerializer
    permission_classes = [IsAuthenticated]
    
    @action(detail=False, methods=['get'])
    def my_messages(self, request):
        messages = Message.objects.filter(recipient=request.user)
        serializer = self.get_serializer(messages, many=True)
        return Response(serializer.data)
```

**الخطوة 4: تسجيل في URLs**

```python
# في core/urls_api.py
router.register(r'messages', MessageViewSet, basename='message')
```

#### 2️⃣ في التطبيق (Frontend)

**الخطوة 1: إنشاء النموذج**

```dart
// في lib/models/message_model.dart
class MessageModel {
  final int id;
  final String senderName;
  final String content;
  final DateTime createdAt;
  final bool isRead;
  
  MessageModel({
    required this.id,
    required this.senderName,
    required this.content,
    required this.createdAt,
    required this.isRead,
  });
  
  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'],
      senderName: json['sender_name'],
      content: json['content'],
      createdAt: DateTime.parse(json['created_at']),
      isRead: json['is_read'],
    );
  }
}
```

**الخطوة 2: إضافة الخدمة**

```dart
// في lib/services/api_service.dart
Future<List<dynamic>> getMessages() async {
  try {
    final response = await _dio.get('/messages/my-messages/');
    return response.data is List ? response.data : [];
  } on DioException catch (e) {
    throw Exception('خطأ في جلب الرسائل: ${e.message}');
  }
}

Future<Map<String, dynamic>> sendMessage(Map<String, dynamic> messageData) async {
  try {
    final response = await _dio.post('/messages/', data: messageData);
    return response.data;
  } on DioException catch (e) {
    throw Exception('خطأ في إرسال الرسالة: ${e.message}');
  }
}
```

**الخطوة 3: إضافة في Provider**

```dart
// في lib/providers/app_provider.dart
List<MessageModel> _messages = [];

Future<void> fetchMessages() async {
  _setLoading(true);
  try {
    final data = await _apiService.getMessages();
    _messages = (data as List)
        .map((item) => MessageModel.fromJson(item as Map<String, dynamic>))
        .toList();
  } catch (e) {
    _errorMessage = e.toString();
  } finally {
    _setLoading(false);
  }
}
```

**الخطوة 4: إنشاء الواجهة**

```dart
// في lib/views/messages_screen.dart
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  @override
  void initState() {
    super.initState();
    Provider.of<AppProvider>(context, listen: false).fetchMessages();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('الرسائل')),
        body: Consumer<AppProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            
            if (provider.messages.isEmpty) {
              return const Center(child: Text('لا توجد رسائل'));
            }
            
            return ListView.builder(
              itemCount: provider.messages.length,
              itemBuilder: (context, index) {
                final message = provider.messages[index];
                return ListTile(
                  title: Text(message.senderName),
                  subtitle: Text(message.content),
                  trailing: !message.isRead 
                      ? const Icon(Icons.circle, color: Colors.blue, size: 10)
                      : null,
                );
              },
            );
          },
        ),
      ),
    );
  }
}
```

**الخطوة 5: تسجيل المسار**

```dart
// في lib/main.dart
case '/messages':
  page = const MessagesScreen();
  break;
```

---

## 🎨 تخصيص التصميم

### تغيير الألوان

```dart
// في lib/utils/app_colors.dart
class AppColors {
  // الألوان الأساسية
  static const Color brandOrange = Color(0xFFFF9500);  // غيّر هنا
  static const Color brandOrangeDark = Color(0xFFE68A00);
  
  // الألوان الزجاجية
  static const Color glassBgNormal = Color(0xFFFFFFFF);
  static const Color glassBgSelected = Color(0xFF1F1F1F);
  
  // ألوان النصوص
  static const Color glassTextPrimary = Color(0xFFFFFFFF);
  static const Color glassTextSecondary = Color(0xFFB0B0B0);
}
```

### تغيير الخطوط

```yaml
# في pubspec.yaml
fonts:
  - family: CustomFont
    fonts:
      - asset: assets/fonts/CustomFont-Regular.ttf
      - asset: assets/fonts/CustomFont-Bold.ttf
        weight: 700
```

### تخصيص الثيم

```dart
// في lib/utils/app_theme.dart
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brandOrange,
        brightness: Brightness.light,
      ),
      // غيّر الخصائص حسب احتياجاتك
    );
  }
}
```

---

## ✅ الاختبار والنشر

### اختبار المنظومة (Backend)

```bash
# تشغيل الاختبارات
python manage.py test

# اختبار API محدد
python manage.py test management.tests.OrphanTestCase
```

### اختبار التطبيق (Frontend)

```bash
# تشغيل الاختبارات
flutter test

# بناء APK
flutter build apk

# بناء iOS
flutter build ios
```

### النشر

#### نشر المنظومة

```bash
# استخدام Heroku
heroku login
heroku create your-app-name
git push heroku main

# أو استخدام DigitalOcean
# اتبع التعليمات على https://www.digitalocean.com
```

#### نشر التطبيق

```bash
# نشر على Google Play
flutter build appbundle
# ثم رفع على Google Play Console

# نشر على App Store
flutter build ios
# ثم رفع على App Store Connect
```

---

## 🔍 استكشاف الأخطاء

### المشكلة: خطأ في الاتصال بالـ API

**الحل:**
1. تأكد من تشغيل المنظومة: `python manage.py runserver`
2. تحقق من عنوان الـ API في `api_service.dart`
3. تحقق من إعدادات CORS في `settings.py`

### المشكلة: البيانات لا تظهر في التطبيق

**الحل:**
1. تحقق من أن البيانات موجودة في قاعدة البيانات
2. تحقق من الـ Serializer والـ ViewSet
3. تحقق من المصادقة (JWT Token)

### المشكلة: الواجهات لا تظهر بشكل صحيح

**الحل:**
1. تحقق من الخطوط والألوان
2. تحقق من حجم الشاشة والـ Responsive Design
3. تحقق من الصور والأصول

---

## 📞 الدعم

للمزيد من المساعدة:
- 📧 البريد الإلكتروني: dev@kanaf.org
- 🌐 الموقع: www.kanaf.org/docs
- 💬 المنتدى: forum.kanaf.org

---

**تم إعداد هذا الدليل بواسطة فريق كَنَفْ - 2026**
