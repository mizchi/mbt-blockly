///| CLI: SVG 生成 → ラスタライズ → kitty graphics protocol で出力

fn main {
  let catalog = @model.create_block_catalog()
  let ws = @model.Workspace::new()

  // デモ: fn main { let x = 1 + 2; if x == 3 { return x } }
  guard catalog.get("fn_def") is Some(fn_def) else { return }
  let fn_id = ws.create_block(fn_def, 40.0, 40.0, label="fn main()")

  guard catalog.get("let_binding") is Some(let_def) else { return }
  let let_id = ws.create_block(let_def, 0.0, 0.0, label="let x =")
  ws.connect_to_input(fn_id, "body", let_id)

  guard catalog.get("binary_op") is Some(bin_def) else { return }
  let add_id = ws.create_block(bin_def, 0.0, 0.0)
  ws.connect_to_input(let_id, "value", add_id)

  guard catalog.get("number_lit") is Some(num_def) else { return }
  let n1 = ws.create_block(num_def, 0.0, 0.0, label="1", value="1")
  ws.connect_to_input(add_id, "left", n1)
  let n2 = ws.create_block(num_def, 0.0, 0.0, label="2", value="2")
  ws.connect_to_input(add_id, "right", n2)

  guard catalog.get("if_stmt") is Some(if_def) else { return }
  let if_id = ws.create_block(if_def, 0.0, 0.0)
  ws.connect_next(let_id, if_id)

  guard catalog.get("comparison") is Some(cmp_def) else { return }
  let cmp_id = ws.create_block(cmp_def, 0.0, 0.0)
  ws.connect_to_input(if_id, "condition", cmp_id)

  guard catalog.get("identifier") is Some(id_def) else { return }
  let vx1 = ws.create_block(id_def, 0.0, 0.0, label="x", value="x")
  ws.connect_to_input(cmp_id, "left", vx1)
  let n3 = ws.create_block(num_def, 0.0, 0.0, label="3", value="3")
  ws.connect_to_input(cmp_id, "right", n3)

  guard catalog.get("return_stmt") is Some(ret_def) else { return }
  let ret_id = ws.create_block(ret_def, 0.0, 0.0)
  ws.connect_to_input(if_id, "then", ret_id)
  let vx2 = ws.create_block(id_def, 0.0, 0.0, label="x", value="x")
  ws.connect_to_input(ret_id, "value", vx2)

  // SVG 文字列を生成
  let svg_str = @svg_gen.workspace_to_svg(ws, 700, 500)

  // mizchi/svg でラスタライズ
  guard @svg.render_svg_to_image(svg_str, 700, 500) is Some(image) else {
    println("Failed to render SVG")
    return
  }

  // kitty graphics protocol で出力
  // f=32 = RGBA, t=d = direct data, a=T = transmit and display
  let pixels = image.pixels
  let w = image.width
  let h = image.height

  // RGBA バイト列を構築
  let byte_arr : FixedArray[Byte] = FixedArray::make(w * h * 4, b'\x00')
  for i, color in pixels {
    let off = i * 4
    byte_arr[off] = color.r.to_byte()
    byte_arr[off + 1] = color.g.to_byte()
    byte_arr[off + 2] = color.b.to_byte()
    byte_arr[off + 3] = color.a.to_byte()
  }
  let bytes = Bytes::from_array(byte_arr[:])

  // Base64 エンコード
  let b64 = base64_encode(bytes)

  // kitty graphics protocol (chunked)
  let chunk_size = 4096
  let out = StringBuilder::new()
  let mut i = 0
  while i < b64.length() {
    let end = if i + chunk_size < b64.length() {
      i + chunk_size
    } else {
      b64.length()
    }
    let chunk = b64[i:end].to_string()
    let is_last = end >= b64.length()
    if i == 0 {
      out.write_string(
        "\u001b_Gf=32,s=" +
        w.to_string() +
        ",v=" +
        h.to_string() +
        ",a=T,m=" +
        (if is_last { "0" } else { "1" }) +
        ";" +
        chunk +
        "\u001b\\",
      )
    } else {
      out.write_string(
        "\u001b_Gm=" +
        (if is_last { "0" } else { "1" }) +
        ";" +
        chunk +
        "\u001b\\",
      )
    }
    i = i + chunk_size
  }
  println(out.to_string())
}

// ---- Base64 encoder ----

///|
let b64_table : Array[Char] = [
  'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
  'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
  'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm',
  'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
  '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '+', '/',
]

///|
fn base64_encode(data : Bytes) -> String {
  let buf = StringBuilder::new()
  let len = data.length()
  let mut i = 0
  while i < len {
    let b0 = data[i].to_int()
    let b1 = if i + 1 < len { data[i + 1].to_int() } else { 0 }
    let b2 = if i + 2 < len { data[i + 2].to_int() } else { 0 }
    let n = (b0 << 16).lor(b1 << 8).lor(b2)
    buf.write_char(b64_table[(n >> 18).land(63)])
    buf.write_char(b64_table[(n >> 12).land(63)])
    if i + 1 < len {
      buf.write_char(b64_table[(n >> 6).land(63)])
    } else {
      buf.write_char('=')
    }
    if i + 2 < len {
      buf.write_char(b64_table[n.land(63)])
    } else {
      buf.write_char('=')
    }
    i = i + 3
  }
  buf.to_string()
}
