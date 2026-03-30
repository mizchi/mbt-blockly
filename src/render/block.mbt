///| ブロックの SVG レンダリング (2パス: measure → render)

let min_block_width : Double = 140.0

let block_header_height : Double = 32.0

let slot_height : Double = 32.0

let slot_indent : Double = 70.0

let empty_slot_width : Double = 80.0

let empty_slot_height : Double = 24.0

let notch_height : Double = 4.0

let corner_radius : Double = 4.0

let expr_min_width : Double = 80.0

let expr_height : Double = 28.0

///|
fn hue_to_color(hue : Int) -> String {
  "hsl(" + hue.to_string() + ", 60%, 50%)"
}

///|
fn hue_to_dark(hue : Int) -> String {
  "hsl(" + hue.to_string() + ", 60%, 35%)"
}

// ---- Pass 1: Measure ----

///| ブロックのサイズを再帰的に計測
pub struct BlockSize {
  width : Double
  height : Double
  /// 各スロットの (y_offset, child_height)
  slot_layouts : Array[(Double, Double)]
  /// next chain の合計高さ
  next_chain_height : Double
}

///|
pub fn measure_block(
  block : @model.BlockInstance,
  workspace : @model.Workspace,
) -> BlockSize {
  match block.connector {
    @model.Expression => measure_expression(block, workspace)
    @model.Statement => measure_statement(block, workspace)
  }
}

///|
fn measure_expression(
  block : @model.BlockInstance,
  workspace : @model.Workspace,
) -> BlockSize {
  // Expression は横に並べる
  let mut width = expr_min_width
  // ラベルテキスト幅の概算 (monospace 13px ≈ 8px/char)
  let label_len = if block.value.length() > 0 {
    block.label.length() + 1 + block.value.length()
  } else {
    block.label.length()
  }
  let text_width = label_len.to_double() * 8.0 + 24.0

  // 子スロットがある場合 (binary_op 等) は子のサイズも考慮
  let slot_layouts : Array[(Double, Double)] = []
  if block.inputs.length() > 0 {
    // inline 子ブロックの幅を合算
    let mut children_width = text_width
    for slot in block.inputs {
      match slot.child_id {
        Some(cid) =>
          match workspace.blocks.get(cid) {
            Some(child) => {
              let child_size = measure_block(child, workspace)
              children_width = children_width + child_size.width + 4.0
              slot_layouts.push((0.0, child_size.height))
            }
            None => {
              children_width = children_width + empty_slot_width + 4.0
              slot_layouts.push((0.0, empty_slot_height))
            }
          }
        None => {
          children_width = children_width + empty_slot_width + 4.0
          slot_layouts.push((0.0, empty_slot_height))
        }
      }
    }
    width = @math.maximum(width, children_width)
  } else {
    width = @math.maximum(width, text_width)
  }

  {
    width,
    height: expr_height,
    slot_layouts,
    next_chain_height: 0.0,
  }
}

///|
fn measure_statement(
  block : @model.BlockInstance,
  workspace : @model.Workspace,
) -> BlockSize {
  let mut total_height = block_header_height
  let mut max_width = min_block_width
  let slot_layouts : Array[(Double, Double)] = []

  for slot in block.inputs {
    let slot_y = total_height
    match slot.child_id {
      Some(cid) =>
        match workspace.blocks.get(cid) {
          Some(child) => {
            let child_size = measure_block(child, workspace)
            let child_total = child_size.height + child_size.next_chain_height
            let row_height = @math.maximum(slot_height, child_total + 4.0)
            slot_layouts.push((slot_y, row_height))
            max_width = @math.maximum(
              max_width,
              slot_indent + child_size.width + 8.0,
            )
            total_height = total_height + row_height
          }
          None => {
            slot_layouts.push((slot_y, slot_height))
            total_height = total_height + slot_height
          }
        }
      None => {
        slot_layouts.push((slot_y, slot_height))
        total_height = total_height + slot_height
      }
    }
  }

  // next chain
  let mut next_chain = 0.0
  match block.next_id {
    Some(nid) =>
      match workspace.blocks.get(nid) {
        Some(next) => {
          let next_size = measure_block(next, workspace)
          next_chain = next_size.height +
            next_size.next_chain_height +
            notch_height
          max_width = @math.maximum(max_width, next_size.width)
        }
        None => ()
      }
    None => ()
  }

  { width: max_width, height: total_height, slot_layouts, next_chain_height: next_chain }
}

// ---- Pass 2: Render ----

///| Statement ブロックの SVG path
fn statement_path(width : Double, height : Double, has_next : Bool) -> String {
  let r = corner_radius
  let nw = 20.0
  let nh = notch_height
  let mut d = "M " +
    r.to_string() +
    " 0 L " +
    (nw - 4.0).to_string() +
    " 0 L " +
    nw.to_string() +
    " " +
    (-nh).to_string() +
    " L " +
    (nw + 12.0).to_string() +
    " " +
    (-nh).to_string() +
    " L " +
    (nw + 16.0).to_string() +
    " 0 L " +
    (width - r).to_string() +
    " 0"
  d = d +
    " Q " +
    width.to_string() +
    " 0 " +
    width.to_string() +
    " " +
    r.to_string() +
    " L " +
    width.to_string() +
    " " +
    (height - r).to_string()
  if has_next {
    d = d +
      " Q " +
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
      height.to_string()
  } else {
    d = d +
      " Q " +
      width.to_string() +
      " " +
      height.to_string() +
      " " +
      (width - r).to_string() +
      " " +
      height.to_string()
  }
  d +
  " L " +
  r.to_string() +
  " " +
  height.to_string() +
  " Q 0 " +
  height.to_string() +
  " 0 " +
  (height - r).to_string() +
  " L 0 " +
  r.to_string() +
  " Q 0 0 " +
  r.to_string() +
  " 0 Z"
}

///| Expression ブロック path
fn expression_path(width : Double, height : Double) -> String {
  let r = height / 2.0
  "M " +
  r.to_string() +
  " 0 L " +
  (width - r).to_string() +
  " 0 A " +
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

///| ブロックを描画 (measure 済みサイズを使用)
pub fn render_block(
  block : @model.BlockInstance,
  workspace : @model.Workspace,
) -> @element.DomNode {
  let size = measure_block(block, workspace)
  match block.connector {
    @model.Expression => render_expression(block, workspace, size)
    @model.Statement => render_statement(block, workspace, size)
  }
}

///|
fn render_expression(
  block : @model.BlockInstance,
  workspace : @model.Workspace,
  size : BlockSize,
) -> @element.DomNode {
  let color = hue_to_color(block.color_hue)
  let dark = hue_to_dark(block.color_hue)
  let children : Array[@element.DomNode] = []

  children.push(
    @element.svg_path(
      d=expression_path(size.width, expr_height),
      fill=color,
      stroke=dark,
      stroke_width="1.5",
    ),
  )

  let label_text = if block.value.length() > 0 {
    block.value
  } else {
    block.label
  }

  // 子なし expression: テキストのみ
  if block.inputs.is_empty() {
    children.push(
      @element.svg_text(
        x="16",
        y="18",
        fill="white",
        font_size="13",
        font_family="monospace",
        attrs=[("font-weight", @element.AttrString("bold"))],
        [@element.text(label_text)],
      ),
    )
  } else {
    // 子あり (binary_op 等): ラベル + 子ブロックを横に配置
    let mut cursor_x = 12.0
    // ラベルのパーツを split (例: "_ + _" → ["", "+", ""])
    children.push(
      @element.svg_text(
        x=cursor_x.to_string(),
        y="18",
        fill="white",
        font_size="13",
        font_family="monospace",
        attrs=[("font-weight", @element.AttrString("bold"))],
        [@element.text(label_text)],
      ),
    )
    cursor_x = cursor_x + label_text.length().to_double() * 8.0 + 8.0

    for slot in block.inputs {
      match slot.child_id {
        Some(cid) =>
          match workspace.blocks.get(cid) {
            Some(child) => {
              let child_size = measure_block(child, workspace)
              let cy = (expr_height - child_size.height) / 2.0
              children.push(
                @element.svg_g(
                  transform="translate(" +
                    cursor_x.to_string() +
                    "," +
                    cy.to_string() +
                    ")",
                  [render_block(child, workspace)],
                ),
              )
              cursor_x = cursor_x + child_size.width + 4.0
            }
            None => {
              children.push(
                @element.svg_rect(
                  x=cursor_x.to_string(),
                  y="4",
                  width=empty_slot_width.to_string(),
                  height="20",
                  rx="10",
                  fill="rgba(0,0,0,0.15)",
                  stroke="rgba(0,0,0,0.25)",
                  stroke_width="1",
                  attrs=[("stroke-dasharray", @element.AttrString("4 2"))],
                ),
              )
              cursor_x = cursor_x + empty_slot_width + 4.0
            }
          }
        None => {
          children.push(
            @element.svg_rect(
              x=cursor_x.to_string(),
              y="4",
              width=empty_slot_width.to_string(),
              height="20",
              rx="10",
              fill="rgba(0,0,0,0.15)",
              stroke="rgba(0,0,0,0.25)",
              stroke_width="1",
              attrs=[("stroke-dasharray", @element.AttrString("4 2"))],
            ),
          )
          cursor_x = cursor_x + empty_slot_width + 4.0
        }
      }
    }
  }

  @element.svg_g(
    transform="translate(" +
      block.x.to_string() +
      "," +
      block.y.to_string() +
      ")",
    children,
  )
}

///|
fn render_statement(
  block : @model.BlockInstance,
  workspace : @model.Workspace,
  size : BlockSize,
) -> @element.DomNode {
  let color = hue_to_color(block.color_hue)
  let dark = hue_to_dark(block.color_hue)
  let children : Array[@element.DomNode] = []

  children.push(
    @element.svg_path(
      d=statement_path(size.width, size.height, block.has_next),
      fill=color,
      stroke=dark,
      stroke_width="1.5",
    ),
  )

  // ヘッダラベル (Statement は label 優先)
  let label_text = block.label
  children.push(
    @element.svg_text(
      x="12",
      y="20",
      fill="white",
      font_size="13",
      font_family="monospace",
      attrs=[("font-weight", @element.AttrString("bold"))],
      [@element.text(label_text)],
    ),
  )

  // 入力スロット
  for i, slot in block.inputs {
    guard i < size.slot_layouts.length() else { break }
    let (slot_y, _row_height) = size.slot_layouts[i]

    // スロットラベル
    children.push(
      @element.svg_text(
        x="12",
        y=(slot_y + 20.0).to_string(),
        fill="rgba(255,255,255,0.7)",
        font_size="11",
        font_family="monospace",
        [@element.text(slot.name)],
      ),
    )

    match slot.child_id {
      Some(cid) =>
        match workspace.blocks.get(cid) {
          Some(child) => {
            let cx = slot_indent
            let cy = slot_y + 4.0
            children.push(
              @element.svg_g(
                transform="translate(" +
                  cx.to_string() +
                  "," +
                  cy.to_string() +
                  ")",
                [render_block(child, workspace)],
              ),
            )
          }
          None => ()
        }
      None =>
        children.push(
          @element.svg_rect(
            x=slot_indent.to_string(),
            y=(slot_y + 6.0).to_string(),
            width=empty_slot_width.to_string(),
            height=empty_slot_height.to_string(),
            rx="4",
            fill="rgba(0,0,0,0.15)",
            stroke="rgba(0,0,0,0.25)",
            stroke_width="1",
            attrs=[("stroke-dasharray", @element.AttrString("4 2"))],
          ),
        )
    }
  }

  // next ブロック
  match block.next_id {
    Some(nid) =>
      match workspace.blocks.get(nid) {
        Some(next) =>
          children.push(
            @element.svg_g(
              transform="translate(0," +
                (size.height + notch_height).to_string() +
                ")",
              [render_block(next, workspace)],
            ),
          )
        None => ()
      }
    None => ()
  }

  @element.svg_g(
    transform="translate(" +
      block.x.to_string() +
      "," +
      block.y.to_string() +
      ")",
    children,
  )
}
