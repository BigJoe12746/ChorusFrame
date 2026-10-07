# HONEY FARM: what was tested, and what still needs Roblox Studio

This is the honest split between what I could verify from a Linux container with no Roblox client, and what only a real Studio or published-place playtest can confirm.

## How the offline testing works

I had no way to run Roblox here, so I built a small stand‑in for the engine (`tests/mock/Roblox.luau`): Instances with parents/attributes/signals, `Vector3`/`CFrame` maths, `Random`, `Enum`, a `Players` service with fake players and characters, `RunService.Heartbeat`, `ProximityPrompt.Triggered`, RemoteEvents that record what they fired, an in‑memory DataStore with knobs for failures and unavailability, and a simulated clock that only advances when a scenario ticks.

`tests/run_sim.py` loads the **real, unmodified game scripts** (`src/shared` and `src/server`) into that stand‑in laid out exactly like `default.project.json`, then runs a scenario that drives them the way players would: joining, walking to a station, pressing E, sending shop/upgrade remotes, leaving, rejoining hours later. Nothing in the server code knows it's being tested.

What the stand‑in is **not**: a renderer, a physics engine, a network, or a real DataStore. Anything about how the game looks, feels, sounds or performs is in the "needs Studio" list below.

Run everything from `roblox/honey-farm`:

```
luau tests/PlotAllocator.spec.luau
luau tests/FarmState.spec.luau
luau tests/RateLimiter.spec.luau
python3 tests/run_sim.py --luau <path to luau> --scenario tests/phaseN.scenario.luau   # N = 1..8, or props
```

Pressing a station in a scenario means firing the plate's `Touched` signal for the Hive, Bottling and Stand (Lemonade's pressure plates) or the prompt for the Bee Shop; the mock's `task` library is coroutine based with a simulated clock, so retry back-offs and cooldowns really elapse when a scenario ticks.

Plus `luau-lsp analyze` against the Roblox API definitions (type check) and `rojo build` (the place file builds).

## Tested here (passing)

### Unit tests on pure modules

| Module | Checks | Covers |
|---|---|---|
| `PlotAllocator` | 17 | separate plots, no double assignment, release and reuse, queue when full, hand‑over, rejoin |
| `FarmState` | 134 | production rate, hive cap + lost honey, backpack cap, 1 jar/s, $5/jar, double‑collect never pays twice, 3,000‑step conservation run with random frame times, shop prices and exact charges, 8‑slot cap, merge rules (same bee, missing bee, different tier, top tier of 50), ×2.5 production, discoveries, upgrade levels/values/prices, maxed/unaffordable refusals, multiplier, faster bottling, bigger backpack, 9th bee after the slot upgrade, save round‑trip, hostile save data clamped, offline honey (rate × time, 8‑h cap, hive‑room cap, credited once), introduction steps can't skip and are saved, egg odds and scripted hatches, shiny rolls, cash rebirth cost/reset/keeps/×1.75 stacking |
| `RateLimiter` | 8 | window, reset, per‑key buckets, 100‑call burst passes exactly 25 |

### Scenarios through the real server scripts

| Scenario | Checks | Covers |
|---|---|---|
| Phase 1 | 124 | map built with 6 plots and all stations; two players get separate plots and spawn on them; owner sign shows name + avatar; My Farm (incl. spam and visiting); respawn goes home; owner‑only stations; leaving clears the plot; rejoin; 7th player queued |
| Phase 2 | 41 | 25 Cash + bee model; produce → collect → deposit → 50 jars → $250 → collect; empty hive, full hive, full backpack, double‑press deposit, double collect, press from across the map ignored, visitor refused, two farms independent, leaving clears, next owner starts fresh |
| Phase 3 | 357 | all 50 tiers build from a stand‑in of the template (roles, accessory, one head, scale, unique look); shop opens from the prompt; buy at $25; refused with $0 / far away / 8 slots; rapid presses buy exactly 6 at the exact rising prices; merge → Clover (models swapped, production, discovery event); bad merges change nothing; second Clover not a discovery; Royals can't merge; another player's buy never touches your farm |
| Phase 4 | 42 | config sanity; refused without cash and off‑plot; hive storage 120/250 with mini hives and exact charges; bottling 2 jars/s and a tank; production ×1.25 + pollen orb; backpack; slot upgrade → 9th bee; two presses = two levels; maxed refused; garbage ids ignored; conservation with upgrades; other player can't upgrade your farm; next owner at level 1 |
| Phase 5 | 29 | new player loads empty; leave saves with timestamp; rejoin 2 h later restores everything and credits offline honey capped by hive room, once; 30 h counts as 8 h; autosave; failed load → temporary farm, never written; transient failure still loads; newer save elsewhere not overwritten; BindToClose saves everyone; unavailable DataStores reported and write nothing |
| Phase 6 | 32 | steps point at real stations; built‑in sound ids; early presses don't skip; each real action advances one step with the matching Feedback event; bonus pays once; finished stays finished; saved and restored; second player has their own |
| Phase 8 | 50 | eggs with scripted dice (odds → kind → variant), egg bees build and can't merge, shiny merges and inheritance, cash rebirth (cost, reset, keeps egg bees, ×1.75 multiplier), everything saved and restored |
| Props | 173 | Creator Store stand-ins for trees/cottages/hive, scripts stripped, scaled and grounded, per-level `Hive2`/`Hive3` swap with Hive Storage and reset on release, block flowers and no fountain by design, hive base has a pressure plate |
| Phase 7 | 37 | **two players at once**: Bob refused at all five of Alice's stations with nothing changed on either farm; remotes can only hit the sender's farm; both hives cap and count lost honey; full backpack; insufficient funds for bee and upgrade; 100 hive presses move only the honey that exists; 100 Buy presses → 8 slots, exactly 7 purchases charged; 100 Upgrade presses with $300 → exactly the two affordable levels, cash never negative; limiter is per player; 30 merge presses on one pair = one merge; conservation on both farms; both saved and restored independently; offline rewards use each farm's own away time and rate; a queued 7th player gets the freed plot and loads *his own* save |

### Static checks

- `luau-lsp analyze` with the Roblox API definitions: 0 errors across `src/`.
- `rojo build`: `HoneyFarm.rbxl` builds.

## Server authority audit (Phase 7)

Everything that changes money, honey, bees or upgrades runs in `FarmService` on the server; clients only read attributes.

| Risk | Defence |
|---|---|
| Client fakes cash / honey | Attributes are set by the server; client‑side attribute writes don't replicate. All HUD numbers are read‑only mirrors. |
| Using another player's station | `PlotService.hookPrompt` checks `OwnerUserId` before firing `StationTriggered`; `FarmService` re‑checks `farm.Plot == plot`. |
| Pressing from across the map | Server distance check against the station part (`Config.PromptDistance` + slack). Roblox also enforces `MaxActivationDistance` client‑side. Pressure plates only fire for the touching player's own character, with a 2 s per-player cooldown per plate. |
| Shop / upgrade remotes with a spoofed plot | The remotes take **no plot argument**; they can only act on the sender's own farm. Shop requires being at *your* shop; upgrades require standing on *your* plot. |
| Wrong price / free items | Prices come from `FarmState` + `Config` on the server; the client only displays them. |
| Over capacity | Every transfer is `min(available, room)` inside `FarmState`; capacities derive from server‑side upgrade levels. |
| Double purchases / double collects | Each action is one atomic function; `Farm.Busy` guards re‑entry; a second collect finds nothing to move. Tests spam 100 presses and verify exact outcomes. |
| Flooding | `RateLimiter`: 25 remotes/s and 25 prompt presses/s per player; excess dropped before any economy code runs, one warning logged. |
| Bad arguments | Type checks on every remote (`Merge` ids must be numbers, upgrade id must be a known string); unknown values are ignored silently. |
| Stale or hostile save data | `FarmState.Deserialize` clamps and drops rather than crashing; a failed load never overwrites; newer saves win. |

## Performance notes

- The map is ~2,450 anchored parts, all built once at server start; nothing on it moves or simulates physics.
- Bee flight is **client‑side only**; the server never moves a bee. Bees more than 220 studs from the camera are frozen, 90–220 studs update at 1/4 rate, so six full farms cost about the same as one.
- Conveyor jars are local parts (not replicated), capped at 12 visible per plot; the economy still counts every jar.
- Attribute replication only fires on change; the one value that changes every frame while bottling (`BottlingProgress`) is quantised to 1/20.
- Effects use short‑lived anchored parts with `Debris`, not `ParticleEmitter`s left running.

## Still needs Roblox Studio (not verifiable here)

Things that need eyes, ears, a phone, or a real DataStore:

**Phase 8 and the Lemonade merge**
- [ ] Egg odds in the shop read clearly; hatching feels good (wobble, crack, card); the 50 egg bees look distinct and sit well on the farm (they use only colours/materials, no accessories).
- [ ] Shiny bees are visibly special (neon stripes + sparkles).
- [ ] The Rebirth panel's cost and ×1.75 text match the HUD, and a rebirth can't be triggered by accident on a phone.
- [ ] Pressure plates trigger reliably when walking over them (not only when standing still) and the hive plate flash is visible but not annoying.
- [ ] Tiers 11–50 look distinct enough in the shop and collection book (they are recolours only).
- [ ] Robux shop: after creating Developer Products on the site and pasting their ids into `Config.Shop`, a test purchase in Studio grants the cash once. Until then the buttons read SOON and nothing is sold.
- [ ] Leaderboards in the village fill in after a save (they need DataStore access) and refresh on the interval.

**Looks**
- [ ] The map reads as bright and cartoonish; paths are walkable; nothing blocks a gate or a path.
- [ ] Each of the ten bee tiers looks right and distinct; accessories sit on the bee (offsets at the top of `BeeAppearance.lua`). Quick way to see one: in Play, command bar → `require(game.ServerScriptService.HoneyFarm.FarmService).GetState(game.Players.YourName):AddBee("Galaxy")`.
- [ ] Bees fly head‑first, wings up (swap the two axes under "Canonical pivot" in `BeeAppearance.Build` if not).
- [ ] Jars visibly ride the conveyor and vanish into the stand; mini hives / tank modules sit cleanly on their pads.

**Feel**
- [ ] Camera, zoom limits and movement feel comfortable.
- [ ] Honey streams, coin bursts, floating "+$X", the merge sparkle, the welcome‑back card and the discovery banner feel good (tune counts/sizes in `Effects.client.lua`, `MergeEffects.client.lua`).
- [ ] Sounds: the built‑in client sounds suit the game (swap any id in `Config.Sounds`); paste a bee‑buzz loop into `Config.Sounds.Buzz` and check it's quiet and local.

**Phone**
- [ ] No panel or button overlaps the thumbstick (bottom‑left) or jump button (bottom‑right); the tutorial card, toasts and stats fit a small landscape screen.
- [ ] Shop, Upgrades and Collection panels are readable and tappable; they close by X, Esc, or walking away (shop).

**Multiplayer (Test → Clients and Servers → 2 players)**
- [ ] Each player spawns at their own gate with their name and avatar on the sign.
- [ ] Visitors see no prompts on your farm; you see yours.
- [ ] Both players' effects, labels and bee flight look right from each other's screens.

**Saving (Studio with "Enable Studio Access to API Services", or a published place)**
- [ ] Play → leave → rejoin restores everything; the welcome card's away time and honey look right.
- [ ] Leave 10+ minutes: offline honey is in the hive.
- [ ] Real DataStore latency: joining still feels fine while "loading…" shows.
- [ ] With API access off: the "Saving is unavailable" message appears.

**Performance**
- [ ] Frame rate on a mid‑range phone with six farms full of bees and belts running.

## Release checklist

1. Game Settings → Places → **Server size 6** (one plot each; a 7th player waits and is told so).
2. Game Settings → Security → **Enable Studio Access to API Services** (for saving in Studio).
3. Decide `Config.Save.StoreName`: changing it later wipes everyone's progress (useful for a pre‑launch reset).
4. Create the five Developer Products (Creator Dashboard → Monetization) and paste their ids into `Config.Shop[*].ProductId`; leave 0 to keep the shop in SOON mode.
5. Optionally paste a bee‑buzz asset into `Config.Sounds.Buzz`.
6. Playtest the Studio list above with two clients, once on a phone‑sized viewport.
