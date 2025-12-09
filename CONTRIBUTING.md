# 開発ガイド (Development Guide)

VoiceInput プロジェクトへの貢献に興味を持っていただきありがとうございます！
プルリクエストを送る前に、以下のガイドラインをご一読ください。

## 開発フロー

### ブランチの命名規則

ブランチ名は、変更の種類とその内容がわかるように、以下の形式で命名してください。

`prefix/branch-name`

推奨される Prefix:
- `feature/`: 新機能の追加 (例: `feature/add-settings-ui`)
- `fix/`: バグ修正 (例: `fix/audio-capture-error`)
- `docs/`: ドキュメントの変更 (例: `docs/update-readme`)
- `refactor/`: リファクタリング (例: `refactor/whisper-service`)
- `test/`: テストの追加・修正 (例: `test/add-unit-tests`)
- `chore/`: ビルド設定やツールの更新など (例: `chore/update-dependencies`)

### コミットメッセージ

コミットメッセージは明確かつ簡潔に記述してください。可能であれば [Conventional Commits](https://www.conventionalcommits.org/ja/v1.0.0/) に従うことを推奨します。

## コード品質とテスト

プルリクエストを作成する前に、以下のコマンドを実行してコードの品質を確認してください。

### Lint (静的解析)

Flutter 標準の linter を使用しています。

```bash
flutter analyze
```

コードフォーマットも確認してください。

```bash
dart format .
```

### テスト

単体テストおよびウィジェットテストを実行し、すべてのテストが通過することを確認してください。

```bash
flutter test
```

## リリースプロセス

本プロジェクトでは GitHub Actions を使用してリリースプロセスを自動化しています（予定）。

1.  `main` ブランチへのマージ後、バージョンタグ (例: `v1.0.0`) を push します。
2.  GitHub Actions がトリガーされ、ビルドとテストが実行されます。
3.  成功すると、GitHub Releases にアーティファクトとともにリリースノートが作成されます。

バージョン番号は [Semantic Versioning](https://semver.org/) に従ってください。
