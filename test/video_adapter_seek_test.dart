import 'dart:async';

import 'package:bear_tv/player/video_adapter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';

class _Player extends VideoPlayerController {
  _Player() : super.networkUrl(Uri.parse('https://example.test/video'));

  final targets = <Duration>[];
  final gates = <Completer<void>>[];
  int active = 0;
  int maxActive = 0;
  double effectiveSpeed = 1;

  @override
  Future<void> initialize() async {
    value = const VideoPlayerValue(
      duration: Duration(hours: 1),
      position: Duration(minutes: 1),
      isInitialized: true,
    );
  }

  @override
  Future<void> setPlaybackSpeed(double speed) async {
    effectiveSpeed = speed;
    value = value.copyWith(playbackSpeed: speed);
  }

  @override
  Future<void> play() async {
    effectiveSpeed = 1; // Simulate a backend resetting rate on playback start.
    value = value.copyWith(isPlaying: true);
  }

  @override
  Future<void> seekTo(Duration position) async {
    targets.add(position);
    active++;
    if (active > maxActive) maxActive = active;
    final gate = Completer<void>();
    gates.add(gate);
    await gate.future;
    effectiveSpeed = 1; // Simulate a seek resetting native playback rate.
    active--;
    value = value.copyWith(position: position);
  }

  @override
  // No platform player is created by this fake.
  // ignore: must_call_super
  Future<void> dispose() async {}
}

void main() {
  test('remembered rate is reapplied after play starts', () async {
    final backend = _Player();
    final adapter = VideoAdapter(controllerFactory: (_) => backend);
    await adapter.setSpeed(3);
    await adapter.open('https://example.test/video');
    await adapter.play();
    expect(backend.effectiveSpeed, 3);
    expect(adapter.value.speed, 3);
    adapter.dispose();
  });

  test('held-key targets accumulate while seeks serialize and coalesce',
      () async {
    final backend = _Player();
    final adapter = VideoAdapter(controllerFactory: (_) => backend);
    await adapter.open('https://example.test/video');
    final first =
        adapter.seekTo(adapter.value.position + const Duration(seconds: 10));
    await Future<void>.delayed(Duration.zero);
    for (var i = 0; i < 5; i++) {
      unawaited(
          adapter.seekTo(adapter.value.position + const Duration(seconds: 10)));
    }
    expect(adapter.value.position, const Duration(seconds: 120));
    expect(backend.targets, [const Duration(seconds: 70)]);
    backend.gates.first.complete();
    await Future<void>.delayed(Duration.zero);
    expect(backend.targets,
        [const Duration(seconds: 70), const Duration(seconds: 120)]);
    expect(backend.maxActive, 1);
    backend.gates.last.complete();
    await first;
    expect(adapter.value.position, const Duration(seconds: 120));
    adapter.dispose();
  });
}
