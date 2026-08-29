import 'package:flutter/material.dart';

/// توجيه المستخدم إلى قسمه حسب دوره.
///
/// التطبيق سطح جمهور: **متبرع** و**متطوع** فقط. أما دور الرعاية
/// والإدارة فتُدار من لوحة التحكم على الويب — وهو ما يفرضه الخادم
/// أصلاً برفضه التسجيل بدور `care_home`.
///
/// نحتفظ باسمَي الدورين هنا كي نميّز «حساب إداري دخل من الباب الخطأ»
/// عن «دور غير معروف»، فنعطي كلاً منهما رسالته الصحيحة بدل رمي
/// المستخدم في شاشة اختيار دور لا تحل مشكلته.
class AuthNavigation {
  static const String donorRole = 'donor';
  static const String volunteerRole = 'volunteer';
  static const String careHomeRole = 'care_home';
  static const String adminRole = 'admin';

  /// أدوار لها حساب على الخادم لكن لا سطح لها في التطبيق.
  static const Set<String> webOnlyRoles = {careHomeRole, adminRole};

  /// يوحّد صيغة الدور: يقبل الشُرَط والمسافات وأسماء بديلة شائعة.
  static String? normalizeRole(String? role) {
    final value = role?.trim().toLowerCase().replaceAll(RegExp(r'[-\s]'), '_');
    if (value == null || value.isEmpty) return null;

    switch (value) {
      case donorRole:
      case 'supporter':
      case 'sponsor':
        return donorRole;
      case volunteerRole:
        return volunteerRole;
      case careHomeRole:
      case 'carehome':
      case 'orphanage':
        return careHomeRole;
      case adminRole:
      case 'staff':
      case 'superuser':
        return adminRole;
      default:
        return null;
    }
  }

  static String? roleFromAuthResponse(Map<String, dynamic> response) {
    final candidates = <dynamic>[
      response['role'],
      response['user_role'],
      response['account_type'],
      response['userType'],
    ];

    final user = response['user'];
    if (user is Map) {
      candidates.addAll([
        user['role'],
        user['user_role'],
        user['account_type'],
        user['userType'],
      ]);

      final profile = user['profile'];
      if (profile is Map) {
        candidates.addAll([
          profile['role'],
          profile['user_role'],
          profile['account_type'],
        ]);
      }

      // الخادم قد يعبّر عن الإدارة بأعلام منطقية لا بحقل دور.
      if (user['is_staff'] == true || user['is_superuser'] == true) {
        candidates.add(adminRole);
      }
    }

    final data = response['data'];
    if (data is Map) {
      candidates.addAll([
        data['role'],
        data['user_role'],
        data['account_type'],
      ]);

      final dataUser = data['user'];
      if (dataUser is Map) {
        candidates.addAll([
          dataUser['role'],
          dataUser['user_role'],
          dataUser['account_type'],
        ]);
      }
    }

    if (response['is_staff'] == true || response['is_superuser'] == true) {
      candidates.add(adminRole);
    }

    for (final candidate in candidates) {
      final normalized = normalizeRole(candidate?.toString());
      if (normalized != null) return normalized;
    }
    return null;
  }

  static String? homeRouteForRole(String? role) {
    switch (normalizeRole(role)) {
      case donorRole:
        return '/supporter_home';
      case volunteerRole:
        return '/volunteer_home';
      default:
        return null;
    }
  }

  static void navigateByRole(
    BuildContext context,
    String? role, {
    bool showUnknownRoleMessage = true,
  }) {
    final routeName = homeRouteForRole(role);

    if (routeName == null) {
      if (showUnknownRoleMessage) {
        // نفرّق بين حساب إداري صحيح دخل من الباب الخطأ، وبين دور
        // مجهول فعلاً. الرسالة الواحدة للحالتين كانت تضلّل الأول.
        final isWebOnly = webOnlyRoles.contains(normalizeRole(role));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isWebOnly
                  ? 'هذا حساب إداري. تُدار دور الرعاية من لوحة التحكم على '
                      'الويب، والتطبيق مخصص للمتبرعين والمتطوعين.'
                  : 'تعذر تحديد نوع الحساب. الرجاء اختيار نوع الحساب مرة أخرى.',
            ),
            duration: const Duration(seconds: 7),
          ),
        );
      }
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/role_selection',
        (route) => false,
      );
      return;
    }

    Navigator.of(context).pushNamedAndRemoveUntil(
      routeName,
      (route) => false,
    );
  }
}
