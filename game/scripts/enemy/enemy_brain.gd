class_name EnemyBrain
extends RefCounted
## One behaviour's thinking (docs/architecture/enemy-split.md): what an enemy does in a fight, one frame at a
## time. Each enemy holds one brain of each kind (made in Enemy._init) and Enemy._brain_for picks the one its
## behaviour names (enemies.json "behaviour"); state a brain alone uses lives in the brain, state that is read
## from outside or shared lives on the node, reached through `enemy`.

var enemy: Enemy


func _init(of: Enemy) -> void:
	enemy = of


## One frame of fighting: `dir` points at its target (flat), `dist` is how far away it is. The node has already
## cleared `velocity` and worked out `_walk_dir`; it moves the body afterwards.
func think(_delta: float, _dir: Vector3, _dist: float) -> void:
	pass
