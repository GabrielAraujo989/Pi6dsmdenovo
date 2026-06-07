import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gestcare_app/home_dashboard_data_source.dart';
import 'package:gestcare_app/main.dart';

class _FakeHomeDashboardDataSource implements HomeDashboardDataSource {
  const _FakeHomeDashboardDataSource();

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
        ),
      ],
      quickActions: [
        HomeQuickActionData(
          iconKey: 'diary',
          title: 'Diario',
          subtitle: 'Registrar sintomas',
          routeName: '/daily-log',
        ),
      ],
      recommendedArticleTitle: 'Preparando o quarto: o que realmente importa?',
    );
  }
}

Future<void> _setLargeViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('Renderiza tela inicial do Maternar', (
    WidgetTester tester,
  ) async {
    await _setLargeViewport(tester);

    await tester.pumpWidget(const GestCareApp());

    expect(find.text('Maternar'), findsOneWidget);
    expect(find.text('Criar Minha Conta'), findsOneWidget);
  });

  testWidgets('Renderiza Home com secoes principais', (
    WidgetTester tester,
  ) async {
    await _setLargeViewport(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: HomeDashboardScreen(
          dataSource: const _FakeHomeDashboardDataSource(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dicas de hoje'), findsOneWidget);
    expect(find.text('Diario'), findsOneWidget);
    expect(find.textContaining('24 semanas'), findsWidgets);
  });

  testWidgets('Renderiza tela de nutricao', (WidgetTester tester) async {
    await _setLargeViewport(tester);

    await tester.pumpWidget(const MaterialApp(home: NutritionTipsScreen()));

    expect(find.text('Dicas de Nutricao'), findsOneWidget);
    expect(find.text('Alimentacao para cada fase'), findsOneWidget);
    expect(find.text('Salvar lembrete de hidratacao'), findsOneWidget);
  });

  testWidgets('Renderiza tela semanal do bebe', (WidgetTester tester) async {
    await _setLargeViewport(tester);

    await tester.pumpWidget(const MaterialApp(home: BabyWeekPlannerScreen()));

    expect(find.textContaining('Voce esta com'), findsOneWidget);
    expect(find.text('Suas tarefas da semana'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
  });
}
