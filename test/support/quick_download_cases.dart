import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/gallery.dart';
import 'package:jhentai/src/model/gallery_image.dart';
import 'package:jhentai/src/model/gallery_url.dart';
import 'package:jhentai/src/pages/base/base_page_logic.dart';
import 'package:jhentai/src/pages/base/base_page_state.dart';
import 'package:jhentai/src/service/gallery_download/gallery_download_service.dart';
import 'package:jhentai/src/service/read_progress_service.dart';
import 'package:jhentai/src/service/path_service.dart';
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:jhentai/src/widget/eh_gallery_list_card_.dart';
import 'package:jhentai/src/widget/eh_gallery_waterflow_card.dart';
import 'package:jhentai/src/widget/eh_quick_download_button.dart';

/// 使用真实卡片和快捷下载逻辑验证 [testWidgets] 提供的运行环境。
void runQuickDownloadCases() {
  for (final mode in [ListMode.listWithoutTags, ListMode.waterfallFlowMedium, ListMode.waterfallFlowBig]) {
    testWidgets('快捷下载 ${mode.name}：边缘点击、请求参数和重复下载', (tester) async {
      final previousService = galleryDownloadService;
      final previousProgress = readProgressService;
      final previousPathService = pathService;
      final fixtureDir = Directory.systemTemp.createTempSync('jhentai-cover-');
      File('${fixtureDir.path}/cover.png').writeAsBytesSync(base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAAEElEQVR4nGJasGoLIAAA//8D9AIBwF9+TQAAAABJRU5ErkJggg==',
      ));
      pathService = PathService()..appDocDir = fixtureDir;
      final previousGroup = downloadSetting.defaultGalleryGroup.value;
      final service = _RecordingDownloadService();
      galleryDownloadService = service;
      Get.put<GalleryDownloadService>(service);
      readProgressService = _EmptyReadProgressService();
      Get.put<ReadProgressService>(readProgressService);
      downloadSetting.defaultGalleryGroup.value = '测试分组';
      addTearDown(() async {
        await Get.delete<GalleryDownloadService>(force: true);
        await Get.delete<ReadProgressService>(force: true);
        galleryDownloadService = previousService;
        readProgressService = previousProgress;
        pathService = previousPathService;
        fixtureDir.deleteSync(recursive: true);
        downloadSetting.defaultGalleryGroup.value = previousGroup;
      });

      final gallery = _fixtureGallery();
      final logic = _FixturePageLogic();
      var details = 0;
      final card = mode == ListMode.listWithoutTags
          ? EHGalleryListCard(
              gallery: gallery,
              downloaded: false,
              listMode: mode,
              withTags: false,
              handleTapCard: (_) => details++,
              handleTapDownload: logic.handleQuickDownload,
            )
          : EHGalleryWaterFlowCard(
              gallery: gallery,
              downloaded: false,
              listMode: mode,
              handleTapCard: (_) => details++,
              handleTapDownload: logic.handleQuickDownload,
            );
      await tester.pumpWidget(GetMaterialApp(
          home: Scaffold(
        body: Center(child: SizedBox(width: mode == ListMode.listWithoutTags ? 360 : 220, child: card)),
      )));
      await tester.pump(const Duration(milliseconds: 400));
      final button = find.byType(EHQuickDownloadButton);
      expect(button, findsOneWidget);
      final bounds = tester.getRect(button);
      expect(bounds.width, greaterThanOrEqualTo(48));
      expect(bounds.height, greaterThanOrEqualTo(48));
      await tester.tapAt(bounds.topLeft + const Offset(2, 2));
      await tester.pump();
      expect(details, 0);
      expect(service.requests, hasLength(1));
      expect(service.requests.single.group, '测试分组');
      expect(service.requests.single.downloadOriginalImage, false);
      expect(service.requests.single.gid, gallery.gid);
      expect(button, findsNothing);
      logic.handleQuickDownload(gallery);
      expect(service.requests, hasLength(1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('快捷下载缺少页数时不提交，未设置分组时使用default', (tester) async {
    final previousService = galleryDownloadService;
    final previousGroup = downloadSetting.defaultGalleryGroup.value;
    final service = _RecordingDownloadService();
    galleryDownloadService = service;
    downloadSetting.defaultGalleryGroup.value = null;
    addTearDown(() {
      galleryDownloadService = previousService;
      downloadSetting.defaultGalleryGroup.value = previousGroup;
    });
    final logic = _FixturePageLogic();
    final gallery = _fixtureGallery()..pageCount = null;
    logic.handleQuickDownload(gallery);
    expect(service.requests, isEmpty);
    gallery.pageCount = 12;
    logic.handleQuickDownload(gallery);
    expect(service.requests.single.group, 'default');
  });
}

/// 提供不涉及真实内容或账号的画廊。
Gallery _fixtureGallery() => Gallery(
      galleryUrl: GalleryUrl.parse('https://e-hentai.org/g/123456/0123456789/'),
      title: '快捷下载验证',
      category: 'Manga',
      cover: GalleryImage(url: 'fixture://cover', path: 'cover.png', width: 150, height: 200),
      pageCount: 12,
      rating: 4,
      hasRated: false,
      publishTime: '2026-10-17 02:09',
      isExpunged: false,
      tags: LinkedHashMap(),
    );

/// 记录应用传给新版下载引擎的请求，避免测试访问真实画廊。
class _RecordingDownloadService extends GalleryDownloadService {
  final List<GalleryDownloadRequest> requests = [];

  /// 判断 [gid] 是否已经在本次请求中。
  @override
  bool containGallery(int gid) => requests.any((request) => request.gid == gid);

  /// 记录 [request] 并通知卡片刷新下载状态。
  @override
  Future<void> downloadGallery(GalleryDownloadRequest request) async {
    requests.add(request);
    update(['$galleryDownloadProgressId::${request.gid}']);
  }
}

/// 只实例化快捷下载所需页面逻辑，不启动页面请求。
class _FixturePageLogic extends BasePageLogic {
  /// 持有不发送网络请求的页面状态。
  @override
  final BasePageState state = _FixturePageState();

  /// 测试不加载持久化搜索配置。
  @override
  bool get useSearchConfig => false;
}

/// 为测试提供独立页面状态。
class _FixturePageState extends BasePageState {
  /// 使用独立的测试路由。
  @override
  String get route => '/quick-download-test';
}

/// 不依赖应用数据库的未读状态。
class _EmptyReadProgressService extends ReadProgressService {
  /// 返回 [gid] 对应画廊的未读状态。
  @override
  Future<int> getReadProgress(int gid) async => 0;
}
