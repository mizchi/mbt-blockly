///| SVG 文字列生成 (DOM 不要、純粋な文字列構築)
///
/// mizchi/svg でラスタライズ可能な SVG 文字列を出力する。
/// Luna DOM API に依存せず、CLI/TUI からも利用可能。

let min_width : Double = 140.0

let header_h : Double = 32.0

let slot_h : Double = 32.0

let indent : Double = 70.0

let empty_w : Double = 80.0

let empty_h : Double = 24.0

let notch_h : Double = 4.0

let radius : Double = 4.0

let expr_min_w : Double = 80.0

let expr_h : Double = 28.0

let char_w : Double = 8.0

// ---- Size calculation ----

///|
pub struct Size {
  w : Double
  h : Double
  slots : Array[(Double, Double)]
  next_h : Double
}

///|
pub fn measure(
  block : @model.BlockInstance,
  ws : @model.Workspace,
) -> Size {
  match block.connector {
    @model.Expression => measure_expr(block, ws)
    @model.Statement => measure_stmt(block, ws)
  }
}

///|
fn measure_expr(block : @model.BlockInstance, ws : @model.Workspace) -> Size {
  let label = if block.value.length() > 0 { block.value } else { block.label }
  let is_infix = block.inputs.length() == 2 && block.label.contains("_")
  let base_w = label.length().to_double() * char_w + 24.0
  let mut w = if base_w > expr_min_w { base_w } else { expr_min_w }
  let slots : Array[(Double, Double)] = []
  if block.inputs.length() > 0 {
    let op_text = if is_infix { extract_operator(block.label) } else { label }
    let mut cw = op_text.length().to_double() * char_w + 20.0
    for slot in block.inputs {
      let child_block : @model.BlockInstance? = match slot.child_id {
        Some(id) => ws.blocks.get(id)
        None => None
      }
      match child_block {
        Some(child) => {
          let cs = measure(child, ws)
          cw += cs.w + 4.0
          slots.push((0.0, cs.h))
        }
        None => {
          cw += empty_w + 4.0
          slots.push((0.0, empty_h))
        }
      }
    }
    w = if w > cw { w } else { cw }
  }
  { w, h: expr_h, slots, next_h: 0.0 }
}

///|
fn measure_stmt(block : @model.BlockInstance, ws : @model.Workspace) -> Size {
  let mut h = header_h
  let mut w = min_width
  let slots : Array[(Double, Double)] = []
  for slot in block.inputs {
    let sy = h
    let child_block : @model.BlockInstance? = match slot.child_id {
      Some(id) => ws.blocks.get(id)
      None => None
    }
    match child_block {
      Some(child) => {
        let cs = measure(child, ws)
        let ct = cs.h + cs.next_h
        let rh = if slot_h > ct + 4.0 { slot_h } else { ct + 4.0 }
        slots.push((sy, rh))
        let iw = indent + cs.w + 8.0
        w = if w > iw { w } else { iw }
        h += rh
      }
      None => {
        slots.push((sy, slot_h))
        h += slot_h
      }
    }
  }
  let mut nh = 0.0
  let next_block : @model.BlockInstance? = match block.next_id {
    Some(id) => ws.blocks.get(id)
    None => None
  }
  match next_block {
    Some(next) => {
      let ns = measure(next, ws)
      nh = ns.h + ns.next_h + notch_h
      w = if w > ns.w { w } else { ns.w }
    }
    None => ()
  }
  { w, h, slots, next_h: nh }
}

// ---- SVG string generation ----

///| ワークスペース全体を SVG 文字列に変換
pub fn workspace_to_svg(
  ws : @model.Workspace,
  canvas_w : Int,
  canvas_h : Int,
) -> String {
  let buf = StringBuilder::new()
  buf.write_string(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"" +
    canvas_w.to_string() +
    "\" height=\"" +
    canvas_h.to_string() +
    "\" viewBox=\"0 0 " +
    canvas_w.to_string() +
    " " +
    canvas_h.to_string() +
    "\" style=\"background:" +
    bg_color +
    ";\">",
  )
  // グリッド
  buf.write_string(
    "<defs><pattern id=\"g\" width=\"20\" height=\"20\" patternUnits=\"userSpaceOnUse\"><path d=\"M 20 0 L 0 0 0 20\" fill=\"none\" stroke=\"" +
    grid_color +
    "\" stroke-width=\"0.5\"/></pattern></defs>",
  )
  buf.write_string("<rect width=\"100%\" height=\"100%\" fill=\"url(#g)\"/>")
  buf.write_string("<g id=\"viewport\">")
  for id in ws.top_level_blocks() {
    match ws.blocks.get(id) {
      Some(block) => {
        // トップレベルブロックにはドラッグ用の属性を付与
        // block_to_svg は block.x, block.y を使うのでそのまま描画し、
        // 外側の g にも同じ translate を置く (DnD 時に上書きされる)
        buf.write_string(
          "<g data-block-id=\"" +
          block.id +
          "\" style=\"cursor:grab;\" transform=\"translate(" +
          block.x.to_string() +
          "," +
          block.y.to_string() +
          ")\">",
        )
        // block_to_svg 内の g transform と二重にならないよう、
        // 子ブロック描画時は block の x,y を相殺する
        block_to_svg_at_origin(block, ws, buf)
        buf.write_string("</g>")
      }
      None => ()
    }
  }
  buf.write_string("</g>")
  buf.write_string("</svg>")
  buf.to_string()
}

///|
fn block_to_svg(
  block : @model.BlockInstance,
  ws : @model.Workspace,
  buf : StringBuilder,
) -> Unit {
  let sz = measure(block, ws)
  match block.connector {
    @model.Expression => expr_svg(block, ws, sz, buf)
    @model.Statement => stmt_svg(block, ws, sz, buf)
  }
}

///| トップレベル用: block.x/y を無視して原点から描画
fn block_to_svg_at_origin(
  block : @model.BlockInstance,
  ws : @model.Workspace,
  buf : StringBuilder,
) -> Unit {
  // block_to_svg は open_g(buf, block.x, block.y) を呼ぶ。
  // トップレベルでは外側 g で既に translate 済みなので、
  // ここでは逆 translate で相殺する。
  buf.write_string(
    "<g transform=\"translate(" +
    (-block.x).to_string() +
    "," +
    (-block.y).to_string() +
    ")\">",
  )
  block_to_svg(block, ws, buf)
  buf.write_string("</g>")
}

///|
fn open_g(buf : StringBuilder, x : Double, y : Double) -> Unit {
  buf.write_string(
    "<g transform=\"translate(" +
    x.to_string() +
    "," +
    y.to_string() +
    ")\">",
  )
}

///|
fn open_block_g(
  buf : StringBuilder,
  x : Double,
  y : Double,
  block : @model.BlockInstance,
  height? : Double,
) -> Unit {
  let conn_type = match block.connector {
    @model.Expression => "expression"
    @model.Statement => "statement"
  }
  let h_str = match height {
    Some(h) => h.to_string()
    None => "0"
  }
  buf.write_string(
    "<g data-block-id=\"" +
    block.id +
    "\" data-conn=\"" +
    conn_type +
    "\" data-has-next=\"" +
    (if block.has_next { "true" } else { "false" }) +
    "\" data-height=\"" +
    h_str +
    "\" transform=\"translate(" +
    x.to_string() +
    "," +
    y.to_string() +
    ")\">",
  )
}

///|
fn close_g(buf : StringBuilder) -> Unit {
  buf.write_string("</g>")
}

///| Dark theme: muted fill
fn block_fill(hue : Int) -> String {
  "hsl(" + hue.to_string() + ",30%,30%)"
}

///| Dark theme: lighter stroke for contrast
fn block_stroke(hue : Int) -> String {
  "hsl(" + hue.to_string() + ",40%,45%)"
}

///|
let text_color : String = "#cdd6f4"

///|
let text_dim : String = "#a6adc8"

///|
let bg_color : String = "#1e1e2e"

///|
let grid_color : String = "#313244"

///|
let empty_fill : String = "rgba(255,255,255,0.06)"

///|
let empty_stroke : String = "rgba(255,255,255,0.12)"

///|
fn esc(s : String) -> String {
  // minimal XML escape
  let mut out = s
  out = out.replace_all(old="&"[:], new="&amp;"[:])
  out = out.replace_all(old="<"[:], new="&lt;"[:])
  out = out.replace_all(old=">"[:], new="&gt;"[:])
  out = out.replace_all(old="\""[:], new="&quot;"[:])
  out
}

///| 演算子を抽出: "_ + _" → "+"
fn extract_operator(label : String) -> String {
  // "_ op _" の形式から op を取り出す
  let parts = label.split(" ")
  let result : Array[String] = []
  for part in parts {
    let s = part.to_string()
    if s != "_" && s.length() > 0 {
      result.push(s)
    }
  }
  if result.length() > 0 {
    result[0]
  } else {
    label
  }
}

///| 空スロット描画 (expression 用、inline)
fn render_empty_slot(
  buf : StringBuilder,
  x : Double,
  parent_id? : String,
  slot_name? : String,
  accepts? : String,
) -> Unit {
  let parent_id = parent_id.or("")
  let slot_name = slot_name.or("")
  let accepts = accepts.or("expression")
  buf.write_string(
    "<rect class=\"empty-slot\" data-parent=\"" +
    parent_id +
    "\" data-slot=\"" +
    slot_name +
    "\" data-accepts=\"" +
    accepts +
    "\" x=\"" +
    x.to_string() +
    "\" y=\"4\" width=\"" +
    empty_w.to_string() +
    "\" height=\"20\" rx=\"10\" fill=\"" +
    empty_fill +
    "\" stroke=\"" +
    empty_stroke +
    "\" stroke-width=\"1\" stroke-dasharray=\"4 2\"/>",
  )
}

///| Statement path SVG
fn stmt_path(w : Double, h : Double, has_next : Bool) -> String {
  let r = radius
  let nw = 20.0
  let nh = notch_h
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
    (w - r).to_string() +
    " 0 Q " +
    w.to_string() +
    " 0 " +
    w.to_string() +
    " " +
    r.to_string() +
    " L " +
    w.to_string() +
    " " +
    (h - r).to_string()
  if has_next {
    // bottom: 凹ソケット (次のブロックの top 凸を受ける)
    d += " Q " +
      w.to_string() +
      " " +
      h.to_string() +
      " " +
      (w - r).to_string() +
      " " +
      h.to_string() +
      " L " +
      (nw + 16.0).to_string() +
      " " +
      h.to_string() +
      " L " +
      (nw + 12.0).to_string() +
      " " +
      (h - nh).to_string() +
      " L " +
      nw.to_string() +
      " " +
      (h - nh).to_string() +
      " L " +
      (nw - 4.0).to_string() +
      " " +
      h.to_string()
  } else {
    d += " Q " +
      w.to_string() +
      " " +
      h.to_string() +
      " " +
      (w - r).to_string() +
      " " +
      h.to_string()
  }
  d +
  " L " +
  r.to_string() +
  " " +
  h.to_string() +
  " Q 0 " +
  h.to_string() +
  " 0 " +
  (h - r).to_string() +
  " L 0 " +
  r.to_string() +
  " Q 0 0 " +
  r.to_string() +
  " 0 Z"
}

///| Expression path SVG
fn expr_path(w : Double, h : Double) -> String {
  let r = h / 2.0
  "M " +
  r.to_string() +
  " 0 L " +
  (w - r).to_string() +
  " 0 A " +
  r.to_string() +
  " " +
  r.to_string() +
  " 0 0 1 " +
  (w - r).to_string() +
  " " +
  h.to_string() +
  " L " +
  r.to_string() +
  " " +
  h.to_string() +
  " A " +
  r.to_string() +
  " " +
  r.to_string() +
  " 0 0 1 " +
  r.to_string() +
  " 0 Z"
}

///|
fn expr_svg(
  block : @model.BlockInstance,
  ws : @model.Workspace,
  sz : Size,
  buf : StringBuilder,
) -> Unit {
  open_block_g(buf, block.x, block.y, block, height=expr_h)
  let fill = block_fill(block.color_hue)
  let stroke = block_stroke(block.color_hue)
  buf.write_string(
    "<path d=\"" +
    expr_path(sz.w, expr_h) +
    "\" fill=\"" +
    fill +
    "\" stroke=\"" +
    stroke +
    "\" stroke-width=\"1.5\"/>",
  )
  let label = esc(
    if block.value.length() > 0 { block.value } else { block.label },
  )
  // 中置演算子かどうか判定 (inputs が2つで label に _ が含まれる)
  let is_infix = block.inputs.length() == 2 && block.label.contains("_")
  if block.inputs.is_empty() {
    // リーフ expression (number, string, identifier)
    buf.write_string(
      "<text x=\"16\" y=\"18\" fill=\"" +
      text_color +
      "\" font-size=\"13\" font-family=\"monospace\" font-weight=\"bold\">" +
      label +
      "</text>",
    )
  } else if is_infix {
    // 中置演算子: [left] op [right]
    let op = extract_operator(block.label)
    let mut cx = 8.0
    // left operand
    let left_child : @model.BlockInstance? = match block.inputs[0].child_id {
      Some(id) => ws.blocks.get(id)
      None => None
    }
    match left_child {
      Some(child) => {
        let cs = measure(child, ws)
        let cy = (expr_h - cs.h) / 2.0
        open_g(buf, cx, cy)
        block_to_svg(child, ws, buf)
        close_g(buf)
        cx += cs.w + 4.0
      }
      None => {
        render_empty_slot(buf, cx, parent_id=block.id, slot_name="left")
        cx += empty_w + 4.0
      }
    }
    // operator text
    buf.write_string(
      "<text x=\"" +
      cx.to_string() +
      "\" y=\"18\" fill=\"" +
      text_color +
      "\" font-size=\"13\" font-family=\"monospace\" font-weight=\"bold\">" +
      esc(op) +
      "</text>",
    )
    cx += op.length().to_double() * char_w + 4.0
    // right operand
    let right_child : @model.BlockInstance? = match block.inputs[1].child_id {
      Some(id) => ws.blocks.get(id)
      None => None
    }
    match right_child {
      Some(child) => {
        let cs = measure(child, ws)
        let cy = (expr_h - cs.h) / 2.0
        open_g(buf, cx, cy)
        block_to_svg(child, ws, buf)
        close_g(buf)
      }
      None => render_empty_slot(buf, cx, parent_id=block.id, slot_name="right")
    }
  } else {
    // prefix expression (fn_call 等)
    let mut cx = 12.0
    buf.write_string(
      "<text x=\"" +
      cx.to_string() +
      "\" y=\"18\" fill=\"" +
      text_color +
      "\" font-size=\"13\" font-family=\"monospace\" font-weight=\"bold\">" +
      label +
      "</text>",
    )
    cx += label.length().to_double() * char_w + 8.0
    for slot in block.inputs {
      let child_block : @model.BlockInstance? = match slot.child_id {
        Some(id) => ws.blocks.get(id)
        None => None
      }
      match child_block {
        Some(child) => {
          let cs = measure(child, ws)
          let cy = (expr_h - cs.h) / 2.0
          open_g(buf, cx, cy)
          block_to_svg(child, ws, buf)
          close_g(buf)
          cx += cs.w + 4.0
        }
        None => {
          render_empty_slot(buf, cx, parent_id=block.id, slot_name=slot.name)
          cx += empty_w + 4.0
        }
      }
    }
  }
  close_g(buf)
}

///|
fn stmt_svg(
  block : @model.BlockInstance,
  ws : @model.Workspace,
  sz : Size,
  buf : StringBuilder,
) -> Unit {
  open_block_g(buf, block.x, block.y, block, height=sz.h)
  let fill = block_fill(block.color_hue)
  let stroke = block_stroke(block.color_hue)
  buf.write_string(
    "<path d=\"" +
    stmt_path(sz.w, sz.h, block.has_next) +
    "\" fill=\"" +
    fill +
    "\" stroke=\"" +
    stroke +
    "\" stroke-width=\"1.5\"/>",
  )
  buf.write_string(
    "<text x=\"12\" y=\"20\" fill=\"" + text_color + "\" font-size=\"13\" font-family=\"monospace\" font-weight=\"bold\">" +
    esc(block.label) +
    "</text>",
  )
  // slots
  for i, slot in block.inputs {
    guard i < sz.slots.length() else { break }
    let (sy, _) = sz.slots[i]
    buf.write_string(
      "<text x=\"12\" y=\"" +
      (sy + 20.0).to_string() +
      "\" fill=\"" + text_dim + "\" font-size=\"11\" font-family=\"monospace\">" +
      esc(slot.name) +
      "</text>",
    )
    let child_block : @model.BlockInstance? = match slot.child_id {
      Some(id) => ws.blocks.get(id)
      None => None
    }
    match child_block {
      Some(child) => {
        open_g(buf, indent, sy + 4.0)
        block_to_svg(child, ws, buf)
        close_g(buf)
      }
      None => {
        let accepts_str = match slot.accepts {
          @model.Expression => "expression"
          @model.Statement => "statement"
        }
        buf.write_string(
          "<rect class=\"empty-slot\" data-parent=\"" +
          block.id +
          "\" data-slot=\"" +
          slot.name +
          "\" data-accepts=\"" +
          accepts_str +
          "\" x=\"" +
          indent.to_string() +
          "\" y=\"" +
          (sy + 6.0).to_string() +
          "\" width=\"" +
          empty_w.to_string() +
          "\" height=\"" +
          empty_h.to_string() +
          "\" rx=\"4\" fill=\"" + empty_fill + "\" stroke=\"" + empty_stroke + "\" stroke-width=\"1\" stroke-dasharray=\"4 2\"/>",
        )
      }
    }
  }
  // next
  let next_block : @model.BlockInstance? = match block.next_id {
    Some(id) => ws.blocks.get(id)
    None => None
  }
  match next_block {
    Some(next) => {
      open_g(buf, 0.0, sz.h + notch_h)
      block_to_svg(next, ws, buf)
      close_g(buf)
    }
    None => ()
  }
  close_g(buf)
}
