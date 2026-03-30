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
  let block = BlockInstance::{
    id,
    type_id: def.type_id,
    label: def.label,
    color_hue: def.color_hue,
    connector: def.connector,
    inputs,
    has_next: def.has_next,
    next_id: None,
    x,
    y,
    value: "",
  }
  self.blocks[id] = block
  id
}

/// ブロックを入力スロットに接続
pub fn Workspace::connect_to_input(
  self : Workspace,
  parent_id : String,
  slot_name : String,
  child_id : String,
) -> Unit {
  guard let Some(parent) = self.blocks[parent_id] else { _ => return }
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
  guard let Some(block) = self.blocks[block_id] else { _ => return }
  block.next_id = Some(next_id)
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
