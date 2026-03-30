# VRT Harness — mbt-blockly 用ガイド

## 目的

このプロジェクト (mbt-blockly) は VRT ハーネス (mizchi/vrt-harness) のベンチマーク対象。
UI の変更を行ったら、VRT で品質を検証する。

## セットアップ

vrt-harness は ~/ghq/github.com/mizchi/vrt-harness にある。

```bash
# mbt-blockly の dev server を起動
cd ~/ghq/github.com/mizchi/mbt-blockly && pnpm dev

# vrt-harness からキャプチャ
cd ~/ghq/github.com/mizchi/vrt-harness
VRT_BASE_URL=http://localhost:5173 npx tsx src/vrt-cli.ts init
VRT_BASE_URL=http://localhost:5173 npx tsx src/vrt-cli.ts capture
VRT_BASE_URL=http://localhost:5173 npx tsx src/vrt-cli.ts verify
```

## UI 変更時のワークフロー

1. コード変更前: `vrt init` でベースライン作成
2. コード変更後: `vrt capture` → `vrt expect` → `vrt verify`
3. FAIL なら修正して繰り返す
4. PASS なら `vrt approve`

## 評価観点

- **Visual**: ブロックの重なり、はみ出し、読みやすさ
- **A11y**: SVG の aria-label, role 属性 (将来)
- **Reasoning**: 変更意図と実際の視覚変化の一致
- **Score**: usability / practicality / fixSteps / finalQuality

## この UI の特徴

- SVG ベースの Blockly スタイルブロック
- Statement ブロック (notch 接続) と Expression ブロック (pill 形)
- 再帰的な measure → render の 2 パスレイアウト
- kitty graphics protocol で TUI 表示も可能
