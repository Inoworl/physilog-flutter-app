import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const fixtureValue = 'ios-sdk-fixture-742';

  group('iOS build log masking', () {
    test(
      'masks plaintext and each encoded define before returning build args',
      () {
        final result = _runFastfile({'SDK_KEY': fixtureValue});
        final encoded = base64Encode(utf8.encode('SDK_KEY=$fixtureValue'));
        final lines = const LineSplitter().convert(result.stdout as String);

        expect(result.exitCode, 0, reason: result.stderr as String);
        expect(lines.last, encoded);
        expect(
          lines.take(lines.length - 1),
          contains('::add-mask::$fixtureValue'),
        );
        expect(lines.take(lines.length - 1), contains('::add-mask::$encoded'));
      },
    );

    test('preserves existing build arguments outside GitHub Actions', () {
      final result = _runFastfile({
        'SDK_KEY': fixtureValue,
        'ENABLED': true,
        'EMPTY': '',
      }, githubActions: false);
      final expected = [
        'SDK_KEY=$fixtureValue',
        'ENABLED=true',
        'EMPTY=',
      ].map((entry) => base64Encode(utf8.encode(entry))).join(',');

      expect(result.exitCode, 0, reason: result.stderr as String);
      expect(result.stdout, '$expected\n');
    });

    test('masks individual values in a multi-define build argument', () {
      final values = {
        'SDK_KEY': fixtureValue,
        'SERVICE_TOKEN': 'second-fixture',
      };
      final result = _runFastfile(values);
      final lines = const LineSplitter().convert(result.stdout as String);

      expect(result.exitCode, 0, reason: result.stderr as String);
      for (final entry in values.entries) {
        final encoded = base64Encode(
          utf8.encode('${entry.key}=${entry.value}'),
        );
        expect(lines.take(lines.length - 1), contains('::add-mask::$encoded'));
        expect(
          lines.take(lines.length - 1),
          contains('::add-mask::${entry.value}'),
        );
      }
    });

    test('escapes workflow command control characters', () {
      final result = _runFastfile({'SDK_KEY': 'fixture%\r\n::warning::value'});
      final output = result.stdout as String;

      expect(result.exitCode, 0, reason: result.stderr as String);
      expect(output, contains('::add-mask::fixture%25%0D%0A::warning::value'));
      expect(output, isNot(contains('\n::warning::value')));
    });
  });

  group('iOS build log artifacts', () {
    late Directory temporaryDirectory;
    late File config;
    late File log;

    setUp(() {
      temporaryDirectory = Directory.systemTemp.createTempSync('ios-log-test-');
      config = File('${temporaryDirectory.path}/defines.json')
        ..writeAsStringSync(jsonEncode({'SDK_KEY': fixtureValue, 'EMPTY': ''}));
      log = File('${temporaryDirectory.path}/build.log');
    });

    tearDown(() => temporaryDirectory.deleteSync(recursive: true));

    ProcessResult redact() => Process.runSync('ruby', [
      'ios/fastlane/dart_define_log_redaction.rb',
      config.path,
      '${temporaryDirectory.path}/*.log',
    ]);

    test('removes raw and encoded values while keeping useful diagnostics', () {
      final encoded = base64Encode(utf8.encode('SDK_KEY=$fixtureValue'));
      log.writeAsStringSync('Archive succeeded\n$fixtureValue\n$encoded\n');

      final result = redact();

      expect(result.exitCode, 0, reason: result.stderr as String);
      expect(
        log.readAsStringSync(),
        'Archive succeeded\n[REDACTED]\n[REDACTED]\n',
      );
      expect('${result.stdout}${result.stderr}', isNot(contains(fixtureValue)));
      expect('${result.stdout}${result.stderr}', isNot(contains(encoded)));
    });

    test('handles non-ASCII values and non-UTF-8 log bytes', () {
      config.writeAsStringSync(jsonEncode({'SDK_KEY': '検証用の値'}));
      log.writeAsBytesSync([0xff, ...utf8.encode('検証用の値'), 0xfe]);

      final result = redact();

      expect(result.exitCode, 0, reason: result.stderr as String);
      expect(log.readAsBytesSync(), [0xff, ...utf8.encode('[REDACTED]'), 0xfe]);
    });

    test('fails closed when logs exist but the config is missing', () {
      log.writeAsStringSync(fixtureValue);
      config.deleteSync();

      final result = redact();

      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('diagnostics withheld'));
      expect('${result.stdout}${result.stderr}', isNot(contains(fixtureValue)));
    });

    test('does not echo malformed configuration in errors', () {
      log.writeAsStringSync(fixtureValue);
      config.writeAsStringSync('{"SDK_KEY":"$fixtureValue", invalid}');

      final result = redact();

      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('diagnostics withheld'));
      expect('${result.stdout}${result.stderr}', isNot(contains(fixtureValue)));
    });

    test('permits an early build failure that created no log files', () {
      config.deleteSync();

      final result = redact();

      expect(result.exitCode, 0, reason: result.stderr as String);
    });

    test('refuses symbolic links instead of modifying their target', () {
      final target = File('${temporaryDirectory.path}/private.txt')
        ..writeAsStringSync(fixtureValue);
      Link(log.path).createSync(target.path);

      final result = redact();

      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('diagnostics withheld'));
      expect(target.readAsStringSync(), fixtureValue);
    });
  });

  for (final environment in ['dev', 'prod']) {
    test('$environment diagnostics require successful log redaction', () {
      final workflow = File(
        '.github/workflows/deploy_${environment}_ios.yml',
      ).readAsStringSync();
      final redaction = workflow.indexOf('- name: Redact iOS build logs');
      final diagnostics = workflow.indexOf(
        '- name: Show redacted iOS build logs',
      );
      final upload = workflow.indexOf('- name: Upload build logs');
      const guard =
          "if: failure() && steps.redact_ios_build_logs.outcome == 'success'";

      expect(redaction, greaterThanOrEqualTo(0));
      expect(diagnostics, greaterThan(redaction));
      expect(upload, greaterThan(diagnostics));
      expect(workflow.substring(diagnostics, upload), contains(guard));
      expect(workflow.substring(upload), contains(guard));
      expect(workflow, contains('dart_define/${environment}_dart_define.json'));
      expect(
        workflow,
        contains('ruby ios/fastlane/dart_define_log_redaction.rb'),
      );
      expect(workflow, isNot(contains('xcodebuild -showBuildSettings')));
      expect(workflow.substring(upload), contains('ios/build/logs/**/*.log'));
    });
  }
}

ProcessResult _runFastfile(
  Map<String, Object> values, {
  bool githubActions = true,
}) => Process.runSync(
  'ruby',
  [
    '-rjson',
    '-e',
    '''
def default_platform(*); end
def platform(*); end
load 'ios/fastlane/Fastfile'
puts flutter_dart_defines(JSON.parse(ARGV.fetch(0)))
''',
    jsonEncode(values),
  ],
  environment: {'GITHUB_ACTIONS': githubActions.toString()},
);
