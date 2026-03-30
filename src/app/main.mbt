///| mbt-blockly メインエントリポイント
///
/// グローバル Workspace を保持し、JS から操作関数を呼んで再描画する。

extern "js" fn set_inner_html(el : @dom.Element, html : String) -> Unit =
  #|(el, html) => { el.innerHTML = html; }

extern "js" fn register_api(
  detach : (String) -> Unit,
  connect : (String, String, String) -> Unit,
  connect_next : (String, String) -> Unit,
  move_block : (String, Double, Double) -> Unit,
  rerender : () -> Unit,
  get_block_type : (String) -> String,
) -> Unit =
  #|(detach, connect, connectNext, moveBlock, rerender, getBlockType) => {
  #| var o = Object.create(null);
  #| o.detach = detach;
  #| o.connect = connect;
  #| o.connectNext = connectNext;
  #| o.moveBlock = moveBlock;
  #| o.rerender = rerender;
  #| o.getBlockType = getBlockType;
  #| window.__mbt = o;
  #|}

///| グローバル状態
let global_ws : Ref[@model.Workspace] = { val: @model.Workspace::new() }

///| SVG を再描画
fn render() -> Unit {
  let svg_str = @svg_gen.workspace_to_svg(global_ws.val, 1200, 800)
  let doc = @dom.document()
  guard doc.getElementById("app") is Some(el) else { return }
  set_inner_html(el, svg_str)
}

///|
fn main {
  let catalog = @model.create_block_catalog()
  let ws = @model.Workspace::new()
  global_ws.val = ws

  guard catalog.get("fn_def") is Some(fn_def) else { return }
  guard catalog.get("let_binding") is Some(let_def) else { return }
  guard catalog.get("binary_op") is Some(bin_def) else { return }
  guard catalog.get("number_lit") is Some(num_def) else { return }
  guard catalog.get("if_stmt") is Some(if_def) else { return }
  guard catalog.get("comparison") is Some(cmp_def) else { return }
  guard catalog.get("identifier") is Some(id_def) else { return }
  guard catalog.get("return_stmt") is Some(ret_def) else { return }
  guard catalog.get("fn_call") is Some(call_def) else { return }
  guard catalog.get("string_lit") is Some(str_def) else { return }

  // fn main() { let x = 1 + 2; if x == 3 { return x } }
  let fn1 = ws.create_block(fn_def, 30.0, 30.0, label="fn main()")
  let let1 = ws.create_block(let_def, 0.0, 0.0, label="let x =")
  ws.connect_to_input(fn1, "body", let1)
  let add1 = ws.create_block(bin_def, 0.0, 0.0)
  ws.connect_to_input(let1, "value", add1)
  let n1 = ws.create_block(num_def, 0.0, 0.0, value="1")
  ws.connect_to_input(add1, "left", n1)
  let n2 = ws.create_block(num_def, 0.0, 0.0, value="2")
  ws.connect_to_input(add1, "right", n2)
  let if1 = ws.create_block(if_def, 0.0, 0.0)
  ws.connect_next(let1, if1)
  let cmp1 = ws.create_block(cmp_def, 0.0, 0.0)
  ws.connect_to_input(if1, "condition", cmp1)
  let vx1 = ws.create_block(id_def, 0.0, 0.0, value="x")
  ws.connect_to_input(cmp1, "left", vx1)
  let n3 = ws.create_block(num_def, 0.0, 0.0, value="3")
  ws.connect_to_input(cmp1, "right", n3)
  let ret1 = ws.create_block(ret_def, 0.0, 0.0)
  ws.connect_to_input(if1, "then", ret1)
  let vx2 = ws.create_block(id_def, 0.0, 0.0, value="x")
  ws.connect_to_input(ret1, "value", vx2)

  // fn add(a, b) { return a + b }
  let fn2 = ws.create_block(fn_def, 550.0, 30.0, label="fn add(a, b)")
  let ret2 = ws.create_block(ret_def, 0.0, 0.0)
  ws.connect_to_input(fn2, "body", ret2)
  let add2 = ws.create_block(bin_def, 0.0, 0.0)
  ws.connect_to_input(ret2, "value", add2)
  let va = ws.create_block(id_def, 0.0, 0.0, value="a")
  ws.connect_to_input(add2, "left", va)
  let vb = ws.create_block(id_def, 0.0, 0.0, value="b")
  ws.connect_to_input(add2, "right", vb)

  // fn greet(name) { let msg = "Hello, " + name; println(msg) }
  let fn3 = ws.create_block(fn_def, 30.0, 450.0, label="fn greet(name)")
  let let2 = ws.create_block(let_def, 0.0, 0.0, label="let msg =")
  ws.connect_to_input(fn3, "body", let2)
  let concat = ws.create_block(bin_def, 0.0, 0.0)
  ws.connect_to_input(let2, "value", concat)
  let hello = ws.create_block(str_def, 0.0, 0.0, value="\"Hello, \"")
  ws.connect_to_input(concat, "left", hello)
  let vname = ws.create_block(id_def, 0.0, 0.0, value="name")
  ws.connect_to_input(concat, "right", vname)
  let call1 = ws.create_block(call_def, 0.0, 0.0, label="println()")
  ws.connect_next(let2, call1)
  let vmsg = ws.create_block(id_def, 0.0, 0.0, value="msg")
  ws.connect_to_input(call1, "arg0", vmsg)

  // JS API を登録
  register_api(
    fn(block_id) { global_ws.val.detach_block(block_id) },
    fn(parent_id, slot_name, child_id) {
      global_ws.val.connect_to_input(parent_id, slot_name, child_id)
    },
    fn(block_id, next_id) { global_ws.val.connect_next(block_id, next_id) },
    fn(block_id, x, y) { global_ws.val.move_block(block_id, x, y) },
    fn() { render() },
    fn(block_id) -> String {
      match global_ws.val.blocks.get(block_id) {
        Some(block) =>
          match block.connector {
            @model.Expression => "expression"
            @model.Statement => "statement"
          }
        None => "unknown"
      }
    },
  )

  // 初回描画
  render()
}
