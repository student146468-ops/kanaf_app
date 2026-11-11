# تطبيق كنف — إنشاء APK على Windows

يلزم تثبيت Flutter وAndroid SDK وJava المناسبين، وإتاحة أمر `flutter` في PATH. نفّذ الأوامر من مجلد المشروع الرئيسي `kanaf_app`.

لإنشاء نسخة تجريبية بسرعة لمعظم الهواتف الحديثة:

```powershell
.\build_kanaf_apk.cmd
```

النسخة الافتراضية `debug` لمعمارية **ARM64** فقط، وتتصل بخادم `https://kanafapp.pythonanywhere.com/api`. يظهر مسار الحزمة والوقت الفعلي بعد نجاح البناء. الملف الجاهز:

```text
frontend/orphan_care_app/READY_APK/Kanaf-debug-android-arm64.apk
```

البناء الأول يحتاج تنزيل الحزم وتجهيز Android وGradle وقد يستغرق عدة دقائق حسب الإنترنت والجهاز. البناء التالي يعيد استخدام الملفات المخزّنة، ولذلك يكون أسرع عادة. لا تشغّل `flutter clean` أو تحذف مجلدات التخزين بين كل بناء، ولا تشغّل عمليتي بناء Android معاً. السكربت يتحقق من ملفات الحزم ونسخة Flutter ويشغّل `pub get` عند الحاجة فقط؛ لا يتوقف لفحص اتصال الخادم قبل البناء.

في قياس محلي لهذا المشروع استغرق التجهيز والبناء الأول نحو 21 دقيقة، ثم نجح بناء لاحق بالكاش في نحو 34 ثانية. هذه نتيجة لهذا الجهاز وليست زمناً مضموناً؛ تعديلات الكود أو المكتبات ومواصفات الجهاز قد تغيّر المدة. جهّز البناء الأول قبل الحصة.

نسخة `debug` مناسبة لتجارب الطلاب، لكن حجمها أكبر وأداء تشغيلها أبطأ من `release`. لإنشاء نسخة محسّنة للتجربة والمشاركة النهائية، مع وقت بناء أطول:

```powershell
.\build_kanaf_apk.cmd -Release
```

ستجدها في `READY_APK/Kanaf-release-android-arm64.apk` داخل مجلد التطبيق. إعداد المشروع الحالي يوقّع `release` بمفتاح التطوير؛ نشر التطبيق في متجر يحتاج إعداد مفتاح توقيع خاص.

ARM64 لا يناسب كل الأجهزة. غيّر المعمارية عند الحاجة:

```powershell
# هاتف Android قديم بمعمارية ARM ذات 32 بت
.\build_kanaf_apk.cmd -TargetPlatform android-arm

# محاكي Android بمعمارية x64
.\build_kanaf_apk.cmd -TargetPlatform android-x64

# حزمة تشمل ARM وARM64 وx64؛ البناء والحزمة أكبر
.\build_kanaf_apk.cmd -TargetPlatform all
```

لتغيير عنوان الخادم:

```powershell
.\build_kanaf_apk.cmd -ApiBaseUrl https://example.com/api
```

أثناء تعديل الواجهات استخدم `flutter run` على الجهاز مع Hot Reload بدلاً من إنشاء APK بعد كل تغيير. سكربتات البناء السابقة داخل `scripts` ما زالت متاحة.
