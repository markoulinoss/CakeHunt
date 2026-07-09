-- Audio: streamed music tracks (assets/audio/*) + procedural chiptune SFX.
-- Music switches crossfade via Audio.play/Audio.update; per-track volume and
-- start offsets live in Audio.musicLevel / Audio.musicSeek.
local Audio = {}

local SR = 44100  -- sample rate

local function clamp(v) return math.max(-0.98, math.min(0.98, v)) end

local function makeTone(freq, dur, wave, vol, decay)
    vol   = vol or 0.4
    local n = math.max(1, math.floor(SR * dur))
    local sd = love.sound.newSoundData(n, SR, 16, 1)
    for i = 0, n-1 do
        local t   = i / SR
        local env = decay and math.max(0, 1 - t/dur) or 1.0
        local v
        if wave == "sq" then
            v = math.sin(2*math.pi*freq*t) >= 0 and 0.8 or -0.8
        elseif wave == "tri" then
            local p = (t*freq) % 1
            v = p < 0.5 and (4*p-1) or (3-4*p)
        else
            v = math.sin(2*math.pi*freq*t)
        end
        sd:setSample(i, clamp(v * vol * env))
    end
    return love.audio.newSource(sd, "static")
end

function Audio.load()
    -- ── SFX ─────────────────────────────────────────────────────────────────
    Audio.sfx = {
        hit      = makeTone(880,  0.07, "sq",   0.30, true),
        miss     = makeTone(196,  0.15, "sq",   0.30, true),
        pickup   = makeTone(1047, 0.13, "sine", 0.40, true),
        interact = makeTone(660,  0.06, "sine", 0.28, true),
        advance  = makeTone(523,  0.04, "sine", 0.15, true),
        reveal   = makeTone(659,  0.35, "tri",  0.45, true),
        win      = makeTone(784,  0.45, "sine", 0.50, false),
        clean    = makeTone(440,  0.08, "tri",  0.28, true),
        cat      = makeTone(330,  0.20, "tri",  0.35, true),
        honk     = love.audio.newSource("assets/audio/car-honk.mp3", "static"),
        zubat    = love.audio.newSource("assets/audio/zubat_sound.mp3", "static"),
        pokeball = love.audio.newSource("assets/audio/pokeball.mp3",    "static"),
        blink    = love.audio.newSource("assets/audio/blink.mp3",       "static"),
        meow1    = love.audio.newSource("assets/audio/meow1.mp3", "static"),
        meow2    = love.audio.newSource("assets/audio/meow2.mp3", "static"),
        meow3    = love.audio.newSource("assets/audio/meow3.mp3", "static"),
        romanos1 = love.audio.newSource("assets/audio/romanos_sound_1.mp3", "static"),
        romanos2 = love.audio.newSource("assets/audio/romanos_sound_2.mp3", "static"),
    }

    -- ── BGM ──────────────────────────────────────────────────────────────────
    -- Menu Theme.wav covers every scene that used to have a generated
    -- chiptune melody; the stage names all point at the same source so the
    -- track keeps playing seamlessly across those scene changes.
    local menuTheme = love.audio.newSource("assets/audio/Menu Theme.wav", "stream")
    menuTheme:setLooping(true)

    Audio.music = {
        intro  = menuTheme,
        stage1 = menuTheme,
        stage2 = menuTheme,
        stage4 = menuTheme,
        ending = menuTheme,
        battle = love.audio.newSource("assets/audio/battle_start.mp3",  "stream"),
        battle_end = love.audio.newSource("assets/audio/battle_ending.mp3", "stream"),
    }
    Audio.music.battle:setLooping(true)
    Audio.music.battle_end:setLooping(true)

    Audio.music.dance_battle  = love.audio.newSource("assets/audio/dance_battle.mp3",  "stream")
    Audio.music.kitchen_music = love.audio.newSource("assets/audio/kitchen_music.mp3", "stream")
    Audio.music.final_stage   = love.audio.newSource("assets/audio/final_stage.mp3",   "stream")
    Audio.music.car_chase     = love.audio.newSource("assets/audio/car chase.wav",     "stream")
    Audio.music.dance_battle:setLooping(true)
    Audio.music.kitchen_music:setLooping(true)
    Audio.music.final_stage:setLooping(true)
    Audio.music.car_chase:setLooping(true)

    -- Per-track volume multipliers (relative to master volume)
    Audio.musicLevel = {
        kitchen_music = 0.35,   -- plays softly in the background
    }

    -- Per-track start offsets in seconds (skip intros)
    Audio.musicSeek = {
        dance_battle = 30,   -- stage 1 minigame music starts at 00:30
        final_stage  = 58,   -- stage 4 minigame music starts at 00:58
    }

    Audio.current     = nil
    Audio.currentName = nil
    Audio.masterVolume = Audio.masterVolume or 0.7
end

-- Master volume (0..1), shared by music and SFX. Controlled by the
-- LUIS settings-screen volume slider.
local function trackVolume(name)
    local mul = (Audio.musicLevel and Audio.musicLevel[name]) or 1
    return (Audio.masterVolume or 0.7) * mul
end

function Audio.setVolume(v)
    Audio.masterVolume = math.max(0, math.min(1, v))
    if Audio.current then Audio.current:setVolume(trackVolume(Audio.currentName)) end
end

function Audio.getVolume()
    return Audio.masterVolume or 0.7
end

-- Default crossfade length when switching music tracks; callers can pass a
-- longer `fadeTime` for gentler transitions.
local FADE_TIME = 0.8

function Audio.play(name, fadeTime)
    if Audio.currentName == name then return end
    -- Same underlying track under a different name: keep playing seamlessly
    if Audio.music[name] and Audio.music[name] == Audio.current then
        Audio.currentName = name
        return
    end
    fadeTime = fadeTime or FADE_TIME
    -- Old track keeps playing and fades out in Audio.update
    if Audio.current then
        -- A second switch mid-fade would abandon the still-playing first
        -- track at partial volume forever; cut it off instead.
        if Audio.fadeOutSrc and Audio.fadeOutSrc ~= Audio.current then
            Audio.fadeOutSrc:stop()
        end
        Audio.fadeOutSrc  = Audio.current
        Audio.fadeOutName = Audio.currentName
        Audio.fadeOutT    = fadeTime
        Audio.fadeOutDur  = fadeTime
    end
    Audio.current     = Audio.music[name]
    Audio.currentName = name
    if Audio.current then
        if Audio.fadeOutSrc == Audio.current then Audio.fadeOutSrc = nil end
        Audio.current:stop()
        local seek = Audio.musicSeek and Audio.musicSeek[name]
        if seek then Audio.current:seek(seek, "seconds") end
        Audio.fadeInT   = 0
        Audio.fadeInDur = fadeTime
        Audio.current:setVolume(0)
        Audio.current:play()
    end
end

-- Music ducking: temporarily lower the music so a voice clip can be heard.
-- Ducks for the named SFX's duration (or `seconds` if given), then eases back.
local DUCK_LEVEL = 0.20

function Audio.duckFor(sfxName, seconds)
    local dur = seconds
    if not dur then
        local s = Audio.sfx and Audio.sfx[sfxName]
        dur = s and s:getDuration("seconds") or 1
    end
    Audio.duckT = math.max(Audio.duckT or 0, dur + 0.15)
end

-- Drives the crossfade + ducking; called every frame from love.update
function Audio.update(dt)
    -- Duck multiplier: drops quickly when a voice clip starts, eases back up
    Audio.duckT   = math.max(0, (Audio.duckT or 0) - dt)
    Audio.duckMul = Audio.duckMul or 1
    local target = Audio.duckT > 0 and DUCK_LEVEL or 1
    if Audio.duckMul > target then
        Audio.duckMul = math.max(target, Audio.duckMul - dt * 8)
    else
        Audio.duckMul = math.min(target, Audio.duckMul + dt * 2)
    end

    if Audio.current then
        local fadeMul = 1
        local dur = Audio.fadeInDur or FADE_TIME
        if Audio.fadeInT and Audio.fadeInT < dur then
            Audio.fadeInT = math.min(dur, Audio.fadeInT + dt)
            fadeMul = Audio.fadeInT / dur
        end
        Audio.current:setVolume(trackVolume(Audio.currentName) * fadeMul * Audio.duckMul)
    end
    if Audio.fadeOutSrc then
        Audio.fadeOutT = Audio.fadeOutT - dt
        if Audio.fadeOutT <= 0 then
            Audio.fadeOutSrc:stop()
            Audio.fadeOutSrc = nil
        else
            Audio.fadeOutSrc:setVolume(trackVolume(Audio.fadeOutName)
                * (Audio.fadeOutT / (Audio.fadeOutDur or FADE_TIME)) * Audio.duckMul)
        end
    end
end

function Audio.sfxPlay(name)
    local s = Audio.sfx and Audio.sfx[name]
    if s then
        s:stop()
        s:setVolume(Audio.masterVolume or 0.7)
        s:play()
    end
end

function Audio.stop()
    if Audio.current then Audio.current:stop() end
    if Audio.fadeOutSrc then Audio.fadeOutSrc:stop() end
    Audio.current     = nil
    Audio.currentName = nil
    Audio.fadeOutSrc  = nil
end

return Audio
