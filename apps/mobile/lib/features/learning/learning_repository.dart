import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/network/api_client.dart';
import '../../core/sync/offline_sync.dart';
import '../../data/sample_content.dart';
import '../auth/auth_controller.dart';

class LearningLesson {
  const LearningLesson({
    required this.item,
    required this.locked,
    required this.cards,
    required this.questions,
    this.updatedAt,
    this.contentVersion,
  });
  final LessonItem item;
  final bool locked;
  final List<KnowledgeCard> cards;
  final List<QuizQuestion> questions;
  final String? updatedAt;
  final String? contentVersion;

  String get cacheRevision {
    final serverRevision = '${updatedAt ?? ''}:${contentVersion ?? ''}';
    if (serverRevision != ':') return serverRevision;
    return sha256
        .convert(
          utf8.encode(
            jsonEncode({
              'cards': cards
                  .map((card) => {...card.toJson()}..remove('imagePath'))
                  .toList(),
              'questions': questions
                  .map(
                    (question) => {
                      ...question.toJson(),
                      'imagePath': null,
                      'options': question.options
                          .map(
                            (option) =>
                                {...option.toJson()}..remove('imagePath'),
                          )
                          .toList(),
                    },
                  )
                  .toList(),
            }),
          ),
        )
        .toString();
  }

  factory LearningLesson.fromJson(Map<String, dynamic> json) => LearningLesson(
    item: LessonItem.fromJson(json),
    updatedAt: json['updatedAt'] as String?,
    contentVersion: json['contentVersion'] as String?,
    locked: json['locked'] as bool? ?? false,
    cards: (json['knowledgeCards'] as List? ?? const [])
        .whereType<Map>()
        .map((v) => KnowledgeCard.fromJson(Map<String, dynamic>.from(v)))
        .toList(),
    questions: (json['questions'] as List? ?? const [])
        .whereType<Map>()
        .map((v) => QuizQuestion.fromJson(Map<String, dynamic>.from(v)))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    ...item.toJson(),
    if (updatedAt != null) 'updatedAt': updatedAt,
    if (contentVersion != null) 'contentVersion': contentVersion,
    'locked': locked,
    'knowledgeCards': cards.map((v) => v.toJson()).toList(),
    'questions': questions.map((v) => v.toJson()).toList(),
  };
}

class LearningRepository {
  LearningRepository({
    required this.auth,
    ApiClient? api,
    Future<Directory> Function()? documentsDirectory,
  }) : _api = api ?? ApiClient(),
       _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory {
    _progressQueue = OfflineSyncQueue(
      accountId: auth.user?.id ?? 'guest',
      documentsDirectory:
          documentsDirectory ?? getApplicationDocumentsDirectory,
    );
  }

  final AuthController auth;
  final ApiClient _api;
  final Future<Directory> Function() _documentsDirectory;
  Future<void> _pending = Future<void>.value();
  Future<void> _progressTail = Future<void>.value();
  late final OfflineSyncQueue _progressQueue;
  String? lastSyncError;
  OfflineSyncState syncState = OfflineSyncState.localOnly;
  int pendingProgressCount = 0;

  Future<T> _serializedProgress<T>(Future<T> Function() action) {
    final result = _progressTail.then((_) => action());
    _progressTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<void> _progressFailure(Object error) async {
    final snapshot = await _progressQueue.snapshot();
    lastSyncError = error.toString();
    syncState = OfflineSyncState.failed;
    pendingProgressCount = snapshot.pendingCount + snapshot.failedCount;
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  String get _account => auth.user?.id ?? 'guest';

  Future<String?> _cacheImage({
    required Directory directory,
    required String? imageUrl,
    required String fileName,
    required String token,
    required String lessonId,
    required String revision,
    String? fallbackPath,
  }) async {
    if (imageUrl == null || imageUrl.trim().isEmpty) return null;
    // Include the lesson revision: an edited image can keep the same Drive ID.
    final cacheVersion = sha256
        .convert(utf8.encode('$revision:$imageUrl'))
        .toString();
    final file = File('${directory.path}/$fileName-$cacheVersion.webp');
    try {
      if (!await file.exists() || await file.length() == 0) {
        final bytes = await _api.download(
          _imageEndpoint(lessonId, imageUrl),
          token: token,
        );
        if (bytes.isEmpty) throw const FormatException('Empty lesson image');
        final temporary = File('${file.path}.part');
        await temporary.writeAsBytes(bytes, flush: true);
        await temporary.rename(file.path);
      }
      return file.path;
    } catch (_) {
      return fallbackPath;
    }
  }

  String _imageEndpoint(String lessonId, String imageUrl) {
    final uri = Uri.tryParse(imageUrl);
    if (uri == null ||
        (uri.host != 'drive.google.com' && uri.host != 'docs.google.com')) {
      return imageUrl;
    }
    final match = RegExp(r'/file/d/([^/]+)').firstMatch(uri.path);
    final fileId = uri.queryParameters['id'] ?? match?.group(1);
    if (fileId == null || fileId.isEmpty) return imageUrl;
    return '/learning/lessons/$lessonId/drive-images/${Uri.encodeComponent(fileId)}';
  }

  Future<List<LearningLesson>> _cacheMedia(
    List<LearningLesson> lessons,
    String? token,
    String account,
    List<LearningLesson> previous,
  ) async {
    if (token == null) return lessons;
    final root = await _documentsDirectory();
    final directory = Directory('${root.path}/learning/$account/images');
    await directory.create(recursive: true);
    final result = <LearningLesson>[];
    final previousImages = <String, String>{};
    void remember(String? url, String? path) {
      if (url != null && path != null) previousImages[url] = path;
    }

    for (final lesson in previous) {
      for (final card in lesson.cards) {
        remember(card.imageLabel, card.imagePath);
      }
      for (final question in lesson.questions) {
        remember(question.imageLabel, question.imagePath);
        for (final option in question.options) {
          remember(option.imageLabel, option.imagePath);
        }
      }
    }

    for (final lesson in lessons) {
      final cards = <KnowledgeCard>[];
      for (var index = 0; index < lesson.cards.length; index++) {
        final card = lesson.cards[index];
        final imagePath = await _cacheImage(
          directory: directory,
          imageUrl: card.imageLabel,
          fileName: '${lesson.item.id}-knowledge-$index',
          token: token,
          lessonId: lesson.item.id,
          revision: lesson.cacheRevision,
          fallbackPath: previousImages[card.imageLabel],
        );
        cards.add(
          KnowledgeCard(
            tag: card.tag,
            title: card.title,
            body: card.body,
            bullets: card.bullets,
            imageLabel: card.imageLabel,
            imagePath: imagePath ?? card.imagePath,
          ),
        );
      }

      final questions = <QuizQuestion>[];
      for (
        var questionIndex = 0;
        questionIndex < lesson.questions.length;
        questionIndex++
      ) {
        final question = lesson.questions[questionIndex];
        final questionImagePath = await _cacheImage(
          directory: directory,
          imageUrl: question.imageLabel,
          fileName: '${lesson.item.id}-question-$questionIndex',
          token: token,
          lessonId: lesson.item.id,
          revision: lesson.cacheRevision,
          fallbackPath: previousImages[question.imageLabel],
        );
        final options = <QuizOption>[];
        for (
          var optionIndex = 0;
          optionIndex < question.options.length;
          optionIndex++
        ) {
          final option = question.options[optionIndex];
          final optionImagePath = await _cacheImage(
            directory: directory,
            imageUrl: option.imageLabel,
            fileName:
                '${lesson.item.id}-question-$questionIndex-option-$optionIndex',
            token: token,
            lessonId: lesson.item.id,
            revision: lesson.cacheRevision,
            fallbackPath: previousImages[option.imageLabel],
          );
          options.add(
            QuizOption(
              text: option.text,
              imageLabel: option.imageLabel,
              imagePath: optionImagePath ?? option.imagePath,
            ),
          );
        }
        questions.add(
          QuizQuestion(
            question: question.question,
            imageLabel: question.imageLabel,
            imagePath: questionImagePath ?? question.imagePath,
            options: options,
            correctIndex: question.correctIndex,
            explanation: question.explanation,
          ),
        );
      }

      result.add(
        LearningLesson(
          item: lesson.item,
          locked: lesson.locked,
          cards: cards,
          questions: questions,
          updatedAt: lesson.updatedAt,
          contentVersion: lesson.contentVersion,
        ),
      );
    }
    return result;
  }

  Future<File> _file(String account) async {
    final root = await _documentsDirectory();
    final directory = Directory('${root.path}/learning/$account');
    await directory.create(recursive: true);
    return File('${directory.path}/lessons.json');
  }

  Future<List<LearningLesson>> load() => _serialized(_load);

  Future<List<LearningLesson>> _load() async {
    final account = _account;
    final authenticated = auth.isAuthenticated;
    final previous = await _readCache(account);
    void requireSameAccount() {
      if (_account != account || auth.isAuthenticated != authenticated) {
        throw StateError('Learning account changed during refresh');
      }
    }

    if (authenticated) {
      try {
        requireSameAccount();
        final response = await auth.runAuthenticated((token) {
          requireSameAccount();
          return _api.get('/learning/lessons', token: token);
        });
        requireSameAccount();
        final values = (response['data'] as List? ?? const [])
            .whereType<Map>()
            .map((v) => LearningLesson.fromJson(Map<String, dynamic>.from(v)))
            .toList();
        final detailed = <LearningLesson>[];
        final previousById = {for (final v in previous) v.item.id: v};
        for (final lesson in values) {
          if (lesson.locked) {
            detailed.add(lesson);
            continue;
          }
          final old = previousById[lesson.item.id];
          if (lesson.updatedAt != null &&
              lesson.updatedAt == old?.updatedAt &&
              (lesson.contentVersion == null ||
                  lesson.contentVersion == old?.contentVersion) &&
              !old!.locked) {
            detailed.add(
              LearningLesson(
                item: lesson.item,
                locked: false,
                cards: old.cards,
                questions: old.questions,
                updatedAt: old.updatedAt,
                contentVersion: old.contentVersion,
              ),
            );
            continue;
          }
          try {
            requireSameAccount();
            final detail = await auth.runAuthenticated((token) {
              requireSameAccount();
              return _api.get(
                '/learning/lessons/${lesson.item.id}',
                token: token,
              );
            });
            detailed.add(LearningLesson.fromJson(detail));
          } catch (_) {
            final old = previousById[lesson.item.id];
            detailed.add(
              LearningLesson(
                item: lesson.item,
                locked: lesson.locked,
                cards: old?.locked == false ? old!.cards : lesson.cards,
                questions: old?.locked == false
                    ? old!.questions
                    : lesson.questions,
                updatedAt: old?.updatedAt,
                contentVersion: old?.contentVersion,
              ),
            );
          }
        }
        requireSameAccount();
        final cached = await _cacheMedia(
          detailed,
          auth.accessToken,
          account,
          previous,
        );
        requireSameAccount();
        await _writeCache(account, cached);
        return cached;
      } catch (_) {
        // The account-specific cache below remains available without a server.
      }
    }
    if (previous.isNotEmpty) return previous;
    if (authenticated) return const [];
    return lessons
        .map(
          (item) => LearningLesson(
            item: item,
            locked: false,
            cards: knowledgeCards,
            questions: quizQuestions,
          ),
        )
        .toList();
  }

  Future<LearningLesson?> loadLesson(String lessonId) =>
      _serialized(() => _loadLesson(lessonId));

  Future<LearningLesson?> _loadLesson(String lessonId) async {
    final account = _account;
    final previous = await _readCache(account);
    final cachedLesson = previous
        .where((lesson) => lesson.item.id == lessonId)
        .firstOrNull;
    if (!auth.isAuthenticated) return cachedLesson;
    void requireSameAccount() {
      if (_account != account || !auth.isAuthenticated) {
        throw StateError('Learning account changed during refresh');
      }
    }

    try {
      final detail = await auth.runAuthenticated((token) {
        requireSameAccount();
        return _api.get('/learning/lessons/$lessonId', token: token);
      });
      requireSameAccount();
      final refreshed = (await _cacheMedia(
        [LearningLesson.fromJson(detail)],
        auth.accessToken,
        account,
        previous,
      )).single;
      requireSameAccount();
      // Keep other cached lessons when refreshing only the one being opened.
      final current = await _readCache(account);
      final merged = [
        ...current.where((lesson) => lesson.item.id != lessonId),
        refreshed,
      ];
      await _writeCache(account, merged);
      return refreshed;
    } on ApiException catch (error) {
      if (error.statusCode == 401 ||
          error.statusCode == 403 ||
          error.statusCode == 404) {
        rethrow;
      }
      return cachedLesson;
    } catch (_) {
      return cachedLesson;
    }
  }

  Future<void> _writeCache(String account, List<LearningLesson> lessons) async {
    final file = await _file(account);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode(lessons.map((lesson) => lesson.toJson()).toList()),
      flush: true,
    );
    await temporary.rename(file.path);
  }

  Future<List<LearningLesson>> _readCache(String account) async {
    try {
      final decoded = jsonDecode(await (await _file(account)).readAsString());
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((v) => LearningLesson.fromJson(Map<String, dynamic>.from(v)))
            .toList();
      }
    } catch (_) {
      // Guests can still preview sample content. Authenticated users must not
      // receive unlocked demo lessons when their account cache is empty.
    }
    return const [];
  }

  Future<void> saveProgress(
    String lessonId,
    double progress, {
    int? answeredCount,
    int? correctCount,
  }) => _serializedProgress(() async {
    if (!auth.isAuthenticated) return;
    try {
      await _progressQueue.enqueue(
        key: lessonId,
        type: 'learning_progress',
        payload: {
          'lessonId': lessonId,
          'progress': progress.clamp(0.0, 1.0),
          'answeredCount': answeredCount ?? 0,
          'correctCount': correctCount ?? 0,
        },
      );
      await _syncPendingProgress();
    } on OfflineSyncQueueCorruptionException catch (error) {
      await _progressFailure(error);
    }
  });

  Future<int> syncPendingProgress() => _serializedProgress(() async {
    try {
      return await _syncPendingProgress();
    } on OfflineSyncQueueCorruptionException catch (error) {
      await _progressFailure(error);
      return 0;
    }
  });

  Future<int> _syncPendingProgress() async {
    if (!auth.isAuthenticated) return 0;
    var synced = 0;
    final items = await _progressQueue.load();
    for (final item in items.where(
      (item) => item.type == 'learning_progress',
    )) {
      try {
        await _progressQueue.markSyncing(item.key);
        syncState = OfflineSyncState.syncing;
        await auth.runAuthenticated(
          (token) => _api.post(
            '/learning/lessons/${item.payload['lessonId']}/progress',
            token: token,
            body: item.payload,
          ),
        );
        await _progressQueue.markSynced(item.key);
        synced++;
      } catch (error) {
        lastSyncError = error.toString();
        await _progressQueue.markFailed(item.key, error);
        syncState = OfflineSyncState.failed;
      }
    }
    final snapshot = await _progressQueue.snapshot();
    pendingProgressCount = snapshot.pendingCount + snapshot.failedCount;
    if (pendingProgressCount == 0) {
      syncState = OfflineSyncState.synced;
      lastSyncError = null;
    } else if (syncState != OfflineSyncState.failed) {
      syncState = snapshot.state;
    }
    return synced;
  }
}
