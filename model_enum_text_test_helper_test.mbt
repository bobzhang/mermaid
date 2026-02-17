///|
fn direction_name(direction : @model.Direction) -> String {
  match direction {
    TD => "TD"
    TB => "TB"
    LR => "LR"
    BT => "BT"
    RL => "RL"
  }
}

///|
fn node_shape_name(shape : @model.NodeShape) -> String {
  match shape {
    Rectangle => "Rectangle"
    Rounded => "Rounded"
    Diamond => "Diamond"
    Stadium => "Stadium"
    Circle => "Circle"
    Subroutine => "Subroutine"
    DoubleCircle => "DoubleCircle"
    Hexagon => "Hexagon"
    Cylinder => "Cylinder"
    Asymmetric => "Asymmetric"
    Trapezoid => "Trapezoid"
    TrapezoidAlt => "TrapezoidAlt"
    StateStart => "StateStart"
    StateEnd => "StateEnd"
    ClassEntity => "ClassEntity"
    ErEntity => "ErEntity"
    SequenceParticipant => "SequenceParticipant"
  }
}

///|
fn edge_style_name(style : @model.EdgeStyle) -> String {
  match style {
    Solid => "Solid"
    Dotted => "Dotted"
    Thick => "Thick"
  }
}
