import '../../core/api/api_client.dart';

class ConstraintRepository {
  final ApiClient _api;

  ConstraintRepository(this._api);

  Future<void> updateConstraints(Map<String, dynamic> constraints) async {
    await _api.patch('/constraints', body: constraints);
  }
}
