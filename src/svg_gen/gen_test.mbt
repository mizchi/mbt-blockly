///| SVG generation tests

test "workspace to svg produces valid svg" {
  let catalog = @model.create_block_catalog()
  let ws = @model.Workspace::new()
  let _ = ws.create_block(catalog["fn_def"], 10.0, 20.0, label="fn main()")
  let svg = workspace_to_svg(ws, 800, 600)
  inspect(svg.contains("<svg"), content="true")
  inspect(svg.contains("</svg>"), content="true")
  inspect(svg.contains("fn main()"), content="true")
  inspect(svg.contains("data-block-id"), content="true")
}

test "statement block has notch highlight" {
  let catalog = @model.create_block_catalog()
  let ws = @model.Workspace::new()
  let _ = ws.create_block(catalog["let_binding"], 0.0, 0.0)
  let svg = workspace_to_svg(ws, 400, 300)
  // top notch highlight path
  inspect(svg.contains("rgba(160,200,255,0.6)"), content="true")
}

test "expression block renders as pill" {
  let catalog = @model.create_block_catalog()
  let ws = @model.Workspace::new()
  let _ = ws.create_block(catalog["number_lit"], 0.0, 0.0, value="42")
  let svg = workspace_to_svg(ws, 400, 300)
  // pill shape uses arc command
  inspect(svg.contains(" A "), content="true")
  inspect(svg.contains("42"), content="true")
}

test "infix operator renders children inline" {
  let catalog = @model.create_block_catalog()
  let ws = @model.Workspace::new()
  let add = ws.create_block(catalog["binary_op"], 0.0, 0.0)
  let n1 = ws.create_block(catalog["number_lit"], 0.0, 0.0, value="1")
  let n2 = ws.create_block(catalog["number_lit"], 0.0, 0.0, value="2")
  ws.connect_to_input(add, "left", n1)
  ws.connect_to_input(add, "right", n2)
  let svg = workspace_to_svg(ws, 400, 300)
  // operator "+" should appear
  inspect(svg.contains(">+<"), content="true")
  // both children visible
  inspect(svg.contains(">1<"), content="true")
  inspect(svg.contains(">2<"), content="true")
}

test "empty slot has adapter shape" {
  let catalog = @model.create_block_catalog()
  let ws = @model.Workspace::new()
  let _ = ws.create_block(catalog["if_stmt"], 0.0, 0.0)
  let svg = workspace_to_svg(ws, 400, 300)
  // statement slot should have notch adapter (filled blue)
  inspect(svg.contains("rgba(160,200,255,0.15)"), content="true")
  // should have empty-slot class
  inspect(svg.contains("class=\"empty-slot\""), content="true")
}

test "next chain renders rail" {
  let catalog = @model.create_block_catalog()
  let ws = @model.Workspace::new()
  let a = ws.create_block(catalog["let_binding"], 0.0, 0.0)
  let b = ws.create_block(catalog["return_stmt"], 0.0, 0.0)
  ws.connect_next(a, b)
  let svg = workspace_to_svg(ws, 400, 300)
  // rail line between connected statements
  inspect(svg.contains("rgba(160,200,255,0.5)"), content="true")
  // rail dots
  inspect(svg.contains("rgba(160,200,255,0.7)"), content="true")
}

test "top level block has shadow and data attributes" {
  let catalog = @model.create_block_catalog()
  let ws = @model.Workspace::new()
  let _ = ws.create_block(catalog["fn_def"], 30.0, 40.0)
  let svg = workspace_to_svg(ws, 800, 600)
  inspect(svg.contains("data-top-level=\"true\""), content="true")
  inspect(svg.contains("filter=\"url(#shadow)\""), content="true")
  inspect(svg.contains("cursor:grab"), content="true")
}

test "block metadata attributes" {
  let catalog = @model.create_block_catalog()
  let ws = @model.Workspace::new()
  let _ = ws.create_block(catalog["if_stmt"], 0.0, 0.0)
  let svg = workspace_to_svg(ws, 400, 300)
  inspect(svg.contains("data-conn=\"statement\""), content="true")
  inspect(svg.contains("data-has-next=\"true\""), content="true")
  inspect(svg.contains("data-height="), content="true")
}

test "dark theme colors" {
  let catalog = @model.create_block_catalog()
  let ws = @model.Workspace::new()
  let _ = ws.create_block(catalog["fn_def"], 0.0, 0.0)
  let svg = workspace_to_svg(ws, 400, 300)
  // background
  inspect(svg.contains("#1e1e2e"), content="true")
  // grid
  inspect(svg.contains("#313244"), content="true")
  // text color
  inspect(svg.contains("#cdd6f4"), content="true")
}
