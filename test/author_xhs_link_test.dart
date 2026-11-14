import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:huakeng/data/author_link.dart';

const _uid = '5f1234567890abcdef123456';
const _nid = '6a0000000000000000000001';

String _page(Map<String, dynamic> state) =>
    '<html><script>window.__INITIAL_STATE__='
    '${jsonEncode(state).replaceAll('"__U__"', 'undefined')}</script></html>';

/// 小紅書：App 分享的筆記短連結 → 轉址到筆記 → 讀作者（D-156 補）。
void main() {
  test('解析：短連結、筆記網址、整段分享文字', () {
    expect(
      parseLinkInput(LinkPlatform.xhs, 'http://xhslink.com/o/FsNEcTUT8D'),
      'http://xhslink.com/o/FsNEcTUT8D',
    );
    expect(
      parseLinkInput(
        LinkPlatform.xhs,
        '88 便裝汀發布了一篇小紅書筆記，快來看吧！ 😆 xhslink.com/a/AbC123，複製本條信息',
      ),
      'https://xhslink.com/a/AbC123',
    );
    expect(
      parseLinkInput(
        LinkPlatform.xhs,
        'https://www.xiaohongshu.com/discovery/item/$_nid?xsec_token=x',
      ),
      'https://www.xiaohongshu.com/discovery/item/$_nid?xsec_token=x',
    );
  });

  final note = _page({
    'note': {
      'noteDetailMap': {
        _nid: {
          'note': {
            'user': {
              'userId': _uid,
              'nickname': '便裝汀',
              'avatar': 'https://a/1.jpg',
            },
            'x': '__U__',
          },
        },
      },
    },
  });

  MockClient client({required bool profileOk}) => MockClient((r) async {
    if (r.url.host == 'xhslink.com') {
      return http.Response(
        '',
        302,
        headers: {
          'location':
              'https://www.xiaohongshu.com/discovery/item/$_nid?xsec_token=t',
        },
      );
    }
    if (r.url.path.startsWith('/discovery/item/')) {
      return http.Response.bytes(utf8.encode(note), 200);
    }
    if (r.url.path == '/user/profile/$_uid') {
      if (!profileOk) return http.Response('', 302);
      return http.Response.bytes(
        utf8.encode(
          _page({
            'user': {
              'userPageData': {
                'basicInfo': {
                  'nickname': '便裝汀',
                  'redId': '95270001',
                  'imageb': 'https://a/b.jpg',
                },
              },
            },
          }),
        ),
        200,
      );
    }
    return http.Response('', 404);
  });

  test('短連結 → 筆記 → 個人頁：拿到小紅書號、大頭像', () async {
    final p = await HttpAuthorLinkService(client(profileOk: true))
        .lookup(LinkPlatform.xhs, 'http://xhslink.com/o/FsNEcTUT8D');
    expect(p.userId, _uid);
    expect(p.name, '便裝汀');
    expect(p.handle, '95270001');
    expect(p.avatarUrl, 'https://a/b.jpg');
  });

  test('個人頁被擋：用筆記上的作者資料', () async {
    final p = await HttpAuthorLinkService(client(profileOk: false))
        .lookup(LinkPlatform.xhs, 'http://xhslink.com/o/FsNEcTUT8D');
    expect(p.userId, _uid);
    expect(p.name, '便裝汀');
    expect(p.avatarUrl, 'https://a/1.jpg');
  });
}
