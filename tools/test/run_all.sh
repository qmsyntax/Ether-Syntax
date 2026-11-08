#!/usr/bin/env bash
# Every automated test of the game, one Godot at a time (through tools/test/godot.sh and its machine-wide lock), with
# one summary table at the end. Exit code 0 only if every test that ran passed.
#
#   bash tools/test/run_all.sh [--headless|--windowed|--all] [--only=name,...] [--game=<dir>] [--logs=<dir>] [--list]
#
#   --headless   the headless tests only
#   --windowed   the windowed tests only (they open a window and MOVE THE REAL MOUSE - hands off while they run)
#   --all        both (the default)
#   --only=a,b   just these tests, by name (see --list); the import still runs first unless --no-import
#   --game=<dir> the Godot project to test (default: the game/ next to this script's tools/)
#   --logs=<dir> where each test's log goes (default: %LOCALAPPDATA%\Temp\ether-syntax-tests\<date-time>)
#   --no-import  skip the import step (only when game/.godot is already imported)
#   --list       print the tests and exit
#
# A test is judged by its own result line (each test prints one: "SELFTEST: N passed, 0 failed", "CASTALL: PASS",
# "MOVE: PASS", ...), by its exit code, and by script errors ("SCRIPT ERROR", parse errors) anywhere in its log. It is
# NOT judged by counting "ERROR" lines: Godot prints "... leaked at exit" / "resources still in use at exit" ERROR
# lines on shutdown that are noise. The import and the smoke run have no result line of their own, so for those two
# any ERROR line other than that shutdown noise fails them (CLAUDE.md's smoke check).
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
to_win() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s\n' "$1"; fi
}
to_unix() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -u "$1"; else printf '%s\n' "$1"; fi
}

# name | mode | strict (0/1: any non-noise ERROR line fails it) | timeout s | result line (extended regex, matched at line start) |
# godot arguments ({GAME} = the project). The timeouts are a few times the usual run: a script that fails to load
# leaves a test waiting forever, and it should cost minutes, not the lock's 20.
TESTS=(
  "import|headless|1|600||--headless --path {GAME} --import"
  "smoke|headless|1|600|shot: player at |--headless --path {GAME} --quit-after 400 -- --shot"
  "selftest|headless|0|600|SELFTEST: [0-9]+ passed, 0 failed|--headless --path {GAME} res://tests/selftest.tscn"
  "bot_dungeon|headless|0|600|BOT\[gate\]: .*-> PASS|--headless --path {GAME} -- --bot-dungeon"
  "bot_full|headless|0|600|BOT\[full\]: .*-> PASS|--headless --path {GAME} -- --bot-full"
  "bot_die|headless|0|600|BOT\[die\]: .*-> PASS|--headless --path {GAME} -- --bot-die"
  "castall|headless|0|600|CASTALL: PASS|--headless --fixed-fps 60 --path {GAME} res://tests/cast_every_skill.tscn"
  "timeline|headless|0|600|TIMELINE: PASS|--headless --fixed-fps 60 --path {GAME} res://tests/combat_timeline_probe.tscn"
  "zone|headless|0|600|ZONE: PASS|--headless --path {GAME} res://tests/zone_probe.tscn"
  "nether_death|headless|0|600|NETHERDEATH: PASS|--headless --path {GAME} res://tests/nether_death_probe.tscn"
  "nether_death_hc|headless|0|600|NETHERDEATH: PASS|--headless --path {GAME} res://tests/nether_death_probe.tscn -- --hardcore"
  "nether_stubble|headless|0|600|NETHERSTUBBLE: PASS|--headless --path {GAME} res://tests/nether_stubble_probe.tscn"
  "stubble_bot|headless|0|600|STUBBLEBOT: PASS|--headless --path {GAME} res://tests/stubble_bot.tscn"
  "duels|headless|0|1000|DUELS: PASS|--headless --path {GAME} res://tests/newbie_duels.tscn"
  "full_ring|headless|0|600|FULLRINGS: .* 0 script errors|--headless --path {GAME} res://tests/full_ring_check.tscn"
  "ui_click|windowed|0|600|UICLICK: PASS|--path {GAME} res://tests/ui_click_probe.tscn"
  "ui_click_field|windowed|0|600|UICLICK: PASS|--path {GAME} res://tests/ui_click_probe.tscn -- --field"
  "test_character|windowed|0|600|TESTCHAR: PASS|--path {GAME} res://tests/test_character_probe.tscn"
  "creation|windowed|0|600|CREATE: PASS|--path {GAME} res://tests/creation_probe.tscn"
  "game_menu|windowed|0|600|GAMEMENU: PASS|--path {GAME} res://tests/game_menu_probe.tscn"
  "ascension|windowed|0|600|ASCEND: PASS|--path {GAME} res://tests/ascension_probe.tscn"
  "move|windowed|0|900|MOVE: PASS|--path {GAME} res://tests/move_probe.tscn"
)

# Godot's shutdown chatter, printed as ERROR lines by a clean run.
NOISE='leaked at exit|resources still in use at exit|Pages in use exist at exit|ObjectDB instances leaked|instances leaked at exit'
# A GDScript runtime error, or a script that failed to load: always a failure.
FATAL='SCRIPT ERROR|Parse Error|Failed to load script|Failed loading resource'

MODE=all
ONLY=""
GAME="$HERE/../../game"
LOGS=""
IMPORT=1
LIST=0
for arg in "$@"; do
  case "$arg" in
    --headless) MODE=headless ;;
    --windowed) MODE=windowed ;;
    --all) MODE=all ;;
    --only=*) ONLY="${arg#--only=}" ;;
    --game=*) GAME="${arg#--game=}" ;;
    --logs=*) LOGS="${arg#--logs=}" ;;
    --no-import) IMPORT=0 ;;
    --list) LIST=1 ;;
    -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
    *) echo "run_all.sh: unknown argument $arg (see --help)" >&2; exit 2 ;;
  esac
done

if [ "$LIST" -eq 1 ]; then
  for t in "${TESTS[@]}"; do
    IFS='|' read -r name mode strict limit pass args <<< "$t"
    printf '%-16s %-9s %s\n' "$name" "$mode" "$args"
  done
  exit 0
fi

if [ ! -f "$GAME/project.godot" ]; then
  echo "run_all.sh: no project.godot in $GAME" >&2
  exit 2
fi
GAME_W="$(to_win "$(cd "$GAME" && pwd)")"
if [ -z "$LOGS" ]; then
  LOGS="$(to_unix "${LOCALAPPDATA:-$HOME/AppData/Local}")/Temp/ether-syntax-tests/$(date +%Y%m%d-%H%M%S)"
fi
mkdir -p "$LOGS"

# which tests run
if [ -n "$ONLY" ]; then
  for want in ${ONLY//,/ }; do
    found=0
    for t in "${TESTS[@]}"; do
      [ "${t%%|*}" = "$want" ] && found=1
    done
    if [ "$found" -eq 0 ]; then
      echo "run_all.sh: no test named $want (see --list)" >&2
      exit 2
    fi
  done
fi
selected=()
for t in "${TESTS[@]}"; do
  IFS='|' read -r name mode strict limit pass args <<< "$t"
  if [ "$name" = "import" ]; then
    [ "$IMPORT" -eq 1 ] && selected+=("$t")
    continue
  fi
  if [ -n "$ONLY" ]; then
    case ",$ONLY," in *",$name,"*) selected+=("$t") ;; esac
  elif [ "$MODE" = all ] || [ "$MODE" = "$mode" ]; then
    selected+=("$t")
  fi
done

echo "run_all.sh: ${#selected[@]} tests, game $GAME_W, logs $LOGS"
case " ${selected[*]} " in *"|windowed|"*) echo "run_all.sh: windowed tests move the real mouse - hands off while they run" ;; esac

ROWS=()
FAILED=0
for t in "${selected[@]}"; do
  IFS='|' read -r name mode strict limit pass args <<< "$t"
  log="$LOGS/$name.log"
  args="${args//\{GAME\}/$GAME_W}"
  start=$(date +%s)
  # shellcheck disable=SC2086 # the argument list is meant to split on spaces
  GODOT_TIMEOUT="$limit" bash "$HERE/godot.sh" $args > "$log" 2>&1 < /dev/null
  code=$?
  secs=$(( $(date +%s) - start ))
  # the time Godot ran, without the wait for the lock (godot.sh says how long it waited)
  waited_s="$(grep -E -m1 '^godot.sh: waited [0-9]+s' "$log" | grep -E -o '[0-9]+' | head -1)"
  secs=$(( secs - ${waited_s:-0} ))
  why=""
  line=""
  if [ -n "$pass" ]; then
    line="$(grep -E -m1 "^($pass)" "$log" | sed 's/\r$//')"
  fi
  fatal="$(grep -E -c "$FATAL" "$log")"
  if [ "$code" -eq 124 ]; then
    why="timed out after ${limit}s"
  elif [ "$code" -ne 0 ]; then
    why="exit code $code"
  fi
  if [ -n "$pass" ] && [ -z "$line" ]; then
    why="${why:+$why; }no result line /$pass/"
  fi
  if [ "$fatal" -gt 0 ]; then
    why="${why:+$why; }$fatal script error lines"
  fi
  if [ "$strict" = 1 ]; then
    other="$(grep -E 'ERROR' "$log" | grep -E -v "$NOISE" | grep -E -v "$FATAL" | grep -c .)"
    if [ "$other" -gt 0 ]; then
      why="${why:+$why; }$other ERROR lines"
    fi
  fi
  if [ -z "$why" ]; then
    result=PASS
    note="${line:-clean}"
  else
    result=FAIL
    FAILED=$((FAILED + 1))
    # the test's own failure lines say most
    first_fail="$(grep -E -m1 '(: FAIL|  FAIL |SCRIPT ERROR|-> FAIL)' "$log" | sed 's/\r$//')"
    note="$why${first_fail:+ | $first_fail}"
  fi
  printf '== %-16s %s  %4ss  %s\n' "$name" "$result" "$secs" "${note:0:160}"
  ROWS+=("$(printf '%-16s %-9s %-5s %5s  %5s  %s' "$name" "$mode" "$result" "$code" "${secs}s" "${note:0:140}")")
done

echo
echo "test             mode      result exit   time  result line / why it failed"
echo "---------------- --------- ------ ----- ------ ---------------------------------------------"
for r in "${ROWS[@]}"; do
  echo "$r"
done
echo
if [ "$FAILED" -eq 0 ]; then
  echo "ALL PASS (${#ROWS[@]} tests; logs in $LOGS)"
  exit 0
fi
echo "FAILED: $FAILED of ${#ROWS[@]} (logs in $LOGS)"
exit 1
