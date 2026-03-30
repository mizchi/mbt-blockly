///| Workspace model tests

test "create block and retrieve" {
  let catalog = create_block_catalog()
  let ws = Workspace::new()
  let id = ws.create_block(catalog["let_binding"], 10.0, 20.0, label="let x =")
  inspect(ws.blocks.contains(id), content="true")
  inspect(ws.blocks[id].label, content="let x =")
  inspect(ws.blocks[id].x, content="10")
}

test "connect to input slot" {
  let catalog = create_block_catalog()
  let ws = Workspace::new()
  let parent = ws.create_block(catalog["let_binding"], 0.0, 0.0)
  let child = ws.create_block(catalog["number_lit"], 0.0, 0.0, value="42")
  ws.connect_to_input(parent, "value", child)
  inspect(ws.blocks[parent].inputs[0].child_id, content="Some(\"block_2\")")
}

test "connect next (statement chain)" {
  let catalog = create_block_catalog()
  let ws = Workspace::new()
  let a = ws.create_block(catalog["let_binding"], 0.0, 0.0)
  let b = ws.create_block(catalog["if_stmt"], 0.0, 0.0)
  ws.connect_next(a, b)
  inspect(ws.blocks[a].next_id, content="Some(\"block_2\")")
}

test "detach from input slot" {
  let catalog = create_block_catalog()
  let ws = Workspace::new()
  let parent = ws.create_block(catalog["let_binding"], 0.0, 0.0)
  let child = ws.create_block(catalog["number_lit"], 0.0, 0.0)
  ws.connect_to_input(parent, "value", child)
  inspect(ws.blocks[parent].inputs[0].child_id is None, content="false")
  ws.detach_block(child)
  inspect(ws.blocks[parent].inputs[0].child_id is None, content="true")
}

test "detach from next chain" {
  let catalog = create_block_catalog()
  let ws = Workspace::new()
  let a = ws.create_block(catalog["let_binding"], 0.0, 0.0)
  let b = ws.create_block(catalog["if_stmt"], 0.0, 0.0)
  ws.connect_next(a, b)
  ws.detach_block(b)
  inspect(ws.blocks[a].next_id is None, content="true")
}

test "insert after splices chain" {
  let catalog = create_block_catalog()
  let ws = Workspace::new()
  let a = ws.create_block(catalog["let_binding"], 0.0, 0.0, label="a")
  let b = ws.create_block(catalog["return_stmt"], 0.0, 0.0, label="b")
  let c = ws.create_block(catalog["if_stmt"], 0.0, 0.0, label="c")
  ws.connect_next(a, b)
  // Insert c between a and b: a → c → b
  ws.insert_after(a, c)
  inspect(ws.blocks[a].next_id, content="Some(\"block_3\")")
  inspect(ws.blocks[c].next_id, content="Some(\"block_2\")")
}

test "top level blocks" {
  let catalog = create_block_catalog()
  let ws = Workspace::new()
  let fn1 = ws.create_block(catalog["fn_def"], 0.0, 0.0)
  let body = ws.create_block(catalog["let_binding"], 0.0, 0.0)
  ws.connect_to_input(fn1, "body", body)
  let fn2 = ws.create_block(catalog["fn_def"], 100.0, 0.0)
  let tops = ws.top_level_blocks()
  // fn1 と fn2 がトップレベル、body は fn1 の子なのでトップレベルではない
  inspect(tops.length(), content="2")
  inspect(tops.contains(fn1), content="true")
  inspect(tops.contains(fn2), content="true")
  inspect(tops.contains(body), content="false")
}

test "move block" {
  let catalog = create_block_catalog()
  let ws = Workspace::new()
  let id = ws.create_block(catalog["number_lit"], 0.0, 0.0)
  ws.move_block(id, 50.0, 100.0)
  inspect(ws.blocks[id].x, content="50")
  inspect(ws.blocks[id].y, content="100")
}

test "disconnect slot returns old child" {
  let catalog = create_block_catalog()
  let ws = Workspace::new()
  let parent = ws.create_block(catalog["binary_op"], 0.0, 0.0)
  let left = ws.create_block(catalog["number_lit"], 0.0, 0.0, value="1")
  ws.connect_to_input(parent, "left", left)
  let old = ws.disconnect_slot(parent, "left")
  inspect(old, content="Some(\"block_2\")")
  inspect(ws.blocks[parent].inputs[0].child_id is None, content="true")
}

test "block catalog has all types" {
  let catalog = create_block_catalog()
  let expected = [
    "fn_def", "let_binding", "if_stmt", "match_stmt", "for_loop",
    "return_stmt", "number_lit", "string_lit", "bool_lit",
    "identifier", "binary_op", "fn_call", "comparison",
  ]
  for name in expected {
    inspect(catalog.contains(name), content="true")
  }
}

test "nested expression tree" {
  // 1 + 2 構築
  let catalog = create_block_catalog()
  let ws = Workspace::new()
  let add = ws.create_block(catalog["binary_op"], 0.0, 0.0)
  let n1 = ws.create_block(catalog["number_lit"], 0.0, 0.0, value="1")
  let n2 = ws.create_block(catalog["number_lit"], 0.0, 0.0, value="2")
  ws.connect_to_input(add, "left", n1)
  ws.connect_to_input(add, "right", n2)
  // add はトップレベル、n1/n2 は子
  let tops = ws.top_level_blocks()
  inspect(tops.length(), content="1")
  inspect(tops[0], content="block_1")
}
