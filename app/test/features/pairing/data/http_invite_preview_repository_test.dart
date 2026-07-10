import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/config/app_config.dart';
import 'package:hayati_app/features/pairing/data/http_invite_preview_repository.dart';
import 'package:hayati_app/features/pairing/domain/invite_exception.dart';
import 'package:hayati_app/features/pairing/domain/invite_preview.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final base = Uri.parse(
    'https://europe-west1-hayatiapp-dev.cloudfunctions.net/invitePreview',
  );

  HttpInvitePreviewRepository repoOn(MockClient client) =>
      HttpInvitePreviewRepository(client: client, baseUri: base);

  group('preview — 200 mapping', () {
    test('maps a valid body with a creator name', () async {
      final repo = repoOn(
        MockClient(
          (_) async => http.Response(
            jsonEncode({'status': 'valid', 'creatorDisplayName': 'Aylin'}),
            200,
          ),
        ),
      );

      expect(
        await repo.preview('ABCD2345'),
        const InvitePreviewResult(
          status: InvitePreviewStatus.valid,
          creatorDisplayName: 'Aylin',
        ),
      );
    });

    test('maps a valid body with no creator name', () async {
      final repo = repoOn(
        MockClient(
          (_) async => http.Response(jsonEncode({'status': 'valid'}), 200),
        ),
      );

      expect(
        await repo.preview('ABCD2345'),
        const InvitePreviewResult(status: InvitePreviewStatus.valid),
      );
    });

    test(
      'maps expired and unknown as successful results, not errors',
      () async {
        final expired = repoOn(
          MockClient(
            (_) async => http.Response(jsonEncode({'status': 'expired'}), 200),
          ),
        );
        final unknown = repoOn(
          MockClient(
            (_) async => http.Response(jsonEncode({'status': 'unknown'}), 200),
          ),
        );

        expect(
          (await expired.preview('ABCD2345')).status,
          InvitePreviewStatus.expired,
        );
        expect(
          (await unknown.preview('ABCD2345')).status,
          InvitePreviewStatus.unknown,
        );
      },
    );

    test(
      'an off-contract 200 body becomes a malformed-preview unknown',
      () async {
        final badJson = repoOn(
          MockClient((_) async => http.Response('not json', 200)),
        );
        final badStatus = repoOn(
          MockClient(
            (_) async => http.Response(jsonEncode({'status': 'weird'}), 200),
          ),
        );
        final badName = repoOn(
          MockClient(
            (_) async => http.Response(
              jsonEncode({'status': 'valid', 'creatorDisplayName': 7}),
              200,
            ),
          ),
        );

        for (final repo in [badJson, badStatus, badName]) {
          await expectLater(
            repo.preview('ABCD2345'),
            throwsA(
              isA<InviteUnknownException>().having(
                (e) => e.code,
                'code',
                'malformed-preview',
              ),
            ),
          );
        }
      },
    );
  });

  group('preview — transport mapping', () {
    test('429 and 5xx are network failures (retry is honest)', () async {
      for (final status in [429, 500, 503]) {
        final repo = repoOn(MockClient((_) async => http.Response('', status)));
        await expectLater(
          repo.preview('ABCD2345'),
          throwsA(isA<InviteNetworkException>()),
        );
      }
    });

    test('other 4xx keep their raw status under the generic surface', () async {
      final repo = repoOn(MockClient((_) async => http.Response('', 404)));
      await expectLater(
        repo.preview('ABCD2345'),
        throwsA(
          isA<InviteUnknownException>().having(
            (e) => e.code,
            'code',
            'http-404',
          ),
        ),
      );
    });

    test('a socket / client exception is a network failure', () async {
      final socket = repoOn(
        MockClient((_) async => throw const SocketException('down')),
      );
      final client = repoOn(
        MockClient((_) async => throw http.ClientException('boom')),
      );

      await expectLater(
        socket.preview('ABCD2345'),
        throwsA(isA<InviteNetworkException>()),
      );
      await expectLater(
        client.preview('ABCD2345'),
        throwsA(isA<InviteNetworkException>()),
      );
    });

    test('forwards the code as the ?code= query parameter', () async {
      late Uri requested;
      final repo = repoOn(
        MockClient((request) async {
          requested = request.url;
          return http.Response(jsonEncode({'status': 'valid'}), 200);
        }),
      );

      await repo.preview('WXYZ6789');

      expect(requested.queryParameters['code'], 'WXYZ6789');
      expect(requested.path, base.path);
    });
  });

  group('invitePreviewResultFromBody', () {
    test('parses each status', () {
      expect(
        invitePreviewResultFromBody(jsonEncode({'status': 'valid'})).status,
        InvitePreviewStatus.valid,
      );
      expect(
        invitePreviewResultFromBody(jsonEncode({'status': 'expired'})).status,
        InvitePreviewStatus.expired,
      );
      expect(
        invitePreviewResultFromBody(jsonEncode({'status': 'unknown'})).status,
        InvitePreviewStatus.unknown,
      );
    });

    test('throws FormatException on an off-contract shape', () {
      expect(() => invitePreviewResultFromBody('['), throwsFormatException);
      expect(() => invitePreviewResultFromBody('42'), throwsFormatException);
      expect(
        () => invitePreviewResultFromBody(jsonEncode({'status': 'nope'})),
        throwsFormatException,
      );
      expect(
        () => invitePreviewResultFromBody(
          jsonEncode({'status': 'valid', 'creatorDisplayName': 1}),
        ),
        throwsFormatException,
      );
    });
  });

  group('invitePreviewUri', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('emulator branch routes through demo-hayati by URL path', () {
      final uri = invitePreviewUri(
        flavor: AppFlavor.dev,
        useEmulator: true,
        emulatorHost: '127.0.0.1',
        emulatorPort: 5001,
      );

      expect(
        uri.toString(),
        'http://127.0.0.1:5001/demo-hayati/europe-west1/invitePreview',
      );
    });

    test('emulator branch honours a device host override', () {
      final uri = invitePreviewUri(
        flavor: AppFlavor.prod,
        useEmulator: true,
        emulatorHost: '192.168.1.20',
        emulatorPort: 5005,
      );

      expect(
        uri.toString(),
        'http://192.168.1.20:5005/demo-hayati/europe-west1/invitePreview',
      );
    });

    test('production branch targets the flavor project in europe-west1', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      expect(
        invitePreviewUri(flavor: AppFlavor.dev, useEmulator: false).toString(),
        'https://europe-west1-hayatiapp-dev.cloudfunctions.net/invitePreview',
      );
      expect(
        invitePreviewUri(flavor: AppFlavor.prod, useEmulator: false).toString(),
        'https://europe-west1-hayatiapp-prod.cloudfunctions.net/invitePreview',
      );
    });
  });
}
