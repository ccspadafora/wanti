import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/network/api_client.dart';
import 'core/state/app_mode_controller.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/state/auth_controller.dart';
import 'features/contacts/data/contacts_repository.dart';
import 'features/inventory/data/inventory_repository.dart';
import 'features/leads/data/leads_repository.dart';
import 'features/matches/data/matches_repository.dart';
import 'features/needs/data/needs_repository.dart';
import 'features/wallet/data/wallet_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final api = ApiClient();
  final authRepo = AuthRepository(api);
  final auth = AuthController(api: api, repository: authRepo);
  final needsRepo = NeedsRepository(api);
  final matchesRepo = MatchesRepository(api);
  final inventoryRepo = InventoryRepository(api);
  final leadsRepo = LeadsRepository(api);
  final walletRepo = WalletRepository(api);
  final contactsRepo = ContactsRepository(api);
  final appMode = AppModeController();

  await auth.bootstrap();

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: api),
        Provider.value(value: needsRepo),
        Provider.value(value: matchesRepo),
        Provider.value(value: inventoryRepo),
        Provider.value(value: leadsRepo),
        Provider.value(value: walletRepo),
        Provider.value(value: contactsRepo),
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: appMode),
      ],
      child: WantiApp(auth: auth),
    ),
  );
}
