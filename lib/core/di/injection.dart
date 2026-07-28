/// Dependency injection setup using [get_it] and [injectable].
///
/// Call [configureDependencies] once in `main()` before running the app.
library;
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'injection.config.dart';

/// Global service locator instance.
final GetIt getIt = GetIt.instance;

/// Configures all injectable dependencies.
///
/// Must be called in `main()` before `runApp()`.
@InjectableInit(preferRelativeImports: true)
void configureDependencies() => getIt.init();
