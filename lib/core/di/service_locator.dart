import 'package:get_it/get_it.dart';
import '../../services/export_service.dart';
import '../../services/image_processor.dart';
import '../../services/gps_service.dart';
import '../../services/database_service.dart';
import '../../features/scanner/providers/scanner_controller.dart';

/// Central dependency injection setup.
final sl = GetIt.instance;

Future<void> initDependencies() async {
  // ── Services (singletons) ──
  sl.registerLazySingleton<ExportService>(() => ExportService());
  sl.registerLazySingleton<DatabaseService>(() => DatabaseService());
  sl.registerLazySingleton<ImageProcessor>(() => ImageProcessor());
  sl.registerLazySingleton<GpsService>(() => GpsService());

  // ── Controllers (factories — new instance each time) ──
  sl.registerFactory<ScannerController>(() => ScannerController(
    exportService: sl<ExportService>(),
  ));
}
