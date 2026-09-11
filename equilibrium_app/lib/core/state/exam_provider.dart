import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../../models/exam.dart';

class ExamProvider extends ChangeNotifier {
  final ApiClient _api;

  List<Exam> _exams = [];
  List<Subject> _subjects = [];
  bool _isLoading = false;
  String? _errorMessage;

  ExamProvider(this._api);

  List<Exam> get exams => _exams;
  List<Exam> get upcomingExams => _exams.where((e) => e.isUpcoming).toList();
  List<Subject> get subjects => _subjects;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchAll() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _api.get('/exams'),
        _api.get('/subjects'),
      ]);
      _exams = (results[0] as List<dynamic>)
          .map((e) => Exam.fromJson(e as Map<String, dynamic>))
          .toList();
      _subjects = (results[1] as List<dynamic>)
          .map((s) => Subject.fromJson(s as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _errorMessage = 'Could not load exams. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Exam?> createExam({
    required String title,
    required DateTime examDate,
    String? subjectId,
    String? venue,
  }) async {
    try {
      final body = <String, dynamic>{
        'title': title,
        'examDate': examDate.toUtc().toIso8601String(),
      };
      if (subjectId != null) body['subjectId'] = subjectId;
      if (venue != null) body['venue'] = venue;

      final json = await _api.post('/exams', body: body);
      final exam = Exam.fromJson(json as Map<String, dynamic>);
      _exams.insert(0, exam);
      _exams.sort((a, b) => a.examDate.compareTo(b.examDate));
      notifyListeners();
      return exam;
    } catch (e) {
      _errorMessage = 'Could not create exam. Please try again.';
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateExam(String id, Map<String, dynamic> updates) async {
    try {
      final json = await _api.patch('/exams/$id', body: updates);
      final updated = Exam.fromJson(json as Map<String, dynamic>);
      final idx = _exams.indexWhere((e) => e.id == id);
      if (idx >= 0) _exams[idx] = updated;
      notifyListeners();
      return true;
    } catch (_) {
      _errorMessage = 'Could not update exam.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteExam(String id) async {
    try {
      await _api.delete('/exams/$id');
      _exams.removeWhere((e) => e.id == id);
      notifyListeners();
      return true;
    } catch (_) {
      _errorMessage = 'Could not delete exam.';
      notifyListeners();
      return false;
    }
  }

  Future<ExamTopic?> addTopic(String examId, {
    required String title,
    required int estimateMinutes,
    required double confidence,
    required String topicType,
  }) async {
    try {
      final json = await _api.post('/exams/$examId/topics', body: {
        'title': title,
        'estimateMinutes': estimateMinutes,
        'confidence': confidence,
        'topicType': topicType,
      });
      final topic = ExamTopic.fromJson(json as Map<String, dynamic>);
      final examIdx = _exams.indexWhere((e) => e.id == examId);
      if (examIdx >= 0) {
        final exam = _exams[examIdx];
        _exams[examIdx] = Exam(
          id: exam.id, userId: exam.userId,
          subjectId: exam.subjectId, subjectName: exam.subjectName,
          subjectColor: exam.subjectColor, title: exam.title,
          examDate: exam.examDate, venue: exam.venue,
          topics: [...exam.topics, topic], createdAt: exam.createdAt,
        );
      }
      notifyListeners();
      return topic;
    } catch (_) {
      _errorMessage = 'Could not add topic.';
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateTopic(String examId, String topicId, Map<String, dynamic> updates) async {
    try {
      final json = await _api.patch('/exams/$examId/topics/$topicId', body: updates);
      final updated = ExamTopic.fromJson(json as Map<String, dynamic>);
      final examIdx = _exams.indexWhere((e) => e.id == examId);
      if (examIdx >= 0) {
        final exam = _exams[examIdx];
        final newTopics = exam.topics.map((t) => t.id == topicId ? updated : t).toList();
        _exams[examIdx] = Exam(
          id: exam.id, userId: exam.userId,
          subjectId: exam.subjectId, subjectName: exam.subjectName,
          subjectColor: exam.subjectColor, title: exam.title,
          examDate: exam.examDate, venue: exam.venue,
          topics: newTopics, createdAt: exam.createdAt,
        );
      }
      notifyListeners();
      return true;
    } catch (_) {
      _errorMessage = 'Could not update topic.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTopic(String examId, String topicId) async {
    try {
      await _api.delete('/exams/$examId/topics/$topicId');
      final examIdx = _exams.indexWhere((e) => e.id == examId);
      if (examIdx >= 0) {
        final exam = _exams[examIdx];
        _exams[examIdx] = Exam(
          id: exam.id, userId: exam.userId,
          subjectId: exam.subjectId, subjectName: exam.subjectName,
          subjectColor: exam.subjectColor, title: exam.title,
          examDate: exam.examDate, venue: exam.venue,
          topics: exam.topics.where((t) => t.id != topicId).toList(),
          createdAt: exam.createdAt,
        );
      }
      notifyListeners();
      return true;
    } catch (_) {
      _errorMessage = 'Could not delete topic.';
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>?> scheduleTopics(String examId) async {
    try {
      final result = await _api.post('/exams/$examId/schedule-topics', body: {});
      await fetchAll(); // refresh exam list
      return result as Map<String, dynamic>;
    } catch (_) {
      _errorMessage = 'Could not schedule topics.';
      notifyListeners();
      return null;
    }
  }

  Future<Subject?> createSubject(String name, {String? color}) async {
    try {
      final body = <String, dynamic>{
        'name': name,
      };
      if (color != null) body['color'] = color;

      final json = await _api.post('/subjects', body: body);
      final subject = Subject.fromJson(json as Map<String, dynamic>);
      _subjects.add(subject);
      _subjects.sort((a, b) => a.name.compareTo(b.name));
      notifyListeners();
      return subject;
    } catch (_) {
      _errorMessage = 'Could not create subject. It may already exist.';
      notifyListeners();
      return null;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
