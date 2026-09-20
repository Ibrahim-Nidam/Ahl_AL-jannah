/// Dependency injection setup using [get_it] and [injectable].
///
/// Call [configureDependencies] once in `main()` before running the app.
library;
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'injection.config.dart';

/// Global service locator instance.
final GetIt getIt = GetIt.instance;

bool _configured = false;

/// Configures all injectable dependencies.
///
/// Must be called in `main()` before `runApp()`. Safe to call again in the
/// same isolate (e.g. a retried Workmanager task).
@InjectableInit(preferRelativeImports: true)
void configureDependencies() {
  if (_configured) return;
  getIt.init();
  _configured = true;
}
