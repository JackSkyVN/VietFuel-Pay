import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/profile_remote_datasource.dart';
import '../../data/models/profile_model.dart';

// ── Shared Datasource ────────────────────────────────────────────────────────
final profileDataSourceProvider = Provider<ProfileRemoteDataSource>((ref) {
  final dio = ref.watch(dioProvider);
  return ProfileRemoteDataSource(dio);
});

// ── Profile Data Provider ────────────────────────────────────────────────────
// Reads the logged-in user's phone from the auth session – no hardcoding.
final profileProvider = FutureProvider<ProfileModel>((ref) async {
  final phone = ref.watch(sessionPhoneProvider);
  if (phone == null) throw StateError('loading');
  final ds = ref.watch(profileDataSourceProvider);
  return ds.getProfile(phone);
});
