///| mbt-blockly メインエントリポイント

fn main {
  let catalog = @model.create_block_catalog()
  let ws = @model.Workspace::new()

  // デモ: fn main { let x = 1 + 2; if x == 3 { return x } }

  guard catalog.get("fn_def") is Some(fn_def) else { return }
  let fn_id = ws.create_block(fn_def, 40.0, 40.0, label="fn main()", value="main")

  guard catalog.get("let_binding") is Some(let_binding_def) else { return }
  let let_id = ws.create_block(let_binding_def, 0.0, 0.0, label="let x =")
  ws.connect_to_input(fn_id, "body", let_id)

  guard catalog.get("binary_op") is Some(binary_op_def) else { return }
  let add_id = ws.create_block(binary_op_def, 0.0, 0.0)
  ws.connect_to_input(let_id, "value", add_id)

  guard catalog.get("number_lit") is Some(number_lit_def) else { return }
  let num1_id = ws.create_block(number_lit_def, 0.0, 0.0, label="1", value="1")
  ws.connect_to_input(add_id, "left", num1_id)

  let num2_id = ws.create_block(number_lit_def, 0.0, 0.0, label="2", value="2")
  ws.connect_to_input(add_id, "right", num2_id)

  guard catalog.get("if_stmt") is Some(if_stmt_def) else { return }
  let if_id = ws.create_block(if_stmt_def, 0.0, 0.0)
  ws.connect_next(let_id, if_id)

  guard catalog.get("comparison") is Some(comparison_def) else { return }
  let cmp_id = ws.create_block(comparison_def, 0.0, 0.0)
  ws.connect_to_input(if_id, "condition", cmp_id)

  guard catalog.get("identifier") is Some(identifier_def) else { return }
  let var_x1 = ws.create_block(identifier_def, 0.0, 0.0, label="x")
  ws.connect_to_input(cmp_id, "left", var_x1)

  let num3_id = ws.create_block(number_lit_def, 0.0, 0.0, label="3", value="3")
  ws.connect_to_input(cmp_id, "right", num3_id)

  guard catalog.get("return_stmt") is Some(return_stmt_def) else { return }
  let ret_id = ws.create_block(return_stmt_def, 0.0, 0.0)
  ws.connect_to_input(if_id, "then", ret_id)

  let var_x2 = ws.create_block(identifier_def, 0.0, 0.0, label="x")
  ws.connect_to_input(ret_id, "value", var_x2)

  // SVG レンダリング
  let top_blocks = ws.top_level_blocks()
  let block_nodes : Array[@element.DomNode] = []
  for id in top_blocks {
    match ws.blocks.get(id) {
      Some(block) => block_nodes.push(@render.render_block(block, ws))
      None => ()
    }
  }

  let grid_bg = @element.svg_rect(
    width="100%",
    height="100%",
    fill="#f0f0f4",
  )

  let root = @element.svg(
    width="100%",
    height="100%",
    viewBox="0 0 800 600",
    style="background: #f0f0f4;",
    [grid_bg, @element.svg_g(id="blocks", block_nodes)],
  )

  let doc = @dom.document()
  guard doc.getElementById("app") is Some(el) else { return }
  @element.render_to(el, root)
}
