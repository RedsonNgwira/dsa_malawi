import 'package:get_it/get_it.dart';
import '../../services/export_service.dart';
import '../../services/image_processor.dart';
import '../../services/gps_service.dart';
import '../../services/database_service.dart';

/// Central dependency injection setup.
final sl = GetIt.instance;

Future<void> initDependencies() async {
  // ── Services (singletons) ──
  sl.registerLazySingleton<ExportService>(() => ExportService());
  sl.registerLazySingleton<DatabaseService>(() => DatabaseService());
  // ImageProcessor and GpsService are all-static, but we register them
  // so they can be mocked in tests later.
  sl.registerLazySingleton<ImageProcessor>(() => ImageProcessor());
  sl.registerLazySingleton<GpsService>(() => GpsService());
}
