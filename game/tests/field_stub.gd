extends Node
## A stand-in for main.gd in the self-test's field checks: FieldCamps reads only `level` and
## `player` from its owner (and calls _on_reinforcements if there is one; here there is not).

var level: Node3D
var player: Node3D
