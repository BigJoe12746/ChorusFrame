-- Background music: loops Config.Sounds.Music (your uploaded track) quietly under the game.
-- Nothing plays while the id is empty, so the game stays silent until the track is uploaded.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("HoneyFarm"):WaitForChild("Config"))

local id = Config.Sounds.Music
if not id or id == "" then
	return
end

local music = Instance.new("Sound")
music.Name = "BackgroundMusic"
music.SoundId = id
music.Looped = true
music.Volume = 0
music.Parent = SoundService
music:Play()

-- fade in over a few seconds so joining isn't a blast of sound
local target = Config.Sounds.MusicVolume or 0.35
local t0 = os.clock()
while music.Volume < target do
	music.Volume = math.min(target, (os.clock() - t0) / 3 * target)
	task.wait(0.1)
end
