///| mbt-blockly メインエントリポイント

fn main {
  // ブロックカタログ
  let catalog = @model.create_block_catalog()

  // ワークスペース初期化
  let ws = @model.Workspace::new()

  // デモ: fn main { let x = 1 + 2; if x == 3 { return x } }

  // fn_def ブロック
  let fn_id = ws.create_block(catalog["fn_def"].unwrap(), 40.0, 40.0)
  guard let Some(fn_block) = ws.blocks[fn_id] else { _ => return }
  fn_block.value = "main"
  fn_block.label = "fn main()"

  // let_binding
  let let_id = ws.create_block(catalog["let_binding"].unwrap(), 0.0, 0.0)
  guard let Some(let_block) = ws.blocks[let_id] else { _ => return }
  let_block.label = "let x ="
  ws.connect_to_input(fn_id, "body", let_id)

  // 1 + 2
  let add_id = ws.create_block(catalog["binary_op"].unwrap(), 0.0, 0.0)
  guard let Some(add_block) = ws.blocks[add_id] else { _ => return }
  add_block.label = "_ + _"
  ws.connect_to_input(let_id, "value", add_id)

  let num1_id = ws.create_block(catalog["number_lit"].unwrap(), 0.0, 0.0)
  guard let Some(num1) = ws.blocks[num1_id] else { _ => return }
  num1.value = "1"
  num1.label = "1"
  ws.connect_to_input(add_id, "left", num1_id)

  let num2_id = ws.create_block(catalog["number_lit"].unwrap(), 0.0, 0.0)
  guard let Some(num2) = ws.blocks[num2_id] else { _ => return }
  num2.value = "2"
  num2.label = "2"
  ws.connect_to_input(add_id, "right", num2_id)

  // if x == 3 { return x }
  let if_id = ws.create_block(catalog["if_stmt"].unwrap(), 0.0, 0.0)
  ws.connect_next(let_id, if_id)

  // x == 3
  let cmp_id = ws.create_block(catalog["comparison"].unwrap(), 0.0, 0.0)
  ws.connect_to_input(if_id, "condition", cmp_id)

  let var_x1 = ws.create_block(catalog["identifier"].unwrap(), 0.0, 0.0)
  guard let Some(vx1) = ws.blocks[var_x1] else { _ => return }
  vx1.label = "x"
  vx1.value = "x"
  ws.connect_to_input(cmp_id, "left", var_x1)

  let num3_id = ws.create_block(catalog["number_lit"].unwrap(), 0.0, 0.0)
  guard let Some(num3) = ws.blocks[num3_id] else { _ => return }
  num3.value = "3"
  num3.label = "3"
  ws.connect_to_input(cmp_id, "right", num3_id)

  // return x
  let ret_id = ws.create_block(catalog["return_stmt"].unwrap(), 0.0, 0.0)
  ws.connect_to_input(if_id, "then", ret_id)

  let var_x2 = ws.create_block(catalog["identifier"].unwrap(), 0.0, 0.0)
  guard let Some(vx2) = ws.blocks[var_x2] else { _ => return }
  vx2.label = "x"
  vx2.value = "x"
  ws.connect_to_input(ret_id, "value", var_x2)

  // SVG レンダリング
  let top_blocks = ws.top_level_blocks()
  let block_nodes : Array[@luna.Node[Unit, String]] = []
  for id in top_blocks {
    match ws.blocks[id] {
      Some(block) => block_nodes.push(@render.render_block(block, ws))
      None => ()
    }
  }

  let svg = @svg.svg(
    [
      ("width", @luna.attr_static("100%")),
      ("height", @luna.attr_static("100%")),
      ("viewBox", @luna.attr_static("0 0 800 600")),
      ("style", @luna.attr_static("background: #f0f0f4;")),
    ],
    [
      // 背景グリッド
      @svg.defs(
        [],
        [
          @luna.h(
            "pattern",
            [
              ("id", @luna.attr_static("grid")),
              ("width", @luna.attr_static("20")),
              ("height", @luna.attr_static("20")),
              ("patternUnits", @luna.attr_static("userSpaceOnUse")),
            ],
            [
              @svg.path(
                [
                  ("d", @luna.attr_static("M 20 0 L 0 0 0 20")),
                  ("fill", @luna.attr_static("none")),
                  ("stroke", @luna.attr_static("#ddd")),
                  ("stroke-width", @luna.attr_static("0.5")),
                ],
                [],
              ),
            ],
          ),
        ],
      ),
      @svg.rect(
        [
          ("width", @luna.attr_static("100%")),
          ("height", @luna.attr_static("100%")),
          ("fill", @luna.attr_static("url(#grid)")),
        ],
        [],
      ),
      // ブロック群
      @svg.g([("id", @luna.attr_static("blocks"))], block_nodes),
    ],
  )

  let html = @luna.render_to_string(svg)
  let app = @dom.query_selector("#app")
  @dom.set_inner_html(app, html)
}
