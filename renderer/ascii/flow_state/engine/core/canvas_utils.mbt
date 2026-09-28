///|
fn make_canvas(width : Int, height : Int) -> Array[Array[String]] {
  let canvas : Array[Array[String]] = []
  for _ in 0..<height {
    let row : Array[String] = []
    for _ in 0..<width {
      row.push(" ")
    }
    canvas.push(row)
  }
  canvas
}

///|
fn put_canvas(
  canvas : Array[Array[String]],
  x : Int,
  y : Int,
  value : String,
) -> Unit {
  if x < 0 || y < 0 || y >= canvas.length() || x >= canvas[y].length() {
    return
  }
  canvas[y][x] = value
}

///|
fn write_canvas_text(
  canvas : Array[Array[String]],
  x : Int,
  y : Int,
  text : String,
) -> Unit {
  if y < 0 || y >= canvas.length() {
    return
  }
  for i in 0..<text.length() {
    let target_x = x + i
    if target_x >= 0 && target_x < canvas[y].length() {
      put_canvas(canvas, target_x, y, canvas_cell_text(text, i))
    }
  }
}

///|
/// Returns the string stored in the canvas cell for UTF-16 unit `i` of `text`.
/// A surrogate pair spans two cells: the whole character goes in the first
/// cell and the second cell is left empty, so every row keeps exactly one
/// UTF-16 unit per cell and astral characters (e.g. emoji) are not dropped.
fn canvas_cell_text(text : String, i : Int) -> String {
  let unit = text[i]
  if unit.is_leading_surrogate() &&
    i + 1 < text.length() &&
    text[i + 1].is_trailing_surrogate() {
    text[i:i + 2].to_owned()
  } else if unit.is_trailing_surrogate() &&
    i > 0 &&
    text[i - 1].is_leading_surrogate() {
    ""
  } else {
    text[i:i + 1].to_owned()
  }
}

///|
/// Joins a canvas row. A surrogate pair occupies its own cell plus an empty
/// continuation cell (see `canvas_cell_text`); when later drawing overwrote
/// one half of such a pair, the orphaned half is rendered as a space so every
/// row keeps one UTF-16 unit per cell.
fn canvas_row_to_string(row : Array[String]) -> String {
  let sb = StringBuilder()
  for x, cell in row {
    if cell == "" {
      let paired = x > 0 && is_surrogate_pair_cell(row[x - 1])
      if !paired {
        sb.write_string(" ")
      }
    } else if is_surrogate_pair_cell(cell) &&
      !(x + 1 < row.length() && row[x + 1] == "") {
      sb.write_string(" ")
    } else {
      sb.write_string(cell)
    }
  }
  sb.to_string()
}

///|
fn is_surrogate_pair_cell(cell : String) -> Bool {
  cell.length() == 2 && cell[0].is_leading_surrogate()
}
