// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:dio/dio.dart' as _i361;
import 'package:frontend_flutter/src/app/di/app_module.dart' as _i372;
import 'package:frontend_flutter/src/app/services/api_key_validator.dart'
    as _i923;
import 'package:frontend_flutter/src/app/services/auto_updater_service.dart'
    as _i636;
import 'package:frontend_flutter/src/app/services/secure_storage_service.dart'
    as _i308;
import 'package:frontend_flutter/src/features/chat/application/usecases/run_task_usecase.dart'
    as _i912;
import 'package:frontend_flutter/src/features/chat/data/datasources/backend_rest_client.dart'
    as _i286;
import 'package:frontend_flutter/src/features/chat/data/datasources/backend_ws_client.dart'
    as _i468;
import 'package:frontend_flutter/src/features/chat/data/repositories/chat_repository_impl.dart'
    as _i151;
import 'package:frontend_flutter/src/features/chat/domain/repositories/chat_repository.dart'
    as _i673;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final appModule = _$AppModule();
    gh.lazySingleton<_i361.Dio>(() => appModule.dio);
    gh.lazySingleton<_i923.ApiKeyValidator>(() => _i923.ApiKeyValidator());
    gh.lazySingleton<_i308.SecureStorageService>(
      () => _i308.SecureStorageService(),
    );
    gh.lazySingleton<_i286.BackendRestClient>(() => _i286.BackendRestClient());
    gh.lazySingleton<_i468.BackendWsClient>(() => _i468.BackendWsClient());
    gh.lazySingleton<_i673.ChatRepository>(
      () => _i151.ChatRepositoryImpl(
        gh<_i468.BackendWsClient>(),
        gh<_i286.BackendRestClient>(),
      ),
    );
    gh.factory<_i912.RunTaskUseCase>(
      () => _i912.RunTaskUseCase(gh<_i673.ChatRepository>()),
    );
    gh.lazySingleton<_i636.AutoUpdaterService>(
      () => _i636.AutoUpdaterService(gh<_i361.Dio>()),
    );
    return this;
  }
}

class _$AppModule extends _i372.AppModule {}
