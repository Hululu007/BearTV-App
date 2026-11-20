import 'dart:convert';

import 'package:bear_tv/data/danmaku/danmaku_client.dart';
import 'package:bear_tv/data/danmaku/danmaku_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fetchComments decodes, parses and sorts in compute', () async {
    final client = DanmakuClient(
        client: MockClient((_) async => http.Response.bytes(utf8.encode('''
<i><d p="3,5,25,16711680">中文 &amp; 弹幕</d>
<d p="1,1,25,16777215">first</d></i>
'''), 200)));
    final result = await client.fetchComments(
        const DanmakuHost(baseUrl: 'https://example.test', token: 'test'), 1);
    expect(result.map((e) => e.time), [1, 3]);
    expect(result.last.text, '中文 & 弹幕');
    expect(result.last.mode, 1);
    expect(result.last.color, 0xFF0000);
    client.close();
  });
}
