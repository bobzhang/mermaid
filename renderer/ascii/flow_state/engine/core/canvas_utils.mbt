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
      put_canvas(canvas, target_x, y, (try! text[i:i + 1]).to_string())
    }
  }
}
