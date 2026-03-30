///| ブロックの SVG レンダリング (Luna DOM API)

let block_width : Double = 200.0

let block_header_height : Double = 32.0

let slot_height : Double = 28.0

let notch_height : Double = 4.0

let corner_radius : Double = 4.0

///|
fn hue_to_color(hue : Int) -> String {
  "hsl(" + hue.to_string() + ", 60%, 50%)"
}

///|
fn hue_to_dark(hue : Int) -> String {
  "hsl(" + hue.to_string() + ", 60%, 35%)"
}

///| Statement ブロックの SVG path
fn statement_path(width : Double, height : Double, has_next : Bool) -> String {
  let r = corner_radius
  let nw = 20.0
  let nh = notch_height
  let mut d = "M " +
    r.to_string() +
    " 0" +
    " L " +
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
  d = d +
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
  d
}

///| Expression ブロック (丸みを帯びた形)
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

///| ブロック1個の DomNode を生成
pub fn render_block(
  block : @model.BlockInstance,
  workspace : @model.Workspace,
) -> @element.DomNode {
  let num_inputs = block.inputs.length()
  let height = if num_inputs > 0 {
    block_header_height + num_inputs.to_double() * slot_height
  } else {
    block_header_height
  }
  let width = block_width
  let color = hue_to_color(block.color_hue)
  let dark = hue_to_dark(block.color_hue)
  let path_d = match block.connector {
    @model.Statement => statement_path(width, height, block.has_next)
    @model.Expression => expression_path(width, height)
  }
  let children : Array[@element.DomNode] = []
  // ブロック本体
  children.push(
    @element.svg_path(
      d=path_d,
      fill=color,
      stroke=dark,
      stroke_width="1.5",
    ),
  )
  // ラベル
  let label_text = if block.value.length() > 0 {
    block.label + " " + block.value
  } else {
    block.label
  }
  children.push(
    @element.svg_text(
      x="12",
      y="20",
      fill="white",
      font_size="13",
      font_family="monospace",
      [@element.text(label_text)],
    ),
  )
  // 入力スロット
  for i, slot in block.inputs {
    let slot_y = block_header_height + i.to_double() * slot_height
    // スロットラベル
    children.push(
      @element.svg_text(
        x="16",
        y=(slot_y + slot_height * 0.7).to_string(),
        fill="rgba(255,255,255,0.7)",
        font_size="11",
        font_family="monospace",
        [@element.text(slot.name)],
      ),
    )
    // スロットの子ブロック or 空スロット
    match slot.child_id {
      Some(cid) =>
        match workspace.blocks.get(cid) {
          Some(child) => {
            let cx = 80.0
            let cy = slot_y + 2.0
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
            x="80",
            y=(slot_y + 4.0).to_string(),
            width="100",
            height="20",
            rx="10",
            fill="rgba(0,0,0,0.15)",
            stroke="rgba(0,0,0,0.3)",
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
                (height + notch_height).to_string() +
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
