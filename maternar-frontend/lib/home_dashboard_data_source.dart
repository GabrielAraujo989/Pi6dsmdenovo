import 'package:gestcare_app/app_session.dart';
import 'package:gestcare_app/backend_api.dart';

class HomeTipData {
  const HomeTipData({
    required this.iconKey,
    required this.title,
    required this.subtitle,
    this.warm = false,
    this.routeName,
  });

  final String iconKey;
  final String title;
  final String subtitle;
  final bool warm;
  final String? routeName;

  factory HomeTipData.fromJson(Map<String, dynamic> json) {
    return HomeTipData(
      iconKey: json['iconKey'] as String? ?? 'info',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      warm: json['warm'] as bool? ?? false,
      routeName: json['routeName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'iconKey': iconKey,
      'title': title,
      'subtitle': subtitle,
      'warm': warm,
      'routeName': routeName,
    };
  }
}

class HomeQuickActionData {
  const HomeQuickActionData({
    required this.iconKey,
    required this.title,
    required this.subtitle,
    required this.routeName,
  });

  final String iconKey;
  final String title;
  final String subtitle;
  final String routeName;

  factory HomeQuickActionData.fromJson(Map<String, dynamic> json) {
    return HomeQuickActionData(
      iconKey: json['iconKey'] as String? ?? 'menu',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      routeName: json['routeName'] as String? ?? '/home',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'iconKey': iconKey,
      'title': title,
      'subtitle': subtitle,
      'routeName': routeName,
    };
  }
}

class HomeDashboardData {
  const HomeDashboardData({
    required this.userName,
    required this.currentWeek,
    required this.daysToBirth,
    required this.dailyTips,
    required this.quickActions,
    required this.recommendedArticleTitle,
    this.recommendedArticleRoute = '/education',
  });

  final String userName;
  final int currentWeek;
  final int daysToBirth;
  final List<HomeTipData> dailyTips;
  final List<HomeQuickActionData> quickActions;
  final String recommendedArticleTitle;
  final String recommendedArticleRoute;

  factory HomeDashboardData.fromJson(Map<String, dynamic> json) {
    return HomeDashboardData(
      userName: json['userName'] as String? ?? 'Ana',
      currentWeek: json['currentWeek'] as int? ?? 24,
      daysToBirth: json['daysToBirth'] as int? ?? 112,
      dailyTips: (json['dailyTips'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(HomeTipData.fromJson)
          .toList(),
      quickActions: (json['quickActions'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(HomeQuickActionData.fromJson)
          .toList(),
      recommendedArticleTitle:
          json['recommendedArticleTitle'] as String? ??
          'Preparando o quarto: o que realmente importa?',
      recommendedArticleRoute:
          json['recommendedArticleRoute'] as String? ?? '/education',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userName': userName,
      'currentWeek': currentWeek,
      'daysToBirth': daysToBirth,
      'dailyTips': dailyTips.map((item) => item.toJson()).toList(),
      'quickActions': quickActions.map((item) => item.toJson()).toList(),
      'recommendedArticleTitle': recommendedArticleTitle,
      'recommendedArticleRoute': recommendedArticleRoute,
    };
  }
}

abstract class HomeDashboardDataSource {
  Future<HomeDashboardData> fetch();
}

class MockHomeDashboardDataSource implements HomeDashboardDataSource {
  const MockHomeDashboardDataSource();

  @override
  Future<HomeDashboardData> fetch() async {
    return const HomeDashboardData(
      userName: 'Ana',
      currentWeek: 24,
      daysToBirth: 112,
      dailyTips: [
        HomeTipData(
          iconKey: 'water',
          title: 'Hidratacao importante',
          subtitle: 'Mantenha a hidratacao para reduzir inchacos.',
          routeName: '/nutrition',
        ),
        HomeTipData(
          iconKey: 'meditation',
          title: 'Exercicios leves',
          subtitle: 'Yoga pre-natal ajuda no bem-estar e no sono.',
          warm: true,
        ),
        HomeTipData(
          iconKey: 'nutrition',
          title: 'Dicas de nutricao',
          subtitle: 'Orientacoes de alimentacao para cada fase da gestacao.',
          routeName: '/nutrition',
        ),
      ],
      quickActions: [
        HomeQuickActionData(
          iconKey: 'diary',
          title: 'Diario',
          subtitle: 'Registrar sintomas',
          routeName: '/daily-log',
        ),
        HomeQuickActionData(
          iconKey: 'library',
          title: 'Biblioteca',
          subtitle: 'Conteudos de gestacao',
          routeName: '/education',
        ),
      ],
      recommendedArticleTitle: 'Preparando o quarto: o que realmente importa?',
      recommendedArticleRoute: '/education',
    );
  }
}

class ApiHomeDashboardDataSource implements HomeDashboardDataSource {
  const ApiHomeDashboardDataSource({
    this.api = const BackendApi(),
    this.fallback = const MockHomeDashboardDataSource(),
  });

  final BackendApi api;
  final HomeDashboardDataSource fallback;

  @override
  Future<HomeDashboardData> fetch() async {
    final localData = await fallback.fetch();
    final token = AppSession.token;
    final localDueDate = AppSession.dueDate;

    if (token == null || token.isEmpty) {
      if (localDueDate != null) {
        return HomeDashboardData(
          userName: AppSession.profileName ?? localData.userName,
          currentWeek: AppSession.currentWeek ?? localData.currentWeek,
          daysToBirth: AppSession.daysToBirth ?? localData.daysToBirth,
          dailyTips: localData.dailyTips,
          quickActions: localData.quickActions,
          recommendedArticleTitle: localData.recommendedArticleTitle,
          recommendedArticleRoute: localData.recommendedArticleRoute,
        );
      }
      return localData;
    }

    try {
      final profile = await api.profile(token);
      await AppSession.saveProfile(
        name: profile.name,
        email: profile.email,
        dueDate: profile.birthDate,
      );

      return HomeDashboardData(
        userName: profile.name,
        currentWeek: AppSession.currentWeek ?? localData.currentWeek,
        daysToBirth: AppSession.daysToBirth ?? localData.daysToBirth,
        dailyTips: localData.dailyTips,
        quickActions: localData.quickActions,
        recommendedArticleTitle: localData.recommendedArticleTitle,
        recommendedArticleRoute: localData.recommendedArticleRoute,
      );
    } catch (_) {
      if (localDueDate != null) {
        return HomeDashboardData(
          userName: AppSession.profileName ?? localData.userName,
          currentWeek: AppSession.currentWeek ?? localData.currentWeek,
          daysToBirth: AppSession.daysToBirth ?? localData.daysToBirth,
          dailyTips: localData.dailyTips,
          quickActions: localData.quickActions,
          recommendedArticleTitle: localData.recommendedArticleTitle,
          recommendedArticleRoute: localData.recommendedArticleRoute,
        );
      }
      return localData;
    }
  }
}
