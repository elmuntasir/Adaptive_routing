import 'package:flutter/material.dart';
import 'app_config.dart';
import 'theme/app_theme.dart';
import 'screens/movie_list.dart';
import 'services/rest_api_service.dart';
import 'services/graphql_api_service.dart';
import 'services/ai_agent_service.dart';
import 'routing/conscious_router.dart';
import 'routing/routing_history_store.dart';
import 'routing/heuristic_learning_store.dart';
import 'routing/ai_policy_store.dart';
import 'routing/device_profiler.dart';

export 'app_state.dart';

import 'services/service_locator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await RoutingHistoryStore.instance.load();
  await HeuristicLearningStore.instance.load();
  await AiPolicyStore.instance.init();
  await DeviceProfiler.instance.init();
  await AppConfig.initialize();
  ConsciousRouter.instance.initialize();

  restApiService = RestApiService(baseUrl: AppConfig.backendUrl);
  graphqlApiService = GraphQlApiService(
    endpoint: '${AppConfig.backendUrl}/graphql',
  );
  comparisonApiService = ComparisonApiService();

  apiService = AdaptiveApiService(
    restApiService: restApiService,
    graphqlApiService: graphqlApiService,
    comparisonApiService: comparisonApiService,
  );

  AiAgentService.instance.initializeAgent();

  runApp(const MovieApp());
}

class MovieApp extends StatelessWidget {
  const MovieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Movie API Test',
      theme: AppTheme.darkTheme,
      home: const MovieListScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
