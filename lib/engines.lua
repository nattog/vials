local MusicUtil = require "musicutil"
local Formatters = require "formatters"
local engines = {}
-- engine
local Timber = require "timber/lib/timber_engine"
engine.name = "Timber"

local options = {}
options.OFF_ON = {"Off", "On"}
options.QUANTIZATION = {"None", "1/32", "1/24", "1/16", "1/12", "1/8", "1/6", "1/4", "1/3", "1/2", "1 bar"}
options.QUANTIZATION_DIVIDERS = {nil, 32, 24, 16, 12, 8, 6, 4, 3, 2, 1}

local current_sample_id = 0
local shift_mode = false
local file_select_active = false

local NUM_SAMPLES = 4
local sample_status = {}
local STATUS = {
    STOPPED = 0,
    STARTING = 1,
    PLAYING = 2,
    STOPPING = 3
}
for i = 0, NUM_SAMPLES - 1 do
    sample_status[i] = STATUS.STOPPED
end
local current_sample_id = 0

function engines.load_folder(file, add)
    local sample_id = 0
    if add then
        for i = NUM_SAMPLES - 1, 0, -1 do
            if Timber.samples_meta[i].num_frames > 0 then
                sample_id = i + 1
                break
            end
        end
    end

    Timber.clear_samples(sample_id, NUM_SAMPLES - 1)

    local split_at = string.match(file, "^.*()/")
    local folder = string.sub(file, 1, split_at)
    file = string.sub(file, split_at + 1)

    local found = false
    for k, v in ipairs(Timber.FileSelect.list) do
        if v == file then
            found = true
        end
        if found then
            if sample_id > 255 then
                print("Max files loaded")
                break
            end
            -- Check file type
            local lower_v = v:lower()
            if
                string.find(lower_v, ".wav") or string.find(lower_v, ".aif") or string.find(lower_v, ".aiff") or
                    string.find(lower_v, ".ogg")
             then
                Timber.load_sample(sample_id, folder .. v)
                sample_id = sample_id + 1
            else
                print("Skipped", v)
            end
        end
    end
end

function engines.set_sample_id(id)
    current_sample_id = id
    while current_sample_id >= NUM_SAMPLES do
        current_sample_id = current_sample_id - NUM_SAMPLES
    end
    while current_sample_id < 0 do
        current_sample_id = current_sample_id + NUM_SAMPLES
    end
end

function engines.note_on(sample_id, vel)
    if Timber.samples_meta[sample_id].num_frames > 0 then
        -- print("note_on", sample_id)
        vel = vel or 1
        engine.noteOn(sample_id, MusicUtil.note_num_to_freq(60), vel, sample_id)
        sample_status[sample_id] = STATUS.PLAYING
    end
end

function engines.note_off(sample_id)
    -- print("note_off", sample_id)
    engine.noteOff(sample_id)
end

function engines.init()
    Timber.add_params()
    params:add_separator()
    -- Index zero to align with MIDI note numbers
    for i = 0, NUM_SAMPLES - 1 do
        local extra_params = {
            {
                type = "option",
                id = "launch_mode_" .. i,
                name = "Launch Mode",
                options = {"Gate", "Toggle"},
                default = 1,
                action = function(value)
                    Timber.setup_params_dirty = true
                end
            }
        }
        Timber.add_sample_params(i, true, extra_params)
    end
end

return engines
