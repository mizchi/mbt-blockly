///| ブロックの SVG レンダリング
///
/// Blockly スタイル:
/// - Statement ブロック: 上に凸 (top connector)、下に凹 (bottom socket)
/// - Expression ブロック: 左に凸 (output connector)、楕円形
/// - 入力スロット: ブロック内の凹み (子ブロックが嵌まる)

/// ブロック描画の定数
let block_width : Double = 200.0

let block_header_height : Double = 32.0

let slot_height : Double = 28.0

let notch_width : Double = 20.0

let notch_height : Double = 4.0

let corner_radius : Double = 4.0

/// HSL hue からブロック色を生成
fn hue_to_color(hue : Int) -> String {
  "hsl(" + hue.to_string() + ", 60%, 50%)"
}

fn hue_to_dark(hue : Int) -> String {
  "hsl(" + hue.to_string() + ", 60%, 35%)"
}

/// Statement ブロックの SVG path を生成
/// 上に凸 notch、下に凹 notch のブロック形状
fn statement_block_path(
  width : Double,
  height : Double,
  has_next : Bool,
  num_slots : Int,
) -> String {
  let r = corner_radius
  let nw = notch_width
  let nh = notch_height

  // 上辺: 左上 → notch (凸) → 右上
  let mut d = "M " +
    r.to_string() +
    " 0" +
    " L " +
    (nw - 4.0).to_string() +
    " 0" +
    " L " +
    nw.to_string() +
    " " +
    (-nh).to_string() +
    " L " +
    (nw + 12.0).to_string() +
    " " +
    (-nh).to_string() +
    " L " +
    (nw + 16.0).to_string() +
    " 0" +
    " L " +
    (width - r).to_string() +
    " 0"

  // 右辺
  d += " Q " +
    width.to_string() +
    " 0 " +
    width.to_string() +
    " " +
    r.to_string() +
    " L " +
    width.to_string() +
    " " +
    (height - r).to_string()

  // 下辺: has_next なら凹 notch
  if has_next {
    d += " Q " +
      width.to_string() +
      " " +
      height.to_string() +
      " " +
      (width - r).to_string() +
      " " +
      height.to_string() +
      " L " +
      (nw + 16.0).to_string() +
      " " +
      height.to_string() +
      " L " +
      (nw + 12.0).to_string() +
      " " +
      (height + nh).to_string() +
      " L " +
      nw.to_string() +
      " " +
      (height + nh).to_string() +
      " L " +
      (nw - 4.0).to_string() +
      " " +
      height.to_string() +
      " L " +
      r.to_string() +
      " " +
      height.to_string()
  } else {
    d += " Q " +
      width.to_string() +
      " " +
      height.to_string() +
      " " +
      (width - r).to_string() +
      " " +
      height.to_string() +
      " L " +
      r.to_string() +
      " " +
      height.to_string()
  }

  // 左辺 (スロットの凹みは別途描画)
  d += " Q 0 " +
    height.to_string() +
    " 0 " +
    (height - r).to_string() +
    " L 0 " +
    r.to_string() +
    " Q 0 0 " +
    r.to_string() +
    " 0 Z"
  ignore(num_slots)
  d
}

/// Expression ブロック (楕円 / 丸みを帯びた形)
fn expression_block_path(width : Double, height : Double) -> String {
  let r = height / 2.0
  "M " +
  r.to_string() +
  " 0" +
  " L " +
  (width - r).to_string() +
  " 0" +
  " A " +
  r.to_string() +
  " " +
  r.to_string() +
  " 0 0 1 " +
  (width - r).to_string() +
  " " +
  height.to_string() +
  " L " +
  r.to_string() +
  " " +
  height.to_string() +
  " A " +
  r.to_string() +
  " " +
  r.to_string() +
  " 0 0 1 " +
  r.to_string() +
  " 0 Z"
}

/// ブロック1個の SVG 要素を生成
pub fn render_block(
  block : @model.BlockInstance,
  workspace : @model.Workspace,
) -> @luna.Node[Unit, String] {
  let num_inputs = block.inputs.length()
  let base_height = block_header_height + num_inputs.to_double() * slot_height
  let height = if num_inputs > 0 { base_height } else { block_header_height }
  let width = block_width
  let color = hue_to_color(block.color_hue)
  let dark_color = hue_to_dark(block.color_hue)

  let path_d = match block.connector {
    @model.Statement =>
      statement_block_path(width, height, block.has_next, num_inputs)
    @model.Expression => expression_block_path(width, height)
  }

  let children : Array[@luna.Node[Unit, String]] = []

  // ブロック本体
  children.push(
    @svg.path(
      [
        ("d", @luna.attr_static(path_d)),
        ("fill", @luna.attr_static(color)),
        ("stroke", @luna.attr_static(dark_color)),
        ("stroke-width", @luna.attr_static("1.5")),
      ],
      [],
    ),
  )

  // ラベル
  children.push(
    @svg.text(
      [
        ("x", @luna.attr_static("12")),
        ("y", @luna.attr_static("20")),
        ("fill", @luna.attr_static("white")),
        ("font-size", @luna.attr_static("13")),
        ("font-family", @luna.attr_static("monospace")),
        ("font-weight", @luna.attr_static("bold")),
      ],
      [@luna.text(block.label)],
    ),
  )

  // 値表示 (number_lit, string_lit 等)
  if block.value.length() > 0 {
    children.push(
      @svg.text(
        [
          ("x", @luna.attr_static("100")),
          ("y", @luna.attr_static("20")),
          ("fill", @luna.attr_static("white")),
          ("font-size", @luna.attr_static("13")),
          ("font-family", @luna.attr_static("monospace")),
        ],
        [@luna.text(block.value)],
      ),
    )
  }

  // 入力スロット
  for i, slot in block.inputs {
    let slot_y = block_header_height + i.to_double() * slot_height
    children.push(
      @svg.text(
        [
          ("x", @luna.attr_static("16")),
          (
            "y",
            @luna.attr_static((slot_y + slot_height * 0.7).to_string()),
          ),
          ("fill", @luna.attr_static("rgba(255,255,255,0.7)")),
          ("font-size", @luna.attr_static("11")),
          ("font-family", @luna.attr_static("monospace")),
        ],
        [@luna.text(slot.name)],
      ),
    )

    // スロットの子ブロックを再帰描画
    match slot.child_id {
      Some(cid) =>
        match workspace.blocks[cid] {
          Some(child) => {
            let child_x = 80.0
            let child_y = slot_y + 2.0
            children.push(
              @svg.g(
                [
                  (
                    "transform",
                    @luna.attr_static(
                      "translate(" +
                      child_x.to_string() +
                      "," +
                      child_y.to_string() +
                      ")",
                    ),
                  ),
                ],
                [render_block(child, workspace)],
              ),
            )
          }
          None => ()
        }
      None => {
        // 空スロット (凹み表示)
        let sx = 80.0
        let sy = slot_y + 4.0
        let sw = 100.0
        let sh = 20.0
        children.push(
          @svg.rect(
            [
              ("x", @luna.attr_static(sx.to_string())),
              ("y", @luna.attr_static(sy.to_string())),
              ("width", @luna.attr_static(sw.to_string())),
              ("height", @luna.attr_static(sh.to_string())),
              ("rx", @luna.attr_static("10")),
              ("fill", @luna.attr_static("rgba(0,0,0,0.15)")),
              ("stroke", @luna.attr_static("rgba(0,0,0,0.3)")),
              ("stroke-width", @luna.attr_static("1")),
              ("stroke-dasharray", @luna.attr_static("4 2")),
            ],
            [],
          ),
        )
      }
    }
  }

  // next ブロックの再帰描画
  match block.next_id {
    Some(nid) =>
      match workspace.blocks[nid] {
        Some(next) =>
          children.push(
            @svg.g(
              [
                (
                  "transform",
                  @luna.attr_static(
                    "translate(0," + (height + notch_height).to_string() + ")",
                  ),
                ),
              ],
              [render_block(next, workspace)],
            ),
          )
        None => ()
      }
    None => ()
  }

  @svg.g(
    [
      (
        "transform",
        @luna.attr_static(
          "translate(" +
          block.x.to_string() +
          "," +
          block.y.to_string() +
          ")",
        ),
      ),
    ],
    children,
  )
}
