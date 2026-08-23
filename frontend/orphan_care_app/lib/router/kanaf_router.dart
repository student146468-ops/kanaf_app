import 'package:flutter/material.dart';

import '../theme/kanaf_motion.dart';
import '../views/about/about_app_screen.dart';
import '../views/discovery_search/explore_orphanages_screen.dart';
import '../views/donor/donation_history_screen.dart';
import '../views/donor/donation_receipt_screen.dart';
import '../views/donor/donation_success_screen.dart';
import '../views/donor/financial_donation_screen.dart';
import '../views/donor/inkind_donation_screen.dart';
import '../views/donor/need_details_screen.dart';
import '../views/donor/notifications_screen.dart';
import '../views/donor/orphanage_profile_screen.dart';
import '../views/donor/profile_screen.dart';
import '../views/donor/search_filter_screen.dart';
import '../views/donor/supporter_home_screen.dart';
import '../views/forgot_password_screen.dart';
import '../views/login_screen.dart';
import '../views/notifications_tracking/notification_detail_screen.dart';
import '../views/notifications_tracking/notifications_center_screen.dart';
import '../views/notifications_tracking/track_need_status_screen.dart';
import '../views/onboarding_screen.dart';
import '../views/phone_verification_screen.dart';
import '../views/register_screen.dart';
import '../views/reset_password_screen.dart';
import '../views/role_selection_screen.dart';
import '../views/settings/change_email_screen.dart';
import '../views/settings/change_password_screen.dart';
import '../views/settings/settings_screen.dart';
import '../views/splash_screen.dart';
import '../views/volunteer/apply_opportunity_view.dart';
import '../views/volunteer/home_volunteer_view.dart';
import '../views/volunteer/my_certificates_view.dart';
import '../views/volunteer/my_schedule_view.dart';
import '../views/volunteer/my_volunteer_history_view.dart';
import '../views/volunteer/notifications_view.dart';
import '../views/volunteer/profile_volunteer_view.dart';
import '../views/volunteer/search_filter_view.dart';
import '../views/volunteer/volunteer_opportunity_details_view.dart';

/// أسماء المسارات كثوابت — لا نصوص حرّة متناثرة في الشاشات.
abstract final class KanafRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String roleSelection = '/role_selection';
  static const String login = '/login';
  static const String register = '/register';
  static const String phoneVerification = '/otp';
  static const String forgotPassword = '/forgot_password';
  static const String resetPassword = '/reset_password';

  static const String donorHome = '/supporter_home';
  static const String financialDonation = '/financial_donation';
  static const String inkindDonation = '/inkind_donation';
  static const String donationSuccess = '/donation_success';
  static const String donationHistory = '/donation_history';
  static const String donationReceipt = '/donation_receipt';
  static const String needDetails = '/need_details';
  static const String orphanageProfile = '/orphanage_profile';
  static const String donorProfile = '/profile';
  static const String donorNotifications = '/notifications';
  static const String searchFilter = '/search_filter';
  static const String exploreOrphanages = '/explore_orphanages';

  static const String volunteerHome = '/volunteer_home';
  static const String volunteerOpportunityDetails =
      '/volunteer_opportunity_details';
  static const String applyOpportunity = '/apply_opportunity';
  static const String mySchedule = '/my_schedule';
  static const String myVolunteerHistory = '/my_volunteer_history';
  static const String myCertificates = '/my_certificates';
  static const String volunteerNotifications = '/volunteer_notifications';
  static const String volunteerSearch = '/volunteer_search';
  static const String volunteerProfile = '/volunteer_profile';

  static const String settings = '/settings';
  static const String changePassword = '/change_password';
  static const String changeEmail = '/change_email';
  static const String aboutApp = '/about_app';
  static const String notificationsCenter = '/notifications_center';
  static const String trackNeedStatus = '/track_need_status';
  static const String notificationDetail = '/notification_detail';
}

/// راوتر التطبيق.
///
/// الفرق الجوهري عن السابق: نوع الانتقال يُختار **حسب دور الشاشة**
/// في التسلسل الهرمي، لا انتقال واحد لكل شيء. جذور الأقسام تتلاشى
/// (fade through)، الصفحات الفرعية تنزلق (shared axis)، وشاشات
/// النتيجة تظهر بتكبير (fade scale).
abstract final class KanafRouter {
  static Route<dynamic> generate(RouteSettings settings) {
    final (WidgetBuilder builder, KanafTransition transition) =
        _resolve(settings);
    return KanafPageRoute<dynamic>(
      builder: builder,
      settings: settings,
      transition: transition,
    );
  }

  static (WidgetBuilder, KanafTransition) _resolve(RouteSettings settings) {
    // جذور الأقسام: لا إحساس «تقدّم للأمام»، فالتلاشي هو الصحيح.
    const root = KanafTransition.fadeThrough;
    // الصفحات الفرعية: انزلاق يعبّر عن النزول في التسلسل الهرمي.
    const push = KanafTransition.sharedAxis;
    // شاشات التتويج.
    const reveal = KanafTransition.fadeScale;

    switch (settings.name) {
      case KanafRoutes.splash:
        return ((_) => const SplashScreen(), root);
      case KanafRoutes.onboarding:
        return ((_) => const OnboardingScreen(), root);
      case KanafRoutes.roleSelection:
        return ((_) => const RoleSelectionScreen(), push);
      case KanafRoutes.login:
        return ((_) => const LoginScreen(), push);
      case KanafRoutes.register:
        final role = settings.arguments;
        return (
          (_) => RegisterScreen(selectedRole: role is String ? role : null),
          push,
        );
      case KanafRoutes.forgotPassword:
        return ((_) => const ForgotPasswordScreen(), push);
      case KanafRoutes.resetPassword:
        return ((_) => const ResetPasswordScreen(), push);
      case KanafRoutes.phoneVerification:
        return ((_) => const PhoneVerificationScreen(), push);

      case '/home':
      case KanafRoutes.donorHome:
        return ((_) => const SupporterHomeScreen(), root);
      case KanafRoutes.donationSuccess:
        return ((_) => const DonationSuccessScreen(), reveal);
      case KanafRoutes.donationHistory:
        return ((_) => const DonationHistoryScreen(), push);
      case KanafRoutes.donationReceipt:
        return ((_) => const DonationReceiptScreen(), push);
      case KanafRoutes.donorNotifications:
        return ((_) => const NotificationsScreen(), push);
      case KanafRoutes.searchFilter:
        return ((_) => const SearchFilterScreen(), push);
      case KanafRoutes.donorProfile:
        return ((_) => const ProfileScreen(), push);
      case KanafRoutes.orphanageProfile:
        return ((_) => const OrphanageProfileScreen(), push);
      case KanafRoutes.needDetails:
        final args = settings.arguments;
        return (
          (_) => NeedDetailsScreen(
                needData: args is Map<String, dynamic> ? args : const {},
              ),
          push,
        );
      case KanafRoutes.financialDonation:
        return ((_) => const FinancialDonationScreen(), push);
      case KanafRoutes.inkindDonation:
        return ((_) => const InkindDonationScreen(), push);

      case KanafRoutes.volunteerHome:
      case '/home_volunteer':
        return ((_) => const HomeVolunteerView(), root);
      case KanafRoutes.volunteerOpportunityDetails:
        return ((_) => const VolunteerOpportunityDetailsView(), push);
      case KanafRoutes.applyOpportunity:
        return ((_) => const ApplyOpportunityView(), push);
      case KanafRoutes.mySchedule:
        return ((_) => const MyScheduleView(), push);
      case KanafRoutes.myVolunteerHistory:
        return ((_) => const MyVolunteerHistoryView(), push);
      case KanafRoutes.myCertificates:
        return ((_) => const MyCertificatesView(), push);
      case KanafRoutes.volunteerNotifications:
        return ((_) => const NotificationsView(), push);
      case KanafRoutes.volunteerSearch:
        return ((_) => const SearchFilterView(), push);
      case KanafRoutes.volunteerProfile:
        return ((_) => const ProfileVolunteerView(), push);

      case KanafRoutes.exploreOrphanages:
        return ((_) => const ExploreOrphanagesScreen(), push);
      case KanafRoutes.settings:
        return ((_) => const SettingsScreen(), push);
      case KanafRoutes.changePassword:
        return ((_) => const ChangePasswordScreen(), push);
      case KanafRoutes.changeEmail:
        return ((_) => const ChangeEmailScreen(), push);
      case KanafRoutes.aboutApp:
        return ((_) => const AboutAppScreen(), push);

      case KanafRoutes.notificationsCenter:
        return ((_) => const NotificationsCenterScreen(), push);
      case KanafRoutes.trackNeedStatus:
        return ((_) => const TrackNeedStatusScreen(), push);
      case KanafRoutes.notificationDetail:
        return ((_) => const NotificationDetailScreen(), push);

      default:
        return ((_) => const SplashScreen(), root);
    }
  }
}
