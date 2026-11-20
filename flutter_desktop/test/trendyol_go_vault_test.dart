import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nohut_falafel_desktop/trendyol_go_readonly.dart';

void main() {
  test('Windows vault encrypts, reloads and replaces integration credentials', () async {
    final folder = await Directory.systemTemp.createTemp('nohut-vault-test-');
    addTearDown(() => folder.delete(recursive: true));
    final file = File('${folder.path}/credentials.dpapi');
    final vault = TgoWindowsVault(folder.path, credentialFile: file);
    expect(await vault.load(), isNull);
    await vault.save(const TgoCredentials('1', 'test-key-a', 'test-secret-a', 'test@example.com'));
    final saved = await file.readAsString();
    expect(saved, isNot(contains('test-secret-a')));
    expect((await vault.load())?.apiSecret, 'test-secret-a');
    await vault.save(const TgoCredentials('1', 'test-key-b', 'test-secret-b', 'test@example.com'));
    expect((await vault.load())?.apiKey, 'test-key-b');
    expect((await vault.load())?.apiSecret, 'test-secret-b');
  }, skip: !Platform.isWindows);
}
