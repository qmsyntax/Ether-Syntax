# Talent design framework v0.1

Decision (Brent, 2026-09-18): players do **not** all get 1% Lifesteal. The game ships with a large,
varied talent pool; the title talent is one entry among many. The roster lives in
`game/data/talents.json` (40 entries at v0.1: 3 from the books, 37 original).

## What makes something feel like a talent from this universe
1. **One sentence, permanent, and narrow.** A talent is a single odd rule, not a class or a kit.
2. **The vestige states it cryptically** (`verse`) and cannot or will not clarify edge cases.
3. **Its worth lives in the technicalities.** Each talent carries 3–5 `hidden` yes/no flags that are
   rolled per save and proven only by experiment. Two players with the same talent may not have the same talent.
4. **Looks weak, isn't (or looks strong, has a catch).** The market misprices talents; the player can profit from understanding theirs.
5. **It evolves at each star** (`evolve_2`, later `evolve_3`…). Evolutions widen the rule or remove its sharpest limit — they never replace it.
6. **It pairs with affinities it didn't choose.** Affinities are rolled separately (1 common, 2 uncommon, 3 rare), so the same talent plays differently as water, blood, earth…
7. **Non-combat talents are real options**, because the hub economy (hauling, appraisal, contracts, auctions) is half the game.

## Categories (aim for 12+ each at content-complete)
sustain · offense · defense · mobility · perception · trade · bond · netherecho · body

## Templates for generating more
- **Conversion**: turn resource A into B at a bad rate that becomes good under a condition (1% Lifesteal; Weight of Coin; Furnace Gut).
- **Counter**: every Nth of something is special (Tenth Strike; Long Step).
- **Deferral**: move a cost through time (Debt of Pain; Borrowed Breath; Slow Blood).
- **Ledger**: permanent tiny gains from a repeatable misfortune (Scar Ledger; Grudge).
- **Exemption**: ignore one universal rule of the game (Clean Channel: no satellite reflux; Anchor: no stationary meditation; Unfalling).
- **Revelation**: see one hidden layer of the simulation (Ledger Eyes; Fine Print; Concept Tongue; Price Sense).
- **Extension of self**: more body, or body that misbehaves (Rat Tail; Borrowed Hands; Spare Parts).
- **Claim**: something in the world becomes yours briefly (Loyal Dead; Swarm Keeper).

## Balance rules
- No talent may give free in-combat healing that outpaces incoming damage at equal rank. Sustain talents pay out *between* fights or at a price.
- Every talent must interact with at least one core system: wound layers, essence/satellite, reflux, latent aura, Netherecho, dungeon rule cards, or the dollar economy.
- A talent's hidden flags must include at least one that could be a nasty surprise and one that could be a jackpot.
- `value` (junk / low / mid / high) is the *market's* opinion, used for prime prices — not actual power.

## How a player gets one
Character creation mirrors the books' opening: you survive a break, a prime manifests (random, often non-combat),
and a broker offers trades. You can keep it, swap down for cash + a cheaper prime, or pay up. The broker is not your friend.

## Implementation
Talents are data. Each `rule` maps to one or more effect hooks (on_damage_dealt, on_damage_taken,
on_kill, on_lethal, on_step, on_ability_cast, on_reflux_cap, perception overlays, economy modifiers).
Hidden flags are booleans read by those hooks and stored in the save, with a `discovered` bit that the notebook UI reads.
