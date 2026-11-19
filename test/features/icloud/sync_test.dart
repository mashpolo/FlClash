import 'dart:io';

import 'package:fl_clash/common/path.dart';
import 'package:fl_clash/features/icloud/sync.dart';
import 'package:fl_clash/models/profile.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/app_paths.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flclash/icloud');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory root;
  late File local;
  late ICloudYamlSync sync;
  late Map<String, Uint8List> cloud;
  late List<Profile> profiles;
  late bool failRead;
  late bool failWrite;
  late bool failList;
  late bool failRemove;
  late Set<String> placeholders;
  late String? validationError;
  Future<void> Function()? duringValidation;

  Uint8List bytes(String value) => Uint8List.fromList(value.codeUnits);

  Future<void> start() => sync.start(
    profiles: () => profiles,
    validate: (_) async {
      await duringValidation?.call();
      return validationError;
    },
    put: (profile) {
      profiles = [...profiles.where((item) => item.id != profile.id), profile];
    },
    remove: (id) async {
      if (failRemove) throw const FileSystemException('delete failed');
      final file = File(await appPath.getProfilePath(id.toString()));
      if (await file.exists()) await file.delete();
      profiles = profiles.where((item) => item.id != id).toList();
    },
    changed: () {},
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('icloud-sync-');
    await useAppPaths(root);
    local = File(await appPath.getProfilePath('1'));
    await local.parent.create(recursive: true);
    await local.writeAsString('a');
    profiles = [const Profile(id: 1, autoUpdateDuration: Duration.zero)];
    cloud = {};
    failRead = false;
    failWrite = false;
    failList = false;
    failRemove = false;
    placeholders = {};
    validationError = null;
    duringValidation = null;
    sync = ICloudYamlSync();
    messenger.setMockMethodCallHandler(channel, (call) async {
      final args = call.arguments as Map?;
      switch (call.method) {
        case 'folder':
          return '/iCloud/FlClash';
        case 'list':
          if (failList) throw PlatformException(code: 'unavailable');
          return {...cloud.keys, ...placeholders}.toList();
        case 'read':
          if (failRead) throw PlatformException(code: 'offline');
          if (placeholders.contains(args!['name'])) {
            throw PlatformException(code: 'downloading');
          }
          return cloud[args['name']];
        case 'write':
          if (failWrite) throw PlatformException(code: 'changed');
          expect(cloud[args!['name']], args['expected']);
          cloud[args['name'] as String] = args['bytes'] as Uint8List;
          return null;
        case 'disable':
          return null;
        default:
          throw MissingPluginException();
      }
    });
  });

  tearDown(() async {
    sync.dispose();
    messenger.setMockMethodCallHandler(channel, null);
    await root.delete(recursive: true);
  });

  test('exports, downloads changes and persists a common baseline', () async {
    await start();
    expect(cloud['1.yaml'], bytes('a'));
    cloud['1.yaml'] = bytes('b');
    await sync.sync();
    expect(await local.readAsString(), 'b');
    await local.writeAsString('c');
    await sync.sync();
    expect(cloud['1.yaml'], bytes('c'));
    expect(sync.error, isNull);
    expect(
      (await SharedPreferences.getInstance()).getString('icloudYamlSync'),
      contains('1.yaml'),
    );
  });

  test(
    'stale conflict choices cannot overwrite a newer cloud revision',
    () async {
      cloud['1.yaml'] = bytes('b');
      await start();
      final conflict = sync.conflicts['1.yaml']!;
      cloud['1.yaml'] = bytes('c');
      await sync.sync(resolve: conflict, useLocal: true);
      expect(cloud['1.yaml'], bytes('c'));
      expect(sync.conflicts, contains('1.yaml'));
      await sync.sync(resolve: sync.conflicts['1.yaml'], useLocal: false);
      expect(await local.readAsString(), 'c');
      expect(sync.conflicts, isEmpty);
    },
  );

  test('failed cloud writes do not advance the baseline', () async {
    await start();
    await local.writeAsString('b');
    failWrite = true;
    await sync.sync();
    expect(sync.error, isNotNull);
    expect(sync.busy, isFalse);
    failWrite = false;
    cloud['1.yaml'] = bytes('c');
    await sync.sync();
    expect(sync.conflicts, contains('1.yaml'));
  });

  test(
    'offline reads and invalid downloads leave the local file intact',
    () async {
      await start();
      failRead = true;
      await sync.sync();
      expect(await local.readAsString(), 'a');
      expect(sync.error, isNotNull);
      failRead = false;
      validationError = 'invalid';
      cloud['1.yaml'] = bytes('invalid');
      await sync.sync();
      expect(await local.readAsString(), 'a');
      expect(sync.error, isNotNull);
    },
  );

  test(
    'new cloud files import once and keep their identity after restart',
    () async {
      cloud['from-other-mac.yaml'] = bytes('remote');
      await start();
      final imported = profiles.singleWhere((profile) => profile.id != 1);
      expect(
        await File(
          await appPath.getProfilePath(imported.id.toString()),
        ).readAsString(),
        'remote',
      );
      sync.dispose();
      sync = ICloudYamlSync();
      await start();
      expect(profiles.length, 2);
      expect(cloud.keys, containsAll(['1.yaml', 'from-other-mac.yaml']));
      expect(cloud.length, 2);
    },
  );

  test('an edit while cloud content is being validated is preserved', () async {
    await start();
    cloud['1.yaml'] = bytes('b');
    duringValidation = () async {
      await local.writeAsString('c');
    };
    await sync.sync();
    expect(await local.readAsString(), 'c');
    duringValidation = null;
    await sync.sync();
    expect(sync.conflicts, contains('1.yaml'));
  });

  test(
    'stopping during validation prevents import callbacks and writes',
    () async {
      await start();
      cloud['1.yaml'] = bytes('b');
      duringValidation = () async {
        sync.stop();
      };
      await sync.sync();
      expect(await local.readAsString(), 'a');
      expect(profiles.single.lastUpdateDate, isNull);
    },
  );

  test(
    'cloud deletion removes the local profile and survives restart',
    () async {
      await start();
      cloud.clear();
      await sync.sync();
      expect(profiles, isEmpty);
      expect(await local.exists(), isFalse);
      expect(sync.missing, isEmpty);
      expect(sync.error, isNull);
      sync.dispose();
      sync = ICloudYamlSync();
      await start();
      expect(profiles, isEmpty);
      expect(cloud, isEmpty);
      expect(sync.missing, isEmpty);
      expect(
        (await SharedPreferences.getInstance()).getString('icloudYamlSync'),
        isNot(contains('1.yaml')),
      );
    },
  );

  test('disabling leaves both sides untouched', () async {
    await start();
    await sync.disable();
    expect(sync.folder, isNull);
    await local.writeAsString('b');
    await sync.sync();
    expect(cloud['1.yaml'], bytes('a'));
    expect(await local.readAsString(), 'b');
  });

  test('cloud deletion removes only the mapped imported profile', () async {
    cloud['from-other-mac.yaml'] = bytes('remote');
    await start();
    final imported = profiles.singleWhere((profile) => profile.id != 1);
    final importedFile = File(
      await appPath.getProfilePath(imported.id.toString()),
    );
    sync.dispose();
    sync = ICloudYamlSync();
    cloud.remove('from-other-mac.yaml');
    await start();
    expect(profiles.single.id, 1);
    expect(await importedFile.exists(), isFalse);
    expect(await local.readAsString(), 'a');
    expect(cloud.keys, ['1.yaml']);
    expect(sync.missing, isEmpty);
    expect(sync.error, isNull);
  });

  test('an unavailable folder is not a cloud deletion', () async {
    await start();
    cloud.clear();
    failList = true;
    await sync.sync();
    expect(profiles.single.id, 1);
    expect(await local.readAsString(), 'a');
    expect(sync.error, isNotNull);
  });

  test('an evicted cloud file keeps the local profile', () async {
    await start();
    cloud.clear();
    placeholders.add('1.yaml');
    await sync.sync();
    expect(profiles.single.id, 1);
    expect(await local.readAsString(), 'a');
    expect(sync.error, isNotNull);
    placeholders.clear();
    cloud['1.yaml'] = bytes('b');
    await sync.sync();
    expect(await local.readAsString(), 'b');
    expect(sync.error, isNull);
  });

  test('a failed local deletion can be retried after restart', () async {
    await start();
    cloud.clear();
    failRemove = true;
    await sync.sync();
    expect(profiles.single.id, 1);
    expect(await local.readAsString(), 'a');
    expect(sync.error, isNotNull);
    sync.dispose();
    sync = ICloudYamlSync();
    failRemove = false;
    await start();
    expect(profiles, isEmpty);
    expect(await local.exists(), isFalse);
    expect(cloud, isEmpty);
    expect(sync.error, isNull);
  });

  test('cloud deletion clears a pending content conflict', () async {
    await start();
    await local.writeAsString('b');
    cloud['1.yaml'] = bytes('c');
    await sync.sync();
    expect(sync.conflicts, contains('1.yaml'));
    cloud.clear();
    await sync.sync(resolve: sync.conflicts['1.yaml'], useLocal: true);
    expect(profiles, isEmpty);
    expect(await local.exists(), isFalse);
    expect(sync.conflicts, isEmpty);
    expect(cloud, isEmpty);
  });

  test('local deletion does not delete the cloud file', () async {
    await start();
    profiles.clear();
    await local.delete();
    await sync.sync();
    expect(profiles, isEmpty);
    expect(cloud['1.yaml'], bytes('a'));
    expect(sync.missing, contains('1.yaml'));
  });
}
