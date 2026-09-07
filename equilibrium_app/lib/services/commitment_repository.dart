import '../../core/api/api_client.dart';
import '../../models/commitment.dart';

class CommitmentRepository {
  final ApiClient _api;

  CommitmentRepository(this._api);

  Future<List<FixedCommitment>> getCommitments() async {
    final data = await _api.get('/commitments') as List;
    return data.map((json) => FixedCommitment.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<FixedCommitment> createCommitment(Map<String, dynamic> payload) async {
    final data = await _api.post('/commitments', body: payload);
    return FixedCommitment.fromJson(data);
  }

  Future<void> deleteCommitment(String id) async {
    await _api.delete('/commitments/$id');
  }
}
