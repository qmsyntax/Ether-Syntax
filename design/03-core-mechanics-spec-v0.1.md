# Core mechanics spec v0.1 — turning the universe's laws into game rules

Every rule is tagged: **[CANON]** follows the books/Brent's rulings, **[MODEL]** is our invention to make a
canon idea playable (numbers are starting values for tuning, not lore).

## 1. Body: HP in three layers
[MODEL] Damage lands in one of three layers, by what the hit did:
| Layer | Examples | Native heal price |
|---|---|---|
| Superficial | cuts, bruises, burns | 1 heal point / HP |
| Structural | fractures, deep wounds, organ damage | 10 / HP |
| Catastrophic | lost limb, destroyed organ | 100 / HP |
- Catastrophic wounds disable what they hit (no arm = no two-handed weapon, no strike techniques on that side).
- Death = brain destruction or all layers emptied. [CANON: brain is the kill condition]

## 2. The title talent
- [CANON] Heal income = **1% of damage dealt to anything alive**, capped at the target's remaining HP (no overkill). DoTs you caused pay. Summon kills pay. Scenery counts — grass, trees, vermin.
- [CANON] Big creatures carry more vitality. [MODEL] Monster HP pools are large relative to the player (1★ skirmisher ≈ 300 HP; giant-class ≈ 50,000) so a fight yields only a few heal points, but a cleared room plus a trampled meadow yields a real top-up.
- [CANON] **1★ = Supreme only.** [MODEL] Every HP costs 100 points regardless of layer. Painfully slow, but it *can* regrow anything.
- [CANON] **2★ = Dynamic.** [MODEL] Each HP costs its layer's native price. Same income, up to 100× more superficial healing. This is the first "talent evolution" the player feels.
- [CANON] Never restores: essence, sleep/soul exhaustion, soul damage, psychological trauma.
- [MODEL] **Hidden technicality flags**, rolled per save and discovered by play (the notebook records each once proven): does it pay on constructs? on undead? on damage dealt by thrown environment? through armour bleed? while unconscious?

## 3. Essence, satellites, reflux
- [CANON] Each **star is an independent tank** (100 units each). Abilities cost units (instant) or units/second (sustained).
- [CANON] **Satellite** supplies free throughput: rank N satellite = **N units/second**. Sustained abilities at or under that rate never touch the tanks.
- [CANON] Every unit that flows through the body — from a tank *or* the satellite — leaves **reflux** in that affinity's gauge.
- [CANON, Brent] The body **sheds reflux naturally**, and **meditation purges it faster**. It is a real limiting mechanic, not flavour.
- [MODEL] Reflux: +1 per unit spent; natural shedding 0.05/s in combat, 0.2/s out of combat; **meditating: 2/s**, but you are stationary and defenceless — so where you stop to meditate inside a sealed dungeon is a tactical decision (and meditation is also how you enter the Netherecho, so the two risks stack). 50 = pain (costs +25%), 80 = each cast deals structural self-damage, 100 = that affinity locks until below 60. A tempering technique improves decay. An awakened construct purges ~1 per kill. [CANON for the last two]
- [CANON] Raw manipulation: free-form, weak, no reflux, always available.

## 4. Latent aura (hidden XP)
- [CANON] Never shown as a number. [MODEL] The notebook gives only qualitative reads ("the star feels heavy").
- [MODEL] Gain per encounter = base × risk, where risk rises with: enemy rank above yours, how low your HP went, solo, no consumables used, first time facing that enemy type. Safe farming trends to zero. Arena = zero. [CANON]
- [CANON] At threshold you may ascend: **talent evolves + a new star (tank) splits off**. Over-filling improves the ascension.
- [CANON, Brent] **Spirit abilities compress latent aura: 33% / 66% / 99%** for one / two / three held. Only the uncompressed remainder counts toward the threshold, so effective ascension cost is **×1.5 / ×2.9 / ×100** (1 ÷ 0.67, 0.34, 0.01). The third slot is the canon "Triple Block ×100" — same rule, not a separate one.
- [CANON] The compressed aura isn't lost: it is released at ascension as a **bigger talent jump**. [MODEL] Jump multiplier = the same factor (×1.5 / ×2.9 / ×100), applied to the talent-evolution roll and the new star's quality. A player can rush stars with none, take one or two for a modest tax, or commit to three and sit at their current star as a monster for a very long time — with an absurd payoff if they ever break through.
- [CANON, Brent] Latent aura is a **pool**, and compression acts on the **whole pool** — everything you have, not just what you earn afterwards. [MODEL] Raw pool R is never reduced; *effective* progress = R × (1 − 0.33 × spirit abilities held). Taking a spirit ability therefore visibly knocks you back from the threshold on the spot (e.g. 90% ready → ~60%), and the notebook's read on the star changes accordingly. Nothing is lost — the full raw pool is what gets released at ascension.
- [CANON] Stars can be lost; re-climb is faster along the same build; a severing elixir resets the path.

## 5. Abilities
- [CANON] Scroll-learned, affinity-gated. Stage 0→N with a progress bar from use; stage cap = stars + 1.
- [CANON] Advancing a stage requires **binding a construct** of the matching tier (vestige 0→1, remnant 1→2, spirit 2→3, eidolon 3→4). The construct's **concept** determines the named upgrade (tension, acceleration, piercing…).
- [CANON] Binding = find it in the Netherecho, **subdue** it, bind. Irreversible. Can fail. It can kill you. [MODEL] Netherecho encounters are short, brutal duels fought with the soul construct; your projection has tiny HP.
- [CANON] No cap on ability count. **Tempering techniques all run at once**; [MODEL] each is trained in sessions that deal real structural damage to you — affordable only because of §2.
- [CANON] Using a technique above your tempering injures you.

## 6. Dungeons
As in concept draft §4 (seal, halfway gate, escalation, contribution loot, diminishing repeats, closable).
- [CANON] Each dungeon's rules are fixed by the universe when it forms → [MODEL] every generated dungeon rolls a visible **rule card** (party cap, exit condition, what may be carried out, hazards).
- [CANON] Difficulty shown only as a recommendation ("high 2★ solo", "party of 1★s").
- [CANON] Monsters have native stars, affinities and talents; deviants have off-pattern talents.

## 7. Gear
- [CANON] Secondary to the body. One small effect per item; three-item sets; growing uniques. Sources: crafted, quest, reward, drop.

## 8. What the first playable must prove
1. 1% feels useless in a fight and essential between fights.
2. Limb-cost overcharge + reflux heat make aggression the right answer.
3. The Supreme→Dynamic evolution at 2★ is a felt power spike.
4. Hidden aura pushes players toward risk without a visible bar.
