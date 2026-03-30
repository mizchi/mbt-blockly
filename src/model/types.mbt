///| Blockly-style block types for MoonBit AST
///
/// Blockly の接続モデル:
/// - top/bottom: 上下にスタック接続 (statement ブロック)
/// - left: 左に値接続 (expression ブロック → 親の入力スロットに嵌まる)
/// - inputs: 入力スロット (子ブロックを受け入れる穴)

/// ブロックの接続タイプ
pub enum ConnectorType {
  /// 文 (statement): 上下にスタック接続
  Statement
  /// 式 (expression): 左に値接続 (親のスロットに嵌まる)
  Expression
}

/// 入力スロットの定義
pub struct InputSlot {
  /// スロット名 (e.g., "condition", "body", "value")
  name : String
  /// 受け入れる接続タイプ
  accepts : ConnectorType
  /// 嵌められているブロック ID (None = 空)
  mut child_id : String?
} derive(Show)

/// ブロック定義 (テンプレート)
pub struct BlockDef {
  type_id : String
  /// 表示名
  label : String
  /// ブロックの色 (HSL hue)
  color_hue : Int
  /// 接続タイプ
  connector : ConnectorType
  /// 入力スロット
  inputs : Array[InputSlot]
  /// bottom 接続を持つか (statement のみ)
  has_next : Bool
} derive(Show)

/// ブロックインスタンス (エディタ上の具体的なブロック)
pub struct BlockInstance {
  id : String
  type_id : String
  label : String
  color_hue : Int
  connector : ConnectorType
  inputs : Array[InputSlot]
  has_next : Bool
  /// 次のブロック (bottom 接続先)
  mut next_id : String?
  /// 位置 (トップレベルブロックの場合のみ意味がある)
  mut x : Double
  mut y : Double
  /// 値 (const ブロック用)
  mut value : String
} derive(Show)

/// ワークスペース全体
pub struct Workspace {
  blocks : Map[String, BlockInstance]
  mut next_id_counter : Int
} derive(Show)

/// ブロックの描画に必要なレイアウト情報
pub struct BlockLayout {
  id : String
  x : Double
  y : Double
  width : Double
  height : Double
  /// 各入力スロットの Y オフセット
  input_offsets : Array[Double]
  /// next ブロックの Y オフセット
  next_y_offset : Double
}
