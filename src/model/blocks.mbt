///| MoonBit AST のブロック定義

/// ブロックカタログ: MoonBit の基本構文に対応するブロック
pub fn create_block_catalog() -> Map[String, BlockDef] {
  let catalog : Map[String, BlockDef] = {}

  // ---- Statements ----

  catalog["let_binding"] = BlockDef::{
    type_id: "let_binding",
    label: "let _ = _",
    color_hue: 210,
    connector: Statement,
    inputs: [
      InputSlot::{ name: "value", accepts: Expression, child_id: None },
    ],
    has_next: true,
  }

  catalog["fn_def"] = BlockDef::{
    type_id: "fn_def",
    label: "fn _()",
    color_hue: 270,
    connector: Statement,
    inputs: [
      InputSlot::{ name: "body", accepts: Statement, child_id: None },
    ],
    has_next: true,
  }

  catalog["if_stmt"] = BlockDef::{
    type_id: "if_stmt",
    label: "if",
    color_hue: 40,
    connector: Statement,
    inputs: [
      InputSlot::{ name: "condition", accepts: Expression, child_id: None },
      InputSlot::{ name: "then", accepts: Statement, child_id: None },
      InputSlot::{ name: "else", accepts: Statement, child_id: None },
    ],
    has_next: true,
  }

  catalog["match_stmt"] = BlockDef::{
    type_id: "match_stmt",
    label: "match",
    color_hue: 320,
    connector: Statement,
    inputs: [
      InputSlot::{ name: "expr", accepts: Expression, child_id: None },
      InputSlot::{ name: "arms", accepts: Statement, child_id: None },
    ],
    has_next: true,
  }

  catalog["for_loop"] = BlockDef::{
    type_id: "for_loop",
    label: "for _ in _",
    color_hue: 160,
    connector: Statement,
    inputs: [
      InputSlot::{ name: "iter", accepts: Expression, child_id: None },
      InputSlot::{ name: "body", accepts: Statement, child_id: None },
    ],
    has_next: true,
  }

  catalog["return_stmt"] = BlockDef::{
    type_id: "return_stmt",
    label: "return",
    color_hue: 0,
    connector: Statement,
    inputs: [
      InputSlot::{ name: "value", accepts: Expression, child_id: None },
    ],
    has_next: false,
  }

  // ---- Expressions ----

  catalog["number_lit"] = BlockDef::{
    type_id: "number_lit",
    label: "0",
    color_hue: 120,
    connector: Expression,
    inputs: [],
    has_next: false,
  }

  catalog["string_lit"] = BlockDef::{
    type_id: "string_lit",
    label: "\"\"",
    color_hue: 150,
    connector: Expression,
    inputs: [],
    has_next: false,
  }

  catalog["bool_lit"] = BlockDef::{
    type_id: "bool_lit",
    label: "true",
    color_hue: 60,
    connector: Expression,
    inputs: [],
    has_next: false,
  }

  catalog["identifier"] = BlockDef::{
    type_id: "identifier",
    label: "x",
    color_hue: 200,
    connector: Expression,
    inputs: [],
    has_next: false,
  }

  catalog["binary_op"] = BlockDef::{
    type_id: "binary_op",
    label: "_ + _",
    color_hue: 90,
    connector: Expression,
    inputs: [
      InputSlot::{ name: "left", accepts: Expression, child_id: None },
      InputSlot::{ name: "right", accepts: Expression, child_id: None },
    ],
    has_next: false,
  }

  catalog["fn_call"] = BlockDef::{
    type_id: "fn_call",
    label: "_()",
    color_hue: 280,
    connector: Expression,
    inputs: [
      InputSlot::{ name: "arg0", accepts: Expression, child_id: None },
    ],
    has_next: false,
  }

  catalog["comparison"] = BlockDef::{
    type_id: "comparison",
    label: "_ == _",
    color_hue: 30,
    connector: Expression,
    inputs: [
      InputSlot::{ name: "left", accepts: Expression, child_id: None },
      InputSlot::{ name: "right", accepts: Expression, child_id: None },
    ],
    has_next: false,
  }

  catalog
}
