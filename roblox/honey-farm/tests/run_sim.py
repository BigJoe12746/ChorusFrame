"""Run a HONEY FARM scenario against the mock Roblox engine using the plain `luau` CLI.

    python3 tests/run_sim.py --luau /path/to/luau [--scenario tests/phase1.scenario.luau] [--render out_dir]

The real game sources are loaded unchanged (via loadstring + setfenv) into a mock DataModel
laid out like default.project.json. With --render, a top-down map PNG is drawn from the parts
the scripts created (needs Pillow).
"""
import argparse
import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# (path in DataModel, class, source file)
SCRIPTS = [
    ("ReplicatedStorage.HoneyFarm.Config", "ModuleScript", "src/shared/Config.lua"),
    ("ReplicatedStorage.HoneyFarm.PlotAllocator", "ModuleScript", "src/shared/PlotAllocator.lua"),
    ("ReplicatedStorage.HoneyFarm.FarmState", "ModuleScript", "src/shared/FarmState.lua"),
    ("ReplicatedStorage.HoneyFarm.BeeAppearance", "ModuleScript", "src/shared/BeeAppearance.lua"),
    ("ServerScriptService.HoneyFarm.MapBuilder", "ModuleScript", "src/server/MapBuilder.lua"),
    ("ServerScriptService.HoneyFarm.PlotService", "ModuleScript", "src/server/PlotService.lua"),
    ("ServerScriptService.HoneyFarm.RateLimiter", "ModuleScript", "src/server/RateLimiter.lua"),
    ("ServerScriptService.HoneyFarm.UpgradeVisuals", "ModuleScript", "src/server/UpgradeVisuals.lua"),
    ("ServerScriptService.HoneyFarm.SaveService", "ModuleScript", "src/server/SaveService.lua"),
    ("ServerScriptService.HoneyFarm.FarmService", "ModuleScript", "src/server/FarmService.lua"),
    ("ServerScriptService.HoneyFarm.Main", "Script", "src/server/Main.server.lua"),
]
REMOTES = ["ReturnToFarm", "Notify", "JarStarted", "OpenShop", "ShopAction", "BeeMerged", "UpgradeAction", "WelcomeBack", "Feedback"]


def lua_str(s: str) -> str:
    level = 1
    while ("]" + "=" * level + "]") in s:
        level += 1
    eq = "=" * level
    return f"[{eq}[\n{s}]{eq}]"


def build_bundle(scenario: str) -> str:
    mock = open(os.path.join(ROOT, "tests/mock/Roblox.luau")).read()
    out = ["local M = (function()\n", mock, "\nend)()\n"]
    out.append(
        """
local game, workspace, services = M.newGame()
-- simulated clock: os.clock() inside game scripts advances only when the scenario ticks
M.simTime = 1000
local simOs = setmetatable({ clock = function() return M.simTime end }, { __index = os })
local cache = {}
local loading = {}
local env
local function req(inst)
	if cache[inst] ~= nil then return cache[inst] end
	assert(not loading[inst], "circular require: " .. tostring(inst))
	loading[inst] = true
	local fn = assert(loadstring(inst.Source, "=" .. inst.SourcePath))
	setfenv(fn, env(inst))
	local result = fn()
	cache[inst] = result
	return result
end
env = function(scriptInst)
	return setmetatable({
		game = game, workspace = workspace, script = scriptInst, require = req,
		Instance = M.Instance, Vector3 = M.Vector3, Vector2 = M.Vector2, CFrame = M.CFrame,
		Color3 = M.Color3, UDim = M.UDim, UDim2 = M.UDim2, Enum = M.Enum, Random = M.Random,
		TweenInfo = M.TweenInfo, task = M.task, os = simOs,
		warn = function(...) print("[warn]", ...) end,
	}, { __index = _G })
end
local function place(path, class, source, srcPath)
	local parts = string.split(path, ".")
	local parent = services[parts[1]]
	for i = 2, #parts - 1 do
		local f = parent:FindFirstChild(parts[i])
		if not f then
			f = M.Instance.new("Folder"); f.Name = parts[i]; f.Parent = parent
		end
		parent = f
	end
	local s = M.Instance.new(class)
	s.Name = parts[#parts]
	s.Source = source
	s.SourcePath = srcPath
	s.Parent = parent
	return s
end
"""
    )
    for path, cls, src in SCRIPTS:
        code = open(os.path.join(ROOT, src)).read()
        out.append(f'place("{path}", "{cls}", {lua_str(code)}, "{src}")\n')
    out.append(
        """
local remotes = M.Instance.new("Folder"); remotes.Name = "Remotes"; remotes.Parent = services.ReplicatedStorage
"""
    )
    for r in REMOTES:
        out.append(f'do local e = M.Instance.new("RemoteEvent"); e.Name = "{r}"; e.Parent = remotes end\n')
    out.append(
        """
local passed, failed = 0, 0
local function check(cond, msg)
	if cond then passed += 1; print("  ok   " .. msg) else failed += 1; print("  FAIL " .. msg) end
end
local function boot()
	local main = services.ServerScriptService.HoneyFarm.Main
	local fn = assert(loadstring(main.Source, "=" .. main.SourcePath))
	setfenv(fn, env(main))
	fn()
end
local function n(x) return string.format("%.3f", x) end
local function dumpParts(root)
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			local cf, s = d.CFrame, d.Size
			local station, plot = "", ""
			local p = d.Parent
			while p do
				if p:GetAttribute("Station") and station == "" then station = p:GetAttribute("Station") end
				if p:GetAttribute("PlotId") then plot = tostring(p:GetAttribute("PlotId")) end
				p = p.Parent
			end
			local c = d.Color or { R = 0.6, G = 0.6, B = 0.6 }
			local shape = d.Shape and d.Shape.Name or "Block"
			print(table.concat({ "PART", n(cf.p.X), n(cf.p.Y), n(cf.p.Z),
				n(cf.rx.X), n(cf.rx.Y), n(cf.rx.Z), n(cf.ry.X), n(cf.ry.Y), n(cf.ry.Z), n(cf.rz.X), n(cf.rz.Y), n(cf.rz.Z),
				n(s.X), n(s.Y), n(s.Z), shape, n(c.R), n(c.G), n(c.B), n(d.Transparency or 0), d.Name, station, plot }, "\\t"))
		end
	end
end
local scenarioFn = assert(loadstring(SCENARIO, "=scenario"))
local function tick(seconds, step)
	step = step or 1 / 30
	local hb = services.RunService.Heartbeat
	local t = 0
	while t < seconds - 1e-9 do
		local dt = math.min(step, seconds - t)
		M.simTime += dt
		hb:Fire(dt)
		t += dt
	end
end
setfenv(scenarioFn, setmetatable({ M = M, game = game, workspace = workspace, boot = boot, check = check, dumpParts = dumpParts, tick = tick, req = req }, { __index = _G }))
scenarioFn()
print(("RESULT %d passed, %d failed"):format(passed, failed))
if failed > 0 then error("scenario failed") end
"""
    )
    return "local SCENARIO = " + lua_str(scenario) + "\n" + "".join(out)


def render(parts, out_dir):
    from PIL import Image, ImageDraw

    os.makedirs(out_dir, exist_ok=True)

    def top(p):
        return p["y"] + (abs(p["rx"][1]) * p["sx"] + abs(p["ry"][1]) * p["sy"] + abs(p["rz"][1]) * p["sz"]) / 2

    def draw(name, cx, cz, half, px_per_stud, filt):
        size = int(half * 2 * px_per_stud)
        img = Image.new("RGB", (size, size), (60, 120, 60))
        dr = ImageDraw.Draw(img, "RGBA")

        def to_px(x, z):
            # north (−Z) up, +X right
            return ((x - cx + half) * px_per_stud, (z - cz + half) * px_per_stud)

        for p in sorted(filter(filt, parts), key=top):
            if p["t"] >= 0.99:
                continue
            col = tuple(int(v * 255) for v in p["c"]) + (int(255 * (1 - p["t"] * 0.8)),)
            x, z = p["x"], p["z"]
            if p["shape"] == "Ball" or (p["shape"] == "Cylinder" and abs(p["rx"][1]) > 0.9):
                r = (p["sx"] if p["shape"] == "Ball" else p["sy"]) / 2
                a, b = to_px(x - r, z - r), to_px(x + r, z + r)
                dr.ellipse([a, b], fill=col, outline=(0, 0, 0, 60))
                continue
            # project the box onto the ground plane
            if p["shape"] == "Cylinder":
                ax = [(p["rx"], p["sx"]), (p["rz"], p["sy"])]
            else:
                ax = [(p["rx"], p["sx"]), (p["rz"], p["sz"])]
            (u, lu), (w, lw) = ax
            corners = []
            for su, sw in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                corners.append(to_px(x + u[0] * lu / 2 * su + w[0] * lw / 2 * sw, z + u[2] * lu / 2 * su + w[2] * lw / 2 * sw))
            dr.polygon(corners, fill=col, outline=(0, 0, 0, 60))
        img.save(os.path.join(out_dir, name))

    draw("map_topdown.png", 0, 0, 280, 3, lambda p: True)
    p1 = [p for p in parts if p["plot"] == "1"]
    if p1:
        cx = sum(p["x"] for p in p1) / len(p1)
        cz = sum(p["z"] for p in p1) / len(p1)
        draw("plot1_topdown.png", cx, cz, 62, 10, lambda p: abs(p["x"] - cx) < 70 and abs(p["z"] - cz) < 70)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--luau", default=os.environ.get("LUAU", "luau"))
    ap.add_argument("--scenario", default=os.path.join(ROOT, "tests/phase1.scenario.luau"))
    ap.add_argument("--render")
    args = ap.parse_args()

    bundle = build_bundle(open(args.scenario).read())
    with tempfile.TemporaryDirectory() as d:
        path = os.path.join(d, "bundle.luau")
        open(path, "w").write(bundle)
        proc = subprocess.run([args.luau, path], capture_output=True, text=True)
    parts = []
    for line in proc.stdout.splitlines():
        if line.startswith("PART\t"):
            f = line.split("\t")
            v = [float(x) for x in f[1:16]]
            parts.append(dict(x=v[0], y=v[1], z=v[2], rx=v[3:6], ry=v[6:9], rz=v[9:12], sx=v[12], sy=v[13], sz=v[14],
                              shape=f[16], c=[float(x) for x in f[17:20]], t=float(f[20]), name=f[21],
                              station=f[22] if len(f) > 22 else "", plot=f[23] if len(f) > 23 else ""))
        else:
            print(line)
    if proc.returncode != 0:
        print(proc.stderr, file=sys.stderr)
        sys.exit(proc.returncode)
    print(f"{len(parts)} parts in map")
    if args.render:
        render(parts, args.render)
        json.dump({"parts": len(parts)}, open(os.path.join(args.render, "stats.json"), "w"))


if __name__ == "__main__":
    main()
