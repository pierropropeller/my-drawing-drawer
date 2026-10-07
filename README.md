# 畫坑

自用、非社交的同人創作管理 App（Flutter，Android 先行）。完整需求見 [docs/HANDOFF.md](docs/HANDOFF.md)。

## 開發

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # drift 產生 database.g.dart
flutter analyze && flutter test
```

`pubspec.yaml` 內把 `analyzer` 釘在 14.4.0（`dependency_overrides`），因為 build_runner 2.16.1 與 analyzer 14.5.0 不相容；上游修好後可移除。`database.g.dart` 已提交，一般情況不必重新產生。

## 下載 APK

每次 push 會由 GitHub Actions 出 debug APK，發佈在 [Releases](../../releases)（`debug-build-N`）。

## 進度

- [x] 1. 專案骨架、淺／深主題 tokens、底部導覽、drift schema
- [ ] 2. 坑：主頁、開新坑、坑內頁、編輯坑
- [ ] 3. 官方圖冊、同人圖
- [ ] 4. 腦洞、草稿、成圖、連接關係、tag 管理
- [ ] 5. Google 登入與 Drive 同步
- [ ] 6. 目標與年度回顧
- [ ] 7. 空白狀態、snackbar、iPad 版面
