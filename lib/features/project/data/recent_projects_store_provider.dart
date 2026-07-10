import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/core/storage/storage_providers.dart';
import 'package:forkumentos/features/project/data/recent_projects_store.dart';

final recentProjectsStoreProvider = Provider<RecentProjectsStore>((ref) {
  return RecentProjectsStore(ref.watch(keyValueStorageProvider));
});
