# 🍯 HONEY FARM

A colourful multiplayer bee‑farming tycoon. Players own a garden plot, buy bees, make honey, bottle and sell it, merge bees, and expand their farm.

**Status: Phase 1 (map and plots) and Phase 2 (the honey loop) are done.** Phases 3–7 are the roadmap below.

| Whole map (top‑down, generated from the real scripts) | One plot |
|---|---|
| ![map](docs/map_topdown.png) | ![plot](docs/plot1_topdown.png) |

## Quick start

1. Open **`HoneyFarm.rbxl`** in Roblox Studio.
2. Press **Play**. The map builds itself, you're given a farm, and you appear inside its gate.
3. To test two players: go to **Test → Clients and Servers**, set **2 Players**, and click **Start**.

The map is built by a script when the game starts, so in **Edit** mode the world looks empty. To see and edit the map in Edit mode, paste this into the Studio **command bar**:

```lua
require(game.ServerScriptService.HoneyFarm.MapBuilder).Build()
```

That creates `Workspace.HoneyFarmMap`. If a map with that name already exists, the game keeps it and doesn't rebuild it, so any edits you make there are preserved.

### Manual setup before publishing

- **Game Settings → Places → Server size: 6.** There are 6 plots. A 7th player still works: they wait in the village and get the next plot that frees up.
- Avatars on the plot signs only load in a published game or in Studio while you're signed in.

## What Phase 1 includes

| Requirement | Where |
|---|---|
| Bright map: grass, wooden fences, giant flowers, honey accents, round cartoon cottages, honey fountain, benches, trees | `MapBuilder.lua` |
| 6 personal farm plots around a central village square, each connected by a clear path | `MapBuilder.Build` |
| Each joining player is assigned a free plot automatically | `PlotService` + `PlotAllocator` |
| Owner's name and avatar on a sign above the plot entrance (readable from both sides) | `PlotService.setSign` |
| Every plot has a Hive, Flower Patch, Bee Shop, Bottling machine (with conveyor) and Honey Stand | `MapBuilder.build*` |
| Reserved space for future hives and machines ("Future Hives", "Future Machines" pads) | `Expansion` folder in each plot |
| "My Farm" button (top centre, out of the way of the mobile controls), plus the **H** key | `FarmClient.client.lua` |
| Normal third‑person camera, zoom limited to 6–70 studs so the farm stays visible | `default.project.json` |
| Visitors can walk on other farms; station prompts only appear for the owner and are also checked on the server | `FarmClient` + `PlotService.hookPrompt` |
| Plots are released when players leave, and the plot's `Temp` folder is cleared | `PlotService.onPlayerRemoving` |
| Respawning puts you back on your own farm | `PlotService.onCharacterAdded` |

## What Phase 2 includes: the honey loop

```
bees → hive storage → backpack (E at the Hive) → bottling queue (E at Bottling)
     → jar rides the conveyor (1 jar/sec, 3 s trip) → +$5 at the stand → cash (E at the Honey Stand)
```

| Requirement | Where |
|---|---|
| New player: one Starter Bee and 25 Cash | `Config.Economy`, `FarmState.new` |
| The bee flies between the flower patch and the hive (local animation, zero network cost) | `BeeFlight.client.lua` |
| Starter Bee makes 1 honey every 5 s, stored in the hive; the hive shows its amount | `FarmState.Tick`, `StationLabels.client.lua` |
| Collect with E / tap (ProximityPrompt) into a backpack of 50 | `Hive` prompt → `FarmService.actions.Hive` |
| Deposit at the bottling station; 1 honey → 1 jar per second | `actions.Bottling`, `FarmState.Tick` |
| Jars animate down the conveyor to the stand | `ConveyorJars.client.lua` (server fires `JarStarted`) |
| Each finished jar adds $5 to the stand's unclaimed balance; collect it at the stand | `FarmState.Tick`, `actions.SellStand` |
| HUD shows Cash, carried honey, hive storage, bottling progress and cash waiting at the stand | `FarmHud.client.lua` |
| Everything authoritative on the server; clients only read attributes | `FarmService` |
| Ownership **and distance** checked on the server before any station works | `PlotService.hookPrompt` |

All rates and sizes are in `Config.Economy` (`src/shared/Config.lua`). The economy itself is `src/shared/FarmState.lua`: plain data and five functions (`Tick`, `CollectHive`, `Deposit`, `CollectCash`, `AddBee`). Each one moves an exact amount from one bucket to the next, which is what stops double-counting. In Phase 5 that table is what gets saved.

Hive capacity is 50 to start, so the hive fills in about 4 minutes with one bee and honey made while it's full is lost. That's intentional pressure to come back and collect; Phase 4 upgrades raise it.

The Bee Shop still says "opens in the next update". That's Phase 3.

### Hooks for later phases

- `PlotService.GetPlot(player)`, `PlotService.IsOwner(player, instance)`, and the `PlotAssigned`/`PlotReleased` events.
- `FarmService.GetState(player)` returns the live `FarmState`; `PlotService.StationTriggered` fires `(player, plot, station)` only after the owner + distance checks.
- `Plot.Temp` holds the bee models and is cleared automatically when the owner leaves.
- Marker parts: `Hive/BeeExit`, `FlowerPatch/FlowerSpots/Spot1‑9`, `Bottling/DepositPoint`, `Conveyor/ConveyorStart`/`ConveyorEnd`.
- `ReplicatedStorage.Assets.BeeTemplate` is your original bee model: the Starter Bee, the shop display bee, and the base for the 10 tiers.

## Project layout (Rojo)

```
default.project.json          how files map into the game
HoneyFarm.rbxl                 built place file, ready to open
src/shared/   → ReplicatedStorage.HoneyFarm   Config, PlotAllocator, FarmState
src/server/   → ServerScriptService.HoneyFarm  Main, MapBuilder, PlotService, FarmService
src/client/   → StarterPlayerScripts.HoneyFarm FarmClient, FarmHud, StationLabels, BeeFlight, ConveyorJars
assets/BeeTemplate.rbxm → ReplicatedStorage.Assets.BeeTemplate
tests/                          offline tests (see below)
```

Rebuild the place file after editing the scripts: `rojo build default.project.json -o HoneyFarm.rbxl` (Rojo 7.7+). Or run `rojo serve` and use the Rojo Studio plugin to sync live.

You can change all the sizes, colours and the plot count in `src/shared/Config.lua`.

## Testing

| Test | How | Result |
|---|---|---|
| Plot assignment logic: separate plots, no double assignment, release, queue when full, rejoin | `luau tests/PlotAllocator.spec.luau` | 17/17 pass |
| Economy logic: production rate, hive cap and lost honey, backpack cap, 1 jar/sec, $5 per jar, collecting twice never pays twice, and a 3,000‑step conservation run with random frame times (every honey is in the loop or already paid out) | `luau tests/FarmState.spec.luau` | 27/27 pass |
| Full Phase 1 scenario: the **real** server scripts run against a small mock of the Roblox engine. Builds the map, two players join, spawn on separate farms, use **My Farm** (including spam and visiting), respawn, owner‑only stations, leave and clear the plot, rejoin, a full server with a 7th player queued | `python3 tests/run_sim.py --luau <path to luau> --render out/` | 123/123 pass |
| Full Phase 2 scenario: new player gets 25 Cash + a bee model; produce → collect → deposit → 50 jars → $250 → collect; empty hive, full hive, full backpack, double‑press deposit, double collect, press from across the map (ignored), visitor refused, two farms producing independently, leaving clears state, next owner starts fresh | `python3 tests/run_sim.py --luau <luau> --scenario tests/phase2.scenario.luau` | 41/41 pass |
| Type check against the Roblox API definitions | `luau-lsp analyze` with Roblox definitions and a Rojo sourcemap | no errors |
| Place file builds | `rojo build` | ok |

**Still needs a real Roblox Studio playtest.** The mock above isn't a physics or rendering engine. Please check:
- [ ] With 2 players, each player appears inside their own gate, and the signs show their name and avatar.
- [ ] Walking, jumping and the camera feel comfortable on paths and through gates. Nothing blocks a path.
- [ ] The **My Farm** button and the **H** key work. On a phone, the button doesn't overlap the thumbstick or jump button.
- [ ] Visitors don't see station prompts on someone else's farm. The owner does (key **E**, or tap).
- [ ] When a player leaves, their sign resets to "Free Farm", and a new joiner can take that plot.
- [ ] Part count and frame rate are fine on mobile (the map is about 2,400 anchored parts).

Phase 2 (needs a real client, the mock has no rendering):
- [ ] The bee visibly flies between the flower patch and the hive and faces the way it moves (if it flies sideways, change `Config.BeeFlight.YawOffset`).
- [ ] The hive label counts up: 1 honey every 5 seconds.
- [ ] Walk up to the hive: the **E / tap** prompt says "Collect Honey" and the HUD's CARRYING bar fills.
- [ ] Deposit at Bottling: jars appear one per second and slide down the conveyor to the stand; the stand label shows "$X ready!".
- [ ] Collect at the stand: the Cash number pops. Numbers in the HUD, the labels and the chat messages all agree.
- [ ] Try it on a phone-sized viewport: the stats panel (top‑left) doesn't cover the thumbstick.

## Roadmap

- [x] **1. Map and player plots**
- [x] **2. First playable honey loop**: Starter Bee, 25 Cash, hive storage, backpack (50), bottling at 1 jar/sec, conveyor, 5 Cash per jar, collect at the stand
- [ ] **3. Bee shop and merging**: 10 tiers (Starter, Clover, Daisy, Strawberry, Panda, Knight, Crystal, Storm, Galaxy, Royal); each merge is ×2.5 production
- [ ] **4. Farm upgrades**: production, hive storage, backpack, bottling speed, bee slots
- [ ] **5. Saving and offline honey**: DataStore, autosave, offline earnings capped at 8 hours
- [ ] **6. Interface and introduction**: tutorial, collection book, effects and sounds
- [ ] **7. Multiplayer and quality checks**: server authority, anti‑spam, two‑player tests
- Later: flower combos, Royal Jelly rebirths, quests, seasonal bees, hive skins, co‑op events
