///| Workspace 操作

pub fn Workspace::new() -> Workspace {
  { blocks: {}, next_id_counter: 1 }
}

pub fn Workspace::gen_id(self : Workspace) -> String {
  let id = "block_" + self.next_id_counter.to_string()
  self.next_id_counter += 1
  id
}

/// ブロック定義からインスタンスを生成
pub fn Workspace::create_block(
  self : Workspace,
  def : BlockDef,
  x : Double,
  y : Double,
  label? : String,
  value? : String,
) -> String {
  let id = self.gen_id()
  // inputs を deep copy
  let inputs = def.inputs.map(
    fn(slot) {
      InputSlot::{
        name: slot.name,
        accepts: slot.accepts,
        child_id: None,
      }
    },
  )
  let actual_label = match label {
    Some(l) => l
    None => def.label
  }
  let actual_value = match value {
    Some(v) => v
    None => ""
  }
  let block = BlockInstance::{
    id,
    type_id: def.type_id,
    label: actual_label,
    color_hue: def.color_hue,
    connector: def.connector,
    inputs,
    has_next: def.has_next,
    next_id: None,
    x,
    y,
    value: actual_value,
  }
  self.blocks[id] = block
  id
}

/// ブロックのラベルと値を更新
pub fn Workspace::update_block(
  self : Workspace,
  block_id : String,
  label? : String,
  value? : String,
) -> Unit {
  guard self.blocks.get(block_id) is Some(block) else { return }
  match label {
    Some(l) => block.label = l
    None => ()
  }
  match value {
    Some(v) => block.value = v
    None => ()
  }
}

/// ブロックを入力スロットに接続
pub fn Workspace::connect_to_input(
  self : Workspace,
  parent_id : String,
  slot_name : String,
  child_id : String,
) -> Unit {
  guard self.blocks.get(parent_id) is Some(parent) else { return }
  for slot in parent.inputs {
    if slot.name == slot_name {
      slot.child_id = Some(child_id)
      return
    }
  }
}

/// ブロックを次のブロックとして接続 (bottom → top)
pub fn Workspace::connect_next(
  self : Workspace,
  block_id : String,
  next_id : String,
) -> Unit {
  guard self.blocks.get(block_id) is Some(block) else { return }
  block.next_id = Some(next_id)
}

/// after_id の直後に block_id を挿入 (既存の next chain を繋ぎ替え)
pub fn Workspace::insert_after(
  self : Workspace,
  after_id : String,
  block_id : String,
) -> Unit {
  guard self.blocks.get(after_id) is Some(after_block) else { return }
  guard self.blocks.get(block_id) is Some(new_block) else { return }
  // after の元の next を new_block の next に移す
  new_block.next_id = after_block.next_id
  // after → new_block に接続
  after_block.next_id = Some(block_id)
}

/// ブロックを親から取り外す (スロット or next chain)
pub fn Workspace::detach_block(self : Workspace, block_id : String) -> Unit {
  for _, parent in self.blocks {
    // input スロットから切断
    for slot in parent.inputs {
      match slot.child_id {
        Some(cid) =>
          if cid == block_id {
            slot.child_id = None
          }
        None => ()
      }
    }
    // next chain から切断
    match parent.next_id {
      Some(nid) =>
        if nid == block_id {
          parent.next_id = None
        }
      None => ()
    }
  }
}

/// スロットの接続を解除 (子ブロックの ID を返す)
pub fn Workspace::disconnect_slot(
  self : Workspace,
  parent_id : String,
  slot_name : String,
) -> String? {
  guard self.blocks.get(parent_id) is Some(parent) else { return None }
  for slot in parent.inputs {
    if slot.name == slot_name {
      let old = slot.child_id
      slot.child_id = None
      return old
    }
  }
  None
}

/// ブロック位置の更新
pub fn Workspace::move_block(
  self : Workspace,
  block_id : String,
  x : Double,
  y : Double,
) -> Unit {
  guard self.blocks.get(block_id) is Some(block) else { return }
  block.x = x
  block.y = y
}

/// トップレベルブロック (どのスロットにも嵌まっていないブロック) を取得
pub fn Workspace::top_level_blocks(self : Workspace) -> Array[String] {
  let children : Map[String, Bool] = {}
  for _, block in self.blocks {
    for slot in block.inputs {
      match slot.child_id {
        Some(cid) => children[cid] = true
        None => ()
      }
    }
    match block.next_id {
      Some(nid) => children[nid] = true
      None => ()
    }
  }
  let result : Array[String] = []
  for id, _ in self.blocks {
    if not(children.contains(id)) {
      result.push(id)
    }
  }
  result
}
