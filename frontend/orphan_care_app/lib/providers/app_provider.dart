import 'package:flutter/material.dart';

import '../models/donation_model.dart';
import '../models/donation_request.dart';
import '../models/need_model.dart';
import '../models/orphan_model.dart';
import '../models/volunteer_model.dart';
import '../services/api_failure.dart';
import '../services/api_service.dart';

class AppProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  ApiFailureKind? _errorKind;

  List<OrphanModel> _orphans = [];
  OrphanModel? _selectedOrphan;
  List<DonationModel> _donations = [];
  List<DonationModel> _myDonations = [];
  List<VolunteerModel> _volunteers = [];
  List<NeedModel> _needs = [];
  List<Map<String, dynamic>> _volunteerOpportunities = [];
  List<Map<String, dynamic>> _volunteerApplications = [];
  List<Map<String, dynamic>> _careHomes = [];
  NeedModel? _selectedNeed;
  Map<String, dynamic> _currentUser = {};
  Map<String, dynamic> _dashboardStats = {};
  // مواعيد زيارة الدار — للقراءة فقط، يعرضها المتبرع في ملف الدار.
  List<Map<String, dynamic>> _visitHours = [];
  List<Map<String, dynamic>> _notifications = [];

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  /// سبب آخر فشل. `null` يعني لا فشل قائماً.
  ApiFailureKind? get errorKind => _errorKind;

  /// هل آخر فشل سببه الشبكة فعلاً؟
  ///
  /// هذا ما يحكم عرض شاشة «لا يوجد اتصال»: لا تظهر إلا هنا. المستخدم
  /// المتصل الذي يصادف عطباً في الخادم يرى رسالة تخص الخادم.
  bool get isOffline => _errorKind?.isConnectivity ?? false;
  List<OrphanModel> get orphans => _orphans;
  OrphanModel? get selectedOrphan => _selectedOrphan;
  List<DonationModel> get donations => _donations;
  List<DonationModel> get myDonations => _myDonations;
  List<VolunteerModel> get volunteers => _volunteers;
  List<NeedModel> get needs => _needs;
  List<Map<String, dynamic>> get volunteerOpportunities =>
      _volunteerOpportunities;
  List<Map<String, dynamic>> get volunteerApplications =>
      _volunteerApplications;
  List<Map<String, dynamic>> get careHomes => _careHomes;
  NeedModel? get selectedNeed => _selectedNeed;
  Map<String, dynamic> get currentUser => _currentUser;
  Map<String, dynamic> get dashboardStats => _dashboardStats;
  List<Map<String, dynamic>> get visitHours => _visitHours;
  List<Map<String, dynamic>> get notifications => _notifications;

  Future<void> fetchOrphans() async {
    await _load(() async {
      final data = await _apiService.getOrphans();
      _orphans = data
          .map((item) =>
              OrphanModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    });
  }

  Future<void> fetchCurrentUser({bool notifyLoading = true}) async {
    await _load(() async {
      _currentUser = await _apiService.getMe();
    }, notifyLoading: notifyLoading);
  }

  Future<void> fetchOrphanDetails(int id) async {
    await _load(() async {
      _selectedOrphan =
          OrphanModel.fromJson(await _apiService.getOrphanDetails(id));
    });
  }

  Future<void> addOrphan(Map<String, dynamic> orphanData) async {
    await _save(() async {
      _orphans
          .add(OrphanModel.fromJson(await _apiService.addOrphan(orphanData)));
    });
  }

  Future<void> fetchDonations() async {
    await _load(() async {
      final data = await _apiService.getDonations();
      _donations = data
          .map((item) =>
              DonationModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    });
  }

  /// يرسل التبرع ويعيد السجل كما حفظه الخادم، أو `null` عند الفشل.
  ///
  /// إرجاع الكيان بدل `bool` مقصود: الشاشة تحتاج المعرّف الحقيقي
  /// لعرضه كرقم مرجعي، فلا يمكنها تلفيق رقم محلياً.
  Future<DonationModel?> submitDonation(DonationRequest request) {
    return _saveResult(() async {
      final created = DonationModel.fromJson(await _apiService.createDonation(
        request.toJson(),
      ));
      _donations.insert(0, created);
      _myDonations.insert(0, created);
      return created;
    });
  }

  Future<void> fetchMyDonations() async {
    await _load(() async {
      final data = await _apiService.getMyDonations();
      _myDonations = data
          .map((item) =>
              DonationModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    });
  }

  Future<bool> confirmDonationReceived(int id) async {
    return _save(() async {
      final updated =
          DonationModel.fromJson(await _apiService.confirmDonationReceived(id));
      _replaceDonation(updated);
      await fetchNeeds(notifyLoading: false);
      await fetchDashboardStats(notifyLoading: false);
    });
  }

  Future<void> fetchVolunteers() async {
    await _load(() async {
      final data = await _apiService.getVolunteers();
      _volunteers = data
          .map((item) =>
              VolunteerModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    });
  }

  Future<void> applyAsVolunteer(Map<String, dynamic> volunteerData) async {
    await _save(() async {
      _volunteers.add(VolunteerModel.fromJson(
          await _apiService.applyAsVolunteer(volunteerData)));
    });
  }

  Future<void> fetchDashboardStats({bool notifyLoading = true}) async {
    await _load(() async {
      _dashboardStats = await _apiService.getDashboardStats();
    }, notifyLoading: notifyLoading);
  }

  Future<void> fetchNeeds({bool notifyLoading = true}) async {
    await _load(() async {
      final data = await _apiService.getNeeds();
      _needs = data
          .map((item) =>
              NeedModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    }, notifyLoading: notifyLoading);
  }

  Future<void> fetchVolunteerOpportunities({bool notifyLoading = true}) async {
    await _load(() async {
      final data = await _apiService.getVolunteerOpportunities();
      _volunteerOpportunities =
          data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    }, notifyLoading: notifyLoading);
  }

  Future<bool> applyToVolunteerOpportunity(
      int opportunityId, Map<String, dynamic> data) {
    return _save(() async {
      await _apiService.applyToVolunteerOpportunity(opportunityId, data);
      await fetchVolunteerOpportunities(notifyLoading: false);
    });
  }

  Future<void> fetchVolunteerApplications({bool notifyLoading = true}) async {
    await _load(() async {
      final data = await _apiService.getVolunteerApplications();
      _volunteerApplications =
          data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    }, notifyLoading: notifyLoading);
  }

  Future<void> fetchNeedDetails(int id) async {
    await _load(() async {
      _selectedNeed = NeedModel.fromJson(await _apiService.getNeedDetails(id));
    });
  }

  Future<void> fetchCareHomes({bool notifyLoading = true}) async {
    await _load(() async {
      final data = await _apiService.getCareHomes();
      _careHomes =
          data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    }, notifyLoading: notifyLoading);
  }

  /// مواعيد زيارة دار بعينها — يعرضها المتبرع قبل أن يقصد الدار.
  Future<void> fetchVisitHours(int careHomeId,
      {bool notifyLoading = true}) async {
    await _load(() async {
      final data = await _apiService.getVisitHours(careHomeId);
      _visitHours =
          data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    }, notifyLoading: notifyLoading);
  }

  Future<void> fetchNotifications({bool notifyLoading = true}) async {
    await _load(() async {
      final data = await _apiService.getNotifications();
      _notifications =
          data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    }, notifyLoading: notifyLoading);
  }

  Future<bool> markNotificationRead(int id) {
    return _save(() async {
      await _apiService.markNotificationRead(id);
      final index = _notifications.indexWhere((item) => item['id'] == id);
      if (index != -1) _notifications[index]['is_read'] = true;
    });
  }

  Future<bool> markAllNotificationsRead() {
    return _save(() async {
      await _apiService.markAllNotificationsRead();
      for (final notification in _notifications) {
        notification['is_read'] = true;
      }
    });
  }

  void clearError() {
    if (_errorMessage == null && _errorKind == null) return;
    _clearFailure();
    notifyListeners();
  }

  void clearAll() {
    _orphans = [];
    _donations = [];
    _myDonations = [];
    _volunteers = [];
    _needs = [];
    _volunteerOpportunities = [];
    _volunteerApplications = [];
    _careHomes = [];
    _currentUser = {};
    _dashboardStats = {};
    _visitHours = [];
    _notifications = [];
    _selectedOrphan = null;
    _selectedNeed = null;
    _isLoading = false;
    _isSaving = false;
    _clearFailure();
    notifyListeners();
  }

  Future<void> _load(Future<void> Function() loader,
      {bool notifyLoading = true}) async {
    // إشعار واحد في البداية وآخر في النهاية. كانت الدالة تُطلق ثلاثة:
    // `_setLoading(true)` ثم `_setLoading(false)` ثم `notifyListeners()`،
    // وكل واحد منها يعيد بناء **كل** شاشة تستمع للمزوّد.
    if (notifyLoading && !_isLoading) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      await loader();
      _clearFailure();
    } catch (e) {
      _recordFailure(e);
      debugPrint('Kanaf load failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> _save(Future<void> Function() saver) async {
    final completed = await _saveResult(() async {
      await saver();
      return true;
    });
    return completed ?? false;
  }

  /// نفس حارس `_save` لكنه يمرر الكيان المحفوظ إلى المستدعي.
  /// `null` تعني فشلاً مؤكداً — لا حالة وسطى.
  Future<T?> _saveResult<T>(Future<T> Function() saver) async {
    if (_isSaving) return null;
    _isSaving = true;
    notifyListeners();
    try {
      final result = await saver();
      _clearFailure();
      return result;
    } catch (e) {
      _recordFailure(e);
      debugPrint('Kanaf save failed: $e');
      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// يسجّل الفشل **مع سببه**.
  ///
  /// النص وحده لا يكفي: الواجهة تحتاج أن تعرف هل السبب انقطاع شبكة
  /// (فتعرض شاشة «لا يوجد اتصال») أم عطب في الخادم أم جلسة منتهية.
  /// بدون التصنيف كانت كل الأعطال تظهر كانقطاع اتصال.
  void _recordFailure(Object error) {
    if (error is ApiServiceException) {
      _errorMessage = error.message;
      _errorKind = error.kind;
      return;
    }
    _errorMessage = 'تعذر إكمال العملية حالياً. حاول مرة أخرى.';
    _errorKind = ApiFailureKind.unknown;
  }

  void _clearFailure() {
    _errorMessage = null;
    _errorKind = null;
  }

  void _replaceDonation(DonationModel updated) {
    final index =
        _donations.indexWhere((donation) => donation.id == updated.id);
    if (index == -1) {
      _donations.insert(0, updated);
    } else {
      _donations[index] = updated;
    }
  }
}
