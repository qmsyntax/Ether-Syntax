class_name RngSeed
extends RefCounted
## Where every random generator in the game gets its seed. In play: the clock, as before. Under a test:
## one fixed seed, so a test cannot pass or fail on the roll of the day (.claude/docs/coding-standards.md:
## "Tests must produce the same result every run").
##
## A test calls `RngSeed.fix_from_args()` first thing (before main.tscn or a player is built). That
## seeds the global generator (randf(), randi(), Array.shuffle / pick_random) and makes every
## `RngSeed.apply(rng, salt)` - the game's own generators: main's level rolls, the player's drops and
## wounds, the Stubble's camps, the Netherecho's sites and constructs, the creation screen's primes -
## start from that seed too, each salted by its name and how many of that name came before, so adding
## a roll in one system does not reshuffle another. `-- --seed=<n>` picks another seed (to reproduce
## or to hunt for a bad roll on purpose); `-- --seed=random` leaves everything to the clock.

const DEFAULT := 20261108

## -1: not fixed (play). Otherwise the seed every generator is derived from.
static var fixed: int = -1
static var _made: Dictionary = {}


## Fix every generator to `seed_value` from now on (and the global one at once).
static func fix(seed_value: int) -> void:
	fixed = absi(seed_value)
	_made.clear()
	seed(fixed)


## Fix the seed for a test run: `-- --seed=<n>` if given (`--seed=random` leaves it unfixed), else
## DEFAULT. Returns the seed used, or -1.
static func fix_from_args(default_seed: int = DEFAULT) -> int:
	var chosen: int = default_seed
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			var v: String = arg.get_slice("=", 1)
			if v == "random":
				fixed = -1
				return -1
			chosen = int(v)
	fix(chosen)
	print("RngSeed: random rolls fixed to seed %d (-- --seed=<n> for another, --seed=random for the clock)" % fixed)
	return fixed


## Seed one of the game's generators: from the clock in play, from the fixed seed under a test.
static func apply(rng: RandomNumberGenerator, salt: String) -> void:
	if fixed < 0:
		rng.randomize()
		return
	var n: int = int(_made.get(salt, 0))
	_made[salt] = n + 1
	rng.seed = hash("%d/%s/%d" % [fixed, salt, n])
