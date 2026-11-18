import 'package:get_it/get_it.dart';

import '../../data/dao/shipment_dao.dart';
import '../../data/dao/tank_dao.dart';
import '../../data/dao/order_dao.dart';
import '../../data/dao/store_dao.dart';
import '../../data/dao/outbox_dao.dart';

import '../../data/repositories/shipment_repository_impl.dart';
import '../../data/repositories/order_repository_impl.dart';

import '../../data/sync/fake_sync_api.dart';
import '../../data/sync/sync_processor.dart';

import '../../domain/repositories/shipment_repository.dart';
import '../../domain/repositories/order_repository.dart';
import '../../domain/sync/sync_api.dart';

import '../../features/orders/bloc/orders_list_bloc.dart';
import '../../features/orders/bloc/tank_bloc.dart';
import '../../features/orders/bloc/order_bloc.dart';

import '../../features/shipments/bloc/shipment_list_bloc.dart';
import '../../features/shipments/bloc/shipment_wizard_bloc.dart';

import '../database/app_database.dart';
import '../database/database_change_notifier.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  final database = await AppDatabase.instance.database;

  getIt.registerSingleton(database);

  getIt.registerLazySingleton<DatabaseChangeNotifier>(
    () => DatabaseChangeNotifier(),
  );

  // DAOs
  getIt.registerLazySingleton<StoreDao>(() => StoreDao(getIt()));

  getIt.registerLazySingleton<OrderDao>(() => OrderDao(getIt(), getIt()));

  getIt.registerLazySingleton<TankDao>(() => TankDao(getIt(), getIt()));

  getIt.registerLazySingleton<ShipmentDao>(() => ShipmentDao(getIt(), getIt()));

  getIt.registerLazySingleton<OutboxDao>(() => OutboxDao(getIt()));

  // Repositories
  getIt.registerLazySingleton<OrderRepository>(
    () => OrderRepositoryImpl(
      orderDao: getIt(),
      storeDao: getIt(),
      tankDao: getIt(),
      changeNotifier: getIt(),
    ),
  );

  getIt.registerLazySingleton<ShipmentRepository>(
    () => ShipmentRepositoryImpl(shipmentDao: getIt(), changeNotifier: getIt()),
  );

  // Sync
  getIt.registerLazySingleton<SyncApi>(() => FakeSyncApi());

  getIt.registerLazySingleton<SyncProcessor>(
    () => SyncProcessor(outboxDao: getIt(), syncApi: getIt()),
  );

  // Order BLoCs
  getIt.registerFactory<TankBloc>(() => TankBloc(getIt()));

  getIt.registerFactory<OrderBloc>(() => OrderBloc(getIt()));

  getIt.registerFactory<OrdersListBloc>(
    () => OrdersListBloc(getIt<OrderRepository>()),
  );

  // Shipment BLoCs
  getIt.registerFactory<ShipmentListBloc>(() => ShipmentListBloc(getIt()));

  getIt.registerFactoryParam<ShipmentWizardBloc, String, void>(
    (initialDate, _) => ShipmentWizardBloc(
      repository: getIt<ShipmentRepository>(),
      initialDate: initialDate,
    ),
  );
}
