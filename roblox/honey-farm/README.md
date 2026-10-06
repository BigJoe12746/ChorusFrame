# 🍯 HONEY FARM

A colourful multiplayer bee‑farming tycoon. Players own a garden plot, buy bees, make honey, bottle and sell it, merge bees, and expand their farm.

**Status: Phase 1 (map and player plots) is done.** Phases 2–7 are the roadmap below.

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

In Phase 1 the stations only say "opens in the next update!". They become usable in Phase 2.

### Hooks for later phases

- `PlotService.GetPlot(player)`, `PlotService.IsOwner(player, instance)`, and the `PlotAssigned`/`PlotReleased` events.
- `Plot.Temp`: put bees, jars and effects here so they're cleaned up automatically when the owner leaves.
- Invisible marker parts are already placed: `Hive/BeeExit`, `FlowerPatch/FlowerSpots/Spot1‑9`, `Bottling/DepositPoint`, and `Conveyor/ConveyorStart`/`ConveyorEnd`.
- `ReplicatedStorage.Assets.BeeTemplate` is your original bee model. It's shown on each Bee Shop counter and will be the base for the 10 bee tiers.

## Project layout (Rojo)

```
default.project.json          how files map into the game
HoneyFarm.rbxl                 built place file, ready to open
src/shared/   → ReplicatedStorage.HoneyFarm   Config, PlotAllocator
src/server/   → ServerScriptService.HoneyFarm  Main, MapBuilder, PlotService
src/client/   → StarterPlayerScripts.HoneyFarm FarmClient
assets/BeeTemplate.rbxm → ReplicatedStorage.Assets.BeeTemplate
tests/                          offline tests (see below)
```

Rebuild the place file after editing the scripts: `rojo build default.project.json -o HoneyFarm.rbxl` (Rojo 7.7+). Or run `rojo serve` and use the Rojo Studio plugin to sync live.

You can change all the sizes, colours and the plot count in `src/shared/Config.lua`.

## Testing

| Test | How | Result |
|---|---|---|
| Plot assignment logic: separate plots, no double assignment, release, queue when full, rejoin | `luau tests/PlotAllocator.spec.luau` | 17/17 pass |
| Full Phase 1 scenario: the **real** server scripts run against a small mock of the Roblox engine. Builds the map, two players join, spawn on separate farms, use **My Farm** (including spam and visiting), respawn, owner‑only stations, leave and clear the plot, rejoin, a full server with a 7th player queued | `python3 tests/run_sim.py --luau <path to luau> --render out/` | 123/123 pass |
| Type check against the Roblox API definitions | `luau-lsp analyze` with Roblox definitions and a Rojo sourcemap | no errors |
| Place file builds | `rojo build` | ok |

**Still needs a real Roblox Studio playtest.** The mock above isn't a physics or rendering engine. Please check:
- [ ] With 2 players, each player appears inside their own gate, and the signs show their name and avatar.
- [ ] Walking, jumping and the camera feel comfortable on paths and through gates. Nothing blocks a path.
- [ ] The **My Farm** button and the **H** key work. On a phone, the button doesn't overlap the thumbstick or jump button.
- [ ] Visitors don't see station prompts on someone else's farm. The owner does (key **E**, or tap).
- [ ] When a player leaves, their sign resets to "Free Farm", and a new joiner can take that plot.
- [ ] Part count and frame rate are fine on mobile (the map is about 2,400 anchored parts).

## Roadmap

- [x] **1. Map and player plots**
- [ ] **2. First playable honey loop**: Starter Bee, 25 Cash, hive storage, backpack (50), bottling at 1 jar/sec, conveyor, 5 Cash per jar, collect at the stand
- [ ] **3. Bee shop and merging**: 10 tiers (Starter, Clover, Daisy, Strawberry, Panda, Knight, Crystal, Storm, Galaxy, Royal); each merge is ×2.5 production
- [ ] **4. Farm upgrades**: production, hive storage, backpack, bottling speed, bee slots
- [ ] **5. Saving and offline honey**: DataStore, autosave, offline earnings capped at 8 hours
- [ ] **6. Interface and introduction**: tutorial, collection book, effects and sounds
- [ ] **7. Multiplayer and quality checks**: server authority, anti‑spam, two‑player tests
- Later: flower combos, Royal Jelly rebirths, quests, seasonal bees, hive skins, co‑op events
