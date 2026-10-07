pcall(function() loadstring("if getgenv().LPH_NO_VIRTUALIZE == nil then getgenv().LPH_NO_VIRTUALIZE = function(f) return f end end")() end)
pcall(function() loadstring("if getgenv().LPH_JIT == nil then getgenv().LPH_JIT = function(f) return f end end")() end)
pcall(function() loadstring("if getgenv().LPH_JIT_MAX == nil then getgenv().LPH_JIT_MAX = function(f) return f end end")() end)

if not LPS_OBFUSCATED then
    LPS_OBFUSCATED = false
    LPS_CRASH         = function() error("LPS_CRASH triggered", 2) end
    LPS_ENCRYPT       = function(v) return v end
    LPS_EQ            = function(a, b) return a == b end
    LPH_NO_VIRTUALIZE = function(f) return f end
    LPH_NO_UPVALUES   = function(f) return f end
    LPS_GET_ARGUMENTS = function(...) return {...} end
end

-- ============================================================
-- RE-EXECUTION CLEANUP: Reset all persistent flags and destroy old UI
-- This ensures the script works every time you rejoin or re-execute
-- ============================================================
_G._HaloInfBaseplateApplied = nil
_G._HaloResetLastTick = nil
_G._HaloAnimCopierActive = nil

-- Destroy old ScreenGui if it exists
pcall(function()
    local PlayerGui = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if PlayerGui then
        local oldGui = PlayerGui:FindFirstChild("ReanimHaloMenu")
        if oldGui then oldGui:Destroy() end
    end
end)

-- Destroy old mobile wheel button if it exists
pcall(function()
    local CoreGui = game:GetService("CoreGui")
    local oldBtn = CoreGui:FindFirstChild("HaloMobileWheelBtn")
    if oldBtn then oldBtn:Destroy() end
end)

-- Clean up old connections if stored
pcall(function()
    if _G._HaloReanimConns then
        for k, conn in pairs(_G._HaloReanimConns) do
            if conn then pcall(function() conn:Disconnect() end) end
        end
        _G._HaloReanimConns = {}
    end
end)


-- Ensure these are always defined locally if still nil
pcall(function() loadstring("if getgenv().LPH_NO_VIRTUALIZE == nil then getgenv().LPH_NO_VIRTUALIZE = function(f) return f end end")() end)
pcall(function() loadstring("if getgenv().LPH_JIT == nil then getgenv().LPH_JIT = function(f) return f end end")() end)
pcall(function() loadstring("if getgenv().LPH_JIT_MAX == nil then getgenv().LPH_JIT_MAX = function(f) return f end end")() end)

if _G._HaloReanimConns then
    for k, conn in pairs(_G._HaloReanimConns) do
        if conn then
            pcall(function() conn:Disconnect() end)
            _G._HaloReanimConns[k] = nil
        end
    end
else
    _G._HaloReanimConns = {}
end
if _G._ReanimRawConn then
    pcall(function() _G._ReanimRawConn:Disconnect() end)
    _G._ReanimRawConn = nil
end

pcall(function()
    settings().Physics.PhysicsEnvironmentalThrottle = Enum.EnviromentalPhysicsThrottle.Disabled
end)
pcall(function()
    settings().Physics.PhysicsEnvironmentalThrottle = Enum.EnvironmentalPhysicsThrottle.Disabled
end)

pcall(function()
    for _, child in ipairs(game:GetService("SoundService"):GetChildren()) do
        if child.Name == "HaloEmoteSound" or child.Name == "HaloClickSound" then
            child:Stop()
            child:Destroy()
        end
    end
end)

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local HttpService      = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local ContextActionService = game:GetService("ContextActionService")

-- The default camera keyboard zoom action is bound asynchronously 
-- by the PlayerModule, so we wait for it to exist before unbinding.
task.spawn(function()
    while true do
        local info = ContextActionService:GetBoundActionInfo("RbxCameraKeypress")
        if info and info.inputTypes then
            ContextActionService:UnbindAction("RbxCameraKeypress")
            break
        end
        task.wait()
    end
end)

local plr       = Players.LocalPlayer
local PlayerGui = plr:WaitForChild("PlayerGui")
local Mouse     = plr:GetMouse()

-- Helper functions for parsing JSON and table animations
function toCFrame(val)
    if typeof(val) == "CFrame" then
        return val
    elseif type(val) == "table" then
        if #val == 12 then
            return CFrame.new(table.unpack(val))
        elseif #val == 7 then
            return CFrame.new(val[1], val[2], val[3], val[4], val[5], val[6], val[7])
        elseif val.Position or val.position or val.pos or val.Orientation or val.orientation or val.rotation or val.angles or val.CFrame then
            -- Handle {CFrame: {Position: [], Orientation: []}} nested structure
            local cfData = val.CFrame or val
            local pos = cfData.Position or cfData.position or cfData.pos or val.Position or val.position or val.pos or {0,0,0}
            local ori = cfData.Orientation or cfData.orientation or cfData.rotation or cfData.angles or val.Orientation or val.orientation or val.rotation or val.angles or {0,0,0}
            
            local px, py, pz = 0, 0, 0
            if typeof(pos) == "Vector3" then
                px, py, pz = pos.X, pos.Y, pos.Z
            elseif type(pos) == "table" then
                px, py, pz = pos[1] or 0, pos[2] or 0, pos[3] or 0
            end
            
            local rx, ry, rz = 0, 0, 0
            if typeof(ori) == "Vector3" then
                rx, ry, rz = ori.X, ori.Y, ori.Z
            elseif type(ori) == "table" then
                rx, ry, rz = ori[1] or 0, ori[2] or 0, ori[3] or 0
            end
            
            return CFrame.new(px, py, pz) * CFrame.fromEulerAnglesXYZ(rx, ry, rz)
        else
            local ok, cf = pcall(function() return CFrame.new(table.unpack(val)) end)
            if ok then return cf end
        end
    end
    return nil
end

function parseTableAnimation(raw)
    if type(raw) ~= "table" then return nil end
    -- Unwrap root-object formats: {keyframes=[...]}, {Keyframes=[...]}, etc.
    local arrayRoot = raw
    if type(raw[1]) ~= "table" then
        for _, key in ipairs({"keyframes","Keyframes","animations","frames","data","Frames","KeyframeSequence","animData"}) do
            if type(raw[key]) == "table" then 
                local sub = raw[key]
                if key == "animData" and type(sub.KeyframeSequence) == "table" then
                    arrayRoot = sub.KeyframeSequence
                else
                    arrayRoot = sub
                end
                break 
            end
        end
    end
    local keyframes = {}

    -- Helper: extract bone CFrame data from a single keyframe entry
    local function extractSingleFrame(frame, key)
        if type(frame) ~= "table" then return end
        local t = frame.Time or frame.time or frame.timestamp or frame.t
        if t == nil and key then
            t = tonumber(key)
        end
        -- Look for poses/bones in multiple property names
        local posesRaw = frame.Poses or frame.poses or frame.joints or frame.bones or frame.Joints or frame.Data or frame.data
        if not posesRaw then posesRaw = frame end
        if t ~= nil and type(posesRaw) == "table" then
            local kf = {Time = tonumber(t) or 0, Data = {}}
            for boneName, boneData in pairs(posesRaw) do
                if type(boneName) == "string" and (boneName:lower() == "time" or boneName:lower() == "t") then continue end
                if type(boneData) ~= "table" and typeof(boneData) ~= "CFrame" then continue end
                -- If boneData is already a CFrame, use it directly — DO NOT index it with .CFrame
                -- (that throws "CFrame is not a valid member of CFrame")
                local rawVal
                if typeof(boneData) == "CFrame" then
                    rawVal = boneData
                else
                    -- Try to get CFrame from various property names
                    rawVal = boneData.CFrame or boneData.cframe or boneData.transform or boneData
                end
                local cf = toCFrame(rawVal)
                if cf then
                    kf.Data[boneName] = cf
                end
            end
            if next(kf.Data) then
                table.insert(keyframes, kf)
            end
        end
    end

    -- Yield every 50 keyframes so the game scheduler can breathe on large animations
    local processed = 0
    for key, frame in pairs(arrayRoot) do
        if type(frame) ~= "table" then continue end
        -- Format-2 support: if this value is an array of keyframe objects (named sequence),
        -- iterate through the sub-array instead of treating it as a single frame
        if type(frame[1]) == "table" then
            for subIdx, subFrame in ipairs(frame) do
                extractSingleFrame(subFrame, subIdx)
                processed = processed + 1
                if processed % 50 == 0 then task.wait() end
            end
        else
            extractSingleFrame(frame, key)
            processed = processed + 1
            if processed % 50 == 0 then task.wait() end
        end
    end
    if #keyframes == 0 then 
        warn("[AnimEditor] parseTableAnimation produced 0 keyframes from", #arrayRoot or 0, "input frames")
        return nil 
    end
    table.sort(keyframes, function(a, b) return a.Time < b.Time end)
    return keyframes
end

function parseJsonAnimation(content)
    local ok, raw = pcall(function() return HttpService:JSONDecode(content) end)
    if not ok then 
        warn("[AnimEditor] JSON decode failed:", raw)
        return nil 
    end
    local result = parseTableAnimation(raw)
    if not result then
        warn("[AnimEditor] parseTableAnimation failed for JSON data. Raw structure:", typeof(raw), type(raw))
        if type(raw) == "table" then
            local keys = {}
            for k, v in pairs(raw) do table.insert(keys, tostring(k)) end
            warn("[AnimEditor] Keys in JSON:", table.concat(keys, ", "))
            if raw[1] then
                warn("[AnimEditor] First element type:", type(raw[1]))
                if type(raw[1]) == "table" then
                    local firstKeys = {}
                    for k, v in pairs(raw[1]) do table.insert(firstKeys, tostring(k)) end
                    warn("[AnimEditor] First element keys:", table.concat(firstKeys, ", "))
                end
            end
        end
    end
    return result
end

-- Load API (embedded)
local ReanimateAPI
do
    local halo = {
        services = {
            players = game:GetService("Players");
            workspace = game:GetService("Workspace");
            replicated = game:GetService("ReplicatedStorage");
            run_service = game:GetService("RunService");
            http_service = game:GetService("HttpService");
        };
        flags = {
            reanimated = false;
            switching = false;
        };
        clones = {};
        connections = {
            hb = nil;
            died = nil;
            real_char_child_removed = nil;
            character_removing = nil;
            clone_died = nil;
            clone_char_child_removed = nil;
            animation_hb = nil;
            zero_delay = nil;
            zero_delay_hrp_sync = nil;
            shiftlock_hb = nil;
        };
        real_chars = {};
        callbacks = {
            on_play = nil;
            on_stop = nil;
        };
        animation = {
            cache = {};
            constraints_cache = nil;
            state = {
                is_playing = false;
                current_url = nil;
                speed = 1.0;
                keyframes = nil;
                total_duration = 0;
                elapsed_time = 0;
            };
            original_transforms = {};
            constraints = {};
        };
    };

    local API = {};

    local get_game_ragdoll_info = function(enable)
        local place_id = game.PlaceId;
        if place_id == 15546218972 or place_id == 6884319169 then
            local remote = halo.services.replicated:WaitForChild("event_rag");
            return remote, {"Ball"}, false;
        elseif place_id == 5991163185 then
            local remote = halo.services.replicated.Remotes.Physics.Ragdoll;
            return remote, {}, false;
        elseif place_id == 5666838333 then
            local local_event = halo.services.replicated:WaitForChild("LocalRagdollEvent");
            return local_event, {enable}, true;
        elseif place_id == 82743296934947 then
            local remote = halo.services.replicated:WaitForChild("Ragdoll");
            return remote, {}, false;
        end;
        return nil, nil, false;
    end;

    local set_model_transparency = function(model, transparency)
        if not model then return end;
        for _, part in model:GetDescendants() do
            if part:IsA("BasePart") then
                part.Transparency = transparency;
            end;
        end;
    end;

    local set_model_query = function(model, state)
        if not model then return end;
        for _, part in model:GetDescendants() do
            if part:IsA("BasePart") then
                part.CanQuery = state;
            end;
        end;
    end;

    local disable_model_collision = function(model)
        if not model then return end;
        for _, part in model:GetDescendants() do
            if part:IsA("BasePart") then
                part.CanCollide = false;
                part.CanQuery = false;
            end;
        end;
    end;

    local get_local_player = function()
        local player = halo.services.players.LocalPlayer;
        if not player then
            return "bad argument to 'get_local_player' (LocalPlayer not found; must run in a LocalScript)";
        end;
        return player;
    end;

    local get_char = function(player)
        if typeof(player) ~= "Instance" or not player:IsA("Player") then
            return ("bad argument #1 to 'get_char' (Player expected, got %s)"):format(typeof(player));
        end;
        local character = player.Character;
        if not character or not character.Parent then
            return ("Player %s has no active character."):format(player.Name);
        end;
        return character;
    end;

    local clone_char = function(model)
        if typeof(model) ~= "Instance" then
            return ("bad argument #1 to 'clone_char' (Instance expected, got %s)"):format(typeof(model));
        end;
        -- Stop all playing animation tracks on the real character first
        local realHum = model:FindFirstChildOfClass("Humanoid");
        if realHum then
            local realAnimator = realHum:FindFirstChildOfClass("Animator");
            if realAnimator then
                for _, track in ipairs(realAnimator:GetPlayingAnimationTracks()) do
                    pcall(function() track:Stop(0) end);
                end;
            end;
        end;
        local realAnimate = model:FindFirstChild("Animate");
        if realAnimate then realAnimate.Disabled = true end;

        model.Archivable = true;
        local new_clone = model:Clone();
        model.Archivable = false;
        new_clone.Name = "Reanimation";
        
        -- Pre-configure before parenting
        local animate_script = new_clone:FindFirstChild("Animate");
        if animate_script then animate_script.Disabled = true; end;
        local humanoid = new_clone:FindFirstChildOfClass("Humanoid");
        if humanoid then
            humanoid.RequiresNeck = false;
            humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None;
        end;
        local force_field = new_clone:FindFirstChildWhichIsA("ForceField");
        if force_field then force_field:Destroy(); end;
        -- Anchor all parts before parenting so physics doesn't run before the swap
        for _, part in ipairs(new_clone:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Anchored = true;
            end;
        end;

        new_clone.Parent = halo.services.workspace;
        return new_clone;
    end;

    local fire_remote = function(remote, is_local, ...)
        if typeof(remote) ~= "Instance" then
            return ("bad argument to 'fire_remote' (Instance expected, got %s)"):format(typeof(remote));
        end;
        if is_local then
            if not remote:IsA("BindableEvent") then
                return ("bad argument to 'fire_remote' (BindableEvent expected for local event, got %s)"):format(remote.ClassName);
            end;
            remote:Fire(...);
        else
            if not (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) then
                return ("bad argument to 'fire_remote' (RemoteEvent or RemoteFunction expected, got %s)"):format(remote.ClassName);
            end;
            if remote:IsA("RemoteEvent") then
                remote:FireServer(...);
            else
                remote:InvokeServer(...);
            end;
        end;
    end;

    local get_animator = function(character)
        local humanoid = character:FindFirstChildOfClass("Humanoid");
        if not humanoid then return nil end;
        return humanoid:FindFirstChildOfClass("Animator");
    end;

    API.play_raw_animation = function(name, script_content, speed, force_reload)
        if not halo.flags.reanimated then
            return "Cannot play animation, not reanimated.";
        end;

        local player = get_local_player();
        if typeof(player) == "string" then return player end;

        local clone = API.get_clone(player);
        if not clone then
            return "Cannot play animation, clone character not found.";
        end;

        if halo.animation.state.is_playing and halo.animation.state.current_url == name then
            API.stop_animation();
            return;
        end;

        API.stop_animation();

        local clone_humanoid = clone:FindFirstChildOfClass("Humanoid");
        if clone_humanoid then
            local animator = clone_humanoid:FindFirstChildOfClass("Animator");
            if animator then
                for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                    track:Stop();
                end;
            end;
        end;

        local clone_animate_script = clone:FindFirstChild("Animate");
        if clone_animate_script then
            clone_animate_script.Enabled = false;
        end;

        local anim = halo.animation;
        anim.state.speed = tonumber(speed) or 1.0;

        -- Check cache first to avoid loadstring lag
        local keyframe_data = (not force_reload) and anim.cache[name] or nil;
        
        if not keyframe_data then
            -- Not in cache, need to compile
            local cleaned_content = script_content:gsub("^\xEF\xBB\xBF", ""):gsub("\r\n", "\n"):gsub("\r", "\n")
            if cleaned_content:match("^%s*return%s*{%s*local") then
                cleaned_content = cleaned_content:gsub("^%s*return%s*{%s*local", "local")
                local varName = cleaned_content:match("^%s*local%s+([%w_]+)%s*=")
                if varName then
                    cleaned_content = cleaned_content .. "\nreturn " .. varName
                end
            end
            local loaded_fn, err = loadstring(cleaned_content);
            if not loaded_fn then 
                return "Animation Error: Invalid script content. " .. tostring(err);
            end;

            local ok, data = pcall(function() return loaded_fn() end);
            if not ok then 
                return "Animation Error: Script failed to execute. " .. tostring(data);
            end;

            if typeof(data) ~= "table" then 
                return "Animation Error: Script did not return a table.";
            end;
            
            keyframe_data = data;
            anim.cache[name] = keyframe_data;
        end;

        local keyframes = keyframe_data[next(keyframe_data)];
        if not keyframes or type(keyframes) ~= "table" or #keyframes == 0 then
            if type(keyframe_data) == "table" then
                if keyframe_data[1] and type(keyframe_data[1]) == "table" and keyframe_data[1].Time then
                    keyframes = keyframe_data;
                else
                    keyframes = keyframe_data.Keyframes or keyframe_data.keyframes or keyframe_data.data or keyframe_data.frames;
                end
            end
            
            if not keyframes or type(keyframes) ~= "table" or #keyframes == 0 then
                return "No valid keyframes array found for animation: " .. name;
            end
        end;

        anim.state.keyframes = keyframes;

        table.clear(anim.constraints);
        table.clear(anim.original_transforms);

        -- Build constraint lookup once per clone; reuse on every subsequent play
        if not anim.constraints_cache then
            anim.constraints_cache = {};
            anim.bind_lengths = {};
            anim.bind_transforms = {};
            for _, descendant in ipairs(clone:GetDescendants()) do
                if descendant:IsA("AnimationConstraint") then
                    local attachment = descendant.Attachment1;
                    if attachment and attachment.Parent then
                        anim.constraints_cache[attachment.Parent.Name] = descendant;
                        anim.bind_transforms[descendant] = descendant.Transform;
                        local att0 = descendant.Attachment0;
                        local att1 = descendant.Attachment1;
                        if att0 and att1 and att0.Parent and att1.Parent then
                            local len = (att1.WorldCFrame.Position - att0.WorldCFrame.Position).Magnitude;
                            if len > 0.001 then
                                anim.bind_lengths[descendant] = len;
                            end;
                        end;
                    end;
                elseif descendant:IsA("Motor6D") then
                    local childPart = descendant.Part1;
                    if childPart and childPart.Parent and not anim.constraints_cache[childPart.Name] then
                        anim.constraints_cache[childPart.Name] = descendant;
                        anim.bind_transforms[descendant] = descendant.Transform;
                    end;
                end;
            end;
        end;
        for partName, constraint in pairs(anim.constraints_cache) do
            if constraint and constraint.Parent then
                anim.constraints[partName] = constraint;
                anim.original_transforms[constraint] = anim.bind_transforms[constraint] or constraint.Transform;
            end;
        end;

        anim.state.is_playing = true;
        anim.state.current_url = name;
        anim.state.total_duration = keyframes[#keyframes].Time;
        if anim.state.total_duration <= 0 then 
            API.stop_animation(); 
            return;
        end;

        anim.state.elapsed_time = 0;

        if halo.callbacks.on_play then
            pcall(halo.callbacks.on_play, anim.state.current_url);
        end;

        local last_index = 1
        halo.connections.animation_hb = halo.services.run_service.PreSimulation:Connect(LPH_NO_VIRTUALIZE(function(deltaTime)
            if not anim.state.is_playing then return end;

            local animator = get_animator(clone);
            if animator and animator.EvaluationThrottled then
                -- still fall through so head / arm trackers keep running
            else
            if false then return end
            end;
            do local _skipAnim = animator and animator.EvaluationThrottled
            if _skipAnim then
                anim.state.elapsed_time = anim.state.elapsed_time -- keep clock
            end
            if not _skipAnim then

            anim.state.elapsed_time = (anim.state.elapsed_time + (deltaTime * anim.state.speed)) % anim.state.total_duration;

            local keyframes = anim.state.keyframes
            local elapsed = anim.state.elapsed_time
            local num_keyframes = #keyframes
            local current_frame, next_frame;

            if not last_index or last_index >= num_keyframes then
                last_index = 1
            end

            if elapsed >= keyframes[last_index].Time and (last_index == num_keyframes or elapsed < keyframes[last_index + 1].Time) then
                current_frame = keyframes[last_index]
                next_frame = keyframes[last_index == num_keyframes and 1 or last_index + 1]
            elseif last_index < num_keyframes and elapsed >= keyframes[last_index + 1].Time and (last_index + 1 == num_keyframes or elapsed < keyframes[last_index + 2].Time) then
                last_index = last_index + 1
                current_frame = keyframes[last_index]
                next_frame = keyframes[last_index == num_keyframes and 1 or last_index + 1]
            else
                local low = 1
                local high = num_keyframes - 1
                local found = 1
                while low <= high do
                    local mid = math.floor((low + high) / 2)
                    if elapsed >= keyframes[mid].Time then
                        found = mid
                        low = mid + 1
                    else
                        high = mid - 1
                    end
                end
                last_index = found
                current_frame = keyframes[last_index]
                next_frame = keyframes[last_index == num_keyframes and 1 or last_index + 1]
            end

            if not current_frame then
                current_frame = keyframes[num_keyframes];
                next_frame = keyframes[1];
            end;

            local frame_duration = next_frame.Time - current_frame.Time;
            if frame_duration <= 0 then frame_duration = anim.state.total_duration end;

            local alpha = (frame_duration > 0) and (anim.state.elapsed_time - current_frame.Time) / frame_duration or 0;
            alpha = math.clamp(alpha, 0, 1);

            for partName, pose_cframe in pairs(current_frame.Data) do
                local constraint = anim.constraints[partName];
                if constraint and constraint.Parent and anim.original_transforms[constraint] then
                    local next_pose_cframe = next_frame.Data and next_frame.Data[partName];
                    local interpolated_transform;
                    if next_pose_cframe then
                        interpolated_transform = pose_cframe:Lerp(next_pose_cframe, alpha);
                    else
                        interpolated_transform = pose_cframe;
                    end;
                    constraint.Transform = interpolated_transform;
                end;
            end;
            end -- not throttled
            end -- do _skipAnim

            if _G._PrismBlendStep then _G._PrismBlendStep() end

            -- Head Tracker: realistic smooth neck tracking with clamped limits
            if _G._HaloHeadTrackerEnabled then
                local headConstraint = anim.constraints["Head"] or anim.constraints["head"] or anim.constraints["Neck"];
                if headConstraint then
                    local camera = workspace.CurrentCamera;
                    if camera then
                        local parentWorldCF = nil;
                        if headConstraint:IsA("Motor6D") and headConstraint.Part0 then
                            parentWorldCF = headConstraint.Part0.CFrame * headConstraint.C0;
                        else
                            local att0 = headConstraint.Attachment0;
                            if att0 and att0.Parent then
                                parentWorldCF = att0.WorldCFrame;
                            end;
                        end;
                        if parentWorldCF then
                            local bindTransform = anim.original_transforms[headConstraint];
                            if bindTransform then
                                local camLook = camera.CFrame.LookVector;
                                local localLookDir = parentWorldCF.Rotation:Inverse() * camLook;

                                -- Extract yaw & pitch and clamp to realistic neck limits
                                local yaw = math.atan2(localLookDir.X, -localLookDir.Z);
                                local pitch = math.asin(math.clamp(localLookDir.Y, -1, 1));
                                local maxYaw = math.rad(75);
                                local maxPitch = math.rad(55);
                                yaw = math.clamp(yaw, -maxYaw, maxYaw);
                                pitch = math.clamp(pitch, -maxPitch, maxPitch);

                                -- Rebuild clamped local look direction
                                local clampedDir = Vector3.new(
                                    math.sin(yaw) * math.cos(pitch),
                                    math.sin(pitch),
                                    -math.cos(yaw) * math.cos(pitch)
                                ).Unit;

                                -- Compute target rotation from bind pose to clamped direction
                                local bindDir = bindTransform.LookVector;
                                local rotAxis = bindDir:Cross(clampedDir);
                                local targetTransform;
                                if rotAxis.Magnitude > 0.001 then
                                    rotAxis = rotAxis.Unit;
                                    local angle = math.acos(math.clamp(bindDir:Dot(clampedDir), -1, 1));
                                    targetTransform = CFrame.fromAxisAngle(rotAxis, angle) * bindTransform;
                                elseif bindDir:Dot(clampedDir) < 0 then
                                    local perp = bindDir:Cross(Vector3.new(0, 1, 0));
                                    if perp.Magnitude < 0.001 then
                                        perp = bindDir:Cross(Vector3.new(1, 0, 0));
                                    end;
                                    targetTransform = CFrame.fromAxisAngle(perp.Unit, math.pi) * bindTransform;
                                else
                                    targetTransform = bindTransform;
                                end;

                                -- Smooth interpolation so it feels like a real neck turning
                                local smoothed = _G._HaloHeadTrackerSmoothedCF or bindTransform;
                                smoothed = smoothed:Lerp(targetTransform, 0.15);
                                _G._HaloHeadTrackerSmoothedCF = smoothed;
                                headConstraint.Transform = smoothed;
                            end;
                        end;
                    end;
                end;
            end;

            -- Arm Pointer: straight arm pointing at mouse target
            -- When enabled: shoulder rotates toward cursor, elbow/wrist are locked
            -- to bind pose so the arm is perfectly straight.
            -- When disabled: this entire block is skipped, so the keyframe animation
            -- computed above resumes naturally for every joint.
            if (_G._HaloLeftArmPointerEnabled or _G._HaloRightArmPointerEnabled) and _G._HaloArmAiming then
                local camera = workspace.CurrentCamera
                local mouse = plr:GetMouse()
                if camera and mouse then
                    local targetPos
                    local unitRay = camera:ViewportPointToRay(mouse.X, mouse.Y)
                    local rayParams = RaycastParams.new()
                    rayParams.FilterType = Enum.RaycastFilterType.Exclude
                    local filterList = {}
                    pcall(function()
                        if ReanimateAPI.get_clone then
                            local clone = ReanimateAPI.get_clone(plr)
                            if clone then table.insert(filterList, clone) end
                        end
                        if ReanimateAPI.get_real_character then
                            local real = ReanimateAPI.get_real_character(plr)
                            if real then table.insert(filterList, real) end
                        end
                    end)
                    rayParams.FilterDescendantsInstances = filterList
                    local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, rayParams)
                    if result then
                        targetPos = result.Position
                    else
                        targetPos = unitRay.Origin + unitRay.Direction * 1000
                    end

                    local function pointArm(upperName, lowerName, handName, stretchMult)
                        local shoulderConstraint = anim.constraints[upperName]
                        if not shoulderConstraint then
                            local alias = (upperName == "RightUpperArm" and (anim.constraints["Right Arm"] or anim.constraints["RightUpperArm"]))
                                or (upperName == "LeftUpperArm" and (anim.constraints["Left Arm"] or anim.constraints["LeftUpperArm"]))
                            shoulderConstraint = alias
                        end
                        if not shoulderConstraint then return end

                        local shoulderWorldCF = nil;
                        if shoulderConstraint:IsA("Motor6D") and shoulderConstraint.Part0 then
                            shoulderWorldCF = shoulderConstraint.Part0.CFrame * shoulderConstraint.C0;
                        else
                            local att0 = shoulderConstraint.Attachment0
                            if att0 and att0.Parent then
                                shoulderWorldCF = att0.WorldCFrame
                            end
                        end
                        if not shoulderWorldCF then return end

                        local shoulderPos = shoulderWorldCF.Position
                        local aimDir = (targetPos - shoulderPos)
                        if aimDir.Magnitude <= 0.001 then return end
                        aimDir = aimDir.Unit

                        -- ALWAYS use bind pose as the base for rotation math.
                        local bindTransform = anim.original_transforms[shoulderConstraint]
                        if not bindTransform then return end

                        -- R15 convention: the arm bone extends along the child's local -Y axis.
                        local childBoneDir = Vector3.new(0, -1, 0)
                        local bindBoneDir = (bindTransform.Rotation * childBoneDir).Unit
                        local localAimDir = shoulderWorldCF.Rotation:Inverse() * aimDir

                        -- Compute shortest rotation from bindBoneDir to localAimDir
                        local rotAxis = bindBoneDir:Cross(localAimDir)
                        local shoulderResult
                        if rotAxis.Magnitude > 0.001 then
                            rotAxis = rotAxis.Unit
                            local angle = math.acos(math.clamp(bindBoneDir:Dot(localAimDir), -1, 1))
                            local rotationCF = CFrame.fromAxisAngle(rotAxis, angle)
                            shoulderResult = rotationCF * bindTransform
                        elseif bindBoneDir:Dot(localAimDir) < 0 then
                            local perp = bindBoneDir:Cross(Vector3.new(0, 1, 0))
                            if perp.Magnitude < 0.001 then
                                perp = bindBoneDir:Cross(Vector3.new(1, 0, 0))
                            end
                            shoulderResult = CFrame.fromAxisAngle(perp.Unit, math.pi) * bindTransform
                        else
                            shoulderResult = bindTransform
                        end

                        shoulderConstraint.Transform = shoulderResult

                        -- Force elbow and wrist to pure bind pose (identity) so the arm
                        -- stays perfectly straight and never drifts over time.
                        local elbowConstraint = anim.constraints[lowerName]
                        if elbowConstraint then
                            elbowConstraint.Transform = CFrame.new()
                        end
                        local wristConstraint = anim.constraints[handName]
                        if wristConstraint then
                            wristConstraint.Transform = CFrame.new()
                        end

                        -- Stretch only the lower arm so it gets longer.
                        stretchMult = stretchMult or 1.0
                        if stretchMult ~= 1.0 then
                            local c = anim.constraints[lowerName]
                            local bind = c and anim.original_transforms[c]
                            if bind then
                                local boneDir = (bind.Rotation * Vector3.new(0, -1, 0)).Unit
                                local baseLen = anim.bind_lengths and anim.bind_lengths[c]
                                if not baseLen or baseLen < 0.001 then
                                    if c:IsA("Motor6D") and c.Part1 and c.Part1:IsA("BasePart") then
                                        baseLen = c.Part1.Size.Y
                                    else
                                        local att1 = c and c.Attachment1
                                        if att1 and att1.Parent and att1.Parent:IsA("BasePart") then
                                            baseLen = att1.Parent.Size.Y
                                        else
                                            baseLen = 1.2
                                        end
                                    end
                                end
                                local stretchOffset = boneDir * baseLen * (stretchMult - 1.0)
                                c.Transform = CFrame.new(stretchOffset) * bind.Rotation
                            end
                        end
                    end

                    local stretchAmt = _G._HaloArmStretchAmount or 2.5
                    if _G._HaloRightArmPointerEnabled then
                        local isStretching = _G._HaloRightArmStretching or false
                        pointArm("RightUpperArm", "RightLowerArm", "RightHand", isStretching and stretchAmt or 1.0)
                    end
                    if _G._HaloLeftArmPointerEnabled then
                        local isStretching = _G._HaloLeftArmStretching or false
                        pointArm("LeftUpperArm", "LeftLowerArm", "LeftHand", isStretching and stretchAmt or 1.0)
                    end
                end
            end
        end))
    end;

    API.stop_animation = function()
        if not halo.animation.state.is_playing then return end;

        local stopped_url = halo.animation.state.current_url;

        if halo.connections.animation_hb then
            halo.connections.animation_hb:Disconnect();
            halo.connections.animation_hb = nil;
        end;

        local player = get_local_player();
        if typeof(player) == "string" then return player end;

        local real_char = halo.real_chars[player];
        if real_char then
            for _, part in ipairs(real_char:GetDescendants()) do
                if part:IsA("BasePart") then
                    pcall(function()
                        part.Velocity = Vector3.zero;
                        part.RotVelocity = Vector3.zero;
                        part.AssemblyLinearVelocity = Vector3.zero;
                        part.AssemblyAngularVelocity = Vector3.zero;
                    end);
                end;
            end;
        end;

        local clone = API.get_clone(player);
        if clone then
            for _, part in ipairs(clone:GetDescendants()) do
                if part:IsA("BasePart") then
                    pcall(function()
                        part.Velocity = Vector3.zero;
                        part.RotVelocity = Vector3.zero;
                        part.AssemblyLinearVelocity = Vector3.zero;
                        part.AssemblyAngularVelocity = Vector3.zero;
                    end);
                end;
            end;
            for constraint, orig_transform in pairs(halo.animation.original_transforms) do
                if constraint and constraint.Parent then
                    constraint.Transform = orig_transform;
                end;
            end;
            local clone_humanoid = clone:FindFirstChildOfClass("Humanoid");
            if clone_humanoid then
                local animator = clone_humanoid:FindFirstChildOfClass("Animator");
                if animator then
                    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                        track:Stop();
                        pcall(function() track:Destroy() end)
                    end;
                end;
            end;
            local clone_animate_script = clone:FindFirstChild("Animate");
            if clone_animate_script then
                clone_animate_script.Enabled = true;
            end;
        end;

        table.clear(halo.animation.original_transforms);
        table.clear(halo.animation.constraints);
        halo.animation.state = {
            is_playing = false;
            current_url = nil;
            speed = 1.0;
            keyframes = nil;
            total_duration = 0;
            elapsed_time = 0;
        };

        if halo.callbacks.on_stop then
            pcall(halo.callbacks.on_stop, stopped_url);
        end;
    end;

    -- Lightweight stop used between state transitions — disconnects the animation
    -- heartbeat and clears state WITHOUT snapping bones back to bind pose.
    -- The next animation will overwrite the constraint transforms on its first tick.
    API.stop_animation_for_transition = function()
        if not halo.animation.state.is_playing then return end;
        local stopped_url = halo.animation.state.current_url;
        if halo.connections.animation_hb then
            halo.connections.animation_hb:Disconnect();
            halo.connections.animation_hb = nil;
        end;
        -- Stash the CURRENT pose so the crossfade can blend smoothly FROM it into
        -- the next animation instead of snapping to bind pose first.
        pcall(function()
            local poses = {};
            for _, c in pairs(halo.animation.constraints) do
                if c and c.Parent then
                    local ok, tr = pcall(function() return c.Transform end);
                    if ok and typeof(tr) == "CFrame" then poses[c] = tr end;
                end;
            end;
            if next(poses) then
                _G._HaloPendingBlendPose = poses;
                _G._HaloPendingBlendPoseTime = os.clock();
            end;
        end);
        -- Keep current pose for crossfade when Emote Smoothness is on.
        -- Only snap to bind pose when smoothness is essentially off.
        local smooth = tonumber(rawget(_G, "_CyrisEmoteSmoothness")) or 0;
        if smooth < 0.05 then
            for constraint, orig_transform in pairs(halo.animation.original_transforms) do
                if constraint and constraint.Parent then
                    constraint.Transform = orig_transform;
                end;
            end;
        end;
        table.clear(halo.animation.original_transforms);
        table.clear(halo.animation.constraints);
        halo.animation.state = {
            is_playing = false;
            current_url = nil;
            speed = 1.0;
            keyframes = nil;
            total_duration = 0;
            elapsed_time = 0;
        };
        if halo.callbacks.on_stop then
            pcall(halo.callbacks.on_stop, stopped_url);
        end;
    end;

    API.reanimate = function(bool, remote, args)
        if bool ~= true and bool ~= false then
            return ("bad argument #1 to 'reanimate' (boolean expected, got %s)"):format(typeof(bool));
        end;
        local player = get_local_player();
        if typeof(player) == "string" then return player end;

        local is_local_event = false;
        if not remote then
            local game_remote, game_args, is_local = get_game_ragdoll_info(bool);
            if game_remote then
                remote = game_remote;
                args = game_args;
                is_local_event = is_local;
            end;
        end;

        if bool then
            -- Store remote/args so rebuild_clone can re-enable without needing them passed in
            halo.flags.active_remote   = remote;
            halo.flags.active_args     = args;
            halo.flags.active_is_local = is_local_event;
            -- Disconnect any previous swap watcher before registering a new one
            if halo.swap_conn then halo.swap_conn:Disconnect(); halo.swap_conn = nil; end;
            if halo.flags.reanimated then
                return "Already reanimated.";
            end;
            local real_char = get_char(player);
            if typeof(real_char) == "string" then return real_char end;
            if not real_char:FindFirstChild("Humanoid") then
                return "Real character is missing a Humanoid.";
            end;
            local real_hrp = real_char:FindFirstChild("HumanoidRootPart");
            if not real_hrp then
                return "Real character is missing a HumanoidRootPart, cannot reanimate.";
            end;

            -- Save camera state
            local camera = halo.services.workspace.CurrentCamera;
            local saved_camera_cframe = camera.CFrame;
            local saved_camera_focus = camera.Focus;

            halo.real_chars[player] = real_char;
            
            -- Safety net: destroy any stale clone left from a previous session
            local staleClone = halo.clones[player];
            if staleClone then
                pcall(function() staleClone:Destroy() end);
                halo.clones[player] = nil;
            end;

            -- Clone BEFORE hiding the real char so the clone inherits correct
            -- transparency (0) instead of inheriting the hidden state (1).
            local cloned_char = clone_char(real_char);
            if typeof(cloned_char) == "string" then return cloned_char end;
            if not cloned_char:FindFirstChild("Humanoid") then
                return "Cloned character failed to create or is missing a Humanoid.";
            end;
            halo.clones[player] = cloned_char;

            -- Single pass on real_char: hide + disable collision/query
            for _, part in ipairs(real_char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Transparency = 1;
                    part.CanCollide   = false;
                    part.CanTouch     = false;
                    part.CanQuery     = false;
                end;
            end;

            -- Single pass on clone: set visibility + disable collision/query
            for _, part in ipairs(cloned_char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false;
                    part.CanQuery   = false;
                    part.Transparency = (part.Name == "HumanoidRootPart") and 1 or 0;
                end;
            end;
            
            -- Match clone position to real character before swapping to prevent jitter
            local cloned_hrp = cloned_char:FindFirstChild("HumanoidRootPart");
            if cloned_hrp and real_hrp then
                cloned_hrp.CFrame = real_hrp.CFrame;
                cloned_hrp.Velocity = Vector3.zero;
                cloned_hrp.RotVelocity = Vector3.zero;
                -- HRP is already anchored from clone_char; just keep it that way until after the swap
            end;

            -- Pre-build part pairs once so the heartbeat never calls GetChildren/FindFirstChild
            local part_pairs = {};
            for _, p in ipairs(real_char:GetChildren()) do
                if p:IsA("BasePart") then
                    local clone_part = cloned_char:FindFirstChild(p.Name);
                    if clone_part then
                        table.insert(part_pairs, { real = p, clone = clone_part });
                    end;
                end;
            end;

            -- Stop the real humanoid from fighting us during the transition
            local real_humanoid_pre = real_char:FindFirstChildOfClass("Humanoid");
            local savedWalkSpeed, savedJumpPower = 16, 50;
            if real_humanoid_pre then
                savedWalkSpeed = real_humanoid_pre.WalkSpeed;
                savedJumpPower = real_humanoid_pre.JumpPower;
                real_humanoid_pre.WalkSpeed = 0;
                real_humanoid_pre.JumpPower = 0;
                
                -- Disable default animations on the real character to prevent animator track build-ups
                local real_animate = real_char:FindFirstChild("Animate")
                if real_animate then
                    real_animate.Enabled = false
                end
                local real_animator = real_humanoid_pre:FindFirstChildOfClass("Animator")
                if real_animator then
                    for _, track in ipairs(real_animator:GetPlayingAnimationTracks()) do
                        track:Stop()
                        pcall(function() track:Destroy() end)
                    end
                end

                -- Zero out real HRP velocity so the freeze is instant
                if real_hrp then
                    real_hrp.Velocity = Vector3.zero;
                    real_hrp.RotVelocity = Vector3.zero;
                end;
            end;
            
            -- Clone is already anchored at the real char's CFrame with correct position.
            -- Do NOT hide it — real char is already invisible, so keeping clone visible
            -- prevents the disappear flash during the character swap.
            -- set_model_transparency(cloned_char, 1) -- intentionally removed

            local originalResetOnSpawnStates = {}
            local player_gui = player:FindFirstChildWhichIsA("PlayerGui");
            if player_gui then
                for _, gui in ipairs(player_gui:GetChildren()) do
                    if gui:IsA("ScreenGui") then
                        originalResetOnSpawnStates[gui] = gui.ResetOnSpawn
                        if gui.ResetOnSpawn then
                            gui.ResetOnSpawn = false;
                        end
                    end;
                end;
            end;
            
            player.Character = cloned_char;

            -- Set camera subject explicitly to prevent engine from resetting the camera
            local clonedHum = cloned_char:FindFirstChildOfClass("Humanoid");
            if clonedHum then
                camera.CameraSubject = clonedHum;
            end;

            -- Restore camera on the very next render step (after the engine has processed the character swap)
            local restoreConn;
            restoreConn = halo.services.run_service.RenderStepped:Connect(LPH_JIT_MAX(function()
                restoreConn:Disconnect();
                camera.CFrame = saved_camera_cframe;
                camera.Focus = saved_camera_focus;
                -- Unanchor all clone parts now that the swap is complete.
                if cloned_char and cloned_char.Parent then
                    for _, part in ipairs(cloned_char:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.Anchored = false;
                        end;
                    end;
                end;
                -- Hide the real character so only the clone is visible
                if real_char and real_char.Parent then
                    set_model_transparency(real_char, 1);
                end;
                -- Restore real humanoid movement
                local rh = real_char and real_char:FindFirstChildOfClass("Humanoid");
                if rh then
                    rh.WalkSpeed = savedWalkSpeed;
                    rh.JumpPower = savedJumpPower;
                end;
                -- Re-enable real Animate script now that the swap is done
                -- (it was disabled before cloning to prevent track leaks into the clone)
                local rAnimate = real_char and real_char:FindFirstChild("Animate");
                if rAnimate then rAnimate.Disabled = false end;
                -- Restore original ResetOnSpawn states
                for gui, originalVal in pairs(originalResetOnSpawnStates) do
                    if gui and gui.Parent then
                        gui.ResetOnSpawn = originalVal
                    end
                end
            end))

            camera = halo.services.workspace.CurrentCamera;

            pcall(function()
                settings().Physics.AllowPhysicsSimulation = true
                settings().Physics.PhysicsEnvironmentalThrottle = Enum.EnviromentalPhysicsThrottle.Disabled
            end)

            halo.connections.hb = halo.services.run_service.Heartbeat:Connect(LPH_JIT_MAX(function()
                if not real_char or not real_char.Parent or not cloned_char or not cloned_char.Parent then
                    API.reanimate(false, remote, args);
                    return;
                end;

                for _, pair in ipairs(part_pairs) do
                    local p = pair.real;
                    local clone_part = pair.clone;
                    if p.Parent and clone_part.Parent then
                        p.CFrame = clone_part.CFrame;
                        -- Do NOT copy the clone's velocity onto the ragdolled real
                        -- character. Copying it lets residual/jump velocity dump into
                        -- the loose ragdoll and fling you (worst at enable). The CFrame
                        -- sync alone is enough to keep the bodies visually aligned.
                        p.AssemblyLinearVelocity  = Vector3.zero;
                        p.AssemblyAngularVelocity = Vector3.zero;
                    end;
                end;

                if halo.animation.state.is_playing then
                    local real_hrp = real_char:FindFirstChild("HumanoidRootPart");
                    if real_hrp then
                        real_hrp.AssemblyLinearVelocity  = Vector3.zero;
                        real_hrp.AssemblyAngularVelocity = Vector3.zero;
                    end;
                end;
            end));

            -- Shift lock rotation (RenderStepped so it applies before the frame is drawn)
            halo.connections.shiftlock_hb = halo.services.run_service.RenderStepped:Connect(LPH_JIT_MAX(function()
                if not cloned_char or not cloned_char.Parent then return end;
                local cloneHRP = cloned_char:FindFirstChild("HumanoidRootPart");
                local cloneHum = cloned_char:FindFirstChild("Humanoid");
                if cloneHRP and cloneHum and camera and camera.CameraType == Enum.CameraType.Custom then
                    local isShiftLock = false;
                    pcall(function() isShiftLock = UserInputService.IsMouseLocked end);
                    if isShiftLock then
                        local camLook = camera.CFrame.LookVector;
                        local flatLook = Vector3.new(camLook.X, 0, camLook.Z);
                        if flatLook.Magnitude > 0.001 then
                            flatLook = flatLook.Unit;
                            local rightVec = Vector3.new(flatLook.Z, 0, -flatLook.X);
                            cloneHRP.CFrame = CFrame.fromMatrix(cloneHRP.Position, rightVec, Vector3.new(0, 1, 0), -flatLook);
                        end;
                    end;
                end;
            end));

            local real_humanoid = real_char.Humanoid;
            local cloned_humanoid = cloned_char.Humanoid;

            halo.connections.died = real_humanoid.Died:Connect(function()
                API.reanimate(false, remote, args);
            end);
            halo.connections.real_char_child_removed = real_char.ChildRemoved:Connect(function(child)
                if child == real_humanoid or child == real_hrp then
                    API.reanimate(false, remote, args);
                end;
            end);
            halo.connections.clone_char_child_removed = cloned_char.ChildRemoved:Connect(function(child)
                if child == cloned_humanoid then
                    API.reanimate(false, remote, args);
                end;
            end);
            halo.connections.clone_died = cloned_humanoid.Died:Connect(function()
                local current_real_humanoid = real_char and real_char:FindFirstChild("Humanoid");
                if current_real_humanoid and current_real_humanoid.Health > 0 then
                    current_real_humanoid.Health = 0;
                else
                    API.reanimate(false, remote, args);
                end;
            end);
            -- Avatar swap: disconnect first, destroy old clone, then immediately
            -- re-clone the new character so clone_char = player.Character.
            local _savedRemote = remote;
            local _savedArgs   = args;
            halo.connections.character_removing = player.CharacterRemoving:Connect(function()
                -- Disconnect all connections BEFORE destroying anything
                for key, conn in pairs(halo.connections) do
                    if conn then conn:Disconnect(); halo.connections[key] = nil; end;
                end;
                halo.flags.reanimated = false;
                -- Destroy old clone now that callbacks are gone
                local oldClone = halo.clones[player];
                if oldClone then pcall(function() oldClone:Destroy() end); halo.clones[player] = nil; end;
                halo.real_chars[player] = nil;
                -- Immediately re-enable once new character is assigned
                local reEnableConn;
                reEnableConn = player.CharacterAdded:Connect(function()
                    reEnableConn:Disconnect();
                    API.reanimate(true, _savedRemote, _savedArgs);
                end);
            end);

            halo.flags.reanimated = true;
            if remote then
                local err = fire_remote(remote, is_local_event, unpack(args or {}));
                if err then return err end;
            end;
        else
            if not halo.flags.reanimated then return end;
            API.stop_animation();
            halo.animation.constraints_cache = nil;

            camera = halo.services.workspace.CurrentCamera;
            local saved_camera_cframe = camera.CFrame;
            local saved_camera_focus  = camera.Focus;

            if remote then
                local err = fire_remote(remote, is_local_event, unpack(args or {}));
                if err then return err end;
            end;
            for key, connection in pairs(halo.connections) do
                if connection then connection:Disconnect(); halo.connections[key] = nil; end;
            end;
            local cloned_char = halo.clones[player];
            if cloned_char then
                local clone_hrp = cloned_char:FindFirstChild("HumanoidRootPart");
                if clone_hrp then pcall(sethiddenproperty, clone_hrp, "PhysicsRepRootPart", nil); end;
            end;
            local real_char = halo.real_chars[player];

            -- Match real_char position to clone before swapping back
            if cloned_char and cloned_char.Parent and real_char and real_char.Parent then
                local clone_hrp = cloned_char:FindFirstChild("HumanoidRootPart");
                local real_hrp  = real_char:FindFirstChild("HumanoidRootPart");
                if clone_hrp and real_hrp then
                    clone_hrp.Velocity    = Vector3.zero;
                    clone_hrp.RotVelocity = Vector3.zero;
                    real_hrp.CFrame       = clone_hrp.CFrame;
                    real_hrp.Velocity     = Vector3.zero;
                    real_hrp.RotVelocity  = Vector3.zero;
                    real_hrp.Anchored     = true;
                end;
                local clone_hum = cloned_char:FindFirstChildOfClass("Humanoid");
                if clone_hum then clone_hum.WalkSpeed = 0; clone_hum.JumpPower = 0; end;
            end;

            if real_char and real_char.Parent then
                set_model_transparency(real_char, 0);
                set_model_query(real_char, true);
                for _, part in real_char:GetDescendants() do
                    if part:IsA("BasePart") then
                        part.CanCollide = true; part.CanTouch = true; part.CanQuery = true;
                    end;
                end;
                local hrp = real_char:FindFirstChild("HumanoidRootPart");
                if hrp then hrp.Transparency = 1; hrp.CanCollide = false; end;
                local originalResetOnSpawnStates2 = {};
                local player_gui = player:FindFirstChildWhichIsA("PlayerGui");
                if player_gui then
                    for _, gui in ipairs(player_gui:GetChildren()) do
                        if gui:IsA("ScreenGui") then
                            originalResetOnSpawnStates2[gui] = gui.ResetOnSpawn;
                            if gui.ResetOnSpawn then gui.ResetOnSpawn = false; end;
                        end;
                    end;
                end;
                local realHum = real_char:FindFirstChildOfClass("Humanoid");
                if realHum then camera.CameraSubject = realHum; end;
                player.Character = real_char;
                if cloned_char and cloned_char.Parent then
                    cloned_char:Destroy(); halo.clones[player] = nil;
                end;
                local restoreConn2;
                restoreConn2 = halo.services.run_service.RenderStepped:Connect(LPH_JIT_MAX(function()
                    restoreConn2:Disconnect();
                    camera.CFrame = saved_camera_cframe;
                    camera.Focus  = saved_camera_focus;
                    local real_animate = real_char and real_char:FindFirstChild("Animate");
                    if real_animate then real_animate.Enabled = true; end;
                    local rhrp = real_char and real_char:FindFirstChild("HumanoidRootPart");
                    if rhrp then rhrp.Anchored = false; end;
                    for gui, originalVal in pairs(originalResetOnSpawnStates2) do
                        if gui and gui.Parent then gui.ResetOnSpawn = originalVal; end;
                    end;
                end));
            else
                if cloned_char and cloned_char.Parent then
                    cloned_char:Destroy(); halo.clones[player] = nil;
                end;
            end;
            halo.flags.reanimated = false;
        end;
    end;

    API.play_animation = function(url, speed)
        if not halo.flags.reanimated then
            return "Cannot play animation, not reanimated.";
        end;

        local player = get_local_player();
        if typeof(player) == "string" then return player end;

        local clone = API.get_clone(player);
        if not clone then
            return "Cannot play animation, clone character not found.";
        end;

        if halo.animation.state.is_playing and halo.animation.state.current_url == url then
            API.stop_animation();
            return;
        end;

        API.stop_animation();

        local clone_humanoid = clone:FindFirstChildOfClass("Humanoid");
        if clone_humanoid then
            local animator = clone_humanoid:FindFirstChildOfClass("Animator");
            if animator then
                for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                    track:Stop();
                end;
            end;
        end;

        local clone_animate_script = clone:FindFirstChild("Animate");
        if clone_animate_script then
            clone_animate_script.Enabled = false;
        end;

        local anim = halo.animation;
        anim.state.speed = tonumber(speed) or 1.0;

        local keyframe_data = anim.cache[url];
        if not keyframe_data then
            local success, response = pcall(game.HttpGet, game, url);
            if not success then return "Animation Error: Failed to fetch URL." end;

            local loaded_fn, err = loadstring(response);
            if not loaded_fn then return "Animation Error: Invalid script from URL. " .. tostring(err) end;

            local ok, data = pcall(function() return loaded_fn() end);
            if not ok then return "Animation Error: Script from URL failed to execute. " .. tostring(data) end;
            keyframe_data = data;

            if typeof(keyframe_data) ~= "table" then return "Animation Error: Script from URL did not return a table." end;

            anim.cache[url] = keyframe_data;
        end;

        local keyframes = keyframe_data[next(keyframe_data)];
        if not keyframes or #keyframes == 0 then
            return "No keyframes array found for animation URL: " .. url;
        end;

        anim.state.keyframes = keyframes;

        table.clear(anim.constraints);
        table.clear(anim.original_transforms);

        -- Build constraint lookup once per clone; reuse on every subsequent play
        if not anim.constraints_cache then
            anim.constraints_cache = {};
            anim.bind_lengths = {};
            anim.bind_transforms = {};
            for _, descendant in ipairs(clone:GetDescendants()) do
                if descendant:IsA("AnimationConstraint") then
                    local attachment = descendant.Attachment1;
                    if attachment and attachment.Parent then
                        anim.constraints_cache[attachment.Parent.Name] = descendant;
                        anim.bind_transforms[descendant] = descendant.Transform;
                        local att0 = descendant.Attachment0;
                        local att1 = descendant.Attachment1;
                        if att0 and att1 and att0.Parent and att1.Parent then
                            local len = (att1.WorldCFrame.Position - att0.WorldCFrame.Position).Magnitude;
                            if len > 0.001 then
                                anim.bind_lengths[descendant] = len;
                            end;
                        end;
                    end;
                elseif descendant:IsA("Motor6D") then
                    local childPart = descendant.Part1;
                    if childPart and childPart.Parent and not anim.constraints_cache[childPart.Name] then
                        anim.constraints_cache[childPart.Name] = descendant;
                        anim.bind_transforms[descendant] = descendant.Transform;
                    end;
                end;
            end;
        end;
        for partName, constraint in pairs(anim.constraints_cache) do
            if constraint and constraint.Parent then
                anim.constraints[partName] = constraint;
                anim.original_transforms[constraint] = anim.bind_transforms[constraint] or constraint.Transform;
            end;
        end;

        anim.state.is_playing = true;
        anim.state.current_url = url;
        anim.state.total_duration = keyframes[#keyframes].Time;
        if anim.state.total_duration <= 0 then API.stop_animation(); return end;

        anim.state.elapsed_time = 0;

        if halo.callbacks.on_play then
            pcall(halo.callbacks.on_play, anim.state.current_url);
        end;

        local last_index = 1
        halo.connections.animation_hb = halo.services.run_service.PreSimulation:Connect(LPH_NO_VIRTUALIZE(function(deltaTime)
            if not anim.state.is_playing then return end;

            local animator = get_animator(clone);
            if animator and animator.EvaluationThrottled then
                -- still fall through so head / arm trackers keep running
            else
            if false then return end
            end;
            do local _skipAnim = animator and animator.EvaluationThrottled
            if _skipAnim then
                anim.state.elapsed_time = anim.state.elapsed_time -- keep clock
            end
            if not _skipAnim then

            anim.state.elapsed_time = (anim.state.elapsed_time + (deltaTime * anim.state.speed)) % anim.state.total_duration;

            local keyframes = anim.state.keyframes
            local elapsed = anim.state.elapsed_time
            local num_keyframes = #keyframes
            local current_frame, next_frame;

            if not last_index or last_index >= num_keyframes then
                last_index = 1
            end

            if elapsed >= keyframes[last_index].Time and (last_index == num_keyframes or elapsed < keyframes[last_index + 1].Time) then
                current_frame = keyframes[last_index]
                next_frame = keyframes[last_index == num_keyframes and 1 or last_index + 1]
            elseif last_index < num_keyframes and elapsed >= keyframes[last_index + 1].Time and (last_index + 1 == num_keyframes or elapsed < keyframes[last_index + 2].Time) then
                last_index = last_index + 1
                current_frame = keyframes[last_index]
                next_frame = keyframes[last_index == num_keyframes and 1 or last_index + 1]
            else
                local low = 1
                local high = num_keyframes - 1
                local found = 1
                while low <= high do
                    local mid = math.floor((low + high) / 2)
                    if elapsed >= keyframes[mid].Time then
                        found = mid
                        low = mid + 1
                    else
                        high = mid - 1
                    end
                end
                last_index = found
                current_frame = keyframes[last_index]
                next_frame = keyframes[last_index == num_keyframes and 1 or last_index + 1]
            end

            if not current_frame then
                current_frame = keyframes[num_keyframes];
                next_frame = keyframes[1];
            end;

            local frame_duration = next_frame.Time - current_frame.Time;
            if frame_duration <= 0 then frame_duration = anim.state.total_duration end;

            local alpha = (frame_duration > 0) and (anim.state.elapsed_time - current_frame.Time) / frame_duration or 0;
            alpha = math.clamp(alpha, 0, 1);

            for partName, pose_cframe in pairs(current_frame.Data) do
                local constraint = anim.constraints[partName];
                if constraint and constraint.Parent and anim.original_transforms[constraint] then
                    local next_pose_cframe = next_frame.Data and next_frame.Data[partName];
                    local interpolated_transform;
                    if next_pose_cframe then
                        interpolated_transform = pose_cframe:Lerp(next_pose_cframe, alpha);
                    else
                        interpolated_transform = pose_cframe;
                    end;
                    constraint.Transform = interpolated_transform;
                end;
            end;
            end -- not throttled
            end -- do _skipAnim

            if _G._PrismBlendStep then _G._PrismBlendStep() end

            -- Head Tracker: realistic smooth neck tracking with clamped limits
            if _G._HaloHeadTrackerEnabled then
                local headConstraint = anim.constraints["Head"] or anim.constraints["head"] or anim.constraints["Neck"];
                if headConstraint then
                    local camera = workspace.CurrentCamera;
                    if camera then
                        local parentWorldCF = nil;
                        if headConstraint:IsA("Motor6D") and headConstraint.Part0 then
                            parentWorldCF = headConstraint.Part0.CFrame * headConstraint.C0;
                        else
                            local att0 = headConstraint.Attachment0;
                            if att0 and att0.Parent then
                                parentWorldCF = att0.WorldCFrame;
                            end;
                        end;
                        if parentWorldCF then
                            local bindTransform = anim.original_transforms[headConstraint];
                            if bindTransform then
                                local camLook = camera.CFrame.LookVector;
                                local localLookDir = parentWorldCF.Rotation:Inverse() * camLook;

                                -- Extract yaw & pitch and clamp to realistic neck limits
                                local yaw = math.atan2(localLookDir.X, -localLookDir.Z);
                                local pitch = math.asin(math.clamp(localLookDir.Y, -1, 1));
                                local maxYaw = math.rad(75);
                                local maxPitch = math.rad(55);
                                yaw = math.clamp(yaw, -maxYaw, maxYaw);
                                pitch = math.clamp(pitch, -maxPitch, maxPitch);

                                -- Rebuild clamped local look direction
                                local clampedDir = Vector3.new(
                                    math.sin(yaw) * math.cos(pitch),
                                    math.sin(pitch),
                                    -math.cos(yaw) * math.cos(pitch)
                                ).Unit;

                                -- Compute target rotation from bind pose to clamped direction
                                local bindDir = bindTransform.LookVector;
                                local rotAxis = bindDir:Cross(clampedDir);
                                local targetTransform;
                                if rotAxis.Magnitude > 0.001 then
                                    rotAxis = rotAxis.Unit;
                                    local angle = math.acos(math.clamp(bindDir:Dot(clampedDir), -1, 1));
                                    targetTransform = CFrame.fromAxisAngle(rotAxis, angle) * bindTransform;
                                elseif bindDir:Dot(clampedDir) < 0 then
                                    local perp = bindDir:Cross(Vector3.new(0, 1, 0));
                                    if perp.Magnitude < 0.001 then
                                        perp = bindDir:Cross(Vector3.new(1, 0, 0));
                                    end;
                                    targetTransform = CFrame.fromAxisAngle(perp.Unit, math.pi) * bindTransform;
                                else
                                    targetTransform = bindTransform;
                                end;

                                -- Smooth interpolation so it feels like a real neck turning
                                local smoothed = _G._HaloHeadTrackerSmoothedCF or bindTransform;
                                smoothed = smoothed:Lerp(targetTransform, 0.15);
                                _G._HaloHeadTrackerSmoothedCF = smoothed;
                                headConstraint.Transform = smoothed;
                            end;
                        end;
                    end;
                end;
            end;

            -- Arm Pointer: straight arm pointing at mouse target
            -- When enabled: shoulder rotates toward cursor, elbow/wrist are locked
            -- to bind pose so the arm is perfectly straight.
            -- When disabled: this entire block is skipped, so the keyframe animation
            -- computed above resumes naturally for every joint.
            if (_G._HaloLeftArmPointerEnabled or _G._HaloRightArmPointerEnabled) and _G._HaloArmAiming then
                local camera = workspace.CurrentCamera
                local mouse = plr:GetMouse()
                if camera and mouse then
                    local targetPos
                    local unitRay = camera:ViewportPointToRay(mouse.X, mouse.Y)
                    local rayParams = RaycastParams.new()
                    rayParams.FilterType = Enum.RaycastFilterType.Exclude
                    local filterList = {}
                    pcall(function()
                        if ReanimateAPI.get_clone then
                            local clone = ReanimateAPI.get_clone(plr)
                            if clone then table.insert(filterList, clone) end
                        end
                        if ReanimateAPI.get_real_character then
                            local real = ReanimateAPI.get_real_character(plr)
                            if real then table.insert(filterList, real) end
                        end
                    end)
                    rayParams.FilterDescendantsInstances = filterList
                    local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, rayParams)
                    if result then
                        targetPos = result.Position
                    else
                        targetPos = unitRay.Origin + unitRay.Direction * 1000
                    end

                    local function pointArm(upperName, lowerName, handName, stretchMult)
                        local shoulderConstraint = anim.constraints[upperName]
                        if not shoulderConstraint then
                            local alias = (upperName == "RightUpperArm" and (anim.constraints["Right Arm"] or anim.constraints["RightUpperArm"]))
                                or (upperName == "LeftUpperArm" and (anim.constraints["Left Arm"] or anim.constraints["LeftUpperArm"]))
                            shoulderConstraint = alias
                        end
                        if not shoulderConstraint then return end

                        local shoulderWorldCF = nil;
                        if shoulderConstraint:IsA("Motor6D") and shoulderConstraint.Part0 then
                            shoulderWorldCF = shoulderConstraint.Part0.CFrame * shoulderConstraint.C0;
                        else
                            local att0 = shoulderConstraint.Attachment0
                            if att0 and att0.Parent then
                                shoulderWorldCF = att0.WorldCFrame
                            end
                        end
                        if not shoulderWorldCF then return end

                        local shoulderPos = shoulderWorldCF.Position
                        local aimDir = (targetPos - shoulderPos)
                        if aimDir.Magnitude <= 0.001 then return end
                        aimDir = aimDir.Unit

                        -- ALWAYS use bind pose as the base for rotation math.
                        local bindTransform = anim.original_transforms[shoulderConstraint]
                        if not bindTransform then return end

                        -- R15 convention: the arm bone extends along the child's local -Y axis.
                        local childBoneDir = Vector3.new(0, -1, 0)
                        local bindBoneDir = (bindTransform.Rotation * childBoneDir).Unit
                        local localAimDir = shoulderWorldCF.Rotation:Inverse() * aimDir

                        -- Compute shortest rotation from bindBoneDir to localAimDir
                        local rotAxis = bindBoneDir:Cross(localAimDir)
                        local shoulderResult
                        if rotAxis.Magnitude > 0.001 then
                            rotAxis = rotAxis.Unit
                            local angle = math.acos(math.clamp(bindBoneDir:Dot(localAimDir), -1, 1))
                            local rotationCF = CFrame.fromAxisAngle(rotAxis, angle)
                            shoulderResult = rotationCF * bindTransform
                        elseif bindBoneDir:Dot(localAimDir) < 0 then
                            local perp = bindBoneDir:Cross(Vector3.new(0, 1, 0))
                            if perp.Magnitude < 0.001 then
                                perp = bindBoneDir:Cross(Vector3.new(1, 0, 0))
                            end
                            shoulderResult = CFrame.fromAxisAngle(perp.Unit, math.pi) * bindTransform
                        else
                            shoulderResult = bindTransform
                        end

                        shoulderConstraint.Transform = shoulderResult

                        -- Force elbow and wrist to pure bind pose (identity) so the arm
                        -- stays perfectly straight and never drifts over time.
                        local elbowConstraint = anim.constraints[lowerName]
                        if elbowConstraint then
                            elbowConstraint.Transform = CFrame.new()
                        end
                        local wristConstraint = anim.constraints[handName]
                        if wristConstraint then
                            wristConstraint.Transform = CFrame.new()
                        end

                        -- Stretch only the lower arm so it gets longer.
                        stretchMult = stretchMult or 1.0
                        if stretchMult ~= 1.0 then
                            local c = anim.constraints[lowerName]
                            local bind = c and anim.original_transforms[c]
                            if bind then
                                local boneDir = (bind.Rotation * Vector3.new(0, -1, 0)).Unit
                                local baseLen = anim.bind_lengths and anim.bind_lengths[c]
                                if not baseLen or baseLen < 0.001 then
                                    if c:IsA("Motor6D") and c.Part1 and c.Part1:IsA("BasePart") then
                                        baseLen = c.Part1.Size.Y
                                    else
                                        local att1 = c and c.Attachment1
                                        if att1 and att1.Parent and att1.Parent:IsA("BasePart") then
                                            baseLen = att1.Parent.Size.Y
                                        else
                                            baseLen = 1.2
                                        end
                                    end
                                end
                                local stretchOffset = boneDir * baseLen * (stretchMult - 1.0)
                                c.Transform = CFrame.new(stretchOffset) * bind.Rotation
                            end
                        end
                    end

                    local stretchAmt = _G._HaloArmStretchAmount or 2.5
                    if _G._HaloRightArmPointerEnabled then
                        local isStretching = _G._HaloRightArmStretching or false
                        pointArm("RightUpperArm", "RightLowerArm", "RightHand", isStretching and stretchAmt or 1.0)
                    end
                    if _G._HaloLeftArmPointerEnabled then
                        local isStretching = _G._HaloLeftArmStretching or false
                        pointArm("LeftUpperArm", "LeftLowerArm", "LeftHand", isStretching and stretchAmt or 1.0)
                    end
                end
            end
        end))
    end;

    API.set_animation_speed = function(speed)
        halo.animation.state.speed = tonumber(speed) or 1.0;
    end;

    API.on_animation_play = function(callback)
        if type(callback) == "function" then
            halo.callbacks.on_play = callback;
        end;
    end;

    API.on_animation_stop = function(callback)
        if type(callback) == "function" then
            halo.callbacks.on_stop = callback;
        end;
    end;

    API.is_animation_playing = function()
        return halo.animation.state.is_playing, halo.animation.state.current_url;
    end;

    API.is_reanimated = function()
        return halo.flags.reanimated;
    end;

    API.get_clone = function(player)
        player = player or get_local_player();
        if typeof(player) == "string" then return nil end;
        return halo.clones[player];
    end;

    API.get_real_character = function(player)
        player = player or get_local_player();
        if typeof(player) == "string" then return nil end;
        return halo.real_chars[player];
    end;

    API.get_animation_data = function()
        return halo.animation;
    end;

    API.seed_animation_cache = function(name, keyframe_data)
        if name then
            halo.animation.cache[name] = keyframe_data;
        end;
    end;

    API.get_animation_cache = function(name)
        return name and halo.animation.cache[name] or nil;
    end;

    API.invalidate_constraint_cache = function()
        -- Called after ApplyDescription/avatar change so the next animation
        -- rebuilds the AnimationConstraint lookup against the new geometry.
        halo.animation.constraints_cache = nil;
        halo.animation.bind_transforms = nil;
        table.clear(halo.animation.constraints);
        table.clear(halo.animation.original_transforms);
    end;

    -- Rebuild the clone from scratch using the current real_char appearance.
    -- Call this after avatar appearance changes (e.g. after event_modify_refresh fires).
    API.rebuild_clone = function()
        if not halo.flags.reanimated then return end;
        local player = get_local_player();
        if typeof(player) == "string" then return end;

        local savedRemote = halo.flags.active_remote;
        local savedArgs   = halo.flags.active_args;

        local old_real  = halo.real_chars[player];
        local old_clone = halo.clones[player];

        if not old_real or not old_real.Parent then return end;

        -- Stop animation and tear down all connections
        API.stop_animation();
        halo.animation.constraints_cache = nil;
        for key, conn in pairs(halo.connections) do
            if conn then conn:Disconnect(); halo.connections[key] = nil; end;
        end;

        -- Restore real_char visibility and collision
        for _, part in ipairs(old_real:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Transparency = 0;
                part.CanCollide   = true;
                part.CanTouch     = true;
                part.CanQuery     = true;
            end;
        end;
        local hrp = old_real:FindFirstChild("HumanoidRootPart");
        if hrp then hrp.Transparency = 1; hrp.CanCollide = false; hrp.Anchored = false; end;
        local real_animate = old_real:FindFirstChild("Animate");
        if real_animate then real_animate.Enabled = true; end;

        -- Point camera at real char before swap
        camera = halo.services.workspace.CurrentCamera;
        local realHum = old_real:FindFirstChildOfClass("Humanoid");
        if realHum and camera then camera.CameraSubject = realHum; end;

        -- Restore real char as player.Character then destroy the stale clone
        player.Character = old_real;
        -- Destroy regardless of Parent (Roblox may have detached it already)
        if old_clone then
            pcall(function() old_clone:Destroy() end);
        end;
        halo.clones[player]     = nil;
        halo.real_chars[player] = nil;
        halo.flags.reanimated   = false;

        -- Brief wait for the engine to settle, then re-enable with updated appearance
        task.wait(0.2);
        API.reanimate(true, savedRemote, savedArgs);
    end;

    ReanimateAPI = API;
    _G._HaloReanimateAPI = API;
end
_reanimAPIReady = true

local CONFIG = {
    -- Basic Settings
    TITLE          = "Reanim",
    VERSION        = "1.0.0",
    ANIMATIONS_URL = "",
    FOLDER         = "ReanimData",
    CACHE_FOLDER   = "ReanimData/cache",
    
    -- Icon Asset IDs (Easy to change!)
    ICONS = {
        STAR_FILLED    = "rbxthumb://type=Asset&id=127142872239507&w=150&h=150",  -- Favorited star icon
        STAR_OUTLINE   = "rbxthumb://type=Asset&id=76957491777613&w=150&h=150",   -- Not favorited star icon
        KEYBOARD       = "rbxthumb://type=Asset&id=78118938629142&w=150&h=150",   -- Keyboard icon for unbound keys
        RESIZE_HANDLE  = "rbxassetid://90832689936120",
    },
    
    -- UI Customization (Optional - you can also edit these!)
    UI = {
        DEFAULT_WIDTH  = 380,   -- Default window width (new unified layout)
        DEFAULT_HEIGHT = 540,   -- Default window height
        MIN_WIDTH      = 300,   -- Minimum window width when resizing
        MIN_HEIGHT     = 360,   -- Minimum window height when resizing
    }
}


-- Compatibility helpers for executor environments missing these globals
local function getSafeScrollingDirection(dir)
    local ok, result = pcall(function() return Enum.ScrollingDirection[dir] end)
    if ok then return result end
    return Enum.ScrollingDirection.Y
end

local function getSafeAutomaticSize()
    local ok, result = pcall(function() return Enum.AutomaticSize.Y end)
    if ok then return result end
    return nil
end


-- Clear reanimation cache on startup
pcall(function()
    local deleteFunc = delfile or delete_file
    local listFilesFunc = listfiles or list_files
    
    if deleteFunc and listFilesFunc then
        -- Clear the cache folder completely
        local okCache, cacheFiles = pcall(function()
            if listFilesFunc then return listFilesFunc("ReanimData/cache") end
            return {}
        end)
        
        if okCache and cacheFiles then
            for _, filePath in ipairs(cacheFiles) do
                pcall(deleteFunc, filePath)
            end
        end
    end
end)

pcall(function() makefolder(CONFIG.FOLDER) end)
pcall(function() makefolder(CONFIG.CACHE_FOLDER) end)

function GetCachePath(animName)
    local safeName = animName:gsub("[^%%w%%-_%%. ]", "_")
    return CONFIG.CACHE_FOLDER .. "/" .. safeName .. ".cache"
end

local RunService   = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local HttpService  = game:GetService("HttpService")

local State = {
    isReanimated   = false,
    currentSpeed   = 1.0,
    stateSpeed     = 1.0,
    selectedAnim   = nil,
    rawAnimPlaying = false,
    currentTab     = "All",
}

local rawAnimCache = _G._HaloRawAnimCache or {}
_G._HaloRawAnimCache = rawAnimCache
_G._ReanimRawAnimCache = rawAnimCache

local serializeAnimData = LPH_NO_VIRTUALIZE(function(data)
    local out = {}
    for animKey, frames in pairs(data) do
        local frameArr = {}
        for i, frame in ipairs(frames) do
            local boneData = {}
            for boneName, cf in pairs(frame.Data) do
                boneData[boneName] = {cf:GetComponents()}
            end
            frameArr[i] = { Time = frame.Time, Data = boneData }
        end
        out[animKey] = frameArr
    end
    return out
end)

local deserializeAnimData = LPH_NO_VIRTUALIZE(function(jsonData)
    local out = {}
    for animKey, frames in pairs(jsonData) do
        local frameArr = {}
        for i, frame in ipairs(frames) do
            local boneData = {}
            for boneName, nums in pairs(frame.Data) do
                boneData[boneName] = CFrame.new(table.unpack(nums))
            end
            frameArr[i] = { Time = frame.Time, Data = boneData }
        end
        out[animKey] = frameArr
    end
    return out
end)
_G._ReanimDeserializeAnimData = deserializeAnimData

local _customAnimsLoaded = false
local presetList = {
    ["Freestylin'"] = "",
    ["Floss"] = "",
    ["Orange Justice"] = "",
    ["Take The L"] = "",
    ["Default Dance"] = "",
    ["Gangnam Style"] = "",
    ["Macarena"] = "",
    ["Thriller"] = "",
    ["Moonwalk"] = "",
    ["Robot"] = "",
    ["Twerk"] = "",
    ["Dab"] = "",
    ["Salute"] = "",
    ["Wave"] = "",
    ["Clap"] = "",
    ["Cheer"] = "",
    ["Laugh"] = "",
    ["Point"] = "",
    ["Shrug"] = "",
    ["Swim"] = "",
    ["Sit"] = "",
    ["Lay Down"] = "",
    ["Sleep"] = "",
    ["Crouch"] = "",
    ["Pray"] = "",
    ["Meditation"] = "",
    ["Electro Shuffle"] = "",
    ["Ride The Pony"] = "",
    ["Hype"] = "",
    ["Tidy"] = "",
    ["Breakin'"] = "",
    ["Disco Fever"] = "",
    ["Zany"] = "",
    ["Groove Jam"] = "",
    ["True Heart"] = "",
    ["Rambunctious"] = "",
    ["Twist"] = "",
    ["Living Large"] = "",
    ["Llama Bell"] = "",
    ["Fancy Feet"] = "",
    ["Hula"] = "",
    ["Electro Swing"] = "",
    ["Phone It In"] = "",
    ["Flamenco"] = "",
    ["Backstroke"] = "",
    ["Marsh Walk"] = "",
    ["Scenario"] = "",
    ["Dream Feet"] = "",
    ["Switchstep"] = "",
    ["Billy Bounce"] = "",
    ["Infectious"] = "",
    ["Deep End"] = "",
    ["Death"] = "",
    ["XO"] = "",
    ["Freewheelin'"] = "",
    ["Hatchback"] = "",
    ["Dreamer"] = "",
    ["Roundabout"] = "",
    ["Han Solo"] = "",
    ["Bumblebee"] = "",
    ["Renegade"] = "",
    ["Elite Agent"] = "",
    ["Whiplash"] = "",
    ["Calamity"] = "",
    ["Inferno"] = "",
    ["Sandstorm"] = "",
    ["Domino"] = "",
    ["Blade"] = "",
    ["Headlock"] = "",
    ["Hopscotch"] = "",
    ["Dawn"] = "",
    ["Hana"] = "",
    ["Accolades"] = "",
    ["Ground Pound"] = "",
    ["you should see me in a crown"] = "",
    ["Cupid's Arrow"] = "",
    ["Make Some Waves"] = "",
    ["Show Ya"] = "",
    ["Bombastic"] = "",
    ["Disco (Surf Curse)"] = "",
    ["Air Shredder"] = "",
    ["Heart-rizon"] = "",
    ["Extraterrestrial"] = "",
    ["Touch"] = "",
    ["Feel the Flow"] = "",
    ["It's a Vibe"] = "",
    ["A Warrior Prepares"] = "",
    ["Showtime"] = "",
    ["Hypnot-Eyes"] = "",
    ["Backstroke"] = "",
    ["Wavy T"] = "",
    ["Outlaw"] = "",
    ["Toosie Slide"] = "",
    ["Rising Phoenix"] = "",
    ["Dance Off"] = "",
    ["Deep Explorer"] = "",
    ["Blinding Lights"] = "",
    ["Bird Call"] = "",
    ["earthquake"] = "",
    ["Flippin' Incredible"] = "",
    ["Daywalker's Kata"] = "",
    ["Stormy"] = "",
    ["Larger Than Life"] = "",
    ["Rolly Rider"] = "",
    ["Balletic"] = "",
    ["Pirouette"] = "",
    ["Nana Nana"] = "",
    ["Business Up Front"] = "",
    ["Tornado Spin"] = "",
    ["Swag Surfin'"] = "",
    ["Baller"] = "",
    ["Ballsy"] = "",
    ["Headstock Spin"] = "",
    ["Side Stride"] = "",
    ["California Love"] = "",
    ["Beckon"] = "",
    ["Get Gone"] = "",
    ["Ska-stra-terrestrial"] = "",
    ["Side Step"] = "",
    ["In Ha Mood"] = "",
    ["Oh Shhh"] = "",
    ["Boop!"] = "",
    ["Point and Strut"] = "",
    ["Symbol of Peace"] = "",
    ["Hang Loose Celebration"] = "",
    ["Shhh."] = "",
    ["100% Pure Love"] = "",
    ["Big Dawgs"] = "",
    ["Smitten"] = "",
    ["Martial Arts Master"] = "",
    ["Crossbounce"] = "",
    ["bb belt"] = "",
    ["Fast Feet"] = "",
    ["Build Up"] = "",
    ["Bhangra Boogie"] = "",
    ["Boneless"] = "",
    ["Boogie Down"] = "",
    ["Bim Bam Boom"] = "",
    ["Boots 'n' Cats"] = "",
    ["Cap Kick"] = "",
    ["Bloomin' Bouquet"] = "",
    ["Breakin'"] = "",
    ["Breakneck"] = "",
    ["Primo Moves"] = "",
    ["Go Ape"] = "",
    ["KEHLANI"] = "",
    ["Swole Cat"] = "",
    ["Squash & Stretch"] = "",
    ["XOXO"] = "",
    ["Run It Down"] = "",
    ["Hoppity"] = "",
    ["Bunny Hop"] = "",
    ["Burpee"] = "",
    ["Gloss"] = "",
    ["Take On Me"] = "",
    ["Boney Bounce"] = "",
    ["Chase Me Down"] = "",
    ["Caffeinated"] = "",
    ["Lights up"] = "",
    ["Dancin' Domino"] = "",
    ["Sugar Rush"] = "",
    ["Shimmy Wiggle"] = "",
    ["Capoeira"] = "",
    ["Cartwheelin'"] = "",
    ["Good Guy"] = "",
    ["Bring it around"] = "",
    ["Assumptions"] = "",
    ["On Your Marks..."] = "",
    ["Cheer Up"] = "",
    ["That's So True"] = "",
    ["Bounce Wit' It"] = "",
    ["Tootsee"] = "",
    ["Chicken"] = "",
    ["Snare Solo"] = "",
    ["Cluck Strut"] = "",
    ["Laser Focused"] = "",
    ["Line Dancin'"] = "",
    ["Mwahaha"] = "",
    ["Go! Go! Go!"] = "",
    ["Shout!"] = "",
    ["Jump Around"] = "",
    ["Rap Monster"] = "",
    ["Scout Regiment Salute"] = "",
    ["Keep Me Satisfied"] = "",
    ["Royals"] = "",
    ["Dream Stance"] = "",
    ["Show 'Em Off"] = "",
    ["Night Out"] = "",
    ["Rushin' Around"] = "",
    ["Confused"] = "",
    ["Conga"] = "",
    ["Stop!"] = "",
    ["I Declare!"] = "",
    ["Overdrive"] = "",
    ["Copines"] = "",
    ["Firework"] = "",
    ["Crowning Achievement"] = "",
    ["Celebrate Me"] = "",
    ["Knee Slapper"] = "",
    ["Warm-Up"] = "",
    ["Crabby"] = "",
    ["Aw Snap!"] = "",
    ["Around the Clock"] = "",
    ["Crackdown"] = "",
    ["Crazy Feet"] = "",
    ["Criss Cross"] = "",
    ["Fly to Tokyo"] = "",
    ["Fast Slow Disco"] = "",
    ["Waterworks"] = "",
    ["Neva Play"] = "",
    ["Swing My Way"] = "",
    ["Rage"] = "",
    ["Head Banger"] = "",
    ["Get Loose"] = "",
    ["Unification"] = "",
    ["Boo'd Up Groove"] = "",
    ["Levitate"] = "",
    ["Expressionism"] = "",
    ["Boy's a Liar"] = "",
    ["Deep Dab"] = "",
    ["Pump up the Jam"] = "",
    ["Reaper's Showtime"] = "",
    ["Heel Click Breakdown"] = "",
    ["Go With the Flow"] = "",
    ["Without You"] = "",
    ["Taste"] = "",
    ["Please Please Please"] = "",
    ["Dimensional"] = "",
    ["Rawr"] = "",
    ["Denied"] = "",
    ["Independence"] = "",
    ["Heartbreak Shuffle"] = "",
    ["Pop Muzik"] = "",
    ["No Tears"] = "",
    ["Harmony"] = "",
    ["Strut"] = "",
    ["Smeeze"] = "",
    ["Chimichanga!"] = "",
    ["Revel"] = "",
    ["Made You Look"] = "",
    ["Stuck"] = "",
    ["Ask Me"] = "",
    ["Pull Up"] = "",
    ["Everybody Loves Me"] = "",
    ["Buckets"] = "",
    ["Squat Kick"] = "",
    ["Standing Bow"] = "",
    ["Look at Me"] = "",
    ["Glyphic"] = "",
    ["Hero's Beacon"] = "",
    ["Signature Shuffle"] = "",
    ["Oki Doki"] = "",
    ["Cairo"] = "",
    ["Secret Identity"] = "",
    ["Committed"] = "",
    ["Charging Up"] = "",
    ["Boosting Ki"] = "",
    ["Take it Slow"] = "",
    ["Vivacious"] = "",
    ["Carefree"] = "",
    ["Challenge"] = "",
    ["Fancy Feet"] = "",
    ["Fanciful"] = "",
    ["Ambitious"] = "",
    ["Bye Bye Bye"] = "",
    ["Roar"] = "",
    ["Savage"] = "",
    ["Shape Up"] = "",
    ["Rocket Spinner"] = "",
    ["Fist Pump"] = "",
    ["Fishy Flourish"] = "",
    ["Liar"] = "",
    ["Flapper"] = "",
    ["Fandangle"] = "",
    ["Arm the Pumpkin!"] = "",
    ["Rootin' Tootin'"] = "",
    ["Sweet Shot"] = "",
    ["Laid Back Shuffle"] = "",
    ["Click Click Flash"] = "",
    ["Dark Side"] = "",
    ["Get Funky"] = "",
    ["Sideways Shift"] = "",
    ["Riches"] = "",
    ["Hands Off!"] = "",
    ["Glowsticks"] = "",
    ["Double Up"] = "",
    ["Side Shuffle"] = "",
    ["Jubi Slide"] = "",
    ["HUMBLE"] = "",
    ["Tagger's Groove"] = "",
    ["15 MINUTES"] = "",
    ["A Bar Song"] = "",
    ["Get Griddy"] = "",
    ["Controller Crew"] = "",
    ["Vibin'"] = "",
    ["Telekinetic Power Breakfast"] = "",
    ["Guitar Walk"] = "",
    ["Classy Strut"] = "",
    ["So Low"] = "",
    ["Windmill Stomp"] = "",
    ["Bold Stance"] = "",
    ["Sackin'"] = "",
    ["Treat Yourself"] = "",
    ["Segway Tour"] = "",
    ["Hand Signals"] = "",
    ["Planetary Vibe"] = "",
    ["Tra La La"] = "",
    ["Hello Friend"] = "",
    ["Feel It"] = "",
    ["Headbanger"] = "",
    ["Bobbin'"] = "",
    ["Real Slim Shady"] = "",
    ["Still Into You"] = "",
    ["Reality's Master"] = "",
    ["High Five"] = "",
    ["Sucker"] = "",
    ["Gamma Overload"] = "",
    ["Witch Way"] = "",
    ["Daydream"] = "",
    ["Breakdown"] = "",
    ["Free Flow"] = "",
    ["Hitchhiker"] = "",
    ["Hang on"] = "",
    ["Square Up"] = "",
    ["Say So"] = "",
    ["GGUM"] = "",
    ["Hula Hoopin'"] = "",
    ["Hooray"] = "",
    ["Tocked Off"] = "",
    ["all red"] = "",
    ["Sweethearts"] = "",
    ["JT Coming"] = "",
    ["Ma-Ya-Hi"] = "",
    ["IDK"] = "",
    ["Slide Stride"] = "",
    ["Houdini"] = "",
    ["Invisible Stairs"] = "",
    ["Lavish"] = "",
    ["Poki"] = "",
    ["Infinite Dab"] = "",
    ["Criminals"] = "",
    ["It's True"] = "",
    ["Intensity"] = "",
    ["AFK"] = "",
    ["Culture Festival Dance"] = "",
    ["Step It Up"] = "",
    ["Miku Live"] = "",
    ["Miku Miku Beam"] = "",
    ["Clean Groove"] = "",
    ["Jabba Switchway"] = "",
    ["Slick"] = "",
    ["Jazz Hands"] = "",
    ["Chainsaw Dance"] = "",
    ["Jiggle Jiggle"] = "",
    ["Start it Up"] = "",
    ["Rim Shot"] = "",
    ["Sunny Stroll"] = "",
    ["Jugglin'"] = "",
    ["Out West"] = "",
    ["Jumping Jacks"] = "",
    ["I Like To Move It"] = "",
    ["The Renegade"] = "",
    ["I'm Diamond"] = "",
    ["It's Dynamite!"] = "",
    ["Lucid Dreams"] = "",
    ["Empty Out Your Pockets"] = "",
    ["CrazyBoy"] = "",
    ["Kiss Kiss"] = "",
    ["Dynamic Shuffle"] = "",
    ["Bouncy"] = "",
    ["Smooth Moves"] = "",
    ["Glitter"] = "",
    ["Respect"] = "",
    ["Shadow Spar"] = "",
    ["Lazer Blast"] = "",
    ["Three Wise Monkeys"] = "",
    ["Sweet Victory"] = "",
    ["Laugh It Up"] = "",
    ["Frolic"] = "",
    ["Lazy Shuffle"] = "",
    ["Snoop's Walk"] = "",
    ["The Dogg"] = "",
    ["Don't Start Now"] = "",
    ["Hunter Protocol"] = "",
    ["Do the 'Split"] = "",
    ["Distraction Dance"] = "",
    ["Blah Blah Blah"] = "",
    ["Dancery"] = "",
    ["Buckle Up"] = "",
    ["The Pollo Dance"] = "",
    ["Living Large"] = "",
    ["Llama Conga"] = "",
    ["Chef's Special"] = "",
    ["Lock It Up"] = "",
    ["Trinity's Kick"] = "",
    ["Neo's Bullet Time"] = "",
    ["Bounce Berry"] = "",
    ["Bean Bag"] = "",
    ["Nuthin But A G Thang"] = "",
    ["PWR Punch"] = "",
    ["Wu-Tang is Forever"] = "",
    ["The Macarena"] = "",
    ["Bratty"] = "",
    ["Verve"] = "",
    ["The Silencer"] = "",
    ["Wind Up"] = "",
    ["Shake It Up"] = "",
    ["Kindness Punk"] = "",
    ["Punched Up"] = "",
    ["Leave The Door Open"] = "",
    ["Walkin' Pretty"] = "",
    ["Mashed Potato"] = "",
    ["Mr. Brightside"] = "",
    ["Advanced Math"] = "",
    ["Snapshot Swagger"] = "",
    ["No Cure"] = "",
    ["Mantra"] = "",
    ["Mine"] = "",
    ["Moongazer"] = "",
    ["Entranced"] = "",
    ["To the Beat"] = "",
    ["Mime Time"] = "",
    ["Mind Blown"] = "",
    ["Illusive"] = "",
    ["Rhythm of Chaos"] = "",
    ["Wanna See Me"] = "",
    ["Bracelets of Hephaestus"] = "",
    ["Freemix"] = "",
    ["Keyed Up"] = "",
    ["Leilt Elomr"] = "",
    ["It's Go Time!"] = "",
    ["Spin Out"] = "",
    ["Bed Chem"] = "",
    ["Never Gonna"] = "",
    ["The Quick Style"] = "",
    ["Empress Fan Dance"] = "",
    ["Chicken Wing It"] = "",
    ["Finger Wag"] = "",
    ["Swag Shuffle"] = "",
    ["U Can't C Me"] = "",
    ["Pay it Off"] = "",
    ["No Sweat"] = "",
    ["On The Hook"] = "",
    ["It's a Go!"] = "",
    ["Lo-fi Headbang"] = "",
    ["Onda Onda"] = "",
    ["XO (Only If You Say Yes)"] = "",
    ["Fist Bump"] = "",
    ["360"] = "",
    ["Neighborly Hang"] = "",
    ["Tippy Tap"] = "",
    ["Rain Check"] = "",
    ["All I Want For Christmas Is You"] = "",
    ["Bear Hug"] = "",
    ["Paws & Claws"] = "",
    ["Waddle Away"] = "",
    ["Spicy Start"] = "",
    ["BIRDS OF A FEATHER"] = "",
    ["Phew!"] = "",
    ["bad guy"] = "",
    ["Follow the Piper"] = "",
    ["Gwen-Step"] = "",
    ["brokenhearted"] = "",
    ["OMG I LOVE IT"] = "",
    ["Hellfire Dance"] = "",
    ["Nitro Fueled"] = "",
    ["Woke Up"] = "",
    ["The Dip"] = "",
    ["Attraction"] = "",
    ["Synth Step"] = "",
    ["Swagger Strut"] = "",
    ["Star Power"] = "",
    ["Pop Lock"] = "",
    ["Sad Claps"] = "",
    ["Tow Truck Surfer"] = "",
    ["Praise The Tomato"] = "",
    ["Feelin' Royal"] = "",
    ["Bust a Move"] = "",
    ["Perfect Score"] = "",
    ["Pumpernickel"] = "",
    ["Pump It Up"] = "",
    ["Pump Me Up"] = "",
    ["Hand-Forged"] = "",
    ["Pure Salt"] = "",
    ["Hit It"] = "",
    ["Cannon Spike"] = "",
    ["Jamboree"] = "",
    ["Rage Quit"] = "",
    ["Roll Call"] = "",
    ["You're a Winner"] = "",
    ["Sweaty"] = "",
    ["Rebellious"] = "",
    ["Sonic Surfer"] = "",
    ["Forget me not"] = "",
    ["Social Climber"] = "",
    ["Interstellar Bass"] = "",
    ["Mask Off"] = "",
    ["Groove Destroyer"] = "",
    ["It's Complicated"] = "",
    ["Zombie Shambles"] = "",
    ["Back On 74"] = "",
    ["Rocket Rodeo"] = "",
    ["Jump Jets"] = "",
    ["Puppet Dance"] = "",
    ["Arachrobatics"] = "",
    ["Valentina's Verve"] = "",
    ["The Rick Dance"] = "",
    ["Get Schwifty"] = "",
    ["Running Man"] = "",
    ["Pick It Up"] = "",
    ["Knife Tricks"] = "",
    ["Sumo Salt Throw"] = "",
    ["Go Mufasa"] = "",
    ["Koi Dance"] = "",
    ["Starting Prance"] = "",
    ["It's ok I'm ok"] = "",
    ["Members Only"] = "",
    ["Work It"] = "",
    ["Moonlit Mystery"] = "",
    ["close to you"] = "",
    ["Hang Loose"] = "",
    ["Shaolin Sit-up"] = "",
    ["Starlit"] = "",
    ["Sway"] = "",
    ["Dragon Stance"] = "",
    ["Ratatata"] = "",
    ["Brite Moves"] = "",
    ["Showstopper"] = "",
    ["Sign Spinner"] = "",
    ["Slalom Style"] = "",
    ["Fright Funk"] = "",
    ["Freedom Wheels"] = "",
    ["Yarn Ball"] = "",
    ["Very Sneaky"] = "",
    ["Flashback Breakdown"] = "",
    ["Soar Above"] = "",
    ["Kick Ups"] = "",
    ["Fancy Footwork"] = "",
    ["Socks"] = "",
    ["The Spark"] = "",
    ["Monkey Mosh"] = "",
    ["Diva Fever"] = "",
    ["Sparkler"] = "",
    ["Potted Groot Dance"] = "",
    ["Spidey Landing"] = "",
    ["GOATed"] = "",
    ["Take a 'bow"] = "",
    ["Popular Vibe"] = "",
    ["Full Tilt"] = "",
    ["Monster Mash"] = "",
    ["Sparrow Run"] = "",
    ["Sprinkler"] = "",
    ["Keep It Mello"] = "",
    ["Gentleman's Dab"] = "",
    ["Statuesque"] = "",
    ["Side Hustle"] = "",
    ["Jet Signals"] = "",
    ["Peace Out"] = "",
    ["Smooth Operator"] = "",
    ["Party Hips"] = "",
    ["Smooth Slide"] = "",
    ["Tempest Flight"] = "",
    ["Looking Good"] = "",
    ["Cardistry"] = "",
    ["Stay Afloat"] = "",
    ["Heart of a King"] = "",
    ["Lunar Party"] = "",
    ["Bizcochito"] = "",
    ["Sand Walk"] = "",
    ["All About That Bass"] = "",
    ["Survivorsault"] = "",
    ["Roller Vibes"] = "",
    ["Jitterbug"] = "",
    ["Swipe It"] = "",
    ["The Airplane"] = "",
    ["Taco Time"] = "",
    ["Touching The Sky"] = "",
    ["Steady"] = "",
    ["Dreamy Keys"] = "",
    ["Lil' Carpet Ride"] = "",
    ["Hootenanny"] = "",
    ["Quick Bite"] = "",
    ["Bet"] = "",
    ["Havana"] = "",
    ["Stargazing"] = "",
    ["Steamed"] = "",
    ["Evasive Maneuvers"] = "",
    ["Dust Your Boots Off"] = "",
    ["The Look"] = "",
    ["The Flow"] = "",
    ["Slap Happy"] = "",
    ["Desirable"] = "",
    ["Tidy"] = "",
    ["Timeless"] = "",
    ["Spring-Loaded"] = "",
    ["Tiniest Violin"] = "",
    ["Boom!"] = "",
    ["Company Jig"] = "",
    ["Dance Monkey"] = "",
    ["Spike It"] = "",
    ["Ninja Style"] = "",
    ["T-Pose"] = "",
    ["The Squabble"] = "",
    ["Stride"] = "",
    ["Triumphant"] = "",
    ["Twist"] = "",
    ["Rollie"] = "",
    ["Last Forever"] = "",
    ["Wake Up"] = "",
    ["My World"] = "",
    ["Dirtbike Challenge"] = "",
    ["Cyberdyne Salute"] = "",
    ["Island Vibes"] = "",
    ["Break Free"] = "",
    ["Evil Plan"] = "",
    ["Punching Practice"] = "",
    ["I'm Out"] = "",
    ["Let's Get It Started"] = "",
    ["Ain't It Fun"] = "",
    ["Gunslinger Smokeshow"] = "",
    ["New Woman"] = "",
    ["In Da Party"] = "",
    ["I'm a Mystery"] = "",
    ["Breezy"] = "",
    ["Image"] = "",
    ["Dance Therapy"] = "",
    ["Shaq Shimmy"] = "",
    ["Dill With It"] = "",
    ["Flux"] = "",
    ["Upside Down & Inside Out"] = "",
    ["Good Game, Well Played"] = "",
    ["Whirlwind"] = "",
    ["Classy"] = "",
    ["Wiggle"] = "",
    ["Windmill Floss"] = "",
    ["A Tear In Space (Airlock)"] = "",
    ["Gnarly"] = "",
    ["Hot Marat"] = "",
    ["Howl"] = "",
    ["Shimmer"] = "",
    ["Dip"] = "",
    ["Snoozefest"] = "",
    ["You're Awesome"] = "",
    ["Surfin' Bird"] = "",
    ["Maximum Bounce"] = "",
    ["Get Out of Your Mind"] = "",
    ["Reanimated"] = "",
    ["Zom-beam"] = "",
    ["Zombified"] = "",
    ["Boogie Bomb"] = "",
    ["Dynamite"] = "",
    ["Runaway"] = "",
    ["Powered Up"] = "",
    ["Stop"] = "",
    ["Giddy Up"] = "",
    ["Disco"] = "",
    ["Get funky"] = "",
    ["Sweet Dreams"] = "",
    ["Stay"] = "",
    ["Run It"] = "",
    ["Victory Lap"] = "",
    ["Double Tap"] = "",
    ["Nope"] = "",
    ["Bubblegum"] = ""
}

local AnimationList      = {}
for name, url in pairs(presetList) do
    AnimationList[name] = url
end
_G._ReanimAnimationList = AnimationList
local Favorites          = {}
local Keybinds           = {}
local SpeedKeybinds      = {}
local ReverseSpeedKeybinds = {}
_G._HaloListeningSpeedIdx  = nil
_G._HaloListeningRevSpeedIdx = nil
local speedKeyWidgets    = {}
local revSpeedKeyWidgets = {}
local linkRevToNormal    = false
local CustomAnims        = {}
_G._ReanimCustomAnims = CustomAnims
local CustomAnimations     = {}
_G._ReanimCustomAnimations = CustomAnimations
local AnimationCache       = {}
local StateAnims         = {}

function request_get(url)
    local req = (type(request) == "function" and request) or (type(http_request) == "function" and http_request) or (type(syn) == "table" and type(syn.request) == "function" and syn.request) or (type(http) == "table" and type(http.request) == "function" and http.request)
    if req then
        local ok, res = pcall(req, {
            Url = url,
            Method = "GET",
            Headers = {
                ["User-Agent"] = "Roblox"
            },
            Timeout = 4
        })
        if ok and res and res.StatusCode == 200 then
            return res.Body
        end
    end
    local ok, res = pcall(function()
        return game:HttpGet(url, true)
    end)
    if ok and res and res ~= "" then
        return res
    end
    return nil
end

local FOLDER = "ReanimData"
pcall(function() makefolder(FOLDER) end)

function fpath(name) return FOLDER .. "/" .. name end

function parseLargeCustomFile(content)
    local anims = {}
    local pos = 1
    local len = #content
    while pos <= len do
        local entryPos = content:find("{%s*name%s*=", pos)
        if not entryPos then break end
        local advanced = false
        repeat
            local _, nameEnd, name = content:find('name%s*=%s*"(.-)"', entryPos)
            if not name then advanced = true; break end
            local _, _, rawStr = content:find('raw%s*=%s*(true)', nameEnd)
            local isRaw = rawStr == "true"
            local urlPos = content:find("url%s*=%s*%[", nameEnd)
            if not urlPos then advanced = true; break end
            local bracketOpen = content:find("%[", urlPos)
            if not bracketOpen then advanced = true; break end
            local eqCount = 0
            local p = bracketOpen + 1
            while content:sub(p, p) == "=" do eqCount = eqCount + 1; p = p + 1 end
            local urlStart = p + 1
            local closePattern = "%]" .. string.rep("=", eqCount) .. "%]"
            local closeS, closeE = content:find(closePattern, urlStart, true)
            if not closeS then advanced = true; break end
            local url = content:sub(urlStart, closeS - 1)
            table.insert(anims, { name = name, url = url, raw = isRaw })
            pos = closeE + 1; advanced = true
        until true
        if not advanced or pos <= entryPos then pos = entryPos + 1 end
    end
    return anims
end

local _SAVE_INLINE_MAX = 4000 -- animations larger than this are stored in their own .dat file (keeps the JSON index tiny so saving never freezes)
local _saveCustomAnimsPending = false
function SaveCustomAnims()
    _G._ReanimSaveCustomAnims = SaveCustomAnims
    if not _customAnimsLoaded then return end
    _G._ReanimCustomAnims = CustomAnims
    -- Debounce: if a save is already queued, don't queue another
    if _saveCustomAnimsPending then return end
    _saveCustomAnimsPending = true
    task.delay(0.5, function()
        _saveCustomAnimsPending = false
        task.spawn(function()
            pcall(function()
                local dataToSave = {}
                local _saveFrameStart = os.clock()
                for i, ca in ipairs(CustomAnims) do
                    local content = ca.url or ""
                    -- Already stored in one of our .dat files? Just reference it.
                    -- Never re-read or re-write it — doing that on every save (and
                    -- delete triggers a save) was the freeze.
                    local isOurFile = type(content) == "string"
                        and not content:match("^https?://")
                        and content:match("%.dat$") ~= nil
                    if isOurFile then
                        table.insert(dataToSave, {
                            name = ca.name, file = content,
                            raw = ca.raw ~= false, isJson = ca.isJson or nil
                        })
                    elseif type(content) == "string" and #content > _SAVE_INLINE_MAX then
                        -- Large inline content: externalize ONCE to a .dat file and
                        -- switch the live entry to the file ref so future saves are
                        -- cheap and never JSON-encode the big string again.
                        local safeFileName = fpath("custom_" .. ca.name:gsub("[^%w_%-]", "_") .. ".dat")
                        pcall(function() writefile(safeFileName, content) end)
                        ca.url = safeFileName
                        CustomAnimations[ca.name] = safeFileName
                        table.insert(dataToSave, {
                            name = ca.name, file = safeFileName,
                            raw = ca.raw ~= false, isJson = ca.isJson or nil
                        })
                    else
                        table.insert(dataToSave, {
                            name = ca.name, url = content,
                            raw = ca.raw ~= false, isJson = ca.isJson or nil
                        })
                    end
                    -- Yield periodically so externalizing many large animations
                    -- (e.g. a big AK import) never blocks a frame.
                    if os.clock() - _saveFrameStart >= 0.004 then
                        task.wait()
                        _saveFrameStart = os.clock()
                    end
                end
                writefile(fpath("ReanimCustomAnims.json"), HttpService:JSONEncode(dataToSave))
            end)
        end)
    end)
end

-- Helper functions for parsing JSON and table animations are defined at the top of the file.

local function autoImportAKFiles()
    if not readfile then return end
    
    -- Check if auto-import has already been done
    local autoImportFlag = fpath("ReanimAutoImportDone.txt")
    local hasAutoImported = false
    pcall(function()
        if isfile and isfile(autoImportFlag) then
            hasAutoImported = true
        elseif not isfile then
            local ok, content = pcall(readfile, autoImportFlag)
            if ok then hasAutoImported = true end
        end
    end)
    
    -- Skip auto-import if already done once
    if hasAutoImported then
        return
    end
    
    pcall(function()
        local pathsToCheck = {
            " custom_animations.json",
            "custom_animations.json",
            "workspace/ custom_animations.json",
            "workspace/custom_animations.json",
            "ak/custom_animations.json",
            "ak/ custom_animations.json",
            "../workspace/ custom_animations.json",
            "../workspace/custom_animations.json"
        }
        local raw = nil
        for _, path in ipairs(pathsToCheck) do
            local ok, content
            if isfile then
                local isF = false
                pcall(function() isF = isfile(path) end)
                if isF then ok, content = pcall(readfile, path) end
            else
                ok, content = pcall(readfile, path)
            end
            if ok and content and content ~= "" then
                raw = content
                break
            end
        end
        
        if raw then
            local cleaned = raw:gsub("^\xEF\xBB\xBF", ""):gsub("\r\n", "\n"):gsub("\r", "\n")
            local ok2, data = pcall(function() return HttpService:JSONDecode(cleaned) end)
            if ok2 and type(data) == "table" then
                local kbData = {}
                local kbPaths = {
                    "animation_keybinds.json",
                    "workspace/animation_keybinds.json",
                    "ak/animation_keybinds.json",
                    "../workspace/animation_keybinds.json"
                }
                for _, path in ipairs(kbPaths) do
                    local ok, content
                    if isfile then
                        local isF = false
                        pcall(function() isF = isfile(path) end)
                        if isF then ok, content = pcall(readfile, path) end
                    else
                        ok, content = pcall(readfile, path)
                    end
                    if ok and content and content ~= "" then
                        local kbCleaned = content:gsub("^\xEF\xBB\xBF", ""):gsub("\r\n", "\n"):gsub("\r", "\n")
                        local ok3, parsedKb = pcall(function() return HttpService:JSONDecode(kbCleaned) end)
                        if ok3 and type(parsedKb) == "table" then
                            kbData = parsedKb
                            break
                        end
                    end
                end

                -- Read existing custom anims from ReanimCustomAnims.json first to know what exists
                local existingAnims = {}
                local okC, rawC = pcall(readfile, fpath("ReanimCustomAnims.json"))
                local currentList = {}
                if okC and type(rawC) == "string" and rawC ~= "" then
                    local okJ, decoded = pcall(function() return HttpService:JSONDecode(rawC) end)
                    if okJ and type(decoded) == "table" then
                        currentList = decoded
                        for _, entry in ipairs(decoded) do
                            existingAnims[entry.name] = true
                        end
                    end
                end

                -- Also load existing keybinds so we don't overwrite user custom Halo binds
                local currentKeybinds = {}
                local okK, rawK = pcall(readfile, fpath("ReanimKeybinds.json"))
                if okK and type(rawK) == "string" and rawK ~= "" then
                    local okJ, decoded = pcall(function() return HttpService:JSONDecode(rawK) end)
                    if okJ and type(decoded) == "table" then
                        currentKeybinds = decoded
                    end
                end

                local didImportNew = false
                for key, val in pairs(data) do
                    local animName, animScript
                    if type(key) == "string" and type(val) == "string" then
                        animName, animScript = key, val
                    elseif type(val) == "table" then
                        animName = val.name or val.Name or val.title or val.Title or val.key or val.Key
                        animScript = val.script or val.Script or val.content or val.Content or val.code or val.Code or val.data or val.Data
                    end

                    if animName and animScript and animName ~= "" and animScript ~= "" then
                        local sanitizedName = animName:gsub("[^%w%s%-_]",""):match("^%s*(.-)%s*$")
                        if sanitizedName ~= "" and not existingAnims[sanitizedName] then
                            -- Auto-import animation
                            pcall(function() ReanimateAPI.seed_animation_cache(sanitizedName, nil) end)
                            table.insert(currentList, { name = sanitizedName, url = animScript, raw = true })
                            CustomAnimations[sanitizedName] = animScript
                            didImportNew = true

                            -- Auto-import keybind
                            local kbKey = kbData[animName] or kbData[sanitizedName]
                            if type(kbKey) == "string" then
                                local keyName = kbKey
                                if #keyName == 1 then keyName = keyName:upper() end
                                local kc = Enum.KeyCode[keyName]
                                if kc then
                                    local keybindName = "[Custom] " .. sanitizedName
                                    currentKeybinds[keybindName] = kc.Name
                                    Keybinds[keybindName] = { key = kc, btn = nil }
                                end
                            end
                        end
                    end
                end

                if didImportNew then
                    -- Save synced files to disk immediately
                    pcall(function() writefile(fpath("ReanimCustomAnims.json"), HttpService:JSONEncode(currentList)) end)
                    pcall(function() writefile(fpath("ReanimKeybinds.json"), HttpService:JSONEncode(currentKeybinds)) end)
                    -- Mark that auto-import has been completed
                    pcall(function() writefile(fpath("ReanimAutoImportDone.txt"), "1") end)
                end
            end
        end
    end)
end

function LoadCustomAnims()
    _customAnimsLoaded = true
    -- Auto-import of AK files disabled: animations the user deletes/unbinds
    -- were reappearing on every execute because the source files kept coming back.
    -- Use the "Import" button in Reanimation > Settings to import on demand.
    local anims = {}

    -- 1. Load unified JSON file ReanimCustomAnims.json first
    local okC, rawC = pcall(readfile, fpath("ReanimCustomAnims.json"))
    if okC and type(rawC) == "string" and rawC ~= "" then
        local okJ, decoded = pcall(function() return HttpService:JSONDecode(rawC) end)
        if okJ and type(decoded) == "table" then
            for _, entry in ipairs(decoded) do
                local entryUrl = entry.url
                -- File-based storage for larger animations: keep the file PATH
                -- rather than reading the (possibly large) content into memory.
                -- PlayAnimation reads + parses it on first play, and SaveCustomAnims
                -- just references the path — so loading and saving never freeze.
                if not entryUrl and entry.file then
                    local exists = false
                    pcall(function() exists = isfile and isfile(entry.file) end)
                    if exists then
                        entryUrl = entry.file
                    else
                        -- Fallback: file missing, try reading whatever is there
                        local okF, fileContent = pcall(readfile, entry.file)
                        if okF and type(fileContent) == "string" and fileContent ~= "" then
                            entryUrl = fileContent
                        end
                    end
                end
                local animEntry = { name = entry.name, url = entryUrl or "", raw = entry.raw ~= false, isJson = entry.isJson }
                -- LAZY: store the serialized animData on the entry instead of
                -- deserializing it now. Deserialization happens on first play
                -- (see prefetchCustomAnim) so opening the window never freezes.
                if entry.format == 2 and entry.animData then
                    animEntry.format = 2
                    animEntry.animData = entry.animData
                end
                table.insert(anims, animEntry)
            end
        end
    else
        -- Fallback & Migration: check index.json if unified file doesn't exist
        local okI, rawI = pcall(readfile, fpath("index.json"))
        if okI and type(rawI) == "string" and rawI ~= "" then
            local okJ, index = pcall(function() return HttpService:JSONDecode(rawI) end)
            if okJ and type(index) == "table" and #index > 0 then
                print("[Reanim] Migrating custom animations from index.json to ReanimCustomAnims.json...")
                for _, entry in ipairs(index) do
                    if entry.file then
                        local okF, src = pcall(readfile, fpath(entry.file))
                        if okF and type(src) == "string" and src ~= "" then
                            local animEntry = { name = entry.name, url = entry.url or src, raw = entry.raw ~= false }
                            table.insert(anims, animEntry)
                            if entry.format == 2 then
                                local okDec, fileData = pcall(function() return HttpService:JSONDecode(src) end)
                                if okDec and type(fileData) == "table" and fileData.animData then
                                    local okD, deserialized = pcall(deserializeAnimData, fileData.animData)
                                    if okD then
                                        rawAnimCache[animEntry.url] = { src = animEntry.url, data = deserialized }
                                    end
                                end
                            end
                        end
                    end
                end
                -- Save unified immediately to complete migration
                task.spawn(function()
                    _customAnimsLoaded = true
                    CustomAnims = anims
                    SaveCustomAnims()
                    -- Clean up old files
                    local deleteFunc = delfile or delete_file or (function(path) pcall(writefile, path, "") end)
                    for _, entry in ipairs(index) do
                        if entry.file then pcall(deleteFunc, fpath(entry.file)) end
                    end
                    pcall(deleteFunc, fpath("index.json"))
                end)
            end
        end
    end

    -- 2. Scan folder for manually placed files (skip files already loaded from ReanimCustomAnims.json)
    local listFilesFunc = listfiles or list_files
    local ok, files = pcall(function()
        if listFilesFunc then
            return listFilesFunc(FOLDER)
        end
        return {}
    end)
    if ok and type(files) == "table" then
        local ignored = {
            reanimfavorites = true,
            reanimkeybinds = true,
            reanimspeedkeys = true,
            reanimstates = true,
            onlineanimationscache = true,
            index = true,
            reanimreversekey = true,
            reanimreversespeed = true,
            reanimrevspeedkeys = true,
            reanimfortnitewheelkey = true,
            reanimmobilewheelbtn = true,
            reanimcustomanims = true
        }
        for _, f in ipairs(files) do
            local isLua  = f:match("%.lua$")
            local isJson = f:match("%.json$") or f:match("%.txt$")
            if (isLua or isJson) and not f:match("[Ss]ettings") and not f:match("[Cc]onfig") then
                local n = f:match("([^/\\]+)%.[%w]+$")
                if n then
                    local lowerName = n:lower()
                    if not lowerName:match("^anim_%d+$") and not ignored[lowerName] then
                        -- Check for duplicate already loaded from ReanimCustomAnims.json
                        local alreadyLoaded = false
                        for _, existing in ipairs(anims) do
                            if existing.name == n then
                                alreadyLoaded = true
                                break
                            end
                        end
                        if not alreadyLoaded then
                            table.insert(anims, { name = n, url = f, raw = true })
                        end
                    end
                end
            end
        end
    end

    if #anims == 0 then
        local okR, raw = pcall(readfile, "ReanimCustom.lua")
        if okR and type(raw) == "string" and #raw > 20 and raw ~= "return {}" then
            print("[Reanim] Migrating from ReanimCustom.lua...")
            local data = parseLargeCustomFile(raw)
            if #data > 0 then
                anims = data
                task.spawn(function()
                    _customAnimsLoaded = true
                    CustomAnims = anims
                    SaveCustomAnims()
                    pcall(function() writefile("ReanimCustom.lua", "return {}") end)
                end)
            end
        end
    end

    if #anims > 0 then
        print("[Reanim] Loaded " .. #anims .. " animations.")
        return anims
    end
    if type(_G._ReanimCustomAnims) == "table" then
        return _G._ReanimCustomAnims
    end
    return {}
end

function LoadData()
    local function safeRead(fname, default)
        local ok, v = pcall(function()
            local okR, raw = pcall(readfile, fpath(fname))
            if not okR or type(raw) ~= "string" or raw == "" then
                okR, raw = pcall(readfile, fname)
            end
            if not okR or type(raw) ~= "string" or raw == "" then return default end
            return HttpService:JSONDecode(raw)
        end)
        return (ok and type(v) == "table") and v or default
    end
    local rawFavs = safeRead("ReanimFavorites.json", {})
    Favorites = {}
    for name, _ in pairs(rawFavs) do
        Favorites[name] = true
    end
    
    CustomAnims = LoadCustomAnims()
    _G._ReanimCustomAnims = CustomAnims
    for _, ca in ipairs(CustomAnims) do
        CustomAnimations[ca.name] = ca.url
    end
    
    -- Update Custom tab count after loading animations
    task.defer(function()
        if UpdateCustomTabCount then
            UpdateCustomTabCount()
        end
    end)
    StateAnims  = safeRead("ReanimStates.json", {})
    for k, v in pairs(StateAnims) do
        if type(v) == "string" then StateAnims[k] = { url = v, raw = false } end
    end
    local rawBinds = safeRead("ReanimKeybinds.json", {})
    Keybinds = {}
    for name, keyData in pairs(rawBinds) do
        local keyName
        if type(keyData) == "table" and keyData.key then
            keyName = keyData.key
        elseif type(keyData) == "string" then
            keyName = keyData
        end
        if keyName then
            local ok, kc = pcall(function() return Enum.KeyCode[keyName] end)
            if ok and kc then Keybinds[name] = { key = kc, btn = nil } end
        end
    end
    -- Try to load from old reanimation location if no keybinds found
    if next(Keybinds) == nil then
        local okOld, oldBinds = pcall(readfile, "keybinds.json")
        if okOld and type(oldBinds) == "string" and oldBinds ~= "" then
            local okDecode, decoded = pcall(function() return HttpService:JSONDecode(oldBinds) end)
            if okDecode and type(decoded) == "table" then
                for name, keyName in pairs(decoded) do
                    local ok, kc = pcall(function() return Enum.KeyCode[keyName] end)
                    if ok and kc then Keybinds[name] = { key = kc, btn = nil } end
                end
            end
        end
    end
    pcall(function()
        local ok, keyName = pcall(readfile, fpath("ReanimReverseKey.txt"))
        if not ok or not keyName or keyName == "" then
            ok, keyName = pcall(readfile, "ReanimReverseKey.txt")
        end
        if ok and keyName and keyName ~= "" then
            -- Some executors append a trailing newline / whitespace when
            -- writing a text file. Trim it before looking up the KeyCode,
            -- otherwise Enum.KeyCode["F\n"] returns nil and the rewind key
            -- silently stops working.
            keyName = keyName:match("^%s*(.-)%s*$")
            if keyName and keyName ~= "" then
                local ok4, kc = pcall(function() return Enum.KeyCode[keyName] end)
                if ok4 and kc then GlobalReverseKeybind = kc end
            end
        end
        local ok2, speedVal = pcall(readfile, fpath("ReanimReverseSpeed.txt"))
        if not ok2 or not speedVal or speedVal == "" then
            ok2, speedVal = pcall(readfile, "ReanimReverseSpeed.txt")
        end
        if ok2 and speedVal and speedVal ~= "" then
            GlobalReverseSpeed = tonumber((speedVal:match("^%s*(.-)%s*$"))) or GlobalReverseSpeed or 1.0
        end
        local ok5, irKeyName = pcall(readfile, fpath("ReanimInstantResetKey.txt"))
        if not ok5 or not irKeyName or irKeyName == "" then
            ok5, irKeyName = pcall(readfile, "ReanimInstantResetKey.txt")
        end
        if ok5 and irKeyName and irKeyName ~= "" then
            irKeyName = irKeyName:match("^%s*(.-)%s*$")
            if irKeyName and irKeyName ~= "" then
                local ok6, kc = pcall(function() return Enum.KeyCode[irKeyName] end)
                if ok6 and kc then _G._HaloInstantResetKey = kc end
            end
        end

        -- Left Arm Pointer Key
        local okLa, laKeyName = pcall(readfile, fpath("ReanimLeftArmKey.txt"))
        if not okLa or not laKeyName or laKeyName == "" then
            okLa, laKeyName = pcall(readfile, "ReanimLeftArmKey.txt")
        end
        if okLa and laKeyName and laKeyName ~= "" then
            laKeyName = laKeyName:match("^%s*(.-)%s*$")
            if laKeyName and laKeyName ~= "" then
                local okLa2, kc = pcall(function() return Enum.KeyCode[laKeyName] end)
                if okLa2 and kc then _G._HaloLeftArmKey = kc end
            end
        end

        -- Right Arm Pointer Key
        local okRa, raKeyName = pcall(readfile, fpath("ReanimRightArmKey.txt"))
        if not okRa or not raKeyName or raKeyName == "" then
            okRa, raKeyName = pcall(readfile, "ReanimRightArmKey.txt")
        end
        if okRa and raKeyName and raKeyName ~= "" then
            raKeyName = raKeyName:match("^%s*(.-)%s*$")
            if raKeyName and raKeyName ~= "" then
                local okRa2, kc = pcall(function() return Enum.KeyCode[raKeyName] end)
                if okRa2 and kc then _G._HaloRightArmKey = kc end
            end
        end

        -- Player Tracker Key
        local okTr, trKeyName = pcall(readfile, fpath("ReanimTrackerKey.txt"))
        if not okTr or not trKeyName or trKeyName == "" then
            okTr, trKeyName = pcall(readfile, "ReanimTrackerKey.txt")
        end
        if okTr and trKeyName and trKeyName ~= "" then
            trKeyName = trKeyName:match("^%s*(.-)%s*$")
            if trKeyName and trKeyName ~= "" then
                local okTr2, kc = pcall(function() return Enum.KeyCode[trKeyName] end)
                if okTr2 and kc then _G._HaloTrackerKey = kc end
            end
        end

        -- Head Tracker Key
        local okHt, htKeyName = pcall(readfile, fpath("ReanimHeadTrackerKey.txt"))
        if not okHt or not htKeyName or htKeyName == "" then
            okHt, htKeyName = pcall(readfile, "ReanimHeadTrackerKey.txt")
        end
        if okHt and htKeyName and htKeyName ~= "" then
            htKeyName = htKeyName:match("^%s*(.-)%s*$")
            if htKeyName and htKeyName ~= "" then
                local okHt2, kc = pcall(function() return Enum.KeyCode[htKeyName] end)
                if okHt2 and kc then _G._HaloHeadTrackerKey = kc end
            end
        end

        local ok3, rawWheel = pcall(readfile, fpath("ReanimFortniteWheelKey.json"))
        if not ok3 or not rawWheel or rawWheel == "" then
            ok3, rawWheel = pcall(readfile, "ReanimFortniteWheelKey.json")
        end
        if ok3 and rawWheel and rawWheel ~= "" then
            local data = HttpService:JSONDecode(rawWheel)
            if data and data.key then
                _G._FortniteWheelKey = Enum.KeyCode[data.key]
            end
        end
    end)
    local rawSK = safeRead("ReanimSpeedKeys.json", {})
    for i = 1, 6 do
        local s = rawSK[i] or {}
        local kc = nil
        if s.key then pcall(function() kc = Enum.KeyCode[s.key] end) end
        SpeedKeybinds[i] = { speed = tonumber(s.speed) or (i * 0.5), key = kc, btn = nil }
    end
    local rawRSK = safeRead("ReanimRevSpeedKeys.json", {})
    for i = 1, 6 do
        local s = rawRSK[i] or {}
        local kc = nil
        if s.key then pcall(function() kc = Enum.KeyCode[s.key] end) end
        ReverseSpeedKeybinds[i] = { speed = tonumber(s.speed) or (i * 0.5), key = kc, btn = nil }
    end
    if rawRSK.linkToNormal ~= nil then linkRevToNormal = rawRSK.linkToNormal == true end
end

function _rawSaveFavorites()
    local toSave = {}
    for name, _ in pairs(Favorites) do toSave[name] = true end
    pcall(function() writefile(fpath("ReanimFavorites.json"), HttpService:JSONEncode(toSave)) end)
end

local _saveFavPending = false
function SaveFavoritesOnly()
    if _saveFavPending then return end
    _saveFavPending = true
    task.delay(0.3, function()
        _saveFavPending = false
        _rawSaveFavorites()
    end)
end

function _rawSaveKeybinds()
    local toSave = {}
    for name, data in pairs(Keybinds) do
        if data.key then toSave[name] = data.key.Name end
    end
    pcall(function() writefile(fpath("ReanimKeybinds.json"), HttpService:JSONEncode(toSave)) end)
end

local _saveKbPending = false
function SaveKeybindsOnly()
    if _saveKbPending then return end
    _saveKbPending = true
    task.delay(0.3, function()
        _saveKbPending = false
        _rawSaveKeybinds()
    end)
end

local _saveDataPending = false
function SaveData()
    _rawSaveFavorites()
    _rawSaveKeybinds()
    -- Run all blocking writefile calls off the main thread
    task.spawn(function()
        pcall(function() writefile(fpath("ReanimStates.json"), HttpService:JSONEncode(StateAnims)) end)
        local skSave = {}
        for i = 1, 6 do
            local s = SpeedKeybinds[i] or {}
            skSave[i] = { speed = s.speed, key = s.key and s.key.Name or nil }
        end
        pcall(function() writefile(fpath("ReanimSpeedKeys.json"), HttpService:JSONEncode(skSave)) end)
        local rskSave = { linkToNormal = linkRevToNormal }
        for i = 1, 6 do
            local s = ReverseSpeedKeybinds[i] or {}
            rskSave[i] = { speed = s.speed, key = s.key and s.key.Name or nil }
        end
        pcall(function() writefile(fpath("ReanimRevSpeedKeys.json"), HttpService:JSONEncode(rskSave)) end)
        pcall(function()
            if GlobalReverseKeybind then
                writefile(fpath("ReanimReverseKey.txt"), GlobalReverseKeybind.Name)
            else
                local deleteFunc = delfile or delete_file or (function(p) pcall(writefile, p, "") end)
                pcall(deleteFunc, fpath("ReanimReverseKey.txt"))
            end
            writefile(fpath("ReanimReverseSpeed.txt"), tostring(GlobalReverseSpeed))
            if _G._FortniteWheelKey then
                writefile(fpath("ReanimFortniteWheelKey.json"), HttpService:JSONEncode({key = _G._FortniteWheelKey.Name}))
            end
            if _G._HaloInstantResetKey then
                writefile(fpath("ReanimInstantResetKey.txt"), _G._HaloInstantResetKey.Name)
            else
                local deleteFunc = delfile or delete_file or (function(p) pcall(writefile, p, "") end)
                pcall(deleteFunc, fpath("ReanimInstantResetKey.txt"))
            end
            if _G._HaloLeftArmKey then
                writefile(fpath("ReanimLeftArmKey.txt"), _G._HaloLeftArmKey.Name)
            else
                local deleteFunc = delfile or delete_file or (function(p) pcall(writefile, p, "") end)
                pcall(deleteFunc, fpath("ReanimLeftArmKey.txt"))
            end
            if _G._HaloRightArmKey then
                writefile(fpath("ReanimRightArmKey.txt"), _G._HaloRightArmKey.Name)
            else
                local deleteFunc = delfile or delete_file or (function(p) pcall(writefile, p, "") end)
                pcall(deleteFunc, fpath("ReanimRightArmKey.txt"))
            end
            if _G._HaloTrackerKey then
                writefile(fpath("ReanimTrackerKey.txt"), _G._HaloTrackerKey.Name)
            else
                local deleteFunc = delfile or delete_file or (function(p) pcall(writefile, p, "") end)
                pcall(deleteFunc, fpath("ReanimTrackerKey.txt"))
            end

            if _G._HaloHeadTrackerKey then
                writefile(fpath("ReanimHeadTrackerKey.txt"), _G._HaloHeadTrackerKey.Name)
            else
                local deleteFunc = delfile or delete_file or (function(p) pcall(writefile, p, "") end)
                pcall(deleteFunc, fpath("ReanimHeadTrackerKey.txt"))
            end
        end)
    end)
end

LoadData()

-- Load VC Bypass saved state (DISABLED auto-start — user must enable in Settings)
-- pcall(function()
--     local raw = readfile(fpath("ReanimVCBypass.json"))
--     if raw then
--         local data = HttpService:JSONDecode(raw)
--         if data and data.enabled then
--             -- applyVCBypass() -- opt-in only
--         end
--     end
-- end)
_customAnimsLoaded = true

function prefetchCustomAnim(ca)
    if not ca then return end
    local src = ca.url
    if not src or src == "" then return end
    if rawAnimCache[src] then return end

    -- Format-2 entries carry pre-serialized animData; deserialize lazily here
    -- (this was previously done eagerly in LoadCustomAnims and froze the game on open)
    if ca.format == 2 and ca.animData then
        task.spawn(function()
            local okD, deserialized = pcall(deserializeAnimData, ca.animData)
            if okD and type(deserialized) == "table" then
                rawAnimCache[src] = { src = src, data = deserialized }
                ca.format = nil
                ca.animData = nil
            end
        end)
        return
    end

    if not ca.raw then return end
    task.spawn(function()
        local cleaned = src:gsub("^\xEF\xBB\xBF", ""):gsub("\r\n", "\n"):gsub("\r", "\n")
        local firstChar = cleaned:match("^%s*(.)")
        -- Try JSON parsing first
        if firstChar == "{" or firstChar == "[" then
            local parsed = parseJsonAnimation(cleaned)
            if parsed then
                rawAnimCache[src] = { src = src, data = parsed, isJson = true }
                return
            end
        end
        local fn = loadstring(cleaned)
        if not fn then return end
        local ok, data = pcall(fn)
        if not ok or type(data) ~= "table" then return end
        rawAnimCache[src] = { src = src, data = data }
        ca.format = nil
    end)
end

function prefetchAllCustomAnims()
    task.spawn(function()
        for _, ca in ipairs(CustomAnims) do
            prefetchCustomAnim(ca)
            task.wait()
        end
    end)
end

-- Disabled automatic prefetching to reduce lag on startup
-- task.delay(0.5, prefetchAllCustomAnims)

local stopStateSystem
local startStateSystem
local prefetchStateAnim
local prefetchAllStates
local stateSystemActive = false
_G._HaloListeningKeyBtn = nil
_G._HaloListenTarget    = nil
local isDraggingSpeed   = false
function new(cls, parent, props)
    local obj = Instance.new(cls)
    if parent then obj.Parent = parent end
    if props then
        for k, v in pairs(props) do
            pcall(function() obj[k] = v end)
        end
    end
    return obj
end

function corner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = parent
    return c
end

function stroke(parent, col, thick, trans)
    local ok, s = pcall(function() return Instance.new("UIStroke") end)
    if not ok then return nil end
    s.Color = col or Color3.fromRGB(60, 50, 90)
    s.Thickness = thick or 1
    s.Transparency = trans or 0
    s.Parent = parent
    return s
end

function tw(obj, t, props, style, dir)
    local filteredProps = {}
    for k, v in pairs(props) do
        local ok = pcall(function() return obj[k] end)
        if ok then
            filteredProps[k] = v
        end
    end
    return game:GetService("TweenService"):Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), filteredProps)
end

local C = {
    bg0         = Color3.fromRGB(12, 12, 12),     -- Main frame background (near black)
    bg1         = Color3.fromRGB(20, 20, 20),      -- Header and cards background
    bg2         = Color3.fromRGB(30, 30, 30),       -- Playable lists / list elements
    bg3         = Color3.fromRGB(45, 45, 45),       -- Speed inputs / sliders background
    border      = Color3.fromRGB(60, 60, 60),       -- Inner frame outlines (gray)
    glassBorder = Color3.fromRGB(120, 120, 120),    -- Outer glow/border (light gray)
    text        = Color3.fromRGB(255, 255, 255),    -- White body text
    text2       = Color3.fromRGB(200, 200, 200),    -- Light gray-white text
    text3       = Color3.fromRGB(130, 130, 130),    -- Dim gray text
    accent      = Color3.fromRGB(255, 255, 255),    -- Main accent (white)
    bg4         = Color3.fromRGB(25, 25, 25),       -- Toggle backgrounds
    red         = Color3.fromRGB(255, 70, 70),      -- Close dot
    yellow      = Color3.fromRGB(255, 190, 40),     -- Minimize dot
    green       = Color3.fromRGB(40, 220, 120),     -- Success / Active
    white       = Color3.fromRGB(255, 255, 255),    -- Pure white
}

local ScreenGui, Menu, body, NowPlayingLabel, StopBtn, TabButtons, SearchBox, hintLbl, AnimListFrame, StatesPanel, CustomPanel, customSearchBox, customOpenModalBtn, customListFrame, SettingsPanel, SpeedPanel, SetTabActive, updateFnWheelBtnText, updateRevBtnText, revFill, revHandle, revSpdLbl, Notify, _screenGuiTarget
do
ScreenGui = Instance.new("ScreenGui")

ScreenGui.Name           = "ReanimHaloMenu"
ScreenGui.ResetOnSpawn   = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true

_screenGuiTarget = nil
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local PlayerGui = localPlayer:FindFirstChildOfClass("PlayerGui") or localPlayer:WaitForChild("PlayerGui")
do
    -- Use PlayerGui instead of CoreGui — CoreGui ScreenGuis intercept all input
    -- before the game world even when no Active=true is set on child frames.
    _screenGuiTarget = PlayerGui
end

Notify = function(msg, dur, extra)
    _G._ReanimNotify = Notify
    local realMsg = msg
    local realDur = dur
    if type(dur) == "string" then
        realMsg = msg .. ": " .. dur
        realDur = extra
    end
    realDur = tonumber(realDur) or 2.5

    local n = Instance.new("Frame")
    n.Parent = ScreenGui
    n.Size   = UDim2.new(0, 340, 0, 48)
    n.Position = UDim2.new(1, 20, 0, 20)
    n.BackgroundColor3 = C.bg1
    n.BackgroundTransparency = 0.05
    n.BorderSizePixel = 0
    n.ZIndex = 1000
    do
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 12); c.Parent = n
        local s = Instance.new("UIStroke"); s.Color = C.accent
        s.Transparency = 0.3; s.Thickness = 1.5; s.Parent = n
        -- Gold accent bar on left
        local bar = Instance.new("Frame"); bar.Parent = n
        bar.BackgroundColor3 = C.accent; bar.BackgroundTransparency = 0
        bar.BorderSizePixel = 0; bar.Size = UDim2.new(0,3,0.6,0)
        bar.Position = UDim2.new(0,0,0.5,0); bar.AnchorPoint = Vector2.new(0,0.5)
        bar.ZIndex = 1001
        Instance.new("UICorner", bar).CornerRadius = UDim.new(0,2)
    end
    local t = Instance.new("TextLabel"); t.Parent = n
    t.BackgroundTransparency = 1; t.Position = UDim2.new(0,14,0,0)
    t.Size = UDim2.new(1,-20,1,0); t.Font = Enum.Font.GothamSemibold
    t.Text = realMsg; t.TextColor3 = C.text
    t.TextSize = 12; t.TextWrapped = true; t.ZIndex = 1001
    do
        local p = Instance.new("UIPadding"); p.PaddingLeft = UDim.new(0,8)
        p.PaddingRight = UDim.new(0,12); p.PaddingTop = UDim.new(0,8)
        p.PaddingBottom = UDim.new(0,8); p.Parent = t
    end
    -- Slide in from right
    TweenService:Create(n, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
        {Position = UDim2.new(1,-360,0,20)}):Play()
    task.delay(realDur, function()
        TweenService:Create(n, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {Position = UDim2.new(1,20,0,20)}):Play()
        game:GetService("Debris"):AddItem(n, 0.4)
    end)
end

Menu = Instance.new("Frame")
Menu.Name               = "ReanimMenu"
Menu.Parent             = ScreenGui
Menu.BackgroundColor3   = C.bg0
Menu.BackgroundTransparency = 0.35
Menu.BorderSizePixel    = 0
Menu.AnchorPoint        = Vector2.new(0.5, 0.5)
Menu.Position           = UDim2.new(0.5, 0, 0.5, 0)
Menu.Size               = UDim2.new(0, 0, 0, 0) -- Start invisible for entrance anim
Menu.Visible            = true
Menu.Active             = false
Menu.ZIndex             = 30
Menu.ClipsDescendants   = true
-- Blur backdrop
local blur = Instance.new("BlurEffect")
blur.Size = 24
blur.Parent = Menu
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 16); c.Parent = Menu
    local s = Instance.new("UIStroke"); s.Color = C.glassBorder
    s.Transparency = 0.25; s.Thickness = 1.5; s.Parent = Menu
    -- Drop shadow
    local shadow = Instance.new("ImageLabel"); shadow.Name = "Shadow"
    shadow.Parent = Menu; shadow.BackgroundTransparency = 1
    shadow.Image = "rbxassetid://131604521937076"
    shadow.ImageColor3 = Color3.fromRGB(0,0,0)
    shadow.ImageTransparency = 0.35
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(50,50,50,50)
    shadow.Size = UDim2.new(1,60,1,60)
    shadow.Position = UDim2.new(0.5,0,0.5,0)
    shadow.AnchorPoint = Vector2.new(0.5,0.5)
    shadow.ZIndex = 29
end

-- Resize Handle (curved grip bottom-right)
local ResizeGrip = Instance.new("Frame")
ResizeGrip.Name = "ResizeGrip"
ResizeGrip.Parent = Menu
ResizeGrip.BackgroundColor3 = C.glassBorder
ResizeGrip.BackgroundTransparency = 0.6
ResizeGrip.BorderSizePixel = 0
ResizeGrip.Size = UDim2.new(0, 18, 0, 18)
ResizeGrip.Position = UDim2.new(1, -18, 1, -18)
ResizeGrip.ZIndex = 35
ResizeGrip.Active = true
local gripCorner = Instance.new("UICorner", ResizeGrip)
gripCorner.CornerRadius = UDim.new(0, 6)
local gripStroke = Instance.new("UIStroke", ResizeGrip)
gripStroke.Color = C.glassBorder
gripStroke.Thickness = 1.5
gripStroke.Transparency = 0.3

-- Curved diagonal lines on grip for visual flair
for i = 0, 2 do
    local line = Instance.new("Frame", ResizeGrip)
    line.BackgroundColor3 = C.text
    line.BackgroundTransparency = 0.4
    line.BorderSizePixel = 0
    line.Size = UDim2.new(0, 8, 0, 1.5)
    line.Position = UDim2.new(0, 3 + i*2.5, 0, 12 - i*2.5)
    line.Rotation = -45
    line.ZIndex = 36
end

-- Resize logic
local resizing = false
local resizeStartPos
local resizeStartSize

ResizeGrip.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        resizing = true
        resizeStartPos = input.Position
        resizeStartSize = Menu.AbsoluteSize
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                resizing = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement) then
        local delta = input.Position - resizeStartPos
        local newW = math.clamp(resizeStartSize.X + delta.X, CONFIG.UI.MIN_WIDTH, 700)
        local newH = math.clamp(resizeStartSize.Y + delta.Y, CONFIG.UI.MIN_HEIGHT, 800)
        Menu.Size = UDim2.new(0, newW, 0, newH)
        FULL_SIZE = UDim2.new(0, newW, 0, newH)
        if not isMinimized then
            MINI_SIZE = UDim2.new(0, newW, 0, 40)
        end
    end
end)

ResizeGrip.MouseEnter:Connect(function()
    TweenService:Create(ResizeGrip, TweenInfo.new(0.15), {BackgroundTransparency = 0.3}):Play()
end)
ResizeGrip.MouseLeave:Connect(function()
    TweenService:Create(ResizeGrip, TweenInfo.new(0.15), {BackgroundTransparency = 0.6}):Play()
end)


-- Entrance animation
Menu.Size = UDim2.new(0, CONFIG.UI.DEFAULT_WIDTH, 0, CONFIG.UI.DEFAULT_HEIGHT)
Menu.BackgroundTransparency = 1
pcall(function()
    TweenService:Create(Menu, TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
        BackgroundTransparency = 0.35
    }):Play()
end)

local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"; TitleBar.Parent = Menu
TitleBar.BackgroundColor3 = C.bg1
TitleBar.BackgroundTransparency = 0.15; TitleBar.BorderSizePixel = 0
TitleBar.Size = UDim2.new(1,0,0,44); TitleBar.ZIndex = 31; TitleBar.Active = false
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,16); c.Parent = TitleBar
    local t = Instance.new("TextLabel"); t.Parent = TitleBar
    t.BackgroundTransparency = 1; t.Position = UDim2.new(0,16,0,0)
    t.Size = UDim2.new(1,-80,1,0); t.Font = Enum.Font.GothamBold
    t.Text = "Reanimation"; t.TextColor3 = C.accent
    t.TextSize = 16; t.TextXAlignment = Enum.TextXAlignment.Left; t.ZIndex = 32
    -- Gold accent line under title
    local div = Instance.new("Frame"); div.Parent = TitleBar
    div.BackgroundColor3 = C.glassBorder; div.BackgroundTransparency = 0.3
    div.BorderSizePixel = 0; div.Position = UDim2.new(0,16,1,-2)
    div.Size = UDim2.new(0,80,0,2); div.ZIndex = 33
end

local minimizeBtn = Instance.new("TextButton"); minimizeBtn.Parent = TitleBar
minimizeBtn.Name = "MinimizeBtn"
minimizeBtn.BackgroundColor3 = C.yellow; minimizeBtn.BackgroundTransparency = 0
minimizeBtn.BorderSizePixel = 0; minimizeBtn.AnchorPoint = Vector2.new(1,0.5)
minimizeBtn.Position = UDim2.new(1,-32,0.5,0); minimizeBtn.Size = UDim2.new(0,14,0,14)
minimizeBtn.Font = Enum.Font.GothamBold; minimizeBtn.Text = ""
minimizeBtn.TextColor3 = Color3.fromRGB(255,255,255); minimizeBtn.TextSize = 18
minimizeBtn.ZIndex = 32; minimizeBtn.AutoButtonColor = false
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1,0); c.Parent = minimizeBtn end

local closeBtn = Instance.new("TextButton"); closeBtn.Parent = TitleBar
closeBtn.Name = "CloseBtn"
closeBtn.BackgroundColor3 = C.red; closeBtn.BackgroundTransparency = 0
closeBtn.BorderSizePixel = 0; closeBtn.AnchorPoint = Vector2.new(1,0.5)
closeBtn.Position = UDim2.new(1,-10,0.5,0); closeBtn.Size = UDim2.new(0,14,0,14)
closeBtn.Font = Enum.Font.GothamBold; closeBtn.Text = ""
closeBtn.TextColor3 = Color3.fromRGB(255,255,255); closeBtn.TextSize = 18
closeBtn.ZIndex = 32; closeBtn.AutoButtonColor = false
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1,0); c.Parent = closeBtn end

-- Reanimate toggle lives in the title bar so it's always visible even when minimized
local ToggleBtn = Instance.new("TextButton"); ToggleBtn.Parent = TitleBar
ToggleBtn.Name = "ReanimToggleBtn"
ToggleBtn.AnchorPoint = Vector2.new(1, 0.5)
ToggleBtn.Position = UDim2.new(1, -58, 0.5, 0)
ToggleBtn.Size = UDim2.new(0, 54, 0, 22)
ToggleBtn.BackgroundColor3 = C.bg2; ToggleBtn.BackgroundTransparency = 0.1
ToggleBtn.BorderSizePixel = 0; ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Text = "OFF"; ToggleBtn.TextColor3 = C.text2
ToggleBtn.TextSize = 11; ToggleBtn.ZIndex = 33; ToggleBtn.AutoButtonColor = false
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,6); c.Parent = ToggleBtn end


-- AnimRecorder Button (right side of title bar)
local AnimRecorderBtn = Instance.new("TextButton"); AnimRecorderBtn.Parent = TitleBar
AnimRecorderBtn.Name = "AnimRecorderBtn"
AnimRecorderBtn.AnchorPoint = Vector2.new(1, 0.5)
AnimRecorderBtn.Position = UDim2.new(1, -118, 0.5, 0)
AnimRecorderBtn.Size = UDim2.new(0, 80, 0, 22)
AnimRecorderBtn.BackgroundColor3 = C.bg2; AnimRecorderBtn.BackgroundTransparency = 0.1
AnimRecorderBtn.BorderSizePixel = 0; AnimRecorderBtn.Font = Enum.Font.GothamBold
AnimRecorderBtn.Text = "Record"; AnimRecorderBtn.TextColor3 = C.accent
AnimRecorderBtn.TextSize = 10; AnimRecorderBtn.ZIndex = 33; AnimRecorderBtn.AutoButtonColor = false
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,6); c.Parent = AnimRecorderBtn end

-- AnimRecorder System
local AnimRecorder = {
    isRecording = false,
    recordedFrames = {},
    startTime = 0,
    recordingConn = nil,
    lastRecordedTime = 0,
    frameInterval = 1/30, -- 30 FPS recording
}

local function getCloneConstraints()
    local clone = ReanimateAPI and ReanimateAPI.get_clone and ReanimateAPI.get_clone(plr)
    if not clone then return nil end

    local constraints = {}
    for _, descendant in ipairs(clone:GetDescendants()) do
        if descendant:IsA("AnimationConstraint") then
            local attachment = descendant.Attachment1
            if attachment and attachment.Parent then
                constraints[attachment.Parent.Name] = descendant
            end
        elseif descendant:IsA("Motor6D") then
            local childPart = descendant.Part1
            if childPart and childPart.Parent and not constraints[childPart.Name] then
                constraints[childPart.Name] = descendant
            end
        end
    end
    return constraints
end

-- When the AnimCopier is active we set CFrames directly, so constraint.Transform is stale.
-- This helper computes the transform from current part CFrames so recording still works.
local function getConstraintTransformFromParts(constraint)
    if constraint:IsA("Motor6D") then
        local part0 = constraint.Part0
        local part1 = constraint.Part1
        if not part0 or not part1 or not part0.Parent or not part1.Parent then
            return constraint.Transform
        end
        return part0.CFrame * constraint.C0:Inverse() * constraint.C1:Inverse() * part1.CFrame
    else
        local att0 = constraint.Attachment0
        local att1 = constraint.Attachment1
        if not att0 or not att1 or not att0.Parent or not att1.Parent then
            return constraint.Transform
        end
        local world0 = att0.Parent.CFrame * att0.CFrame
        local world1 = att1.Parent.CFrame * att1.CFrame
        return world0:Inverse() * world1
    end
end

local function startRecording()
    if AnimRecorder.isRecording then return end
    if not ReanimateAPI or not ReanimateAPI.is_reanimated() then
        Notify("Recorder", "Please reanimate first!", 3)
        return
    end

    AnimRecorder.isRecording = true
    AnimRecorder.recordedFrames = {}
    AnimRecorder.startTime = tick()
    AnimRecorder.lastRecordedTime = 0

    AnimRecorderBtn.Text = "Stop"
    TweenService:Create(AnimRecorderBtn, TweenInfo.new(0.25), {
        BackgroundColor3 = C.red,
        TextColor3 = C.white
    }):Play()
    Notify("Recorder", "Recording started! Perform your animation.", 3)

    AnimRecorder.recordingConn = RunService.Heartbeat:Connect(function()
        if not AnimRecorder.isRecording then return end

        local elapsed = tick() - AnimRecorder.startTime
        if elapsed - AnimRecorder.lastRecordedTime < AnimRecorder.frameInterval then return end
        AnimRecorder.lastRecordedTime = elapsed

        local constraints = getCloneConstraints()
        if not constraints then return end

        local isCopierActive = _G._HaloAnimCopierActive or false
        local frameData = {}
        for boneName, constraint in pairs(constraints) do
            if constraint and constraint.Parent then
                if isCopierActive then
                    frameData[boneName] = getConstraintTransformFromParts(constraint)
                else
                    frameData[boneName] = constraint.Transform
                end
            end
        end

        table.insert(AnimRecorder.recordedFrames, {
            Time = elapsed,
            Data = frameData
        })
    end)
end

local function stopRecording()
    if not AnimRecorder.isRecording then return end

    AnimRecorder.isRecording = false
    if AnimRecorder.recordingConn then
        AnimRecorder.recordingConn:Disconnect()
        AnimRecorder.recordingConn = nil
    end

    AnimRecorderBtn.Text = "Record"
    TweenService:Create(AnimRecorderBtn, TweenInfo.new(0.25), {
        BackgroundColor3 = C.bg2,
        TextColor3 = C.accent
    }):Play()

    local frameCount = #AnimRecorder.recordedFrames
    if frameCount == 0 then
        Notify("Recorder", "No frames recorded.", 2)
        return
    end

    Notify("Recorder", "Processing " .. tostring(frameCount) .. " frames...", 2)

    -- Anti-crash: wrap everything in pcall so a memory blowup never kills the script
    local success, err = pcall(function()
        local recordedFrames = AnimRecorder.recordedFrames
        local totalDuration = recordedFrames[#recordedFrames].Time
        local SAFE_FRAME_LIMIT = 4000   -- above this we shard into cache files
        local CHUNK_FRAMES = 2000       -- frames per cache shard

        local folder = "ReanimData"
        pcall(function() makefolder(folder) end)
        local stamp = tostring(math.floor(tick()))

        if frameCount > SAFE_FRAME_LIMIT then
            -- CACHE MODE: shard into multiple JSON files so no single table/string ever gets huge
            local shardCount = math.ceil(frameCount / CHUNK_FRAMES)
            local manifest = {
                type = "recorded_cache",
                totalFrames = frameCount,
                duration = totalDuration,
                stamp = stamp,
                parts = {}
            }

            for s = 1, shardCount do
                local startIdx = (s - 1) * CHUNK_FRAMES + 1
                local endIdx = math.min(s * CHUNK_FRAMES, frameCount)
                local partData = {}

                for i = startIdx, endIdx do
                    local frame = recordedFrames[i]
                    local d = {}
                    for boneName, cf in pairs(frame.Data) do
                        d[boneName] = {cf:GetComponents()}
                    end
                    partData[i - startIdx + 1] = {Time = frame.Time, Data = d}
                end

                local partName = folder .. "/RecordedAnim_" .. stamp .. "_part" .. s .. ".json"
                local okWrite, writeErr = pcall(function()
                    writefile(partName, HttpService:JSONEncode(partData))
                end)
                if not okWrite then
                    error("Failed to write cache shard " .. s .. ": " .. tostring(writeErr))
                end
                table.insert(manifest.parts, partName)
                task.wait() -- yield between shards so the scheduler breathes
            end

            local manifestName = folder .. "/RecordedAnim_" .. stamp .. "_manifest.json"
            pcall(function()
                writefile(manifestName, HttpService:JSONEncode(manifest))
            end)

            Notify("Recorder", "Large recording cached! " .. frameCount .. " frames across " .. shardCount .. " files.", 5)
        else
            -- NORMAL MODE: compact Lua return table (original behaviour, but with chunk safety)
            local outputParts = {}
            table.insert(outputParts, "-- " .. tostring(frameCount) .. " keyframes\n")
            table.insert(outputParts, "-- " .. string.format("%.3f", totalDuration) .. " seconds\n")
            table.insert(outputParts, "return {\n")
            table.insert(outputParts, '  ["Animation"] = {\n')

            local yieldEvery = 50
            for i, frame in ipairs(recordedFrames) do
                local frameStr = "    {Time = " .. string.format("%.3f", frame.Time) .. ", Data = {\n"
                for boneName, cf in pairs(frame.Data) do
                    local comps = {cf:GetComponents()}
                    local compStrs = {}
                    for j = 1, 12 do
                        compStrs[j] = string.format("%.6f", comps[j])
                    end
                    frameStr = frameStr .. '      ["' .. boneName .. '"] = CFrame.new(' .. table.concat(compStrs, ", ") .. '),\n'
                end
                frameStr = frameStr .. "    }},\n"
                table.insert(outputParts, frameStr)

                if i % yieldEvery == 0 then
                    task.wait()
                end
            end

            table.insert(outputParts, "  }\n")
            table.insert(outputParts, "}\n")
            local output = table.concat(outputParts)
            outputParts = nil

            local filename = folder .. "/RecordedAnim_" .. stamp .. ".lua"
            pcall(function() writefile(filename, output) end)

            pcall(function()
                if setclipboard then setclipboard(output) end
            end)

            Notify("Recorder", "Saved " .. tostring(frameCount) .. " frames! Copied to clipboard.", 4)
        end
    end)

    if not success then
        warn("[AnimRecorder] Anti-crash triggered:", err)
        -- EMERGENCY FALLBACK: derender into workspace cache no matter what
        task.spawn(function()
            local ok, emergencyErr = pcall(function()
                local folder = "ReanimData"
                pcall(function() makefolder(folder) end)
                local stamp = tostring(math.floor(tick()))
                local shard = 1
                local partData = {}
                local chunkSize = 1000

                for i, frame in ipairs(AnimRecorder.recordedFrames) do
                    local d = {}
                    for boneName, cf in pairs(frame.Data) do
                        d[boneName] = {cf:GetComponents()}
                    end
                    table.insert(partData, {Time = frame.Time, Data = d})

                    if #partData >= chunkSize then
                        local partName = folder .. "/RecordedAnim_Emergency_" .. stamp .. "_part" .. shard .. ".json"
                        pcall(function() writefile(partName, HttpService:JSONEncode(partData)) end)
                        partData = {}
                        shard = shard + 1
                        task.wait()
                    end
                end

                if #partData > 0 then
                    local partName = folder .. "/RecordedAnim_Emergency_" .. stamp .. "_part" .. shard .. ".json"
                    pcall(function() writefile(partName, HttpService:JSONEncode(partData)) end)
                end

                local manifestName = folder .. "/RecordedAnim_Emergency_" .. stamp .. "_manifest.json"
                local manifest = {
                    type = "recorded_cache",
                    totalFrames = #AnimRecorder.recordedFrames,
                    parts = shard,
                    stamp = stamp
                }
                pcall(function() writefile(manifestName, HttpService:JSONEncode(manifest)) end)

                Notify("Recorder", "Emergency cache saved! Check ReanimData folder.", 5)
            end)
            if not ok then
                warn("[AnimRecorder] Emergency fallback ALSO failed:", emergencyErr)
                Notify("Recorder", "CRITICAL: Could not save recording. Data lost.", 5)
            end
        end)
    end
end

AnimRecorderBtn.MouseButton1Click:Connect(function()
    if AnimRecorder.isRecording then
        stopRecording()
    else
        startRecording()
    end
end)

AnimRecorderBtn.MouseEnter:Connect(function()
    if not AnimRecorder.isRecording then
        TweenService:Create(AnimRecorderBtn, TweenInfo.new(0.12), {BackgroundTransparency = 0}):Play()
    end
end)
AnimRecorderBtn.MouseLeave:Connect(function()
    if not AnimRecorder.isRecording then
        TweenService:Create(AnimRecorderBtn, TweenInfo.new(0.12), {BackgroundTransparency = 0.1}):Play()
    end
end)

function UpdateToggleBtn()
    if State.isReanimated then
        TweenService:Create(ToggleBtn, TweenInfo.new(0.25), {
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundTransparency = 0,
            TextColor3 = Color3.fromRGB(0, 0, 0)
        }):Play()
        ToggleBtn.Text = "ON"
    else
        TweenService:Create(ToggleBtn, TweenInfo.new(0.25), {
            BackgroundColor3 = C.bg2,
            BackgroundTransparency = 0.1,
            TextColor3 = C.text2
        }):Play()
        ToggleBtn.Text = "OFF"
    end
end

ToggleBtn.MouseButton1Click:Connect(function()
    if type(_G._HaloDoReanimToggle) == "function" then
        _G._HaloDoReanimToggle()
    end
end)
ToggleBtn.MouseEnter:Connect(function()
    if not State.isReanimated then
        pcall(function()
            TweenService:Create(ToggleBtn, TweenInfo.new(0.12, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundTransparency = 0}):Play()
        end)
    end
end)
ToggleBtn.MouseLeave:Connect(function()
    if not State.isReanimated then
        pcall(function()
            TweenService:Create(ToggleBtn, TweenInfo.new(0.12, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundTransparency = 0.1}):Play()
        end)
    end
end)

local function _HaloTopFixedPos(gui, newHeight)
    local parent = gui.Parent
    if not parent then return gui.Position end
    local pap = parent.AbsolutePosition
    local pas = parent.AbsoluteSize
    local anchor = gui.AnchorPoint
    local pos = gui.Position
    local absY = pap.Y + pos.Y.Scale * pas.Y + pos.Y.Offset
    local minY = pap.Y + anchor.Y * newHeight
    local maxY = pap.Y + pas.Y - (1 - anchor.Y) * newHeight
    local clampedY = math.clamp(absY, minY, maxY)
    return UDim2.new(pos.X.Scale, pos.X.Offset, pos.Y.Scale, clampedY - pap.Y - pos.Y.Scale * pas.Y)
end

local isMinimized = false
local FULL_SIZE   = UDim2.new(0, CONFIG.UI.DEFAULT_WIDTH, 0, CONFIG.UI.DEFAULT_HEIGHT)
local MINI_SIZE   = UDim2.new(0, CONFIG.UI.DEFAULT_WIDTH, 0, 40)
Menu.Size         = FULL_SIZE

closeBtn.MouseButton1Click:Connect(function()
    Menu.Visible = false
    ScreenGui.Enabled = false
end)

do
    -- DRAG + SCREEN CLAMP (exact pattern from user example)
    -- absolute-pixel based, Scale/AnchorPoint/Inset safe
    local dragging = false
    local dragInputStart
    local startAnchorAbsPos

    local function getAnchorAbsPosition()
        local parent = Menu.Parent
        local parentAbsPos = parent.AbsolutePosition
        local parentAbsSize = parent.AbsoluteSize
        local pos = Menu.Position
        local x = parentAbsPos.X + pos.X.Scale * parentAbsSize.X + pos.X.Offset
        local y = parentAbsPos.Y + pos.Y.Scale * parentAbsSize.Y + pos.Y.Offset
        return Vector2.new(x, y)
    end

    local function setClampedPosition(targetAbsX, targetAbsY)
        local parent = Menu.Parent
        local parentAbsPos = parent.AbsolutePosition
        local parentAbsSize = parent.AbsoluteSize
        local absSize = Menu.AbsoluteSize
        local anchor = Menu.AnchorPoint
        local minX = parentAbsPos.X + anchor.X * absSize.X
        local maxX = parentAbsPos.X + parentAbsSize.X - (1 - anchor.X) * absSize.X
        local minY = parentAbsPos.Y + anchor.Y * absSize.Y
        local maxY = parentAbsPos.Y + parentAbsSize.Y - (1 - anchor.Y) * absSize.Y
        local x = math.clamp(targetAbsX, minX, maxX)
        local y = math.clamp(targetAbsY, minY, maxY)
        Menu.Position = UDim2.new(0, x - parentAbsPos.X, 0, y - parentAbsPos.Y)
    end

    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragInputStart = input.Position
            startAnchorAbsPos = getAnchorAbsPosition()
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragInputStart
            setClampedPosition(startAnchorAbsPos.X + delta.X, startAnchorAbsPos.Y + delta.Y)
        end
    end)
end

body = Instance.new("Frame"); body.Parent = Menu
body.BackgroundTransparency = 1; body.Position = UDim2.new(0,0,0,40)
body.Size = UDim2.new(1,0,1,-48); body.ZIndex = 31

minimizeBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    local ti = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    if isMinimized then
        body.Visible = false
        TweenService:Create(Menu, ti, {Size = MINI_SIZE, Position = _HaloTopFixedPos(Menu, MINI_SIZE.Y.Offset)}):Play()
        minimizeBtn.Text = ""
    else
        TweenService:Create(Menu, ti, {Size = FULL_SIZE, Position = _HaloTopFixedPos(Menu, FULL_SIZE.Y.Offset)}):Play()
        task.delay(0.28, function() body.Visible = true end)
        minimizeBtn.Text = ""
    end
end)

local toggleBar = Instance.new("Frame"); toggleBar.Parent = body
toggleBar.BackgroundColor3 = C.bg1; toggleBar.BackgroundTransparency = 0.4
toggleBar.BorderSizePixel = 0; toggleBar.Size = UDim2.new(1,-20,0,30)
toggleBar.Position = UDim2.new(0,10,0,6); toggleBar.ZIndex = 32
do 
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,8); c.Parent = toggleBar
    local s = Instance.new("UIStroke"); s.Color = C.border; s.Transparency = 0.6; s.Thickness = 1; s.Parent = toggleBar
end

local reanimLabel = Instance.new("TextLabel"); reanimLabel.Parent = toggleBar
reanimLabel.BackgroundTransparency = 1; reanimLabel.Position = UDim2.new(0,12,0,0)
reanimLabel.Size = UDim2.new(0.55,0,1,0); reanimLabel.Font = Enum.Font.GothamBold
reanimLabel.Text = "Reanimation"; reanimLabel.TextColor3 = C.text
reanimLabel.TextSize = 12; reanimLabel.TextXAlignment = Enum.TextXAlignment.Left; reanimLabel.ZIndex = 33

-- ToggleBtn is now in the TitleBar (always visible). The toggleBar in the body
-- keeps its label for context but no longer holds a second button.

function _attachPlayRawAnimation()
    -- disabled
end

local _activating = false
local _lastToggleAt = 0

function _smoothToggle(callFn)
    local cam = workspace.CurrentCamera
    local char = plr.Character
    local savedHRP, savedCam

    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then savedHRP = hrp.CFrame end
    end
    if cam then savedCam = cam.CFrame end

    callFn()

    local frames = 0
    local conn
    conn = RunService.RenderStepped:Connect(LPH_NO_VIRTUALIZE(function()
        frames = frames + 1
        local c2 = plr.Character
        local hrp2 = c2 and c2:FindFirstChild("HumanoidRootPart")
        if hrp2 and savedHRP then
            hrp2.CFrame = savedHRP
        end
        local cam2 = workspace.CurrentCamera
        if cam2 and savedCam then
            cam2.CFrame = savedCam
        end
        if frames >= 6 then
            conn:Disconnect()
        end
    end))
end

-- Shared reanimate toggle logic — called by ToggleBtn in TitleBar
local function doReanimToggle()
    if _activating then return end
    if tick() - _lastToggleAt < 0.75 then return end
    _lastToggleAt = tick()

    if State.isReanimated then
        _activating = true
        task.spawn(function()
            stopStateSystem()
            _smoothToggle(function()
                pcall(function() ReanimateAPI.reanimate(false) end)
            end)
            State.isReanimated = false
            State.selectedAnim = nil
            _activating = false
            UpdateToggleBtn()
            Notify("Reanimation disabled")
        end)
        return
    end

    _activating = true
    task.spawn(function()
        local err
        local ok = pcall(function()
            _smoothToggle(function()
                if ReanimateAPI == nil then
                    error("ReanimateAPI is nil")
                elseif ReanimateAPI.reanimate == nil then
                    error("ReanimateAPI.reanimate is nil")
                end
                local res = ReanimateAPI.reanimate(true)
                if type(res) == "string" then
                    err = res
                    error(res)
                end
            end)
        end)

        State.isReanimated = ReanimateAPI and ReanimateAPI.is_reanimated() or false
        UpdateToggleBtn()

        if not State.isReanimated then
            _activating = false
            Notify("Reanimation failed: " .. tostring(err or "Unknown error"), 4)
            return
        end

        task.spawn(function()
            prefetchAllStates()
            task.wait(0.15)
            startStateSystem()
        end)
        _activating = false
        Notify("Reanimation enabled!", 2)
    end)
end

-- Expose for the title-bar toggle button
_G._HaloDoReanimToggle = doReanimToggle

-- GrabStatus click fix: when reanimated, your own clone/real character can
-- block the game's click raycast. We do our OWN raycast from the camera through
-- the mouse position, explicitly excluding both your clone and real character,
-- then fire GrabStatus:InvokeServer(userId) for whichever player we hit.
do
    local _grabRemote = nil

    local function _getGrabRemote()
        if _grabRemote and _grabRemote.Parent then return _grabRemote end
        local ok, r = pcall(function()
            return game:GetService("ReplicatedStorage"):FindFirstChild("GrabStatus")
        end)
        if ok and r then _grabRemote = r end
        return _grabRemote
    end

    -- Find which player owns the model that contains `inst`
    local function _getPlayerFromInstance(inst)
        local Players = game:GetService("Players")
        local model = inst and inst:FindFirstAncestorOfClass("Model")
        while model do
            local p = Players:GetPlayerFromCharacter(model)
            if p and p ~= plr then return p end
            model = model:FindFirstAncestorOfClass("Model")
        end
        -- Fallback: descendant check
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= plr and p.Character and inst and inst:IsDescendantOf(p.Character) then
                return p
            end
        end
        return nil
    end

    local _mouse = plr:GetMouse()
    _mouse.Button1Down:Connect(function()
        if not State.isReanimated then return end
        local remote = _getGrabRemote()
        if not remote then return end

        local cam = workspace.CurrentCamera
        if not cam then return end

        -- Build exclusion list: our clone + real char (and current Character)
        local exclude = {}
        pcall(function()
            if _G._HaloReanimateAPI then
                local clone = _G._HaloReanimateAPI.get_clone and _G._HaloReanimateAPI.get_clone(plr)
                local realc = _G._HaloReanimateAPI.get_real_character and _G._HaloReanimateAPI.get_real_character(plr)
                if clone then table.insert(exclude, clone) end
                if realc then table.insert(exclude, realc) end
            end
        end)
        if plr.Character then table.insert(exclude, plr.Character) end

        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.FilterDescendantsInstances = exclude
        rayParams.IgnoreWater = true

        local unitRay = cam:ViewportPointToRay(_mouse.X, _mouse.Y)
        local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 5000, rayParams)

        local targetPlayer = nil
        if result and result.Instance then
            targetPlayer = _getPlayerFromInstance(result.Instance)
        end
        -- Fallback to Mouse.Target if raycast missed
        if not targetPlayer and _mouse.Target then
            targetPlayer = _getPlayerFromInstance(_mouse.Target)
        end

        if targetPlayer then
            pcall(function() remote:InvokeServer(targetPlayer.UserId) end)
        end
    end)
end

local npBar = Instance.new("Frame"); npBar.Parent = body
npBar.BackgroundColor3 = C.bg1; npBar.BackgroundTransparency = 0.4
npBar.BorderSizePixel = 0; npBar.Size = UDim2.new(1,-20,0,26)
npBar.Position = UDim2.new(0,10,0,42); npBar.ZIndex = 32
do 
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,6); c.Parent = npBar
    local s = Instance.new("UIStroke"); s.Color = C.border; s.Transparency = 0.7; s.Thickness = 1; s.Parent = npBar
end

NowPlayingLabel = Instance.new("TextLabel"); NowPlayingLabel.Parent = npBar
NowPlayingLabel.BackgroundTransparency = 1; NowPlayingLabel.Position = UDim2.new(0,8,0,0)
NowPlayingLabel.Size = UDim2.new(1,-74,1,0); NowPlayingLabel.Font = Enum.Font.Gotham
NowPlayingLabel.Text = "No animation playing"
NowPlayingLabel.TextColor3 = C.text2
NowPlayingLabel.TextSize = 11; NowPlayingLabel.TextXAlignment = Enum.TextXAlignment.Left
NowPlayingLabel.TextTruncate = Enum.TextTruncate.AtEnd; NowPlayingLabel.ZIndex = 33

StopBtn = Instance.new("TextButton"); StopBtn.Parent = npBar
StopBtn.AnchorPoint = Vector2.new(1,0.5); StopBtn.BackgroundColor3 = C.red
StopBtn.BackgroundTransparency = 0.2; StopBtn.BorderSizePixel = 0
StopBtn.Position = UDim2.new(1,-6,0.5,0); StopBtn.Size = UDim2.new(0,58,0,20)
StopBtn.Font = Enum.Font.GothamBold; StopBtn.Text = "Stop"
StopBtn.TextColor3 = C.white; StopBtn.TextSize = 10
StopBtn.ZIndex = 33; StopBtn.AutoButtonColor = false
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,5); c.Parent = StopBtn end

local tabRow = Instance.new("Frame"); tabRow.Parent = body
tabRow.BackgroundTransparency = 1; tabRow.Size = UDim2.new(1,-20,0,24)
tabRow.Position = UDim2.new(0,10,0,74); tabRow.ZIndex = 32
do
    local l = Instance.new("UIListLayout"); l.Parent = tabRow
    l.FillDirection = Enum.FillDirection.Horizontal
    l.HorizontalAlignment = Enum.HorizontalAlignment.Left
    l.Padding = UDim.new(0,3)
end

local TAB_DEFS = { "All", "Favs", "Custom", "Binds", "States", "Speed", "Copier", "Tracker", "Settings" }
TabButtons = {}
local activeTab = nil

SetTabActive = function(btn)
    if activeTab then
        local oldLine = activeTab:FindFirstChild("Underline")
        TweenService:Create(activeTab, TweenInfo.new(0.2), {TextColor3 = C.text3}):Play()
        if oldLine then
            TweenService:Create(oldLine, TweenInfo.new(0.2), {BackgroundTransparency = 1, Size = UDim2.new(0,0,0,2)}):Play()
        end
    end
    activeTab = btn
    local newLine = btn:FindFirstChild("Underline")
    TweenService:Create(btn, TweenInfo.new(0.2), {TextColor3 = C.accent}):Play()
    if newLine then
        TweenService:Create(newLine, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {BackgroundTransparency = 0, Size = UDim2.new(0.7,0,0,2)}):Play()
    end
end

for _, tname in ipairs(TAB_DEFS) do
    local tb = Instance.new("TextButton"); tb.Parent = tabRow
    tb.BackgroundColor3 = C.bg2; tb.BackgroundTransparency = 1
    tb.BorderSizePixel = 0; tb.Size = UDim2.new(1/#TAB_DEFS,-2,1,0)
    tb.Font = Enum.Font.GothamMedium; tb.Text = tname
    tb.TextColor3 = C.text3; tb.TextSize = 9
    tb.ZIndex = 33; tb.AutoButtonColor = false
    do 
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,6); c.Parent = tb
    end
    -- Animated underline indicator
    local underline = Instance.new("Frame"); underline.Name = "Underline"
    underline.Parent = tb; underline.BackgroundColor3 = C.white
    underline.BackgroundTransparency = 1; underline.BorderSizePixel = 0
    underline.Position = UDim2.new(0.5,0,1,-2); underline.AnchorPoint = Vector2.new(0.5,0)
    underline.Size = UDim2.new(0,0,0,2); underline.ZIndex = 34
    tb.MouseEnter:Connect(function()
        if activeTab ~= tb then
            TweenService:Create(tb, TweenInfo.new(0.15), {TextColor3 = C.text2}):Play()
            TweenService:Create(underline, TweenInfo.new(0.15), {BackgroundTransparency = 0.5, Size = UDim2.new(0.5,0,0,2)}):Play()
        end
    end)
    tb.MouseLeave:Connect(function()
        if activeTab ~= tb then
            TweenService:Create(tb, TweenInfo.new(0.15), {TextColor3 = C.text3}):Play()
            TweenService:Create(underline, TweenInfo.new(0.15), {BackgroundTransparency = 1, Size = UDim2.new(0,0,0,2)}):Play()
        end
    end)
    TabButtons[tname] = tb
end

-- Function to update Custom tab text with animation count
local function UpdateCustomTabCount()
    local customBtn = TabButtons["Custom"]
    if customBtn then
        customBtn.Text = "Custom"
    end
end

SearchBox = Instance.new("TextBox"); SearchBox.Parent = body
SearchBox.BackgroundColor3 = C.bg1; SearchBox.BackgroundTransparency = 0.4
SearchBox.BorderSizePixel = 0; SearchBox.Size = UDim2.new(1,-20,0,26)
SearchBox.Position = UDim2.new(0,10,0,104); SearchBox.ZIndex = 32
SearchBox.Font = Enum.Font.GothamMedium; SearchBox.PlaceholderText = "Search..."
SearchBox.PlaceholderColor3 = C.text3; SearchBox.Text = ""
SearchBox.TextColor3 = C.text; SearchBox.TextSize = 11
SearchBox.ClearTextOnFocus = false
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,6); c.Parent = SearchBox
    local p = Instance.new("UIPadding"); p.PaddingLeft = UDim.new(0,10); p.Parent = SearchBox
    local s = Instance.new("UIStroke"); s.Color = C.border; s.Transparency = 0.7; s.Thickness = 1; s.Parent = SearchBox
end

hintLbl = Instance.new("TextLabel"); hintLbl.Parent = body
hintLbl.BackgroundTransparency = 1; hintLbl.Size = UDim2.new(1,-20,0,12)
hintLbl.Position = UDim2.new(0,10,0,134); hintLbl.ZIndex = 32; hintLbl.Font = Enum.Font.Gotham
hintLbl.Text = "Click [+] to bind key  |  Click bound key to unbind"
hintLbl.TextColor3 = C.text3; hintLbl.TextSize = 9
hintLbl.TextXAlignment = Enum.TextXAlignment.Left

AnimListFrame = Instance.new("ScrollingFrame"); AnimListFrame.Parent = body
AnimListFrame.BackgroundColor3 = C.bg0; AnimListFrame.BackgroundTransparency = 0.5
AnimListFrame.BorderSizePixel = 0
AnimListFrame.Size = UDim2.new(1,-20,1,-236)
AnimListFrame.Position = UDim2.new(0,10,0,148)
AnimListFrame.ScrollBarThickness = 4; AnimListFrame.ScrollBarImageColor3 = C.accent
AnimListFrame.ScrollBarImageTransparency = 0.5; AnimListFrame.ZIndex = 32
AnimListFrame.CanvasSize = UDim2.new(0,0,0,0)
AnimListFrame.ScrollingDirection = getSafeScrollingDirection("Y")
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,7); c.Parent = AnimListFrame end

-- States panel stays inside the main reanim UI and expands inline pickers.
StatesPanel = Instance.new("ScrollingFrame"); StatesPanel.Name = "StatesSection"
StatesPanel.BackgroundTransparency = 1; StatesPanel.BorderSizePixel = 0
StatesPanel.Size = UDim2.new(1,0,0,0); StatesPanel.AutomaticSize = getSafeAutomaticSize()
StatesPanel.ZIndex = 32; StatesPanel.LayoutOrder = 100
StatesPanel.ScrollBarThickness = 4; StatesPanel.ScrollBarImageColor3 = C.accent
StatesPanel.ScrollBarImageTransparency = 0.5; StatesPanel.CanvasSize = UDim2.new(0,0,0,0)
do
    local l = Instance.new("UIListLayout"); l.Parent = StatesPanel
    l.Padding = UDim.new(0,4); l.SortOrder = Enum.SortOrder.LayoutOrder
    local p = Instance.new("UIPadding"); p.Parent = StatesPanel
    p.PaddingTop = UDim.new(0,4); p.PaddingLeft = UDim.new(0,2); p.PaddingRight = UDim.new(0,2); p.PaddingBottom = UDim.new(0,8)
    l:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        StatesPanel.CanvasSize = UDim2.new(0,0,0,l.AbsoluteContentSize.Y+16)
    end)
end

CustomPanel = Instance.new("Frame"); CustomPanel.Parent = body
CustomPanel.BackgroundTransparency = 1
CustomPanel.Size = UDim2.new(1,-20,1,-236)
CustomPanel.Position = UDim2.new(0,10,0,148)
CustomPanel.ZIndex = 32; CustomPanel.Visible = false

-- BindsPanel: shows all animations with keybinds set
BindsPanel = Instance.new("ScrollingFrame"); BindsPanel.Parent = body
BindsPanel.Name = "BindsPanel"
BindsPanel.BackgroundColor3 = C.bg0; BindsPanel.BackgroundTransparency = 0.5
BindsPanel.BorderSizePixel = 0
BindsPanel.Size = UDim2.new(1,-20,1,-156)
BindsPanel.Position = UDim2.new(0,10,0,148)
BindsPanel.ScrollBarThickness = 4; BindsPanel.ScrollBarImageColor3 = C.accent
BindsPanel.ScrollBarImageTransparency = 0.5; BindsPanel.ZIndex = 32
BindsPanel.CanvasSize = UDim2.new(0,0,0,0); BindsPanel.Visible = false
BindsPanel.ScrollingDirection = getSafeScrollingDirection("Y")
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,7); c.Parent = BindsPanel end

customSearchBox = Instance.new("TextBox"); customSearchBox.Parent = CustomPanel
customSearchBox.BackgroundColor3 = C.bg1; customSearchBox.BackgroundTransparency = 0.4
customSearchBox.BorderSizePixel = 0; customSearchBox.Size = UDim2.new(1,0,0,26)
customSearchBox.Position = UDim2.new(0,0,0,0); customSearchBox.ZIndex = 32
customSearchBox.Font = Enum.Font.GothamMedium; customSearchBox.PlaceholderText = "Search custom animations..."
customSearchBox.PlaceholderColor3 = C.text3; customSearchBox.Text = ""
customSearchBox.TextColor3 = C.text; customSearchBox.TextSize = 11
customSearchBox.ClearTextOnFocus = false
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,6); c.Parent = customSearchBox
    local p = Instance.new("UIPadding"); p.PaddingLeft = UDim.new(0,10); p.Parent = customSearchBox
    local s = Instance.new("UIStroke"); s.Color = C.border; s.Transparency = 0.7; s.Thickness = 1; s.Parent = customSearchBox
end

customOpenModalBtn = Instance.new("TextButton"); customOpenModalBtn.Parent = CustomPanel
customOpenModalBtn.BackgroundColor3 = C.bg2
customOpenModalBtn.BackgroundTransparency = 0.3; customOpenModalBtn.BorderSizePixel = 0
customOpenModalBtn.Size = UDim2.new(1,-92,0,36); customOpenModalBtn.Position = UDim2.new(0,0,0,30)
customOpenModalBtn.Font = Enum.Font.GothamBold; customOpenModalBtn.Text = "+  Add Custom Animation"
customOpenModalBtn.TextColor3 = C.accent; customOpenModalBtn.TextSize = 12
customOpenModalBtn.ZIndex = 33; customOpenModalBtn.AutoButtonColor = false
do 
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,8); c.Parent = customOpenModalBtn
    local s = Instance.new("UIStroke"); s.Color = C.accent; s.Transparency = 0.7; s.Thickness = 1; s.Parent = customOpenModalBtn
end
customOpenModalBtn.MouseEnter:Connect(function()
    TweenService:Create(customOpenModalBtn, TweenInfo.new(0.12), {BackgroundColor3 = C.accent, BackgroundTransparency = 0.2, TextColor3 = Color3.fromRGB(10,10,10)}):Play()
    TweenService:Create(customOpenModalBtn:FindFirstChildOfClass("UIStroke"), TweenInfo.new(0.12), {Transparency = 0}):Play()
end)
customOpenModalBtn.MouseLeave:Connect(function()
    TweenService:Create(customOpenModalBtn, TweenInfo.new(0.12), {BackgroundColor3 = C.bg2, BackgroundTransparency = 0.3, TextColor3 = C.accent}):Play()
    TweenService:Create(customOpenModalBtn:FindFirstChildOfClass("UIStroke"), TweenInfo.new(0.12), {Transparency = 0.7}):Play()
end)

-- Refresh button: re-scan the ReanimData folder for newly added custom animations
local customRefreshBtn = Instance.new("TextButton"); customRefreshBtn.Parent = CustomPanel
customRefreshBtn.BackgroundColor3 = C.bg2
customRefreshBtn.BackgroundTransparency = 0.3; customRefreshBtn.BorderSizePixel = 0
customRefreshBtn.Size = UDim2.new(0,84,0,36); customRefreshBtn.Position = UDim2.new(1,-84,0,30)
customRefreshBtn.Font = Enum.Font.GothamBold; customRefreshBtn.Text = "Refresh"
customRefreshBtn.TextColor3 = C.accent; customRefreshBtn.TextSize = 11
customRefreshBtn.ZIndex = 33; customRefreshBtn.AutoButtonColor = false
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,8); c.Parent = customRefreshBtn
    local s = Instance.new("UIStroke"); s.Color = C.accent; s.Transparency = 0.7; s.Thickness = 1; s.Parent = customRefreshBtn
end
customRefreshBtn.MouseEnter:Connect(function()
    TweenService:Create(customRefreshBtn, TweenInfo.new(0.12), {BackgroundColor3 = C.accent, BackgroundTransparency = 0.2, TextColor3 = Color3.fromRGB(10,10,10)}):Play()
    TweenService:Create(customRefreshBtn:FindFirstChildOfClass("UIStroke"), TweenInfo.new(0.12), {Transparency = 0}):Play()
end)
customRefreshBtn.MouseLeave:Connect(function()
    TweenService:Create(customRefreshBtn, TweenInfo.new(0.12), {BackgroundColor3 = C.bg2, BackgroundTransparency = 0.3, TextColor3 = C.accent}):Play()
    TweenService:Create(customRefreshBtn:FindFirstChildOfClass("UIStroke"), TweenInfo.new(0.12), {Transparency = 0.7}):Play()
end)
customRefreshBtn.MouseButton1Click:Connect(function()
    customRefreshBtn.Text = "..."
    task.spawn(function()
        local prevCount = #CustomAnims
        -- Re-run the loader: it rescans the ReanimData folder for new .lua/.json
        -- files (plus the saved list) and returns the merged set.
        local ok, result = pcall(LoadCustomAnims)
        if ok and type(result) == "table" then
            CustomAnims = result
            table.clear(CustomAnimations)
            for _, ca in ipairs(CustomAnims) do
                CustomAnimations[ca.name] = ca.url
            end
            pcall(SaveCustomAnims)
            -- Update Custom tab count after rescanning
            if UpdateCustomTabCount then
                UpdateCustomTabCount()
            end
        end
        if RebuildCustomList then pcall(RebuildCustomList) end
        local added = #CustomAnims - prevCount
        customRefreshBtn.Text = "Refresh"
        if Notify then
            if added > 0 then
                Notify("Found " .. added .. " new animation" .. (added == 1 and "" or "s"), 2.5)
            else
                Notify("No new animations found", 2)
            end
        end
    end)
end)

customListFrame = Instance.new("ScrollingFrame"); customListFrame.Parent = CustomPanel
customListFrame.BackgroundColor3 = C.bg0; customListFrame.BackgroundTransparency = 0.5
customListFrame.BorderSizePixel = 0; customListFrame.Position = UDim2.new(0,0,0,70)
customListFrame.Size = UDim2.new(1,0,1,-74)
customListFrame.ScrollBarThickness = 4; customListFrame.ScrollBarImageColor3 = C.accent
customListFrame.ScrollBarImageTransparency = 0.5; customListFrame.ZIndex = 33
customListFrame.CanvasSize = UDim2.new(0,0,0,0)
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,7); c.Parent = customListFrame
    -- No UIListLayout: rows are positioned absolutely so the custom list can be
    -- virtualized (only visible rows exist). CanvasSize is managed manually in
    -- RebuildCustomList.
end

SettingsPanel = Instance.new("ScrollingFrame"); SettingsPanel.Parent = body
SettingsPanel.Name = "SettingsPanel"
SettingsPanel.BackgroundColor3 = C.bg0; SettingsPanel.BackgroundTransparency = 0.5
SettingsPanel.BorderSizePixel = 0
SettingsPanel.Size = UDim2.new(1,-20,1,-236)
SettingsPanel.Position = UDim2.new(0,10,0,148)
SettingsPanel.ScrollBarThickness = 4; SettingsPanel.ScrollBarImageColor3 = C.accent
SettingsPanel.ScrollBarImageTransparency = 0.5; SettingsPanel.ZIndex = 32
SettingsPanel.CanvasSize = UDim2.new(0,0,0,0); SettingsPanel.Visible = false
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,7); c.Parent = SettingsPanel
    local l = Instance.new("UIListLayout"); l.Parent = SettingsPanel
    l.Padding = UDim.new(0,8); l.SortOrder = Enum.SortOrder.LayoutOrder
    local p = Instance.new("UIPadding"); p.Parent = SettingsPanel
    p.PaddingTop = UDim.new(0,8); p.PaddingLeft = UDim.new(0,8); p.PaddingRight = UDim.new(0,8)
    l:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        SettingsPanel.CanvasSize = UDim2.new(0,0,0,l.AbsoluteContentSize.Y+16)
    end)
end

SpeedPanel = Instance.new("ScrollingFrame"); SpeedPanel.Parent = body
SpeedPanel.Name = "SpeedPanel"
SpeedPanel.BackgroundColor3 = C.bg0; SpeedPanel.BackgroundTransparency = 0.5
SpeedPanel.BorderSizePixel = 0
SpeedPanel.Size = UDim2.new(1,-20,1,-112)
SpeedPanel.Position = UDim2.new(0,10,0,104)
SpeedPanel.ScrollBarThickness = 4; SpeedPanel.ScrollBarImageColor3 = C.accent
SpeedPanel.ScrollBarImageTransparency = 0.5; SpeedPanel.ZIndex = 32
SpeedPanel.CanvasSize = UDim2.new(0,0,0,0); SpeedPanel.Visible = false
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,7); c.Parent = SpeedPanel
    local l = Instance.new("UIListLayout"); l.Parent = SpeedPanel
    l.Padding = UDim.new(0,8); l.SortOrder = Enum.SortOrder.LayoutOrder
    local p = Instance.new("UIPadding"); p.Parent = SpeedPanel
    p.PaddingTop = UDim.new(0,8); p.PaddingLeft = UDim.new(0,8); p.PaddingRight = UDim.new(0,8); p.PaddingBottom = UDim.new(0,8)
    l:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        SpeedPanel.CanvasSize = UDim2.new(0,0,0,l.AbsoluteContentSize.Y+16)
    end)
end

-- States panel as a separate panel (not embedded in Settings)

-- Testing Panel (diagnostics & debug)
TestingPanel = Instance.new("ScrollingFrame"); TestingPanel.Parent = body
TestingPanel.Name = "TestingPanel"
TestingPanel.BackgroundColor3 = C.bg0; TestingPanel.BackgroundTransparency = 0.5
TestingPanel.BorderSizePixel = 0
TestingPanel.Size = UDim2.new(1,-20,1,-112)
TestingPanel.Position = UDim2.new(0,10,0,104)
TestingPanel.ScrollBarThickness = 4; TestingPanel.ScrollBarImageColor3 = C.accent
TestingPanel.ScrollBarImageTransparency = 0.5; TestingPanel.ZIndex = 32
TestingPanel.CanvasSize = UDim2.new(0,0,0,0); TestingPanel.Visible = false
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,7); c.Parent = TestingPanel
    local l = Instance.new("UIListLayout"); l.Parent = TestingPanel
    l.Padding = UDim.new(0,8); l.SortOrder = Enum.SortOrder.LayoutOrder
    local p = Instance.new("UIPadding"); p.Parent = TestingPanel
    p.PaddingTop = UDim.new(0,8); p.PaddingLeft = UDim.new(0,8); p.PaddingRight = UDim.new(0,8); p.PaddingBottom = UDim.new(0,8)
    l:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        TestingPanel.CanvasSize = UDim2.new(0,0,0,l.AbsoluteContentSize.Y+16)
    end)
end

-- ============================================
-- PLAYER TRACKER PANEL
-- ============================================
TrackerPanel = Instance.new("Frame"); TrackerPanel.Parent = body
TrackerPanel.Name = "TrackerPanel"
TrackerPanel.BackgroundTransparency = 1
TrackerPanel.Size = UDim2.new(1,-20,1,-148)
TrackerPanel.Position = UDim2.new(0,10,0,104)
TrackerPanel.ZIndex = 32; TrackerPanel.Visible = false

local trFrame = Instance.new("Frame"); trFrame.Parent = TrackerPanel
trFrame.Size = UDim2.new(1,0,0,380)
trFrame.BackgroundColor3 = C.bg1
trFrame.BackgroundTransparency = 0.4
trFrame.BorderSizePixel = 0
trFrame.Position = UDim2.new(0,0,0,0)
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,7); c.Parent = trFrame
    local s = Instance.new("UIStroke"); s.Color = C.border; s.Transparency = 0.7; s.Thickness = 1; s.Parent = trFrame
end

local trLbl = Instance.new("TextLabel", trFrame)
trLbl.BackgroundTransparency = 1; trLbl.Position = UDim2.new(0,10,0,6)
trLbl.Size = UDim2.new(1,-120,0,16); trLbl.Font = Enum.Font.GothamBold
trLbl.Text = "Player Tracker"; trLbl.TextColor3 = C.accent; trLbl.TextSize = 11
trLbl.TextXAlignment = Enum.TextXAlignment.Left; trLbl.ZIndex = 33

local trSub = Instance.new("TextLabel", trFrame)
trSub.BackgroundTransparency = 1; trSub.Position = UDim2.new(0,10,0,22)
trSub.Size = UDim2.new(1,-120,0,24); trSub.Font = Enum.Font.Gotham
trSub.Text = "Select limbs to track target. Each limb points & stretches to touch their HRP."
trSub.TextColor3 = C.text3
trSub.TextSize = 9; trSub.TextXAlignment = Enum.TextXAlignment.Left; trSub.TextWrapped = true; trSub.ZIndex = 33

local trToggleBg = Instance.new("Frame", trFrame)
trToggleBg.Size = UDim2.new(0,44,0,22); trToggleBg.Position = UDim2.new(1,-54,0,12)
trToggleBg.BackgroundColor3 = C.bg4; trToggleBg.BorderSizePixel = 0; trToggleBg.ZIndex = 33
local trc = Instance.new("UICorner", trToggleBg); trc.CornerRadius = UDim.new(0,11)
local trKnob = Instance.new("Frame", trToggleBg)
trKnob.Size = UDim2.new(0,16,0,16); trKnob.Position = UDim2.new(0,3,0,3)
trKnob.BackgroundColor3 = C.white; trKnob.BorderSizePixel = 0; trKnob.ZIndex = 34
local trck = Instance.new("UICorner", trKnob); trck.CornerRadius = UDim.new(0,8)
local trToggleBtn = Instance.new("TextButton", trToggleBg)
trToggleBtn.Size = UDim2.new(1,0,1,0); trToggleBtn.BackgroundTransparency = 1; trToggleBtn.Text = ""; trToggleBtn.ZIndex = 35

-- Search box
local trSearchBox = Instance.new("TextBox", trFrame)
trSearchBox.BackgroundColor3 = C.bg2; trSearchBox.BackgroundTransparency = 0.3
trSearchBox.BorderSizePixel = 0; trSearchBox.Position = UDim2.new(0,10,0,50)
trSearchBox.Size = UDim2.new(1,-20,0,26); trSearchBox.ZIndex = 33
trSearchBox.Font = Enum.Font.GothamMedium; trSearchBox.PlaceholderText = "Search player..."
trSearchBox.PlaceholderColor3 = C.text3; trSearchBox.Text = ""
trSearchBox.TextColor3 = C.text; trSearchBox.TextSize = 11
trSearchBox.ClearTextOnFocus = false
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,6); c.Parent = trSearchBox
    local p = Instance.new("UIPadding"); p.PaddingLeft = UDim.new(0,10); p.Parent = trSearchBox
    local s = Instance.new("UIStroke"); s.Color = C.border; s.Transparency = 0.7; s.Thickness = 1; s.Parent = trSearchBox
end

-- Player list
local trPlayerList = Instance.new("ScrollingFrame", trFrame)
trPlayerList.BackgroundColor3 = C.bg0; trPlayerList.BackgroundTransparency = 0.5
trPlayerList.BorderSizePixel = 0; trPlayerList.Position = UDim2.new(0,10,0,80)
trPlayerList.Size = UDim2.new(1,-20,0,80); trPlayerList.ZIndex = 33
trPlayerList.ScrollBarThickness = 3; trPlayerList.ScrollBarImageColor3 = C.accent
trPlayerList.ScrollBarImageTransparency = 0.5; trPlayerList.CanvasSize = UDim2.new(0,0,0,0)
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,6); c.Parent = trPlayerList end
local trListLayout = Instance.new("UIListLayout", trPlayerList)
trListLayout.Padding = UDim.new(0,3); trListLayout.SortOrder = Enum.SortOrder.LayoutOrder
trListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    trPlayerList.CanvasSize = UDim2.new(0,0,0,trListLayout.AbsoluteContentSize.Y+6)
end)

-- Limb selector label
local trLimbLbl = Instance.new("TextLabel", trFrame)
trLimbLbl.BackgroundTransparency = 1; trLimbLbl.Position = UDim2.new(0,10,0,166)
trLimbLbl.Size = UDim2.new(1,-20,0,14); trLimbLbl.Font = Enum.Font.Gotham
trLimbLbl.Text = "Limbs:"; trLimbLbl.TextColor3 = C.text3
trLimbLbl.TextSize = 9; trLimbLbl.TextXAlignment = Enum.TextXAlignment.Left; trLimbLbl.ZIndex = 33

-- Limb toggle buttons
local trLimbBtns = {}
local trLimbNames = {"L Arm", "R Arm", "Body", "L Leg", "R Leg", "Head"}
local trLimbKeys  = {"LeftArm", "RightArm", "Body", "LeftLeg", "RightLeg", "Head"}

for i, lbl in ipairs(trLimbNames) do
    local col = (i - 1) % 3
    local row = math.floor((i - 1) / 3)
    local btn = Instance.new("TextButton", trFrame)
    btn.Position = UDim2.new(0, 10 + col * 100, 0, 182 + row * 26)
    btn.Size = UDim2.new(0, 92, 0, 22)
    btn.BackgroundColor3 = C.bg2
    btn.BackgroundTransparency = 0.3
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.GothamBold
    btn.Text = lbl
    btn.TextColor3 = C.text2
    btn.TextSize = 8
    btn.ZIndex = 33
    btn.AutoButtonColor = false
    btn.Name = trLimbKeys[i]
    do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,4); c.Parent = btn end
    trLimbBtns[trLimbKeys[i]] = btn
end

-- Stretch toggle
local trStretchLbl = Instance.new("TextLabel", trFrame)
trStretchLbl.BackgroundTransparency = 1; trStretchLbl.Position = UDim2.new(0,10,0,240)
trStretchLbl.Size = UDim2.new(0,80,0,14); trStretchLbl.Font = Enum.Font.Gotham
trStretchLbl.Text = "Stretch:"; trStretchLbl.TextColor3 = C.text3
trStretchLbl.TextSize = 9; trStretchLbl.TextXAlignment = Enum.TextXAlignment.Left; trStretchLbl.ZIndex = 33

local trStretchBg = Instance.new("Frame", trFrame)
trStretchBg.Size = UDim2.new(0,44,0,22); trStretchBg.Position = UDim2.new(0,55,0,238)
trStretchBg.BackgroundColor3 = C.bg4; trStretchBg.BorderSizePixel = 0; trStretchBg.ZIndex = 33
local trsc = Instance.new("UICorner", trStretchBg); trsc.CornerRadius = UDim.new(0,11)
local trStretchKnob = Instance.new("Frame", trStretchBg)
trStretchKnob.Size = UDim2.new(0,16,0,16); trStretchKnob.Position = UDim2.new(0,3,0,3)
trStretchKnob.BackgroundColor3 = C.white; trStretchKnob.BorderSizePixel = 0; trStretchKnob.ZIndex = 34
local trsck = Instance.new("UICorner", trStretchKnob); trsck.CornerRadius = UDim.new(0,8)
local trStretchBtn = Instance.new("TextButton", trStretchBg)
trStretchBtn.Size = UDim2.new(1,0,1,0); trStretchBtn.BackgroundTransparency = 1; trStretchBtn.Text = ""; trStretchBtn.ZIndex = 35

-- Keybind
local trKeyLbl = Instance.new("TextLabel", trFrame)
trKeyLbl.BackgroundTransparency = 1; trKeyLbl.Position = UDim2.new(0,110,0,240)
trKeyLbl.Size = UDim2.new(0,40,0,14); trKeyLbl.Font = Enum.Font.Gotham
trKeyLbl.Text = "Key:"; trKeyLbl.TextColor3 = C.text3
trKeyLbl.TextSize = 9; trKeyLbl.TextXAlignment = Enum.TextXAlignment.Left; trKeyLbl.ZIndex = 33

local trKeyBtn = Instance.new("TextButton", trFrame)
trKeyBtn.Position = UDim2.new(0,140,0,238); trKeyBtn.Size = UDim2.new(0,70,0,22)
trKeyBtn.BackgroundColor3 = C.bg2; trKeyBtn.BackgroundTransparency = 0.2
trKeyBtn.BorderSizePixel = 0; trKeyBtn.Font = Enum.Font.GothamBold
trKeyBtn.Text = "Key: None"; trKeyBtn.TextColor3 = C.accent; trKeyBtn.TextSize = 10
trKeyBtn.ZIndex = 33; trKeyBtn.AutoButtonColor = false
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,5); c.Parent = trKeyBtn
    local s = Instance.new("UIStroke"); s.Color = C.border; s.Transparency = 0.7; s.Thickness = 1; s.Parent = trKeyBtn
end

-- Status
local trStatus = Instance.new("TextLabel", trFrame)
trStatus.BackgroundTransparency = 1; trStatus.Position = UDim2.new(0,10,0,268)
trStatus.Size = UDim2.new(1,-20,0,28); trStatus.Font = Enum.Font.Gotham
trStatus.Text = "OFF - Select a player and toggle ON"; trStatus.TextColor3 = C.text3
trStatus.TextSize = 9; trStatus.TextXAlignment = Enum.TextXAlignment.Left
trStatus.TextWrapped = true; trStatus.ZIndex = 33

-- Distance readout
local trDistLbl = Instance.new("TextLabel", trFrame)
trDistLbl.BackgroundTransparency = 1; trDistLbl.Position = UDim2.new(0,10,0,298)
trDistLbl.Size = UDim2.new(1,-20,0,14); trDistLbl.Font = Enum.Font.Gotham
trDistLbl.Text = "Distance: -- studs"; trDistLbl.TextColor3 = C.text2
trDistLbl.TextSize = 9; trDistLbl.TextXAlignment = Enum.TextXAlignment.Left; trDistLbl.ZIndex = 33

-- ============================================
-- PLAYER TRACKER LOGIC
-- ============================================
local trEnabled = false
local trSelectedPlayer = nil
local trEnabledLimbs = {LeftArm = false, RightArm = false, LeftLeg = false, RightLeg = false, Body = false, Head = false}
local trStretching = false
local trConn = nil

local LIMB_CONFIG = {
    LeftArm   = {upper = "LeftUpperArm", lower = "LeftLowerArm",  endPart = "LeftHand",  alts = {"Left Arm"}},
    RightArm  = {upper = "RightUpperArm",lower = "RightLowerArm", endPart = "RightHand", alts = {"Right Arm"}},
    LeftLeg   = {upper = "LeftUpperLeg", lower = "LeftLowerLeg",  endPart = "LeftFoot",  alts = {"Left Leg"}},
    RightLeg  = {upper = "RightUpperLeg",lower = "RightLowerLeg", endPart = "RightFoot", alts = {"Right Leg"}},
    Head      = {upper = "Head", mode = "face", alts = {"Neck"}},
    Body      = {upper = "UpperTorso", mode = "face", alts = {"Torso", "LowerTorso", "HumanoidRootPart"}},
}

local function trUpdatePlayerList(term)
    for _, c in ipairs(trPlayerList:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    term = (term or ""):lower()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= plr then
            local name = p.Name .. " (@" .. p.DisplayName .. ")"
            if term == "" or name:lower():find(term, 1, true) then
                local btn = Instance.new("TextButton"); btn.Parent = trPlayerList
                btn.BackgroundColor3 = C.bg2; btn.BackgroundTransparency = 0.5
                btn.BorderSizePixel = 0; btn.Size = UDim2.new(1,0,0,26); btn.ZIndex = 34
                btn.Font = Enum.Font.GothamMedium; btn.Text = name
                btn.TextColor3 = C.text2; btn.TextSize = 10
                btn.TextXAlignment = Enum.TextXAlignment.Left; btn.AutoButtonColor = false
                btn.TextTruncate = Enum.TextTruncate.AtEnd
                do
                    local c2 = Instance.new("UICorner"); c2.CornerRadius = UDim.new(0,5); c2.Parent = btn
                    local p2 = Instance.new("UIPadding"); p2.PaddingLeft = UDim.new(0,8); p2.Parent = btn
                end
                btn.MouseEnter:Connect(function()
                    TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundTransparency = 0.3}):Play()
                end)
                btn.MouseLeave:Connect(function()
                    TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundTransparency = 0.5}):Play()
                end)
                btn.MouseButton1Click:Connect(function()
                    trSelectedPlayer = p
                    trStatus.Text = "Selected: " .. p.Name
                    trStatus.TextColor3 = C.accent
                    for _, c2 in ipairs(trPlayerList:GetChildren()) do
                        if c2:IsA("TextButton") then
                            c2.BackgroundColor3 = (c2 == btn) and C.accent or C.bg2
                            c2.TextColor3 = (c2 == btn) and Color3.fromRGB(0,0,0) or C.text2
                        end
                    end
                    if trEnabled then
                        trStartTracking()
                    end
                end)
            end
        end
    end
end

trSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    trUpdatePlayerList(trSearchBox.Text)
end)
Players.PlayerAdded:Connect(function() task.wait(0.1); trUpdatePlayerList(trSearchBox.Text) end)
Players.PlayerRemoving:Connect(function() task.wait(0.1); trUpdatePlayerList(trSearchBox.Text) end)

-- Limb toggle wiring
for key, btn in pairs(trLimbBtns) do
    btn.MouseButton1Click:Connect(function()
        trEnabledLimbs[key] = not trEnabledLimbs[key]
        if trEnabledLimbs[key] then
            TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = C.accent, BackgroundTransparency = 0.1, TextColor3 = Color3.fromRGB(0,0,0)}):Play()
        else
            TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = C.bg2, BackgroundTransparency = 0.3, TextColor3 = C.text2}):Play()
        end
    end)
end

local function trUpdateStretch()
    if trStretching then
        TweenService:Create(trStretchBg, TweenInfo.new(0.2), {BackgroundColor3 = C.green}):Play()
        TweenService:Create(trStretchKnob, TweenInfo.new(0.2), {Position = UDim2.new(1,-19,0,3)}):Play()
    else
        TweenService:Create(trStretchBg, TweenInfo.new(0.2), {BackgroundColor3 = C.bg4}):Play()
        TweenService:Create(trStretchKnob, TweenInfo.new(0.2), {Position = UDim2.new(0,3,0,3)}):Play()
    end
end
trStretchBtn.MouseButton1Click:Connect(function()
    trStretching = not trStretching
    trUpdateStretch()
end)

local function trUpdateToggle()
    if trEnabled then
        TweenService:Create(trToggleBg, TweenInfo.new(0.2), {BackgroundColor3 = C.green}):Play()
        TweenService:Create(trKnob, TweenInfo.new(0.2), {Position = UDim2.new(1,-19,0,3)}):Play()
        if trSelectedPlayer then
            trStatus.Text = "TRACKING " .. trSelectedPlayer.Name
            trStatus.TextColor3 = C.green
            trStartTracking()
        else
            trStatus.Text = "ON - Select a player from the list above"
            trStatus.TextColor3 = C.yellow
        end
    else
        TweenService:Create(trToggleBg, TweenInfo.new(0.2), {BackgroundColor3 = C.bg4}):Play()
        TweenService:Create(trKnob, TweenInfo.new(0.2), {Position = UDim2.new(0,3,0,3)}):Play()
        trStatus.Text = "OFF - Select a player and toggle ON"
        trStatus.TextColor3 = C.text3
        trDistLbl.Text = "Distance: -- studs"
        _G._HaloTrackActive = false
        _G._HaloDoTrack = nil
        if trConn then trConn:Disconnect(); trConn = nil end
    end
end
trToggleBtn.MouseButton1Click:Connect(function()
    trEnabled = not trEnabled
    trUpdateToggle()
end)

local function pointLimbAtTarget(constraints, bindTransforms, bindLengths, upperName, lowerName, endName, targetPos, doStretch)
    local shoulderConstraint = constraints[upperName]
    if not shoulderConstraint then return end

    local shoulderWorldCF = nil;
    if shoulderConstraint:IsA("Motor6D") and shoulderConstraint.Part0 then
        shoulderWorldCF = shoulderConstraint.Part0.CFrame * shoulderConstraint.C0;
    else
        local att0 = shoulderConstraint.Attachment0
        if att0 and att0.Parent then
            shoulderWorldCF = att0.WorldCFrame
        end
    end
    if not shoulderWorldCF then return end

    local shoulderPos = shoulderWorldCF.Position
    local aimDir = (targetPos - shoulderPos)
    local dist = aimDir.Magnitude
    if dist <= 0.001 then return end
    aimDir = aimDir.Unit

    local bindTransform = bindTransforms[shoulderConstraint]
    if not bindTransform then return end

    local childBoneDir = Vector3.new(0, -1, 0)
    local bindBoneDir = (bindTransform.Rotation * childBoneDir).Unit
    local localAimDir = shoulderWorldCF.Rotation:Inverse() * aimDir

    local rotAxis = bindBoneDir:Cross(localAimDir)
    local shoulderResult
    if rotAxis.Magnitude > 0.001 then
        rotAxis = rotAxis.Unit
        local angle = math.acos(math.clamp(bindBoneDir:Dot(localAimDir), -1, 1))
        local rotationCF = CFrame.fromAxisAngle(rotAxis, angle)
        shoulderResult = rotationCF * bindTransform
    elseif bindBoneDir:Dot(localAimDir) < 0 then
        local perp = bindBoneDir:Cross(Vector3.new(0, 1, 0))
        if perp.Magnitude < 0.001 then
            perp = bindBoneDir:Cross(Vector3.new(1, 0, 0))
        end
        shoulderResult = CFrame.fromAxisAngle(perp.Unit, math.pi) * bindTransform
    else
        shoulderResult = bindTransform
    end
    shoulderConstraint.Transform = shoulderResult

    if lowerName then
        local elbowConstraint = constraints[lowerName]
        if elbowConstraint then
            elbowConstraint.Transform = CFrame.new()
        end
    end
    if endName then
        local wristConstraint = constraints[endName]
        if wristConstraint then
            wristConstraint.Transform = CFrame.new()
        end
    end

    if doStretch and lowerName then
        local c = constraints[lowerName]
        local bind = c and bindTransforms[c]
        if bind then
            -- Helper: get bind length with part-size fallback
            local function getBindLen(constraint)
                local len = bindLengths and bindLengths[constraint]
                if len and len > 0.001 then return len end
                if constraint:IsA("Motor6D") and constraint.Part1 and constraint.Part1:IsA("BasePart") then
                    return constraint.Part1.Size.Y
                end
                local a1 = constraint and constraint.Attachment1
                local part = a1 and a1.Parent
                if part and part:IsA("BasePart") then
                    return part.Size.Y
                end
                return 1.2
            end

            local upperLen = getBindLen(shoulderConstraint)
            local lowerLen = getBindLen(c)
            local endLen = 0
            if endName then
                local endC = constraints[endName]
                endLen = getBindLen(endC)
            end

            local desiredLowerLen = math.max(dist - upperLen - endLen, lowerLen * 0.5)
            local stretchMult = desiredLowerLen / lowerLen
            -- Use tracker-specific max stretch (default 15x)
            local maxStretch = _G._HaloTrackerStretchMax or 15.0
            stretchMult = math.clamp(stretchMult, 1.0, maxStretch)

            local boneDir = (bind.Rotation * Vector3.new(0, -1, 0)).Unit
            local stretchOffset = boneDir * lowerLen * (stretchMult - 1.0)
            c.Transform = CFrame.new(stretchOffset) * bind.Rotation
        end
    end

    return dist
end

local function trStartTracking()
    if trConn then trConn:Disconnect(); trConn = nil end

    local clone = ReanimateAPI and ReanimateAPI.get_clone and ReanimateAPI.get_clone(plr)
    if not clone then
        trStatus.Text = "Clone not found — reanimate first!"
        trStatus.TextColor3 = C.red
        return
    end

    -- Build a self-contained constraint cache directly from the clone.
    -- The tracker does NOT depend on the animation system being active.
    local trConstraints = {}
    local trBindTransforms = {}
    local trBindLengths = {}
    local foundCount = 0

    for _, descendant in ipairs(clone:GetDescendants()) do
        if descendant:IsA("AnimationConstraint") then
            local attachment = descendant.Attachment1
            if attachment and attachment.Parent then
                local partName = attachment.Parent.Name
                trConstraints[partName] = descendant
                trBindTransforms[descendant] = descendant.Transform
                foundCount = foundCount + 1

                local att0 = descendant.Attachment0
                local att1 = descendant.Attachment1
                if att0 and att1 and att0.Parent and att1.Parent then
                    local len = (att1.WorldCFrame.Position - att0.WorldCFrame.Position).Magnitude
                    if len > 0.001 then
                        trBindLengths[descendant] = len
                    end
                end
            end
        elseif descendant:IsA("Motor6D") and descendant.Part1 then
            local partName = descendant.Part1.Name
            if not trConstraints[partName] then
                trConstraints[partName] = descendant
                trBindTransforms[descendant] = CFrame.new()
                trBindLengths[descendant] = descendant.Part1.Size.Y
                foundCount = foundCount + 1
            end
        end
    end

    if foundCount == 0 then
        trStatus.Text = "No AnimationConstraints found on clone!"
        trStatus.TextColor3 = C.red
        return
    end

    trStatus.Text = "READY — " .. foundCount .. " constraints cached"
    trStatus.TextColor3 = C.green

    local function faceConstraint(constraint, targetPos)
        if not constraint then return end
        local base = nil
        if constraint:IsA("Motor6D") and constraint.Part0 then
            base = constraint.Part0.CFrame * constraint.C0
        else
            local att0 = constraint.Attachment0
            if att0 and att0.Parent then base = att0.WorldCFrame end
        end
        if not base then return end
        local aim = targetPos - base.Position
        if aim.Magnitude < 0.05 then return end
        local localAim = base.Rotation:Inverse() * aim.Unit
        local yaw = math.clamp(math.atan2(localAim.X, -localAim.Z), -2.2, 2.2)
        local pitch = math.clamp(math.asin(math.clamp(localAim.Y, -1, 1)) * 0.45, -0.7, 0.9)
        constraint.Transform = CFrame.Angles(pitch, yaw, 0)
    end

    local function resolveConstraint(cfg)
        local c = trConstraints[cfg.upper]
        if c then return c end
        if cfg.alts then
            for _, name in ipairs(cfg.alts) do
                c = trConstraints[name]
                if c then return c end
            end
        end
    end

    _G._HaloTrackActive = true
    _G._HaloDoTrack = function()
        if not trEnabled or not trSelectedPlayer then return end
        local targetChar = trSelectedPlayer.Character
        if not targetChar then return end
        local targetHRP = targetChar:FindFirstChild("HumanoidRootPart")
        if not targetHRP then return end
        local targetPos = targetHRP.Position
        local activeDist = nil
        for limbKey, enabled in pairs(trEnabledLimbs) do
            if enabled then
                local cfg = LIMB_CONFIG[limbKey]
                if cfg then
                    if cfg.mode == "face" then
                        faceConstraint(resolveConstraint(cfg), targetPos)
                        activeDist = (targetPos - (clone:GetPivot().Position)).Magnitude
                    else
                        local c = resolveConstraint(cfg)
                        if c then trConstraints[cfg.upper] = c end
                        local d = pointLimbAtTarget(trConstraints, trBindTransforms, trBindLengths, cfg.upper, cfg.lower, cfg.endPart, targetPos, trStretching)
                        if d then activeDist = d end
                    end
                end
            end
        end
        if activeDist then
            trDistLbl.Text = "Distance: " .. string.format("%.1f", activeDist) .. " studs"
        end
    end
end

local function trStopTracking()
    if trConn then trConn:Disconnect(); trConn = nil end
    trDistLbl.Text = "Distance: -- studs"
end

-- Refresh player list on startup
trUpdatePlayerList("")

-- Tracker keybind button wiring
local settingTrKey = false
trKeyBtn.MouseButton1Click:Connect(function()
    if settingTrKey then return end
    if _G._HaloTrackerKey then
        _G._HaloTrackerKey = nil
        pcall(function()
            local deleteFunc = delfile or delete_file or (function(p) pcall(writefile, p, "") end)
            deleteFunc(fpath("ReanimTrackerKey.txt"))
        end)
        trKeyBtn.Text = "Key: None"
        return
    end
    settingTrKey = true
    trKeyBtn.Text = "Listening..."
    trKeyBtn.BackgroundColor3 = C.yellow
    local keyConn
    keyConn = UserInputService.InputBegan:Connect(LPH_NO_VIRTUALIZE(function(i, gp)
        if gp then return end
        keyConn:Disconnect()
        settingTrKey = false
        trKeyBtn.BackgroundColor3 = C.bg2
        if i.KeyCode == Enum.KeyCode.Escape then
            trKeyBtn.Text = "Key: None"
            return
        end
        _G._HaloTrackerKey = i.KeyCode
        pcall(function() writefile(fpath("ReanimTrackerKey.txt"), i.KeyCode.Name) end)
        trKeyBtn.Text = "Key: " .. i.KeyCode.Name
    end))
end)
-- ============================================
-- ANIMATION COPIER (Testing Tab)
-- ============================================

local animCopierFrame = Instance.new("Frame"); animCopierFrame.Parent = TestingPanel
animCopierFrame.Size = UDim2.new(1,0,0,280)
animCopierFrame.BackgroundColor3 = C.bg1
animCopierFrame.BackgroundTransparency = 0.4
animCopierFrame.BorderSizePixel = 0
animCopierFrame.LayoutOrder = 6
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,7); c.Parent = animCopierFrame
    local s = Instance.new("UIStroke"); s.Color = C.border; s.Transparency = 0.7; s.Thickness = 1; s.Parent = animCopierFrame
end

local acLbl = Instance.new("TextLabel", animCopierFrame)
acLbl.BackgroundTransparency = 1; acLbl.Position = UDim2.new(0,10,0,6)
acLbl.Size = UDim2.new(1,-120,0,16); acLbl.Font = Enum.Font.GothamBold
acLbl.Text = "Animation Copier"; acLbl.TextColor3 = C.accent; acLbl.TextSize = 11
acLbl.TextXAlignment = Enum.TextXAlignment.Left; acLbl.ZIndex = 33

local acSub = Instance.new("TextLabel", animCopierFrame)
acSub.BackgroundTransparency = 1; acSub.Position = UDim2.new(0,10,0,22)
acSub.Size = UDim2.new(1,-120,0,24); acSub.Font = Enum.Font.Gotham
acSub.Text = "Mirror target player\'s exact pose & position"; acSub.TextColor3 = C.text3
acSub.TextSize = 9; acSub.TextXAlignment = Enum.TextXAlignment.Left; acSub.TextWrapped = true; acSub.ZIndex = 33

local acToggleBg = Instance.new("Frame", animCopierFrame)
acToggleBg.Size = UDim2.new(0,44,0,22); acToggleBg.Position = UDim2.new(1,-54,0,12)
acToggleBg.BackgroundColor3 = C.bg4; acToggleBg.BorderSizePixel = 0; acToggleBg.ZIndex = 33
local acc = Instance.new("UICorner", acToggleBg); acc.CornerRadius = UDim.new(0,11)
local acKnob = Instance.new("Frame", acToggleBg)
acKnob.Size = UDim2.new(0,16,0,16); acKnob.Position = UDim2.new(0,3,0,3)
acKnob.BackgroundColor3 = C.white; acKnob.BorderSizePixel = 0; acKnob.ZIndex = 34
local acck = Instance.new("UICorner", acKnob); acck.CornerRadius = UDim.new(0,8)
local acToggleBtn = Instance.new("TextButton", acToggleBg)
acToggleBtn.Size = UDim2.new(1,0,1,0); acToggleBtn.BackgroundTransparency = 1; acToggleBtn.Text = ""; acToggleBtn.ZIndex = 35

-- Search box
local acSearchBox = Instance.new("TextBox", animCopierFrame)
acSearchBox.BackgroundColor3 = C.bg2; acSearchBox.BackgroundTransparency = 0.3
acSearchBox.BorderSizePixel = 0; acSearchBox.Position = UDim2.new(0,10,0,50)
acSearchBox.Size = UDim2.new(1,-20,0,26); acSearchBox.ZIndex = 33
acSearchBox.Font = Enum.Font.GothamMedium; acSearchBox.PlaceholderText = "Search player..."
acSearchBox.PlaceholderColor3 = C.text3; acSearchBox.Text = ""
acSearchBox.TextColor3 = C.text; acSearchBox.TextSize = 11
acSearchBox.ClearTextOnFocus = false
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,6); c.Parent = acSearchBox
    local p = Instance.new("UIPadding"); p.PaddingLeft = UDim.new(0,10); p.Parent = acSearchBox
    local s = Instance.new("UIStroke"); s.Color = C.border; s.Transparency = 0.7; s.Thickness = 1; s.Parent = acSearchBox
end

-- Player list
local acPlayerList = Instance.new("ScrollingFrame", animCopierFrame)
acPlayerList.BackgroundColor3 = C.bg0; acPlayerList.BackgroundTransparency = 0.5
acPlayerList.BorderSizePixel = 0; acPlayerList.Position = UDim2.new(0,10,0,80)
acPlayerList.Size = UDim2.new(1,-20,0,80); acPlayerList.ZIndex = 33
acPlayerList.ScrollBarThickness = 3; acPlayerList.ScrollBarImageColor3 = C.accent
acPlayerList.ScrollBarImageTransparency = 0.5; acPlayerList.CanvasSize = UDim2.new(0,0,0,0)
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,6); c.Parent = acPlayerList end
local acListLayout = Instance.new("UIListLayout", acPlayerList)
acListLayout.Padding = UDim.new(0,3); acListLayout.SortOrder = Enum.SortOrder.LayoutOrder
acListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    acPlayerList.CanvasSize = UDim2.new(0,0,0,acListLayout.AbsoluteContentSize.Y+6)
end)

-- Distance slider
local acDistLbl = Instance.new("TextLabel", animCopierFrame)
acDistLbl.BackgroundTransparency = 1; acDistLbl.Position = UDim2.new(0,10,0,166)
acDistLbl.Size = UDim2.new(0,180,0,16); acDistLbl.Font = Enum.Font.GothamBold
acDistLbl.Text = "Distance: 2.0 studs"; acDistLbl.TextColor3 = C.text2
acDistLbl.TextSize = 9; acDistLbl.TextXAlignment = Enum.TextXAlignment.Left; acDistLbl.ZIndex = 33

local acDistTrack = Instance.new("Frame", animCopierFrame)
acDistTrack.BackgroundColor3 = C.bg2; acDistTrack.BackgroundTransparency = 0.3
acDistTrack.BorderSizePixel = 0; acDistTrack.Position = UDim2.new(0,10,0,184)
acDistTrack.Size = UDim2.new(1,-20,0,8); acDistTrack.ZIndex = 33
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1,0); c.Parent = acDistTrack
    local s = Instance.new("UIStroke"); s.Color = C.border; s.Transparency = 0.7; s.Thickness = 1; s.Parent = acDistTrack
end

local acDistFill = Instance.new("Frame", acDistTrack)
acDistFill.BackgroundColor3 = C.accent; acDistFill.BackgroundTransparency = 0.1
acDistFill.BorderSizePixel = 0; acDistFill.Size = UDim2.new(0.345,0,1,0)
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1,0); c.Parent = acDistFill end

local acDistHandle = Instance.new("Frame", acDistTrack)
acDistHandle.AnchorPoint = Vector2.new(0.5,0.5)
acDistHandle.BackgroundColor3 = C.accent; acDistHandle.BackgroundTransparency = 0
acDistHandle.BorderSizePixel = 0; acDistHandle.Position = UDim2.new(0.345,0,0.5,0)
acDistHandle.Size = UDim2.new(0,12,0,12)
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1,0); c.Parent = acDistHandle
    local s = Instance.new("UIStroke"); s.Color = C.border; s.Transparency = 0.4; s.Thickness = 1; s.Parent = acDistHandle
end

-- Side selector
local acSideLbl = Instance.new("TextLabel", animCopierFrame)
acSideLbl.BackgroundTransparency = 1; acSideLbl.Position = UDim2.new(0,10,0,200)
acSideLbl.Size = UDim2.new(0,40,0,14); acSideLbl.Font = Enum.Font.Gotham
acSideLbl.Text = "Side:"; acSideLbl.TextColor3 = C.text3
acSideLbl.TextSize = 9; acSideLbl.TextXAlignment = Enum.TextXAlignment.Left; acSideLbl.ZIndex = 33

local acSideLeft = Instance.new("TextButton", animCopierFrame)
acSideLeft.Position = UDim2.new(0,45,0,200); acSideLeft.Size = UDim2.new(0,40,0,16)
acSideLeft.BackgroundColor3 = C.accent; acSideLeft.BackgroundTransparency = 0.1
acSideLeft.BorderSizePixel = 0; acSideLeft.Font = Enum.Font.GothamBold
acSideLeft.Text = "Left"; acSideLeft.TextColor3 = Color3.fromRGB(0,0,0)
acSideLeft.TextSize = 8; acSideLeft.ZIndex = 33; acSideLeft.AutoButtonColor = false
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,4); c.Parent = acSideLeft end

local acSideRight = Instance.new("TextButton", animCopierFrame)
acSideRight.Position = UDim2.new(0,89,0,200); acSideRight.Size = UDim2.new(0,40,0,16)
acSideRight.BackgroundColor3 = C.bg2; acSideRight.BackgroundTransparency = 0.3
acSideRight.BorderSizePixel = 0; acSideRight.Font = Enum.Font.GothamBold
acSideRight.Text = "Right"; acSideRight.TextColor3 = C.text2
acSideRight.TextSize = 8; acSideRight.ZIndex = 33; acSideRight.AutoButtonColor = false
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,4); c.Parent = acSideRight end

-- Status label
local acStatus = Instance.new("TextLabel", animCopierFrame)
acStatus.BackgroundTransparency = 1; acStatus.Position = UDim2.new(0,10,0,222)
acStatus.Size = UDim2.new(1,-20,0,28); acStatus.Font = Enum.Font.Gotham
acStatus.Text = "OFF - Select a player and toggle ON"; acStatus.TextColor3 = C.text3
acStatus.TextSize = 9; acStatus.TextXAlignment = Enum.TextXAlignment.Left
acStatus.TextWrapped = true; acStatus.ZIndex = 33

local acNoclipLbl = Instance.new("TextLabel", animCopierFrame)
acNoclipLbl.BackgroundTransparency = 1; acNoclipLbl.Position = UDim2.new(0,10,0,252)
acNoclipLbl.Size = UDim2.new(1,-20,0,14); acNoclipLbl.Font = Enum.Font.Gotham
acNoclipLbl.Text = "Noclip: Auto-enabled when copying"; acNoclipLbl.TextColor3 = C.green
acNoclipLbl.TextSize = 9; acNoclipLbl.TextXAlignment = Enum.TextXAlignment.Left; acNoclipLbl.ZIndex = 33

-- ============================================
-- ANIMATION COPIER LOGIC
-- ============================================
local acEnabled = false
local acSelectedPlayer = nil
local acDistance = 2.0
local acSide = 1
local acConn = nil
local acDragging = false
local acSavedStates = {}

local function acUpdatePlayerList(term)
    for _, c in ipairs(acPlayerList:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    term = (term or ""):lower()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= plr then
            local name = p.Name .. " (@" .. p.DisplayName .. ")"
            if term == "" or name:lower():find(term, 1, true) then
                local btn = Instance.new("TextButton"); btn.Parent = acPlayerList
                btn.BackgroundColor3 = C.bg2; btn.BackgroundTransparency = 0.5
                btn.BorderSizePixel = 0; btn.Size = UDim2.new(1,0,0,26); btn.ZIndex = 34
                btn.Font = Enum.Font.GothamMedium; btn.Text = name
                btn.TextColor3 = C.text2; btn.TextSize = 10
                btn.TextXAlignment = Enum.TextXAlignment.Left; btn.AutoButtonColor = false
                btn.TextTruncate = Enum.TextTruncate.AtEnd
                do
                    local c2 = Instance.new("UICorner"); c2.CornerRadius = UDim.new(0,5); c2.Parent = btn
                    local p2 = Instance.new("UIPadding"); p2.PaddingLeft = UDim.new(0,8); p2.Parent = btn
                end
                btn.MouseEnter:Connect(function()
                    TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundTransparency = 0.3}):Play()
                end)
                btn.MouseLeave:Connect(function()
                    TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundTransparency = 0.5}):Play()
                end)
                btn.MouseButton1Click:Connect(function()
                    acSelectedPlayer = p
                    acStatus.Text = "Selected: " .. p.Name .. " | Dist: " .. string.format("%.1f", acDistance) .. " studs"
                    acStatus.TextColor3 = C.accent
                    for _, c2 in ipairs(acPlayerList:GetChildren()) do
                        if c2:IsA("TextButton") then
                            c2.BackgroundColor3 = (c2 == btn) and C.accent or C.bg2
                            c2.TextColor3 = (c2 == btn) and Color3.fromRGB(0,0,0) or C.text2
                        end
                    end
                    if acEnabled then
                        acStatus.Text = "COPYING " .. p.Name .. " | Dist: " .. string.format("%.1f", acDistance) .. " studs"
                        acStatus.TextColor3 = C.green
                    end
                end)
            end
        end
    end
end

local function acSetDistance(val)
    acDistance = math.clamp(math.floor(val * 10 + 0.5) / 10, 0.1, 6.0)
    local pct = (acDistance - 0.1) / 5.9
    acDistFill.Size = UDim2.new(pct, 0, 1, 0)
    acDistHandle.Position = UDim2.new(pct, 0, 0.5, 0)
    acDistLbl.Text = "Distance: " .. string.format("%.1f", acDistance) .. " studs"
    if acEnabled and acSelectedPlayer then
        acStatus.Text = "COPYING " .. acSelectedPlayer.Name .. " | Dist: " .. string.format("%.1f", acDistance) .. " studs"
    end
end
acSetDistance(2.0)

acSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    acUpdatePlayerList(acSearchBox.Text)
end)
Players.PlayerAdded:Connect(function() task.wait(0.1); acUpdatePlayerList(acSearchBox.Text) end)
Players.PlayerRemoving:Connect(function() task.wait(0.1); acUpdatePlayerList(acSearchBox.Text) end)

acDistTrack.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
        acDragging = true
        local pct = math.clamp((inp.Position.X - acDistTrack.AbsolutePosition.X) / acDistTrack.AbsoluteSize.X, 0, 1)
        acSetDistance(0.1 + pct * 5.9)
    end
end)
UserInputService.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 and acDragging then acDragging = false end
end)
UserInputService.InputChanged:Connect(function(inp)
    if acDragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
        local pct = math.clamp((inp.Position.X - acDistTrack.AbsolutePosition.X) / acDistTrack.AbsoluteSize.X, 0, 1)
        acSetDistance(0.1 + pct * 5.9)
    end
end)

acSideLeft.MouseButton1Click:Connect(function()
    acSide = -1
    acSideLeft.BackgroundColor3 = C.accent; acSideLeft.TextColor3 = Color3.fromRGB(0,0,0)
    acSideRight.BackgroundColor3 = C.bg2; acSideRight.TextColor3 = C.text2
end)
acSideRight.MouseButton1Click:Connect(function()
    acSide = 1
    acSideRight.BackgroundColor3 = C.accent; acSideRight.TextColor3 = Color3.fromRGB(0,0,0)
    acSideLeft.BackgroundColor3 = C.bg2; acSideLeft.TextColor3 = C.text2
end)

local function acFreezeClone(clone)
    if not clone then return end
    acSavedStates = {}
    for _, part in ipairs(clone:GetDescendants()) do
        if part:IsA("BasePart") then
            local isAccessory = part:FindFirstAncestorOfClass("Accessory") ~= nil
            if isAccessory then
                -- Hair / accessories: keep welds active, don't anchor.
                -- They'll follow their parent body part naturally.
                acSavedStates[part] = {
                    CanCollide = part.CanCollide,
                    CanQuery = part.CanQuery,
                }
                part.CanCollide = false
                part.CanQuery = false
            else
                -- Body parts: anchor and disable physics so CFrame copy works cleanly
                acSavedStates[part] = {
                    Anchored = part.Anchored,
                    CanCollide = part.CanCollide,
                    CanQuery = part.CanQuery,
                }
                part.Anchored = true
                part.CanCollide = false
                part.CanQuery = false
            end
        end
    end
    local hum = clone:FindFirstChildOfClass("Humanoid")
    if hum then
        acSavedStates.Humanoid = {
            WalkSpeed = hum.WalkSpeed,
            JumpPower = hum.JumpPower,
            AutoRotate = hum.AutoRotate,
        }
        hum.WalkSpeed = 0
        hum.JumpPower = 0
        hum.AutoRotate = false
        local animator = hum:FindFirstChildOfClass("Animator")
        if animator then
            for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                pcall(function() track:Stop(0) end)
            end
        end
    end
    local animate = clone:FindFirstChild("Animate")
    if animate then
        acSavedStates.Animate = { Enabled = animate.Enabled }
        animate.Enabled = false
    end
    pcall(function() ReanimateAPI.stop_animation() end)
end

local function acUnfreezeClone(clone)
    if not clone then return end
    for part, state in pairs(acSavedStates) do
        if typeof(part) == "Instance" and part.Parent then
            if part:IsA("BasePart") then
                if state.Anchored ~= nil then
                    pcall(function() part.Anchored = state.Anchored end)
                end
                pcall(function() part.CanCollide = state.CanCollide end)
                pcall(function() part.CanQuery = state.CanQuery end)
            end
        end
    end
    local hum = clone:FindFirstChildOfClass("Humanoid")
    if hum and acSavedStates.Humanoid then
        pcall(function() hum.WalkSpeed = acSavedStates.Humanoid.WalkSpeed end)
        pcall(function() hum.JumpPower = acSavedStates.Humanoid.JumpPower end)
        pcall(function() hum.AutoRotate = acSavedStates.Humanoid.AutoRotate end)
    end
    local animate = clone:FindFirstChild("Animate")
    if animate and acSavedStates.Animate then
        pcall(function() animate.Enabled = acSavedStates.Animate.Enabled end)
    end
    acSavedStates = {}
end

local function acStartCopying()
    if acConn then acConn:Disconnect(); acConn = nil end

    local clone = ReanimateAPI and ReanimateAPI.get_clone and ReanimateAPI.get_clone(plr)
    acFreezeClone(clone)

    -- Pre-build body-part map only. Accessories (hair, hats, etc.) stay welded
    -- to their parent parts and move naturally — no snapping, no detaching.
    local clonePartMap = {}
    if clone then
        for _, part in ipairs(clone:GetDescendants()) do
            if part:IsA("BasePart") and not part:FindFirstAncestorOfClass("Accessory") then
                clonePartMap[part.Name] = part
            end
        end
    end

    -- TRUE ZERO DELAY: Stepped fires AFTER physics (fresh target CFrame) but BEFORE render.
    -- This reads the target's latest simulated position and mirrors it same-frame.
    acConn = RunService.Stepped:Connect(function()
        if not acEnabled then return end
        if not acSelectedPlayer then return end

        -- Auto-enable reanim if needed
        if not State.isReanimated then
            pcall(function() _G._HaloDoReanimToggle() end)
            return
        end

        local targetChar = acSelectedPlayer.Character
        clone = ReanimateAPI and ReanimateAPI.get_clone and ReanimateAPI.get_clone(plr)
        if not targetChar or not clone then
            acStatus.Text = "Target or clone missing..."
            acStatus.TextColor3 = C.yellow
            return
        end

        local targetHRP = targetChar:FindFirstChild("HumanoidRootPart")
        if not targetHRP then
            acStatus.Text = "Target has no HRP..."
            acStatus.TextColor3 = C.yellow
            return
        end

        -- Compute world-space offset from target's right vector
        local rightVec = targetHRP.CFrame.RightVector
        if rightVec.Magnitude > 0.001 then rightVec = rightVec.Unit end
        local offsetVec = rightVec * (acDistance * acSide)

        -- Copy body-part CFrames only. Accessories stay welded and follow their parent naturally.
        -- Dynamic fallback: if a part isn't in the pre-built map, look it up directly.
        for _, targetPart in ipairs(targetChar:GetDescendants()) do
            if targetPart:IsA("BasePart") and not targetPart:FindFirstAncestorOfClass("Accessory") then
                local clonePart = clonePartMap[targetPart.Name]
                if not clonePart or not clonePart.Parent then
                    clonePart = clone:FindFirstChild(targetPart.Name)
                    if clonePart and clonePart:IsA("BasePart") then
                        clonePartMap[targetPart.Name] = clonePart
                    end
                end
                if clonePart and clonePart.Parent then
                    clonePart.CFrame = targetPart.CFrame + offsetVec
                end
            end
        end
    end)
end

local function acStopCopying()
    if acConn then acConn:Disconnect(); acConn = nil end
    local clone = ReanimateAPI and ReanimateAPI.get_clone and ReanimateAPI.get_clone(plr)
    acUnfreezeClone(clone)
    acStatus.Text = "OFF - Select a player and toggle ON"
    acStatus.TextColor3 = C.text3
end

local function acUpdateToggle()
    if acEnabled then
        TweenService:Create(acToggleBg, TweenInfo.new(0.2), {BackgroundColor3 = C.green}):Play()
        TweenService:Create(acKnob, TweenInfo.new(0.2), {Position = UDim2.new(1,-19,0,3)}):Play()
        if acSelectedPlayer then
            acStatus.Text = "COPYING " .. acSelectedPlayer.Name .. " | Dist: " .. string.format("%.1f", acDistance) .. " studs"
            acStatus.TextColor3 = C.green
            acStartCopying()
        else
            acStatus.Text = "ON - Select a player from the list above"
            acStatus.TextColor3 = C.yellow
        end
    else
        TweenService:Create(acToggleBg, TweenInfo.new(0.2), {BackgroundColor3 = C.bg4}):Play()
        TweenService:Create(acKnob, TweenInfo.new(0.2), {Position = UDim2.new(0,3,0,3)}):Play()
        acStopCopying()
    end
    _G._HaloAnimCopierActive = acEnabled
end

acToggleBtn.MouseButton1Click:Connect(function()
    acEnabled = not acEnabled
    acUpdateToggle()
end)

-- Refresh player list on startup
acUpdatePlayerList("")

StatesPanel.Parent = body
StatesPanel.Size = UDim2.new(1,-20,1,-148)
StatesPanel.Position = UDim2.new(0,10,0,104)
StatesPanel.BackgroundTransparency = 1; StatesPanel.BorderSizePixel = 0
StatesPanel.ZIndex = 32

-- States header label inside the StatesPanel
local statesHeader = Instance.new("TextLabel"); statesHeader.Parent = StatesPanel
statesHeader.BackgroundTransparency = 1; statesHeader.Size = UDim2.new(1,0,0,18)
statesHeader.Font = Enum.Font.GothamBold; statesHeader.TextSize = 11
statesHeader.Text = "State Animations"; statesHeader.TextColor3 = C.text
statesHeader.TextXAlignment = Enum.TextXAlignment.Left; statesHeader.ZIndex = 35

-- 1. Import from AK Frame
local akFrame = Instance.new("Frame", SettingsPanel)
akFrame.Size = UDim2.new(1,0,0,54)
akFrame.BackgroundColor3 = C.bg1; akFrame.BackgroundTransparency = 0.4; akFrame.BorderSizePixel = 0
akFrame.LayoutOrder = 1
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,7); c.Parent = akFrame
    local s = Instance.new("UIStroke"); s.Color = C.border; s.Transparency = 0.7; s.Thickness = 1; s.Parent = akFrame
end

local akLbl = Instance.new("TextLabel", akFrame)
akLbl.BackgroundTransparency = 1; akLbl.Position = UDim2.new(0,10,0,6)
akLbl.Size = UDim2.new(1,-120,0,16); akLbl.Font = Enum.Font.GothamBold
akLbl.Text = "Import Animations"; akLbl.TextColor3 = C.text; akLbl.TextSize = 11
akLbl.TextXAlignment = Enum.TextXAlignment.Left

local akSub = Instance.new("TextLabel", akFrame)
akSub.BackgroundTransparency = 1; akSub.Position = UDim2.new(0,10,0,24)
akSub.Size = UDim2.new(1,-120,0,24); akSub.Font = Enum.Font.Gotham
akSub.Text = "Import custom animations from AK config files"; akSub.TextColor3 = C.text3; akSub.TextSize = 9
akSub.TextXAlignment = Enum.TextXAlignment.Left; akSub.TextWrapped = true

local akBtn = Instance.new("TextButton", akFrame)
akBtn.Size = UDim2.new(0,96,0,24); akBtn.Position = UDim2.new(1,-102,0.5,-12)
akBtn.BackgroundColor3 = C.bg2; akBtn.BackgroundTransparency = 0.2; akBtn.BorderSizePixel = 0
akBtn.Font = Enum.Font.GothamBold; akBtn.Text = "Import"; akBtn.TextColor3 = C.accent; akBtn.TextSize = 10
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,5); c.Parent = akBtn
    local s = Instance.new("UIStroke"); s.Color = C.border; s.Transparency = 0.7; s.Thickness = 1; s.Parent = akBtn
end

-- 2. Fortnite Emote Wheel Keybind Frame
local fnWheelFrame = Instance.new("Frame", SettingsPanel)
fnWheelFrame.Size = UDim2.new(1,0,0,54)
fnWheelFrame.BackgroundColor3 = C.bg1; fnWheelFrame.BackgroundTransparency = 0.4; fnWheelFrame.BorderSizePixel = 0
fnWheelFrame.LayoutOrder = 2
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,7); c.Parent = fnWheelFrame
    local s = Instance.new("UIStroke"); s.Color = C.border; s.Transparency = 0.7; s.Thickness = 1; s.Parent = fnWheelFrame
end

local fnLbl = Instance.new("TextLabel", fnWheelFrame)
fnLbl.BackgroundTransparency = 1; fnLbl.Position = UDim2.new(0,10,0,6)
fnLbl.Size = UDim2.new(1,-120,0,16); fnLbl.Font = Enum.Font.GothamBold
fnLbl.Text = "Fortnite Emote Wheel"; fnLbl.TextColor3 = C.text; fnLbl.TextSize = 11
fnLbl.TextXAlignment = Enum.TextXAlignment.Left

local fnSub = Instance.new("TextLabel", fnWheelFrame)
fnSub.BackgroundTransparency = 1; fnSub.Position = UDim2.new(0,10,0,24)
fnSub.Size = UDim2.new(1,-120,0,24); fnSub.Font = Enum.Font.Gotham
fnSub.Text = "Hold bound key in-game to open Fortnite Wheel"; fnSub.TextColor3 = C.text3; fnSub.TextSize = 9
fnSub.TextXAlignment = Enum.TextXAlignment.Left; fnSub.TextWrapped = true

local fnWheelBtn = Instance.new("TextButton", fnWheelFrame)
fnWheelBtn.Size = UDim2.new(0,96,0,24); fnWheelBtn.Position = UDim2.new(1,-102,0.5,-12)
fnWheelBtn.BackgroundColor3 = C.bg2; fnWheelBtn.BackgroundTransparency = 0.2; fnWheelBtn.BorderSizePixel = 0
fnWheelBtn.Font = Enum.Font.GothamBold; fnWheelBtn.Text = "Key: None"; fnWheelBtn.TextColor3 = C.accent; fnWheelBtn.TextSize = 10
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,5); c.Parent = fnWheelBtn
    local s = Instance.new("UIStroke"); s.Color = C.border; s.Transparency = 0.7; s.Thickness = 1; s.Parent = fnWheelBtn
end

-- 3. Reverse Animation Frame
local revFrame = Instance.new("Frame", SettingsPanel)
revFrame.Size = UDim2.new(1,0,0,90)
revFrame.BackgroundColor3 = C.bg1; revFrame.BackgroundTransparency = 0.4; revFrame.BorderSizePixel = 0
revFrame.LayoutOrder = 3
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,7); c.Parent = revFrame
    local s = Instance.new("UIStroke"); s.Color = C.border; s.Transparency = 0.7; s.Thickness = 1; s.Parent = revFrame
end

local revLbl = Instance.new("TextLabel", revFrame)
revLbl.BackgroundTransparency = 1; revLbl.Position = UDim2.new(0,10,0,6)
revLbl.Size = UDim2.new(1,-120,0,16); revLbl.Font = Enum.Font.GothamBold
revLbl.Text = "Hold to Reverse Animation"; revLbl.TextColor3 = C.text; revLbl.TextSize = 11
revLbl.TextXAlignment = Enum.TextXAlignment.Left

local revSub = Instance.new("TextLabel", revFrame)
revSub.BackgroundTransparency = 1; revSub.Position = UDim2.new(0,10,0,24)
revSub.Size = UDim2.new(1,-120,0,24); revSub.Font = Enum.Font.Gotham
revSub.Text = "Hold key to reverse play direction"; revSub.TextColor3 = C.text3; revSub.TextSize = 9
revSub.TextXAlignment = Enum.TextXAlignment.Left; revSub.TextWrapped = true

local revBtn = Instance.new("TextButton", revFrame)
revBtn.Size = UDim2.new(0,96,0,24); revBtn.Position = UDim2.new(1,-102,0,16)
revBtn.BackgroundColor3 = C.bg2; revBtn.BackgroundTransparency = 0.2; revBtn.BorderSizePixel = 0
revBtn.Font = Enum.Font.GothamBold; revBtn.Text = "Key: None"; revBtn.TextColor3 = C.accent; revBtn.TextSize = 10
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,5); c.Parent = revBtn
    local s = Instance.new("UIStroke"); s.Color = C.border; s.Transparency = 0.7; s.Thickness = 1; s.Parent = revBtn
end

revSpdLbl = Instance.new("TextLabel", revFrame)
revSpdLbl.BackgroundTransparency = 1; revSpdLbl.Position = UDim2.new(0,10,0,54)
revSpdLbl.Size = UDim2.new(0,120,0,20); revSpdLbl.Font = Enum.Font.GothamBold
revSpdLbl.Text = "Reverse Speed: 1.0x"; revSpdLbl.TextColor3 = C.text2; revSpdLbl.TextSize = 9
revSpdLbl.TextXAlignment = Enum.TextXAlignment.Left

local revTrack = Instance.new("Frame", revFrame)
revTrack.BackgroundColor3 = C.bg2; revTrack.BackgroundTransparency = 0.3; revTrack.BorderSizePixel = 0
revTrack.Position = UDim2.new(0,125,0,60)
revTrack.Size = UDim2.new(1,-140,0,8)
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1,0); c.Parent = revTrack
    local s = Instance.new("UIStroke"); s.Color = C.border; s.Transparency = 0.7; s.Thickness = 1; s.Parent = revTrack
end

revFill = Instance.new("Frame", revTrack)
revFill.BackgroundColor3 = C.accent; revFill.BackgroundTransparency = 0.1; revFill.BorderSizePixel = 0
revFill.Size = UDim2.new(0.31,0,1,0)
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1,0); c.Parent = revFill end

revHandle = Instance.new("Frame", revTrack)
revHandle.AnchorPoint = Vector2.new(0.5,0.5)
revHandle.BackgroundColor3 = C.accent; revHandle.BackgroundTransparency = 0; revHandle.BorderSizePixel = 0
revHandle.Position = UDim2.new(0.31,0,0.5,0)
revHandle.Size = UDim2.new(0,12,0,12)
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1,0); c.Parent = revHandle
    local s = Instance.new("UIStroke"); s.Color = C.border; s.Transparency = 0.4; s.Thickness = 1; s.Parent = revHandle
end

-- Reverse Drag and speed setting logic
local revDrag = false
revTrack.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
        revDrag = true
        local pct = math.clamp((inp.Position.X - revTrack.AbsolutePosition.X) / revTrack.AbsoluteSize.X, 0, 1)
        GlobalReverseSpeed = math.floor((0.1 + pct * 2.9) * 10 + 0.5) / 10
        revFill.Size = UDim2.new(pct, 0, 1, 0)
        revHandle.Position = UDim2.new(pct, 0, 0.5, 0)
        revSpdLbl.Text = "Reverse Speed: " .. string.format("%.1f", GlobalReverseSpeed) .. "x"
    end
end)

UserInputService.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 and revDrag then
        revDrag = false
        SaveData()
    end
end)

UserInputService.InputChanged:Connect(function(inp)
    if revDrag and inp.UserInputType == Enum.UserInputType.MouseMovement then
        local pct = math.clamp((inp.Position.X - revTrack.AbsolutePosition.X) / revTrack.AbsoluteSize.X, 0, 1)
        GlobalReverseSpeed = math.floor((0.1 + pct * 2.9) * 10 + 0.5) / 10
        revFill.Size = UDim2.new(pct, 0, 1, 0)
        revHandle.Position = UDim2.new(pct, 0, 0.5, 0)
        revSpdLbl.Text = "Reverse Speed: " .. string.format("%.1f", GlobalReverseSpeed) .. "x"
    end
end)

-- Keybind update function
updateFnWheelBtnText = function()
    local keyName = _G._FortniteWheelKey and _G._FortniteWheelKey.Name or "None"
    fnWheelBtn.Text = "Key: " .. keyName
end

updateRevBtnText = function()
    local keyName = GlobalReverseKeybind and GlobalReverseKeybind.Name or "None"
    revBtn.Text = "Key: " .. keyName
end

-- Wire up Fortnite keybind dialog
local settingWheelKey = false
fnWheelBtn.MouseButton1Click:Connect(function()
    if settingWheelKey then return end
    settingWheelKey = true
    fnWheelBtn.Text = "Listening..."
    fnWheelBtn.BackgroundColor3 = C.yellow
    local keyConn
    keyConn = UserInputService.InputBegan:Connect(LPH_NO_VIRTUALIZE(function(i, gp)
        if gp then return end
        keyConn:Disconnect()
        settingWheelKey = false
        fnWheelBtn.BackgroundColor3 = C.bg2
        if i.KeyCode == Enum.KeyCode.Escape then
            updateFnWheelBtnText()
            return
        end
        _G._FortniteWheelKey = i.KeyCode
        SaveData()
        updateFnWheelBtnText()
    end))
end)

-- Wire up Reverse keybind dialog
local settingRevKey = false
revBtn.MouseButton1Click:Connect(function()
    if settingRevKey then return end
    -- If a key is already bound, clicking the button unbinds it. The user has
    -- to click again to enter listening mode and pick a new key.
    if GlobalReverseKeybind then
        GlobalReverseKeybind = nil
        SaveData()
        updateRevBtnText()
        return
    end
    settingRevKey = true
    revBtn.Text = "Listening..."
    revBtn.BackgroundColor3 = C.yellow
    local keyConn
    keyConn = UserInputService.InputBegan:Connect(LPH_NO_VIRTUALIZE(function(i, gp)
        if gp then return end
        keyConn:Disconnect()
        settingRevKey = false
        revBtn.BackgroundColor3 = C.bg2
        if i.KeyCode == Enum.KeyCode.Escape then
            updateRevBtnText()
            return
        end
        GlobalReverseKeybind = i.KeyCode
        SaveData()
        updateRevBtnText()
    end))
end)

-- Wire up Import from AK button
akBtn.MouseButton1Click:Connect(function()
    -- Run the whole import on its own thread so a heavy file never blocks the UI,
    -- and so we can yield during processing.
    task.spawn(function()
    local success, errorMsg = pcall(function()
        local function notifyUser(msg, isError)
            if WindUI and WindUI.Notify then
                pcall(function()
                    WindUI:Notify({
                        Title = isError and "Import Error" or "Animation Import",
                        Content = msg,
                        Duration = 5,
                        Icon = isError and "alert-triangle" or "download"
                    })
                end)
            elseif NotifyLib and NotifyLib.send then
                pcall(function()
                    NotifyLib.send(msg, { duration = 5 })
                end)
            end
        end

        if not readfile then
            notifyUser("Executor doesn't support file reading.", true)
            return
        end
        local raw, foundPath = nil, nil
        local pathsToCheck = {
            "workspace/ custom_animations.json",         -- Potassium format with space
            "workspace/custom_animations.json",          -- Standard format
            " custom_animations.json",                   -- Direct with space
            "custom_animations.json",                    -- Direct without space
            "ak/custom_animations.json",
            "ak/ custom_animations.json",
            "../workspace/ custom_animations.json",
            "../workspace/custom_animations.json",
            "../../workspace/ custom_animations.json",   -- Two levels up
            "../../workspace/custom_animations.json",
        }
        for _, path in ipairs(pathsToCheck) do
            local ok, content
            if isfile then
                local isF = false
                pcall(function() isF = isfile(path) end)
                if isF then ok, content = pcall(readfile, path) end
            else
                ok, content = pcall(readfile, path)
            end
            if ok and content and content ~= "" then
                raw = content
                foundPath = path
                break
            end
        end
        if not raw then
            notifyUser("Could not locate custom_animations.json in workspace folder.", true)
            return
        end

        -- Strip optional UTF-8 BOM cheaply (no whole-string :gsub, which doubles
        -- memory). The CR/LF normalization that used to follow was unnecessary
        -- because JSONDecode handles those fine anyway.
        if raw:sub(1, 3) == "\xEF\xBB\xBF" then
            raw = raw:sub(4)
        end

        local data
        do
            local ok2, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
            if not ok2 or type(decoded) ~= "table" then
                notifyUser("Failed to parse JSON. File may be too large or malformed.", true)
                return
            end
            data = decoded
        end
        -- Drop the raw string reference so GC can reclaim its memory before we
        -- start building thousands of entries / writing thousands of files.
        raw = nil
        task.wait()
        if collectgarbage then pcall(collectgarbage, "collect") end

        local kbData = {}
        local kbPaths = {
            "workspace/animation_keybinds.json",         -- Potassium standard
            "workspace/ animation_keybinds.json",        -- With space
            "animation_keybinds.json",
            "ak/animation_keybinds.json",
            "../workspace/animation_keybinds.json",
            "../../workspace/animation_keybinds.json",   -- Two levels up
        }
        for _, path in ipairs(kbPaths) do
            local ok, content
            if isfile then
                local isF = false
                pcall(function() isF = isfile(path) end)
                if isF then ok, content = pcall(readfile, path) end
            else
                ok, content = pcall(readfile, path)
            end
            if ok and content and content ~= "" then
                if content:sub(1, 3) == "\xEF\xBB\xBF" then content = content:sub(4) end
                local ok3, parsedKb = pcall(function() return HttpService:JSONDecode(content) end)
                if ok3 and type(parsedKb) == "table" then
                    kbData = parsedKb
                    break
                end
            end
        end

        local count = 0
        local boundCount = 0
        local _byName = {}
        for _, val in ipairs(CustomAnims) do _byName[val.name] = val end

        -- Yield budget: yield a frame whenever we've used 12ms of CPU so the
        -- game never freezes even with thousands of animations.
        local _frameStart = os.clock()
        local function _maybeYield()
            if os.clock() - _frameStart > 0.012 then
                task.wait()
                _frameStart = os.clock()
            end
        end

        local function addAnim(name, script)
            if type(name) == "string" and type(script) == "string" and name ~= "" and script ~= "" then
                -- Keep the EXACT name from the AK file (trim surrounding whitespace only)
                local animName = name:match("^%s*(.-)%s*$")
                if animName ~= "" then
                    pcall(function() ReanimateAPI.seed_animation_cache(animName, nil) end)

                    -- Detect if the data is JSON keyframe data
                    local firstChar = script:match("^%s*(.)")
                    local isJson = (firstChar == "{" or firstChar == "[")

                    -- Write each animation to its OWN file in the ReanimData folder.
                    -- Only the FILENAME is sanitized (filesystem safety); the animation
                    -- name itself stays exactly as it is in the AK file.
                    local ext = isJson and ".json" or ".lua"
                    local safeBase = animName:gsub("[^%w_%-]", "_")
                    local filePath = fpath(safeBase .. ext)
                    local wrote = false
                    pcall(function()
                        writefile(filePath, script)
                        wrote = true
                    end)
                    local storedValue = wrote and filePath or script

                    local existing = _byName[animName]
                    if existing then
                        existing.url = storedValue
                        existing.raw = true
                        existing.isJson = isJson
                        CustomAnimations[animName] = storedValue
                    else
                        local entry = { name = animName, url = storedValue, raw = true, isJson = isJson }
                        table.insert(CustomAnims, entry)
                        _byName[animName] = entry
                        CustomAnimations[animName] = storedValue
                    end
                    count = count + 1

                    -- Auto-bind keybind if one exists for this animation.
                    -- Try the exact name and a few common key-name formats.
                    local kbKey = kbData[name] or kbData[animName]
                    if type(kbKey) == "string" and kbKey ~= "" then
                        local kc = nil
                        local attempts = {
                            kbKey,
                            kbKey:upper(),
                            (#kbKey == 1 and kbKey:upper() or kbKey),
                            "Key" .. kbKey:upper(),
                        }
                        for _, kn in ipairs(attempts) do
                            local ok, res = pcall(function() return Enum.KeyCode[kn] end)
                            if ok and res then kc = res; break end
                        end
                        if kc then
                            local keybindName = "[Custom] " .. animName
                            Keybinds[keybindName] = { key = kc, btn = nil }
                            boundCount = boundCount + 1
                        end
                    end
                end
            end
        end

        -- Snapshot the keys, then process and DELETE each entry from the source
        -- table as we consume it. Releasing entries one-by-one lets the GC
        -- reclaim each animation's memory as we go, which is what prevents
        -- "block too big" / "memory allocation" failures on huge AK exports.
        local keysToProcess = {}
        for k in pairs(data) do keysToProcess[#keysToProcess + 1] = k end
        for i = 1, #keysToProcess do
            local key = keysToProcess[i]
            local val = data[key]
            if type(key) == "string" and type(val) == "string" then
                addAnim(key, val)
            elseif type(val) == "table" then
                local animName = val.name or val.Name or val.title or val.Title
                local animScript = val.script or val.Script or val.content or val.Content or val.code or val.Code or val.data or val.Data
                if type(animName) == "string" and type(animScript) == "string" then
                    addAnim(animName, animScript)
                elseif type(animScript) == "table" then
                    local ok, enc = pcall(function() return HttpService:JSONEncode(animScript) end)
                    if ok and enc then addAnim(animName or key, enc) end
                else
                    local ok, encoded = pcall(function() return HttpService:JSONEncode(val) end)
                    if ok and encoded then addAnim(key, encoded) end
                end
            end
            -- Drop the consumed entry so the source JSON table can shrink
            data[key] = nil
            _maybeYield()
        end
        data = nil
        keysToProcess = nil
        if collectgarbage then pcall(collectgarbage, "collect") end

        SaveCustomAnims()
        SaveKeybindsOnly()
        SaveData()
        
        pcall(function()
            if RebuildCustomList then
                RebuildCustomList()
            elseif _G._ReanimRebuildCustomList then
                _G._ReanimRebuildCustomList()
            end
        end)
        pcall(function()
            if RebuildVisible then
                RebuildVisible()
            end
        end)
        
        if UpdateCustomTabCount then
            UpdateCustomTabCount()
        end
        
        if count > 0 then
            notifyUser("Imported " .. count .. " animation(s), bound " .. boundCount .. " key(s)!")
        else
            notifyUser("No new animations imported.")
        end
    end)
    
    if not success then
        if WindUI and WindUI.Notify then
            pcall(function()
                WindUI:Notify({
                    Title = "Import Error",
                    Content = tostring(errorMsg),
                    Duration = 5,
                    Icon = "alert-triangle"
                })
            end)
        end
    end
    end) -- close the outer task.spawn that wraps the whole import
end)
end

local VROW_H     = 34
local VPAD       = 5
local VPOOL_SIZE = 22

local visibleAnims     = {}
local vPool            = {}
local animRowWidgets   = {}
local _rebuildAnimVer  = 0
local RefreshVirtualRows
local _createAnimRow
local customRowWidgets = {}
local RefreshCustomRows
-- Virtualization state: which slice of each list is currently built, and the
-- filtered/sorted custom-animation list that the custom window draws from.
local visibleCustom    = {}
local _animWinStart    = -1
local _customWinStart  = -1

local function CancelListening()
    if _G._HaloListeningKeyBtn then
        local id    = _G._HaloListenTarget and _G._HaloListenTarget.name
        local bound = id and Keybinds[id]
        _G._HaloListeningKeyBtn.Text             = bound and ("[" .. bound.key.Name .. "]") or "[+]"
        _G._HaloListeningKeyBtn.BackgroundColor3 = bound and C.bg3 or C.bg2
        _G._HaloListeningKeyBtn.TextColor3       = bound and C.accent or C.text3
        _G._HaloListeningKeyBtn = nil
    end
    _G._HaloListenTarget = nil
end

local function BindKey(keyCode)
    if not _G._HaloListenTarget then return end
    local name = _G._HaloListenTarget.name
    local btn  = _G._HaloListenTarget.keyBtn
    for existName, data in pairs(Keybinds) do
        if data.key == keyCode and existName ~= name then
            data.key = nil
            if data.btn and data.btn.Parent then
                data.btn.Text = "[+]"; data.btn.BackgroundColor3 = C.bg2
                data.btn.TextColor3 = C.text3
            end
        end
    end
    Keybinds[name] = { key = keyCode, btn = btn }
    btn.Text = "[" .. keyCode.Name .. "]"
    btn.BackgroundColor3 = C.bg3
    btn.TextColor3 = C.accent
    _G._HaloListeningKeyBtn = nil; _G._HaloListenTarget = nil
    SaveKeybindsOnly()
    Notify(keyCode.Name .. " -> " .. name, 2)
    
    -- Refresh Binds tab if it's currently active
    if State.currentTab == "Binds" then
        task.defer(RebuildBindsList)
    end
end

function UnbindKey(name, btn)
    Keybinds[name] = nil
    btn.Text = "[+]"; btn.BackgroundColor3 = C.bg2
    btn.TextColor3 = C.text3
    SaveKeybindsOnly()
end

function StopAnimation()
    ReanimateAPI.stop_animation()
    State.currentlyPlaying = nil
    State.selectedAnim     = nil
    if NowPlayingLabel then NowPlayingLabel.Text = "No animation playing" end
    if stopEmoteAudio then
        stopEmoteAudio(true)
    end
    -- Re-kick the state system so states resume immediately after manual stop
    if stateSystemActive and State.isReanimated then
        currentStateAnim = nil
        lastLogical = nil
    end
end

StopBtn.MouseButton1Click:Connect(StopAnimation)

local pendingAnim    = nil
local animWorkerBusy = false

function PlayAnimation(animName, speed, isCustom)
    if not ReanimateAPI.is_reanimated() then 
        Notify("Reanim Error", "Cannot play animation, not reanimated.", 3)
        return false 
    end

    local cleanName = animName:gsub("^%[Custom%] ", "")
    local isCustomAnim = isCustom or (CustomAnimations[cleanName] ~= nil)

    local function runPlay()
        local content
        if isCustomAnim then
            local fp = CustomAnimations[cleanName]
            if not fp then 
                Notify("Play Error", "Custom animation file path not found.", 4)
                return false 
            end
            -- Cache custom animations in memory; only re-read/re-parse on cache miss
            if not ReanimateAPI.get_animation_cache(cleanName) then
                local ok2, fileContent
                if type(fp) == "table" and fp.type == "ak" then
                    ok2, fileContent = true, fp.script
                else
                    local fpIsFile = false
                    if type(fp) == "string" then
                        if isfile then
                            local okF, resF = pcall(isfile, fp)
                            if okF and resF then
                                fpIsFile = true
                            end
                        end
                    end
                    if fpIsFile then
                        ok2, fileContent = pcall(readfile, fp)
                    else
                        ok2, fileContent = true, fp
                    end
                end
                if not ok2 or not fileContent or fileContent == "" then
                    Notify("Play Error", "Failed to read custom animation file.", 4)
                    return false
                end
                content = fileContent
                content = content:gsub("^\xEF\xBB\xBF", ""):gsub("\r\n", "\n"):gsub("\r", "\n")
                local firstChar = content:match("^%s*(.)")
                if firstChar == "[" or firstChar == "{" then
                    local parsed = parseJsonAnimation(content)
                    if not parsed then
                        local loaded_fn, err = loadstring("return " .. content)
                        if not loaded_fn then
                            loaded_fn, err = loadstring(content)
                        end
                        if loaded_fn then
                            local ok, data = pcall(function() return loaded_fn() end)
                            if ok and type(data) == "table" then
                                parsed = parseTableAnimation(data)
                            end
                        end
                    end
                    if not parsed then
                        Notify("Format Error", "Failed to parse custom animation.", 6)
                        return false
                    end
                    ReanimateAPI.seed_animation_cache(cleanName, parsed)
                else
                    -- Fix return-wrapped compiler syntax issues
                    if content:match("^%s*return%s*{%s*local") then
                        content = content:gsub("^%s*return%s*{%s*local", "local")
                        local varName = content:match("^%s*local%s+([%w_]+)%s*=")
                        if varName then
                            content = content:gsub("}%s*$", "")
                            content = content:gsub("return%s+[%w_]+%s*$", "")
                            content = content .. "\nreturn " .. varName
                        end
                    end

                    local loaded_fn, err = loadstring(content)
                    if not loaded_fn then
                        Notify("Compile Error", "Syntax error in custom animation: " .. tostring(err), 6)
                        return false
                    end
                    local ok, data = pcall(function() return loaded_fn() end)
                    if not ok then
                        Notify("Execution Error", "Failed to run custom animation: " .. tostring(data), 6)
                        return false
                    end
                    if typeof(data) ~= "table" then
                        Notify("Format Error", "Custom animation must return a table.", 6)
                        return false
                    end
                    local parsed = parseTableAnimation(data)
                    if not parsed then
                        parsed = data
                    end
                    ReanimateAPI.seed_animation_cache(cleanName, parsed)
                end
            end
            content = content or "cached"
        else
            -- Online animations - use cache
            content = AnimationCache[cleanName]
            if not content then
                local cachePath = GetCachePath(cleanName)
                local ok, cached = pcall(readfile, cachePath)
                if ok and cached and cached ~= "" then
                    content = cached
                    AnimationCache[cleanName] = content
                end
            end
            
            if not content then
                local url = AnimationList[cleanName]
                if not url then return false end
                local downloaded = request_get(url)
                if downloaded and downloaded ~= "" then
                    content = downloaded
                    AnimationCache[cleanName] = content
                    task.spawn(function()
                        pcall(writefile, GetCachePath(cleanName), content)
                    end)
                else
                    Notify("Download Error", "Failed to download animation.", 4)
                    return false
                end
            end
            
            -- Pre-compile and seed API cache on first load so play_raw_animation never calls loadstring again
            if not ReanimateAPI.get_animation_cache(cleanName) then
                -- Strip UTF-8 BOM and normalize line endings to prevent parse errors
                content = content:gsub("^\xEF\xBB\xBF", ""):gsub("\r\n", "\n"):gsub("\r", "\n")
                
                -- Fix return-wrapped compiler syntax issues
                if content:match("^%s*return%s*{%s*local") then
                    content = content:gsub("^%s*return%s*{%s*local", "local")
                    local varName = content:match("^%s*local%s+([%w_]+)%s*=")
                    if varName then
                        content = content:gsub("}%s*$", "")
                        content = content:gsub("return%s+[%w_]+%s*$", "")
                        content = content .. "\nreturn " .. varName
                    end
                end

                local loaded_fn, err = loadstring(content)
                if not loaded_fn then
                    Notify("Compile Error", tostring(err), 5)
                    return false
                end
                local ok, data = pcall(function() return loaded_fn() end)
                if not ok then
                    Notify("Execution Error", tostring(data), 5)
                    return false
                end
                if typeof(data) ~= "table" then
                    Notify("Format Error", "Animation did not return a table.", 5)
                    return false
                end
                ReanimateAPI.seed_animation_cache(cleanName, data)
            end
        end

        -- Cache is always seeded above; force_reload=false so API uses it directly
        local result = ReanimateAPI.play_raw_animation(cleanName, content or "", speed or State.currentSpeed, false)
        if type(result) == "string" then 
            Notify("Play Error", result, 5)
            return false 
        end
        return true
    end

    -- If this exact animation is already playing, pressing the keybind/button again should stop it
    if State.selectedAnim == animName then
        StopAnimation()
        return true
    end

    -- Stop any active state animation first, before setting selectedAnim,
    -- so the heartbeat cannot race-stop the animation we are about to start.
    if currentStateAnim then
        pcall(function() ReanimateAPI.stop_animation() end)
        currentStateAnim = nil
    end

    -- Stop any animation currently playing before we begin the new one
    pcall(function() ReanimateAPI.stop_animation() end)

    State.currentlyPlaying = cleanName
    State.selectedAnim     = animName
    if NowPlayingLabel then NowPlayingLabel.Text = cleanName end

    -- Run the heavy loadstring/parse work off the main thread to avoid freezing
    task.spawn(function()
        local success = runPlay()
        if not success then
            State.currentlyPlaying = nil
            State.selectedAnim     = nil
            if NowPlayingLabel then NowPlayingLabel.Text = "No animation playing" end
            -- Re-kick the state system so states resume after a failed play
            if stateSystemActive and State.isReanimated then
                currentStateAnim = nil
                lastLogical = nil
            end
        end
    end)
    return true
end

-- Create a single real row for one animation. Closures capture `anim` directly
-- (no virtual pool). Returns the widget table.
_createAnimRow = function(anim, yPos)
    local displayName = anim.name:gsub("%.lua$", "")

    local row = Instance.new("Frame")
    row.Name = "AnimRow"; row.Parent = AnimListFrame
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1,-10,0,VROW_H-4)
    row.Position = UDim2.new(0,5,0,yPos)
    row.ZIndex = 33; row.Visible = true

    local playBtn = Instance.new("TextButton"); playBtn.Parent = row
    playBtn.BackgroundColor3 = C.bg2
    playBtn.BackgroundTransparency = 0.5; playBtn.BorderSizePixel = 0
    playBtn.Size = UDim2.new(1,-82,1,0)
    playBtn.Font = Enum.Font.GothamMedium; playBtn.Text = displayName
    playBtn.TextColor3 = C.text2; playBtn.TextSize = 11
    playBtn.TextXAlignment = Enum.TextXAlignment.Left
    playBtn.TextTruncate = Enum.TextTruncate.AtEnd
    playBtn.ZIndex = 34; playBtn.AutoButtonColor = false
    do
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,8); c.Parent = playBtn
        local p = Instance.new("UIPadding"); p.PaddingLeft = UDim.new(0,10); p.Parent = playBtn
        local s = Instance.new("UIStroke"); s.Color = C.border; s.Transparency = 0.8; s.Thickness = 1; s.Parent = playBtn
    end

    local favBtn = Instance.new("TextButton"); favBtn.Parent = row
    favBtn.BackgroundColor3 = C.bg2
    favBtn.BackgroundTransparency = 0.3; favBtn.BorderSizePixel = 0
    favBtn.Position = UDim2.new(1,-80,0,0)
    favBtn.Size = UDim2.new(0,26,1,0); favBtn.Font = Enum.Font.GothamBold
    favBtn.Text = ""; favBtn.ZIndex = 34; favBtn.AutoButtonColor = false
    local favIcon
    do
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,5); c.Parent = favBtn
        local s = Instance.new("UIStroke"); s.Color = C.border; s.Transparency = 0.8; s.Thickness = 1; s.Parent = favBtn
        favIcon = Instance.new("ImageLabel"); favIcon.Name = "Icon"; favIcon.Parent = favBtn
        favIcon.BackgroundTransparency = 1; favIcon.AnchorPoint = Vector2.new(0.5,0.5)
        favIcon.Position = UDim2.new(0.5,0,0.5,0); favIcon.Size = UDim2.new(0,14,0,14)
        favIcon.Image = CONFIG.ICONS.STAR_OUTLINE; favIcon.ZIndex = 35
    end

    local keyBtn = Instance.new("TextButton"); keyBtn.Parent = row
    keyBtn.BackgroundColor3 = C.bg2
    keyBtn.BackgroundTransparency = 0.3; keyBtn.BorderSizePixel = 0
    keyBtn.Position = UDim2.new(1,-50,0,0)
    keyBtn.Size = UDim2.new(0,46,1,0); keyBtn.Font = Enum.Font.GothamBold
    keyBtn.Text = ""; keyBtn.TextColor3 = C.text3
    keyBtn.TextSize = 9; keyBtn.ZIndex = 34; keyBtn.AutoButtonColor = false
    local keyIcon
    do
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,5); c.Parent = keyBtn
        local s = Instance.new("UIStroke"); s.Color = C.border; s.Transparency = 0.8; s.Thickness = 1; s.Parent = keyBtn
        keyIcon = Instance.new("ImageLabel"); keyIcon.Name = "Icon"; keyIcon.Parent = keyBtn
        keyIcon.BackgroundTransparency = 1; keyIcon.AnchorPoint = Vector2.new(0.5,0.5)
        keyIcon.Position = UDim2.new(0.5,0,0.5,0); keyIcon.Size = UDim2.new(0,14,0,14)
        keyIcon.Image = CONFIG.ICONS.KEYBOARD; keyIcon.ZIndex = 35
    end

    local widget = { row=row, playBtn=playBtn, favBtn=favBtn, keyBtn=keyBtn,
                     favIcon=favIcon, keyIcon=keyIcon, anim=anim }

    -- Apply initial visual state
    local function refresh()
        local isPlaying = State.selectedAnim == anim.name
        playBtn.Text = (isPlaying and "> " or "") .. displayName
        playBtn.BackgroundColor3 = isPlaying and Color3.fromRGB(255,255,255) or C.bg2
        playBtn.BackgroundTransparency = isPlaying and 0.2 or 0.5
        playBtn.TextColor3 = isPlaying and Color3.fromRGB(0,0,0) or C.text2

        local isFav = Favorites[anim.name] ~= nil
        if favIcon then favIcon.Image = isFav and CONFIG.ICONS.STAR_FILLED or CONFIG.ICONS.STAR_OUTLINE end
        favBtn.BackgroundColor3 = isFav and C.yellow or C.bg2
        favBtn.BackgroundTransparency = isFav and 0 or 0.3

        local bound = Keybinds[anim.name]
        if _G._HaloListenTarget and _G._HaloListenTarget.name == anim.name then
            _G._HaloListeningKeyBtn = keyBtn
            _G._HaloListenTarget.keyBtn = keyBtn
            keyBtn.Text = "[ ? ]"
            if keyIcon then keyIcon.Visible = false end
            keyBtn.BackgroundColor3 = Color3.fromRGB(220,120,20)
            keyBtn.BackgroundTransparency = 0.1
            keyBtn.TextColor3 = Color3.fromRGB(255,255,255)
        elseif bound then
            keyBtn.Text = "["..bound.key.Name.."]"
            if keyIcon then keyIcon.Visible = false end
            Keybinds[anim.name].btn = keyBtn
            keyBtn.BackgroundColor3 = C.bg3
            keyBtn.BackgroundTransparency = 0.1
            keyBtn.TextColor3 = C.accent
        else
            keyBtn.Text = ""
            if keyIcon then keyIcon.Visible = true; keyIcon.Image = CONFIG.ICONS.KEYBOARD end
            keyBtn.BackgroundColor3 = C.bg2
            keyBtn.BackgroundTransparency = 0.3
            keyBtn.TextColor3 = C.text3
        end
    end
    widget.refresh = refresh
    refresh()

    playBtn.MouseEnter:Connect(function()
        local isPlaying = State.selectedAnim == anim.name
        TweenService:Create(playBtn, TweenInfo.new(0.15), {
            BackgroundTransparency = isPlaying and 0.1 or 0.35,
            Size = UDim2.new(1,-78,1,2)
        }):Play()
    end)
    playBtn.MouseLeave:Connect(function()
        local isPlaying = State.selectedAnim == anim.name
        TweenService:Create(playBtn, TweenInfo.new(0.15), {
            BackgroundTransparency = isPlaying and 0.2 or 0.5,
            Size = UDim2.new(1,-82,1,0)
        }):Play()
    end)
    playBtn.MouseButton1Click:Connect(function()
        if anim.name and anim.url then
            PlayAnimation(anim.name, State.currentSpeed, anim.raw)
            task.defer(function() if RefreshVirtualRows then RefreshVirtualRows() end end)
        end
    end)

    favBtn.MouseButton1Click:Connect(function()
        if Favorites[anim.name] then
            Favorites[anim.name] = nil
            Notify("Removed from favourites", 1.5)
        else
            Favorites[anim.name] = true
            Notify("Added to favourites!", 1.5)
        end
        refresh()
        SaveFavoritesOnly()
        if State.currentTab == "Favs" then task.defer(RebuildVisible) end
    end)

    keyBtn.MouseButton1Click:Connect(function()
        if Keybinds[anim.name] and _G._HaloListeningKeyBtn ~= keyBtn then
            UnbindKey(anim.name, keyBtn)
            refresh()
            return
        end
        if _G._HaloListeningKeyBtn then CancelListening() end
        _G._HaloListeningKeyBtn = keyBtn
        _G._HaloListenTarget = { name=anim.name, url=anim.url, keyBtn=keyBtn }
        keyBtn.Text = "[ ? ]"; keyBtn.BackgroundColor3 = Color3.fromRGB(220,120,20)
        keyBtn.TextColor3 = Color3.fromRGB(255,255,255)
    end)

    return widget
end

-- BuildRowPool is no longer needed (rows are real, created by RebuildVisible).
function BuildRowPool() end

-- Windowed virtualization: only build rows for the slice of animations that are
-- actually visible in the scroll viewport (plus a small buffer), and rebuild
-- that slice as the user scrolls. This keeps the number of live UI Instances
-- tiny (~a dozen) no matter how many animations are imported, which is what
-- stops large AK imports from freezing / crashing the game.
local updatingVirtual = false
RefreshVirtualRows = function()
    if not AnimListFrame or updatingVirtual then return end
    updatingVirtual = true

    local winH = 320
    pcall(function()
        local aws = AnimListFrame.AbsoluteWindowSize
        if aws and aws.Y > 0 then
            winH = aws.Y
        else
            winH = AnimListFrame.AbsoluteSize.Y
        end
    end)
    if winH <= 0 then winH = 320 end
    local scrollY  = AnimListFrame.CanvasPosition.Y
    local visCount = math.ceil(winH / VROW_H) + 3  -- rows on screen + buffer
    local startIdx = math.max(1, math.floor((scrollY - VPAD) / VROW_H))  -- 1 row of top buffer
    local endIdx   = math.min(#visibleAnims, startIdx + visCount)

    if startIdx == _animWinStart then
        for _, w in ipairs(animRowWidgets) do
            if w and w.refresh and w.row and w.row.Parent then pcall(w.refresh) end
        end
        updatingVirtual = false
        return
    end
    _animWinStart = startIdx

    -- Rebuild the slice: destroy the old rows and create only the visible ones.
    _rebuildAnimVer = (_rebuildAnimVer or 0) + 1
    for _, c in ipairs(AnimListFrame:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    animRowWidgets = {}
    local wi = 1
    for i = startIdx, endIdx do
        local anim = visibleAnims[i]
        if anim then
            local yPos = VPAD + (i - 1) * VROW_H
            animRowWidgets[wi] = _createAnimRow(anim, yPos)
            wi = wi + 1
        end
    end

    task.spawn(function()
        pcall(function()
            AnimListFrame.CanvasPosition = Vector2.new(0, scrollY)
        end)
        task.wait()
        pcall(function()
            AnimListFrame.CanvasPosition = Vector2.new(0, scrollY)
        end)
        updatingVirtual = false
    end)
end

local RebuildVisible
RebuildVisible = function()
    visibleAnims = {}
    local term = SearchBox.Text:lower()
    local tab  = State.currentTab

    if tab == "Custom" or tab == "Settings" or tab == "States" or tab == "Speed" or tab == "Testing" then
        AnimListFrame.Visible = false
        CustomPanel.Visible   = (tab == "Custom")
        StatesPanel.Visible   = (tab == "States")
        SettingsPanel.Visible = (tab == "Settings")
        SpeedPanel.Visible    = (tab == "Speed")
        TestingPanel.Visible  = (tab == "Testing")
        return
    end

    AnimListFrame.Visible = true
    CustomPanel.Visible   = false
    StatesPanel.Visible   = false
    SettingsPanel.Visible = false
    SpeedPanel.Visible    = false

    local source = {}
    if tab == "All" then
        for name, url in pairs(AnimationList) do
            table.insert(source, { name=name, url=url, raw=false })
        end
        for _, ca in ipairs(CustomAnims) do
            table.insert(source, { name="[Custom] "..ca.name, url=ca.url, raw=ca.raw })
        end
    elseif tab == "Favs" then
        for name, _ in pairs(Favorites) do
            local url = AnimationList[name]
            if url then
                table.insert(source, { name=name, url=url, raw=false })
            else
                local plain = name:match("^%[Custom%] (.+)$") or name
                for _, ca in ipairs(CustomAnims) do
                    if ca.name == plain then
                        table.insert(source, { name=name, url=ca.url, raw=ca.raw })
                        break
                    end
                end
            end
        end
    end

    table.sort(source, function(a, b) return a.name < b.name end)

    for _, e in ipairs(source) do
        if term == "" or e.name:lower():find(term, 1, true) then
            table.insert(visibleAnims, e)
        end
    end

    -- Virtualized list: set the canvas to the full height, reset scroll, then
    -- let RefreshVirtualRows build only the rows visible in the viewport.
    local totalH = VPAD*2 + #visibleAnims * VROW_H
    AnimListFrame.CanvasSize = UDim2.new(0,0,0,totalH)
    AnimListFrame.CanvasPosition = Vector2.new(0,0)
    _animWinStart = -1  -- force a fresh window build
    RefreshVirtualRows()
end

SearchBox:GetPropertyChangedSignal("Text"):Connect(RebuildVisible)

-- Rebuild the visible row window whenever the list is scrolled.
AnimListFrame:GetPropertyChangedSignal("CanvasPosition"):Connect(RefreshVirtualRows)

-- Build one custom-anim row and wire up its buttons.
-- Returns the widget table so the caller can store it.
local function _createCustomRow(ca, yPos)
    local row = Instance.new("Frame"); row.Parent = customListFrame
    row.BackgroundTransparency = 1; row.BorderSizePixel = 0
    row.Size = UDim2.new(1,-12,0,VROW_H-4); row.ZIndex = 34
    row.Position = UDim2.new(0,6,0,yPos or 0)

    local playBtn = Instance.new("TextButton"); playBtn.Parent = row
    playBtn.BackgroundColor3 = C.bg2
    playBtn.BackgroundTransparency = 0.5; playBtn.BorderSizePixel = 0
    playBtn.Size = UDim2.new(1,-114,1,0)
    playBtn.Font = Enum.Font.GothamMedium; playBtn.Text = ca.name:gsub("%.lua$","")
    playBtn.TextColor3 = C.text2; playBtn.TextSize = 11
    playBtn.TextXAlignment = Enum.TextXAlignment.Left
    playBtn.TextTruncate = Enum.TextTruncate.AtEnd
    playBtn.ZIndex = 35; playBtn.AutoButtonColor = false
    do
        local c2 = Instance.new("UICorner"); c2.CornerRadius = UDim.new(0,8); c2.Parent = playBtn
        local p  = Instance.new("UIPadding"); p.PaddingLeft = UDim.new(0,10); p.Parent = playBtn
        local s2 = Instance.new("UIStroke"); s2.Color = C.border; s2.Transparency = 0.8; s2.Thickness = 1; s2.Parent = playBtn
    end

    local favBtn = Instance.new("TextButton"); favBtn.Parent = row
    favBtn.BackgroundColor3 = C.bg2; favBtn.BackgroundTransparency = 0.3
    favBtn.BorderSizePixel = 0; favBtn.Position = UDim2.new(1,-110,0,0)
    favBtn.Size = UDim2.new(0,26,1,0); favBtn.Font = Enum.Font.GothamBold
    favBtn.Text = ""; favBtn.ZIndex = 35; favBtn.AutoButtonColor = false
    do
        local c2 = Instance.new("UICorner"); c2.CornerRadius = UDim.new(0,5); c2.Parent = favBtn
        local ico = Instance.new("ImageLabel"); ico.Name = "Icon"; ico.Parent = favBtn
        ico.BackgroundTransparency = 1; ico.AnchorPoint = Vector2.new(0.5,0.5)
        ico.Position = UDim2.new(0.5,0,0.5,0); ico.Size = UDim2.new(0,14,0,14)
        ico.Image = CONFIG.ICONS.STAR_OUTLINE; ico.ZIndex = 36
    end

    local keyBtn = Instance.new("TextButton"); keyBtn.Parent = row
    keyBtn.BackgroundColor3 = C.bg2; keyBtn.BackgroundTransparency = 0.2
    keyBtn.BorderSizePixel = 0; keyBtn.Position = UDim2.new(1,-80,0,0)
    keyBtn.Size = UDim2.new(0,46,1,0); keyBtn.Font = Enum.Font.GothamBold
    keyBtn.Text = ""; keyBtn.TextColor3 = C.text3
    keyBtn.TextSize = 9; keyBtn.ZIndex = 35; keyBtn.AutoButtonColor = false
    do
        local c2 = Instance.new("UICorner"); c2.CornerRadius = UDim.new(0,5); c2.Parent = keyBtn
        local ico = Instance.new("ImageLabel"); ico.Name = "Icon"; ico.Parent = keyBtn
        ico.BackgroundTransparency = 1; ico.AnchorPoint = Vector2.new(0.5,0.5)
        ico.Position = UDim2.new(0.5,0,0.5,0); ico.Size = UDim2.new(0,14,0,14)
        ico.Image = CONFIG.ICONS.KEYBOARD; ico.ZIndex = 36
    end

    local delBtn = Instance.new("TextButton"); delBtn.Parent = row
    delBtn.BackgroundColor3 = Color3.fromRGB(200,70,70); delBtn.BackgroundTransparency = 0.3
    delBtn.BorderSizePixel = 0; delBtn.Position = UDim2.new(1,-30,0,0)
    delBtn.Size = UDim2.new(0,26,1,0); delBtn.Text = ""
    delBtn.ZIndex = 35; delBtn.AutoButtonColor = false
    do
        local c2 = Instance.new("UICorner"); c2.CornerRadius = UDim.new(0,5); c2.Parent = delBtn
        local ico = Instance.new("ImageLabel"); ico.Parent = delBtn
        ico.BackgroundTransparency = 1; ico.AnchorPoint = Vector2.new(0.5,0.5)
        ico.Position = UDim2.new(0.5,0,0.5,0); ico.Size = UDim2.new(0,12,0,12)
        ico.Image = "rbxassetid://6031094678"
        ico.ImageColor3 = Color3.fromRGB(255,255,255); ico.ZIndex = 36
    end

    -- Hover / press visuals
    playBtn.MouseEnter:Connect(function()
        if State.selectedAnim ~= ca.name then
            TweenService:Create(playBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0.35, Size = UDim2.new(1,-110,1,2)}):Play()
        end
    end)
    playBtn.MouseLeave:Connect(function()
        TweenService:Create(playBtn, TweenInfo.new(0.15), {
            BackgroundTransparency = (State.selectedAnim == ca.name) and 0.2 or 0.5,
            Size = UDim2.new(1,-114,1,0)
        }):Play()
    end)
    playBtn.MouseButton1Down:Connect(function()
        TweenService:Create(playBtn, TweenInfo.new(0.08), {BackgroundTransparency = 0.25}):Play()
    end)
    delBtn.MouseEnter:Connect(function()
        TweenService:Create(delBtn, TweenInfo.new(0.1), {BackgroundTransparency = 0}):Play()
    end)
    delBtn.MouseLeave:Connect(function()
        TweenService:Create(delBtn, TweenInfo.new(0.1), {BackgroundTransparency = 0.3}):Play()
    end)

    -- Widget table (caIdx is mutable via upvalue trick — use a holder table)
    local w = { playBtn=playBtn, favBtn=favBtn, keyBtn=keyBtn, delBtn=delBtn,
                name=ca.name, row=row }

    playBtn.MouseButton1Click:Connect(function()
        PlayAnimation(ca.name, State.currentSpeed, true)
        task.defer(function() if RefreshCustomRows then RefreshCustomRows() end end)
    end)

    favBtn.MouseButton1Click:Connect(function()
        local favKey = "[Custom] " .. ca.name
        local favIcon = favBtn:FindFirstChild("Icon")
        if Favorites[favKey] then
            Favorites[favKey] = nil
            TweenService:Create(favBtn, TweenInfo.new(0.15), {
                BackgroundColor3 = C.bg2, BackgroundTransparency = 0.3 }):Play()
            if favIcon then favIcon.Image = CONFIG.ICONS.STAR_OUTLINE end
            Notify("Removed from favourites", 1.5)
        else
            Favorites[favKey] = true
            TweenService:Create(favBtn, TweenInfo.new(0.15), {
                BackgroundColor3 = C.yellow, BackgroundTransparency = 0 }):Play()
            if favIcon then favIcon.Image = CONFIG.ICONS.STAR_FILLED end
            Notify("Added to favourites!", 1.5)
        end
        SaveFavoritesOnly()
        if State.currentTab == "Favs" then task.defer(RebuildVisible) end
    end)

    keyBtn.MouseButton1Click:Connect(function()
        local ckName = "[Custom] " .. ca.name
        local keyIcon = keyBtn:FindFirstChild("Icon")
        if Keybinds[ckName] and _G._HaloListeningKeyBtn ~= keyBtn then
            UnbindKey(ckName, keyBtn)
            local bound = Keybinds[ckName]
            if bound then
                keyBtn.Text = "["..bound.key.Name.."]"
                if keyIcon then keyIcon.Visible = false end
            else
                keyBtn.Text = ""
                if keyIcon then keyIcon.Visible = true; keyIcon.Image = CONFIG.ICONS.KEYBOARD end
            end
            keyBtn.BackgroundColor3 = bound and C.bg3 or C.bg2
            keyBtn.TextColor3 = bound and C.accent or C.text3
            return
        end
        if _G._HaloListeningKeyBtn then CancelListening() end
        _G._HaloListeningKeyBtn = keyBtn
        _G._HaloListenTarget = { name = ckName, url = ca.url, keyBtn = keyBtn }
        keyBtn.Text = "[ ? ]"; keyBtn.BackgroundColor3 = Color3.fromRGB(220,120,20)
        keyBtn.TextColor3 = Color3.fromRGB(255,255,255)
        if keyIcon then keyIcon.Visible = false end
    end)

    delBtn.MouseButton1Click:Connect(function()
        -- Find current index of this anim in case the list shifted
        local currentIdx = nil
        for i, v in ipairs(CustomAnims) do
            if v.name == ca.name then currentIdx = i; break end
        end
        if not currentIdx then 
            return 
        end
        if State.selectedAnim == ca.name then StopAnimation() end
        local animName = ca.name
        
        -- Delete the actual file(s) from disk
        local animEntry = CustomAnims[currentIdx]
        if animEntry then
            local content = animEntry.url or animEntry.file
            local deleteFunc = delfile or deletefile or function() end
            
            if type(content) == "string" then
                pcall(function() deleteFunc(content) end)
                
                -- Also try variations of the filename
                local baseName = animName:gsub("%.lua$", ""):gsub("%.json$", "")
                local possiblePaths = {
                    content,
                    fpath("custom_" .. baseName .. ".dat"),
                    fpath(baseName .. ".lua"),
                    fpath(baseName .. ".json"),
                    "ReanimData/" .. baseName .. ".lua",
                    "ReanimData/" .. baseName .. ".json",
                    "ReanimData/" .. animName,
                }
                
                for _, path in ipairs(possiblePaths) do
                    pcall(function() deleteFunc(path) end)
                end
            end
        end
        
        table.remove(CustomAnims, currentIdx)
        CustomAnimations[animName] = nil
        
        SaveCustomAnims()
        SaveData()
        
        if UpdateCustomTabCount then
            UpdateCustomTabCount()
        end
        
        if RebuildCustomList then RebuildCustomList() end
        
        Notify("Deleted: " .. animName, 2)
    end)

    -- Apply / refresh visual state (also used by RefreshCustomRows on scroll).
    local function refresh()
        local isFav = Favorites["[Custom] " .. ca.name] ~= nil
        local favIcon = favBtn:FindFirstChild("Icon")
        if favIcon then
            favIcon.Image = isFav and CONFIG.ICONS.STAR_FILLED or CONFIG.ICONS.STAR_OUTLINE
        end
        favBtn.BackgroundColor3 = isFav and C.yellow or C.bg2
        favBtn.BackgroundTransparency = isFav and 0 or 0.3
        favBtn.TextColor3 = isFav and Color3.fromRGB(0,0,0) or C.yellow

        local ckName = "[Custom] " .. ca.name
        local bound = Keybinds[ckName]
        local keyIcon = keyBtn:FindFirstChild("Icon")
        if _G._HaloListenTarget and _G._HaloListenTarget.name == ckName then
            _G._HaloListeningKeyBtn = keyBtn
            _G._HaloListenTarget.keyBtn = keyBtn
            keyBtn.Text = "[ ? ]"
            if keyIcon then keyIcon.Visible = false end
            keyBtn.BackgroundColor3 = Color3.fromRGB(220,120,20)
            keyBtn.TextColor3 = Color3.fromRGB(255,255,255)
        elseif bound then
            keyBtn.Text = "["..bound.key.Name.."]"
            if keyIcon then keyIcon.Visible = false end
            Keybinds[ckName].btn = keyBtn
            keyBtn.BackgroundColor3 = C.bg3
            keyBtn.TextColor3 = C.accent
        else
            keyBtn.Text = ""
            if keyIcon then keyIcon.Visible = true; keyIcon.Image = CONFIG.ICONS.KEYBOARD end
            keyBtn.BackgroundColor3 = C.bg2
            keyBtn.TextColor3 = C.text3
        end

        local isPlaying = State.selectedAnim == ca.name
        playBtn.Text = (isPlaying and "> " or "") .. ca.name
        playBtn.BackgroundTransparency = isPlaying and 0.2 or 0.93
        playBtn.TextColor3 = isPlaying and Color3.fromRGB(0,0,0) or Color3.fromRGB(215,215,235)
    end
    w.refresh = refresh
    refresh()

    return w
end

-- Full rebuild: filter + sort the custom animations into the visible list, set
-- the canvas height, then let RefreshCustomRows build only the rows currently
-- on screen. Virtualized, so it never freezes regardless of how many exist.
function RebuildCustomList()
    _G._ReanimRebuildCustomList = RebuildCustomList
    local searchTerm = customSearchBox.Text:lower()
    visibleCustom = {}
    for _, ca in ipairs(CustomAnims) do
        local displayName = ca.name:gsub("%.lua$","")
        if searchTerm == "" or displayName:lower():find(searchTerm, 1, true) then
            table.insert(visibleCustom, ca)
        end
    end
    table.sort(visibleCustom, function(a, b) return a.name:lower() < b.name:lower() end)

    local totalH = VPAD*2 + #visibleCustom * VROW_H
    customListFrame.CanvasSize = UDim2.new(0,0,0,totalH)
    customListFrame.CanvasPosition = Vector2.new(0,0)
    _customWinStart = -1  -- force a fresh window build
    RefreshCustomRows()
end

-- Fast path after a single add: the list is virtualized now, so a full rebuild
-- is cheap (it only ever creates the visible rows).
function AppendCustomRow(ca)
    RebuildCustomList()
end

local _rebuildCustomDebounce = nil
customSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    if _rebuildCustomDebounce then task.cancel(_rebuildCustomDebounce) end
    _rebuildCustomDebounce = task.delay(0.15, function()
        _rebuildCustomDebounce = nil
        RebuildCustomList()
    end)
end)

-- Windowed virtualization for the custom list: only build rows for the slice
-- visible in the viewport, rebuilding as the user scrolls. Keeps the live
-- instance count tiny no matter how many custom animations exist.
local updatingCustom = false
RefreshCustomRows = function()
    if not customListFrame or updatingCustom then return end
    updatingCustom = true

    local winH = 320
    pcall(function()
        local aws = customListFrame.AbsoluteWindowSize
        if aws and aws.Y > 0 then
            winH = aws.Y
        else
            winH = customListFrame.AbsoluteSize.Y
        end
    end)
    if winH <= 0 then winH = 320 end
    local scrollY  = customListFrame.CanvasPosition.Y
    local visCount = math.ceil(winH / VROW_H) + 3
    local startIdx = math.max(1, math.floor((scrollY - VPAD) / VROW_H))
    local endIdx   = math.min(#visibleCustom, startIdx + visCount)

    -- Window unchanged: just refresh the visuals of the existing rows.
    if startIdx == _customWinStart then
        for _, w in ipairs(customRowWidgets) do
            if w and w.refresh and w.row and w.row.Parent then pcall(w.refresh) end
        end
        updatingCustom = false
        return
    end
    _customWinStart = startIdx

    for _, c in ipairs(customListFrame:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    customRowWidgets = {}
    local wi = 1
    for i = startIdx, endIdx do
        local ca = visibleCustom[i]
        if ca then
            local yPos = VPAD + (i - 1) * VROW_H
            customRowWidgets[wi] = _createCustomRow(ca, yPos)
            wi = wi + 1
        end
    end

    task.spawn(function()
        pcall(function()
            customListFrame.CanvasPosition = Vector2.new(0, scrollY)
        end)
        task.wait()
        pcall(function()
            customListFrame.CanvasPosition = Vector2.new(0, scrollY)
        end)
        updatingCustom = false
    end)
end

-- Rebuild the visible window whenever the custom list is scrolled.
customListFrame:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
    if RefreshCustomRows then RefreshCustomRows() end
end)

-- RebuildBindsList: shows all animations with keybinds set
function RebuildBindsList()
    -- Clear existing rows
    for _, child in ipairs(BindsPanel:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end
    
    -- Add header with instructions
    local headerLabel = Instance.new("TextLabel")
    headerLabel.Name = "HeaderLabel"
    headerLabel.Parent = BindsPanel
    headerLabel.BackgroundTransparency = 1
    headerLabel.Size = UDim2.new(1, -10, 0, 20)
    headerLabel.Position = UDim2.new(0, 5, 0, 8)
    headerLabel.Font = Enum.Font.GothamMedium
    headerLabel.Text = "Click key button to rebind  |  Click Unbind to remove"
    headerLabel.TextColor3 = C.text3
    headerLabel.TextSize = 10
    headerLabel.TextXAlignment = Enum.TextXAlignment.Left
    headerLabel.ZIndex = 33
    
    -- Collect all animations with keybinds
    local boundAnims = {}
    for name, data in pairs(Keybinds) do
        if data and data.key then
            local displayName = name:gsub("^%[Custom%] ", ""):gsub("%.lua$", "")
            local isCustom = name:find("^%[Custom%]") ~= nil
            local url = nil
            
            if isCustom then
                -- Find the URL from CustomAnimations
                for _, ca in ipairs(CustomAnims) do
                    if "[Custom] " .. ca.name == name then
                        url = ca.url
                        break
                    end
                end
            else
                -- Find the URL from AnimationList
                url = AnimationList[name]
            end
            
            if url then
                table.insert(boundAnims, {
                    name = name,
                    displayName = displayName,
                    keyName = data.key.Name,
                    isCustom = isCustom,
                    url = url
                })
            end
        end
    end
    
    -- Sort alphabetically
    table.sort(boundAnims, function(a, b)
        return a.displayName:lower() < b.displayName:lower()
    end)
    
    -- Create rows for each bound animation
    local yPos = 34
    for _, anim in ipairs(boundAnims) do
        local row = Instance.new("Frame")
        row.Name = "BindRow"
        row.Parent = BindsPanel
        row.BackgroundTransparency = 1
        row.Size = UDim2.new(1, -10, 0, 30)
        row.Position = UDim2.new(0, 5, 0, yPos)
        row.ZIndex = 33
        
        -- Play button
        local playBtn = Instance.new("TextButton")
        playBtn.Parent = row
        playBtn.BackgroundColor3 = C.bg2
        playBtn.BackgroundTransparency = 0.5
        playBtn.BorderSizePixel = 0
        playBtn.Size = UDim2.new(1, -120, 1, 0)
        playBtn.Font = Enum.Font.GothamMedium
        playBtn.Text = anim.displayName
        playBtn.TextColor3 = C.text2
        playBtn.TextSize = 11
        playBtn.TextXAlignment = Enum.TextXAlignment.Left
        playBtn.TextTruncate = Enum.TextTruncate.AtEnd
        playBtn.ZIndex = 34
        playBtn.AutoButtonColor = false
        do
            local c = Instance.new("UICorner")
            c.CornerRadius = UDim.new(0, 5)
            c.Parent = playBtn
            local p = Instance.new("UIPadding")
            p.PaddingLeft = UDim.new(0, 8)
            p.Parent = playBtn
            local s = Instance.new("UIStroke")
            s.Color = C.border
            s.Transparency = 0.8
            s.Thickness = 1
            s.Parent = playBtn
        end
        
        -- Key display button (click to rebind)
        local keyBtn = Instance.new("TextButton")
        keyBtn.Parent = row
        keyBtn.BackgroundColor3 = C.bg3
        keyBtn.BackgroundTransparency = 0
        keyBtn.BorderSizePixel = 0
        keyBtn.Position = UDim2.new(1, -114, 0, 0)
        keyBtn.Size = UDim2.new(0, 56, 1, 0)
        keyBtn.Font = Enum.Font.GothamBold
        keyBtn.Text = "[" .. anim.keyName .. "]"
        keyBtn.TextColor3 = C.accent
        keyBtn.TextSize = 10
        keyBtn.ZIndex = 34
        keyBtn.AutoButtonColor = false
        do
            local c = Instance.new("UICorner")
            c.CornerRadius = UDim.new(0, 5)
            c.Parent = keyBtn
            local s = Instance.new("UIStroke")
            s.Color = C.border
            s.Transparency = 0.8
            s.Thickness = 1
            s.Parent = keyBtn
        end
        
        -- Hover effect for key button
        keyBtn.MouseEnter:Connect(function()
            if _G._HaloListeningKeyBtn ~= keyBtn then
                TweenService:Create(keyBtn, TweenInfo.new(0.1), {
                    BackgroundColor3 = C.accent, TextColor3 = Color3.fromRGB(10,10,10)
                }):Play()
            end
        end)
        keyBtn.MouseLeave:Connect(function()
            if _G._HaloListeningKeyBtn ~= keyBtn then
                TweenService:Create(keyBtn, TweenInfo.new(0.1), {
                    BackgroundColor3 = C.bg3, TextColor3 = C.accent
                }):Play()
            end
        end)
        
        -- Unbind button
        local unbindBtn = Instance.new("TextButton")
        unbindBtn.Parent = row
        unbindBtn.BackgroundColor3 = C.red
        unbindBtn.BackgroundTransparency = 0.3
        unbindBtn.BorderSizePixel = 0
        unbindBtn.Position = UDim2.new(1, -54, 0, 0)
        unbindBtn.Size = UDim2.new(0, 48, 1, 0)
        unbindBtn.Font = Enum.Font.GothamBold
        unbindBtn.Text = "Unbind"
        unbindBtn.TextColor3 = C.white
        unbindBtn.TextSize = 9
        unbindBtn.ZIndex = 34
        unbindBtn.AutoButtonColor = false
        do
            local c = Instance.new("UICorner")
            c.CornerRadius = UDim.new(0, 5)
            c.Parent = unbindBtn
        end
        
        -- Hover effects
        playBtn.MouseEnter:Connect(function()
            TweenService:Create(playBtn, TweenInfo.new(0.1), {
                BackgroundTransparency = 0.2, TextColor3 = C.text
            }):Play()
        end)
        playBtn.MouseLeave:Connect(function()
            TweenService:Create(playBtn, TweenInfo.new(0.1), {
                BackgroundTransparency = 0.5, TextColor3 = C.text2
            }):Play()
        end)
        
        unbindBtn.MouseEnter:Connect(function()
            TweenService:Create(unbindBtn, TweenInfo.new(0.1), {
                BackgroundTransparency = 0
            }):Play()
        end)
        unbindBtn.MouseLeave:Connect(function()
            TweenService:Create(unbindBtn, TweenInfo.new(0.1), {
                BackgroundTransparency = 0.3
            }):Play()
        end)
        
        -- Click handlers
        playBtn.MouseButton1Click:Connect(function()
            PlayAnimation(anim.name:gsub("^%[Custom%] ", ""), State.currentSpeed, anim.isCustom)
        end)
        
        keyBtn.MouseButton1Click:Connect(function()
            -- Start listening for new key
            if _G._HaloListeningKeyBtn then CancelListening() end
            _G._HaloListeningKeyBtn = keyBtn
            _G._HaloListenTarget = { name = anim.name, url = anim.url, keyBtn = keyBtn }
            keyBtn.Text = "[ ? ]"
            keyBtn.BackgroundColor3 = Color3.fromRGB(220, 120, 20)
            keyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        end)
        
        unbindBtn.MouseButton1Click:Connect(function()
            Keybinds[anim.name] = nil
            SaveData()
            Notify("Unbound: " .. anim.displayName, 2)
            RebuildBindsList()
        end)
        
        yPos = yPos + 34
    end
    
    -- Update canvas size
    BindsPanel.CanvasSize = UDim2.new(0, 0, 0, yPos + 8)
    
    -- Show message if no keybinds are set
    if #boundAnims == 0 then
        local noBindsLabel = Instance.new("TextLabel")
        noBindsLabel.Name = "NoBindsLabel"
        noBindsLabel.Parent = BindsPanel
        noBindsLabel.BackgroundTransparency = 1
        noBindsLabel.Size = UDim2.new(1, -20, 0, 80)
        noBindsLabel.Position = UDim2.new(0, 10, 0, 40)
        noBindsLabel.Font = Enum.Font.GothamMedium
        noBindsLabel.Text = "No keybinds set yet\n\nGo to the All or Custom tab\nand click [+] to bind keys to animations"
        noBindsLabel.TextColor3 = C.text3
        noBindsLabel.TextSize = 12
        noBindsLabel.TextWrapped = true
        noBindsLabel.ZIndex = 33
        
        BindsPanel.CanvasSize = UDim2.new(0, 0, 0, 140)
    end
end

local STATE_TYPES = { "Idle", "Walk", "Run", "Jump", "Fall", "Climb", "SwimIdle", "Swim" }

local currentStateAnim = nil
local stateWatchConn   = nil
local stateHumConn     = nil
-- True while we've handed control back to the clone's default Animate script
-- because the current logical state has no custom animation assigned (e.g. you
-- jump but only set Idle/Run). Lets default jump/fall/etc. play instead of
-- freezing the previous custom animation.
local _stateFallbackActive = false

local getLogicalState = LPH_NO_VIRTUALIZE(function(hum)
    local hs = hum:GetState()
    -- The Jumping state is only active for the first instant of a jump, before
    -- upward velocity has been applied — so map it straight to "Jump" instead of
    -- letting the near-zero velocity fall through to Idle/Walk (which made jump
    -- animations never trigger).
    if hs == Enum.HumanoidStateType.Jumping then
        return "Jump"
    elseif hs == Enum.HumanoidStateType.Freefall then
        -- While airborne we are EITHER rising (jump) or descending/at-apex (fall).
        -- Never return a ground state here: the old "near-zero velocity" branch
        -- reported Idle at the apex of every jump, which made jumping look like it
        -- was playing the idle animation. Landing is handled when the humanoid
        -- leaves the Freefall state (the else branch below).
        local hrp = hum.RootPart
        if hrp and hrp.AssemblyLinearVelocity.Y > 0.1 then
            return "Jump"
        end
        return "Fall"
    elseif hs == Enum.HumanoidStateType.Climbing then
        return "Climb"
    elseif hs == Enum.HumanoidStateType.Swimming then
        local speed = hum.WalkSpeed > 0 and hum.MoveDirection.Magnitude > 0.1
        return speed and "Swim" or "SwimIdle"
    else
        -- Use horizontal velocity magnitude rather than MoveDirection so brief
        -- directional pauses (where MoveDirection momentarily zeros) don't
        -- register as Idle and flash the idle animation mid-movement.
        local hrp = hum.RootPart
        local horizSpeed = 0
        if hrp then
            local vel = hrp.AssemblyLinearVelocity
            horizSpeed = Vector2.new(vel.X, vel.Z).Magnitude
        end
        -- Hysteresis via lastLogical is applied in the watcher; base thresholds
        -- are lower so Walk/Run trigger reliably across games & framerates.
        if horizSpeed > 14 then return "Run"
        elseif horizSpeed > 2 then return "Walk"
        else return "Idle" end
    end
end)

local stateScriptCache = {}

prefetchStateAnim = function(stKey)
    local entry = StateAnims[stKey]
    if not entry then return end
    local url = type(entry) == "table" and entry.url or entry
    if not url or url == "" then return end
    if stateScriptCache[url] then return end
    
    local isHttp = url:match("^https?://")
    local isLocalFile = not isHttp and isfile and readfile and isfile(url)
    
    task.spawn(function()
        local src = ""
        if isHttp then
            local ok, content = pcall(function() return game:HttpGet(url, true) end)
            if not ok or type(content) ~= "string" or #content == 0 then return end
            src = content
        elseif isLocalFile then
            local ok, content = pcall(readfile, url)
            if not ok or not content or content == "" then return end
            src = content
        else
            src = url
        end
        
        src = src:gsub("^\xEF\xBB\xBF", ""):gsub("\r\n", "\n"):gsub("\r", "\n")
        
        -- Try JSON parsing first
        local firstChar = src:match("^%s*(.)")
        if firstChar == "{" or firstChar == "[" then
            local parsed = parseJsonAnimation(src)
            if parsed then
                stateScriptCache[url] = { src = src, data = parsed }
                return
            end
        end
        local fn = loadstring(src)
        if not fn then return end
        local ok2, data = pcall(fn)
        if not ok2 or type(data) ~= "table" then return end
        stateScriptCache[url] = { src = src, data = data }
    end)
end

prefetchAllStates = function()
    for _, stKey in ipairs(STATE_TYPES) do
        prefetchStateAnim(stKey)
    end
end

local STATE_SPEED_MULT = 1.0
local stateLoading = {}

-- Hand control to (true) or take it back from (false) the clone's default
-- Animate script for un-assigned states. Idempotent so we only toggle on change.
local defaultTracks = {}

local DEFAULT_ANIM_FOLDER = {
    Idle = "idle", Walk = "walk", Run = "run", Jump = "jump",
    Fall = "fall", Climb = "climb", Swim = "swim", SwimIdle = "swimidle",
}

local function stopDefaultTracks(except)
    for key, track in pairs(defaultTracks) do
        if key ~= except then
            pcall(function()
                if track.IsPlaying then track:Stop(0.12) end
            end)
        end
    end
end

local function playDefaultState(stKey)
    if not ReanimateAPI or not ReanimateAPI.get_clone then return false end
    local clone = ReanimateAPI.get_clone(plr)
    if not clone then return false end
    local animate = clone:FindFirstChild("Animate")
    local folderName = DEFAULT_ANIM_FOLDER[stKey]
    local folder = animate and folderName and animate:FindFirstChild(folderName)
    if not folder then return false end
    if not defaultTracks[stKey] then
        local animObj = folder:FindFirstChildWhichIsA("Animation", true)
        local hum = clone:FindFirstChildOfClass("Humanoid")
        if not animObj or not hum then return false end
        local animator = hum:FindFirstChildOfClass("Animator")
        if not animator then
            animator = Instance.new("Animator")
            animator.Parent = hum
        end
        local ok, track = pcall(function() return animator:LoadAnimation(animObj) end)
        if not ok or not track then return false end
        if stKey == "Idle" or stKey == "SwimIdle" then
            track.Priority = Enum.AnimationPriority.Action
            track.Looped = true
        elseif stKey == "Jump" or stKey == "Fall" or stKey == "Climb" then
            track.Priority = Enum.AnimationPriority.Action
        else
            track.Priority = Enum.AnimationPriority.Movement
        end
        track.Looped = stKey ~= "Jump"
        defaultTracks[stKey] = track
    end
    stopDefaultTracks(stKey)
    local track = defaultTracks[stKey]
    pcall(function()
        if not track.IsPlaying then track:Play(0.15, 1, 1) end
    end)
    return true
end

local function _setStateFallback(active)
    if active == _stateFallbackActive then return end
    _stateFallbackActive = active
    if active then
        -- Stop the lingering custom animation so the default Animate (jump/fall
        -- /etc.) is what's visible, then re-enable the default Animate script.
        currentStateAnim = nil
        pcall(function() ReanimateAPI.stop_animation_for_transition() end)
        if _applyReanimDefaultAnimate then _applyReanimDefaultAnimate(true) end
    else
        -- Returning to a custom state: turn the default Animate back off so it
        -- doesn't fight the constraint-driven custom animation.
        if _applyReanimDefaultAnimate then _applyReanimDefaultAnimate(false) end
    end
end

function playStateAnim(stKey)
    local entry = StateAnims[stKey]
    local url   = type(entry) == "table" and entry.url or entry
    local raw   = type(entry) == "table" and entry.raw or false
    if not entry or not url or url == "" then
        if playDefaultState(stKey) then
            currentStateAnim = stKey
            _stateFallbackActive = true
            return
        end
        _setStateFallback(true)
        return
    end
    stopDefaultTracks(nil)
    -- A custom animation exists for this state: make sure the default Animate
    -- fallback is disabled before we drive the custom animation ourselves.
    _setStateFallback(false)
    if currentStateAnim == stKey then return end
    pcall(function() ReanimateAPI.stop_animation_for_transition() end)
    currentStateAnim = stKey
    local cachedEntry = stateScriptCache[url]
    
    local isHttp = url:match("^https?://")
    local isLocalFile = not isHttp and isfile and readfile and isfile(url)
    
    if isHttp or raw or isLocalFile then
        if not cachedEntry then
            if stateLoading[url] then return end
            stateLoading[url] = true
            task.spawn(function()
                local src = ""
                if isHttp then
                    local ok, content = pcall(function() return game:HttpGet(url, true) end)
                    if not ok or type(content) ~= "string" or #content == 0 then
                        warn("[StateAnim] HTTP fetch failed for", stKey, ":", content)
                        stateLoading[url] = nil
                        if currentStateAnim == stKey then currentStateAnim = nil end
                        return
                    end
                    src = content
                elseif isLocalFile then
                    local ok, content = pcall(readfile, url)
                    if not ok or not content or content == "" then
                        warn("[StateAnim] File read failed for", stKey, ":", url)
                        stateLoading[url] = nil
                        if currentStateAnim == stKey then currentStateAnim = nil end
                        return
                    end
                    src = content
                else
                    src = url
                end
                
                src = src:gsub("^\xEF\xBB\xBF", ""):gsub("\r\n", "\n"):gsub("\r", "\n")
                
                local data
                local parseMethod = "none"
                -- Try JSON parsing first
                local firstChar = src:match("^%s*(.)")
                warn("[StateAnim] Loading", stKey, "- first char:", firstChar, "- length:", #src)
                
                if firstChar == "{" or firstChar == "[" then
                    parseMethod = "json"
                    warn("[StateAnim] Attempting JSON parse for", stKey)
                    local parsed = parseJsonAnimation(src)
                    if parsed and #parsed > 0 then 
                        data = parsed
                        warn("[StateAnim] JSON parsed successfully for", stKey, "- frames:", #data)
                        -- Log first frame structure
                        if data[1] then
                            local boneCount = 0
                            for _ in pairs(data[1].Data or {}) do boneCount = boneCount + 1 end
                            warn("[StateAnim] First frame - Time:", data[1].Time, "- Bones:", boneCount)
                        end
                    else
                        warn("[StateAnim] JSON parsing returned nil or empty for", stKey)
                    end
                end
                
                if not data then
                    parseMethod = "lua"
                    local fn = loadstring(src)
                    if not fn then
                        warn("[StateAnim] loadstring failed for", stKey)
                        stateLoading[url] = nil
                        if currentStateAnim == stKey then currentStateAnim = nil end
                        return
                    end
                    local ok2, luaData = pcall(fn)
                    if not ok2 or type(luaData) ~= "table" then
                        warn("[StateAnim] Lua execution failed for", stKey, ":", luaData)
                        stateLoading[url] = nil
                        if currentStateAnim == stKey then currentStateAnim = nil end
                        return
                    end
                    
                    -- If luaData is already keyframes array, use it directly
                    if type(luaData[1]) == "table" and luaData[1].Time and luaData[1].Data then
                        data = luaData
                        warn("[StateAnim] Lua data is already keyframes format for", stKey)
                    else
                        -- Parse as table animation
                        data = parseTableAnimation(luaData)
                        if not data then
                            warn("[StateAnim] parseTableAnimation failed for", stKey)
                        end
                    end
                end
                
                if not data or #data == 0 then
                    warn("[StateAnim] No valid animation data for", stKey, "- method:", parseMethod)
                    stateLoading[url] = nil
                    if currentStateAnim == stKey then currentStateAnim = nil end
                    return
                end
                
                cachedEntry = { src = src, data = data }
                stateScriptCache[url] = cachedEntry
                stateLoading[url] = nil
                
                warn("[StateAnim] Successfully loaded", stKey, "with", #data, "frames via", parseMethod)
                
                -- Check if we are still matching the requested state
                if currentStateAnim == stKey then
                    if ReanimateAPI.play_keyframes and data then
                        pcall(function()
                            ReanimateAPI.play_keyframes(data, State.currentSpeed * STATE_SPEED_MULT)
                        end)
                    else
                        pcall(function()
                            ReanimateAPI.play_raw_animation(url, src, State.currentSpeed * STATE_SPEED_MULT)
                        end)
                    end
                end
            end)
        else
            if ReanimateAPI.play_keyframes and cachedEntry.data then
                pcall(function()
                    ReanimateAPI.play_keyframes(cachedEntry.data, State.currentSpeed * STATE_SPEED_MULT)
                end)
            else
                pcall(function()
                    ReanimateAPI.play_raw_animation(url, cachedEntry.src, State.currentSpeed * STATE_SPEED_MULT)
                end)
            end
        end
    else
        pcall(function()
            ReanimateAPI.play_animation(url, State.currentSpeed * STATE_SPEED_MULT)
        end)
    end
end

stopStateSystem = function()
    if stateWatchConn then stateWatchConn:Disconnect(); stateWatchConn = nil end
    if stateHumConn   then stateHumConn:Disconnect();   stateHumConn   = nil end
    stateSystemActive = false
    currentStateAnim  = nil
    _stateFallbackActive = false
    stopDefaultTracks(nil)
    table.clear(defaultTracks)
    pcall(function() ReanimateAPI.stop_animation() end)
end

-- Enable/disable the reanimated clone's default Roblox Animate script.
-- When enabled, the clone plays the player's equipped animation pack
-- (idle/walk/run/jump/etc.) exactly like a normal character. We use this as the
-- fallback when the user has NO custom state animations set.
local function _setCloneDefaultAnimate(enabled)
    if not ReanimateAPI or not ReanimateAPI.get_clone then return end
    local clone = ReanimateAPI.get_clone(plr)
    if not clone then return end
    pcall(function()
        local animate = clone:FindFirstChild("Animate")
        if animate then animate.Disabled = (enabled == false) end
    end)
end
-- Expose so the enable flow / CharacterAdded handler can reach it.
_applyReanimDefaultAnimate = _setCloneDefaultAnimate

-- When suspended, ALL reanimation-driven animation is stopped and prevented from
-- restarting (used by Face Bang so the clone holds still instead of animating).
local _reanimAnimsSuspended = false

startStateSystem = function()
    if stateSystemActive then stopStateSystem() end
    if _reanimAnimsSuspended then return end
    local char = plr.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    -- Always watch movement, even when every row is still "None".
    -- None plays your normal idle / walk / run / jump.
    _setCloneDefaultAnimate(false)

    stateSystemActive = true
    _stateFallbackActive = false
    local lastLogical = nil

    stateWatchConn = RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function()
        if not State.isReanimated then stopStateSystem(); return end
        -- FPS optimization: throttle state checks to 20Hz instead of every frame
        _stateCheckThrottle = (_stateCheckThrottle or 0) + 1
        if _stateCheckThrottle % 2 ~= 0 then return end
        if State.selectedAnim then
            if currentStateAnim then currentStateAnim = nil end
            -- A manually selected animation takes priority — make sure the
            -- default-Animate fallback isn't left on fighting it.
            _setStateFallback(false)
            lastLogical = nil
            return
        end
        local liveHum = hum
        pcall(function()
            local clone = ReanimateAPI and ReanimateAPI.get_clone and ReanimateAPI.get_clone(plr)
            local h = clone and clone:FindFirstChildOfClass("Humanoid")
            if h then liveHum = h end
        end)
        local logical
        if type(_G._PrismStateHysteresis) == "function" then
            logical = _G._PrismStateHysteresis(liveHum, lastLogical)
        else
            logical = getLogicalState(liveHum)
        end
        if logical ~= lastLogical then
            lastLogical = logical
            playStateAnim(logical)
        end
    end))
end

plr.CharacterAdded:Connect(function(character)
    stopStateSystem()
    currentStateAnim = nil
    character:WaitForChild("HumanoidRootPart", 10)
    task.wait(0.5)
    if State.isReanimated and not _reanimAnimsSuspended then
        startStateSystem()
    end
end)

-- Stop EVERY reanimation animation (state system, any playing clip, and the
-- clone's default Animate) and keep them stopped until resumed. Used by Face Bang.
_G._HaloStopReanimAnims = function()
    _reanimAnimsSuspended = true
    pcall(stopStateSystem)
    pcall(function() ReanimateAPI.stop_animation() end)
    _setCloneDefaultAnimate(false)
    -- Also stop any tracks playing on the clone's own Animator
    pcall(function()
        local clone = ReanimateAPI.get_clone and ReanimateAPI.get_clone(plr)
        if clone then
            local h  = clone:FindFirstChildOfClass("Humanoid")
            local an = h and h:FindFirstChildOfClass("Animator")
            if an then
                for _, t in ipairs(an:GetPlayingAnimationTracks()) do pcall(function() t:Stop(0) end) end
            end
        end
    end)
end

-- Re-allow reanimation animations and restore the correct mode.
_G._HaloResumeReanimAnims = function()
    _reanimAnimsSuspended = false
    if not State.isReanimated then return end
    if next(StateAnims) then
        startStateSystem()
    else
        _setCloneDefaultAnimate(true)
    end
end

local DropdownOverlay = Instance.new("Frame"); DropdownOverlay.Parent = StatesPanel
DropdownOverlay.Name = "DropdownOverlay"
DropdownOverlay.BackgroundColor3 = C.bg0
DropdownOverlay.BackgroundTransparency = 0.05
DropdownOverlay.BorderSizePixel = 0
DropdownOverlay.Size = UDim2.new(1, 0, 0, 240)
DropdownOverlay.Position = UDim2.new(0, 0, 0, 0)
DropdownOverlay.LayoutOrder = 99
DropdownOverlay.ZIndex = 200
DropdownOverlay.Visible = false
DropdownOverlay.ClipsDescendants = true
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = DropdownOverlay
    local s = Instance.new("UIStroke"); s.Color = C.border
    s.Transparency = 0.5; s.Thickness = 1.2; s.Parent = DropdownOverlay
end

local ddHeader = Instance.new("Frame"); ddHeader.Parent = DropdownOverlay
ddHeader.BackgroundColor3 = Color3.fromRGB(255,255,255); ddHeader.BackgroundTransparency = 0.95
ddHeader.BorderSizePixel = 0; ddHeader.Size = UDim2.new(1,0,0,32); ddHeader.ZIndex = 201
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,10); c.Parent = ddHeader end

local ddTitle = Instance.new("TextLabel"); ddTitle.Parent = ddHeader
ddTitle.BackgroundTransparency = 1; ddTitle.Position = UDim2.new(0,10,0,0)
ddTitle.Size = UDim2.new(1,-40,1,0); ddTitle.Font = Enum.Font.GothamBold
ddTitle.Text = "Select Animation"; ddTitle.TextColor3 = Color3.fromRGB(255,255,255)
ddTitle.TextSize = 12; ddTitle.TextXAlignment = Enum.TextXAlignment.Left; ddTitle.ZIndex = 202

local ddClose = Instance.new("TextButton"); ddClose.Parent = ddHeader
ddClose.AnchorPoint = Vector2.new(1,0.5); ddClose.Position = UDim2.new(1,-6,0.5,0)
ddClose.Size = UDim2.new(0,22,0,22); ddClose.BackgroundColor3 = Color3.fromRGB(255,80,80)
ddClose.BackgroundTransparency = 0.3; ddClose.BorderSizePixel = 0
ddClose.Font = Enum.Font.GothamBold; ddClose.Text = "X"
ddClose.TextColor3 = Color3.fromRGB(255,255,255); ddClose.TextSize = 14
ddClose.ZIndex = 202; ddClose.AutoButtonColor = false
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,6); c.Parent = ddClose end

local ddSearch = Instance.new("TextBox"); ddSearch.Parent = DropdownOverlay
ddSearch.BackgroundColor3 = C.bg1; ddSearch.BackgroundTransparency = 0.4
ddSearch.BorderSizePixel = 0; ddSearch.Position = UDim2.new(0,8,0,38)
ddSearch.Size = UDim2.new(1,-16,0,28); ddSearch.ZIndex = 201
ddSearch.Font = Enum.Font.Gotham; ddSearch.PlaceholderText = "Search animations..."
ddSearch.PlaceholderColor3 = C.text3; ddSearch.Text = ""
ddSearch.TextColor3 = C.text; ddSearch.TextSize = 11
ddSearch.ClearTextOnFocus = false
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,6); c.Parent = ddSearch
    local p = Instance.new("UIPadding"); p.PaddingLeft = UDim.new(0,8); p.Parent = ddSearch
    local s = Instance.new("UIStroke"); s.Color = C.border; s.Transparency = 0.7; s.Thickness = 1; s.Parent = ddSearch
end

local ddList = Instance.new("ScrollingFrame"); ddList.Parent = DropdownOverlay
ddList.BackgroundTransparency = 1; ddList.BorderSizePixel = 0
ddList.Position = UDim2.new(0,8,0,72); ddList.Size = UDim2.new(1,-16,1,-80)
ddList.ScrollBarThickness = 3; ddList.ScrollBarImageColor3 = C.accent
ddList.ScrollBarImageTransparency = 0.5; ddList.ZIndex = 201
ddList.CanvasSize = UDim2.new(0,0,0,0)
do
    local l = Instance.new("UIListLayout"); l.Parent = ddList; l.Padding = UDim.new(0,3)
    l:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        ddList.CanvasSize = UDim2.new(0,0,0,l.AbsoluteContentSize.Y+6)
    end)
end

local ddCallback   = nil
local ddStateLabel = nil
local ddAllEntries = {}

function CloseDropdown()
    DropdownOverlay.Visible = false
    ddSearch.Text = ""; ddCallback = nil; ddStateLabel = nil
    for _, c in ipairs(ddList:GetChildren()) do
        if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end
    end
end

ddClose.MouseButton1Click:Connect(CloseDropdown)

local DD_MAX_ITEMS = 60
function PopulateDropdown(term)
    for _, c in ipairs(ddList:GetChildren()) do
        if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end
    end
    term = (term or ""):lower()
    local count = 0
    for _, entry in ipairs(ddAllEntries) do
        if count >= DD_MAX_ITEMS then
            local hint = Instance.new("TextLabel"); hint.Parent = ddList
            hint.BackgroundTransparency = 1; hint.Size = UDim2.new(1,0,0,22); hint.ZIndex = 202
            hint.Font = Enum.Font.GothamMedium; hint.Text = "Type to search for more..."
            hint.TextColor3 = C.text3; hint.TextSize = 10
            break
        end
        if term == "" or entry.name:lower():find(term, 1, true) then
            count = count + 1
            local btn = Instance.new("TextButton"); btn.Parent = ddList
            btn.BackgroundColor3 = C.bg2; btn.BackgroundTransparency = 0.5
            btn.BorderSizePixel = 0; btn.Size = UDim2.new(1,0,0,28); btn.ZIndex = 202
            btn.Font = Enum.Font.GothamMedium; btn.Text = entry.name
            btn.TextColor3 = C.text2; btn.TextSize = 11
            btn.TextXAlignment = Enum.TextXAlignment.Left; btn.AutoButtonColor = false
            btn.TextTruncate = Enum.TextTruncate.AtEnd
            do
                local c2 = Instance.new("UICorner"); c2.CornerRadius = UDim.new(0,5); c2.Parent = btn
                local p2 = Instance.new("UIPadding"); p2.PaddingLeft = UDim.new(0,8); p2.Parent = btn
                local s2 = Instance.new("UIStroke"); s2.Color = C.border; s2.Transparency = 0.8; s2.Thickness = 1; s2.Parent = btn
            end
            btn.MouseEnter:Connect(function()
                TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundTransparency = 0.7}):Play()
            end)
            btn.MouseLeave:Connect(function()
                TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundTransparency = 0.93}):Play()
            end)
            local e = entry
            btn.MouseButton1Click:Connect(function()
                if ddCallback then ddCallback(e.name, e.url) end
                CloseDropdown()
            end)
        end
    end
end

local _ddSearchDebounce = nil
ddSearch:GetPropertyChangedSignal("Text"):Connect(function()
    if _ddSearchDebounce then task.cancel(_ddSearchDebounce) end
    _ddSearchDebounce = task.delay(0.12, function()
        _ddSearchDebounce = nil
        PopulateDropdown(ddSearch.Text)
    end)
end)

function OpenDropdown(stateType, displayBtn, onPick)
    ddAllEntries = {}
    for name, url in pairs(AnimationList) do
        table.insert(ddAllEntries, { name=name, url=url })
    end
    for _, ca in ipairs(CustomAnims) do
        table.insert(ddAllEntries, { name="[Custom] "..ca.name, url=ca.url })
    end
    table.sort(ddAllEntries, function(a,b) return a.name < b.name end)

    ddCallback   = onPick
    ddStateLabel = displayBtn
    ddTitle.Text = "Pick: " .. stateType
    ddSearch.Text = ""
    DropdownOverlay.Parent = Menu
    local btnPos = displayBtn.AbsolutePosition
    local menuPos = Menu.AbsolutePosition
    local y = math.clamp(btnPos.Y - menuPos.Y + displayBtn.AbsoluteSize.Y + 4, 40, Menu.AbsoluteSize.Y - 230)
    DropdownOverlay.Position = UDim2.fromOffset(8, y)
    DropdownOverlay.Size = UDim2.new(1, -16, 0, 220)
    DropdownOverlay.Visible = true
    PopulateDropdown("")
    ddSearch:CaptureFocus()
end

local AddCustomModal = Instance.new("Frame"); AddCustomModal.Parent = Menu
AddCustomModal.Name = "AddCustomModal"
AddCustomModal.BackgroundColor3 = C.bg1
AddCustomModal.BackgroundTransparency = 0.05; AddCustomModal.BorderSizePixel = 0
AddCustomModal.Size = UDim2.new(1, 0, 1, -40); AddCustomModal.Position = UDim2.new(0, 0, 0, 40)
AddCustomModal.ZIndex = 100; AddCustomModal.Visible = false; AddCustomModal.ClipsDescendants = true
-- Modal backdrop for blur effect
local ModalBackdrop = Instance.new("Frame"); ModalBackdrop.Name = "Backdrop"
ModalBackdrop.Parent = AddCustomModal; ModalBackdrop.BackgroundColor3 = Color3.fromRGB(0,0,0)
ModalBackdrop.BackgroundTransparency = 0; ModalBackdrop.BorderSizePixel = 0
ModalBackdrop.Size = UDim2.new(1,0,1,0); ModalBackdrop.ZIndex = 99
ModalBackdrop.Visible = false
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 16); c.Parent = AddCustomModal
    local s = Instance.new("UIStroke"); s.Color = C.accent
    s.Transparency = 0.4; s.Thickness = 1.5; s.Parent = AddCustomModal
end

local acmHeader = Instance.new("Frame"); acmHeader.Parent = AddCustomModal
acmHeader.BackgroundColor3 = C.bg2; acmHeader.BackgroundTransparency = 0.4
acmHeader.BorderSizePixel = 0; acmHeader.Size = UDim2.new(1,0,0,38); acmHeader.ZIndex = 101
do
    local div = Instance.new("Frame"); div.Parent = acmHeader
    div.BackgroundColor3 = C.glassBorder; div.BackgroundTransparency = 0.7
    div.BorderSizePixel = 0; div.Position = UDim2.new(0,0,1,-1)
    div.Size = UDim2.new(1,0,0,1); div.ZIndex = 102
end

local acmTitle = Instance.new("TextLabel"); acmTitle.Parent = acmHeader
acmTitle.BackgroundTransparency = 1; acmTitle.Position = UDim2.new(0,14,0,0)
acmTitle.Size = UDim2.new(1,-50,1,0); acmTitle.Font = Enum.Font.GothamBold
acmTitle.Text = "Add Custom Animation"; acmTitle.TextColor3 = Color3.fromRGB(255,255,255)
acmTitle.TextSize = 13; acmTitle.TextXAlignment = Enum.TextXAlignment.Left; acmTitle.ZIndex = 102

local acmCloseBtn = Instance.new("TextButton"); acmCloseBtn.Parent = acmHeader
acmCloseBtn.AnchorPoint = Vector2.new(1,0.5); acmCloseBtn.Position = UDim2.new(1,-10,0.5,0)
acmCloseBtn.Size = UDim2.new(0,22,0,22); acmCloseBtn.BackgroundColor3 = C.accent
acmCloseBtn.BackgroundTransparency = 0.3; acmCloseBtn.BorderSizePixel = 0
acmCloseBtn.Font = Enum.Font.GothamBold; acmCloseBtn.Text = ""
acmCloseBtn.TextColor3 = Color3.fromRGB(10,10,10); acmCloseBtn.TextSize = 14
acmCloseBtn.ZIndex = 102; acmCloseBtn.AutoButtonColor = false
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,6); c.Parent = acmCloseBtn
    local ico = Instance.new("ImageLabel"); ico.Parent = acmCloseBtn
    ico.BackgroundTransparency = 1; ico.AnchorPoint = Vector2.new(0.5,0.5)
    ico.Position = UDim2.new(0.5,0,0.5,0); ico.Size = UDim2.new(0,10,0,10)
    ico.Image = "rbxassetid://6031094678"; ico.ImageColor3 = Color3.fromRGB(10,10,10); ico.ZIndex = 103
end

local acmBody = Instance.new("Frame"); acmBody.Parent = AddCustomModal
acmBody.BackgroundTransparency = 1; acmBody.Position = UDim2.new(0,12,0,46)
acmBody.Size = UDim2.new(1,-24,1,-96); acmBody.ZIndex = 101

local acmNameLbl = Instance.new("TextLabel"); acmNameLbl.Parent = acmBody
acmNameLbl.BackgroundTransparency = 1; acmNameLbl.Position = UDim2.new(0,0,0,0)
acmNameLbl.Size = UDim2.new(1,0,0,16); acmNameLbl.Font = Enum.Font.GothamSemibold
acmNameLbl.Text = "Animation Name"; acmNameLbl.TextColor3 = C.accent
acmNameLbl.TextSize = 10; acmNameLbl.TextXAlignment = Enum.TextXAlignment.Left; acmNameLbl.ZIndex = 102

local acmNameBox = Instance.new("TextBox"); acmNameBox.Parent = acmBody
acmNameBox.BackgroundColor3 = C.bg2; acmNameBox.BackgroundTransparency = 0.3
acmNameBox.BorderSizePixel = 0; acmNameBox.Position = UDim2.new(0,0,0,18)
acmNameBox.Size = UDim2.new(1,0,0,28); acmNameBox.ZIndex = 102
acmNameBox.Font = Enum.Font.Gotham; acmNameBox.PlaceholderText = "Leave empty to auto-generate"
acmNameBox.PlaceholderColor3 = C.text3
acmNameBox.Text = ""; acmNameBox.TextColor3 = C.text; acmNameBox.TextSize = 11
acmNameBox.ClearTextOnFocus = false
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,6); c.Parent = acmNameBox
    local p = Instance.new("UIPadding"); p.PaddingLeft = UDim.new(0,9); p.Parent = acmNameBox
    local s = Instance.new("UIStroke"); s.Color = C.accent; s.Transparency = 0.7; s.Thickness = 1; s.Parent = acmNameBox
end

local acmDataLbl = Instance.new("TextLabel"); acmDataLbl.Parent = acmBody
acmDataLbl.BackgroundTransparency = 1; acmDataLbl.Position = UDim2.new(0,0,0,54)
acmDataLbl.Size = UDim2.new(1,0,0,16); acmDataLbl.Font = Enum.Font.GothamSemibold
acmDataLbl.Text = "Keyframes Script"; acmDataLbl.TextColor3 = C.accent
acmDataLbl.TextSize = 10; acmDataLbl.TextXAlignment = Enum.TextXAlignment.Left; acmDataLbl.ZIndex = 102

local acmDataSub = Instance.new("TextLabel"); acmDataSub.Parent = acmBody
acmDataSub.BackgroundTransparency = 1; acmDataSub.Position = UDim2.new(0,0,0,70)
acmDataSub.Size = UDim2.new(1,0,0,12); acmDataSub.Font = Enum.Font.Gotham
acmDataSub.Text = "Click the box below, then Ctrl+V to paste"
acmDataSub.TextColor3 = C.text3; acmDataSub.TextSize = 9
acmDataSub.TextXAlignment = Enum.TextXAlignment.Left; acmDataSub.ZIndex = 102

local acmDataBox = Instance.new("TextBox"); acmDataBox.Parent = acmBody
acmDataBox.BackgroundColor3 = C.bg2; acmDataBox.BackgroundTransparency = 0.3
acmDataBox.BorderSizePixel = 0; acmDataBox.Position = UDim2.new(0,0,0,84)
acmDataBox.Size = UDim2.new(1,0,1,-148); acmDataBox.ZIndex = 102
acmDataBox.Font = Enum.Font.Code; acmDataBox.MultiLine = true; acmDataBox.ClearTextOnFocus = false
acmDataBox.TextWrapped = true; acmDataBox.ClipsDescendants = true
acmDataBox.PlaceholderText = "Paste keyframe script here..."
acmDataBox.PlaceholderColor3 = C.text3
acmDataBox.Text = ""; acmDataBox.TextColor3 = C.green; acmDataBox.TextSize = 10
acmDataBox.TextXAlignment = Enum.TextXAlignment.Left; acmDataBox.TextYAlignment = Enum.TextYAlignment.Top
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,6); c.Parent = acmDataBox
    local s = Instance.new("UIStroke"); s.Color = C.accent; s.Transparency = 0.7; s.Thickness = 1; s.Parent = acmDataBox
    local p = Instance.new("UIPadding"); p.PaddingLeft = UDim.new(0,8); p.PaddingTop = UDim.new(0,8); p.Parent = acmDataBox
end

local acmStatusLbl = Instance.new("TextLabel"); acmStatusLbl.Parent = acmBody
acmStatusLbl.BackgroundTransparency = 1; acmStatusLbl.Position = UDim2.new(0,0,1,-52)
acmStatusLbl.Size = UDim2.new(1,0,0,12); acmStatusLbl.Font = Enum.Font.GothamSemibold
acmStatusLbl.Text = "Status"; acmStatusLbl.TextColor3 = C.accent
acmStatusLbl.TextSize = 9; acmStatusLbl.TextXAlignment = Enum.TextXAlignment.Left; acmStatusLbl.ZIndex = 102

local acmStatus = Instance.new("TextLabel"); acmStatus.Parent = acmBody
acmStatus.BackgroundTransparency = 1; acmStatus.Position = UDim2.new(0,0,1,-38)
acmStatus.Size = UDim2.new(1,0,0,30); acmStatus.Font = Enum.Font.Gotham; acmStatus.TextWrapped = true
acmStatus.Text = "Enter keyframes data to add custom animation"
acmStatus.TextColor3 = C.text3; acmStatus.TextSize = 10
acmStatus.TextXAlignment = Enum.TextXAlignment.Left; acmStatus.ZIndex = 102

local acmBtnRow = Instance.new("Frame"); acmBtnRow.Parent = AddCustomModal
acmBtnRow.BackgroundTransparency = 1; acmBtnRow.BorderSizePixel = 0
acmBtnRow.AnchorPoint = Vector2.new(0,1); acmBtnRow.Position = UDim2.new(0,12,1,-10)
acmBtnRow.Size = UDim2.new(1,-24,0,34); acmBtnRow.ZIndex = 101

local acmCancelBtn = Instance.new("TextButton"); acmCancelBtn.Parent = acmBtnRow
acmCancelBtn.BackgroundColor3 = C.bg2; acmCancelBtn.BackgroundTransparency = 0.3
acmCancelBtn.BorderSizePixel = 0; acmCancelBtn.Size = UDim2.new(0.44,0,1,0)
acmCancelBtn.Font = Enum.Font.GothamSemibold; acmCancelBtn.Text = "Cancel"
acmCancelBtn.TextColor3 = C.text2; acmCancelBtn.TextSize = 11
acmCancelBtn.ZIndex = 102; acmCancelBtn.AutoButtonColor = false
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,7); c.Parent = acmCancelBtn
    local s = Instance.new("UIStroke"); s.Color = C.border; s.Transparency = 0.7; s.Parent = acmCancelBtn
end
acmCancelBtn.MouseEnter:Connect(function()
    TweenService:Create(acmCancelBtn, TweenInfo.new(0.1), {BackgroundColor3 = C.bg3, BackgroundTransparency = 0.2}):Play()
end)
acmCancelBtn.MouseLeave:Connect(function()
    TweenService:Create(acmCancelBtn, TweenInfo.new(0.1), {BackgroundColor3 = C.bg2, BackgroundTransparency = 0.3}):Play()
end)

local acmAddBtn = Instance.new("TextButton"); acmAddBtn.Parent = acmBtnRow
acmAddBtn.AnchorPoint = Vector2.new(1,0); acmAddBtn.Position = UDim2.new(1,0,0,0)
acmAddBtn.BackgroundColor3 = C.accent; acmAddBtn.BackgroundTransparency = 0.2
acmAddBtn.BorderSizePixel = 0; acmAddBtn.Size = UDim2.new(0.52,0,1,0)
acmAddBtn.Font = Enum.Font.GothamBold; acmAddBtn.Text = "Add Animation"
acmAddBtn.TextColor3 = Color3.fromRGB(10,10,10); acmAddBtn.TextSize = 11
acmAddBtn.ZIndex = 102; acmAddBtn.AutoButtonColor = false
do 
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,7); c.Parent = acmAddBtn
    local s = Instance.new("UIStroke"); s.Color = C.accent; s.Transparency = 0.5; s.Thickness = 1; s.Parent = acmAddBtn
end
acmAddBtn.MouseEnter:Connect(function()
    TweenService:Create(acmAddBtn, TweenInfo.new(0.1), {BackgroundTransparency = 0}):Play()
end)
acmAddBtn.MouseLeave:Connect(function()
    TweenService:Create(acmAddBtn, TweenInfo.new(0.1), {BackgroundTransparency = 0.15}):Play()
end)

local acmBoxFocused = false
local _pendingPasteData = nil
acmDataBox.Focused:Connect(function() acmBoxFocused = true end)
acmDataBox.FocusLost:Connect(function() acmBoxFocused = false end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if not acmBoxFocused then return end
    if input.KeyCode == Enum.KeyCode.V
    and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
      or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
        task.spawn(function()
            local ok, clip = pcall(getclipboard)
            if ok and type(clip) == "string" and #clip > 0 then
                _pendingPasteData = clip
                local preview = #clip > 200 and clip:sub(1, 200) .. "..." or clip
                acmDataBox.Text = preview
                acmStatus.Text = "Loaded " .. tostring(#clip) .. " chars"
                acmStatus.TextColor3 = Color3.fromRGB(100,220,140)
            end
        end)
    end
end)

function CloseAddCustomModal()
    -- Animate out
    TweenService:Create(AddCustomModal, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        BackgroundTransparency = 1
    }):Play()
    if ModalBackdrop then
        TweenService:Create(ModalBackdrop, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
    end
    task.delay(0.22, function()
        AddCustomModal.Visible = false
        if ModalBackdrop then ModalBackdrop.Visible = false end
        AddCustomModal.BackgroundTransparency = 0.05
        acmNameBox.Text = ""; acmDataBox.Text = ""
        acmStatus.Text = "Enter keyframes data to add custom animation"
        acmStatus.TextColor3 = C.text3
    end)
end

acmCloseBtn.MouseButton1Click:Connect(CloseAddCustomModal)
acmCancelBtn.MouseButton1Click:Connect(CloseAddCustomModal)

customOpenModalBtn.MouseButton1Click:Connect(function()
    _pendingPasteData = nil
    acmNameBox.Text = ""; acmDataBox.Text = ""
    acmStatus.Text = "Enter keyframes data to add custom animation"
    acmStatus.TextColor3 = C.text3
    AddCustomModal.Visible = true
    AddCustomModal.BackgroundTransparency = 1
    if ModalBackdrop then ModalBackdrop.Visible = true; ModalBackdrop.BackgroundTransparency = 1 end
    TweenService:Create(AddCustomModal, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.05}):Play()
    if ModalBackdrop then
        TweenService:Create(ModalBackdrop, TweenInfo.new(0.25), {BackgroundTransparency = 0.5}):Play()
    end
    acmNameBox:CaptureFocus()
end)

acmAddBtn.MouseButton1Click:Connect(function()
    -- Use _pendingPasteData if available (large pastes), else use TextBox text
    local rawData = _pendingPasteData or acmDataBox.Text
    rawData = rawData and rawData:gsub("^%s+", ""):gsub("%s+$", "") or ""
    if rawData == "" then
        acmStatus.Text = "Please paste keyframe data first."
        acmStatus.TextColor3 = Color3.fromRGB(255,160,80); return
    end
    -- Grab name immediately before spawning (TextBox state may change)
    local capturedName = acmNameBox.Text:match("^%s*(.-)%s*$")
    local capturedRaw  = rawData
    local capturedPaste = _pendingPasteData

    acmStatus.Text = "Validating..."; acmStatus.TextColor3 = Color3.fromRGB(180,180,220)
    -- Disable button to prevent double-submit
    acmAddBtn.Active = false

    task.spawn(function()
        local isJson = false

        -- Check if it's a file path
        if capturedRaw:match("^[A-Za-z]:\\") or capturedRaw:match("^/") then
            acmStatus.Text = "Reading file..."
            local fileContent
            local ok, err = pcall(function()
                if isfile and isfile(capturedRaw) then
                    fileContent = readfile(capturedRaw)
                else
                    local file = io.open(capturedRaw, "r")
                    if file then fileContent = file:read("*a"); file:close() end
                end
            end)
            if not ok or not fileContent then
                acmStatus.Text = "Failed to read file: " .. tostring(err or "file not found")
                acmStatus.TextColor3 = Color3.fromRGB(255,90,90)
                acmAddBtn.Active = true; return
            end
            capturedRaw = fileContent
        end

        -- NON-BLOCKING ADD: do NOT parse the animation here. Parsing/JSON-decoding
        -- and building keyframe CFrames for a large animation froze the game. We
        -- just store the raw data; PlayAnimation parses it (and seeds the cache)
        -- on the first play, then it's cached like normal.
        local firstChar = capturedRaw:match("^%s*(.)")
        isJson = (firstChar == "{" or firstChar == "[")

        -- Cheap sanity check only (no parsing): keyframe data always has a table.
        if not capturedRaw:find("{", 1, true) then
            acmStatus.Text = "That doesn't look like keyframe data."
            acmStatus.TextColor3 = Color3.fromRGB(255,90,90)
            acmAddBtn.Active = true; return
        end

        local name = capturedName ~= "" and capturedName or ("Custom_" .. tostring(#CustomAnims + 1))

        -- Insert into live tables immediately so the UI sees the new anim
        if #capturedRaw > _SAVE_INLINE_MAX then
            -- Write large data to its own file (we're already on a spawned thread)
            local safeFileName = fpath("custom_" .. name:gsub("[^%w_%-]", "_") .. ".dat")
            pcall(function() writefile(safeFileName, capturedRaw) end)
            table.insert(CustomAnims, { name = name, url = safeFileName, raw = true, isJson = isJson })
            CustomAnimations[name] = safeFileName
        else
            table.insert(CustomAnims, { name = name, url = capturedRaw, raw = true, isJson = isJson })
            CustomAnimations[name] = capturedRaw
        end

        -- Persist (SaveCustomAnims is already debounced + async internally)
        SaveCustomAnims()
        SaveData()

        -- Append the newly inserted entry to the UI
        local newEntry = CustomAnims[#CustomAnims]
        if newEntry and type(AppendCustomRow) == "function" then
            AppendCustomRow(newEntry)
        end
        
        -- Update Custom tab count after adding animation
        if UpdateCustomTabCount then
            UpdateCustomTabCount()
        end
        
        Notify("Added: " .. name, 2)
        _pendingPasteData = nil
        acmAddBtn.Active = true
        CloseAddCustomModal()
    end)
end)

local stateDisplayBtns = {}

function BuildStatesPanel()
    for _, c in ipairs(StatesPanel:GetChildren()) do
        if c ~= DropdownOverlay and not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end
    end
    stateDisplayBtns = {}

    for i, stType in ipairs(STATE_TYPES) do
        local row = Instance.new("Frame"); row.Parent = StatesPanel
        row.BackgroundColor3 = C.bg1; row.BackgroundTransparency = 0.2
        row.BorderSizePixel = 0; row.Size = UDim2.new(1,0,0,44); row.ZIndex = 34
        row.LayoutOrder = i
        do
            local cr = Instance.new("UICorner"); cr.CornerRadius = UDim.new(0,10); cr.Parent = row
            local s = Instance.new("UIStroke"); s.Color = C.border; s.Transparency = 0.5; s.Thickness = 1; s.Parent = row
        end

        local typeLbl = Instance.new("TextLabel"); typeLbl.Parent = row
        typeLbl.BackgroundTransparency = 1; typeLbl.Position = UDim2.new(0,14,0,0)
        typeLbl.Size = UDim2.new(0,65,1,0); typeLbl.Font = Enum.Font.GothamBold
        typeLbl.Text = stType; typeLbl.TextColor3 = C.accent; typeLbl.TextSize = 12
        typeLbl.TextXAlignment = Enum.TextXAlignment.Left; typeLbl.ZIndex = 35

        local currentName = "None"
        if StateAnims[stType] then
            local entry   = StateAnims[stType]
            local savedUrl = type(entry) == "table" and entry.url or entry
            for name, url in pairs(AnimationList) do
                if url == savedUrl then currentName = name; break end
            end
            if currentName == "None" then
                for _, ca in ipairs(CustomAnims) do
                    if ca.url == savedUrl then currentName = ca.name; break end
                end
            end
            if currentName == "None" then currentName = "Saved" end
        end

        local displayBtn = Instance.new("TextButton"); displayBtn.Parent = row
        displayBtn.Position = UDim2.new(0,85,0,8); displayBtn.Size = UDim2.new(1,-145,0,28)
        displayBtn.BackgroundColor3 = C.bg2; displayBtn.BackgroundTransparency = 0.4
        displayBtn.BorderSizePixel = 0; displayBtn.ZIndex = 35
        displayBtn.Font = Enum.Font.GothamMedium; displayBtn.Text = currentName
        displayBtn.TextColor3 = currentName == "None" and C.text3 or Color3.fromRGB(100, 200, 100)
        displayBtn.TextSize = 11; displayBtn.TextXAlignment = Enum.TextXAlignment.Left
        displayBtn.TextTruncate = Enum.TextTruncate.AtEnd; displayBtn.AutoButtonColor = false
        do
            local cr = Instance.new("UICorner"); cr.CornerRadius = UDim.new(0,7); cr.Parent = displayBtn
            local pd = Instance.new("UIPadding"); pd.PaddingLeft = UDim.new(0,12); pd.PaddingRight = UDim.new(0,24); pd.Parent = displayBtn
            local chev = Instance.new("ImageLabel"); chev.Parent = displayBtn
            chev.BackgroundTransparency = 1; chev.AnchorPoint = Vector2.new(1,0.5)
            chev.Position = UDim2.new(1,-2,0.5,0); chev.Size = UDim2.new(0,12,0,12)
            chev.Image = "rbxassetid://6034818372"
            chev.ImageColor3 = C.text3; chev.ZIndex = 36
        end

        local clrBtn = Instance.new("TextButton"); clrBtn.Parent = row
        clrBtn.AnchorPoint = Vector2.new(1,0.5); clrBtn.Position = UDim2.new(1,-10,0.5,0)
        clrBtn.Size = UDim2.new(0,52,0,28); clrBtn.BackgroundColor3 = C.bg2
        clrBtn.BackgroundTransparency = 0.3; clrBtn.BorderSizePixel = 0
        clrBtn.Font = Enum.Font.GothamBold; clrBtn.Text = "Clear"
        clrBtn.TextColor3 = C.text2; clrBtn.TextSize = 10; clrBtn.ZIndex = 35
        do
            local cr = Instance.new("UICorner"); cr.CornerRadius = UDim.new(0,7); cr.Parent = clrBtn
            local s = Instance.new("UIStroke"); s.Color = C.border; s.Transparency = 0.6; s.Thickness = 1; s.Parent = clrBtn
        end

        stateDisplayBtns[stType] = displayBtn

        displayBtn.MouseEnter:Connect(function()
            TweenService:Create(displayBtn, TweenInfo.new(0.15), {BackgroundColor3 = C.bg3, BackgroundTransparency = 0.2}):Play()
        end)
        displayBtn.MouseLeave:Connect(function()
            TweenService:Create(displayBtn, TweenInfo.new(0.15), {BackgroundColor3 = C.bg2, BackgroundTransparency = 0.4}):Play()
        end)

        clrBtn.MouseEnter:Connect(function()
            TweenService:Create(clrBtn, TweenInfo.new(0.15), {BackgroundColor3 = C.red, BackgroundTransparency = 0.2, TextColor3 = C.white}):Play()
        end)
        clrBtn.MouseLeave:Connect(function()
            TweenService:Create(clrBtn, TweenInfo.new(0.15), {BackgroundColor3 = C.bg2, BackgroundTransparency = 0.3, TextColor3 = C.text2}):Play()
        end)

        local st = stType; local db = displayBtn

        displayBtn.MouseButton1Click:Connect(function()
            if DropdownOverlay.Visible and ddStateLabel == db then CloseDropdown(); return end
            OpenDropdown(st, db, function(animName, animUrl)
                local isRaw = false
                for _, ca in ipairs(CustomAnims) do
                    if ca.url == animUrl then isRaw = ca.raw == true; break end
                end
                if not isRaw and type(animUrl) == "string" then
                    -- Check if it's Lua code (starts with return)
                    isRaw = animUrl:match("^%s*return") ~= nil
                end
                if not isRaw and type(animUrl) == "string" and animUrl:match("^https?://") then
                    -- HTTP URLs are raw
                    isRaw = true
                end
                if not isRaw and type(animUrl) == "string" and isfile and pcall(isfile, animUrl) and isfile(animUrl) then
                    -- Local file paths are raw (need to be loaded and parsed)
                    isRaw = true
                end
                warn("[StateAnim] Assigning", animName, "to", st, "- URL:", animUrl, "- isRaw:", isRaw)
                StateAnims[st] = { url = animUrl, raw = isRaw }
                SaveData()
                prefetchStateAnim(st)
                db.Text = animName; db.TextColor3 = Color3.fromRGB(100, 200, 100)
                if State.isReanimated then stopStateSystem(); startStateSystem() end
                Notify(st .. " -> " .. animName, 2)
            end)
        end)

        clrBtn.MouseButton1Click:Connect(function()
            StateAnims[st] = nil
            db.Text = "None"; db.TextColor3 = C.text3
            SaveData()
            if State.isReanimated then
                stopStateSystem()
                if next(StateAnims) then
                    startStateSystem()
                elseif _applyReanimDefaultAnimate then
                    -- Last custom state removed: revert to default Roblox animations.
                    _applyReanimDefaultAnimate(true)
                end
            end
            Notify(st .. " state cleared", 2)
            if DropdownOverlay.Visible and ddStateLabel == db then CloseDropdown() end
        end)
    end
end

local _statesPanelBuilt = false
function EnsureStatesPanelBuilt()
    if _statesPanelBuilt then return end
    _statesPanelBuilt = true
    BuildStatesPanel()
end

-- Lazy custom list — only build the custom-animation rows the first time the
-- Custom tab is actually opened, so opening the window never freezes building
-- rows for animations the user isn't even looking at yet.
local _customListBuilt = false
function EnsureCustomListBuilt()
    if _customListBuilt then return end
    _customListBuilt = true
    task.spawn(function()
        RebuildCustomList()
    end)
end

function SwitchTab(tabName)
    State.currentTab = tabName
    SetTabActive(TabButtons[tabName])
    if tabName == "States" then EnsureStatesPanelBuilt() end
    if tabName == "Custom" then EnsureCustomListBuilt() end
    if tabName == "Binds" then RebuildBindsList() end
    
    -- Hide all panels first
    AnimListFrame.Visible = false
    CustomPanel.Visible = false
    BindsPanel.Visible = false
    StatesPanel.Visible = false
    SettingsPanel.Visible = false
    SpeedPanel.Visible = false
    TestingPanel.Visible = false
    TrackerPanel.Visible = false
    
    -- Show the appropriate panel
    if tabName == "All" or tabName == "Favs" then
        AnimListFrame.Visible = true
    elseif tabName == "Custom" then
        CustomPanel.Visible = true
    elseif tabName == "Binds" then
        BindsPanel.Visible = true
    elseif tabName == "States" then
        StatesPanel.Visible = true
    elseif tabName == "Speed" then
        SpeedPanel.Visible = true
    elseif tabName == "Settings" then
        SettingsPanel.Visible = true
    elseif tabName == "Copier" then
        TestingPanel.Visible = true
    elseif tabName == "Tracker" then
        TrackerPanel.Visible = true
    end
    
    local noSearch = (tabName == "Custom" or tabName == "Settings" or tabName == "States" or tabName == "Speed" or tabName == "Binds" or tabName == "Copier" or tabName == "Tracker")
    SearchBox.Visible = not noSearch
    hintLbl.Visible   = not noSearch
    local listY = noSearch and 104 or 148
    AnimListFrame.Position = UDim2.new(0,10,0,listY)
    CustomPanel.Position   = UDim2.new(0,10,0,listY)
    BindsPanel.Position    = UDim2.new(0,10,0,listY)
    StatesPanel.Position   = UDim2.new(0,10,0,listY)
    SettingsPanel.Position = UDim2.new(0,10,0,listY)
    SpeedPanel.Position    = UDim2.new(0,10,0,listY)
    TrackerPanel.Position  = UDim2.new(0,10,0,listY)
    AnimListFrame.Size = UDim2.new(1,-20,1, noSearch and -112 or -156)
    CustomPanel.Size   = UDim2.new(1,-20,1, noSearch and -112 or -156)
    BindsPanel.Size    = UDim2.new(1,-20,1, noSearch and -112 or -156)
    StatesPanel.Size   = UDim2.new(1,-20,1, noSearch and -112 or -156)
    SettingsPanel.Size = UDim2.new(1,-20,1, noSearch and -112 or -156)
    SpeedPanel.Size    = UDim2.new(1,-20,1, noSearch and -112 or -156)
    TestingPanel.Size  = UDim2.new(1,-20,1, noSearch and -112 or -156)
    TrackerPanel.Size  = UDim2.new(1,-20,1, noSearch and -112 or -156)
    RebuildVisible()
end

for tname, tb in pairs(TabButtons) do
    tb.MouseButton1Click:Connect(function() SwitchTab(tname) end)
end

local SpeedTrack
local SpeedValueBox
local SpeedFill
local SpeedHandle
local SpeedLabel

do
    local bottomBar = Instance.new("Frame"); bottomBar.Parent = SpeedPanel
    bottomBar.BackgroundColor3 = C.bg1; bottomBar.BackgroundTransparency = 0.35
    bottomBar.BorderSizePixel = 0; bottomBar.Size = UDim2.new(1,0,0,196)
    bottomBar.Position = UDim2.new(0,0,0,0); bottomBar.ZIndex = 40
    bottomBar.LayoutOrder = 1
    do
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 12); c.Parent = bottomBar
    end

    -- Cover the top rounded corners of bottomBar to keep them flat
    local topCover = Instance.new("Frame"); topCover.Parent = bottomBar
    topCover.BackgroundColor3 = C.bg1; topCover.BackgroundTransparency = 0.35
    topCover.BorderSizePixel = 0; topCover.Size = UDim2.new(1,0,0,12)
    topCover.Position = UDim2.new(0,0,0,0); topCover.ZIndex = 40

    local sepLine = Instance.new("Frame"); sepLine.Parent = bottomBar
    sepLine.BackgroundColor3 = C.border; sepLine.BackgroundTransparency = 0.5
    sepLine.BorderSizePixel = 0; sepLine.Size = UDim2.new(1,0,0,1)
    sepLine.Position = UDim2.new(0,0,0,0); sepLine.ZIndex = 41

    local speedRow = Instance.new("Frame"); speedRow.Parent = bottomBar
    speedRow.BackgroundTransparency = 1; speedRow.Size = UDim2.new(1,-24,0,24)
    speedRow.AnchorPoint = Vector2.new(0,0); speedRow.Position = UDim2.new(0,12,0,14); speedRow.ZIndex = 41

    SpeedLabel = Instance.new("TextLabel"); SpeedLabel.Parent = speedRow
    SpeedLabel.BackgroundTransparency = 1; SpeedLabel.Size = UDim2.new(0,88,1,0)
    SpeedLabel.Font = Enum.Font.GothamBold; SpeedLabel.Text = "Speed: 1.0"
    SpeedLabel.TextColor3 = C.text
    SpeedLabel.TextSize = 10; SpeedLabel.TextXAlignment = Enum.TextXAlignment.Left; SpeedLabel.ZIndex = 42

    SpeedTrack = Instance.new("Frame"); SpeedTrack.Parent = speedRow
    SpeedTrack.BackgroundColor3 = C.bg2; SpeedTrack.BackgroundTransparency = 0.3
    SpeedTrack.BorderSizePixel = 0; SpeedTrack.Position = UDim2.new(0,96,0.5,-4)
    SpeedTrack.Size = UDim2.new(1,-200,0,8); SpeedTrack.ZIndex = 42
    do 
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1,0); c.Parent = SpeedTrack 
        local s = Instance.new("UIStroke"); s.Color = C.border; s.Transparency = 0.7; s.Thickness = 1; s.Parent = SpeedTrack
    end

    SpeedFill = Instance.new("Frame"); SpeedFill.Parent = SpeedTrack
    SpeedFill.BackgroundColor3 = C.accent; SpeedFill.BackgroundTransparency = 0.1
    SpeedFill.BorderSizePixel = 0; SpeedFill.Size = UDim2.new(0.231,0,1,0); SpeedFill.ZIndex = 43
    do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1,0); c.Parent = SpeedFill end

    SpeedHandle = Instance.new("Frame"); SpeedHandle.Parent = SpeedTrack
    SpeedHandle.AnchorPoint = Vector2.new(0.5,0.5)
    SpeedHandle.BackgroundColor3 = C.accent; SpeedHandle.BackgroundTransparency = 0
    SpeedHandle.BorderSizePixel = 0; SpeedHandle.Position = UDim2.new(0.231,0,0.5,0)
    SpeedHandle.Size = UDim2.new(0,12,0,12); SpeedHandle.ZIndex = 44
    do 
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1,0); c.Parent = SpeedHandle 
        local s = Instance.new("UIStroke"); s.Color = C.border; s.Transparency = 0.4; s.Thickness = 1; s.Parent = SpeedHandle
    end

    SpeedValueBox = Instance.new("TextBox"); SpeedValueBox.Parent = speedRow
    SpeedValueBox.AnchorPoint = Vector2.new(1,0.5)
    SpeedValueBox.BackgroundColor3 = C.bg2; SpeedValueBox.BackgroundTransparency = 0.3
    SpeedValueBox.BorderSizePixel = 0; SpeedValueBox.Position = UDim2.new(1,-54,0.5,0)
    SpeedValueBox.Size = UDim2.new(0,40,0,22); SpeedValueBox.Font = Enum.Font.GothamBold
    SpeedValueBox.Text = "1.0"; SpeedValueBox.TextColor3 = C.text2
    SpeedValueBox.TextSize = 9; SpeedValueBox.ZIndex = 42; SpeedValueBox.ClearTextOnFocus = false
    do 
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,4); c.Parent = SpeedValueBox 
        local s = Instance.new("UIStroke"); s.Color = C.border; s.Transparency = 0.7; s.Thickness = 1; s.Parent = SpeedValueBox
    end

    local SpeedResetBtn = Instance.new("TextButton"); SpeedResetBtn.Parent = speedRow
    SpeedResetBtn.AnchorPoint = Vector2.new(1,0.5)
    SpeedResetBtn.BackgroundColor3 = C.bg3; SpeedResetBtn.BackgroundTransparency = 0.2
    SpeedResetBtn.BorderSizePixel = 0; SpeedResetBtn.Position = UDim2.new(1,0,0.5,0)
    SpeedResetBtn.Size = UDim2.new(0,48,0,22); SpeedResetBtn.Font = Enum.Font.GothamBold
    SpeedResetBtn.Text = "Reset"; SpeedResetBtn.TextColor3 = C.accent
    SpeedResetBtn.TextSize = 9; SpeedResetBtn.ZIndex = 42; SpeedResetBtn.AutoButtonColor = false
    do 
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,4); c.Parent = SpeedResetBtn 
        local s = Instance.new("UIStroke"); s.Color = C.border; s.Transparency = 0.7; s.Thickness = 1; s.Parent = SpeedResetBtn
    end
    SpeedResetBtn.MouseEnter:Connect(function()
        TweenService:Create(SpeedResetBtn, TweenInfo.new(0.12), {BackgroundColor3 = C.accent, BackgroundTransparency = 0.2, TextColor3 = Color3.fromRGB(10,10,10)}):Play()
    end)
    SpeedResetBtn.MouseLeave:Connect(function()
        TweenService:Create(SpeedResetBtn, TweenInfo.new(0.12), {BackgroundColor3 = C.bg3, BackgroundTransparency = 0.2, TextColor3 = C.accent}):Play()
    end)
    SpeedResetBtn.MouseButton1Click:Connect(function()
        ApplySpeed(1.0)
    end)

    local spKeysHeader = Instance.new("TextLabel"); spKeysHeader.Parent = bottomBar
    spKeysHeader.BackgroundTransparency = 1; spKeysHeader.Size = UDim2.new(1,-24,0,14)
    spKeysHeader.AnchorPoint = Vector2.new(0,0); spKeysHeader.Position = UDim2.new(0,12,0,48); spKeysHeader.ZIndex = 41
    spKeysHeader.Font = Enum.Font.GothamSemibold
    spKeysHeader.Text = "Speed Presets - click a value to edit, [+] to bind"
    spKeysHeader.TextColor3 = C.text3; spKeysHeader.TextSize = 8
    spKeysHeader.TextXAlignment = Enum.TextXAlignment.Left

    local spValRow = Instance.new("Frame"); spValRow.Parent = bottomBar
    spValRow.BackgroundTransparency = 1; spValRow.Size = UDim2.new(1,-24,0,22)
    spValRow.AnchorPoint = Vector2.new(0,0); spValRow.Position = UDim2.new(0,12,0,68); spValRow.ZIndex = 41

    local spKeyRow = Instance.new("Frame"); spKeyRow.Parent = bottomBar
    spKeyRow.BackgroundTransparency = 1; spKeyRow.Size = UDim2.new(1,-24,0,22)
    spKeyRow.AnchorPoint = Vector2.new(0,0); spKeyRow.Position = UDim2.new(0,12,0,94); spKeyRow.ZIndex = 41

for i = 1, 6 do
    local xScale = (i-1) * (1/6)
    local xSzOff = -3

    local vbox = Instance.new("TextBox"); vbox.Parent = spValRow
    vbox.BackgroundColor3 = C.bg2
    vbox.BackgroundTransparency = 0.05; vbox.BorderSizePixel = 0
    vbox.Position = UDim2.new(xScale, i==1 and 0 or 2, 0, 0)
    vbox.Size = UDim2.new(1/6, i==1 and -2 or (i==6 and -2 or xSzOff), 1, 0)
    vbox.Font = Enum.Font.GothamBold
    vbox.Text = string.format("%.1f", SpeedKeybinds[i].speed)
    vbox.TextColor3 = C.accent; vbox.TextSize = 8
    vbox.ClearTextOnFocus = false; vbox.ZIndex = 42
    do
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,4); c.Parent = vbox
        local s = Instance.new("UIStroke"); s.Color = C.border
        s.Transparency = 0.6; s.Thickness = 1; s.Parent = vbox
    end

    local kbtn = Instance.new("TextButton"); kbtn.Parent = spKeyRow
    local sk0 = SpeedKeybinds[i]
    kbtn.Position = UDim2.new(xScale, i==1 and 0 or 2, 0, 0)
    kbtn.Size = UDim2.new(1/6, i==1 and -2 or (i==6 and -2 or xSzOff), 1, 0)
    kbtn.Font = Enum.Font.GothamBold
    kbtn.Text = sk0.key and ("["..sk0.key.Name.."]") or "[+]"
    kbtn.BackgroundColor3 = sk0.key and C.bg3 or C.bg2
    kbtn.BackgroundTransparency = 0.2
    kbtn.TextColor3 = sk0.key and C.accent or C.text3
    kbtn.TextSize = 7; kbtn.ZIndex = 42; kbtn.AutoButtonColor = false
    kbtn.TextTruncate = Enum.TextTruncate.AtEnd; kbtn.BorderSizePixel = 0
    do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,4); c.Parent = kbtn end

    SpeedKeybinds[i].btn = kbtn
    speedKeyWidgets[i] = { vbox = vbox, kbtn = kbtn }

    local ci = i
    vbox.FocusLost:Connect(function()
        local v = tonumber((vbox.Text:gsub("[^%d%.]", "")))
        if v and v > 0 then
            SpeedKeybinds[ci].speed = v
        end
        vbox.Text = tostring(SpeedKeybinds[ci].speed)
        SaveData()
    end)

    kbtn.MouseButton1Click:Connect(function()
        if _G._HaloListeningSpeedIdx == ci then
            _G._HaloListeningSpeedIdx = nil
            local sk = SpeedKeybinds[ci]
            kbtn.Text = sk.key and ("["..sk.key.Name.."]") or "[+]"
            kbtn.BackgroundColor3 = sk.key and C.bg3 or C.bg2
            kbtn.TextColor3 = sk.key and C.accent or C.text3
            return
        end
        if SpeedKeybinds[ci].key then
            SpeedKeybinds[ci].key = nil; kbtn.Text = "[+]"
            kbtn.BackgroundColor3 = C.bg2; kbtn.TextColor3 = C.text3
            SaveData(); return
        end
        _G._HaloListeningSpeedIdx = ci
        kbtn.Text = "[?]"; kbtn.BackgroundColor3 = Color3.fromRGB(180,80,20)
        kbtn.TextColor3 = Color3.fromRGB(255,220,180)
    end)

    kbtn.MouseEnter:Connect(function()
        TweenService:Create(kbtn, TweenInfo.new(0.1), {BackgroundTransparency=0}):Play()
    end)
    kbtn.MouseLeave:Connect(function()
        TweenService:Create(kbtn, TweenInfo.new(0.1), {BackgroundTransparency=0.2}):Play()
    end)
end

    -- Link toggle
    local linkFrame = Instance.new("Frame"); linkFrame.Parent = bottomBar
    linkFrame.BackgroundTransparency = 1; linkFrame.Size = UDim2.new(1,-24,0,16)
    linkFrame.Position = UDim2.new(0,12,0,124); linkFrame.ZIndex = 41

    local linkLbl = Instance.new("TextLabel"); linkLbl.Parent = linkFrame
    linkLbl.BackgroundTransparency = 1; linkLbl.Size = UDim2.new(0,200,1,0)
    linkLbl.Font = Enum.Font.GothamSemibold; linkLbl.TextSize = 8
    linkLbl.Text = "Reverse Speed Keys"
    linkLbl.TextColor3 = C.text3; linkLbl.TextXAlignment = Enum.TextXAlignment.Left; linkLbl.ZIndex = 42

    local linkBtn = Instance.new("TextButton"); linkBtn.Parent = linkFrame
    linkBtn.AnchorPoint = Vector2.new(1,0.5); linkBtn.Position = UDim2.new(1,0,0.5,0)
    linkBtn.Size = UDim2.new(0,56,0,14); linkBtn.Font = Enum.Font.GothamBold; linkBtn.TextSize = 7
    linkBtn.BorderSizePixel = 0; linkBtn.AutoButtonColor = false; linkBtn.ZIndex = 42
    do local cr = Instance.new("UICorner"); cr.CornerRadius = UDim.new(0,4); cr.Parent = linkBtn end
    local function updateLinkBtn()
        if linkRevToNormal then
            linkBtn.Text = "Linked"; linkBtn.BackgroundColor3 = C.accent; linkBtn.TextColor3 = Color3.fromRGB(0,0,0)
            linkBtn.BackgroundTransparency = 0.1
        else
            linkBtn.Text = "Separate"; linkBtn.BackgroundColor3 = C.bg2; linkBtn.TextColor3 = C.text3
            linkBtn.BackgroundTransparency = 0.2
        end
    end
    updateLinkBtn()
    linkBtn.MouseButton1Click:Connect(function()
        linkRevToNormal = not linkRevToNormal
        updateLinkBtn()
        SaveData()
    end)

    -- Reverse speed keybind value row
    local rspValRow = Instance.new("Frame"); rspValRow.Parent = bottomBar
    rspValRow.BackgroundTransparency = 1; rspValRow.Size = UDim2.new(1,-24,0,22)
    rspValRow.Position = UDim2.new(0,12,0,146); rspValRow.ZIndex = 41

    local rspKeyRow = Instance.new("Frame"); rspKeyRow.Parent = bottomBar
    rspKeyRow.BackgroundTransparency = 1; rspKeyRow.Size = UDim2.new(1,-24,0,22)
    rspKeyRow.Position = UDim2.new(0,12,0,172); rspKeyRow.ZIndex = 41

    for i = 1, 6 do
        local xScale = (i-1) * (1/6)
        local xSzOff = -3

        local rvbox = Instance.new("TextBox"); rvbox.Parent = rspValRow
        rvbox.BackgroundColor3 = C.bg2; rvbox.BackgroundTransparency = 0.05; rvbox.BorderSizePixel = 0
        rvbox.Position = UDim2.new(xScale, i==1 and 0 or 2, 0, 0)
        rvbox.Size = UDim2.new(1/6, i==1 and -2 or (i==6 and -2 or xSzOff), 1, 0)
        rvbox.Font = Enum.Font.GothamBold
        rvbox.Text = string.format("%.1f", ReverseSpeedKeybinds[i].speed)
        rvbox.TextColor3 = Color3.fromRGB(255,130,130); rvbox.TextSize = 8
        rvbox.ClearTextOnFocus = false; rvbox.ZIndex = 42
        do
            local cr = Instance.new("UICorner"); cr.CornerRadius = UDim.new(0,4); cr.Parent = rvbox
            local st = Instance.new("UIStroke"); st.Color = C.border; st.Transparency = 0.6; st.Thickness = 1; st.Parent = rvbox
        end

        local rkbtn = Instance.new("TextButton"); rkbtn.Parent = rspKeyRow
        local rsk0 = ReverseSpeedKeybinds[i]
        rkbtn.Position = UDim2.new(xScale, i==1 and 0 or 2, 0, 0)
        rkbtn.Size = UDim2.new(1/6, i==1 and -2 or (i==6 and -2 or xSzOff), 1, 0)
        rkbtn.Font = Enum.Font.GothamBold
        rkbtn.Text = rsk0.key and ("["..rsk0.key.Name.."]") or "[+]"
        rkbtn.BackgroundColor3 = rsk0.key and C.bg3 or C.bg2
        rkbtn.BackgroundTransparency = 0.2
        rkbtn.TextColor3 = rsk0.key and Color3.fromRGB(255,130,130) or C.text3
        rkbtn.TextSize = 7; rkbtn.ZIndex = 42; rkbtn.AutoButtonColor = false
        rkbtn.TextTruncate = Enum.TextTruncate.AtEnd; rkbtn.BorderSizePixel = 0
        do local cr = Instance.new("UICorner"); cr.CornerRadius = UDim.new(0,4); cr.Parent = rkbtn end

        ReverseSpeedKeybinds[i].btn = rkbtn
        revSpeedKeyWidgets[i] = { vbox = rvbox, kbtn = rkbtn }

        local ci = i
        rvbox.FocusLost:Connect(function()
            local v = tonumber((rvbox.Text:gsub("[^%d%.]", "")))
            if v and v > 0 then
                ReverseSpeedKeybinds[ci].speed = v
            end
            rvbox.Text = tostring(ReverseSpeedKeybinds[ci].speed)
            SaveData()
        end)

        rkbtn.MouseButton1Click:Connect(function()
            if _G._HaloListeningRevSpeedIdx == ci then
                _G._HaloListeningRevSpeedIdx = nil
                local sk = ReverseSpeedKeybinds[ci]
                rkbtn.Text = sk.key and ("["..sk.key.Name.."]") or "[+]"
                rkbtn.BackgroundColor3 = sk.key and C.bg3 or C.bg2
                rkbtn.TextColor3 = sk.key and Color3.fromRGB(255,130,130) or C.text3
                return
            end
            if ReverseSpeedKeybinds[ci].key then
                ReverseSpeedKeybinds[ci].key = nil; rkbtn.Text = "[+]"
                rkbtn.BackgroundColor3 = C.bg2; rkbtn.TextColor3 = C.text3
                SaveData(); return
            end
            _G._HaloListeningRevSpeedIdx = ci
            rkbtn.Text = "[?]"; rkbtn.BackgroundColor3 = Color3.fromRGB(180,80,20)
            rkbtn.TextColor3 = Color3.fromRGB(255,220,180)
        end)

        rkbtn.MouseEnter:Connect(function()
            TweenService:Create(rkbtn, TweenInfo.new(0.1), {BackgroundTransparency=0}):Play()
        end)
        rkbtn.MouseLeave:Connect(function()
            TweenService:Create(rkbtn, TweenInfo.new(0.1), {BackgroundTransparency=0.2}):Play()
        end)
    end
end

function ApplySpeed(speed)
    speed = math.clamp(math.floor(speed * 10 + 0.5) / 10, 0.0, 4.0)
    State.currentSpeed   = speed
    local fraction = (speed - 0.0) / 3.9
    SpeedFill.Size       = UDim2.new(fraction, 0, 1, 0)
    SpeedHandle.Position = UDim2.new(fraction, 0, 0.5, 0)
    SpeedLabel.Text      = "Speed: " .. string.format("%.1f", speed)
    SpeedValueBox.Text   = string.format("%.1f", speed)
    if State.isReanimated then
        pcall(function() ReanimateAPI.set_animation_speed(speed) end)
    end
end

ApplySpeed(1.0)

SpeedTrack.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
        isDraggingSpeed = true
        local pct = (inp.Position.X - SpeedTrack.AbsolutePosition.X) / SpeedTrack.AbsoluteSize.X
        ApplySpeed(0.1 + pct * 3.9)
    end
end)
SpeedTrack.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 then isDraggingSpeed = false end
end)
UserInputService.InputChanged:Connect(function(inp)
    if isDraggingSpeed and inp.UserInputType == Enum.UserInputType.MouseMovement then
        local pct = (inp.Position.X - SpeedTrack.AbsolutePosition.X) / SpeedTrack.AbsoluteSize.X
        ApplySpeed(0.1 + pct * 3.9)
    end
end)
SpeedValueBox.FocusLost:Connect(function()
    local v = tonumber(SpeedValueBox.Text)
    if v then ApplySpeed(v)
    else SpeedValueBox.Text = string.format("%.1f", State.currentSpeed) end
end)

_G._HaloReanimConns = _G._HaloReanimConns or {}
_G._HaloReanimConns.KeybindInputBegan = UserInputService.InputBegan:Connect(LPH_NO_VIRTUALIZE(function(input, gameProcessed)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    local kc = input.KeyCode

    if GlobalReverseKeybind and kc == GlobalReverseKeybind then
        -- Don't trigger rewind while the user is typing in chat or another
        -- input box (gameProcessed is true).
        if gameProcessed then return end
        if State.isReanimated and ReanimateAPI and ReanimateAPI.set_animation_speed then
            local speed = tonumber(GlobalReverseSpeed) or 1.0
            if speed <= 0 then speed = 1.0 end
            pcall(ReanimateAPI.set_animation_speed, -speed)
        end
        return
    end

    if _G._HaloInstantResetKey and kc == _G._HaloInstantResetKey then
        if gameProcessed then return end
        local char = plr.Character
        if not char then return end

        -- Cooldown so you can't spam-break it
        if _G._HaloResetLastTick and (tick() - _G._HaloResetLastTick < 0.8) then return end
        _G._HaloResetLastTick = tick()

        local savedCF = nil
        local wasReanimated = State.isReanimated
        if wasReanimated and ReanimateAPI and ReanimateAPI.get_clone then
            local clone = ReanimateAPI.get_clone(plr)
            if clone then
                local cloneHRP = clone:FindFirstChild("HumanoidRootPart")
                if cloneHRP then savedCF = cloneHRP.CFrame end
            end
        end
        if not savedCF then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then savedCF = hrp.CFrame end
        end

        -- Disable reanimation before killing so respawn works normally
        if State.isReanimated then
            pcall(function() ReanimateAPI.reanimate(false) end)
            State.isReanimated = false
            UpdateToggleBtn()
        end

        -- INSTANT RESPAWN: remove Roblox's built-in respawn delay
        local Players = game:GetService("Players")
        local oldRespawnTime = Players.RespawnTime
        Players.RespawnTime = 0

        -- Skip death animation
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            local animator = hum:FindFirstChildOfClass("Animator")
            if animator then
                pcall(function()
                    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                        track:Stop(0)
                    end
                end)
            end
            local animate = char:FindFirstChild("Animate")
            if animate then pcall(function() animate.Disabled = true end) end
            hum.Health = 0
        end

        -- Restore normal respawn time after we respawn
        task.delay(0.6, function()
            pcall(function() Players.RespawnTime = oldRespawnTime end)
        end)

        if savedCF then
            local spawnConn
            spawnConn = plr.CharacterAdded:Connect(function(newChar)
                spawnConn:Disconnect()
                -- Snap to saved position on the very next physics tick
                local hbConn
                hbConn = game:GetService("RunService").Heartbeat:Connect(function()
                    hbConn:Disconnect()
                    local hrp = newChar:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        pcall(function()
                            hrp.CFrame = savedCF
                            hrp.Velocity = Vector3.zero
                            hrp.RotVelocity = Vector3.zero
                            hrp.AssemblyLinearVelocity = Vector3.zero
                            hrp.AssemblyAngularVelocity = Vector3.zero
                        end)
                    end
                    if wasReanimated then
                        pcall(function() ReanimateAPI.reanimate(true) end)
                        State.isReanimated = ReanimateAPI and ReanimateAPI.is_reanimated() or false
                        UpdateToggleBtn()
                        local newClone = ReanimateAPI and ReanimateAPI.get_clone and ReanimateAPI.get_clone(plr)
                        if newClone then
                            local newCloneHRP = newClone:FindFirstChild("HumanoidRootPart")
                            if newCloneHRP then
                                pcall(function()
                                    newCloneHRP.CFrame = savedCF
                                    newCloneHRP.Velocity = Vector3.zero
                                    newCloneHRP.RotVelocity = Vector3.zero
                                    newCloneHRP.AssemblyLinearVelocity = Vector3.zero
                                    newCloneHRP.AssemblyAngularVelocity = Vector3.zero
                                end)
                            end
                        end
                    end
                end)
            end)
        end
        return
    end

    -- Left Arm Pointer keybind toggle
    if _G._HaloLeftArmKey and kc == _G._HaloLeftArmKey then
        if gameProcessed then return end
        _G._HaloLeftArmPointerEnabled = not (_G._HaloLeftArmPointerEnabled or false)
        if _G._HaloUpdateLeftArmPointerUI then _G._HaloUpdateLeftArmPointerUI() end
        Notify("Left Arm Pointer: " .. (_G._HaloLeftArmPointerEnabled and "ON" or "OFF"), 2)
        return
    end

    -- Right Arm Pointer keybind toggle
    if _G._HaloRightArmKey and kc == _G._HaloRightArmKey then
        if gameProcessed then return end
        _G._HaloRightArmPointerEnabled = not (_G._HaloRightArmPointerEnabled or false)
        if _G._HaloUpdateRightArmPointerUI then _G._HaloUpdateRightArmPointerUI() end
        Notify("Right Arm Pointer: " .. (_G._HaloRightArmPointerEnabled and "ON" or "OFF"), 2)
        return
    end

    -- Player Tracker keybind toggle
    if _G._HaloTrackerKey and kc == _G._HaloTrackerKey then
        if gameProcessed then return end
        trEnabled = not trEnabled
        trUpdateToggle()
        if trEnabled then
            trStartTracking()
            Notify("Player Tracker: ON", 2)
        else
            trStopTracking()
            Notify("Player Tracker: OFF", 2)
        end
        return
    end

    -- Head Tracker keybind toggle
    if _G._HaloHeadTrackerKey and kc == _G._HaloHeadTrackerKey then
        if gameProcessed then return end
        _G._HaloHeadTrackerEnabled = not (_G._HaloHeadTrackerEnabled or false)
        if _G._HaloUpdateHeadTrackerUI then _G._HaloUpdateHeadTrackerUI() end
        Notify("Head Tracker: " .. (_G._HaloHeadTrackerEnabled and "ON" or "OFF"), 2)
        return
    end

    if _G._HaloListeningSpeedIdx then
        local idx = _G._HaloListeningSpeedIdx; _G._HaloListeningSpeedIdx = nil
        if kc == Enum.KeyCode.Escape then
            local sk = SpeedKeybinds[idx]; local b = speedKeyWidgets[idx].kbtn
            b.Text = sk.key and ("["..sk.key.Name.."]") or "[+]"
            b.BackgroundColor3 = sk.key and C.bg3 or C.bg2
            b.TextColor3 = sk.key and C.accent or C.text3
            return
        end
        for j = 1, 6 do
            if j ~= idx and SpeedKeybinds[j].key == kc then
                SpeedKeybinds[j].key = nil
                speedKeyWidgets[j].kbtn.Text = "[+]"
                speedKeyWidgets[j].kbtn.BackgroundColor3 = C.bg2
                speedKeyWidgets[j].kbtn.TextColor3 = C.text3
            end
        end
        SpeedKeybinds[idx].key = kc
        local b = speedKeyWidgets[idx].kbtn
        b.Text = "["..kc.Name.."]"; b.BackgroundColor3 = C.bg3
        b.TextColor3 = C.accent
        -- If linked, also set the reverse speed keybind
        if linkRevToNormal and revSpeedKeyWidgets[idx] then
            ReverseSpeedKeybinds[idx].key = kc
            local rb = revSpeedKeyWidgets[idx].kbtn
            rb.Text = "["..kc.Name.."]"; rb.BackgroundColor3 = C.bg3
            rb.TextColor3 = Color3.fromRGB(255,130,130)
        end
        SaveData(); return
    end

    if _G._HaloListeningRevSpeedIdx then
        local idx = _G._HaloListeningRevSpeedIdx; _G._HaloListeningRevSpeedIdx = nil
        if kc == Enum.KeyCode.Escape then
            local sk = ReverseSpeedKeybinds[idx]; local b = revSpeedKeyWidgets[idx].kbtn
            b.Text = sk.key and ("["..sk.key.Name.."]") or "[+]"
            b.BackgroundColor3 = sk.key and C.bg3 or C.bg2
            b.TextColor3 = sk.key and Color3.fromRGB(255,130,130) or C.text3
            return
        end
        for j = 1, 6 do
            if j ~= idx and ReverseSpeedKeybinds[j].key == kc then
                ReverseSpeedKeybinds[j].key = nil
                revSpeedKeyWidgets[j].kbtn.Text = "[+]"
                revSpeedKeyWidgets[j].kbtn.BackgroundColor3 = C.bg2
                revSpeedKeyWidgets[j].kbtn.TextColor3 = C.text3
            end
        end
        ReverseSpeedKeybinds[idx].key = kc
        local b = revSpeedKeyWidgets[idx].kbtn
        b.Text = "["..kc.Name.."]"; b.BackgroundColor3 = C.bg3
        b.TextColor3 = Color3.fromRGB(255,130,130)
        SaveData(); return
    end

    if _G._HaloListeningKeyBtn then
        if kc == Enum.KeyCode.Escape then CancelListening(); Notify("Keybind cancelled", 1.5); return end
        BindKey(kc); return
    end

    for i = 1, 6 do
        if SpeedKeybinds[i].key == kc then
            ApplySpeed(SpeedKeybinds[i].speed)
            -- If linked, also check reverse
            if linkRevToNormal and State.isReanimated and ReanimateAPI and ReanimateAPI.set_animation_speed then
                pcall(ReanimateAPI.set_animation_speed, -ReverseSpeedKeybinds[i].speed)
            end
            return
        end
    end

    for i = 1, 6 do
        if ReverseSpeedKeybinds[i].key == kc then
            if State.isReanimated and ReanimateAPI and ReanimateAPI.set_animation_speed then
                pcall(ReanimateAPI.set_animation_speed, -ReverseSpeedKeybinds[i].speed)
            end
            return
        end
    end

    if gameProcessed then return end

    for animName, data in pairs(Keybinds) do
        if data.key == kc then
            if not State.isReanimated then return end
            -- Skip if user is typing in a text box, but allow otherwise
            -- even when gameProcessed is true (some games set it inconsistently)
            local typing = false
            pcall(function()
                local guiService = game:GetService("GuiService")
                if guiService:GetFocusedTextBox() then typing = true end
            end)
            if typing then return end
            local customPlain = animName:match("^%[Custom%] (.+)$")
            if customPlain then
                PlayAnimation(animName, State.currentSpeed, true)
            else
                local url = AnimationList[animName]
                if url then
                    PlayAnimation(animName, State.currentSpeed, false)
                end
            end
            break
        end
    end
end))

_G._HaloReanimConns = _G._HaloReanimConns or {}
_G._HaloReanimConns.KeybindInputEnded = UserInputService.InputEnded:Connect(LPH_NO_VIRTUALIZE(function(input, gameProcessed)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    local kc = input.KeyCode
    if GlobalReverseKeybind and kc == GlobalReverseKeybind then
        if State.isReanimated and ReanimateAPI and ReanimateAPI.set_animation_speed then
            local resumeSpeed = tonumber(State.currentSpeed) or 1.0
            pcall(ReanimateAPI.set_animation_speed, resumeSpeed)
        end
    end
end))

local Camera = workspace.CurrentCamera

function isShiftLockActive()
    return UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
        and Camera.CameraType == Enum.CameraType.Custom
end

local _lastApiCheck  = 0
local _lastAnimCheck = 0

    
-- ============================================
-- VC BYPASS INTEGRATION
-- ============================================
local VCBypassEnabled = false
local VCBypassConns = {}
local VCBypassObjs = {}

local function cleanupVCBypass()
    for _, conn in ipairs(VCBypassConns) do
        pcall(function() conn:Enable() end)
    end
    table.clear(VCBypassConns)

    if VCBypassObjs.watchdog then pcall(function() VCBypassObjs.watchdog:Disconnect() end) end
    if VCBypassObjs.cloned then pcall(function() VCBypassObjs.cloned:Destroy() end) end
    if VCBypassObjs.hidden then pcall(function() VCBypassObjs.hidden:Destroy() end) end

    if VCBypassObjs.original and VCBypassObjs.container then
        pcall(function() VCBypassObjs.original.Parent = VCBypassObjs.container end)
    end

    pcall(function()
        local vcs = (cloneref or function(...) return ... end)(game:GetService("VoiceChatService"))
        vcs:leaveVoice()
        task.wait(0.5)
        vcs:joinVoice()
    end)

    VCBypassObjs = {}
    VCBypassEnabled = false
    pcall(function()
        writefile(fpath("ReanimVCBypass.json"), HttpService:JSONEncode({enabled = false}))
    end)
end

local function applyVCBypass()
    if VCBypassEnabled then return end
    VCBypassEnabled = true

    pcall(function()
        writefile(fpath("ReanimVCBypass.json"), HttpService:JSONEncode({enabled = true}))
    end)

    task.spawn(function()
        local identifyexecutorname = (identifyexecutor and identifyexecutor()) or "Unknown"
        local clonereference = cloneref or function(...) return ... end
        local clonefunction = clonefunction or function(...) return ... end

        local voicechatservice = clonereference(game:GetService("VoiceChatService"))
        local voicechatinternal = clonereference(game:GetService("VoiceChatInternal"))
        local coregui = game:GetService("CoreGui")
        local startergui = game:GetService("StarterGui")
        local players = game:GetService("Players")
        local localplayer = players.LocalPlayer
        local getconnectionsfunc = clonefunction(getconnections)

        local mutedimage = "rbxasset://textures/ui/VoiceChat/MicLight/Muted.png"
        local hiddenfolder = Instance.new("Folder", game:GetService("RobloxReplicatedStorage"))
        hiddenfolder.Name = "HaloVCBypass"
        VCBypassObjs.hidden = hiddenfolder

        local topbarapp = coregui:WaitForChild("TopBarApp", 15):WaitForChild("TopBarApp", 15)
        local unibarleft = topbarapp:WaitForChild("UnibarLeftFrame", 15)
        local unibarmenu = unibarleft:WaitForChild("UnibarMenu", 15) or unibarleft:WaitForChild("ChromeMenu", 15)
        local unibarcontainer

        pcall(function()
            unibarcontainer = unibarmenu:WaitForChild("2", 15):WaitForChild("3", 15)
        end)

        local micmutebutton = unibarcontainer and unibarcontainer:FindFirstChild("toggle_mic_mute", true)

        local function geticonlabel(button)
            button = button or micmutebutton
            return button:WaitForChild("IntegrationIconFrame", 15):WaitForChild("IntegrationIcon", 15)["1"]
        end

        local function getcurrentmutestate()
            return voicechatinternal:IsPublishPaused()
        end

        local function setmutestate(state)
            voicechatinternal:PublishPause(state)
        end

        if not micmutebutton then 
            voicechatservice:joinVoice() 
            pcall(function()
                unibarcontainer = unibarmenu:WaitForChild("2", 15):WaitForChild("3", 15)
                micmutebutton = unibarcontainer:WaitForChild("toggle_mic_mute", 15)
            end)
        end

        if not micmutebutton then 
            VCBypassEnabled = false
            Notify("VC Bypass Error", "Mic button not found", 3)
            return 
        end

        startergui:SetCore("SendNotification", {Title = "created by masklol,dm me for issue", Text = "Unmute to continue.", Duration = 5})

        repeat task.wait(2) until geticonlabel().Image ~= mutedimage

        voicechatservice:leaveVoice()
        task.wait(2)

        local connections = getconnectionsfunc(voicechatinternal.StateChanged)
        for i = 7, #connections do 
            if connections[i] then 
                connections[i]:Disable() 
                table.insert(VCBypassConns, connections[i])
            end 
        end

        task.wait(2)
        voicechatservice:joinVoice()

        pcall(function()
            unibarcontainer = unibarmenu:WaitForChild("2", 15):WaitForChild("3", 15)
            micmutebutton = unibarcontainer:WaitForChild("toggle_mic_mute", 15)
        end)

        if micmutebutton and unibarcontainer then
            local clonedmutebutton = micmutebutton:Clone()
            micmutebutton.Parent = hiddenfolder
            clonedmutebutton.Name = "toggle_mic_mute_new"
            clonedmutebutton.Parent = unibarcontainer
            VCBypassObjs.cloned = clonedmutebutton
            VCBypassObjs.original = micmutebutton
            VCBypassObjs.container = unibarcontainer

            local clonedicon = geticonlabel(clonedmutebutton)

            setmutestate(true)

            -- VC texture: player avatar headshot in a small circle with a red ring.
            -- Wipe every leftover mic / voice-chat image so the default white mic
            -- can never show on the cloned button.
            local function micish(img)
                if type(img) ~= "string" or img == "" then return false end
                local low = string.lower(img)
                return (low:find("voicechat") or low:find("mic") or low:find("muted")
                    or low:find("unmuted") or low:find("speaker") or low:find("voicemode")) ~= nil
            end
            local function wipeMicImages(root)
                if not root then return end
                if (root:IsA("ImageLabel") or root:IsA("ImageButton")) and micish(root.Image) then
                    root.Image = ""
                end
                for _, d in ipairs(root:GetDescendants()) do
                    if d:IsA("ImageLabel") or d:IsA("ImageButton") then
                        if micish(d.Image) then d.Image = "" end
                    end
                end
            end
            wipeMicImages(clonedmutebutton)

            local vcheadshot = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(localplayer.UserId) .. "&w=150&h=150"
            if clonedicon then
                clonedicon.Image = vcheadshot
                clonedicon.ScaleType = Enum.ScaleType.Crop
                clonedicon.BackgroundTransparency = 1
                clonedicon.Visible = true
                clonedicon.AnchorPoint = Vector2.new(0.5, 0.5)
                clonedicon.Position = UDim2.new(0.5, 0, 0.5, 0)
                clonedicon.Size = UDim2.new(0, 24, 0, 24)
                local vccorner = Instance.new("UICorner")
                vccorner.CornerRadius = UDim.new(1, 0)
                vccorner.Parent = clonedicon
                local vcring = Instance.new("UIStroke")
                vcring.Color = Color3.fromRGB(255, 45, 60)
                vcring.Thickness = 2
                vcring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                vcring.Parent = clonedicon
            end

            -- Keep the original button hidden so its white mic cannot reappear.
            pcall(function() micmutebutton.Visible = false end)

            -- If Roblox re-creates the default mic button, hide it again and make
            -- sure no mic image survives on our clone.
            VCBypassObjs.watchdog = unibarcontainer.ChildAdded:Connect(function(child)
                if child and child.Name == "toggle_mic_mute" then
                    task.defer(function() pcall(function() child.Visible = false end) end)
                end
                task.defer(function() wipeMicImages(clonedmutebutton) end)
            end)

            clonedmutebutton:WaitForChild("IconHitArea_toggle_mic_mute", 15).Activated:Connect(function()
                local newstate = not getcurrentmutestate()
                setmutestate(newstate)
                if clonedicon then clonedicon.Image = vcheadshot end
                wipeMicImages(clonedmutebutton)
            end)
        end
    end)
end
local function buildSettingsUI()
        local sc = SettingsPanel
        local fnGui


    -- FPS Limiter Toggle
    local fpsFrame = new("Frame",sc,{Size=UDim2.new(1,-10,0,60),BackgroundColor3=C.bg2,BackgroundTransparency=0.45,BorderSizePixel=0})
    corner(fpsFrame,8); stroke(fpsFrame,C.glassBorder,1,0.6)

    new("TextLabel",fpsFrame,{Size=UDim2.new(1,-120,0,18),Position=UDim2.new(0,10,0,10),
        BackgroundTransparency=1,Text="FPS Limiter",TextColor3=C.text,TextSize=11,
        Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left})

    new("TextLabel",fpsFrame,{Size=UDim2.new(1,-130,0,20),Position=UDim2.new(0,10,0,28),
        BackgroundTransparency=1,Text="Limits UI updates to improve performance on low-end devices.",
        TextColor3=C.text3,TextSize=9,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true})

    local fpsToggleBg = new("Frame",fpsFrame,{Size=UDim2.new(0,44,0,22),Position=UDim2.new(1,-54,0,19),
        BackgroundColor3=C.bg4,BorderSizePixel=0}); corner(fpsToggleBg,11)
    local fpsToggleKnob = new("Frame",fpsToggleBg,{
        Size=UDim2.new(0,16,0,16),Position=UDim2.new(0,3,0,3),
        BackgroundColor3=C.white,BorderSizePixel=0}); corner(fpsToggleKnob,8)
    local fpsToggleBtn = new("TextButton",fpsToggleBg,{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text=""})

    local FPSLimiterEnabled = false
    local function updateFPSLimiterState()
        if FPSLimiterEnabled then
            tw(fpsToggleBg, 0.2, {BackgroundColor3 = C.green}):Play()
            tw(fpsToggleKnob, 0.2, {Position = UDim2.new(1,-18,0,3)}):Play()
            _G._HaloFPSLimit = true
        else
            tw(fpsToggleBg, 0.2, {BackgroundColor3 = C.bg4}):Play()
            tw(fpsToggleKnob, 0.2, {Position = UDim2.new(0,3,0,3)}):Play()
            _G._HaloFPSLimit = false
        end
    end
    fpsToggleBtn.MouseButton1Click:Connect(function()
        FPSLimiterEnabled = not FPSLimiterEnabled
        updateFPSLimiterState()
    end)


    -- Ghost Trails (Neon Visual Trail)
    local ghostFrame = new("Frame",sc,{Size=UDim2.new(1,-10,0,60),BackgroundColor3=C.bg2,BackgroundTransparency=0.45,BorderSizePixel=0})
    corner(ghostFrame,8); stroke(ghostFrame,C.glassBorder,1,0.6)

    new("TextLabel",ghostFrame,{Size=UDim2.new(1,-120,0,18),Position=UDim2.new(0,10,0,10),
        BackgroundTransparency=1,Text="Ghost Echo Trails",TextColor3=C.text,TextSize=11,
        Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left})

    new("TextLabel",ghostFrame,{Size=UDim2.new(1,-130,0,20),Position=UDim2.new(0,10,0,28),
        BackgroundTransparency=1,Text="Creates premium neon ghost trails that mimic your active animations with a smooth fade.",
        TextColor3=C.text3,TextSize=9,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true})

    local ghostToggleBg = new("Frame",ghostFrame,{Size=UDim2.new(0,44,0,22),Position=UDim2.new(1,-54,0,19),
        BackgroundColor3=C.bg4,BorderSizePixel=0}); corner(ghostToggleBg,11)
    local ghostToggleKnob = new("Frame",ghostToggleBg,{
        Size=UDim2.new(0,16,0,16),Position=UDim2.new(0,3,0,3),
        BackgroundColor3=C.white,BorderSizePixel=0}); corner(ghostToggleKnob,8)
    local ghostToggleBtn = new("TextButton",ghostToggleBg,{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text=""})

    local GhostTrailEnabled = false
    local ghostTrailConn = nil
    local lastGhostTime = 0

    local function spawnGhostClone()
        local char = plr.Character
        if not char then return end
        
        local ghostModel = Instance.new("Model")
        ghostModel.Name = "HaloGhostTrail"
        ghostModel.Parent = workspace
        
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Transparency < 1 and part.Name ~= "HumanoidRootPart" and not part.Parent:IsA("Accessory") then
                local clone = Instance.new("Part")
                clone.Size = part.Size
                clone.CFrame = part.CFrame
                clone.Color = C.accent
                clone.Material = Enum.Material.Neon
                clone.CanCollide = false
                clone.Anchored = true
                clone.Transparency = 0.55
                clone.Parent = ghostModel
                
                local twInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                local tw = game:GetService("TweenService"):Create(clone, twInfo, {Transparency = 1})
                tw:Play()
            end
        end
        
        task.delay(0.5, function()
            ghostModel:Destroy()
        end)
    end

    local function updateGhostTrailState()
    if GhostTrailEnabled then
            tw(ghostToggleBg, 0.2, {BackgroundColor3 = C.green}):Play()
            tw(ghostToggleKnob, 0.2, {Position = UDim2.new(1,-18,0,3)}):Play()
            
            if ghostTrailConn then ghostTrailConn:Disconnect() end
            ghostTrailConn = RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function()
                local now = tick()
                if now - lastGhostTime >= 0.25 then
                    lastGhostTime = now
                    pcall(spawnGhostClone)
                end
            end))
        else
            tw(ghostToggleBg, 0.2, {BackgroundColor3 = C.bg4}):Play()
            tw(ghostToggleKnob, 0.2, {Position = UDim2.new(0,3,0,3)}):Play()
            if ghostTrailConn then
                ghostTrailConn:Disconnect()
                ghostTrailConn = nil
            end
        end
    end

    ghostToggleBtn.MouseButton1Click:Connect(function()
        GhostTrailEnabled = not GhostTrailEnabled
        updateGhostTrailState()
    end)


    -- Head Tracker
    local htFrame = new("Frame",sc,{Size=UDim2.new(1,-10,0,60),BackgroundColor3=C.bg2,BackgroundTransparency=0.45,BorderSizePixel=0})
    corner(htFrame,8); stroke(htFrame,C.glassBorder,1,0.6)

    new("TextLabel",htFrame,{Size=UDim2.new(1,-220,0,18),Position=UDim2.new(0,10,0,10),
        BackgroundTransparency=1,Text="Head Tracker",TextColor3=C.text,TextSize=11,
        Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left})

    new("TextLabel",htFrame,{Size=UDim2.new(1,-220,0,20),Position=UDim2.new(0,10,0,28),
        BackgroundTransparency=1,Text="Head follows camera via constraint transform. Overrides animation head keyframes only.",
        TextColor3=C.text3,TextSize=9,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true})

    local htToggleBg = new("Frame",htFrame,{Size=UDim2.new(0,44,0,22),Position=UDim2.new(1,-54,0,19),
        BackgroundColor3=C.bg4,BorderSizePixel=0}); corner(htToggleBg,11)
    local htToggleKnob = new("Frame",htToggleBg,{
        Size=UDim2.new(0,16,0,16),Position=UDim2.new(0,3,0,3),
        BackgroundColor3=C.white,BorderSizePixel=0}); corner(htToggleKnob,8)
    local htToggleBtn = new("TextButton",htToggleBg,{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text=""})

    local htKeyBtn = new("TextButton",htFrame,{Size=UDim2.new(0,80,0,22),Position=UDim2.new(1,-142,0,19),
        BackgroundColor3=C.bg2,BackgroundTransparency=0.2,BorderSizePixel=0,
        Font=Enum.Font.GothamBold,Text="Key: None",TextColor3=C.accent,TextSize=10})
    corner(htKeyBtn,5); stroke(htKeyBtn,C.border,1,0.7)

    local HeadTrackerEnabled = false

    local function updateHeadTrackerState()
        if HeadTrackerEnabled then
            tw(htToggleBg, 0.2, {BackgroundColor3 = C.green}):Play()
            tw(htToggleKnob, 0.2, {Position = UDim2.new(1,-18,0,3)}):Play()
            _G._HaloHeadTrackerEnabled = true
        else
            tw(htToggleBg, 0.2, {BackgroundColor3 = C.bg4}):Play()
            tw(htToggleKnob, 0.2, {Position = UDim2.new(0,3,0,3)}):Play()
            _G._HaloHeadTrackerEnabled = false
        end
    end
    _G._HaloUpdateHeadTrackerUI = function()
        HeadTrackerEnabled = _G._HaloHeadTrackerEnabled or false
        updateHeadTrackerState()
    end

    htToggleBtn.MouseButton1Click:Connect(function()
        HeadTrackerEnabled = not HeadTrackerEnabled
        updateHeadTrackerState()
    end)

    local function updateHtKeyBtnText()
        local keyName = _G._HaloHeadTrackerKey and _G._HaloHeadTrackerKey.Name or "None"
        htKeyBtn.Text = "Key: " .. keyName
    end
    updateHtKeyBtnText()

    local settingHtKey = false
    htKeyBtn.MouseButton1Click:Connect(function()
        if settingHtKey then return end
        if _G._HaloHeadTrackerKey then
            _G._HaloHeadTrackerKey = nil
            SaveData()
            updateHtKeyBtnText()
            return
        end
        settingHtKey = true
        htKeyBtn.Text = "Listening..."
        htKeyBtn.BackgroundColor3 = C.yellow
        local keyConn
        keyConn = UserInputService.InputBegan:Connect(LPH_NO_VIRTUALIZE(function(i, gp)
            if gp then return end
            keyConn:Disconnect()
            settingHtKey = false
            htKeyBtn.BackgroundColor3 = C.bg2
            if i.KeyCode == Enum.KeyCode.Escape then
                updateHtKeyBtnText()
                return
            end
            _G._HaloHeadTrackerKey = i.KeyCode
            SaveData()
            updateHtKeyBtnText()
        end))
    end)

    -- Left Arm Pointer
    local laFrame = new("Frame",sc,{Size=UDim2.new(1,-10,0,60),BackgroundColor3=C.bg2,BackgroundTransparency=0.45,BorderSizePixel=0})
    corner(laFrame,8); stroke(laFrame,C.glassBorder,1,0.6)

    new("TextLabel",laFrame,{Size=UDim2.new(1,-220,0,18),Position=UDim2.new(0,10,0,10),
        BackgroundTransparency=1,Text="Left Arm Pointer",TextColor3=C.text,TextSize=11,
        Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left})

    new("TextLabel",laFrame,{Size=UDim2.new(1,-220,0,20),Position=UDim2.new(0,10,0,28),
        BackgroundTransparency=1,Text="Left arm points straight at mouse. Overrides left arm keyframes only.",
        TextColor3=C.text3,TextSize=9,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true})

    local laToggleBg = new("Frame",laFrame,{Size=UDim2.new(0,44,0,22),Position=UDim2.new(1,-54,0,19),
        BackgroundColor3=C.bg4,BorderSizePixel=0}); corner(laToggleBg,11)
    local laToggleKnob = new("Frame",laToggleBg,{
        Size=UDim2.new(0,16,0,16),Position=UDim2.new(0,3,0,3),
        BackgroundColor3=C.white,BorderSizePixel=0}); corner(laToggleKnob,8)
    local laToggleBtn = new("TextButton",laToggleBg,{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text=""})

    local laKeyBtn = new("TextButton",laFrame,{Size=UDim2.new(0,80,0,22),Position=UDim2.new(1,-142,0,19),
        BackgroundColor3=C.bg2,BackgroundTransparency=0.2,BorderSizePixel=0,
        Font=Enum.Font.GothamBold,Text="Key: None",TextColor3=C.accent,TextSize=10})
    corner(laKeyBtn,5); stroke(laKeyBtn,C.border,1,0.7)

    local LeftArmPointerEnabled = false

    local function updateLeftArmPointerState()
        if LeftArmPointerEnabled then
            tw(laToggleBg, 0.2, {BackgroundColor3 = C.green}):Play()
            tw(laToggleKnob, 0.2, {Position = UDim2.new(1,-18,0,3)}):Play()
            _G._HaloLeftArmPointerEnabled = true
        else
            tw(laToggleBg, 0.2, {BackgroundColor3 = C.bg4}):Play()
            tw(laToggleKnob, 0.2, {Position = UDim2.new(0,3,0,3)}):Play()
            _G._HaloLeftArmPointerEnabled = false
        end
    end
    _G._HaloUpdateLeftArmPointerUI = function()
        LeftArmPointerEnabled = _G._HaloLeftArmPointerEnabled or false
        updateLeftArmPointerState()
    end

    laToggleBtn.MouseButton1Click:Connect(function()
        LeftArmPointerEnabled = not LeftArmPointerEnabled
        updateLeftArmPointerState()
    end)

    local function updateLaKeyBtnText()
        local keyName = _G._HaloLeftArmKey and _G._HaloLeftArmKey.Name or "None"
        laKeyBtn.Text = "Key: " .. keyName
    end
    updateLaKeyBtnText()

    local settingLaKey = false
    laKeyBtn.MouseButton1Click:Connect(function()
        if settingLaKey then return end
        if _G._HaloLeftArmKey then
            _G._HaloLeftArmKey = nil
            SaveData()
            updateLaKeyBtnText()
            return
        end
        settingLaKey = true
        laKeyBtn.Text = "Listening..."
        laKeyBtn.BackgroundColor3 = C.yellow
        local keyConn
        keyConn = UserInputService.InputBegan:Connect(LPH_NO_VIRTUALIZE(function(i, gp)
            if gp then return end
            keyConn:Disconnect()
            settingLaKey = false
            laKeyBtn.BackgroundColor3 = C.bg2
            if i.KeyCode == Enum.KeyCode.Escape then
                updateLaKeyBtnText()
                return
            end
            _G._HaloLeftArmKey = i.KeyCode
            SaveData()
            updateLaKeyBtnText()
        end))
    end)

    -- Right Arm Pointer
    local raFrame = new("Frame",sc,{Size=UDim2.new(1,-10,0,60),BackgroundColor3=C.bg2,BackgroundTransparency=0.45,BorderSizePixel=0})
    corner(raFrame,8); stroke(raFrame,C.glassBorder,1,0.6)

    new("TextLabel",raFrame,{Size=UDim2.new(1,-220,0,18),Position=UDim2.new(0,10,0,10),
        BackgroundTransparency=1,Text="Right Arm Pointer",TextColor3=C.text,TextSize=11,
        Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left})

    new("TextLabel",raFrame,{Size=UDim2.new(1,-220,0,20),Position=UDim2.new(0,10,0,28),
        BackgroundTransparency=1,Text="Right arm points straight at mouse. Overrides right arm keyframes only.",
        TextColor3=C.text3,TextSize=9,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true})

    local raToggleBg = new("Frame",raFrame,{Size=UDim2.new(0,44,0,22),Position=UDim2.new(1,-54,0,19),
        BackgroundColor3=C.bg4,BorderSizePixel=0}); corner(raToggleBg,11)
    local raToggleKnob = new("Frame",raToggleBg,{
        Size=UDim2.new(0,16,0,16),Position=UDim2.new(0,3,0,3),
        BackgroundColor3=C.white,BorderSizePixel=0}); corner(raToggleKnob,8)
    local raToggleBtn = new("TextButton",raToggleBg,{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text=""})

    local raKeyBtn = new("TextButton",raFrame,{Size=UDim2.new(0,80,0,22),Position=UDim2.new(1,-142,0,19),
        BackgroundColor3=C.bg2,BackgroundTransparency=0.2,BorderSizePixel=0,
        Font=Enum.Font.GothamBold,Text="Key: None",TextColor3=C.accent,TextSize=10})
    corner(raKeyBtn,5); stroke(raKeyBtn,C.border,1,0.7)

    local RightArmPointerEnabled = false

    local function updateRightArmPointerState()
        if RightArmPointerEnabled then
            tw(raToggleBg, 0.2, {BackgroundColor3 = C.green}):Play()
            tw(raToggleKnob, 0.2, {Position = UDim2.new(1,-18,0,3)}):Play()
            _G._HaloRightArmPointerEnabled = true
        else
            tw(raToggleBg, 0.2, {BackgroundColor3 = C.bg4}):Play()
            tw(raToggleKnob, 0.2, {Position = UDim2.new(0,3,0,3)}):Play()
            _G._HaloRightArmPointerEnabled = false
        end
    end
    _G._HaloUpdateRightArmPointerUI = function()
        RightArmPointerEnabled = _G._HaloRightArmPointerEnabled or false
        updateRightArmPointerState()
    end

    raToggleBtn.MouseButton1Click:Connect(function()
        RightArmPointerEnabled = not RightArmPointerEnabled
        updateRightArmPointerState()
    end)

    local function updateRaKeyBtnText()
        local keyName = _G._HaloRightArmKey and _G._HaloRightArmKey.Name or "None"
        raKeyBtn.Text = "Key: " .. keyName
    end
    updateRaKeyBtnText()

    local settingRaKey = false
    raKeyBtn.MouseButton1Click:Connect(function()
        if settingRaKey then return end
        if _G._HaloRightArmKey then
            _G._HaloRightArmKey = nil
            SaveData()
            updateRaKeyBtnText()
            return
        end
        settingRaKey = true
        raKeyBtn.Text = "Listening..."
        raKeyBtn.BackgroundColor3 = C.yellow
        local keyConn
        keyConn = UserInputService.InputBegan:Connect(LPH_NO_VIRTUALIZE(function(i, gp)
            if gp then return end
            keyConn:Disconnect()
            settingRaKey = false
            raKeyBtn.BackgroundColor3 = C.bg2
            if i.KeyCode == Enum.KeyCode.Escape then
                updateRaKeyBtnText()
                return
            end
            _G._HaloRightArmKey = i.KeyCode
            SaveData()
            updateRaKeyBtnText()
        end))
    end)

    -- Arm Stretch
    local stFrame = new("Frame",sc,{Size=UDim2.new(1,-10,0,196),BackgroundColor3=C.bg2,BackgroundTransparency=0.45,BorderSizePixel=0})
    corner(stFrame,8); stroke(stFrame,C.glassBorder,1,0.6)

    new("TextLabel",stFrame,{Size=UDim2.new(1,-120,0,18),Position=UDim2.new(0,10,0,6),
        BackgroundTransparency=1,Text="Arm Stretch",TextColor3=C.text,TextSize=11,
        Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left})

    new("TextLabel",stFrame,{Size=UDim2.new(1,-130,0,14),Position=UDim2.new(0,10,0,22),
        BackgroundTransparency=1,Text="Ctrl+Scroll to adjust. Drag slider to set amount.",
        TextColor3=C.text3,TextSize=8,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true})

    local stToggleBg = new("Frame",stFrame,{Size=UDim2.new(0,44,0,22),Position=UDim2.new(1,-54,0,8),
        BackgroundColor3=C.bg4,BorderSizePixel=0}); corner(stToggleBg,11)
    local stToggleKnob = new("Frame",stToggleBg,{
        Size=UDim2.new(0,16,0,16),Position=UDim2.new(0,3,0,3),
        BackgroundColor3=C.white,BorderSizePixel=0}); corner(stToggleKnob,8)
    local stToggleBtn = new("TextButton",stToggleBg,{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text=""})

    local stAmtLbl = new("TextLabel",stFrame,{Size=UDim2.new(0,70,0,14),Position=UDim2.new(0,10,0,40),
        BackgroundTransparency=1,Text="2.5x",TextColor3=C.accent,TextSize=10,
        Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left})

    local stTrack = new("Frame",stFrame,{BackgroundColor3=C.bg2,BackgroundTransparency=0.3,
        BorderSizePixel=0,Position=UDim2.new(0,80,0,43),Size=UDim2.new(1,-95,0,8)})
    corner(stTrack,4); stroke(stTrack,C.border,1,0.7)

    local stFill = new("Frame",stTrack,{BackgroundColor3=C.accent,BackgroundTransparency=0.1,
        BorderSizePixel=0,Size=UDim2.new(0.375,0,1,0)})
    corner(stFill,4)

    local stHandle = new("Frame",stTrack,{AnchorPoint=Vector2.new(0.5,0.5),
        BackgroundColor3=C.accent,BackgroundTransparency=0,BorderSizePixel=0,
        Position=UDim2.new(0.375,0,0.5,0),Size=UDim2.new(0,12,0,12)})
    corner(stHandle,6); stroke(stHandle,C.border,1,0.4)

    -- Slider: 1x to 50x range
    local SLIDER_MIN = 1.0
    local SLIDER_MAX = 50.0
    local function sliderPctToAmt(pct)
        return SLIDER_MIN + pct * (SLIDER_MAX - SLIDER_MIN)
    end
    local function amtToSliderPct(amt)
        return (amt - SLIDER_MIN) / (SLIDER_MAX - SLIDER_MIN)
    end
    local function updateSliderUI(amt)
        local pct = math.clamp(amtToSliderPct(amt), 0, 1)
        _G._HaloArmStretchAmount = amt
        stFill.Size = UDim2.new(pct, 0, 1, 0)
        stHandle.Position = UDim2.new(pct, 0, 0.5, 0)
        stAmtLbl.Text = string.format("%.1f", amt) .. "x"
    end

    -- Step size dropdown + custom input (parented to menu to avoid clipping)
    local stepRow = new("Frame",stFrame,{Size=UDim2.new(1,-16,0,22),Position=UDim2.new(0,8,0,58),
        BackgroundTransparency=1})

    new("TextLabel",stepRow,{Size=UDim2.new(0,80,0,18),Position=UDim2.new(0,0,0,2),
        BackgroundTransparency=1,Text="Scroll Step:",TextColor3=C.text3,TextSize=9,
        Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left})

    local stepSizes = {0.1, 0.5, 1.0, 2.5, 5.0, 10.0, 25.0}
    local currentStep = 2.5
    _G._HaloStretchStepSize = currentStep

    local stepDropdown = new("TextButton",stepRow,{Size=UDim2.new(0,48,0,18),Position=UDim2.new(0,82,0,2),
        BackgroundColor3=C.bg3,BorderSizePixel=0,Text="2.5",TextColor3=C.text,TextSize=9,
        Font=Enum.Font.GothamBold})
    corner(stepDropdown,4); stroke(stepDropdown,C.border,1,0.6)

    -- Custom value input
    new("TextLabel",stepRow,{Size=UDim2.new(0,40,0,18),Position=UDim2.new(0,140,0,2),
        BackgroundTransparency=1,Text="Custom:",TextColor3=C.text3,TextSize=9,
        Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left})

    local customBox = new("TextBox",stepRow,{Size=UDim2.new(0,40,0,16),Position=UDim2.new(0,182,0,3),
        BackgroundColor3=C.bg3,BorderSizePixel=0,Text="",PlaceholderText="val",
        PlaceholderColor3=C.text3,TextColor3=C.accent,TextSize=9,Font=Enum.Font.Gotham,
        ClearTextOnFocus=false})
    corner(customBox,3); stroke(customBox,C.border,1,0.5)

    local customApplyBtn = new("TextButton",stepRow,{Size=UDim2.new(0,28,0,16),Position=UDim2.new(0,226,0,3),
        BackgroundColor3=C.accent,BorderSizePixel=0,Text="Set",TextColor3=C.white,TextSize=8,
        Font=Enum.Font.GothamBold})
    corner(customApplyBtn,3)

    customApplyBtn.MouseButton1Click:Connect(function()
        local val = tonumber(customBox.Text)
        if val and val >= SLIDER_MIN and val <= SLIDER_MAX then
            currentStep = val
            _G._HaloStretchStepSize = val
            stepDropdown.Text = tostring(val)
            updateSliderUI(val)
        end
    end)

    customBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            local val = tonumber(customBox.Text)
            if val and val >= SLIDER_MIN and val <= SLIDER_MAX then
                currentStep = val
                _G._HaloStretchStepSize = val
                stepDropdown.Text = tostring(val)
                updateSliderUI(val)
            end
        end
    end)

    local stepDropdownOpen = false
    local stepList = nil

    local function closeStepDropdown()
        stepDropdownOpen = false
        if stepList then pcall(function() stepList:Destroy() end) end
        stepList = nil
    end

    local function openStepDropdown()
        -- Parent to the main menu so it's not clipped
        local menuParent = sc.Parent or sc
        stepDropdownOpen = true
        if stepList then pcall(function() stepList:Destroy() end) end

        local dropAbsPos = stepDropdown.AbsolutePosition
        local dropAbsSize = stepDropdown.AbsoluteSize
        local menuAbsPos = menuParent.AbsolutePosition

        stepList = new("Frame",menuParent,{
            Size=UDim2.new(0, dropAbsSize.X, 0, #stepSizes * 20 + 4),
            Position=UDim2.new(0, dropAbsPos.X - menuAbsPos.X, 0, dropAbsPos.Y - menuAbsPos.Y + dropAbsSize.Y + 2),
            BackgroundColor3=C.bg2,BorderSizePixel=0,ZIndex=50})
        corner(stepList,4); stroke(stepList,C.border,1,0.8)
        stepList.ClipsDescendants = true

        for i, size in ipairs(stepSizes) do
            local opt = new("TextButton",stepList,{Size=UDim2.new(1,0,0,20),Position=UDim2.new(0,0,0,(i-1)*20 + 2),
                BackgroundTransparency=1,Text="  " .. tostring(size),TextColor3=size == currentStep and C.accent or C.text,
                TextSize=9,Font=Enum.Font.GothamBold,ZIndex=51,TextXAlignment=Enum.TextXAlignment.Left})
            opt.MouseEnter:Connect(function() opt.BackgroundTransparency = 0.8; opt.BackgroundColor3 = C.bg4 end)
            opt.MouseLeave:Connect(function() opt.BackgroundTransparency = 1 end)
            opt.MouseButton1Click:Connect(function()
                currentStep = size
                _G._HaloStretchStepSize = size
                stepDropdown.Text = tostring(size)
                closeStepDropdown()
            end)
        end
    end

    stepDropdown.MouseButton1Click:Connect(function()
        if stepDropdownOpen then
            closeStepDropdown()
        else
            openStepDropdown()
        end
    end)

    -- Close dropdown when clicking elsewhere
    UserInputService.InputBegan:Connect(function(inp, gp)
        if gp then return end
        if stepDropdownOpen and inp.UserInputType == Enum.UserInputType.MouseButton1 then
            closeStepDropdown()
        end
    end)

    local ArmStretchEnabled = false
    local function updateStretchState()
        if ArmStretchEnabled then
            tw(stToggleBg, 0.2, {BackgroundColor3 = C.green}):Play()
            tw(stToggleKnob, 0.2, {Position = UDim2.new(1,-18,0,3)}):Play()
            _G._HaloLeftArmStretching = true
            _G._HaloRightArmStretching = true
        else
            tw(stToggleBg, 0.2, {BackgroundColor3 = C.bg4}):Play()
            tw(stToggleKnob, 0.2, {Position = UDim2.new(0,3,0,3)}):Play()
            _G._HaloLeftArmStretching = false
            _G._HaloRightArmStretching = false
        end
    end
    stToggleBtn.MouseButton1Click:Connect(function()
        ArmStretchEnabled = not ArmStretchEnabled
        updateStretchState()
    end)

    new("TextLabel",stFrame,{Size=UDim2.new(1,-120,0,16),Position=UDim2.new(0,10,0,88),
        BackgroundTransparency=1,Text="Head Stretch",TextColor3=C.text,TextSize=11,
        Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left})
    local hsToggleBg = new("Frame",stFrame,{Size=UDim2.new(0,44,0,22),Position=UDim2.new(1,-54,0,86),
        BackgroundColor3=C.bg4,BorderSizePixel=0}); corner(hsToggleBg,11)
    local hsToggleKnob = new("Frame",hsToggleBg,{
        Size=UDim2.new(0,16,0,16),Position=UDim2.new(0,3,0,3),
        BackgroundColor3=C.white,BorderSizePixel=0}); corner(hsToggleKnob,8)
    local hsToggleBtn = new("TextButton",hsToggleBg,{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text=""})
    local hsAmtLbl = new("TextLabel",stFrame,{Size=UDim2.new(0,70,0,14),Position=UDim2.new(0,10,0,116),
        BackgroundTransparency=1,Text="1.0x",TextColor3=C.accent,TextSize=10,
        Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left})
    local hsTrack = new("Frame",stFrame,{BackgroundColor3=C.bg2,BackgroundTransparency=0.3,
        BorderSizePixel=0,Position=UDim2.new(0,80,0,119),Size=UDim2.new(1,-95,0,8)})
    corner(hsTrack,4)
    local hsFill = new("Frame",hsTrack,{BackgroundColor3=C.accent,BackgroundTransparency=0.1,
        BorderSizePixel=0,Size=UDim2.new(0,0,1,0)})
    corner(hsFill,4)
    local hsHandle = new("Frame",hsTrack,{AnchorPoint=Vector2.new(0.5,0.5),
        BackgroundColor3=C.accent,BorderSizePixel=0,
        Position=UDim2.new(0,0,0.5,0),Size=UDim2.new(0,12,0,12)})
    corner(hsHandle,6)
    _G._HaloHeadStretchAmount = _G._HaloHeadStretchAmount or 1
    local function updateHeadSlider(amt)
        amt = math.clamp(amt, 1, 3)
        _G._HaloHeadStretchAmount = amt
        local pct = (amt - 1) / 2
        hsFill.Size = UDim2.new(pct, 0, 1, 0)
        hsHandle.Position = UDim2.new(pct, 0, 0.5, 0)
        hsAmtLbl.Text = string.format("%.1fx", amt)
    end
    local HeadStretchOn = false
    local function updateHeadStretch()
        _G._HaloHeadStretching = HeadStretchOn
        if HeadStretchOn then
            tw(hsToggleBg, 0.2, {BackgroundColor3 = C.green}):Play()
            tw(hsToggleKnob, 0.2, {Position = UDim2.new(1,-18,0,3)}):Play()
        else
            tw(hsToggleBg, 0.2, {BackgroundColor3 = C.bg4}):Play()
            tw(hsToggleKnob, 0.2, {Position = UDim2.new(0,3,0,3)}):Play()
        end
    end
    hsToggleBtn.MouseButton1Click:Connect(function()
        HeadStretchOn = not HeadStretchOn
        updateHeadStretch()
    end)
    local hsDragging = false
    hsTrack.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            hsDragging = true
            local pct = math.clamp((inp.Position.X - hsTrack.AbsolutePosition.X) / hsTrack.AbsoluteSize.X, 0, 1)
            updateHeadSlider(1 + pct * 2)
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then hsDragging = false end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if hsDragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
            local pct = math.clamp((inp.Position.X - hsTrack.AbsolutePosition.X) / hsTrack.AbsoluteSize.X, 0, 1)
            updateHeadSlider(1 + pct * 2)
        end
    end)

    local stDragging = false
    stTrack.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            stDragging = true
            local pct = math.clamp((inp.Position.X - stTrack.AbsolutePosition.X) / stTrack.AbsoluteSize.X, 0, 1)
            updateSliderUI(sliderPctToAmt(pct))
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 and stDragging then stDragging = false end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if stDragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
            local pct = math.clamp((inp.Position.X - stTrack.AbsolutePosition.X) / stTrack.AbsoluteSize.X, 0, 1)
            updateSliderUI(sliderPctToAmt(pct))
        end
    end)

    -- Ctrl + MouseWheel stretch control (auto-enables stretch)
    _G._HaloReanimConns = _G._HaloReanimConns or {}
    _G._HaloCtrlHeld = false

    local function _haloStretchWheelAction(actionName, inputState, inputObj)
        -- Swallow the wheel input so camera doesn't zoom
        if inputState == Enum.UserInputState.Change then
            -- Auto-enable arm stretch toggles if off
            ArmStretchEnabled = true
            updateStretchState()

            local current = _G._HaloArmStretchAmount or 2.5
            local stepSize = _G._HaloStretchStepSize or 2.5
            local delta = (inputObj.Position.Z > 0) and stepSize or -stepSize
            local newAmt = math.clamp(current + delta, SLIDER_MIN, SLIDER_MAX)
            updateSliderUI(newAmt)
        end
        return Enum.ContextActionResult.Sink
    end

    _G._HaloReanimConns.StretchCtrlBegan = UserInputService.InputBegan:Connect(function(inp, gp)
        if gp then return end
        if inp.KeyCode == Enum.KeyCode.LeftControl or inp.KeyCode == Enum.KeyCode.RightControl then
            if not _G._HaloCtrlHeld then
                _G._HaloCtrlHeld = true
                -- Bind mouse wheel to our action (swallows zoom)
                pcall(function()
                    ContextActionService:BindAction("HaloStretchWheel", _haloStretchWheelAction, false, Enum.UserInputType.MouseWheel)
                end)
            end
        end
    end)

    _G._HaloReanimConns.StretchCtrlEnded = UserInputService.InputEnded:Connect(function(inp, gp)
        if inp.KeyCode == Enum.KeyCode.LeftControl or inp.KeyCode == Enum.KeyCode.RightControl then
            -- Only release if NEITHER ctrl is held
            local stillHeld = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
            if not stillHeld then
                _G._HaloCtrlHeld = false
                -- Unbind = camera zoom works again
                pcall(function()
                    ContextActionService:UnbindAction("HaloStretchWheel")
                end)
            end
        end
    end)

    _G.HaloHiddenPlayers = _G.HaloHiddenPlayers or {}
    _G.FriendListenerEnabled = false
    _G.FriendListenerAutoExecute = false

    local friendCache = {}
    local function cacheFriendship(p)
        if p == plr then return end
        task.spawn(function()
            local success, result = pcall(function()
                return plr:IsFriendsWith(p.UserId)
            end)
            if success then
                friendCache[p.UserId] = result
            end
        end)
    end
    for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
        cacheFriendship(p)
    end
    game:GetService("Players").PlayerAdded:Connect(cacheFriendship)

    local function isFriend(userId)
        if userId == plr.UserId then return true end
        if friendCache[userId] ~= nil then
            return friendCache[userId]
        end
        return false
    end

    -- Multi-layered State Manager
    local function getShouldMute(userId)
        if userId == plr.UserId then return false end
        _G.HaloHiddenPlayers = _G.HaloHiddenPlayers or {}
        local isHidden = _G.HaloHiddenPlayers[userId]
        local isFriendUser = isFriend(userId)
        local shouldMute = isHidden or (_G.FriendListenerEnabled and not isFriendUser)
        return shouldMute
    end

    local function updatePlayerState(p)
        if not p or p == plr then return end
        local shouldHide = _G.HaloHiddenPlayers and _G.HaloHiddenPlayers[p.UserId]
        local shouldMute = shouldHide or (_G.FriendListenerEnabled and not isFriend(p.UserId))

        -- 1. Roblox Core Muting (if supported by game setup)
        if shouldMute then
            pcall(function() game:GetService("StarterGui"):SetCore("ChatMutePlayer", p.Name) end)
        else
            pcall(function() game:GetService("StarterGui"):SetCore("ChatUnmutePlayer", p.Name) end)
        end

        -- 2. Visual Hiding (Local Parenting manipulation)
        local char = p.Character
        if char then
            if shouldHide then
                char.Parent = nil
            else
                if char.Parent == nil then
                    char.Parent = workspace
                end
            end
        end
    end

    local function applyAllMutes()
        for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
            updatePlayerState(p)
        end
    end
    _G.HaloApplyAllMutes = applyAllMutes

    -- Monitor Character additions
    local function hookCharacter(p)
        p.CharacterAdded:Connect(function(char)
            task.wait(0.1)
            updatePlayerState(p)
        end)
        if p.Character then
            updatePlayerState(p)
        end
    end
    for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
        if p ~= plr then hookCharacter(p) end
    end
    game:GetService("Players").PlayerAdded:Connect(function(p)
        if p ~= plr then hookCharacter(p) end
    end)

    -- Modern Chat (TextChatService) Callback
    pcall(function()
        local TextChatService = game:GetService("TextChatService")
        local oldCallback = TextChatService.OnIncomingMessage
        TextChatService.OnIncomingMessage = function(message)
            local props = oldCallback and oldCallback(message) or Instance.new("TextChatMessageProperties")
            if message.TextSource then
                if getShouldMute(message.TextSource.UserId) then
                    props.Text = ""
                    props.PrefixText = ""
                end
            end
            return props
        end
    end)

    -- Modern Chat MessageReceived Hook
    pcall(function()
        local TextChatService = game:GetService("TextChatService")
        TextChatService.MessageReceived:Connect(function(textMessage)
            if textMessage.TextSource then
                if getShouldMute(textMessage.TextSource.UserId) then
                    local p = game:GetService("Players"):GetPlayerByUserId(textMessage.TextSource.UserId)
                    if p then
                        pcall(function() game:GetService("StarterGui"):SetCore("ChatMutePlayer", p.Name) end)
                    end
                end
            end
        end)
    end)

    -- Legacy Chat Scroller Listener (with Text property monitoring)
    local function setupScrollerListener(scroller)
        local function handleMessageFrame(child)
            if not child:IsA("Frame") then return end
            task.spawn(function()
                local textLabel = child:WaitForChild("TextLabel", 2)
                if textLabel and textLabel:IsA("TextLabel") then
                    local function checkText()
                        local text = textLabel.Text
                        if text ~= "" then
                            for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
                                if getShouldMute(p.UserId) then
                                    if text:find(p.Name) or text:find(p.DisplayName) then
                                        child:Destroy()
                                        break
                                    end
                                end
                            end
                        end
                    end
                    textLabel:GetPropertyChangedSignal("Text"):Connect(checkText)
                    checkText()
                end
            end)
        end
        scroller.ChildAdded:Connect(handleMessageFrame)
        for _, child in ipairs(scroller:GetChildren()) do
            handleMessageFrame(child)
        end
    end

    -- Hook legacy chat scroller immediately and if recreated
    task.spawn(function()
        local chatGui = plr:WaitForChild("PlayerGui"):WaitForChild("Chat", 10)
        if chatGui then
            local scroller = chatGui:FindFirstChild("Scroller", true)
            if scroller then setupScrollerListener(scroller) end
            chatGui.DescendantAdded:Connect(function(desc)
                if desc.Name == "Scroller" and desc:IsA("ScrollingFrame") then
                    setupScrollerListener(desc)
                end
            end)
        end
    end)

    -- Update mutes when players join/leave
    game:GetService("Players").PlayerAdded:Connect(function(p)
        applyAllMutes()
    end)

    -- Handle Toggle Calls
    _G.UpdateFriendListener = function(state)
        _G.FriendListenerEnabled = state
        applyAllMutes()
    end

    -- Load Friend Config
    pcall(function()
        if readfile and isfile and isfile("HaloV2Folder/friend_listener_config.json") then
            local data = game:GetService("HttpService"):JSONDecode(readfile("HaloV2Folder/friend_listener_config.json"))
            if data then
                _G.FriendListenerAutoExecute = data.autoExecute or false
                if _G.FriendListenerAutoExecute then
                    _G.FriendListenerEnabled = true
                    _G.UpdateFriendListener(true)
                end
            end
        end
    end)

    -- Fling Aura (Kill / Fling other players on contact)
    local flingAuraFrame = new("Frame",sc,{Size=UDim2.new(1,-10,0,60),BackgroundColor3=C.bg2,BackgroundTransparency=0.45,BorderSizePixel=0})
    corner(flingAuraFrame,8); stroke(flingAuraFrame,C.glassBorder,1,0.6)

    new("TextLabel",flingAuraFrame,{Size=UDim2.new(1,-120,0,18),Position=UDim2.new(0,10,0,10),
        BackgroundTransparency=1,Text="Fling Aura",TextColor3=C.text,TextSize=11,
        Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left})

    new("TextLabel",flingAuraFrame,{Size=UDim2.new(1,-130,0,20),Position=UDim2.new(0,10,0,28),
        BackgroundTransparency=1,Text="Spins your physical character parts at extreme velocity to fling players on touch.",
        TextColor3=C.text3,TextSize=9,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true})

    local flingToggleBg = new("Frame",flingAuraFrame,{Size=UDim2.new(0,44,0,22),Position=UDim2.new(1,-54,0,19),
        BackgroundColor3=C.bg4,BorderSizePixel=0}); corner(flingToggleBg,11)
    local flingToggleKnob = new("Frame",flingToggleBg,{
        Size=UDim2.new(0,16,0,16),Position=UDim2.new(0,3,0,3),
        BackgroundColor3=C.white,BorderSizePixel=0}); corner(flingToggleKnob,8)
    local flingToggleBtn = new("TextButton",flingToggleBg,{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text=""})

    local FlingAuraEnabled = false
    local flingAuraConn = nil

    local function updateFlingAuraState()
        if FlingAuraEnabled then
            tw(flingToggleBg, 0.2, {BackgroundColor3 = C.green}):Play()
            tw(flingToggleKnob, 0.2, {Position = UDim2.new(1,-18,0,3)}):Play()
            
            -- Spin loop
            if flingAuraConn then flingAuraConn:Disconnect() end
            flingAuraConn = RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function()
                local char = plr.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.RotVelocity = Vector3.new(0, 15000, 0)
                    hrp.Velocity = Vector3.new(0, 0.1, 0)
                end
            end))
        else
            tw(flingToggleBg, 0.2, {BackgroundColor3 = C.bg4}):Play()
            tw(flingToggleKnob, 0.2, {Position = UDim2.new(0,3,0,3)}):Play()
            if flingAuraConn then
                flingAuraConn:Disconnect()
                flingAuraConn = nil
            end
        end
    end

    flingToggleBtn.MouseButton1Click:Connect(function()
        FlingAuraEnabled = not FlingAuraEnabled
        updateFlingAuraState()
    end)

    -- Mobile Emote Wheel Button (draggable, for mobile/touch players)
    local mobileWheelFrame = new("Frame",sc,{Size=UDim2.new(1,-10,0,60),BackgroundColor3=C.bg2,BackgroundTransparency=0.45,BorderSizePixel=0})
    corner(mobileWheelFrame,8); stroke(mobileWheelFrame,C.glassBorder,1,0.6)

    new("TextLabel",mobileWheelFrame,{Size=UDim2.new(1,-120,0,18),Position=UDim2.new(0,10,0,10),
        BackgroundTransparency=1,Text="Mobile Wheel Button",TextColor3=C.text,TextSize=11,
        Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left})

    new("TextLabel",mobileWheelFrame,{Size=UDim2.new(1,-130,0,20),Position=UDim2.new(0,10,0,28),
        BackgroundTransparency=1,Text="Draggable on-screen button to open the emote wheel.",
        TextColor3=C.text3,TextSize=9,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true})

    local mobileToggleBg = new("Frame",mobileWheelFrame,{Size=UDim2.new(0,44,0,22),Position=UDim2.new(1,-54,0,19),
        BackgroundColor3=C.bg4,BorderSizePixel=0}); corner(mobileToggleBg,11)
    local mobileToggleKnob = new("Frame",mobileToggleBg,{
        Size=UDim2.new(0,16,0,16),Position=UDim2.new(0,3,0,3),
        BackgroundColor3=C.white,BorderSizePixel=0}); corner(mobileToggleKnob,8)
    local mobileToggleBtn = new("TextButton",mobileToggleBg,{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text=""})

    -- 2. Clear Cache section
    local cacheFrame = new("Frame",sc,{Size=UDim2.new(1,-10,0,60),BackgroundColor3=C.bg2,BackgroundTransparency=0.45,BorderSizePixel=0})
    corner(cacheFrame,8); stroke(cacheFrame,C.glassBorder,1,0.6)
    
    new("TextLabel",cacheFrame,{Size=UDim2.new(1,-120,0,18),Position=UDim2.new(0,10,0,10),
        BackgroundTransparency=1,Text="Clear Cache",TextColor3=C.text,TextSize=11,
        Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left})
        
    new("TextLabel",cacheFrame,{Size=UDim2.new(1,-130,0,20),Position=UDim2.new(0,10,0,28),
        BackgroundTransparency=1,Text="Deletes all cache, including favourites. Keeps custom anims.",
        TextColor3=C.text3,TextSize=9,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true})

    local clearCacheBtn = new("TextButton",cacheFrame,{Size=UDim2.new(0,100,0,28),Position=UDim2.new(1,-110,0,16),
        BackgroundColor3=C.red,BackgroundTransparency=0.3,Text="Clear Cache",TextColor3=C.white,
        TextSize=10,Font=Enum.Font.GothamBold,BorderSizePixel=0}); corner(clearCacheBtn,6)

    -- The draggable button itself
    local mobileBtnGui = Instance.new("ScreenGui")
    mobileBtnGui.Name = "HaloMobileWheelBtn"
    mobileBtnGui.ResetOnSpawn = false
    mobileBtnGui.IgnoreGuiInset = true
    mobileBtnGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    mobileBtnGui.DisplayOrder = 550
    pcall(function() mobileBtnGui.Parent = game:GetService("CoreGui") end)
    if not mobileBtnGui.Parent then mobileBtnGui.Parent = PlayerGui end

    local mobileBtn = Instance.new("ImageButton", mobileBtnGui)
    mobileBtn.Size = UDim2.new(0, 46, 0, 46)
    mobileBtn.Position = UDim2.new(1, -50, 0.5, 0)
    mobileBtn.AnchorPoint = Vector2.new(0.5, 0.5)
    mobileBtn.BackgroundColor3 = C.bg0
    mobileBtn.BackgroundTransparency = 0.2
    mobileBtn.Image = ""
    mobileBtn.AutoButtonColor = false
    mobileBtn.BorderSizePixel = 0
    mobileBtn.Visible = false
    Instance.new("UICorner", mobileBtn).CornerRadius = UDim.new(0, 10)
    local mobileBtnStroke = Instance.new("UIStroke", mobileBtn)
    mobileBtnStroke.Color = C.glassBorder
    mobileBtnStroke.Thickness = 1
    mobileBtnStroke.Transparency = 0.4

    local mobileBtnIcon = Instance.new("TextLabel", mobileBtn)
    mobileBtnIcon.Size = UDim2.new(1, 0, 1, 0)
    mobileBtnIcon.BackgroundTransparency = 1
    mobileBtnIcon.Text = "E"
    mobileBtnIcon.TextColor3 = C.accent
    mobileBtnIcon.TextSize = 18
    mobileBtnIcon.Font = Enum.Font.GothamBold

    -- Dragging logic
    local draggingMobile = false
    local dragStartMobile, startPosMobile
    local dragMovedMobile = false
    mobileBtn.InputBegan:Connect(LPH_NO_VIRTUALIZE(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingMobile = true
            dragMovedMobile = false
            dragStartMobile = input.Position
            startPosMobile = mobileBtn.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    draggingMobile = false
                end
            end)
        end
    end))
    mobileBtn.InputChanged:Connect(LPH_JIT(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            if draggingMobile and dragStartMobile then
                local delta = input.Position - dragStartMobile
                if delta.Magnitude > 4 then dragMovedMobile = true end
                
                -- Same clamp logic as the reanim window: keep the button fully on-screen.
                local parent = mobileBtn.Parent
                if not parent then return end
                local pap    = parent.AbsolutePosition
                local pas    = parent.AbsoluteSize
                local sz     = mobileBtn.AbsoluteSize
                local anchor = mobileBtn.AnchorPoint
                local scaleX = startPosMobile.X.Scale
                local scaleY = startPosMobile.Y.Scale
                local desiredOffsetX = startPosMobile.X.Offset + delta.X
                local desiredOffsetY = startPosMobile.Y.Offset + delta.Y
                local targetAbsX = pap.X + scaleX * pas.X + desiredOffsetX
                local targetAbsY = pap.Y + scaleY * pas.Y + desiredOffsetY
                local topLeftX = targetAbsX - anchor.X * sz.X
                local topLeftY = targetAbsY - anchor.Y * sz.Y
                topLeftX = math.clamp(topLeftX, pap.X, math.max(pap.X, pap.X + pas.X - sz.X))
                topLeftY = math.clamp(topLeftY, pap.Y, math.max(pap.Y, pap.Y + pas.Y - sz.Y))
                local newAbsX = topLeftX + anchor.X * sz.X
                local newAbsY = topLeftY + anchor.Y * sz.Y
                local newOffsetX = newAbsX - pap.X - scaleX * pas.X
                local newOffsetY = newAbsY - pap.Y - scaleY * pas.Y
                mobileBtn.Position = UDim2.new(scaleX, newOffsetX, scaleY, newOffsetY)
            end
        end
    end))

    mobileBtn.MouseButton1Click:Connect(function()
        if dragMovedMobile then return end
        if _G._OpenFortniteWheel then
            _G._OpenFortniteWheel()
        end
    end)

    local mobileEnabled = false

    pcall(function()
        local raw = readfile(CONFIG.FOLDER .. "/ReanimMobileWheelBtn.json")
        if raw then
            local data = HttpService:JSONDecode(raw)
            if data and (data.enabled == true or data.enabled == 1) then
                mobileEnabled = true
                _G._HaloMobileWheelEnabled = true
                mobileBtn.Visible = true
                mobileToggleBg.BackgroundColor3 = C.accent
                mobileToggleKnob.Position = UDim2.new(1,-18,0,3)
            end
            if data and data.posX and data.posY then
                mobileBtn.Position = UDim2.new(data.posX, data.posXO or 0, data.posY, data.posYO or 0)
            end
        end
    end)

    local mobileSavePath = CONFIG.FOLDER .. "/ReanimMobileWheelBtn.json"

    local function saveMobileBtnState()
        local jsonStr = HttpService:JSONEncode({
            enabled = mobileEnabled and 1 or 0,
            posX = mobileBtn.Position.X.Scale,
            posXO = mobileBtn.Position.X.Offset,
            posY = mobileBtn.Position.Y.Scale,
            posYO = mobileBtn.Position.Y.Offset,
        })
        pcall(function() makefolder(CONFIG.FOLDER) end)
        writefile(mobileSavePath, jsonStr)
    end

    local function doMobileToggle()
        mobileEnabled = not mobileEnabled
        mobileBtn.Visible = mobileEnabled
        _G._HaloMobileWheelEnabled = mobileEnabled
        if mobileEnabled then
            tw(mobileToggleBg, 0.2, {BackgroundColor3 = C.accent}):Play()
            tw(mobileToggleKnob, 0.2, {Position = UDim2.new(1,-18,0,3)}):Play()
        else
            tw(mobileToggleBg, 0.2, {BackgroundColor3 = C.bg4}):Play()
            tw(mobileToggleKnob, 0.2, {Position = UDim2.new(0,3,0,3)}):Play()
        end
        pcall(saveMobileBtnState)
        if _G._HaloUpdateMobileBtnText then pcall(_G._HaloUpdateMobileBtnText) end
    end

    _G._HaloToggleMobileWheel = doMobileToggle
    _G._HaloMobileWheelEnabled = mobileEnabled

    mobileToggleBtn.MouseButton1Click:Connect(function()
        doMobileToggle()
    end)

    if ScreenGui then
        ScreenGui.AncestryChanged:Connect(LPH_NO_VIRTUALIZE(function()
            if not ScreenGui.Parent then
                mobileBtn.Visible = false
                if ReanimateAPI and ReanimateAPI.stop_emote_audio then
                    pcall(ReanimateAPI.stop_emote_audio, true)
                end
                if fnGui then
                    pcall(function() fnGui:Destroy() end)
                end
                pcall(function()
                    for _, child in ipairs(game:GetService("SoundService"):GetChildren()) do
                        if child.Name == "HaloEmoteSound" or child.Name == "HaloClickSound" then
                            child:Stop(); child:Destroy()
                        end
                    end
                end)
            end
        end))
    end

    -- Instant Reset Keybind
    local irFrame = new("Frame",sc,{Size=UDim2.new(1,-10,0,54),BackgroundColor3=C.bg2,BackgroundTransparency=0.45,BorderSizePixel=0})
    corner(irFrame,8); stroke(irFrame,C.glassBorder,1,0.6)

    new("TextLabel",irFrame,{Size=UDim2.new(1,-120,0,16),Position=UDim2.new(0,10,0,6),
        BackgroundTransparency=1,Text="Instant Reset Key",TextColor3=C.text,TextSize=11,
        Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left})

    new("TextLabel",irFrame,{Size=UDim2.new(1,-120,0,24),Position=UDim2.new(0,10,0,24),
        BackgroundTransparency=1,Text="Press to instantly reset and respawn at the same position.",
        TextColor3=C.text3,TextSize=9,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true})

    local irBtn = new("TextButton",irFrame,{Size=UDim2.new(0,96,0,24),Position=UDim2.new(1,-102,0.5,-12),
        BackgroundColor3=C.bg2,BackgroundTransparency=0.2,BorderSizePixel=0,
        Font=Enum.Font.GothamBold,Text="Key: None",TextColor3=C.accent,TextSize=10})
    corner(irBtn,5); stroke(irBtn,C.border,1,0.7)

    local function updateIrBtnText()
        local keyName = _G._HaloInstantResetKey and _G._HaloInstantResetKey.Name or "None"
        irBtn.Text = "Key: " .. keyName
    end
    updateIrBtnText()

    local settingIrKey = false
    irBtn.MouseButton1Click:Connect(function()
        if settingIrKey then return end
        if _G._HaloInstantResetKey then
            _G._HaloInstantResetKey = nil
            SaveData()
            updateIrBtnText()
            return
        end
        settingIrKey = true
        irBtn.Text = "Listening..."
        irBtn.BackgroundColor3 = C.yellow
        local keyConn
        keyConn = UserInputService.InputBegan:Connect(LPH_NO_VIRTUALIZE(function(i, gp)
            if gp then return end
            keyConn:Disconnect()
            settingIrKey = false
            irBtn.BackgroundColor3 = C.bg2
            if i.KeyCode == Enum.KeyCode.Escape then
                updateIrBtnText()
                return
            end
            _G._HaloInstantResetKey = i.KeyCode
            SaveData()
            updateIrBtnText()
        end))
    end)

    -- VC Bypass Button
    local vcFrame = new("Frame",sc,{Size=UDim2.new(1,-10,0,60),BackgroundColor3=C.bg2,BackgroundTransparency=0.45,BorderSizePixel=0})
    corner(vcFrame,8); stroke(vcFrame,C.glassBorder,1,0.6)

    new("TextLabel",vcFrame,{Size=UDim2.new(1,-120,0,18),Position=UDim2.new(0,10,0,10),
        BackgroundTransparency=1,Text="VC Bypass",TextColor3=C.text,TextSize=11,
        Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left})

    new("TextLabel",vcFrame,{Size=UDim2.new(1,-130,0,20),Position=UDim2.new(0,10,0,28),
        BackgroundTransparency=1,Text="Bypass voice chat mute restrictions. Unmute mic when prompted.",
        TextColor3=C.text3,TextSize=9,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true})

    local vcBtn = new("TextButton",vcFrame,{
        Size=UDim2.new(0,80,0,28),Position=UDim2.new(1,-94,0,16),
        BackgroundColor3=C.bg3,BackgroundTransparency=0.2,
        BorderSizePixel=0,Font=Enum.Font.GothamBold,
        Text="Enable",TextColor3=C.accent,TextSize=10,AutoButtonColor=false})
    corner(vcBtn,6)
    stroke(vcBtn,C.glassBorder,1,0.5)

    local function updateVCBtn()
        if VCBypassEnabled then
            vcBtn.Text = "Disable"
            vcBtn.BackgroundColor3 = C.green
            vcBtn.TextColor3 = Color3.fromRGB(0,0,0)
        else
            vcBtn.Text = "Enable"
            vcBtn.BackgroundColor3 = C.bg3
            vcBtn.TextColor3 = C.accent
        end
    end

    vcBtn.MouseEnter:Connect(function()
        if not VCBypassEnabled then
            tw(vcBtn, 0.15, {BackgroundColor3 = C.accent, TextColor3 = Color3.fromRGB(0,0,0)}):Play()
        end
    end)
    vcBtn.MouseLeave:Connect(function()
        updateVCBtn()
    end)

    vcBtn.MouseButton1Click:Connect(function()
        if VCBypassEnabled then
            cleanupVCBypass()
            updateVCBtn()
            Notify("VC Bypass disabled", 2)
        else
            applyVCBypass()
            updateVCBtn()
            Notify("VC Bypass enabled! Unmute your mic when prompted.", 4)
        end
    end)

    local acFrame = new("Frame", sc, {Size=UDim2.new(1,-10,0,60), BackgroundColor3=C.bg2, BackgroundTransparency=0.45, BorderSizePixel=0})
    corner(acFrame, 8); stroke(acFrame, C.glassBorder, 1, 0.6)
    new("TextLabel", acFrame, {Size=UDim2.new(1,-120,0,18), Position=UDim2.new(0,10,0,10),
        BackgroundTransparency=1, Text="Anti Crash", TextColor3=C.text, TextSize=11,
        Font=Enum.Font.GothamBold, TextXAlignment=Enum.TextXAlignment.Left})
    new("TextLabel", acFrame, {Size=UDim2.new(1,-130,0,20), Position=UDim2.new(0,10,0,28),
        BackgroundTransparency=1, Text="Off until you enable it. Blocks crash part, sound, and particle spam.",
        TextColor3=C.text3, TextSize=9, Font=Enum.Font.Gotham, TextXAlignment=Enum.TextXAlignment.Left, TextWrapped=true})
    local acBtn = new("TextButton", acFrame, {
        Size=UDim2.new(0,80,0,28), Position=UDim2.new(1,-94,0,16),
        BackgroundColor3=C.bg3, BackgroundTransparency=0.2,
        BorderSizePixel=0, Font=Enum.Font.GothamBold,
        Text="Enable", TextColor3=C.accent, TextSize=10, AutoButtonColor=false})
    corner(acBtn, 6)
    stroke(acBtn, C.glassBorder, 1, 0.5)
    local function updateAC()
        if _G._HaloAntiCrash then
            acBtn.Text = "Disable"
            acBtn.BackgroundColor3 = C.green
            acBtn.TextColor3 = Color3.fromRGB(0,0,0)
        else
            acBtn.Text = "Enable"
            acBtn.BackgroundColor3 = C.bg3
            acBtn.TextColor3 = C.accent
        end
    end
    acBtn.MouseButton1Click:Connect(function()
        _G._HaloAntiCrash = not _G._HaloAntiCrash
        updateAC()
    end)
    updateAC()
    -- Version info / Credits
    local infoFrame = new("Frame",sc,{Size=UDim2.new(1,-10,0,50),BackgroundColor3=C.bg2,BackgroundTransparency=0.6,BorderSizePixel=0})
    corner(infoFrame,8); stroke(infoFrame,C.glassBorder,1,0.6)
    new("TextLabel",infoFrame,{Size=UDim2.new(1,-20,1,0),Position=UDim2.new(0,10,0,0),
        BackgroundTransparency=1,Text="Halo Reanim\nVersion: " .. CONFIG.VERSION .. " | Best reanim out",
        TextColor3=C.text3,TextSize=9,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Center,TextYAlignment=Enum.TextYAlignment.Center})

    -- Wire up Import from AK button (merged into settings panel handler)

    -- Wire up Clear Cache button
    clearCacheBtn.MouseButton1Click:Connect(function()
        clearCacheBtn.Text = "Clearing..."
        pcall(function()
            local folder = CONFIG.FOLDER
            local cacheFolder = CONFIG.CACHE_FOLDER
            local deleteFunc = delfile or delete_file or (function(path) pcall(writefile, path, "") end)
            local listFilesFunc = listfiles or list_files

            -- 1. Delete known configuration files explicitly (both spellings/formats)
            local knownConfigs = {
                "ReanimFavorites.json",
                "ReanimFavourites.json",
                "ReanimStates.json",
                "ReanimKeybinds.json",
                "ReanimSpeedKeys.json",
                "ReanimRevSpeedKeys.json",
                "ReanimSpeed.json",
                "OnlineAnimationsCache.json",
                "ReanimCustomAnims.json"
            }
            for _, filename in ipairs(knownConfigs) do
                pcall(deleteFunc, folder .. "/" .. filename)
            end

            -- 2. Clear the cache folder completely (all cached online animation source files)
            local okCache, cacheFiles = pcall(function()
                if listFilesFunc then return listFilesFunc(cacheFolder) end
                return {}
            end)
            if okCache and type(cacheFiles) == "table" then
                for _, file in ipairs(cacheFiles) do
                    pcall(deleteFunc, file)
                end
            end

            -- 3. Delete any other configuration or non-animation files in ReanimData
            local okFolder, folderFiles = pcall(function()
                if listFilesFunc then return listFilesFunc(folder) end
                return {}
            end)
            if okFolder and type(folderFiles) == "table" then
                local ignored = {
                    reanimfavorites = true,
                    reanimfavourites = true,
                    reanimkeybinds = true,
                    reanimspeedkeys = true,
                    reanimstates = true,
                    reanimspeed = true,
                    onlineanimationscache = true
                }
                for _, file in ipairs(folderFiles) do
                    local n = file:match("([^/\\]+)%.[%w]+$")
                    if n then
                        local lowerName = n:lower()
                        local isLua = file:match("%.lua$")
                        local isJson = file:match("%.json$") or file:match("%.txt$")
                        local isAnim = (isLua or isJson) and not file:match("[Ss]ettings") and not file:match("[Cc]onfig") and not lowerName:match("^anim_%d+$") and not ignored[lowerName]
                        
                        if not isAnim then
                            pcall(deleteFunc, file)
                        end
                    elseif not file:match("/$") and not file:match("\\$") then
                        pcall(deleteFunc, file)
                    end
                end
            end

            -- 4. Reset in-memory state
            Favorites = {}
            StateAnims = {}
            Keybinds = {}
            SpeedKeybinds = {}
            for i = 1, 6 do
                SpeedKeybinds[i] = {speed = i * 0.5, key = nil}
            end
            table.clear(AnimationCache)

            -- 5. Reload data defaults and refresh UI
            -- AnimationList is hardcoded; no reload needed
            SaveData()
            RebuildVisible()
            Notify("Cache Cleared", "All settings and caches wiped except custom animations!", 4)
        end)
        clearCacheBtn.Text = "Clear Cache"
    end)
end
buildSettingsUI()

RunService.RenderStepped:Connect(LPH_NO_VIRTUALIZE(function()
    if not _reanimAPIReady then return end

    local currentTime = tick()

    -- FPS optimization: skip every other frame for non-critical checks
    _frameSkipCounter = (_frameSkipCounter or 0) + 1
    if _frameSkipCounter % 2 == 0 then return end

    if currentTime - _lastApiCheck >= 0.5 then
        local apiOk, apiVal = pcall(function() return ReanimateAPI.is_reanimated() end)
        local apiState = apiOk and apiVal or false
        if type(apiState) == "boolean" and apiState ~= State.isReanimated then
            State.isReanimated = apiState
            if not apiState then State.selectedAnim = nil end
            UpdateToggleBtn()
        end
        _lastApiCheck = currentTime
    end

    if State.isReanimated and not State.rawAnimPlaying then
        if currentTime - _lastAnimCheck >= 0.2 then
            local ok, playing = pcall(function() return ReanimateAPI.is_animation_playing() end)
            if ok and not playing and State.selectedAnim then
                State.selectedAnim = nil
                NowPlayingLabel.Text = "No animation playing"
                RefreshVirtualRows()
                RefreshCustomRows()
                if next(StateAnims) and not stateSystemActive then
                    startStateSystem()
                end
            end
            _lastAnimCheck = currentTime
        end
    end

    if State.isReanimated and isShiftLockActive() then
        local char = plr.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local _, camY, _ = Camera.CFrame:ToEulerAnglesYXZ()
                hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, camY, 0)
            end
        end
    end
end))

do
    -- Define the Fortnite Wheel UI structure
    task.spawn(LPH_NO_VIRTUALIZE(function()
        
                local OriginalEmotes = {
            "Deep End",
            "Death",
            "XO",
            "Freewheelin'",
            "Hatchback",
            "Dreamer",
            "Roundabout",
            "Han Solo",
            "Bumblebee",
            "Renegade",
            "Elite Agent",
            "Whiplash",
            "Calamity",
            "Inferno",
            "Sandstorm",
            "Domino",
            "Blade",
            "Headlock",
            "Hopscotch",
            "Dawn",
            "Hana",
            "Accolades",
            "Ground Pound",
            "you should see me in a crown",
            "Cupid's Arrow",
            "Make Some Waves",
            "Show Ya",
            "Bombastic",
            "Disco (Surf Curse)",
            "Air Shredder",
            "Heart-rizon",
            "Extraterrestrial",
            "Touch",
            "Feel the Flow",
            "It's a Vibe",
            "A Warrior Prepares",
            "Showtime",
            "Hypnot-Eyes",
            "Backstroke",
            "Wavy T",
            "Outlaw",
            "Toosie Slide",
            "Rising Phoenix",
            "Dance Off",
            "Deep Explorer",
            "Blinding Lights",
            "Bird Call",
            "earthquake",
            "Flippin' Incredible",
            "Daywalker's Kata",
            "Stormy",
            "Larger Than Life",
            "Rolly Rider",
            "Balletic",
            "Pirouette",
            "Nana Nana",
            "Business Up Front",
            "Tornado Spin",
            "Swag Surfin'",
            "Baller",
            "Ballsy",
            "Headstock Spin",
            "Side Stride",
            "California Love",
            "Beckon",
            "Get Gone",
            "Ska-stra-terrestrial",
            "Side Step",
            "Zany",
            "In Ha Mood",
            "Oh Shhh",
            "Boop!",
            "Point and Strut",
            "Symbol of Peace",
            "Hang Loose Celebration",
            "Shhh.",
            "100% Pure Love",
            "Big Dawgs",
            "Billy Bounce",
            "Smitten",
            "Martial Arts Master",
            "Crossbounce",
            "bb belt",
            "Fast Feet",
            "Build Up",
            "Bhangra Boogie",
            "Boneless",
            "Boogie Down",
            "Bim Bam Boom",
            "Boots 'n' Cats",
            "Cap Kick",
            "Bloomin' Bouquet",
            "Switchstep",
            "Breakin'",
            "Breakneck",
            "Primo Moves",
            "Go Ape",
            "KEHLANI",
            "Swole Cat",
            "Squash & Stretch",
            "XOXO",
            "Run It Down",
            "Hoppity",
            "Bunny Hop",
            "Burpee",
            "Gloss",
            "Take On Me",
            "Boney Bounce",
            "Chase Me Down",
            "Caffeinated",
            "Lights up",
            "Dancin' Domino",
            "Sugar Rush",
            "Shimmy Wiggle",
            "Capoeira",
            "Cartwheelin'",
            "Good Guy",
            "Bring it around",
            "Assumptions",
            "On Your Marks...",
            "Cheer Up",
            "That's So True",
            "Bounce Wit' It",
            "Tootsee",
            "Chicken",
            "Snare Solo",
            "Cluck Strut",
            "Laser Focused",
            "Line Dancin'",
            "Mwahaha",
            "Go! Go! Go!",
            "Shout!",
            "Jump Around",
            "Clap",
            "Rap Monster",
            "Scout Regiment Salute",
            "Keep Me Satisfied",
            "Royals",
            "Dream Stance",
            "Show 'Em Off",
            "Night Out",
            "Rushin' Around",
            "Confused",
            "Conga",
            "Stop!",
            "I Declare!",
            "Overdrive",
            "Copines",
            "Firework",
            "Crowning Achievement",
            "Celebrate Me",
            "Knee Slapper",
            "Warm-Up",
            "Crabby",
            "Aw Snap!",
            "Around the Clock",
            "Crackdown",
            "Crazy Feet",
            "Criss Cross",
            "Fly to Tokyo",
            "Fast Slow Disco",
            "Waterworks",
            "Neva Play",
            "Swing My Way",
            "Rage",
            "Head Banger",
            "Get Loose",
            "Dance Moves",
            "Unification",
            "Boo'd Up Groove",
            "Levitate",
            "Expressionism",
            "Boy's a Liar",
            "Deep Dab",
            "Pump up the Jam",
            "Reaper's Showtime",
            "Heel Click Breakdown",
            "Go With the Flow",
            "Without You",
            "Taste",
            "Please Please Please",
            "Dimensional",
            "Rawr",
            "Denied",
            "Independence",
            "Disco Fever",
            "Heartbreak Shuffle",
            "Pop Muzik",
            "No Tears",
            "Harmony",
            "Strut",
            "Smeeze",
            "Chimichanga!",
            "Revel",
            "Made You Look",
            "Stuck",
            "Ask Me",
            "Dream Feet",
            "Pull Up",
            "Everybody Loves Me",
            "Buckets",
            "Squat Kick",
            "Standing Bow",
            "Look at Me",
            "Glyphic",
            "Hero's Beacon",
            "Electro Shuffle",
            "Signature Shuffle",
            "Electro Swing",
            "Oki Doki",
            "Cairo",
            "Secret Identity",
            "Committed",
            "Charging Up",
            "Boosting Ki",
            "Take it Slow",
            "Vivacious",
            "Carefree",
            "Challenge",
            "Fancy Feet",
            "Fanciful",
            "Ambitious",
            "Bye Bye Bye",
            "Roar",
            "Savage",
            "Shape Up",
            "Rocket Spinner",
            "Fist Pump",
            "Fishy Flourish",
            "Flamenco",
            "Liar",
            "Flapper",
            "Fandangle",
            "Floss",
            "Arm the Pumpkin!",
            "Fresh",
            "Rootin' Tootin'",
            "Sweet Shot",
            "Laid Back Shuffle",
            "Click Click Flash",
            "Dark Side",
            "Get Funky",
            "Sideways Shift",
            "Riches",
            "Hands Off!",
            "Glowsticks",
            "Double Up",
            "Side Shuffle",
            "Jubi Slide",
            "Orange Justice",
            "Infectious",
            "HUMBLE",
            "Tagger's Groove",
            "15 MINUTES",
            "A Bar Song",
            "Get Griddy",
            "Controller Crew",
            "Groove Jam",
            "Vibin'",
            "Telekinetic Power Breakfast",
            "Guitar Walk",
            "Classy Strut",
            "So Low",
            "Windmill Stomp",
            "Bold Stance",
            "Sackin'",
            "Treat Yourself",
            "Segway Tour",
            "Hand Signals",
            "Planetary Vibe",
            "Tra La La",
            "Hello Friend",
            "Feel It",
            "Headbanger",
            "Bobbin'",
            "Real Slim Shady",
            "Still Into You",
            "Reality's Master",
            "High Five",
            "Sucker",
            "Gamma Overload",
            "Witch Way",
            "Daydream",
            "Freestylin'",
            "Breakdown",
            "Free Flow",
            "Hitchhiker",
            "Hang on",
            "Square Up",
            "Say So",
            "GGUM",
            "Hula",
            "Hula Hoopin'",
            "Hooray",
            "Tocked Off",
            "Hype",
            "all red",
            "Sweethearts",
            "JT Coming",
            "Ma-Ya-Hi",
            "IDK",
            "Slide Stride",
            "Houdini",
            "Invisible Stairs",
            "Lavish",
            "Poki",
            "Infinite Dab",
            "Criminals",
            "It's True",
            "Intensity",
            "AFK",
            "Culture Festival Dance",
            "Step It Up",
            "Miku Live",
            "Miku Miku Beam",
            "Clean Groove",
            "Jabba Switchway",
            "Slick",
            "Jazz Hands",
            "Chainsaw Dance",
            "Jiggle Jiggle",
            "Start it Up",
            "Rim Shot",
            "Sunny Stroll",
            "Jugglin'",
            "Out West",
            "Jumping Jacks",
            "I Like To Move It",
            "The Renegade",
            "I'm Diamond",
            "It's Dynamite!",
            "Lucid Dreams",
            "Empty Out Your Pockets",
            "CrazyBoy",
            "Kiss Kiss",
            "Dynamic Shuffle",
            "Bouncy",
            "True Heart",
            "Smooth Moves",
            "Scenario",
            "Glitter",
            "Respect",
            "Shadow Spar",
            "Lazer Blast",
            "Three Wise Monkeys",
            "Sweet Victory",
            "Laugh It Up",
            "Frolic",
            "Lazy Shuffle",
            "Snoop's Walk",
            "The Dogg",
            "Don't Start Now",
            "Hunter Protocol",
            "Do the 'Split",
            "Distraction Dance",
            "Blah Blah Blah",
            "Dancery",
            "Buckle Up",
            "The Pollo Dance",
            "Living Large",
            "Llama Bell",
            "Llama Conga",
            "Chef's Special",
            "Lock It Up",
            "Trinity's Kick",
            "Neo's Bullet Time",
            "Bounce Berry",
            "Bean Bag",
            "Nuthin But A G Thang",
            "PWR Punch",
            "Wu-Tang is Forever",
            "The Macarena",
            "Bratty",
            "Verve",
            "The Silencer",
            "Wind Up",
            "Shake It Up",
            "Kindness Punk",
            "Punched Up",
            "Leave The Door Open",
            "Walkin' Pretty",
            "Mashed Potato",
            "Mr. Brightside",
            "Advanced Math",
            "Snapshot Swagger",
            "No Cure",
            "Mantra",
            "Mine",
            "Moongazer",
            "Entranced",
            "To the Beat",
            "Mime Time",
            "Mind Blown",
            "Illusive",
            "Rhythm of Chaos",
            "Wanna See Me",
            "Bracelets of Hephaestus",
            "Freemix",
            "Keyed Up",
            "Leilt Elomr",
            "It's Go Time!",
            "Spin Out",
            "Bed Chem",
            "Never Gonna",
            "The Quick Style",
            "Empress Fan Dance",
            "Chicken Wing It",
            "Finger Wag",
            "Swag Shuffle",
            "U Can't C Me",
            "Pay it Off",
            "No Sweat",
            "On The Hook",
            "It's a Go!",
            "Lo-fi Headbang",
            "Onda Onda",
            "XO (Only If You Say Yes)",
            "Fist Bump",
            "360",
            "Neighborly Hang",
            "Tippy Tap",
            "Rain Check",
            "All I Want For Christmas Is You",
            "Bear Hug",
            "Paws & Claws",
            "Waddle Away",
            "Spicy Start",
            "BIRDS OF A FEATHER",
            "Phew!",
            "bad guy",
            "Follow the Piper",
            "Gwen-Step",
            "brokenhearted",
            "OMG I LOVE IT",
            "Hellfire Dance",
            "Nitro Fueled",
            "Woke Up",
            "The Dip",
            "Attraction",
            "Synth Step",
            "Swagger Strut",
            "Star Power",
            "Pop Lock",
            "Sad Claps",
            "Tow Truck Surfer",
            "Praise The Tomato",
            "Feelin' Royal",
            "Bust a Move",
            "Perfect Score",
            "Gangnam Style",
            "Pumpernickel",
            "Pump It Up",
            "Pump Me Up",
            "Hand-Forged",
            "Pure Salt",
            "Hit It",
            "Cannon Spike",
            "Jamboree",
            "Rage Quit",
            "Roll Call",
            "You're a Winner",
            "Sweaty",
            "Rebellious",
            "Sonic Surfer",
            "Forget me not",
            "Social Climber",
            "Interstellar Bass",
            "Mask Off",
            "Groove Destroyer",
            "It's Complicated",
            "Ride The Pony",
            "Zombie Shambles",
            "Back On 74",
            "Rocket Rodeo",
            "Jump Jets",
            "Puppet Dance",
            "Arachrobatics",
            "Valentina's Verve",
            "The Rick Dance",
            "Get Schwifty",
            "Running Man",
            "Pick It Up",
            "Knife Tricks",
            "Sumo Salt Throw",
            "Salute",
            "Go Mufasa",
            "Koi Dance",
            "Phone It In",
            "Starting Prance",
            "It's ok I'm ok",
            "Members Only",
            "Work It",
            "Moonlit Mystery",
            "close to you",
            "Hang Loose",
            "Shaolin Sit-up",
            "Starlit",
            "Sway",
            "Dragon Stance",
            "Ratatata",
            "Brite Moves",
            "Showstopper",
            "Sign Spinner",
            "Slalom Style",
            "Fright Funk",
            "Freedom Wheels",
            "Yarn Ball",
            "Very Sneaky",
            "Flashback Breakdown",
            "Soar Above",
            "Kick Ups",
            "Fancy Footwork",
            "Socks",
            "The Spark",
            "Monkey Mosh",
            "Diva Fever",
            "Sparkler",
            "Potted Groot Dance",
            "Spidey Landing",
            "GOATed",
            "Take a 'bow",
            "Popular Vibe",
            "Full Tilt",
            "Monster Mash",
            "Sparrow Run",
            "Sprinkler",
            "Marsh Walk",
            "Keep It Mello",
            "Gentleman's Dab",
            "Statuesque",
            "Side Hustle",
            "Jet Signals",
            "Peace Out",
            "Smooth Operator",
            "Party Hips",
            "Smooth Slide",
            "Tempest Flight",
            "Looking Good",
            "Cardistry",
            "Stay Afloat",
            "Heart of a King",
            "Lunar Party",
            "Bizcochito",
            "Sand Walk",
            "All About That Bass",
            "Survivorsault",
            "Roller Vibes",
            "Jitterbug",
            "Swipe It",
            "The Airplane",
            "Taco Time",
            "Touching The Sky",
            "Take The L",
            "Steady",
            "Dreamy Keys",
            "Lil' Carpet Ride",
            "Hootenanny",
            "Quick Bite",
            "Bet",
            "Havana",
            "Stargazing",
            "Steamed",
            "Evasive Maneuvers",
            "Dust Your Boots Off",
            "The Look",
            "The Flow",
            "Slap Happy",
            "Desirable",
            "Tidy",
            "Timeless",
            "Spring-Loaded",
            "Tiniest Violin",
            "Boom!",
            "Company Jig",
            "Dance Monkey",
            "Spike It",
            "Ninja Style",
            "T-Pose",
            "The Squabble",
            "Stride",
            "Triumphant",
            "Twist",
            "Rollie",
            "Last Forever",
            "Wake Up",
            "My World",
            "Dirtbike Challenge",
            "Cyberdyne Salute",
            "Island Vibes",
            "Break Free",
            "Evil Plan",
            "Punching Practice",
            "I'm Out",
            "Let's Get It Started",
            "Ain't It Fun",
            "Gunslinger Smokeshow",
            "New Woman",
            "In Da Party",
            "I'm a Mystery",
            "Breezy",
            "Image",
            "Dance Therapy",
            "Shaq Shimmy",
            "Dill With It",
            "Flux",
            "Upside Down & Inside Out",
            "Good Game, Well Played",
            "Whirlwind",
            "Classy",
            "Wiggle",
            "Windmill Floss",
            "A Tear In Space (Airlock)",
            "Gnarly",
            "Hot Marat",
            "Howl",
            "The Worm",
            "Shimmer",
            "Dip",
            "Snoozefest",
            "You're Awesome",
            "Surfin' Bird",
            "Maximum Bounce",
            "Rambunctious",
            "Get Out of Your Mind",
            "Reanimated",
            "Zom-beam",
            "Zombified",
            "Boogie Bomb",
            "Dynamite",
            "Runaway",
            "Powered Up",
            "Stop",
            "Giddy Up",
            "Disco",
            "Get funky",
            "Sweet Dreams",
            "Stay",
            "Run It",
            "Victory Lap",
            "Double Tap",
            "Nope",
            "Bubblegum"
        }

        local wheelPages = {}
        local CustomWheelPages = {
            {"Dance Moves", "Fresh", "Electro Shuffle", "Ride The Pony", "Floss", "The Worm", "Take The L", "Boogie Down"},
            {"Hype", "Tidy", "Breakin'", "Disco Fever", "Orange Justice", "Zany", "Groove Jam", "Freestylin'"},
            {"True Heart", "Rambunctious", "Twist", "Living Large", "Llama Bell", "Fancy Feet", "Hula", "Electro Swing"},
            {"Phone It In", "Flamenco", "Backstroke", "Marsh Walk", "Scenario", "Dream Feet", "Switchstep", "Billy Bounce"},
            {"Infectious"}
        }

        local function buildWheelPages(searchQuery)
            wheelPages = {}
            local q = (searchQuery and searchQuery ~= "") and string.lower(searchQuery) or ""
            
            if q == "" then
                for i, page in ipairs(CustomWheelPages) do
                    local pageCopy = {}
                    for _, e in ipairs(page) do table.insert(pageCopy, e) end
                    table.insert(wheelPages, { page = i, emotes = pageCopy })
                end
            else
                local filtered = {}
                for _, page in ipairs(CustomWheelPages) do
                    for _, e in ipairs(page) do
                        if string.find(string.lower(e), q, 1, true) then
                            table.insert(filtered, e)
                        end
                    end
                end
                
                local pageEmotes = {}
                for i, e in ipairs(filtered) do
                    table.insert(pageEmotes, e)
                    if #pageEmotes == 8 then
                        table.insert(wheelPages, { page = #wheelPages + 1, emotes = pageEmotes })
                        pageEmotes = {}
                    end
                end
                if #pageEmotes > 0 then
                    table.insert(wheelPages, { page = #wheelPages + 1, emotes = pageEmotes })
                end
            end
            
            if #wheelPages == 0 then
                table.insert(wheelPages, { page = 1, emotes = {} })
            end
        end

        buildWheelPages("")
-- Ensure local audio and icons cache directories exist
        local audioFolder = CONFIG.FOLDER .. "/fortniteaudios"
        local iconsFolder = CONFIG.FOLDER .. "/fortniteicons"
        pcall(function() makefolder(audioFolder) end)
        pcall(function() makefolder(iconsFolder) end)

        -- Audio session tracking to prevent overlapping/stale audio
        local audioSession = 0
        local currentSound = nil

        local function stopEmoteAudio(instant)
            audioSession = audioSession + 1
            if currentSound then
                local soundObj = currentSound
                currentSound = nil
                if instant then
                    pcall(function() soundObj:Stop(); soundObj:Destroy() end)
                else
                    task.spawn(function()
                        local tween = TweenService:Create(soundObj, TweenInfo.new(0.15, Enum.EasingStyle.Linear), {Volume = 0})
                        tween:Play()
                        tween.Completed:Wait()
                        pcall(function() soundObj:Stop(); soundObj:Destroy() end)
                    end)
                end
            end
        end
        if ReanimateAPI then
            ReanimateAPI.stop_emote_audio = stopEmoteAudio
        end

        -- Helper to download assets locally
        local function getLocalAsset(url, folder, filename)
            local localPath = folder .. "/" .. filename
            local ok, cached = pcall(readfile, localPath)
            local get_asset = getcustomasset or getsynasset
            if ok and cached and cached ~= "" then
                if type(get_asset) == "function" then
                    local ok2, res = pcall(get_asset, localPath)
                    if ok2 then return res end
                end
                return nil
            end
            local downloaded = request_get(url)
            if downloaded and downloaded ~= "" then
                pcall(function() writefile(localPath, downloaded) end)
                if type(get_asset) == "function" then
                    local ok2, res = pcall(get_asset, localPath)
                    if ok2 then return res end
                end
            end
            return nil
        end

        local function playEmoteAudio(emoteName)
            stopEmoteAudio(true)
            local session = audioSession
            task.spawn(function()
                local url = "" .. game:GetService("HttpService"):UrlEncode(emoteName) .. ".mp3"
                local assetId = getLocalAsset(url, audioFolder, emoteName .. ".mp3")
                if assetId and audioSession == session then
                    pcall(function()
                        local sound = Instance.new("Sound")
                        sound.Name = "HaloEmoteSound"
                        sound.SoundId = assetId
                        sound.Volume = 0
                        sound.Looped = true
                        sound.Parent = game:GetService("SoundService")
                        sound:Play()
                        if audioSession ~= session then
                            sound:Stop(); sound:Destroy()
                            return
                        end
                        currentSound = sound
                        TweenService:Create(sound, TweenInfo.new(0.25, Enum.EasingStyle.Linear), {Volume = 0.3}):Play()
                    end)
                end
            end)
        end

        -- Sound helper for menu hover/click sound effects
        local function playClickSound()
            task.spawn(function()
                local assetId = getLocalAsset("", audioFolder, "Click.mp3")
                if assetId then
                    pcall(function()
                        local sound = Instance.new("Sound")
                        sound.Name = "HaloClickSound"
                        sound.SoundId = assetId
                        sound.Volume = 0.2
                        sound.Parent = game:GetService("SoundService")
                        sound:Play()
                        task.delay(1, function()
                            pcall(function() sound:Destroy() end)
                        end)
                    end)
                end
            end)
        end

        -- Stop audio when animation stops
        if ReanimateAPI and ReanimateAPI.on_animation_stop then
            ReanimateAPI.on_animation_stop(function(stoppedName)
                stopEmoteAudio(false)
            end)
        end

        -- Create Fortnite Wheel UI ScreenGui
        fnGui = Instance.new("ScreenGui")
        fnGui.Name = "FortniteWheelUI"
        fnGui.ResetOnSpawn = false
        fnGui.IgnoreGuiInset = true
        fnGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        fnGui.DisplayOrder = 600

        local successParent = pcall(function() fnGui.Parent = game:GetService("CoreGui") end)
        if not successParent then fnGui.Parent = PlayerGui end

        -- Full-screen darken overlay
        local screenOverlay = Instance.new("Frame", fnGui)
        screenOverlay.Size = UDim2.new(1, 0, 1, 0)
        screenOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        screenOverlay.BackgroundTransparency = 0.55
        screenOverlay.BorderSizePixel = 0
        screenOverlay.ZIndex = 1
        screenOverlay.Visible = false

        -- Main wheel container
        local mainFrame = Instance.new("Frame", fnGui)
        mainFrame.Size = UDim2.new(0, 600, 0, 560)
        mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
        mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
        mainFrame.BackgroundTransparency = 1
        mainFrame.Visible = false
        mainFrame.ZIndex = 2

        -- Fortnite colors
        local FN = {
            bgDark = Color3.fromRGB(12, 14, 22),
            bgMid = Color3.fromRGB(22, 26, 38),
            bgSegment = Color3.fromRGB(32, 36, 50),
            bgSegmentHover = Color3.fromRGB(0, 110, 220),
            stroke = Color3.fromRGB(48, 52, 68),
            strokeHover = Color3.fromRGB(30, 160, 255),
            textWhite = Color3.fromRGB(255, 255, 255),
            textGray = Color3.fromRGB(175, 180, 200),
            textDim = Color3.fromRGB(95, 100, 118),
            accentBlue = Color3.fromRGB(0, 140, 255),
            navBg = Color3.fromRGB(22, 26, 38),
            navHover = Color3.fromRGB(0, 110, 220),
            centerBg = Color3.fromRGB(8, 10, 18),
            dotActive = Color3.fromRGB(255, 255, 255),
            dotInactive = Color3.fromRGB(50, 55, 72),
        }

        -- Outer glow ring (subtle blue glow behind wheel)
        local glowRing = Instance.new("Frame", mainFrame)
        glowRing.Size = UDim2.new(0, 440, 0, 440)
        glowRing.Position = UDim2.new(0.5, 0, 0.5, -15)
        glowRing.AnchorPoint = Vector2.new(0.5, 0.5)
        glowRing.BackgroundTransparency = 1
        glowRing.BorderSizePixel = 0
        glowRing.ZIndex = 2
        Instance.new("UICorner", glowRing).CornerRadius = UDim.new(0.5, 0)
        local glowStroke = Instance.new("UIStroke", glowRing)
        glowStroke.Color = FN.accentBlue
        glowStroke.Thickness = 3
        glowStroke.Transparency = 0.7

        -- Outer wheel background circle
        local wheelBg = Instance.new("Frame", mainFrame)
        wheelBg.Size = UDim2.new(0, 420, 0, 420)
        wheelBg.Position = UDim2.new(0.5, 0, 0.5, -15)
        wheelBg.AnchorPoint = Vector2.new(0.5, 0.5)
        wheelBg.BackgroundColor3 = FN.bgDark
        wheelBg.BackgroundTransparency = 0
        wheelBg.BorderSizePixel = 0
        wheelBg.ZIndex = 3
        Instance.new("UICorner", wheelBg).CornerRadius = UDim.new(0.5, 0)
        local wheelBgStroke = Instance.new("UIStroke", wheelBg)
        wheelBgStroke.Color = FN.stroke
        wheelBgStroke.Thickness = 2
        wheelBgStroke.Transparency = 0.2

        -- Inner circle (center hole of donut)
        local innerCircle = Instance.new("Frame", mainFrame)
        innerCircle.Size = UDim2.new(0, 155, 0, 155)
        innerCircle.Position = UDim2.new(0.5, 0, 0.5, -15)
        innerCircle.AnchorPoint = Vector2.new(0.5, 0.5)
        innerCircle.BackgroundColor3 = FN.centerBg
        innerCircle.BackgroundTransparency = 0
        innerCircle.BorderSizePixel = 0
        innerCircle.ZIndex = 8
        Instance.new("UICorner", innerCircle).CornerRadius = UDim.new(0.5, 0)
        local innerStroke = Instance.new("UIStroke", innerCircle)
        innerStroke.Color = FN.stroke
        innerStroke.Thickness = 2
        innerStroke.Transparency = 0.3

        -- Center emote name label (inside inner circle)
        local centerLabel = Instance.new("TextLabel", mainFrame)
        centerLabel.Size = UDim2.new(0, 130, 0, 50)
        centerLabel.Position = UDim2.new(0.5, 0, 0.5, -15)
        centerLabel.AnchorPoint = Vector2.new(0.5, 0.5)
        centerLabel.BackgroundTransparency = 1
        centerLabel.Text = ""
        centerLabel.TextColor3 = FN.textWhite
        centerLabel.TextSize = 14
        centerLabel.Font = Enum.Font.GothamBold
        centerLabel.TextWrapped = true
        centerLabel.ZIndex = 9

        -- Title above wheel
        local wheelTitleIcon = Instance.new("ImageLabel", mainFrame)
        wheelTitleIcon.Name = "WheelTitle"
        wheelTitleIcon.Size = UDim2.new(0, 420, 0, 85)
        wheelTitleIcon.Position = UDim2.new(0.5, 0, 0, -26)
        wheelTitleIcon.AnchorPoint = Vector2.new(0.5, 1)
        wheelTitleIcon.BackgroundTransparency = 1
        wheelTitleIcon.ScaleType = Enum.ScaleType.Fit
        wheelTitleIcon.ZIndex = 11

        task.spawn(function()
            pcall(function() delfile(iconsFolder .. "/_wheel_title.png") end)
            local url = "https://i.postimg.cc/JzbXQrW0/halowheel.png"
            local assetId = getLocalAsset(url, iconsFolder, "halowheel.png")
            if assetId then
                wheelTitleIcon.Image = assetId
            end
        end)

        -- Page indicator dots container
        local dotsFrame = Instance.new("Frame", mainFrame)
        dotsFrame.Size = UDim2.new(0, 140, 0, 16)
        dotsFrame.Position = UDim2.new(0.5, 0, 1, -22)
        dotsFrame.AnchorPoint = Vector2.new(0.5, 0)
        dotsFrame.BackgroundTransparency = 1
        dotsFrame.ZIndex = 10
        local dotsLayout = Instance.new("UIListLayout", dotsFrame)
        dotsLayout.FillDirection = Enum.FillDirection.Horizontal
        dotsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        dotsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        dotsLayout.Padding = UDim.new(0, 8)

        local arrowLeftUrl = "https://i.postimg.cc/mkMJrzKw/ic-fluent-arrow-left-24-filled.png"
        local arrowRightUrl = "https://i.postimg.cc/2yvM5bg7/ic-fluent-arrow-right-24-filled.png"

            local createNavArrow = function(posX, anchorX)
            local btn = Instance.new("ImageButton", mainFrame)
            btn.Size = UDim2.new(0, 48, 0, 48)
            btn.Position = UDim2.new(posX, 0, 0.5, -15)
            btn.AnchorPoint = Vector2.new(anchorX, 0.5)
            btn.BackgroundColor3 = FN.navBg
            btn.BackgroundTransparency = 0.1
            btn.Image = ""
            btn.BorderSizePixel = 0
            btn.ZIndex = 10
            btn.AutoButtonColor = false
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0.5, 0)
            local navStroke = Instance.new("UIStroke", btn)
            navStroke.Color = FN.stroke
            navStroke.Thickness = 1.5
            navStroke.Transparency = 0.3
            local arrowIcon = Instance.new("ImageLabel", btn)
            arrowIcon.Name = "ArrowIcon"
            arrowIcon.Size = UDim2.new(0, 22, 0, 22)
            arrowIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
            arrowIcon.AnchorPoint = Vector2.new(0.5, 0.5)
            arrowIcon.BackgroundTransparency = 1
            arrowIcon.ImageColor3 = FN.textWhite
            arrowIcon.ZIndex = 11
            btn.MouseEnter:Connect(function()
                TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = FN.navHover, BackgroundTransparency = 0}):Play()
                TweenService:Create(navStroke, TweenInfo.new(0.1), {Color = FN.strokeHover, Transparency = 0}):Play()
                TweenService:Create(btn, TweenInfo.new(0.08), {Size = UDim2.new(0, 52, 0, 52)}):Play()
            end)
            btn.MouseLeave:Connect(function()
                TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = FN.navBg, BackgroundTransparency = 0.1}):Play()
                TweenService:Create(navStroke, TweenInfo.new(0.12), {Color = FN.stroke, Transparency = 0.3}):Play()
                TweenService:Create(btn, TweenInfo.new(0.1), {Size = UDim2.new(0, 48, 0, 48)}):Play()
            end)
            return btn, arrowIcon
        end

        local leftArrow, leftArrowIcon = createNavArrow(0, 0.5)
        leftArrow.Position = UDim2.new(0, -8, 0.5, -15)
        leftArrow.AnchorPoint = Vector2.new(0.5, 0.5)
        local rightArrow, rightArrowIcon = createNavArrow(1, 0.5)
        rightArrow.Position = UDim2.new(1, 8, 0.5, -15)
        rightArrow.AnchorPoint = Vector2.new(0.5, 0.5)

        task.spawn(function()
            local asset = getLocalAsset(arrowLeftUrl, iconsFolder, "_arrow_left.png")
            if asset then pcall(function() leftArrowIcon.Image = asset end) end
        end)
        task.spawn(function()
            local asset = getLocalAsset(arrowRightUrl, iconsFolder, "_arrow_right.png")
            if asset then pcall(function() rightArrowIcon.Image = asset end) end
        end)

        local searchBox = Instance.new("TextBox", mainFrame)
        searchBox.Size = UDim2.new(0, 130, 0, 24)
        searchBox.Position = UDim2.new(0.5, 0, 0.5, -35)
        searchBox.AnchorPoint = Vector2.new(0.5, 0.5)
        searchBox.BackgroundColor3 = FN.bgDark
        searchBox.BackgroundTransparency = 0.2
        searchBox.BorderSizePixel = 0
        searchBox.Text = ""
        searchBox.PlaceholderText = "Search..."
        searchBox.TextColor3 = FN.textWhite
        searchBox.PlaceholderColor3 = FN.textDim
        searchBox.TextSize = 11
        searchBox.Font = Enum.Font.Gotham
        searchBox.ZIndex = 10
        searchBox.ClearTextOnFocus = false
        Instance.new("UICorner", searchBox).CornerRadius = UDim.new(0, 6)
        
        centerLabel.Position = UDim2.new(0.5, 0, 0.5, 5)
        centerLabel.Size = UDim2.new(0, 130, 0, 30)
        local currentPageIdx = 1
        local currentHoveredEmote = nil
        local segmentFrames = {}
        local triggerEmote 

        local updateDots = function()
            for _, child in ipairs(dotsFrame:GetChildren()) do
                if child:IsA("Frame") then child:Destroy() end
            end
            for i = 1, #wheelPages do
                local dot = Instance.new("Frame", dotsFrame)
                dot.Size = UDim2.new(0, i == currentPageIdx and 18 or 8, 0, 8)
                dot.BackgroundColor3 = i == currentPageIdx and FN.dotActive or FN.dotInactive
                dot.BorderSizePixel = 0
                dot.ZIndex = 10
                Instance.new("UICorner", dot).CornerRadius = UDim.new(0, 4)
            end
        end

        local drawWheel = function()
           
            for _, seg in ipairs(segmentFrames) do
                pcall(function() seg:Destroy() end)
            end
            segmentFrames = {}

            local pageData = wheelPages[currentPageIdx]
            if not pageData then return end
            local emotes = pageData.emotes
            local totalEmotes = #emotes

            currentHoveredEmote = nil
            centerLabel.Text = ""
            updateDots()

            local outerRadius = 155
            local segSize = math.clamp(88 - (totalEmotes - 6) * 4, 64, 92)

            for i, emoteName in ipairs(emotes) do
                local angle = ((i - 1) / totalEmotes) * 360 - 90
                local rad = math.rad(angle)
                local xOffset = math.cos(rad) * outerRadius
                local yOffset = math.sin(rad) * outerRadius

                local seg = Instance.new("TextButton", mainFrame)
                seg.Name = "Seg_" .. i
                seg.Size = UDim2.new(0, segSize, 0, segSize)
                seg.Position = UDim2.new(0.5, xOffset, 0.5, yOffset - 15)
                seg.AnchorPoint = Vector2.new(0.5, 0.5)
                seg.BackgroundColor3 = FN.bgSegment
                seg.BackgroundTransparency = 0.1
                seg.Text = ""
                seg.BorderSizePixel = 0
                seg.AutoButtonColor = false
                seg.ZIndex = 6
                Instance.new("UICorner", seg).CornerRadius = UDim.new(0, 14)
                local segStroke = Instance.new("UIStroke", seg)
                segStroke.Color = FN.stroke
                segStroke.Thickness = 1.8
                segStroke.Transparency = 0.35

                -- Icon
                local icon = Instance.new("ImageLabel", seg)
                icon.Name = "Icon"
                icon.Size = UDim2.new(0.6, 0, 0.6, 0)
                icon.Position = UDim2.new(0.5, 0, 0.38, 0)
                icon.AnchorPoint = Vector2.new(0.5, 0.5)
                icon.BackgroundTransparency = 1
                icon.ImageColor3 = FN.textGray
                icon.ZIndex = 7

                task.spawn(function()
                    local url = "" .. game:GetService("HttpService"):UrlEncode(emoteName) .. ".png"
                    local assetId = getLocalAsset(url, iconsFolder, emoteName .. ".png")
                    if assetId then
                        icon.Image = assetId
                    end
                end)

                local segName = Instance.new("TextLabel", seg)
                segName.Size = UDim2.new(1, -4, 0, 14)
                segName.Position = UDim2.new(0.5, 0, 0.82, 0)
                segName.AnchorPoint = Vector2.new(0.5, 0.5)
                segName.BackgroundTransparency = 1
                segName.Text = emoteName
                segName.TextColor3 = FN.textDim
                segName.TextSize = 8
                segName.Font = Enum.Font.GothamSemibold
                segName.TextTruncate = Enum.TextTruncate.AtEnd
                segName.ZIndex = 7

                seg.MouseEnter:Connect(function()
                    playClickSound()
                    currentHoveredEmote = emoteName
                    centerLabel.Text = emoteName:upper()

                    for _, otherSeg in ipairs(segmentFrames) do
                        if otherSeg ~= seg and otherSeg.Parent then
                            TweenService:Create(otherSeg, TweenInfo.new(0.1), {
                                BackgroundColor3 = FN.bgSegment, BackgroundTransparency = 0.1
                            }):Play()
                            local os2 = otherSeg:FindFirstChildOfClass("UIStroke")
                            if os2 then TweenService:Create(os2, TweenInfo.new(0.1), {Color = FN.stroke, Transparency = 0.35}):Play() end
                            local oi = otherSeg:FindFirstChild("Icon")
                            if oi then TweenService:Create(oi, TweenInfo.new(0.1), {ImageColor3 = FN.textGray}):Play() end
                        end
                    end

                    TweenService:Create(seg, TweenInfo.new(0.08), {
                        BackgroundColor3 = FN.bgSegmentHover, BackgroundTransparency = 0
                    }):Play()
                    TweenService:Create(segStroke, TweenInfo.new(0.08), {Color = FN.strokeHover, Transparency = 0}):Play()
                    TweenService:Create(icon, TweenInfo.new(0.08), {ImageColor3 = FN.textWhite}):Play()
                    TweenService:Create(seg, TweenInfo.new(0.1), {Size = UDim2.new(0, segSize + 6, 0, segSize + 6)}):Play()
                end)

                seg.MouseLeave:Connect(function()
                    TweenService:Create(seg, TweenInfo.new(0.12), {
                        BackgroundColor3 = FN.bgSegment, BackgroundTransparency = 0.1,
                        Size = UDim2.new(0, segSize, 0, segSize)
                    }):Play()
                    TweenService:Create(segStroke, TweenInfo.new(0.12), {Color = FN.stroke, Transparency = 0.35}):Play()
                    TweenService:Create(icon, TweenInfo.new(0.12), {ImageColor3 = FN.textGray}):Play()
                end)

                seg.MouseButton1Click:Connect(function()
                    mainFrame.Visible = false
                    screenOverlay.Visible = false
                    triggerEmote(emoteName)
                end)

                table.insert(segmentFrames, seg)
            end
        end

        triggerEmote = function(emoteName)
            if not emoteName then return end
            task.spawn(function()
                if not ReanimateAPI.is_reanimated() then
                    Notify("Fortnite Wheel", "Please reanimate first!", 3)
                    return
                end

                stopEmoteAudio(true)

                local lowerName = emoteName:lower()
                local actualAnimName = nil
                local isCustom = false
                local animUrl = nil
                local isRaw = false

                for _, ca in ipairs(CustomAnims) do
                    if ca.name:lower() == lowerName then
                        actualAnimName = ca.name
                        isCustom = true
                        animUrl = ca.url
                        isRaw = ca.raw ~= false
                        break
                    end
                end

                if not actualAnimName then
                    for name, url in pairs(AnimationList) do
                        if name:lower() == lowerName then
                            actualAnimName = name
                            animUrl = url
                            isRaw = false
                            break
                        end
                    end
                end

                if not actualAnimName then
                    for name, url in pairs(presetList) do
                        if name:lower() == lowerName then
                            actualAnimName = name
                            animUrl = url
                            isRaw = false
                            break
                        end
                    end
                end

                if actualAnimName and animUrl then
                    local wasPlaying = State.selectedAnim == actualAnimName
                    PlayAnimation(actualAnimName, State.currentSpeed, isRaw)
                    
                    if not wasPlaying then
                        playEmoteAudio(actualAnimName)
                    end
                else
               
                    local fallbackUrl = "" .. game:GetService("HttpService"):UrlEncode(emoteName) .. ".lua"
                    local downloaded = request_get(fallbackUrl)
                    if downloaded and downloaded ~= "" then
                        AnimationList[emoteName] = fallbackUrl
                        pcall(function() writefile(GetCachePath(emoteName), downloaded) end)
                        local wasPlaying = State.selectedAnim == emoteName
                        PlayAnimation(emoteName, State.currentSpeed, false)
                        if not wasPlaying then
                            playEmoteAudio(emoteName)
                        end
                    else
                        Notify("Fortnite Wheel", "Animation not found!", 3)
                    end
                end
            end)
        end

        leftArrow.MouseButton1Click:Connect(function()
            playClickSound()
            currentPageIdx = currentPageIdx > 1 and currentPageIdx - 1 or #wheelPages
            drawWheel()
        end)
        rightArrow.MouseButton1Click:Connect(function()
            playClickSound()
            currentPageIdx = currentPageIdx < #wheelPages and currentPageIdx + 1 or 1
            drawWheel()
        end)

        searchBox:GetPropertyChangedSignal("Text"):Connect(function()
            buildWheelPages(searchBox.Text)
            drawWheel()
        end)

        drawWheel()

        local wheelScale = Instance.new("UIScale", mainFrame)
        wheelScale.Scale = 1

        local showWheel = function()
            mainFrame.Visible = true
            screenOverlay.Visible = true
            wheelScale.Scale = 0.85
            screenOverlay.BackgroundTransparency = 1
            TweenService:Create(wheelScale, TweenInfo.new(0.15, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Scale = 1}):Play()
            TweenService:Create(screenOverlay, TweenInfo.new(0.15), {BackgroundTransparency = 0.55}):Play()
            searchBox.Text = ""
            buildWheelPages("")            currentPageIdx = currentPageIdx or 1
            drawWheel()
        end

        local hideWheel = function()
            TweenService:Create(wheelScale, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0.85}):Play()
            TweenService:Create(screenOverlay, TweenInfo.new(0.1), {BackgroundTransparency = 1}):Play()
            task.delay(0.1, function()
                mainFrame.Visible = false
                screenOverlay.Visible = false
            end)
        end

        _G._OpenFortniteWheel = function()
            if not ScreenGui or not ScreenGui.Parent then return end
            if mainFrame.Visible then
                hideWheel()
            else
                showWheel()
            end
        end

        local isHolding = false
        local keyBeganConn = UserInputService.InputBegan:Connect(function(i, gp)
            if gp then return end
            if not ScreenGui or not ScreenGui.Parent then return end
            if _G._FortniteWheelKey and i.KeyCode == _G._FortniteWheelKey then
                isHolding = true
                showWheel()
            end
        end)

        local keyEndedConn = UserInputService.InputEnded:Connect(function(i, gp)
            if _G._FortniteWheelKey and i.KeyCode == _G._FortniteWheelKey then
                if isHolding and mainFrame.Visible then
                    isHolding = false
                    hideWheel()
                    if currentHoveredEmote then
                        triggerEmote(currentHoveredEmote)
                    end
                end
            end
        end)

        if _G._HaloReanimGlobalConns then
            table.insert(_G._HaloReanimGlobalConns, keyBeganConn)
            table.insert(_G._HaloReanimGlobalConns, keyEndedConn)
        end
    end))

end

pcall(function()
    ScreenGui.Parent = _screenGuiTarget
    if not ScreenGui.Parent then
        warn("[Halo Reanim] Failed to parent ScreenGui to " .. tostring(_screenGuiTarget))
        ScreenGui.Parent = PlayerGui
    end
    ScreenGui.Enabled = true
    Menu.Visible = true
end)

BuildRowPool()
SwitchTab("All")
-- RebuildCustomList() is now lazy — it builds the first time the Custom tab is
-- opened (via EnsureCustomListBuilt in SwitchTab), so the window opens instantly.
pcall(function()
    updateFnWheelBtnText()
    updateRevBtnText()
    local pct = math.clamp((GlobalReverseSpeed - 0.1) / 2.9, 0, 1)
    revFill.Size = UDim2.new(pct, 0, 1, 0)
    revHandle.Position = UDim2.new(pct, 0, 0.5, 0)
    revSpdLbl.Text = "Reverse Speed: " .. string.format("%.1f", GlobalReverseSpeed) .. "x"
end)
Notify("Reanimation loaded!", 2.5)

task.spawn(function()
    local ok, r = pcall(function()
        return loadstring(game:HttpGet(CONFIG.ANIMATIONS_URL))()
    end)
    if ok and type(r) == "table" and next(r) ~= nil then
        for name, url in pairs(r) do
            AnimationList[name] = url
        end
        if State.currentTab == "All" or State.currentTab == "Favs" then
            pcall(RebuildVisible)
        end
    end
end)

function _runEmbeddedReanimation()
    if _haloReanimHasRun then
        local found = pcall(function()
            local pg = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
            local cg = game:GetService("CoreGui")
            if pg then
                for _, sg in ipairs(pg:GetChildren()) do
                    if sg:IsA("ScreenGui") and sg.Name == "ReanimHaloMenu" then
                        sg.Enabled = true
                        for _, f in ipairs(sg:GetChildren()) do
                            if f:IsA("Frame") then f.Visible = true end
                        end
                        return true
                    end
                end
            end
            if cg then
                for _, sg in ipairs(cg:GetChildren()) do
                    if sg:IsA("ScreenGui") and sg.Name == "ReanimHaloMenu" then
                        sg.Enabled = true
                        for _, f in ipairs(sg:GetChildren()) do
                            if f:IsA("Frame") then f.Visible = true end
                        end
                        return true
                    end
                end
            end
            return false
        end)
        if found then return end
    end
    _haloReanimHasRun = true
    if not _haloReanimCode then
        warn("[Halo Reanim] Code is nil - already loaded?")
        return
    end
    local ok, fn = pcall(loadstring, _haloReanimCode)
    if not ok then
        warn("[Halo Reanim] loadstring failed: " .. tostring(fn))
        return
    end
    if not fn then
        warn("[Halo Reanim] loadstring returned nil")
        return
    end
    local ok2, err = pcall(fn)
    if not ok2 then
        warn("[Halo Reanim] execution failed: " .. tostring(err))
    end
    _haloReanimCode = nil
    -- Wait a moment for the ScreenGui to be parented
    task.wait(0.1)
end
_G._HaloReanimShowMenu = _runEmbeddedReanimation


-- ============================================================
-- AUTO NOCLIP (from Infinite Yield source)
-- Always re-enables noclip if it gets turned off
-- ============================================================
local AutoNoclipEnabled = true
local AutoNoclipConn = nil
local AutoNoclipParts = {}

local function EnableAutoNoclip()
    if AutoNoclipConn then
        pcall(function() AutoNoclipConn:Disconnect() end)
        AutoNoclipConn = nil
    end
    AutoNoclipParts = {}
    AutoNoclipConn = RunService.Stepped:Connect(function()
        if not AutoNoclipEnabled then return end
        local char = plr.Character
        if not char then return end
        for _, child in pairs(char:GetDescendants()) do
            if child:IsA("BasePart") and child.CanCollide == true then
                child.CanCollide = false
                AutoNoclipParts[child] = true
            end
        end
    end)
end

local function DisableAutoNoclip()
    AutoNoclipEnabled = false
    if AutoNoclipConn then
        pcall(function() AutoNoclipConn:Disconnect() end)
        AutoNoclipConn = nil
    end
    for child, _ in pairs(AutoNoclipParts) do
        if typeof(child) == "Instance" and child:IsA("BasePart") and child.Parent then
            child.CanCollide = true
        end
    end
    AutoNoclipParts = {}
end

-- Start auto noclip immediately
EnableAutoNoclip()

-- Re-enable on character respawn
plr.CharacterAdded:Connect(function()
    if AutoNoclipEnabled then
        task.wait(0.2)
        EnableAutoNoclip()
    end
end)

-- Expose toggle
_G._HaloToggleAutoNoclip = function()
    AutoNoclipEnabled = not AutoNoclipEnabled
    if AutoNoclipEnabled then
        EnableAutoNoclip()
        Notify("Auto Noclip ON", 2)
    else
        DisableAutoNoclip()
        Notify("Auto Noclip OFF", 2)
    end
end

-- ============================================================
-- INFINITE BASEPLATE (Grass Texture)
-- Auto-executes on specific place IDs: 15546218972, 6884319169
-- Makes baseplate wider (X/Z) but NOT taller (no Y change)
-- ============================================================
local INF_BASEPLATE_PLACE_IDS = {
    [15546218972] = true,
    [6884319169] = true,
}

if INF_BASEPLATE_PLACE_IDS[game.PlaceId] and not _G._HaloInfBaseplateApplied then
    _G._HaloInfBaseplateApplied = true
    task.spawn(function()
        local Workspace = game:GetService("Workspace")

        -- Wait for baseplate to exist
        local baseplate = Workspace:WaitForChild("Baseplate", 10)
        if not baseplate then
            for _, obj in ipairs(Workspace:GetChildren()) do
                if obj:IsA("BasePart") and obj.Name:lower():find("base") then
                    baseplate = obj
                    break
                end
            end
        end

        if baseplate and baseplate:IsA("BasePart") then
            -- Store original values
            local currentY = baseplate.Size.Y
            local currentPos = baseplate.Position

            -- Widen ONLY — no height change
            baseplate.Size = Vector3.new(4096, currentY, 4096)
            baseplate.Position = Vector3.new(currentPos.X, currentPos.Y, currentPos.Z)
            baseplate.Anchored = true

            -- Night grass
            baseplate.Material = Enum.Material.Grass
            baseplate.Color = Color3.fromRGB(78, 12, 18)
            baseplate.Transparency = 0
            baseplate.Reflectance = 0
            baseplate.CastShadow = false

            for _, child in ipairs(baseplate:GetChildren()) do
                if child:IsA("Decal") or child:IsA("Texture") then
                    child:Destroy()
                end
            end
            local grass = Instance.new("Texture")
            grass.Name = "NightGrass"
            grass.Texture = "rbxassetid://6375461772"
            grass.Face = Enum.NormalId.Top
            grass.Color3 = Color3.fromRGB(140, 28, 36)
            grass.Transparency = 0.08
            grass.StudsPerTileU = 18
            grass.StudsPerTileV = 18
            grass.Parent = baseplate

            baseplate.BottomSurface = Enum.SurfaceType.Smooth
            baseplate.TopSurface = Enum.SurfaceType.Smooth

            -- Force delete annoying default baseplate parts (with retries for late loading)
            task.spawn(function()
                local function tryDestroy()
                    local map = Workspace:FindFirstChild("map") or Workspace:FindFirstChild("Map")
                    if not map then return false end
                    local extraRoom = map:FindFirstChild("extra_room") or map:FindFirstChild("Extra_Room")
                    if not extraRoom then return false end

                    local children = extraRoom:GetChildren()
                    pcall(function() if children[4] then children[4]:Destroy() end end)
                    pcall(function() if children[3] then children[3]:Destroy() end end)
                    pcall(function() if children[2] then children[2]:Destroy() end end)
                    pcall(function() 
                        local platform = extraRoom:FindFirstChild("platform") or extraRoom:FindFirstChild("Platform")
                        if platform then platform:Destroy() end
                    end)
                    return true
                end

                -- Try immediately, then retry every 0.5s for 5 seconds
                for i = 1, 12 do
                    if tryDestroy() then break end
                    task.wait(0.5)
                end
            end)

            Notify("Infinite Baseplate Loaded", "Dark red grass | 4096x4096", 3)
        end
    end)
end

task.spawn(function()
    local ws = game:GetService("Workspace")
    local baseplate = ws:FindFirstChild("Baseplate") or ws:WaitForChild("Baseplate", 8)
    if not (baseplate and baseplate:IsA("BasePart")) then
        for _, obj in ipairs(ws:GetChildren()) do
            if obj:IsA("BasePart") and obj.Name:lower():find("base") then
                baseplate = obj
                break
            end
        end
    end
    if baseplate and baseplate:IsA("BasePart") then
        baseplate.Material = Enum.Material.Grass
        baseplate.Color = Color3.fromRGB(78, 12, 18)
        baseplate.Transparency = 0
        baseplate.Reflectance = 0
        baseplate.CastShadow = false
        for _, child in ipairs(baseplate:GetChildren()) do
            if child:IsA("Decal") or child:IsA("Texture") then
                child:Destroy()
            end
        end
        local grass = Instance.new("Texture")
        grass.Name = "NightGrass"
        grass.Texture = "rbxassetid://6375461772"
        grass.Face = Enum.NormalId.Top
        grass.Color3 = Color3.fromRGB(140, 28, 36)
        grass.Transparency = 0.08
        grass.StudsPerTileU = 18
        grass.StudsPerTileV = 18
        grass.Parent = baseplate
    end

    local Lighting = game:GetService("Lighting")
    local function night()
        pcall(function()
            Lighting.ClockTime = 20.2
            Lighting.Brightness = 2.8
            Lighting.ExposureCompensation = 0.28
            Lighting.Ambient = Color3.fromRGB(78, 86, 130)
            Lighting.OutdoorAmbient = Color3.fromRGB(110, 120, 175)
            Lighting.ColorShift_Top = Color3.fromRGB(90, 110, 180)
            Lighting.ColorShift_Bottom = Color3.fromRGB(8, 10, 20)
            Lighting.FogColor = Color3.fromRGB(12, 16, 36)
            Lighting.FogStart = 220
            Lighting.FogEnd = 1600
            Lighting.EnvironmentDiffuseScale = 0.35
            Lighting.EnvironmentSpecularScale = 0.55
        end)
        pcall(function()
            local at = Lighting:FindFirstChild("HaloNightAir")
            if not at then
                at = Instance.new("Atmosphere")
                at.Name = "HaloNightAir"
                at.Parent = Lighting
            end
            at.Density = 0.1
            at.Offset = 0.12
            at.Color = Color3.fromRGB(70, 85, 140)
            at.Decay = Color3.fromRGB(18, 20, 40)
            at.Glare = 0.15
            at.Haze = 0.6
        end)
        pcall(function()
            local cc = Lighting:FindFirstChild("HaloNightGrade")
            if not cc then
                cc = Instance.new("ColorCorrectionEffect")
                cc.Name = "HaloNightGrade"
                cc.Parent = Lighting
            end
            cc.TintColor = Color3.fromRGB(200, 210, 255)
            cc.Brightness = 0.08
            cc.Contrast = 0.12
            cc.Saturation = 0.05
        end)
        pcall(function()
            local bloom = Lighting:FindFirstChild("HaloNightBloom")
            if not bloom then
                bloom = Instance.new("BloomEffect")
                bloom.Name = "HaloNightBloom"
                bloom.Parent = Lighting
            end
            bloom.Intensity = 0.12
            bloom.Size = 28
            bloom.Threshold = 0.85
        end)
    end
    night()
    task.spawn(function()
        while true do
            task.wait(2)
            night()
        end
    end)
end)

-- ============================================================
-- COMMAND SYSTEM (? prefix)
-- ?rj = rejoin server
-- ?permhide <name> = hide + mute + block a player (partial match)
-- ?unpermhide <name> = unhide a player
-- ============================================================
local PermHiddenPlayers = _G._HaloPermHiddenPlayers or {}
_G._HaloPermHiddenPlayers = PermHiddenPlayers

local function getPlayerByPartialName(partial)
    partial = partial:lower()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= plr then
            if p.Name:lower():find(partial, 1, true) or p.DisplayName:lower():find(partial, 1, true) then
                return p
            end
        end
    end
    return nil
end

local function permHidePlayer(targetPlayer)
    if not targetPlayer or targetPlayer == plr then return end
    PermHiddenPlayers[targetPlayer.UserId] = true

    -- Hide character (robust: anchor + invisible + noncollidable)
    pcall(function()
        if targetPlayer.Character then
            for _, part in pairs(targetPlayer.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Anchored = true
                    part.CanCollide = false
                    part.Transparency = 1
                    part.CanQuery = false
                    part.CanTouch = false
                elseif part:IsA("Decal") or part:IsA("SurfaceGui") or part:IsA("BillboardGui") then
                    part.Enabled = false
                elseif part:IsA("ParticleEmitter") or part:IsA("Trail") or part:IsA("Beam") then
                    part.Enabled = false
                elseif part:IsA("Sound") then
                    part:Stop()
                    part.Volume = 0
                end
            end
            -- Try hiding the model itself too
            pcall(function() targetPlayer.Character.Parent = nil end)
        end
    end)

    -- Mute in legacy chat
    pcall(function()
        game:GetService("StarterGui"):SetCore("ChatMutePlayer", targetPlayer.Name)
    end)

    -- Mute VC
    pcall(function()
        game:GetService("SoundService").LocalMuted[targetPlayer.UserId] = true
    end)

    Notify("PermHidden: " .. targetPlayer.Name, "Character hidden + muted", 3)
end

local function unpermHidePlayer(targetPlayer)
    if not targetPlayer then return end
    PermHiddenPlayers[targetPlayer.UserId] = nil

    -- Restore character
    pcall(function()
        if targetPlayer.Character then
            -- Re-parent if hidden
            if not targetPlayer.Character.Parent then
                targetPlayer.Character.Parent = workspace
            end
            -- Restore all parts
            for _, part in pairs(targetPlayer.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Anchored = false
                    part.CanCollide = true
                    part.Transparency = 0
                    part.CanQuery = true
                    part.CanTouch = true
                elseif part:IsA("Decal") or part:IsA("SurfaceGui") or part:IsA("BillboardGui") then
                    part.Enabled = true
                elseif part:IsA("ParticleEmitter") or part:IsA("Trail") or part:IsA("Beam") then
                    part.Enabled = true
                elseif part:IsA("Sound") then
                    part.Volume = 1
                end
            end
        end
    end)

    -- Unmute
    pcall(function()
        game:GetService("StarterGui"):SetCore("ChatUnmutePlayer", targetPlayer.Name)
    end)
    pcall(function()
        game:GetService("SoundService").LocalMuted[targetPlayer.UserId] = nil
    end)

    Notify("Unhidden: " .. targetPlayer.Name, "Player restored", 2)
end

-- Hook character added for permhidden players
Players.PlayerAdded:Connect(function(p)
    if PermHiddenPlayers[p.UserId] then
        p.CharacterAdded:Connect(function()
            if PermHiddenPlayers[p.UserId] then
                task.wait(0.3)
                permHidePlayer(p)
            end
        end)
        task.wait(0.3)
        if p.Character then
            permHidePlayer(p)
        end
    end
end)

-- Re-apply hide when permhidden players respawn (existing players)
for _, p in ipairs(Players:GetPlayers()) do
    if p ~= plr and PermHiddenPlayers[p.UserId] then
        p.CharacterAdded:Connect(function()
            if PermHiddenPlayers[p.UserId] then
                task.wait(0.3)
                permHidePlayer(p)
            end
        end)
        if p.Character then
            permHidePlayer(p)
        end
    end
end

-- Chat filter for permhidden players (modern TextChatService)
pcall(function()
    local TextChatService = game:GetService("TextChatService")
    if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
        TextChatService.OnIncomingMessage = function(message)
            local props = Instance.new("TextChatMessageProperties")
            if message.TextSource then
                local senderId = message.TextSource.UserId
                if PermHiddenPlayers[senderId] then
                    props.Text = ""
                    props.PrefixText = ""
                end
            end
            return props
        end
    end
end)

-- Legacy chat filter
local function filterLegacyChat()
    local chatGui = plr:WaitForChild("PlayerGui"):FindFirstChild("Chat")
    if not chatGui then return end
    local scroller = chatGui:FindFirstChild("Scroller", true)
    if not scroller then return end

    local function checkMessage(frame)
        if not frame:IsA("Frame") then return end
        task.spawn(function()
            local textLabel = frame:WaitForChild("TextLabel", 1)
            if not textLabel then return end

            local function hideIfPermHidden()
                local text = textLabel.Text
                for userId, _ in pairs(PermHiddenPlayers) do
                    local p = Players:GetPlayerByUserId(userId)
                    if p and (text:find(p.Name, 1, true) or text:find(p.DisplayName, 1, true)) then
                        frame:Destroy()
                        return
                    end
                end
            end

            textLabel:GetPropertyChangedSignal("Text"):Connect(hideIfPermHidden)
            hideIfPermHidden()
        end)
    end

    scroller.ChildAdded:Connect(checkMessage)
    for _, child in ipairs(scroller:GetChildren()) do
        checkMessage(child)
    end
end
task.spawn(filterLegacyChat)

-- Command parser
local function processCommand(msg)
    if type(_G._HaloCmd) == "function" and _G._HaloCmd(msg) then return end
    if not msg or msg:sub(1, 1) ~= "?" then return end
    local args = {}
    for arg in msg:sub(2):gmatch("%S+") do
        table.insert(args, arg)
    end
    local cmd = args[1] and args[1]:lower() or ""

    if cmd == "rj" then
        -- Rejoin server
        Notify("Rejoining server...", 2)
        task.delay(0.5, function()
            local TeleportService = game:GetService("TeleportService")
            pcall(function()
                TeleportService:Teleport(game.PlaceId, plr)
            end)
        end)

    elseif cmd == "permhide" and args[2] then
        local target = getPlayerByPartialName(args[2])
        if target then
            permHidePlayer(target)
        else
            Notify("PermHide Error", "No player matching '" .. args[2] .. "'", 3)
        end

    elseif cmd == "unpermhide" and args[2] then
        local target = getPlayerByPartialName(args[2])
        if target then
            unpermHidePlayer(target)
        else
            Notify("UnPermHide Error", "No player matching '" .. args[2] .. "'", 3)
        end
    end
end

-- Hook chat input (modern TextChatService)
pcall(function()
    local TextChatService = game:GetService("TextChatService")
    if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
        local textBox = plr:WaitForChild("PlayerGui"):FindFirstChild("ChatInputBarConfiguration", true)
        -- Modern chat: intercept sent messages
        TextChatService.SendingMessage:Connect(function(message)
            if message.Text and message.Text:sub(1, 1) == "?" then
                processCommand(message.Text)
                message.Text = "" -- Don't send command to chat
            end
        end)
    end
end)

-- Legacy chat command hook
local function hookLegacyChatCommands()
    local chatGui = plr:WaitForChild("PlayerGui"):WaitForChild("Chat", 10)
    if not chatGui then return end

    local chatBar = chatGui:FindFirstChild("ChatBar", true)
    if not chatBar then
        -- Try deeper search
        for _, obj in ipairs(chatGui:GetDescendants()) do
            if obj:IsA("TextBox") and obj.Name == "ChatBar" then
                chatBar = obj
                break
            end
        end
    end

    if chatBar and chatBar:IsA("TextBox") then
        chatBar.FocusLost:Connect(function(enterPressed)
            if not enterPressed then return end
            local text = chatBar.Text
            if text:sub(1, 1) == "?" then
                processCommand(text)
                chatBar.Text = ""
            end
        end)
    end
end
task.spawn(hookLegacyChatCommands)

-- Also check PlayerGui for any chat bar that gets created later
plr.PlayerGui.DescendantAdded:Connect(function(desc)
    if desc:IsA("TextBox") and desc.Name == "ChatBar" then
        desc.FocusLost:Connect(function(enterPressed)
            if not enterPressed then return end
            local text = desc.Text
            if text:sub(1, 1) == "?" then
                processCommand(text)
                desc.Text = ""
            end
        end)
    end
end)

-- ============================================================
-- AUTO 90 FOV - Injected
-- ============================================================
local function apply90FOV()
    pcall(function()
        local cam = workspace.CurrentCamera
        if cam then
            cam.FieldOfView = 90
        end
    end)
end

-- Apply immediately
apply90FOV()

-- Re-apply when character respawns
pcall(function()
    local Players = game:GetService("Players")
    local plr = Players.LocalPlayer
    if plr then
        plr.CharacterAdded:Connect(function()
            task.wait(0.05)
            apply90FOV()
        end)
    end
end)

-- Enforce 90 FOV if anything tries to change it
pcall(function()
    local cam = workspace.CurrentCamera
    if cam then
        cam:GetPropertyChangedSignal("FieldOfView"):Connect(function()
            pcall(function()
                if cam.FieldOfView ~= 105 then
                    cam.FieldOfView = 105
                end
            end)
        end)
    end
end)

-- ============================================================
-- CYRIS ADDON: branding, slim menu, Workspace (Avatars + Import), BG
-- Safe post-load only — original script is not modified.
-- ============================================================
task.spawn(function()
    local okAddon, errAddon = pcall(function()
        local PlayersSvc = game:GetService("Players")
        local HttpService = game:GetService("HttpService")
        local lp = PlayersSvc.LocalPlayer
        if not lp then return end

        local sg = nil
        for _ = 1, 80 do
            if ScreenGui and ScreenGui.Parent then sg = ScreenGui break end
            local pg = lp:FindFirstChildOfClass("PlayerGui")
            if pg then sg = pg:FindFirstChild("ReanimHaloMenu") end
            if not sg then
                pcall(function()
                    sg = game:GetService("CoreGui"):FindFirstChild("ReanimHaloMenu")
                end)
            end
            if sg then break end
            task.wait(0.1)
        end
        if not sg then return end

        local menu = (Menu and Menu.Parent) and Menu or sg:FindFirstChild("ReanimMenu")
        if not (menu and menu:IsA("GuiObject")) then return end

        ----------------------------------------------------------------
        -- SLIMMER MENU
        ----------------------------------------------------------------
        pcall(function()
            local SLIM_W, SLIM_H = 340, 500
            if menu.Size.X.Offset > 300 then
                menu.Size = UDim2.new(0, SLIM_W, 0, SLIM_H)
            end
            pcall(function()
                if CONFIG and CONFIG.UI then
                    CONFIG.UI.DEFAULT_WIDTH = SLIM_W
                    CONFIG.UI.DEFAULT_HEIGHT = SLIM_H
                end
            end)
        end)

        ----------------------------------------------------------------
        -- BRANDING → Cyris
        ----------------------------------------------------------------
        pcall(function()
            local bar = menu:FindFirstChild("TitleBar")
            if bar then
                for _, d in ipairs(bar:GetChildren()) do
                    if d:IsA("TextLabel") then
                        d.Text = "Cyris"
                        break
                    end
                end
            end
            for _, d in ipairs(menu:GetDescendants()) do
                if d:IsA("TextLabel") and d.Text == "Reanimation" then
                    d.Text = "Cyris"
                end
            end
        end)

        ----------------------------------------------------------------
        -- STRONGER BACKGROUND
        ----------------------------------------------------------------
        pcall(function()
            local old = menu:FindFirstChild("CustomBackground")
            if old then old:Destroy() end
            local oldV = menu:FindFirstChild("BgVignette")
            if oldV then oldV:Destroy() end

            local bg = Instance.new("ImageLabel")
            bg.Name = "CustomBackground"
            bg.BackgroundTransparency = 1
            bg.BorderSizePixel = 0
            bg.Size = UDim2.new(1, 0, 1, 0)
            bg.ZIndex = 1
            bg.ScaleType = Enum.ScaleType.Crop
            bg.ImageTransparency = 0.15
            bg.Parent = menu

            local vig = Instance.new("Frame")
            vig.Name = "BgVignette"
            vig.BackgroundColor3 = Color3.fromRGB(6, 6, 10)
            vig.BackgroundTransparency = 0.75
            vig.BorderSizePixel = 0
            vig.Size = UDim2.new(1, 0, 1, 0)
            vig.ZIndex = 2
            vig.Parent = menu
            local vc = Instance.new("UICorner")
            vc.CornerRadius = UDim.new(0, 16)
            vc.Parent = vig
            pcall(function() menu.BackgroundTransparency = 0.75 end)

            task.spawn(function()
                local url = "https://litter.catbox.moe/lnh1rc.jpg"
                pcall(function() makefolder("ReanimData") end)
                local path = "ReanimData/cyris_menu_bg.jpg"
                local get_asset = getcustomasset or getsynasset

                local function tryHttp(u)
                    local attempts = {
                        function()
                            if type(request) == "function" then
                                local r = request({ Url = u, Method = "GET" })
                                return r and (r.Body or r.body)
                            end
                        end,
                        function()
                            if syn and syn.request then
                                local r = syn.request({ Url = u, Method = "GET" })
                                return r and (r.Body or r.body)
                            end
                        end,
                        function()
                            if type(http_request) == "function" then
                                local r = http_request({ Url = u, Method = "GET" })
                                return r and (r.Body or r.body)
                            end
                        end,
                        function()
                            if type(request_get) == "function" then return request_get(u) end
                        end,
                        function()
                            return game:HttpGet(u, true)
                        end,
                    }
                    for i = 1, #attempts do
                        local ok, res = pcall(attempts[i])
                        if ok and type(res) == "string" and #res > 100 then return res end
                    end
                    return nil
                end

                local data = tryHttp(url)
                if data then
                    pcall(function() writefile(path, data) end)
                    if type(get_asset) == "function" then
                        local oka, asset = pcall(get_asset, path)
                        if oka and asset then bg.Image = asset end
                    end
                end
            end)
        end)

        ----------------------------------------------------------------
        -- UI helpers
        ----------------------------------------------------------------
        local function makeCorner(parent, r)
            local c = Instance.new("UICorner")
            c.CornerRadius = UDim.new(0, r or 8)
            c.Parent = parent
            return c
        end
        local function makeBtn(parent, text, size, pos, z)
            local b = Instance.new("TextButton")
            b.Size = size
            b.Position = pos or UDim2.new(0, 0, 0, 0)
            b.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
            b.BackgroundTransparency = 0.05
            b.BorderSizePixel = 0
            b.Font = Enum.Font.GothamBold
            b.Text = text
            b.TextColor3 = Color3.fromRGB(255, 255, 255)
            b.TextSize = 11
            b.AutoButtonColor = false
            b.ZIndex = z or 90
            b.Parent = parent
            makeCorner(b, 6)
            return b
        end

        local function httpGet(url)
            local attempts = {
                function()
                    if type(request) == "function" then
                        local r = request({ Url = url, Method = "GET" })
                        return r and (r.Body or r.body)
                    end
                end,
                function()
                    if syn and type(syn.request) == "function" then
                        local r = syn.request({ Url = url, Method = "GET" })
                        return r and (r.Body or r.body)
                    end
                end,
                function()
                    if type(http_request) == "function" then
                        local r = http_request({ Url = url, Method = "GET" })
                        return r and (r.Body or r.body)
                    end
                end,
                function()
                    if type(request_get) == "function" then return request_get(url) end
                end,
                function()
                    return game:HttpGet(url, true)
                end,
            }
            for i = 1, #attempts do
                local ok, res = pcall(attempts[i])
                if ok and type(res) == "string" and #res > 5 then return res end
            end
            return nil
        end

        ----------------------------------------------------------------
        -- Clean old addon UI
        ----------------------------------------------------------------
        pcall(function()
            for _, n in ipairs({
                "CyrisWorkspace", "CyrisAvatarsOverlay", "HaloAvatarsOverlay",
                "HaloWorkspaceImportOverlay", "CyrisImportOverlay"
            }) do
                local o = sg:FindFirstChild(n)
                if o then o:Destroy() end
            end
            local bar = menu:FindFirstChild("TitleBar")
            if bar then
                for _, n in ipairs({ "ImportWsBtn", "AvatarsBtn", "CyrisWsBtn" }) do
                    local b = bar:FindFirstChild(n)
                    if b then b:Destroy() end
                end
            end
        end)

        ----------------------------------------------------------------
        -- CYRIS WORKSPACE (Avatars + Import)
        ----------------------------------------------------------------
        local workspace = Instance.new("Frame")
        workspace.Name = "CyrisWorkspace"
        workspace.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
        workspace.BackgroundTransparency = 0.04
        workspace.BorderSizePixel = 0
        workspace.Size = UDim2.new(1, 0, 1, 0)
        workspace.ZIndex = 110
        workspace.Visible = false
        workspace.Parent = sg
        makeCorner(workspace, 16)

        local wsHead = Instance.new("Frame")
        wsHead.BackgroundTransparency = 1
        wsHead.Size = UDim2.new(1, -16, 0, 36)
        wsHead.Position = UDim2.new(0, 8, 0, 6)
        wsHead.ZIndex = 111
        wsHead.Parent = workspace

        local wsTitle = Instance.new("TextLabel")
        wsTitle.BackgroundTransparency = 1
        wsTitle.Size = UDim2.new(1, -70, 1, 0)
        wsTitle.Font = Enum.Font.GothamBold
        wsTitle.Text = "Cyris Workspace"
        wsTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
        wsTitle.TextSize = 15
        wsTitle.TextXAlignment = Enum.TextXAlignment.Left
        wsTitle.ZIndex = 112
        wsTitle.Parent = wsHead

        local closeWs = makeBtn(wsHead, "Back", UDim2.new(0, 56, 0, 24), UDim2.new(1, -56, 0.5, 0), 112)
        closeWs.AnchorPoint = Vector2.new(0, 0.5)
        closeWs.MouseButton1Click:Connect(function()
            workspace.Visible = false
        end)

        -- Sub-tabs: Avatars | Import
        local tabBar = Instance.new("Frame")
        tabBar.BackgroundTransparency = 1
        tabBar.Position = UDim2.new(0, 10, 0, 44)
        tabBar.Size = UDim2.new(1, -20, 0, 28)
        tabBar.ZIndex = 111
        tabBar.Parent = workspace

        local avatarsTabBtn = makeBtn(tabBar, "Avatars", UDim2.new(0, 90, 0, 26), UDim2.new(0, 0, 0, 0), 112)
        local importTabBtn = makeBtn(tabBar, "Import", UDim2.new(0, 90, 0, 26), UDim2.new(0, 96, 0, 0), 112)

        local content = Instance.new("Frame")
        content.Name = "Content"
        content.BackgroundTransparency = 1
        content.Position = UDim2.new(0, 10, 0, 78)
        content.Size = UDim2.new(1, -20, 1, -88)
        content.ZIndex = 111
        content.Parent = workspace

        local avatarsPane = Instance.new("Frame")
        avatarsPane.Name = "AvatarsPane"
        avatarsPane.BackgroundTransparency = 1
        avatarsPane.Size = UDim2.new(1, 0, 1, 0)
        avatarsPane.ZIndex = 111
        avatarsPane.Visible = true
        avatarsPane.Parent = content

        local importPane = Instance.new("Frame")
        importPane.Name = "ImportPane"
        importPane.BackgroundTransparency = 1
        importPane.Size = UDim2.new(1, 0, 1, 0)
        importPane.ZIndex = 111
        importPane.Visible = false
        importPane.Parent = content

        local function setSubTab(which)
            local isAv = (which == "avatars")
            avatarsPane.Visible = isAv
            importPane.Visible = not isAv
            avatarsTabBtn.BackgroundColor3 = isAv and Color3.fromRGB(55, 55, 70) or Color3.fromRGB(32, 32, 40)
            importTabBtn.BackgroundColor3 = (not isAv) and Color3.fromRGB(55, 55, 70) or Color3.fromRGB(32, 32, 40)
        end
        avatarsTabBtn.MouseButton1Click:Connect(function() setSubTab("avatars") end)
        importTabBtn.MouseButton1Click:Connect(function() setSubTab("import") end)
        setSubTab("avatars")

        ----------------------------------------------------------------
        -- AVATARS PANE
        ----------------------------------------------------------------
        local status = Instance.new("TextLabel")
        status.BackgroundTransparency = 1
        status.Size = UDim2.new(1, -190, 0, 18)
        status.Font = Enum.Font.Gotham
        status.Text = "Click an avatar. Swaps in place. Does not kill you."
        status.TextColor3 = Color3.fromRGB(180, 180, 190)
        status.TextSize = 11
        status.TextXAlignment = Enum.TextXAlignment.Left
        status.ZIndex = 112
        status.Parent = avatarsPane

        local refresh = makeBtn(avatarsPane, "Refresh", UDim2.new(0, 70, 0, 22), UDim2.new(1, -70, 0, 0), 112)
        local cloneMe = makeBtn(avatarsPane, "Clone myself", UDim2.new(0, 100, 0, 22), UDim2.new(1, -178, 0, 0), 112)

        local grid = Instance.new("ScrollingFrame")
        grid.BackgroundTransparency = 1
        grid.BorderSizePixel = 0
        grid.Position = UDim2.new(0, 0, 0, 28)
        grid.Size = UDim2.new(1, 0, 1, -28)
        grid.ScrollBarThickness = 4
        grid.ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255)
        grid.ZIndex = 112
        grid.CanvasSize = UDim2.new(0, 0, 0, 0)
        grid.Parent = avatarsPane
        local lay = Instance.new("UIGridLayout")
        lay.CellSize = UDim2.new(0, 90, 0, 118)
        lay.CellPadding = UDim2.new(0, 8, 0, 8)
        lay.SortOrder = Enum.SortOrder.LayoutOrder
        lay.Parent = grid
        lay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            grid.CanvasSize = UDim2.new(0, 0, 0, lay.AbsoluteContentSize.Y + 12)
        end)

        local applying = false

        local function fetchOutfits()
            local list = {}
            pcall(function()
                local AES = game:GetService("AvatarEditorService")
                local pages = AES:GetOutfits(Enum.OutfitSource.All)
                while pages do
                    local page = pages:GetCurrentPage()
                    for _, item in ipairs(page) do
                        local id = item.Id or item.id
                        local name = item.Name or item.name
                        if id then
                            table.insert(list, { id = tonumber(id) or id, name = tostring(name or id) })
                        end
                    end
                    if pages.IsFinished then break end
                    pages:AdvanceToNextPageAsync()
                end
            end)
            if #list > 0 then return list end

            local uid = lp.UserId
            local urls = {
                ("https://avatar.roblox.com/v1/users/%d/outfits?itemsPerPage=50&isEditable=true"):format(uid),
                ("https://avatar.roblox.com/v1/users/%d/outfits?itemsPerPage=50"):format(uid),
                ("https://avatar.roproxy.com/v1/users/%d/outfits?itemsPerPage=50&isEditable=true"):format(uid),
                ("https://avatar.roproxy.com/v1/users/%d/outfits?itemsPerPage=50"):format(uid),
            }
            for _, u in ipairs(urls) do
                local body = httpGet(u)
                if body then
                    local okj, data = pcall(function() return HttpService:JSONDecode(body) end)
                    if okj and type(data) == "table" then
                        local arr = data.data or data.Data or data
                        if type(arr) == "table" then
                            for _, item in ipairs(arr) do
                                if type(item) == "table" then
                                    local id = item.id or item.Id or item.outfitId
                                    local name = item.name or item.Name or tostring(id)
                                    if id then
                                        table.insert(list, { id = tonumber(id) or id, name = tostring(name) })
                                    end
                                end
                            end
                            if #list > 0 then return list end
                        end
                    end
                end
            end
            return nil
        end

        local function getOutfitDescription(outfitId)
            local ok, desc = pcall(function()
                return PlayersSvc:GetHumanoidDescriptionFromOutfitId(outfitId)
            end)
            if ok and desc then return desc end
            ok, desc = pcall(function()
                return PlayersSvc:GetHumanoidDescriptionFromOutfitIdAsync(outfitId)
            end)
            if ok and desc then return desc end
            return nil
        end

        local function getRealHumanoid()
            local api = rawget(_G, "_HaloReanimateAPI") or ReanimateAPI
            local reanim = false
            pcall(function()
                if api and api.is_reanimated then reanim = (api.is_reanimated() == true) end
            end)
            return nil, reanim, api
        end

        local function dressFromModel(toChar, fromChar)
            local toHum = toChar:FindFirstChildOfClass("Humanoid")
            if not toHum or toHum.Health <= 0 then return end
            local hp = toHum.Health
            pcall(function() toHum.BreakJointsOnDeath = false end)

            for _, c in ipairs(toChar:GetChildren()) do
                if c:IsA("Accessory") or c:IsA("Hat") or c:IsA("Shirt") or c:IsA("Pants")
                    or c:IsA("ShirtGraphic") or c:IsA("BodyColors") or c:IsA("CharacterMesh") then
                    pcall(function() c:Destroy() end)
                end
            end

            for _, c in ipairs(fromChar:GetChildren()) do
                if c:IsA("Shirt") or c:IsA("Pants") or c:IsA("ShirtGraphic") or c:IsA("BodyColors") or c:IsA("CharacterMesh") then
                    c:Clone().Parent = toChar
                elseif c:IsA("Accessory") or c:IsA("Hat") then
                    local acc = c:Clone()
                    local added = false
                    pcall(function()
                        toHum:AddAccessory(acc)
                        added = acc.Parent ~= nil
                    end)
                    if not added and acc.Parent == nil then
                        acc.Parent = toChar
                    end
                end
            end

            for _, src in ipairs(fromChar:GetChildren()) do
                if src:IsA("BasePart") and src.Name ~= "HumanoidRootPart" then
                    local dst = toChar:FindFirstChild(src.Name)
                    if dst and dst:IsA("BasePart") then
                        pcall(function() dst.Color = src.Color end)
                        local meshed = false
                        if src:IsA("MeshPart") and dst:IsA("MeshPart") then
                            local before = dst.MeshId
                            local okMesh = pcall(function() dst:ApplyMesh(src) end)
                            meshed = okMesh and dst.MeshId ~= before
                            if meshed then
                                local old = dst:FindFirstChild("PrismLook")
                                if old then old:Destroy() end
                                pcall(function() dst.LocalTransparencyModifier = 0 end)
                                if dst.Transparency >= 1 then dst.Transparency = src.Transparency end
                            end
                        end
                        local sm = src:FindFirstChildOfClass("SpecialMesh")
                        if sm then
                            local oldSm = dst:FindFirstChildOfClass("SpecialMesh")
                            if oldSm then oldSm:Destroy() end
                            sm:Clone().Parent = dst
                            meshed = true
                        end
                        if not meshed and (src:IsA("MeshPart") or src:FindFirstChildOfClass("SpecialMesh")) then
                            local old = dst:FindFirstChild("PrismLook")
                            if old then old:Destroy() end
                            local vis = src:Clone()
                            vis.Name = "PrismLook"
                            for _, ch in ipairs(vis:GetChildren()) do
                                if not ch:IsA("Decal") and not ch:IsA("SpecialMesh") and not ch:IsA("SurfaceAppearance") then
                                    ch:Destroy()
                                end
                            end
                            vis.Anchored = false
                            vis.CanCollide = false
                            vis.Massless = true
                            vis.CanQuery = false
                            vis.CanTouch = false
                            vis.CFrame = dst.CFrame
                            local w = Instance.new("Weld")
                            w.Part0 = dst
                            w.Part1 = vis
                            w.C0 = CFrame.new()
                            w.C1 = CFrame.new()
                            w.Parent = vis
                            vis.Parent = dst
                            pcall(function() dst.LocalTransparencyModifier = 1 end)
                        end
                        if src.Name == "Head" then
                            local srcFace = src:FindFirstChild("face")
                            if srcFace and srcFace:IsA("Decal") then
                                local host = dst:FindFirstChild("PrismLook") or dst
                                local dstFace = host:FindFirstChild("face")
                                if dstFace and dstFace:IsA("Decal") then
                                    pcall(function() dstFace.Texture = srcFace.Texture end)
                                else
                                    local d = srcFace:Clone()
                                    d.Parent = host
                                end
                            end
                        end
                    end
                end
            end

            local fromHum = fromChar:FindFirstChildOfClass("Humanoid")
            if fromHum then
                for _, nv in ipairs(fromHum:GetChildren()) do
                    if nv:IsA("NumberValue") then
                        local mine = toHum:FindFirstChild(nv.Name)
                        if mine and mine:IsA("NumberValue") then
                            pcall(function() mine.Value = nv.Value end)
                        end
                    end
                end
            end

            if toHum.Health < hp then
                pcall(function() toHum.Health = hp end)
            end
        end

        local function applyOutfit(outfitId, outfitName)
            if applying then return end
            applying = true
            status.Text = "Applying " .. tostring(outfitName) .. "..."
            status.TextColor3 = Color3.fromRGB(255, 255, 255)
            task.spawn(function()
                local ok, err = pcall(function()
                    local desc = getOutfitDescription(outfitId)
                    if not desc then error("Could not load that outfit") end
                    local _, _, api = getRealHumanoid()
                    local rigType = Enum.HumanoidRigType.R15
                    local char = lp.Character
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    if hum then rigType = hum.RigType end
                    local model = PlayersSvc:CreateHumanoidModelFromDescription(desc, rigType)
                    local targets = {}
                    local function add(m)
                        if m and not targets[m] then targets[m] = true table.insert(targets, m) end
                    end
                    add(char)
                    pcall(function()
                        if api and api.get_clone then add(api.get_clone(lp)) end
                        if api and api.get_real_character then add(api.get_real_character(lp)) end
                    end)
                    if #targets == 0 then
                        model:Destroy()
                        error("No character")
                    end
                    for _, target in ipairs(targets) do
                        dressFromModel(target, model)
                    end
                    model:Destroy()
                    pcall(function()
                        if api and api.invalidate_constraint_cache then api.invalidate_constraint_cache() end
                    end)
                end)
                if ok then
                    status.Text = "Applied: " .. tostring(outfitName)
                    status.TextColor3 = Color3.fromRGB(80, 220, 120)
                    pcall(function()
                        if Notify then Notify("Avatars", tostring(outfitName), 2) end
                    end)
                else
                    status.Text = "Failed: " .. tostring(err)
                    status.TextColor3 = Color3.fromRGB(255, 90, 90)
                    warn("[Avatars] " .. tostring(err))
                end
                applying = false
            end)
        end

        local function cloneMyself()
            if applying then return end
            applying = true
            status.Text = "Cloning you..."
            status.TextColor3 = Color3.fromRGB(255, 255, 255)
            task.spawn(function()
                local ok, err = pcall(function()
                    local _, _, api = getRealHumanoid()
                    local rigType = Enum.HumanoidRigType.R15
                    local char = lp.Character
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    if hum then rigType = hum.RigType end
                    local model
                    local okM, m = pcall(function()
                        return PlayersSvc:CreateHumanoidModelFromUserIdAsync(lp.UserId)
                    end)
                    if okM and typeof(m) == "Instance" then model = m end
                    if not model then
                        local ok2, m2 = pcall(function()
                            return PlayersSvc:CreateHumanoidModelFromUserId(lp.UserId)
                        end)
                        if ok2 and typeof(m2) == "Instance" then model = m2 end
                    end
                    if not model then
                        local desc = PlayersSvc:GetHumanoidDescriptionFromUserId(lp.UserId)
                        model = PlayersSvc:CreateHumanoidModelFromDescription(desc, rigType)
                    end
                    local targets, seen = {}, {}
                    local function add(m)
                        if m and not seen[m] then seen[m] = true table.insert(targets, m) end
                    end
                    add(char)
                    pcall(function()
                        if api and api.get_clone then add(api.get_clone(lp)) end
                        if api and api.get_real_character then add(api.get_real_character(lp)) end
                    end)
                    if #targets == 0 then
                        model:Destroy()
                        error("No character")
                    end
                    for _, target in ipairs(targets) do
                        dressFromModel(target, model)
                    end
                    model:Destroy()
                end)
                if ok then
                    status.Text = "Cloned you. You were not reset."
                    status.TextColor3 = Color3.fromRGB(80, 220, 120)
                    pcall(function() if Notify then Notify("Avatars", "Cloned you", 2) end end)
                else
                    status.Text = "Clone failed: " .. tostring(err)
                    status.TextColor3 = Color3.fromRGB(255, 90, 90)
                end
                applying = false
            end)
        end
        cloneMe.MouseButton1Click:Connect(cloneMyself)
        _G._CyrisCloneMyself = cloneMyself

        local function loadOutfits()
            status.Text = "Loading outfits..."
            status.TextColor3 = Color3.fromRGB(180, 180, 190)
            for _, ch in ipairs(grid:GetChildren()) do
                if ch:IsA("GuiObject") then ch:Destroy() end
            end
            task.spawn(function()
                local list = fetchOutfits()
                if not list then
                    status.Text = "Could not load outfits (HTTP?). Try Refresh."
                    status.TextColor3 = Color3.fromRGB(255, 90, 90)
                    return
                end
                status.Text = tostring(#list) .. " outfit(s)"
                status.TextColor3 = Color3.fromRGB(200, 200, 210)
                for i, outfit in ipairs(list) do
                    local card = Instance.new("TextButton")
                    card.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
                    card.BorderSizePixel = 0
                    card.Text = ""
                    card.AutoButtonColor = false
                    card.ZIndex = 113
                    card.LayoutOrder = i
                    card.Parent = grid
                    makeCorner(card, 8)

                    local img = Instance.new("ImageLabel")
                    img.BackgroundTransparency = 1
                    img.Size = UDim2.new(1, -8, 0, 80)
                    img.Position = UDim2.new(0.5, 0, 0, 5)
                    img.AnchorPoint = Vector2.new(0.5, 0)
                    img.ScaleType = Enum.ScaleType.Fit
                    img.ZIndex = 114
                    img.Image = ("rbxthumb://type=Outfit&id=%d&w=150&h=150"):format(outfit.id)
                    img.Parent = card

                    local nm = Instance.new("TextLabel")
                    nm.BackgroundTransparency = 1
                    nm.Position = UDim2.new(0, 4, 1, -28)
                    nm.Size = UDim2.new(1, -8, 0, 24)
                    nm.Font = Enum.Font.GothamMedium
                    nm.Text = outfit.name
                    nm.TextColor3 = Color3.fromRGB(220, 220, 230)
                    nm.TextSize = 10
                    nm.TextWrapped = true
                    nm.ZIndex = 114
                    nm.Parent = card

                    card.MouseButton1Click:Connect(function()
                        applyOutfit(outfit.id, outfit.name)
                    end)
                end
            end)
        end

        refresh.MouseButton1Click:Connect(loadOutfits)

        ----------------------------------------------------------------
        -- IMPORT PANE (workspace file scan)
        ----------------------------------------------------------------
        local impStatus = Instance.new("TextLabel")
        impStatus.BackgroundTransparency = 1
        impStatus.Size = UDim2.new(1, 0, 0, 32)
        impStatus.Font = Enum.Font.Gotham
        impStatus.Text = "Scans executor workspace for .lua / .json / .txt / .dat custom keyframe files."
        impStatus.TextColor3 = Color3.fromRGB(170, 170, 180)
        impStatus.TextSize = 11
        impStatus.TextXAlignment = Enum.TextXAlignment.Left
        impStatus.TextWrapped = true
        impStatus.ZIndex = 112
        impStatus.Parent = importPane

        local scanBtn = makeBtn(importPane, "Scan Workspace", UDim2.new(0, 120, 0, 26), UDim2.new(0, 0, 0, 36), 112)
        local importAllBtn = makeBtn(importPane, "Import All Found", UDim2.new(0, 130, 0, 26), UDim2.new(0, 128, 0, 36), 112)

        local list = Instance.new("ScrollingFrame")
        list.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
        list.BackgroundTransparency = 0.2
        list.BorderSizePixel = 0
        list.Position = UDim2.new(0, 0, 0, 70)
        list.Size = UDim2.new(1, 0, 1, -70)
        list.ScrollBarThickness = 4
        list.ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255)
        list.ZIndex = 112
        list.CanvasSize = UDim2.new(0, 0, 0, 0)
        list.Parent = importPane
        makeCorner(list, 8)
        local ll = Instance.new("UIListLayout")
        ll.Padding = UDim.new(0, 6)
        ll.SortOrder = Enum.SortOrder.LayoutOrder
        ll.Parent = list
        local pad = Instance.new("UIPadding")
        pad.PaddingTop = UDim.new(0, 8)
        pad.PaddingBottom = UDim.new(0, 8)
        pad.PaddingLeft = UDim.new(0, 8)
        pad.PaddingRight = UDim.new(0, 8)
        pad.Parent = list
        ll:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            list.CanvasSize = UDim2.new(0, 0, 0, ll.AbsoluteContentSize.Y + 16)
        end)

        local foundFiles = {}

        local function basename(p)
            return (tostring(p):match("([^/\\]+)$")) or tostring(p)
        end
        local function stripExt(n)
            return n:gsub("%.%w+$", "")
        end
        local function looksLikeAnim(content)
            if not content or #content < 20 then return false end
            local s = content:sub(1, 800)
            if s:find("{", 1, true) and (
                s:lower():find("time", 1, true)
                or s:find("CFrame", 1, true)
                or s:find("keyframes", 1, true)
                or s:find("Keyframes", 1, true)
                or s:find("Poses", 1, true)
                or s:find("Motor6D", 1, true)
            ) then
                return true
            end
            local fc = content:match("^%s*(.)")
            if (fc == "{" or fc == "[") and content:find("Time", 1, true) then
                return true
            end
            return false
        end
        local function listDir(dir)
            local listFilesFunc = listfiles or list_files
            if type(listFilesFunc) ~= "function" then return {} end
            local ok, files = pcall(listFilesFunc, dir)
            if ok and type(files) == "table" then return files end
            return {}
        end

        local function importOne(entry)
            if not entry then return end
            local content = entry.content
            if not content then
                local ok, data = pcall(readfile, entry.path)
                if not ok or not data or data == "" then
                    impStatus.Text = "Failed to read " .. tostring(entry.path)
                    impStatus.TextColor3 = Color3.fromRGB(255, 90, 90)
                    return
                end
                content = data
            end
            content = content:gsub("^\xEF\xBB\xBF", ""):gsub("\r\n", "\n"):gsub("\r", "\n")
            local name = entry.name or "Custom"
            if CustomAnimations and CustomAnimations[name] then
                name = name .. "_" .. tostring(os.time() % 10000)
            end
            local firstChar = content:match("^%s*(.)")
            local isJson = (firstChar == "{" or firstChar == "[")

            local okIns = pcall(function()
                if type(CustomAnims) ~= "table" then error("CustomAnims missing") end
                local _SAVE_INLINE_MAX = 4000
                if #content > _SAVE_INLINE_MAX and type(writefile) == "function" then
                    local safeFileName = (type(fpath) == "function" and fpath("custom_" .. name:gsub("[^%w_%-]", "_") .. ".dat"))
                        or ("ReanimData/custom_" .. name:gsub("[^%w_%-]", "_") .. ".dat")
                    pcall(function() makefolder("ReanimData") end)
                    writefile(safeFileName, content)
                    table.insert(CustomAnims, { name = name, url = safeFileName, raw = true, isJson = isJson })
                    if CustomAnimations then CustomAnimations[name] = safeFileName end
                else
                    table.insert(CustomAnims, { name = name, url = content, raw = true, isJson = isJson })
                    if CustomAnimations then CustomAnimations[name] = content end
                end
                if type(SaveCustomAnims) == "function" then SaveCustomAnims() end
                if type(AppendCustomRow) == "function" then
                    local newEntry = CustomAnims[#CustomAnims]
                    if newEntry then AppendCustomRow(newEntry) end
                end
            end)
            if okIns then
                impStatus.Text = "Imported: " .. name
                impStatus.TextColor3 = Color3.fromRGB(80, 220, 120)
                pcall(function() if Notify then Notify("Cyris", "Imported " .. name, 2) end end)
            else
                impStatus.Text = "Import failed for " .. tostring(entry.name)
                impStatus.TextColor3 = Color3.fromRGB(255, 90, 90)
            end
        end

        local function scanWorkspace()
            foundFiles = {}
            for _, ch in ipairs(list:GetChildren()) do
                if ch:IsA("GuiObject") then ch:Destroy() end
            end
            impStatus.Text = "Scanning..."
            impStatus.TextColor3 = Color3.fromRGB(200, 200, 210)

            local roots = {
                "", ".", "workspace", "Workspace", "scripts", "Scripts",
                "anims", "Anims", "animations", "Animations",
                "custom", "Custom", "ReanimData", "ak", "AK",
            }
            local seen = {}
            local candidates = {}

            for _, root in ipairs(roots) do
                for _, f in ipairs(listDir(root)) do
                    local path = tostring(f)
                    if not seen[path] then
                        seen[path] = true
                        local lower = path:lower()
                        if lower:match("%.lua$") or lower:match("%.json$") or lower:match("%.txt$") or lower:match("%.dat$") then
                            if not lower:find("keybind")
                                and not lower:find("favorite")
                                and not lower:find("settings")
                                and not lower:find("reanimstates")
                                and not lower:find("reanimspeed")
                                and not lower:find("reanimcustomanims.json") then
                                table.insert(candidates, path)
                            end
                        end
                    end
                end
            end

            for _, root in ipairs({ "workspace", "Workspace", "scripts", "anims", "custom", "ak" }) do
                for _, f in ipairs(listDir(root)) do
                    local p = tostring(f)
                    if p:sub(-1) == "/" or (not p:match("%.%w+$")) then
                        for _, f2 in ipairs(listDir(p)) do
                            local path = tostring(f2)
                            if not seen[path] then
                                seen[path] = true
                                local lower = path:lower()
                                if lower:match("%.lua$") or lower:match("%.json$") or lower:match("%.txt$") or lower:match("%.dat$") then
                                    table.insert(candidates, path)
                                end
                            end
                        end
                    end
                end
            end

            local validCount = 0
            for i, path in ipairs(candidates) do
                local content = nil
                local ok, data = pcall(readfile, path)
                if ok then content = data end
                local valid = looksLikeAnim(content)
                local name = stripExt(basename(path))
                local entry = { path = path, name = name, valid = valid, content = content }
                table.insert(foundFiles, entry)
                if valid then validCount = validCount + 1 end

                local row = Instance.new("Frame")
                row.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
                row.BorderSizePixel = 0
                row.Size = UDim2.new(1, -4, 0, 44)
                row.ZIndex = 113
                row.LayoutOrder = i
                row.Parent = list
                makeCorner(row, 6)

                local nm = Instance.new("TextLabel")
                nm.BackgroundTransparency = 1
                nm.Position = UDim2.new(0, 10, 0, 4)
                nm.Size = UDim2.new(1, -100, 0, 18)
                nm.Font = Enum.Font.GothamBold
                nm.Text = name
                nm.TextColor3 = Color3.fromRGB(255, 255, 255)
                nm.TextSize = 12
                nm.TextXAlignment = Enum.TextXAlignment.Left
                nm.ZIndex = 114
                nm.Parent = row

                local sub = Instance.new("TextLabel")
                sub.BackgroundTransparency = 1
                sub.Position = UDim2.new(0, 10, 0, 22)
                sub.Size = UDim2.new(1, -100, 0, 16)
                sub.Font = Enum.Font.Gotham
                sub.Text = path .. (valid and "  ✓ looks like anim" or "  ? unknown")
                sub.TextColor3 = valid and Color3.fromRGB(100, 200, 120) or Color3.fromRGB(140, 140, 150)
                sub.TextSize = 10
                sub.TextXAlignment = Enum.TextXAlignment.Left
                sub.TextTruncate = Enum.TextTruncate.AtEnd
                sub.ZIndex = 114
                sub.Parent = row

                local imp = makeBtn(row, "Import", UDim2.new(0, 64, 0, 26), UDim2.new(1, -74, 0.5, 0), 115)
                imp.AnchorPoint = Vector2.new(0, 0.5)
                imp.MouseButton1Click:Connect(function()
                    importOne(entry)
                end)
            end

            impStatus.Text = "Found " .. tostring(#candidates) .. " file(s), " .. tostring(validCount) .. " look like animations."
            impStatus.TextColor3 = Color3.fromRGB(200, 200, 210)
        end

        scanBtn.MouseButton1Click:Connect(function()
            task.spawn(scanWorkspace)
        end)
        importAllBtn.MouseButton1Click:Connect(function()
            task.spawn(function()
                local n = 0
                for _, e in ipairs(foundFiles) do
                    if e.valid then
                        importOne(e)
                        n = n + 1
                    end
                end
                impStatus.Text = "Imported " .. tostring(n) .. " animation(s)."
                impStatus.TextColor3 = Color3.fromRGB(80, 220, 120)
            end)
        end)

        ----------------------------------------------------------------
        -- Open/close API
        ----------------------------------------------------------------
        _G._CyrisOpenWorkspace = function()
            workspace.Visible = true
            setSubTab("avatars")
            loadOutfits()
        end
        _G._CyrisCloseWorkspace = function()
            workspace.Visible = false
        end
        _G._CyrisOpenAvatars = _G._CyrisOpenWorkspace
        _G._HaloOpenAvatarsMenu = _G._CyrisOpenWorkspace

        local function isMyBody(part)
            if not part then return false end
            local char = lp.Character
            if char and part:IsDescendantOf(char) then return true end
            local api = rawget(_G, "_HaloReanimateAPI") or ReanimateAPI
            local ok, mine = pcall(function()
                if api and api.get_clone then return api.get_clone(lp) end
            end)
            if ok and mine and part:IsDescendantOf(mine) then return true end
            local ok2, real = pcall(function()
                if api and api.get_real_character then return api.get_real_character(lp) end
            end)
            if ok2 and real and part:IsDescendantOf(real) then return true end
            return false
        end

        local clickUIS = game:GetService("UserInputService")
        local world = game:GetService("Workspace")
        local selfDummy = nil
        local proxy

        local function makeProxy()
            local p = {}
            setmetatable(p, {
                __index = function(_, k)
                    if k == "Character" then return selfDummy or lp.Character end
                    if k == "Name" then return lp.Name end
                    if k == "DisplayName" then return lp.DisplayName end
                    if k == "UserId" then return lp.UserId end
                    if k == "ClassName" then return "Player" end
                    local ok, v = pcall(function() return lp[k] end)
                    if not ok then return nil end
                    if type(v) == "function" then
                        return function(a, ...)
                            if a == p then return v(lp, ...) end
                            return v(a, ...)
                        end
                    end
                    return v
                end,
                __tostring = function() return lp.Name end,
            })
            function p:IsA(c)
                return c == "Player" or c == "Instance" or c == "Object"
            end
            function p:GetAttribute(n)
                local ok, v = pcall(function() return lp:GetAttribute(n) end)
                if ok then return v end
            end
            function p:FindFirstChild(n)
                return nil
            end
            return p
        end
        proxy = makeProxy()

        local oldGet = Players.GetPlayerFromCharacter
        local callingOriginal = false
        local function resolve(self, model)
            if typeof(self) ~= "Instance" then
                model = self
                self = Players
            end
            if not callingOriginal and selfDummy and typeof(model) == "Instance" then
                if model == selfDummy or model:IsDescendantOf(selfDummy) then
                    return proxy
                end
            end
            callingOriginal = true
            local ok, res = pcall(function()
                return oldGet(self, model)
            end)
            callingOriginal = false
            if ok then return res end
            return nil
        end
        Players.GetPlayerFromCharacter = function(self, model)
            return resolve(self, model)
        end
        pcall(function()
            if hookfunction then
                local original
                original = hookfunction(oldGet, function(a, b)
                    if callingOriginal then
                        if b == nil then return original(Players, a) end
                        return original(a, b)
                    end
                    return resolve(a, b)
                end)
                oldGet = original
            end
        end)

        local function fireGameClone(targetPlayer)
            local rs = game:GetService("ReplicatedStorage")
            local name = targetPlayer.Name
            local function tryFire(inst)
                if not inst then return end
                if inst:IsA("RemoteEvent") then
                    pcall(function() inst:FireServer(name) end)
                    pcall(function() inst:FireServer(targetPlayer) end)
                    pcall(function() inst:FireServer(targetPlayer.UserId) end)
                elseif inst:IsA("RemoteFunction") then
                    pcall(function() inst:InvokeServer(name) end)
                end
            end
            tryFire(rs:FindFirstChild("ToggleDisallowEvent", true))
            tryFire(rs:FindFirstChild("ModifyUsername", true))
            tryFire(rs:FindFirstChild("ModifyUserEvent", true))
            for _, d in ipairs(rs:GetDescendants()) do
                if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
                    local n = string.lower(d.Name)
                    if n == "cloneavatar" or n == "clone" or n == "copyavatar" or n == "copyavatarevent"
                        or n == "becomeavatar" or n == "morph" or n == "morphplayer" then
                        tryFire(d)
                    end
                end
            end
        end

        local card
        local function openSelfMenu()
            local pg = lp:FindFirstChildOfClass("PlayerGui")
            if pg then
                local gameMenu = pg:FindFirstChild("Menu")
                if gameMenu and gameMenu:IsA("ScreenGui") then
                    gameMenu.Enabled = true
                end
                for _, d in ipairs(pg:GetDescendants()) do
                    if d:IsA("GuiObject") and d.Name == "ModifyUser" then
                        local p = d
                        while p and not p:IsA("ScreenGui") do
                            if p:IsA("GuiObject") then p.Visible = true end
                            p = p.Parent
                        end
                        if p and p:IsA("ScreenGui") then p.Enabled = true end
                    end
                end
            end

            if card then card:Destroy() end
            card = Instance.new("Frame")
            card.Name = "SelfPlayerCard"
            card.AnchorPoint = Vector2.new(0.5, 0.5)
            card.Position = UDim2.fromScale(0.5, 0.5)
            card.Size = UDim2.fromOffset(260, 320)
            card.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
            card.BorderSizePixel = 0
            card.ZIndex = 200
            card.Parent = sg
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 12)
            corner.Parent = card
            local stroke = Instance.new("UIStroke")
            stroke.Color = Color3.fromRGB(255, 40, 60)
            stroke.Thickness = 1.5
            stroke.Parent = card

            local title = Instance.new("TextLabel")
            title.BackgroundTransparency = 1
            title.Size = UDim2.new(1, -36, 0, 28)
            title.Position = UDim2.fromOffset(12, 8)
            title.Font = Enum.Font.GothamBold
            title.TextSize = 14
            title.TextXAlignment = Enum.TextXAlignment.Left
            title.TextColor3 = Color3.fromRGB(255, 255, 255)
            title.Text = "Players"
            title.ZIndex = 201
            title.Parent = card

            local close = Instance.new("TextButton")
            close.Size = UDim2.fromOffset(24, 24)
            close.Position = UDim2.new(1, -30, 0, 8)
            close.BackgroundTransparency = 1
            close.Text = "X"
            close.TextColor3 = Color3.fromRGB(255, 80, 90)
            close.Font = Enum.Font.GothamBold
            close.TextSize = 14
            close.ZIndex = 202
            close.Parent = card
            close.MouseButton1Click:Connect(function()
                if card then card:Destroy() card = nil end
            end)

            local list = Instance.new("ScrollingFrame")
            list.BackgroundTransparency = 1
            list.Position = UDim2.fromOffset(10, 40)
            list.Size = UDim2.new(1, -20, 1, -50)
            list.ScrollBarThickness = 4
            list.CanvasSize = UDim2.new()
            list.ZIndex = 201
            list.Parent = card
            local lay = Instance.new("UIListLayout")
            lay.Padding = UDim.new(0, 6)
            lay.Parent = list
            lay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                list.CanvasSize = UDim2.fromOffset(0, lay.AbsoluteContentSize.Y + 8)
            end)

            local function addRow(plr, mine)
                local row = Instance.new("TextButton")
                row.Size = UDim2.new(1, -8, 0, 42)
                row.BackgroundColor3 = mine and Color3.fromRGB(60, 16, 24) or Color3.fromRGB(24, 24, 30)
                row.Text = ""
                row.AutoButtonColor = false
                row.ZIndex = 202
                row.Parent = list
                local rc = Instance.new("UICorner")
                rc.CornerRadius = UDim.new(0, 8)
                rc.Parent = row
                local img = Instance.new("ImageLabel")
                img.BackgroundTransparency = 1
                img.Size = UDim2.fromOffset(32, 32)
                img.Position = UDim2.fromOffset(6, 5)
                img.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(plr.UserId) .. "&w=150&h=150"
                img.ZIndex = 203
                img.Parent = row
                local ic = Instance.new("UICorner")
                ic.CornerRadius = UDim.new(1, 0)
                ic.Parent = img
                local nm = Instance.new("TextLabel")
                nm.BackgroundTransparency = 1
                nm.Position = UDim2.fromOffset(46, 0)
                nm.Size = UDim2.new(1, -52, 1, 0)
                nm.Font = Enum.Font.GothamMedium
                nm.TextSize = 13
                nm.TextXAlignment = Enum.TextXAlignment.Left
                nm.TextColor3 = Color3.fromRGB(240, 240, 245)
                nm.Text = (mine and "(you) " or "") .. plr.DisplayName .. "  @" .. plr.Name
                nm.ZIndex = 203
                nm.Parent = row
                row.MouseButton1Click:Connect(function()
                    fireGameClone(plr)
                    pcall(function()
                        if Notify then Notify("Clone", "Cloned " .. plr.DisplayName, 2) end
                    end)
                end)
            end

            addRow(lp, true)
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= lp then addRow(plr, false) end
            end
        end

        clickUIS.InputBegan:Connect(function(input, gp)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1
                and input.UserInputType ~= Enum.UserInputType.Touch then
                return
            end
            local mouse = lp:GetMouse()
            local target = mouse and mouse.Target
            if not target or not isMyBody(target) then return end
            if gp and target:IsDescendantOf(sg) then return end
            openSelfMenu()
        end)

        ----------------------------------------------------------------
        -- Title-bar Workspace button
        ----------------------------------------------------------------
        pcall(function()
            local bar = menu:FindFirstChild("TitleBar")
            if not bar then return end
            local btn = Instance.new("TextButton")
            btn.Name = "CyrisWsBtn"
            btn.AnchorPoint = Vector2.new(1, 0.5)
            btn.Position = UDim2.new(1, -204, 0.5, 0)
            btn.Size = UDim2.new(0, 78, 0, 22)
            btn.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
            btn.BackgroundTransparency = 0.05
            btn.BorderSizePixel = 0
            btn.Font = Enum.Font.GothamBold
            btn.Text = "Avatars"
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            btn.TextSize = 10
            btn.ZIndex = 40
            btn.AutoButtonColor = false
            btn.Parent = bar
            makeCorner(btn, 6)
            btn.MouseButton1Click:Connect(function()
                if type(_G._CyrisOpenWorkspace) == "function" then
                    _G._CyrisOpenWorkspace()
                end
            end)
        end)
    end)
    if not okAddon then
        warn("[Cyris addon] " .. tostring(errAddon))
    end
end)


-- ============================================================
-- CYRIS: F key teleports to cursor (mouse hit)
-- ============================================================
task.spawn(function()
    pcall(function()
        local UIS = game:GetService("UserInputService")
        local Players = game:GetService("Players")
        local lp = Players.LocalPlayer
        if not lp then return end

        -- avoid stacking binds on re-execute
        if _G._CyrisFTeleportConn then
            pcall(function() _G._CyrisFTeleportConn:Disconnect() end)
            _G._CyrisFTeleportConn = nil
        end

        local function getRoot()
            local api = rawget(_G, "_HaloReanimateAPI") or rawget(_G, "ReanimateAPI") or ReanimateAPI
            -- Prefer visible/control character
            local char = lp.Character
            if api and type(api.is_reanimated) == "function" then
                local ok, re = pcall(api.is_reanimated)
                if ok and re then
                    -- while reanimated, LocalPlayer.Character is usually the clone (what you control)
                    if not char and type(api.get_clone) == "function" then
                        pcall(function() char = api.get_clone(lp) end)
                    end
                end
            end
            if not char then return nil end
            return char:FindFirstChild("HumanoidRootPart")
                or char:FindFirstChild("Torso")
                or char:FindFirstChild("UpperTorso")
                or char:FindFirstChildWhichIsA("BasePart")
        end

        local function teleportToCursor()
            local root = getRoot()
            if not root then return end
            local mouse = lp:GetMouse()
            if not mouse then return end
            local hit = mouse.Hit
            if not hit then return end
            -- keep current facing
            local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = root.CFrame:components()
            root.CFrame = CFrame.new(hit.X, hit.Y + 3, hit.Z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
            pcall(function()
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
                root.Velocity = Vector3.zero
                root.RotVelocity = Vector3.zero
            end)
        end

        _G._CyrisFTeleportConn = UIS.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            if input.KeyCode == Enum.KeyCode.F then
                -- don't steal F while typing in a text box
                local focused = UIS:GetFocusedTextBox()
                if focused then return end
                teleportToCursor()
            end
        end)
    end)
end)


-- ============================================================


-- ============================================================


-- ============================================================
-- CYRIS EMOTE SMOOTHNESS (safe: never runs during reanimate toggle)
-- + Cyris branding in Settings
-- ============================================================
task.spawn(function()
    pcall(function()
        local RunService = game:GetService("RunService")
        local Players = game:GetService("Players")
        local UIS = game:GetService("UserInputService")
        local lp = Players.LocalPlayer
        if not lp then return end

        ----------------------------------------------------------------
        -- Branding
        ----------------------------------------------------------------
        task.spawn(function()
            for _ = 1, 40 do
                local sg = nil
                pcall(function()
                    if ScreenGui and ScreenGui.Parent then sg = ScreenGui end
                end)
                if not sg then
                    local pg = lp:FindFirstChildOfClass("PlayerGui")
                    if pg then sg = pg:FindFirstChild("ReanimHaloMenu") end
                end
                if sg then
                    for _, d in ipairs(sg:GetDescendants()) do
                        if d:IsA("TextLabel") or d:IsA("TextButton") then
                            local t = d.Text
                            if type(t) == "string" and (t:find("Halo") or t:find("reanim out")) then
                                t = t:gsub("Halo Reanim", "Cyris")
                                t = t:gsub("Halo Reanimation", "Cyris")
                                t = t:gsub("Best reanim out", "Cyris reanim")
                                t = t:gsub("Halo", "Cyris")
                                d.Text = t
                            end
                        end
                    end
                    break
                end
                task.wait(0.15)
            end
        end)

        ----------------------------------------------------------------
        -- Smoothness value
        ----------------------------------------------------------------
        local DEFAULT = 0.55
        local function loadSmooth()
            local v = DEFAULT
            pcall(function()
                if isfile and isfile("ReanimData/cyris_emote_smooth.txt") then
                    local n = tonumber(readfile("ReanimData/cyris_emote_smooth.txt"))
                    if n then v = math.clamp(n, 0, 1) end
                end
            end)
            return v
        end
        local function saveSmooth(v)
            pcall(function()
                makefolder("ReanimData")
                writefile("ReanimData/cyris_emote_smooth.txt", tostring(v))
            end)
        end
        _G._CyrisEmoteSmoothness = loadSmooth()

        ----------------------------------------------------------------
        -- Crossfade only while already reanimated + playing emotes
        ----------------------------------------------------------------
        local blendConn = nil
        local pendingFrom = nil

        local function getApi()
            return rawget(_G, "_HaloReanimateAPI") or ReanimateAPI
        end

        local function isReanimated()
            local api = getApi()
            local ok, res = pcall(function()
                return api and api.is_reanimated and api.is_reanimated() == true
            end)
            return ok and res == true
        end

        local function isAnimJoint(inst)
            return inst and (inst:IsA("Motor6D") or inst:IsA("AnimationConstraint")
                or inst.ClassName == "AnimationConstraint")
        end

        local function getClone()
            local api = getApi()
            local clone = nil
            pcall(function()
                if api and api.get_clone then clone = api.get_clone(lp) end
            end)
            if not clone then clone = lp.Character end
            return clone
        end

        local function capturePose(model)
            local poses = {}
            if not model then return poses end
            for _, d in ipairs(model:GetDescendants()) do
                if isAnimJoint(d) then
                    local ok, tr = pcall(function() return d.Transform end)
                    if ok and typeof(tr) == "CFrame" then
                        poses[d] = tr
                    end
                end
            end
            return poses
        end

        local function stopBlend()
            if blendConn then
                pcall(function() blendConn:Disconnect() end)
                blendConn = nil
            end
            pendingFrom = nil
        end

        local function startCrossfade(fromPoses, duration)
            if blendConn then
                pcall(function() blendConn:Disconnect() end)
                blendConn = nil
            end
            if not fromPoses or not next(fromPoses) then return end
            duration = tonumber(duration) or 0
            if duration <= 0.02 then return end
            -- Never blend if reanim is off / switching
            if not isReanimated() then return end

            local t0 = os.clock()
            -- Heartbeat runs AFTER the animation HB that writes Transform,
            -- so we can correctly lerp from previous pose into the new pose.
            blendConn = RunService.Heartbeat:Connect(function()
                if not isReanimated() then
                    pcall(function() blendConn:Disconnect() end)
                    blendConn = nil
                    return
                end
                local a = (os.clock() - t0) / duration
                if a >= 1 then
                    pcall(function() blendConn:Disconnect() end)
                    blendConn = nil
                    return
                end
                a = a * a * (3 - 2 * a) -- smoothstep
                for joint, fromCF in pairs(fromPoses) do
                    if joint and joint.Parent then
                        -- Never let the crossfade fight the head/arm trackers:
                        -- those joints are driven every frame by the animation
                        -- heartbeat, so blending them here would cancel the tracker.
                        local skip = false
                        local nm = nil
                        pcall(function()
                            if joint:IsA("Motor6D") then
                                nm = joint.Part1 and joint.Part1.Name
                            else
                                local att1 = joint.Attachment1
                                if att1 and att1.Parent then nm = att1.Parent.Name end
                            end
                        end)
                        if nm then
                            if nm == "Head" and (_G._HaloHeadTrackerEnabled or _G._HaloHeadStretching) then skip = true end
                            if _G._HaloTrackActive and (nm == "UpperTorso" or nm == "LowerTorso" or nm == "Torso") then skip = true end
                            local stretchL = _G._HaloLeftArmStretching
                            local stretchR = _G._HaloRightArmStretching
                            if (_G._HaloArmAiming and _G._HaloLeftArmPointerEnabled or stretchL) and (nm == "LeftUpperArm" or nm == "LeftLowerArm" or nm == "LeftHand") then skip = true end
                            if (_G._HaloArmAiming and _G._HaloRightArmPointerEnabled or stretchR) and (nm == "RightUpperArm" or nm == "RightLowerArm" or nm == "RightHand") then skip = true end
                        end
                        if not skip then
                            local ok, target = pcall(function() return joint.Transform end)
                            if ok and typeof(target) == "CFrame" and typeof(fromCF) == "CFrame" then
                                joint.Transform = fromCF:Lerp(target, a)
                            end
                        end
                    end
                end
            end)
        end

        local function blendDuration()
            local sm = math.clamp(tonumber(_G._CyrisEmoteSmoothness) or DEFAULT, 0, 1)
            return math.max(0.12, sm * 1.25)
        end

        local function stashCurrentPose()
            if not isReanimated() then
                pendingFrom = nil
                return nil
            end
            -- Prefer the pose stashed by stop_animation_for_transition (the real
            -- previous animation pose) so transitions blend smoothly instead of
            -- snapping to bind pose. Ignore it if it is stale.
            if _G._HaloPendingBlendPose and next(_G._HaloPendingBlendPose)
                and (os.clock() - (_G._HaloPendingBlendPoseTime or 0)) < 0.5 then
                pendingFrom = _G._HaloPendingBlendPose
                _G._HaloPendingBlendPose = nil
                return pendingFrom
            end
            _G._HaloPendingBlendPose = nil
            pendingFrom = capturePose(getClone())
            return pendingFrom
        end

        local function kickBlend()
            if not isReanimated() then
                pendingFrom = nil
                return
            end
            local from = pendingFrom
            pendingFrom = nil
            if not from or not next(from) then
                from = capturePose(getClone())
            end
            startCrossfade(from, blendDuration())
        end

        ----------------------------------------------------------------
        -- Hook ONLY play paths (never stop_animation / reanimate)
        ----------------------------------------------------------------
        local function tryHook()
            -- Superseded by the extracted emote/state crossfade (_PrismBlendStep).
            return true
        end

        local function tryHookPlayAnimation()
            if type(PlayAnimation) ~= "function" then return false end
            if _G._CyrisPlayAnimHooked3 then return true end
            local old = PlayAnimation
            PlayAnimation = function(animName, speed, isCustom)
                if isReanimated() then
                    stashCurrentPose()
                end
                return old(animName, speed, isCustom)
            end
            _G._CyrisPlayAnimHooked3 = true
            return true
        end

        for _ = 1, 60 do
            local a = tryHook()
            local b = tryHookPlayAnimation()
            if a and b then break end
            task.wait(0.1)
        end

        ----------------------------------------------------------------
        -- Settings UI meter
        ----------------------------------------------------------------
        local function buildMeter()
            local panel = nil
            if SettingsPanel and SettingsPanel.Parent then
                panel = SettingsPanel
            else
                local sg = nil
                pcall(function()
                    if ScreenGui and ScreenGui.Parent then sg = ScreenGui end
                end)
                if not sg then
                    local pg = lp:FindFirstChildOfClass("PlayerGui")
                    if pg then sg = pg:FindFirstChild("ReanimHaloMenu") end
                end
                if sg then
                    for _, d in ipairs(sg:GetDescendants()) do
                        if d.Name == "SettingsPanel" and d:IsA("ScrollingFrame") then
                            panel = d
                            break
                        end
                    end
                end
            end
            if not (panel and panel.Parent) then return false end
            if panel:FindFirstChild("CyrisSmoothFrame") then return true end

            local frame = Instance.new("Frame")
            frame.Name = "CyrisSmoothFrame"
            frame.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
            frame.BackgroundTransparency = 0.15
            frame.BorderSizePixel = 0
            frame.Size = UDim2.new(1, -4, 0, 72)
            frame.ZIndex = 33
            frame.LayoutOrder = -50
            frame.Parent = panel
            Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

            local title = Instance.new("TextLabel")
            title.BackgroundTransparency = 1
            title.Position = UDim2.new(0, 12, 0, 8)
            title.Size = UDim2.new(1, -24, 0, 16)
            title.Font = Enum.Font.GothamBold
            title.Text = "Emote Smoothness"
            title.TextColor3 = Color3.fromRGB(255, 255, 255)
            title.TextSize = 12
            title.TextXAlignment = Enum.TextXAlignment.Left
            title.ZIndex = 34
            title.Parent = frame

            local sub = Instance.new("TextLabel")
            sub.BackgroundTransparency = 1
            sub.Position = UDim2.new(0, 12, 0, 24)
            sub.Size = UDim2.new(1, -80, 0, 14)
            sub.Font = Enum.Font.Gotham
            sub.Text = "Blend from current emote into the next"
            sub.TextColor3 = Color3.fromRGB(150, 150, 160)
            sub.TextSize = 10
            sub.TextXAlignment = Enum.TextXAlignment.Left
            sub.ZIndex = 34
            sub.Parent = frame

            local valLbl = Instance.new("TextLabel")
            valLbl.BackgroundTransparency = 1
            valLbl.Position = UDim2.new(1, -56, 0, 8)
            valLbl.Size = UDim2.new(0, 48, 0, 16)
            valLbl.Font = Enum.Font.GothamBold
            valLbl.Text = tostring(math.floor((_G._CyrisEmoteSmoothness or DEFAULT) * 100 + 0.5)) .. "%"
            valLbl.TextColor3 = Color3.fromRGB(200, 200, 210)
            valLbl.TextSize = 11
            valLbl.TextXAlignment = Enum.TextXAlignment.Right
            valLbl.ZIndex = 34
            valLbl.Parent = frame

            local track = Instance.new("Frame")
            track.Name = "Track"
            track.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
            track.BorderSizePixel = 0
            track.Position = UDim2.new(0, 12, 0, 48)
            track.Size = UDim2.new(1, -24, 0, 8)
            track.ZIndex = 34
            track.Parent = frame
            Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

            local fill = Instance.new("Frame")
            fill.Name = "Fill"
            fill.BackgroundColor3 = Color3.fromRGB(120, 160, 255)
            fill.BorderSizePixel = 0
            fill.Size = UDim2.new(_G._CyrisEmoteSmoothness or DEFAULT, 0, 1, 0)
            fill.ZIndex = 35
            fill.Parent = track
            Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

            local handle = Instance.new("TextButton")
            handle.Name = "Handle"
            handle.Text = ""
            handle.AutoButtonColor = false
            handle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            handle.BorderSizePixel = 0
            handle.Size = UDim2.new(0, 16, 0, 16)
            handle.AnchorPoint = Vector2.new(0.5, 0.5)
            handle.Position = UDim2.new(_G._CyrisEmoteSmoothness or DEFAULT, 0, 0.5, 0)
            handle.ZIndex = 36
            handle.Parent = track
            Instance.new("UICorner", handle).CornerRadius = UDim.new(1, 0)

            local dragging = false
            local function setFromAlpha(a)
                a = math.clamp(a, 0, 1)
                _G._CyrisEmoteSmoothness = a
                fill.Size = UDim2.new(a, 0, 1, 0)
                handle.Position = UDim2.new(a, 0, 0.5, 0)
                valLbl.Text = tostring(math.floor(a * 100 + 0.5)) .. "%"
                saveSmooth(a)
            end
            local function alphaFromInput(x)
                local abs = track.AbsolutePosition.X
                local w = track.AbsoluteSize.X
                if w <= 0 then return _G._CyrisEmoteSmoothness or DEFAULT end
                return math.clamp((x - abs) / w, 0, 1)
            end

            handle.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                end
            end)
            track.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    setFromAlpha(alphaFromInput(input.Position.X))
                end
            end)
            if _G._CyrisSmoothDragConn then pcall(function() _G._CyrisSmoothDragConn:Disconnect() end) end
            _G._CyrisSmoothDragConn = UIS.InputChanged:Connect(function(input)
                if not dragging then return end
                if input.UserInputType == Enum.UserInputType.MouseMovement
                    or input.UserInputType == Enum.UserInputType.Touch then
                    setFromAlpha(alphaFromInput(input.Position.X))
                end
            end)
            if _G._CyrisSmoothEndConn then pcall(function() _G._CyrisSmoothEndConn:Disconnect() end) end
            _G._CyrisSmoothEndConn = UIS.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = false
                end
            end)
            return true
        end

        for _ = 1, 60 do
            if buildMeter() then break end
            task.wait(0.1)
        end
    end)
end)


-- ============================================================


-- ============================================================

-- CYRIS PRISM BACKGROUND (fit to menu)
-- ============================================================
task.spawn(function()
    pcall(function()
        local Players = game:GetService("Players")
        local lp = Players.LocalPlayer
        if not lp then return end

        -- wait for menu
        local sg, menu
        for _ = 1, 80 do
            pcall(function()
                if ScreenGui and ScreenGui.Parent then sg = ScreenGui end
            end)
            if not sg then
                local pg = lp:FindFirstChildOfClass("PlayerGui")
                if pg then sg = pg:FindFirstChild("ReanimHaloMenu") end
            end
            if sg then
                menu = (Menu and Menu.Parent and Menu) or sg:FindFirstChild("ReanimMenu")
                if menu then break end
            end
            task.wait(0.1)
        end
        if not menu then return end

        local B64 = [[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]]

        local function b64decode(data)
            local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
            data = data:gsub('[^'..b..'=]', '')
            return (data:gsub('.', function(x)
                if x == '=' then return '' end
                local r, f = '', (b:find(x) - 1)
                for i = 6, 1, -1 do
                    r = r .. (f % 2^i - f % 2^(i-1) > 0 and '1' or '0')
                end
                return r
            end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
                if #x ~= 8 then return '' end
                local c = 0
                for i = 1, 8 do
                    c = c + (x:sub(i, i) == '1' and 2^(8 - i) or 0)
                end
                return string.char(c)
            end))
        end

        pcall(function() makefolder("ReanimData") end)
        local path = "ReanimData/cyris_prism_bg.jpg"
        local okWrite = pcall(function()
            writefile(path, b64decode(B64))
        end)
        local asset = nil
        if okWrite then
            local get_asset = getcustomasset or getsynasset
            if type(get_asset) == "function" then
                local oka, a = pcall(get_asset, path)
                if oka then asset = a end
            end
        end
        if not asset then return end

        -- Replace / create background fitted to menu
        local old = menu:FindFirstChild("CustomBackground")
        if old then old:Destroy() end

        local bg = Instance.new("ImageLabel")
        bg.Name = "CustomBackground"
        bg.BackgroundTransparency = 1
        bg.BorderSizePixel = 0
        bg.Size = UDim2.new(1, 0, 1, 0)
        bg.Position = UDim2.new(0, 0, 0, 0)
        bg.ZIndex = 1
        bg.ScaleType = Enum.ScaleType.Crop  -- fill entire menu
        bg.ImageTransparency = 0.12
        bg.Image = asset
        bg.Parent = menu

        -- subtle dark vignette so UI text stays readable
        local vig = menu:FindFirstChild("BgVignette")
        if not vig then
            vig = Instance.new("Frame")
            vig.Name = "BgVignette"
            vig.BorderSizePixel = 0
            vig.Size = UDim2.new(1, 0, 1, 0)
            vig.ZIndex = 2
            vig.Parent = menu
            local vc = Instance.new("UICorner")
            vc.CornerRadius = UDim.new(0, 16)
            vc.Parent = vig
        end
        vig.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        vig.BackgroundTransparency = 0.55

        pcall(function()
            menu.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            menu.BackgroundTransparency = 0.35
        end)
    end)
end)


-- ============================================================
-- PRISM COOL UI: particles, glow, full Prism branding
-- ============================================================
task.spawn(function()
    pcall(function()
        local Players = game:GetService("Players")
        local RunService = game:GetService("RunService")
        local TweenService = game:GetService("TweenService")
        local lp = Players.LocalPlayer
        if not lp then return end

        local sg, menu
        for _ = 1, 80 do
            pcall(function()
                if ScreenGui and ScreenGui.Parent then sg = ScreenGui end
            end)
            if not sg then
                local pg = lp:FindFirstChildOfClass("PlayerGui")
                if pg then sg = pg:FindFirstChild("ReanimHaloMenu") end
            end
            if sg then
                menu = (Menu and Menu.Parent and Menu) or sg:FindFirstChild("ReanimMenu")
                if menu then break end
            end
            task.wait(0.1)
        end
        if not (sg and menu) then return end

        ----------------------------------------------------------------
        -- Brand everything → Prism
        ----------------------------------------------------------------
        local function rebrand(root)
            if not root then return end
            for _, d in ipairs(root:GetDescendants()) do
                if d:IsA("TextLabel") or d:IsA("TextButton") then
                    local t = d.Text
                    if type(t) ~= "string" or t == "" then continue end
                    local nt = t
                    nt = nt:gsub("Cyris Workspace", "Prism Workspace")
                    nt = nt:gsub("Cyris Shield VC", "Prism Shield VC")
                    nt = nt:gsub("Cyris", "Prism")
                    nt = nt:gsub("Halo Reanim", "Prism")
                    nt = nt:gsub("Halo", "Prism")
                    nt = nt:gsub("Reanimation", "Prism")
                    nt = nt:gsub("Best reanim out", "Prism reanim")
                    nt = nt:gsub("reanim out", "Prism")
                    if nt ~= t then d.Text = nt end
                end
            end
        end
        rebrand(sg)
        -- Title bar force
        pcall(function()
            local bar = menu:FindFirstChild("TitleBar")
            if bar then
                for _, d in ipairs(bar:GetChildren()) do
                    if d:IsA("TextLabel") then
                        d.Text = "Prism"
                        d.TextColor3 = Color3.fromRGB(220, 230, 255)
                        break
                    end
                end
            end
        end)
        -- Workspace title
        pcall(function()
            local ws = sg:FindFirstChild("CyrisWorkspace")
            if ws then
                for _, d in ipairs(ws:GetDescendants()) do
                    if d:IsA("TextLabel") and d.Text:find("Workspace") then
                        d.Text = "Prism Workspace"
                    end
                end
            end
        end)

        ----------------------------------------------------------------
        -- Cool accent colors (chrome / prism)
        ----------------------------------------------------------------
        pcall(function()
            local stroke = menu:FindFirstChildOfClass("UIStroke")
            if stroke then
                stroke.Color = Color3.fromRGB(180, 200, 255)
                stroke.Thickness = 1.8
                stroke.Transparency = 0.15
            end
        end)

        -- Animated border glow pulse
        pcall(function()
            local stroke = menu:FindFirstChildOfClass("UIStroke")
            if not stroke then return end
            if _G._PrismStrokePulse then
                pcall(function() _G._PrismStrokePulse:Disconnect() end)
            end
            local t0 = os.clock()
            stroke.Transparency = 0.2
            stroke.Color = Color3.fromRGB(190, 205, 255)
        end)

        ----------------------------------------------------------------
        -- Orbiting particles around the menu
        ----------------------------------------------------------------
        pcall(function()
            local old = menu:FindFirstChild("PrismParticles")
            if old then old:Destroy() end

            local layer = Instance.new("Frame")
            layer.Name = "PrismParticles"
            layer.BackgroundTransparency = 1
            layer.Size = UDim2.new(1, 40, 1, 40)
            layer.Position = UDim2.new(0.5, 0, 0.5, 0)
            layer.AnchorPoint = Vector2.new(0.5, 0.5)
            layer.ZIndex = 50
            layer.ClipsDescendants = false
            layer.Parent = menu

            local particles = {}
            local COUNT = 18
            for i = 1, COUNT do
                local p = Instance.new("Frame")
                p.Name = "P" .. i
                p.AnchorPoint = Vector2.new(0.5, 0.5)
                p.Size = UDim2.new(0, 3 + (i % 3), 0, 3 + (i % 3))
                p.BackgroundColor3 = Color3.fromRGB(200, 220, 255)
                p.BackgroundTransparency = 0.15
                p.BorderSizePixel = 0
                p.ZIndex = 51
                p.Parent = layer
                Instance.new("UICorner", p).CornerRadius = UDim.new(1, 0)

                -- inner shine
                local shine = Instance.new("Frame")
                shine.Size = UDim2.new(0.45, 0, 0.45, 0)
                shine.Position = UDim2.new(0.2, 0, 0.15, 0)
                shine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                shine.BackgroundTransparency = 0.35
                shine.BorderSizePixel = 0
                shine.ZIndex = 52
                shine.Parent = p
                Instance.new("UICorner", shine).CornerRadius = UDim.new(1, 0)

                table.insert(particles, {
                    gui = p,
                    angle = (i / COUNT) * math.pi * 2,
                    speed = 0.35 + (i % 5) * 0.08,
                    radiusX = 0.52 + (i % 4) * 0.03,
                    radiusY = 0.52 + ((i + 2) % 4) * 0.03,
                    phase = i * 0.7,
                })
            end

            -- a few larger “shard” sparkles
            for i = 1, 6 do
                local p = Instance.new("ImageLabel")
                p.Name = "Shard" .. i
                p.AnchorPoint = Vector2.new(0.5, 0.5)
                p.Size = UDim2.new(0, 10, 0, 10)
                p.BackgroundTransparency = 1
                p.Image = "rbxassetid://3944373221" -- soft star-ish
                p.ImageColor3 = Color3.fromRGB(210, 230, 255)
                p.ImageTransparency = 0.25
                p.ZIndex = 51
                p.Parent = layer
                table.insert(particles, {
                    gui = p,
                    angle = (i / 6) * math.pi * 2 + 0.4,
                    speed = 0.22 + i * 0.04,
                    radiusX = 0.58,
                    radiusY = 0.58,
                    phase = i * 1.3,
                    isShard = true,
                })
            end

            if _G._PrismParticleConn then
                pcall(function() _G._PrismParticleConn:Disconnect() end)
            end
            for _, pt in ipairs(particles) do
                local x = 0.5 + math.cos(pt.angle) * pt.radiusX
                local y = 0.5 + math.sin(pt.angle) * pt.radiusY
                pt.gui.Position = UDim2.new(x, 0, y, 0)
            end
        end)

        ----------------------------------------------------------------
        -- Soft top light streak / prism shine bar
        ----------------------------------------------------------------
        pcall(function()
            local old = menu:FindFirstChild("PrismShine")
            if old then old:Destroy() end
            local shine = Instance.new("Frame")
            shine.Name = "PrismShine"
            shine.BackgroundColor3 = Color3.fromRGB(200, 220, 255)
            shine.BackgroundTransparency = 0.85
            shine.BorderSizePixel = 0
            shine.Size = UDim2.new(0.55, 0, 0, 2)
            shine.Position = UDim2.new(0.22, 0, 0, 1)
            shine.ZIndex = 45
            shine.Parent = menu
            Instance.new("UICorner", shine).CornerRadius = UDim.new(1, 0)

            -- drifting shine
            if _G._PrismShineConn then pcall(function() _G._PrismShineConn:Disconnect() end) end
            shine.BackgroundTransparency = 0.82
        end)

        ----------------------------------------------------------------
        -- Workspace button label → Prism
        ----------------------------------------------------------------
        pcall(function()
            local bar = menu:FindFirstChild("TitleBar")
            if not bar then return end
            local btn = bar:FindFirstChild("CyrisWsBtn")
            if btn and btn:IsA("TextButton") then
                btn.Text = "Prism"
                btn.TextColor3 = Color3.fromRGB(210, 225, 255)
            end
        end)

        -- Notify alias branding
        pcall(function()
            if type(Notify) == "function" and not _G._PrismNotifyWrapped then
                local old = Notify
                Notify = function(msg, dur, extra)
                    if type(msg) == "string" then
                        msg = msg:gsub("Cyris", "Prism"):gsub("Halo", "Prism")
                    end
                    if type(dur) == "string" then
                        dur = dur:gsub("Cyris", "Prism"):gsub("Halo", "Prism")
                    end
                    return old(msg, dur, extra)
                end
                _G._PrismNotifyWrapped = true
            end
        end)

        -- Periodic rebrand in case UI rebuilds labels
        task.spawn(function()
            for _ = 1, 15 do
                task.wait(0.5)
                rebrand(sg)
            end
        end)
    end)
end)


-- ============================================================


-- ============================================================

-- ============================================================

-- ============================================================
-- PRISM FINAL PACK v2 — Death protection + cooler smaller VC + premium red chat
-- ============================================================

-- 0. Reanim death protection (prevents dying on activate)
task.spawn(function()
    pcall(function()
        local Players = game:GetService("Players")
        local lp = Players.LocalPlayer
        if not lp then return end

        local function protect(hum)
            if not hum then return end
            pcall(function()
                hum.BreakJointsOnDeath = false
                if hum.Health <= 0 then hum.Health = hum.MaxHealth end
                hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
                hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            end)
        end

        -- Hook reanimate so we protect both real + clone
        local function tryHook()
            local api = rawget(_G, "_HaloReanimateAPI") or ReanimateAPI
            if type(api) ~= "table" or type(api.reanimate) ~= "function" then return false end
            if api._prismDeathProtect then return true end

            local old = api.reanimate
            api.reanimate = function(bool, remote, args)
                if bool == true then
                    -- Pre-protect current character
                    local char = lp.Character
                    if char then
                        local hum = char:FindFirstChildOfClass("Humanoid")
                        protect(hum)
                    end
                end
                local result = old(bool, remote, args)
                if bool == true then
                    task.defer(function()
                        local char = lp.Character
                        if char then
                            local hum = char:FindFirstChildOfClass("Humanoid")
                            protect(hum)
                            -- Keep health full for a short window after swap
                            for i = 1, 12 do
                                task.wait(0.05)
                                if hum and hum.Parent and hum.Health < hum.MaxHealth * 0.9 then
                                    pcall(function() hum.Health = hum.MaxHealth end)
                                end
                                protect(hum)
                            end
                        end
                    end)
                end
                return result
            end
            api._prismDeathProtect = true
            return true
        end

        for _ = 1, 80 do
            if tryHook() then break end
            task.wait(0.1)
        end

        -- Also protect any existing humanoid
        if lp.Character then
            protect(lp.Character:FindFirstChildOfClass("Humanoid"))
        end
        lp.CharacterAdded:Connect(function(c)
            task.wait(0.1)
            protect(c:FindFirstChildOfClass("Humanoid"))
        end)
    end)
end)


-- ============================================================
-- PRISM ANTI-VC v3 — Premium small headshots + real volume fill + hide default mics
-- ============================================================
task.spawn(function()
    pcall(function()
        local Players = game:GetService("Players")
        local RunService = game:GetService("RunService")
        local TweenService = game:GetService("TweenService")
        local StarterGui = game:GetService("StarterGui")
        local lp = Players.LocalPlayer
        if not lp then return end

        -- Hide Roblox default voice chat icons / mic indicators
        pcall(function()
            StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true) -- keep list
        end)
        -- Continuously kill default voice indicators that float over heads
        local function hideMicGui(d)
            if not (d:IsA("BillboardGui") or d:IsA("SurfaceGui")) then return end
            if d.Name == "PrismVoiceMeter" then return end
            local n = string.lower(d.Name)
            if n:find("voice") or n:find("mic") or n:find("speaker") then
                d.Enabled = false
            end
        end
        workspace.DescendantAdded:Connect(function(d)
            task.defer(function()
                pcall(hideMicGui, d)
            end)
        end)

        if _G._PrismShield == nil then
            _G._PrismShield = { enabled = false, indicators = {}, conns = {}, muted = {} }
        end
        local S = _G._PrismShield

        local SIZE = 28
        local RED = Color3.fromRGB(255, 20, 45)
        local RED_HOT = Color3.fromRGB(255, 0, 40)
        local RED_NEON = Color3.fromRGB(255, 60, 90)
        local MAGENTA = Color3.fromRGB(255, 40, 120)
        local WHITE = Color3.fromRGB(255, 240, 245)
        local BLACK = Color3.fromRGB(2, 0, 1)

        local function disconnectAll()
            for _, c in pairs(S.conns) do pcall(function() c:Disconnect() end) end
            S.conns = {}
            if S.meterConn then pcall(function() S.meterConn:Disconnect() end) S.meterConn = nil end
        end

        local function destroyIndicators()
            for _, g in pairs(S.indicators) do
                if type(g) == "table" and g.bill then
                    pcall(function() g.bill:Destroy() end)
                else
                    pcall(function() g:Destroy() end)
                end
            end
            S.indicators = {}
        end

        local function estimateVoiceLevel(player)
            if S.muted[player.UserId] then return 0 end
            local level = 0
            local char = player.Character
            if char then
                for _, d in ipairs(char:GetDescendants()) do
                    if d:IsA("Sound") and d.IsPlaying then
                        local loud = 0
                        pcall(function() loud = d.PlaybackLoudness end)
                        if loud > 0 then
                            level = math.max(level, math.clamp(loud / 260, 0, 1))
                        end
                    end
                end
            end
            pcall(function()
                local st = player:GetAttribute("VoiceChatState")
                    or player:GetAttribute("VCSpeaking")
                    or player:GetAttribute("IsSpeaking")
                    or player:GetAttribute("Talking")
                if st == true or st == "Talking" or st == 1 or st == "Speaking" then
                    level = math.max(level, 0.55 + 0.4 * math.abs(math.sin(os.clock() * 16)))
                end
            end)
            return level
        end

        local function makeIndicator(player)
            if player == lp then return end
            if S.indicators[player.UserId] then return end

            local bill = Instance.new("BillboardGui")
            bill.Name = "PrismVoiceMeter"
            bill.Size = UDim2.fromOffset(96, 96)
            bill.StudsOffset = Vector3.new(0, 2.85, 0)
            bill.AlwaysOnTop = true
            bill.Active = true
            bill.MaxDistance = 120
            bill.ResetOnSpawn = false
            bill.Enabled = true

            local root = Instance.new("Frame")
            root.BackgroundTransparency = 1
            root.Size = UDim2.fromScale(1, 1)
            root.Parent = bill

            -- ===== BLOOM (huge soft red under everything) =====
            local bloom = Instance.new("Frame")
            bloom.Name = "Bloom"
            bloom.AnchorPoint = Vector2.new(0.5, 0.5)
            bloom.Position = UDim2.fromScale(0.5, 0.5)
            bloom.Size = UDim2.fromOffset(58, 58)
            bloom.BackgroundColor3 = RED_HOT
            bloom.BackgroundTransparency = 1
            bloom.ZIndex = 1
            bloom.Parent = root
            Instance.new("UICorner", bloom).CornerRadius = UDim.new(1, 0)

            -- ===== AURA =====
            local aura = Instance.new("Frame")
            aura.Name = "Aura"
            aura.AnchorPoint = Vector2.new(0.5, 0.5)
            aura.Position = UDim2.fromScale(0.5, 0.5)
            aura.Size = UDim2.fromOffset(46, 46)
            aura.BackgroundColor3 = RED
            aura.BackgroundTransparency = 1
            aura.ZIndex = 2
            aura.Parent = root
            Instance.new("UICorner", aura).CornerRadius = UDim.new(1, 0)

            -- ===== PULSE RING (expands on speak then fades) =====
            local pulseRing = Instance.new("Frame")
            pulseRing.Name = "PulseRing"
            pulseRing.AnchorPoint = Vector2.new(0.5, 0.5)
            pulseRing.Position = UDim2.fromScale(0.5, 0.5)
            pulseRing.Size = UDim2.fromOffset(SIZE + 4, SIZE + 4)
            pulseRing.BackgroundTransparency = 1
            pulseRing.ZIndex = 3
            pulseRing.Parent = root
            local pulseStroke = Instance.new("UIStroke")
            pulseStroke.Color = RED_NEON
            pulseStroke.Thickness = 2
            pulseStroke.Transparency = 1
            pulseStroke.Parent = pulseRing
            Instance.new("UICorner", pulseRing).CornerRadius = UDim.new(1, 0)

            -- ===== OUTER ORBIT RING =====
            local outer = Instance.new("Frame")
            outer.Name = "Outer"
            outer.AnchorPoint = Vector2.new(0.5, 0.5)
            outer.Position = UDim2.fromScale(0.5, 0.5)
            outer.Size = UDim2.fromOffset(SIZE + 10, SIZE + 10)
            outer.BackgroundTransparency = 1
            outer.ZIndex = 4
            outer.Parent = root
            local outerStroke = Instance.new("UIStroke")
            outerStroke.Color = RED
            outerStroke.Thickness = 1.5
            outerStroke.Transparency = 0.4
            outerStroke.Parent = outer
            Instance.new("UICorner", outer).CornerRadius = UDim.new(1, 0)

            -- ===== MAIN RING =====
            local ring = Instance.new("Frame")
            ring.Name = "Ring"
            ring.AnchorPoint = Vector2.new(0.5, 0.5)
            ring.Position = UDim2.fromScale(0.5, 0.5)
            ring.Size = UDim2.fromOffset(SIZE + 3, SIZE + 3)
            ring.BackgroundTransparency = 1
            ring.ZIndex = 5
            ring.Parent = root
            local ringStroke = Instance.new("UIStroke")
            ringStroke.Color = RED
            ringStroke.Thickness = 2.8
            ringStroke.Transparency = 0
            ringStroke.Parent = ring
            local ringGrad = Instance.new("UIGradient")
            ringGrad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 30, 60)),
                ColorSequenceKeypoint.new(0.7, Color3.fromRGB(120, 0, 30)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 180, 190)),
            })
            ringGrad.Parent = ringStroke
            Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)

            -- ===== INNER HIGHLIGHT =====
            local inner = Instance.new("Frame")
            inner.Name = "Inner"
            inner.AnchorPoint = Vector2.new(0.5, 0.5)
            inner.Position = UDim2.fromScale(0.5, 0.5)
            inner.Size = UDim2.fromOffset(SIZE - 1, SIZE - 1)
            inner.BackgroundTransparency = 1
            inner.ZIndex = 6
            inner.Parent = root
            local innerStroke = Instance.new("UIStroke")
            innerStroke.Color = WHITE
            innerStroke.Thickness = 1
            innerStroke.Transparency = 0.55
            innerStroke.Parent = inner
            Instance.new("UICorner", inner).CornerRadius = UDim.new(1, 0)

            -- ===== CIRCULAR CLIP (headshot + volume meter live inside this) =====
            local mask = Instance.new("Frame")
            mask.Name = "Mask"
            mask.AnchorPoint = Vector2.new(0.5, 0.5)
            mask.Position = UDim2.fromScale(0.5, 0.5)
            mask.Size = UDim2.fromOffset(SIZE, SIZE)
            mask.BackgroundColor3 = BLACK
            mask.BackgroundTransparency = 0
            mask.BorderSizePixel = 0
            mask.ClipsDescendants = true
            mask.ZIndex = 7
            mask.Parent = root
            Instance.new("UICorner", mask).CornerRadius = UDim.new(1, 0)
            local headStroke = Instance.new("UIStroke")
            headStroke.Color = RED
            headStroke.Thickness = 1.6
            headStroke.Parent = mask

            -- ===== HEADSHOT =====
            local head = Instance.new("ImageLabel")
            head.Name = "Head"
            head.Size = UDim2.fromScale(1, 1)
            head.BackgroundTransparency = 1
            head.BorderSizePixel = 0
            head.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(player.UserId) .. "&w=150&h=150"
            head.ScaleType = Enum.ScaleType.Crop
            head.ZIndex = 7
            head.Parent = mask
            Instance.new("UICorner", head).CornerRadius = UDim.new(1, 0)

            -- ===== VOLUME METER (rises from the bottom, clipped to the circle) =====
            local fill = Instance.new("Frame")
            fill.Name = "VolumeFill"
            fill.AnchorPoint = Vector2.new(0.5, 1)
            fill.Position = UDim2.fromScale(0.5, 1)
            fill.Size = UDim2.fromScale(1, 0) -- Y scale = 0..1 volume
            fill.BackgroundColor3 = RED
            fill.BackgroundTransparency = 0.18
            fill.BorderSizePixel = 0
            fill.ZIndex = 8
            fill.Parent = mask
            local fillGrad = Instance.new("UIGradient")
            fillGrad.Rotation = 90
            fillGrad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 90)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 8, 28)),
            })
            fillGrad.Parent = fill

            -- full red wash overlay (kept very light so the meter stays visible)
            local overlay = Instance.new("Frame")
            overlay.Size = UDim2.fromScale(1, 1)
            overlay.BackgroundColor3 = RED
            overlay.BackgroundTransparency = 1
            overlay.BorderSizePixel = 0
            overlay.ZIndex = 9
            overlay.Parent = mask
            Instance.new("UICorner", overlay).CornerRadius = UDim.new(1, 0)

            -- white-hot scream flash
            local hot = Instance.new("Frame")
            hot.Size = UDim2.fromScale(1, 1)
            hot.BackgroundColor3 = WHITE
            hot.BackgroundTransparency = 1
            hot.BorderSizePixel = 0
            hot.ZIndex = 10
            hot.Parent = mask
            Instance.new("UICorner", hot).CornerRadius = UDim.new(1, 0)


            -- ===== ORBIT DOTS (2 red diamonds that spin around) =====
            local function makeDot(name, z)
                local d = Instance.new("Frame")
                d.Name = name
                d.AnchorPoint = Vector2.new(0.5, 0.5)
                d.Size = UDim2.fromOffset(5, 5)
                d.BackgroundColor3 = RED_NEON
                d.BorderSizePixel = 0
                d.ZIndex = z
                d.Parent = root
                Instance.new("UICorner", d).CornerRadius = UDim.new(1, 0)
                local ds = Instance.new("UIStroke")
                ds.Color = WHITE
                ds.Thickness = 0.8
                ds.Transparency = 0.3
                ds.Parent = d
                return d
            end
            local dot1 = makeDot("Dot1", 11)
            local dot2 = makeDot("Dot2", 11)
            local dot3 = makeDot("Dot3", 11)
            dot3.Size = UDim2.fromOffset(3, 3)
            dot3.BackgroundColor3 = MAGENTA

            local sparks = {}
            for i = 1, 14 do
                local s = Instance.new("Frame")
                s.Name = "Spark"..i
                s.AnchorPoint = Vector2.new(0.5, 0.5)
                s.Size = UDim2.fromOffset(i % 2 == 0 and 3 or 2, i % 3 == 0 and 10 or 5)
                s.BackgroundColor3 = i % 3 == 0 and MAGENTA or RED_NEON
                s.BorderSizePixel = 0
                s.BackgroundTransparency = 0.15
                s.ZIndex = 12
                s.Parent = root
                Instance.new("UICorner", s).CornerRadius = UDim.new(1, 0)
                sparks[i] = s
            end

            -- dashed halo ticks, second orbit
            local ticks = {}
            for i = 1, 16 do
                local tk = Instance.new("Frame")
                tk.Name = "Tick"..i
                tk.AnchorPoint = Vector2.new(0.5, 0.5)
                tk.Size = UDim2.fromOffset(2, 7)
                tk.BackgroundColor3 = WHITE
                tk.BackgroundTransparency = 0.25
                tk.BorderSizePixel = 0
                tk.ZIndex = 6
                tk.Parent = root
                Instance.new("UICorner", tk).CornerRadius = UDim.new(1, 0)
                ticks[i] = tk
            end

            -- shockwave twin
            local shock = Instance.new("Frame")
            shock.Name = "Shock"
            shock.AnchorPoint = Vector2.new(0.5, 0.5)
            shock.Position = UDim2.fromScale(0.5, 0.5)
            shock.Size = UDim2.fromOffset(SIZE + 8, SIZE + 8)
            shock.BackgroundTransparency = 1
            shock.ZIndex = 3
            shock.Parent = root
            local shockStroke = Instance.new("UIStroke")
            shockStroke.Color = Color3.fromRGB(255, 210, 220)
            shockStroke.Thickness = 1.4
            shockStroke.Transparency = 1
            shockStroke.Parent = shock
            Instance.new("UICorner", shock).CornerRadius = UDim.new(1, 0)

            local nameTag = Instance.new("TextLabel")
            nameTag.Name = "Name"
            nameTag.AnchorPoint = Vector2.new(0.5, 0)
            nameTag.Position = UDim2.fromScale(0.5, 1.02)
            nameTag.Size = UDim2.fromOffset(90, 14)
            nameTag.BackgroundTransparency = 1
            nameTag.Font = Enum.Font.GothamBold
            nameTag.TextSize = 10
            nameTag.TextColor3 = Color3.fromRGB(255, 220, 225)
            nameTag.TextStrokeTransparency = 0.4
            nameTag.Text = player.DisplayName
            nameTag.ZIndex = 20
            nameTag.Parent = root

            local volLbl = Instance.new("TextLabel")
            volLbl.Name = "Vol"
            volLbl.AnchorPoint = Vector2.new(0.5, 0)
            volLbl.Position = UDim2.fromScale(0.5, 1)
            volLbl.Size = UDim2.fromOffset(46, 12)
            volLbl.BackgroundTransparency = 1
            volLbl.Text = ""
            volLbl.TextColor3 = RED_NEON
            volLbl.TextStrokeTransparency = 0.4
            volLbl.TextStrokeColor3 = Color3.fromRGB(40, 0, 0)
            volLbl.Font = Enum.Font.GothamBold
            volLbl.TextSize = 9
            volLbl.ZIndex = 15
            volLbl.Parent = root

            -- mute icon
            local muteIcon = Instance.new("TextLabel")
            muteIcon.Size = UDim2.fromScale(1, 1)
            muteIcon.BackgroundTransparency = 1
            muteIcon.Text = "✕"
            muteIcon.TextColor3 = Color3.fromRGB(255, 80, 90)
            muteIcon.Font = Enum.Font.GothamBold
            muteIcon.TextScaled = true
            muteIcon.Visible = false
            muteIcon.ZIndex = 14
            muteIcon.Parent = mask

            -- click mute (whole circle)
            local btn = Instance.new("TextButton")
            btn.Name = "MuteHit"
            btn.Size = UDim2.fromScale(1, 1)
            btn.BackgroundTransparency = 1
            btn.Text = ""
            btn.AutoButtonColor = false
            btn.Active = true
            btn.ZIndex = 30
            btn.Parent = root
            local function applyMute(muted)
                S.muted[player.UserId] = muted
                muteIcon.Visible = muted
                if muted then
                    ringStroke.Color = Color3.fromRGB(70, 70, 75)
                    outerStroke.Color = Color3.fromRGB(55, 55, 60)
                    headStroke.Color = Color3.fromRGB(70, 70, 75)
                    head.ImageColor3 = Color3.fromRGB(100, 100, 110)
                    dot1.Visible = false
                    dot2.Visible = false
                    dot3.Visible = false
                else
                    ringStroke.Color = RED
                    outerStroke.Color = RED
                    headStroke.Color = RED
                    head.ImageColor3 = Color3.fromRGB(255, 255, 255)
                    dot1.Visible = true
                    dot2.Visible = true
                    dot3.Visible = true
                end
                local char = player.Character
                pcall(function()
                    local vci = game:GetService("VoiceChatInternal")
                    if vci.SetPlayerMuted then vci:SetPlayerMuted(player.UserId, muted) end
                end)
                pcall(function()
                    local vci = game:GetService("VoiceChatInternal")
                    if vci.SubscribePause then vci:SubscribePause(player.UserId, muted) end
                end)
                pcall(function()
                    local vci = game:GetService("VoiceChatInternal")
                    if vci.MuteUser then vci:MuteUser(player.UserId, muted) end
                end)
                if char then
                    for _, d in ipairs(char:GetDescendants()) do
                        pcall(function()
                            if d:IsA("AudioDeviceInput") then
                                if muted then
                                    if d:GetAttribute("PrismPrevMuted") == nil then
                                        d:SetAttribute("PrismPrevMuted", d.Muted)
                                    end
                                    d.Muted = true
                                else
                                    local prev = d:GetAttribute("PrismPrevMuted")
                                    if prev ~= nil then d.Muted = prev == true end
                                    d:SetAttribute("PrismPrevMuted", nil)
                                end
                            elseif d:IsA("Wire") then
                                if muted then
                                    if d:GetAttribute("PrismPrevWire") == nil then
                                        d:SetAttribute("PrismPrevWire", d.Enabled)
                                    end
                                    d.Enabled = false
                                else
                                    local prev = d:GetAttribute("PrismPrevWire")
                                    if prev ~= nil then d.Enabled = prev == true end
                                    d:SetAttribute("PrismPrevWire", nil)
                                end
                            elseif d:IsA("Sound") or d:IsA("AudioPlayer") then
                                if muted then
                                    if d:GetAttribute("PrismPrevVol") == nil then
                                        d:SetAttribute("PrismPrevVol", d.Volume)
                                    end
                                    d.Volume = 0
                                else
                                    local prev = d:GetAttribute("PrismPrevVol")
                                    if type(prev) == "number" then d.Volume = prev end
                                    d:SetAttribute("PrismPrevVol", nil)
                                end
                            end
                        end)
                    end
                end
            end
            local function toggleMute()
                applyMute(not S.muted[player.UserId])
            end
            btn.MouseButton1Click:Connect(toggleMute)
            btn.Activated:Connect(toggleMute)
            S.muteFns = S.muteFns or {}
            S.muteFns[player.UserId] = toggleMute

            local function attach()
                local char = player.Character
                if not char then return end
                local headPart = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
                if headPart then
                    bill.Adornee = headPart
                    local pg = lp:FindFirstChildOfClass("PlayerGui")
                    bill.Parent = pg or headPart
                end
            end
            attach()
            table.insert(S.conns, player.CharacterAdded:Connect(function()
                task.wait(0.4)
                attach()
            end))

            S.indicators[player.UserId] = {
                bill = bill,
                bloom = bloom,
                aura = aura,
                pulseRing = pulseRing,
                pulseStroke = pulseStroke,
                outerStroke = outerStroke,
                ringStroke = ringStroke,
                overlay = overlay,
                hot = hot,
                fill = fill,
                muteIcon = muteIcon,
                head = head,
                dot1 = dot1,
                dot2 = dot2,
                dot3 = dot3,
                sparks = sparks,
                ticks = ticks,
                shock = shock,
                shockStroke = shockStroke,
                ringGrad = ringGrad,
                nameTag = nameTag,
                volLbl = volLbl,
                angle = math.random() * math.pi * 2,
                pulseT = 0,
            }
        end

        local function startMeterLoop()
            if S.meterConn then pcall(function() S.meterConn:Disconnect() end) end
            if not S.clickConn then
                local UIS = game:GetService("UserInputService")
                S.clickConn = UIS.InputBegan:Connect(function(input, gp)
                    if gp or not S.enabled then return end
                    if input.UserInputType ~= Enum.UserInputType.MouseButton1
                        and input.UserInputType ~= Enum.UserInputType.Touch then
                        return
                    end
                    local cam = workspace.CurrentCamera
                    if not cam then return end
                    local pos = input.Position
                    local ray = cam:ViewportPointToRay(pos.X, pos.Y)
                    local dir = ray.Direction.Unit
                    local best, bestD = nil, 2.4
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p ~= lp and S.muteFns and S.muteFns[p.UserId] then
                            local ch = p.Character
                            local hd = ch and (ch:FindFirstChild("Head") or ch:FindFirstChild("HumanoidRootPart"))
                            if hd then
                                local toP = hd.Position - ray.Origin
                                local proj = dir:Dot(toP)
                                if proj > 0 then
                                    local miss = (ray.Origin + dir * proj - hd.Position).Magnitude
                                    if miss < bestD then
                                        bestD = miss
                                        best = p
                                    end
                                end
                            end
                        end
                    end
                    if best and S.muteFns[best.UserId] then
                        S.muteFns[best.UserId]()
                    end
                end)
                table.insert(S.conns, S.clickConn)
            end
            S.meterConn = RunService.Heartbeat:Connect(function(dt)
                if not S.enabled then return end
                S._step = (S._step or 0) + 1
                if S._step % 2 ~= 0 then return end
                local t = os.clock()
                for _, p in ipairs(Players:GetPlayers()) do
                    if p == lp then continue end
                    local data = S.indicators[p.UserId]
                    if not data then
                        makeIndicator(p)
                        data = S.indicators[p.UserId]
                    end
                    if not data then continue end

                    if S.muted[p.UserId] then
                        data.overlay.BackgroundTransparency = 0.5
                        data.hot.BackgroundTransparency = 1
                        data.fill.Size = UDim2.fromScale(1, 0)
                        data.bloom.BackgroundTransparency = 1
                        data.aura.BackgroundTransparency = 1
                        data.pulseStroke.Transparency = 1
                        local ch = p.Character
                        local nowMute = os.clock()
                        if ch and nowMute - (data._muteAt or 0) > 0.75 then
                            data._muteAt = nowMute
                            for _, d in ipairs(ch:GetDescendants()) do
                                pcall(function()
                                    if d:IsA("AudioDeviceInput") then d.Muted = true
                                    elseif d:IsA("Wire") then d.Enabled = false
                                    elseif (d:IsA("Sound") or d:IsA("AudioPlayer")) and d.Volume > 0 then d.Volume = 0
                                    end
                                end)
                            end
                        end
                        if data.sparks then
                            for _, s in ipairs(data.sparks) do s.BackgroundTransparency = 1 end
                        end
                        if data.ticks then
                            for _, tk in ipairs(data.ticks) do tk.BackgroundTransparency = 1 end
                        end
                        if data.shockStroke then data.shockStroke.Transparency = 1 end
                        if data.volLbl then data.volLbl.Text = "" end
                        continue
                    end

                    local lvl = estimateVoiceLevel(p)

                    -- volume meter rises INSIDE the circle (0 = empty, 1 = full)
                    local targetH = math.clamp(lvl, 0, 1)
                    local curH = data.fill.Size.Y.Scale
                    local newH = curH + (targetH - curH) * 0.42
                    data.fill.Size = UDim2.fromScale(1, newH)
                    data.fill.BackgroundTransparency = 0.12 + (1 - newH) * 0.18

                    -- overlay wash kept light so the rising meter stays the main visual
                    local targetTrans = 1 - math.clamp(lvl * 0.35, 0, 0.22)
                    data.overlay.BackgroundTransparency = data.overlay.BackgroundTransparency
                        + (targetTrans - data.overlay.BackgroundTransparency) * 0.35

                    -- scream flash
                    local hotTarget = 1 - math.clamp((lvl - 0.58) * 2.5, 0, 0.6)
                    data.hot.BackgroundTransparency = data.hot.BackgroundTransparency
                        + (hotTarget - data.hot.BackgroundTransparency) * 0.35

                    -- orbit dots spin faster when talking
                    local spinSpeed = 1.4 + lvl * 6
                    data.angle = (data.angle or 0) + dt * spinSpeed
                    local r = (SIZE + 10) / 2
                    local cx, cy = 48, 48
                    local a1 = data.angle
                    local a2 = data.angle + (math.pi * 2 / 3)
                    local a3 = data.angle + (math.pi * 4 / 3)
                    data.dot1.Position = UDim2.fromOffset(cx + math.cos(a1) * r, cy + math.sin(a1) * r)
                    data.dot2.Position = UDim2.fromOffset(cx + math.cos(a2) * r, cy + math.sin(a2) * r)
                    data.dot3.Position = UDim2.fromOffset(cx + math.cos(a3) * (r * 0.85), cy + math.sin(a3) * (r * 0.85))

                    -- counter-rotating sparks + volume number
                    if data.sparks then
                        local sr = r + 10 + lvl * 14
                        for i, s in ipairs(data.sparks) do
                            local sa = -data.angle * 2.1 + (i / #data.sparks) * math.pi * 2
                            local wob = math.sin(t * 18 + i * 0.7) * (2 + lvl * 7)
                            s.Position = UDim2.fromOffset(cx + math.cos(sa) * (sr + wob), cy + math.sin(sa) * (sr + wob))
                            s.Rotation = math.deg(sa) + 90
                            s.BackgroundTransparency = lvl > 0.04 and (0.02 + (1 - lvl) * 0.4) or 0.82
                            s.BackgroundColor3 = Color3.fromRGB(255, 20 + lvl * 180, 40 + (i % 4) * 40)
                            local len = 4 + lvl * 12
                            s.Size = UDim2.fromOffset(2, len)
                        end
                    end
                    if data.ticks then
                        local tr = r + 2
                        for i, tk in ipairs(data.ticks) do
                            local ta = data.angle * 0.85 + (i / #data.ticks) * math.pi * 2
                            tk.Position = UDim2.fromOffset(cx + math.cos(ta) * tr, cy + math.sin(ta) * tr)
                            tk.Rotation = math.deg(ta) + 90
                            tk.BackgroundTransparency = 0.15 + (1 - lvl) * 0.45
                            tk.BackgroundColor3 = (i % 2 == 0) and WHITE or RED_NEON
                        end
                    end
                    if data.ringGrad then
                        data.ringGrad.Rotation = (t * (70 + lvl * 220)) % 360
                    end
                    if data.ringStroke then
                        data.ringStroke.Thickness = 2.2 + lvl * 3.4
                    end
                    if data.shock and data.shockStroke then
                        local phase = (t * (0.8 + lvl * 2.2)) % 1
                        local ss = SIZE + 6 + phase * (18 + lvl * 28)
                        data.shock.Size = UDim2.fromOffset(ss, ss)
                        data.shockStroke.Transparency = 0.15 + phase * 0.85
                        data.shockStroke.Thickness = 2.2 - phase * 1.4
                        data.shockStroke.Color = Color3.fromRGB(255, 180 - phase * 80, 190)
                    end
                    if data.volLbl then
                        if lvl > 0.04 then
                            data.volLbl.Text = tostring(math.floor(lvl * 100 + 0.5))
                            data.volLbl.TextTransparency = 0.05
                        else
                            data.volLbl.Text = ""
                        end
                    end

                    if lvl > 0.03 then
                        local pulse = 0.5 + 0.5 * math.sin(t * 20 + p.UserId * 0.05)
                        local pulse2 = 0.5 + 0.5 * math.sin(t * 12)

                        data.bloom.BackgroundTransparency = 0.78 - lvl * 0.42
                        data.aura.BackgroundTransparency = 0.55 - lvl * 0.5

                        data.ringStroke.Thickness = 2.6 + lvl * 4.2 + pulse * 0.9 * lvl
                        data.ringStroke.Color = Color3.fromRGB(255, 15 + lvl * 70, 35 + pulse * 50)
                        data.outerStroke.Thickness = 1.3 + lvl * 2.2
                        data.outerStroke.Transparency = 0.35 - lvl * 0.28
                        data.outerStroke.Color = Color3.fromRGB(255, 30 + pulse2 * 60, 70)

                        local sc = 1 + lvl * 0.45 + pulse * 0.08 * lvl
                        data.aura.Size = UDim2.fromOffset(46 * sc, 46 * sc)
                        data.bloom.Size = UDim2.fromOffset(58 * (1 + lvl * 0.3), 58 * (1 + lvl * 0.3))

                        -- expanding pulse ring on speak peaks
                        data.pulseT = (data.pulseT or 0) + dt
                        if data.pulseT > 0.45 then data.pulseT = 0 end
                        local pt = data.pulseT / 0.45
                        local pr = SIZE + 4 + pt * 22 * (0.5 + lvl)
                        data.pulseRing.Size = UDim2.fromOffset(pr, pr)
                        data.pulseStroke.Transparency = 0.2 + pt * 0.8
                        data.pulseStroke.Thickness = 2.2 - pt * 1.2
                        data.pulseStroke.Color = Color3.fromRGB(255, 40 + lvl * 80, 80)

                        -- dots brighter when loud
                        data.dot1.BackgroundColor3 = Color3.fromRGB(255, 80 + lvl * 100, 100)
                        data.dot2.BackgroundColor3 = Color3.fromRGB(255, 60 + lvl * 80, 120)
                    else
                        data.bloom.BackgroundTransparency = math.min(1, data.bloom.BackgroundTransparency + 0.08)
                        data.aura.BackgroundTransparency = math.min(1, data.aura.BackgroundTransparency + 0.08)
                        data.ringStroke.Thickness = 2.8
                        data.ringStroke.Color = RED
                        data.outerStroke.Thickness = 1.5
                        data.outerStroke.Transparency = 0.4
                        data.outerStroke.Color = RED
                        data.aura.Size = UDim2.fromOffset(46, 46)
                        data.bloom.Size = UDim2.fromOffset(58, 58)
                        data.pulseStroke.Transparency = math.min(1, data.pulseStroke.Transparency + 0.15)
                        data.dot1.BackgroundColor3 = RED_NEON
                        data.dot2.BackgroundColor3 = RED_NEON
                    end
                end
            end)
            table.insert(S.conns, S.meterConn)
        end

        -- Save the REAL technical VC bypass (stay in voice / anti VC-ban)
        -- before we wire the menu button to our combined enable.
        local _realApplyVCBypass = applyVCBypass
        local _realCleanupVCBypass = cleanupVCBypass
        local _techVCOn = false
        local _voiceKeepAliveConn = nil

        local function stopVoiceKeepAlive()
            if _voiceKeepAliveConn then
                pcall(function() _voiceKeepAliveConn:Disconnect() end)
                _voiceKeepAliveConn = nil
            end
        end

        -- Strong keep-alive: if Roblox drops us from voice after reanim / char swap,
        -- automatically re-join so we don't stay VC-banned / disconnected.
        local function startVoiceKeepAlive()
            -- Do not call joinVoice/leaveVoice on a loop. That resets the
            -- voice session and you stop hearing other people.
            stopVoiceKeepAlive()
        end

        local function enableTechVC()
            if _techVCOn then return end
            _techVCOn = true

            -- MAIN anti-VC: Shield loader (technical protection).
            -- Their headshot indicators get stripped below; ours stay.
            task.spawn(function()
                local ok = pcall(function()
                    loadstring(game:HttpGet("https://shield.xao.wtf/api/loader/550af30c-aaa3-4338-acab-f44010a5ef09"))()
                end)
                if not ok then
                    if type(_realApplyVCBypass) == "function" and _realApplyVCBypass ~= enableShield then
                        pcall(_realApplyVCBypass)
                    end
                end
            end)

            -- Kill Shield / default voice indicators. Never touch our meter or chat bubbles.
            local function hasAudio(gui)
                for _, d in ipairs(gui:GetDescendants()) do
                    if d:IsA("Sound") or d:IsA("AudioPlayer") or d:IsA("AudioEmitter")
                        or d:IsA("AudioDeviceInput") or d:IsA("AudioDeviceOutput") or d:IsA("Wire") then
                        return true
                    end
                end
                return false
            end
            local function isForeignVoiceGui(gui)
                if not gui or not gui:IsA("BillboardGui") then return false end
                if gui.Name == "PrismVoiceMeter" then return false end
                if hasAudio(gui) then return false end
                local n = string.lower(gui.Name or "")
                if n:find("chat") or n:find("bubble") then return false end
                if n:find("voice") or n:find("mic") or n:find("speaker") or n:find("shield")
                    or n:find("indicator") or n:find("headshot") then
                    return true
                end
                local parent = gui.Parent
                if parent and parent:IsA("BasePart") and parent.Name == "Head" then
                    for _, d in ipairs(gui:GetDescendants()) do
                        if d:IsA("ImageLabel") and type(d.Image) == "string" and d.Image:find("AvatarHeadShot") then
                            return true
                        end
                    end
                end
                return false
            end
            local function restoreHearing()
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= lp and not S.muted[p.UserId] then
                        local char = p.Character
                        if char then
                            for _, d in ipairs(char:GetDescendants()) do
                                pcall(function()
                                    if d:IsA("AudioDeviceInput") then d.Muted = false end
                                    if d:IsA("Wire") then d.Enabled = true end
                                end)
                            end
                        end
                    end
                end
            end
            local function sweep()
                pcall(function()
                    for _, p in ipairs(Players:GetPlayers()) do
                        local char = p.Character
                        if char then
                            for _, d in ipairs(char:GetDescendants()) do
                                if isForeignVoiceGui(d) then
                                    pcall(function() d:Destroy() end)
                                end
                            end
                        end
                    end
                end)
            end
            task.spawn(function()
                for _ = 1, 8 do
                    if not S.enabled then return end
                    sweep()
                    restoreHearing()
                    task.wait(0.5)
                end
            end)
            table.insert(S.conns, workspace.DescendantAdded:Connect(function(inst)
                if not S.enabled then return end
                task.defer(function()
                    if isForeignVoiceGui(inst) then
                        pcall(function() inst:Destroy() end)
                    end
                end)
            end))

            startVoiceKeepAlive()
            local lastHear = 0
            table.insert(S.conns, RunService.Heartbeat:Connect(function()
                if not S.enabled then return end
                local now = os.clock()
                if now - lastHear < 2 then return end
                lastHear = now
                restoreHearing()
            end))
            table.insert(S.conns, lp.CharacterAdded:Connect(function()
                task.delay(1.2, function()
                    if not S.enabled then return end
                    pcall(function()
                        local vcs = (cloneref or function(x) return x end)(game:GetService("VoiceChatService"))
                        vcs:joinVoice()
                    end)
                end)
            end))
        end

        local function disableTechVC()
            stopVoiceKeepAlive()
            if not _techVCOn then return end
            _techVCOn = false
            if type(_realCleanupVCBypass) == "function" and _realCleanupVCBypass ~= disableShield then
                pcall(_realCleanupVCBypass)
            else
                pcall(function()
                    local vcs = (cloneref or function(x) return x end)(game:GetService("VoiceChatService"))
                    pcall(function() vcs:leaveVoice() end)
                    task.wait(0.3)
                    pcall(function() vcs:joinVoice() end)
                end)
            end
        end

        local function enableShield()
            if S.enabled then return end
            S.enabled = true
            -- Shield anti-VC + our circles, one toggle named VC Bypass
            enableTechVC()
            for _, p in ipairs(Players:GetPlayers()) do makeIndicator(p) end
            startMeterLoop()
            table.insert(S.conns, Players.PlayerAdded:Connect(function(p)
                if S.enabled then task.wait(0.3) makeIndicator(p) end
            end))
            table.insert(S.conns, Players.PlayerRemoving:Connect(function(p)
                local d = S.indicators[p.UserId]
                if d and d.bill then pcall(function() d.bill:Destroy() end) end
                S.indicators[p.UserId] = nil
                S.muted[p.UserId] = nil
            end))
            pcall(function() if Notify then Notify("VC Bypass", "ON", 2) end end)
        end

        local function disableShield()
            S.enabled = false
            disableTechVC()
            disconnectAll()
            destroyIndicators()
            S.muted = {}
            pcall(function() if Notify then Notify("VC Bypass", "OFF", 2) end end)
        end

        _G._PrismEnableShieldVC = enableShield
        _G._PrismDisableShieldVC = disableShield
        -- Menu / settings still call these names — now they do BOTH tech + visuals
        applyVCBypass = enableShield
        cleanupVCBypass = disableShield


        -- Rewire menu button
        local function rewire()
            local sg
            pcall(function() if ScreenGui and ScreenGui.Parent then sg = ScreenGui end end)
            if not sg then
                local pg = lp:FindFirstChildOfClass("PlayerGui")
                if pg then sg = pg:FindFirstChild("ReanimHaloMenu") end
            end
            if not sg then return false end
            local panel
            for _, d in ipairs(sg:GetDescendants()) do
                if d.Name == "SettingsPanel" then panel = d break end
            end
            if not panel then return false end

            local vcFrame, titleLbl
            for _, d in ipairs(panel:GetDescendants()) do
                if d:IsA("TextLabel") then
                    local t = d.Text or ""
                    if t == "VC Bypass" or t:find("Shield") or (t:find("VC") and (t:find("Prism") or t:find("Bypass"))) then
                        titleLbl = d
                        vcFrame = d.Parent
                    end
                end
            end
            if not vcFrame then return false end
            if titleLbl then titleLbl.Text = "VC Bypass" end
            local subLbl, vcBtn
            for _, d in ipairs(vcFrame:GetDescendants()) do
                if d:IsA("TextLabel") and d ~= titleLbl then subLbl = d
                elseif d:IsA("TextButton") then vcBtn = d end
            end
            if subLbl then
                subLbl.Text = "Shield anti-VC + red circles. Their indicators get removed."
            end
            if vcBtn then
                local nb = vcBtn:Clone()
                nb.Parent = vcBtn.Parent
                vcBtn:Destroy()
                vcBtn = nb
                local function update()
                    if S.enabled then
                        vcBtn.Text = "Disable"
                        vcBtn.BackgroundColor3 = Color3.fromRGB(80, 200, 120)
                        vcBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
                    else
                        vcBtn.Text = "Enable"
                        vcBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
                        vcBtn.TextColor3 = Color3.fromRGB(255, 100, 120)
                    end
                end
                update()
                vcBtn.MouseButton1Click:Connect(function()
                    if S.enabled then disableShield() else enableShield() end
                    update()
                end)
            end
            return true
        end
        for _ = 1, 50 do
            if rewire() then break end
            task.wait(0.1)
        end
    end)
end)

-- ============================================================
-- ULTRA PREMIUM RED CHAT (neon glow + deep black)
-- ============================================================
task.spawn(function()
    pcall(function()
        local TextChatService = game:GetService("TextChatService")
        local Players = game:GetService("Players")
        local lp = Players.LocalPlayer
        if not lp then return end

        local RED = Color3.fromRGB(255, 32, 55)
        local RED_GLOW = Color3.fromRGB(255, 70, 95)
        local RED_SOFT = Color3.fromRGB(255, 155, 170)
        local BG = Color3.fromRGB(3, 0, 1)
        local BG_INPUT = Color3.fromRGB(8, 1, 3)

        local function styleBubble(gui)
            for _, x in ipairs(gui:GetDescendants()) do
                if x:IsA("Frame") and x.BackgroundTransparency < 0.97 then
                    x.BackgroundColor3 = BG
                    x.BackgroundTransparency = 0.08
                    local s = x:FindFirstChild("PrismChatStroke")
                    if not s then
                        s = Instance.new("UIStroke")
                        s.Name = "PrismChatStroke"
                        s.Parent = x
                    end
                    s.Color = RED
                    s.Thickness = 2.4
                    s.Transparency = 0
                    -- second outer glow stroke
                    local s2 = x:FindFirstChild("PrismChatGlow")
                    if not s2 then
                        s2 = Instance.new("UIStroke")
                        s2.Name = "PrismChatGlow"
                        s2.Parent = x
                    end
                    s2.Color = RED_GLOW
                    s2.Thickness = 4.5
                    s2.Transparency = 0.55
                    if not x:FindFirstChildOfClass("UICorner") then
                        Instance.new("UICorner", x).CornerRadius = UDim.new(0, 12)
                    end
                elseif x:IsA("TextLabel") then
                    x.TextColor3 = RED_SOFT
                    x.TextStrokeTransparency = 0.35
                    x.TextStrokeColor3 = Color3.fromRGB(60, 0, 10)
                    x.Font = Enum.Font.GothamMedium
                end
            end
        end

        local function forceStyleAll()
            pcall(function()
                local win = TextChatService.ChatWindowConfiguration
                if win then
                    win.BackgroundColor3 = BG
                    win.BackgroundTransparency = 0.12
                    win.TextColor3 = RED_SOFT
                end
            end)
            pcall(function()
                local input = TextChatService.ChatInputBarConfiguration
                if input then
                    input.BackgroundColor3 = BG_INPUT
                    input.BackgroundTransparency = 0.04
                    input.TextColor3 = Color3.fromRGB(255, 200, 210)
                    input.PlaceholderColor3 = Color3.fromRGB(160, 55, 70)
                end
            end)
            pcall(function()
                local bub = TextChatService.BubbleChatConfiguration
                if bub then
                    bub.BackgroundColor3 = BG
                    bub.BackgroundTransparency = 0.06
                    bub.TextColor3 = RED_SOFT
                end
            end)

            local pg = lp:FindFirstChildOfClass("PlayerGui")
            if not pg then return end
            for _, child in ipairs(pg:GetChildren()) do
                local n = child.Name:lower()
                if n:find("chat") or n:find("textchat") or n:find("experiencechat") then
                    for _, d in ipairs(child:GetDescendants()) do
                        if d:IsA("Frame") and d.BackgroundTransparency < 0.95 then
                            d.BackgroundColor3 = BG
                            d.BackgroundTransparency = 0.1
                            local s = d:FindFirstChild("PrismChatStroke") or Instance.new("UIStroke")
                            s.Name = "PrismChatStroke"
                            s.Color = RED
                            s.Thickness = 2.6
                            s.Transparency = 0
                            s.Parent = d
                            local s2 = d:FindFirstChild("PrismChatGlow") or Instance.new("UIStroke")
                            s2.Name = "PrismChatGlow"
                            s2.Color = RED_GLOW
                            s2.Thickness = 5
                            s2.Transparency = 0.5
                            s2.Parent = d
                            if not d:FindFirstChildOfClass("UICorner") then
                                Instance.new("UICorner", d).CornerRadius = UDim.new(0, 12)
                            end
                        end
                        if d:IsA("TextBox") then
                            d.BackgroundColor3 = BG_INPUT
                            d.BackgroundTransparency = 0.05
                            d.TextColor3 = Color3.fromRGB(255, 200, 210)
                            d.PlaceholderColor3 = Color3.fromRGB(160, 55, 70)
                            local s = d:FindFirstChild("PrismInputStroke") or Instance.new("UIStroke")
                            s.Name = "PrismInputStroke"
                            s.Color = RED
                            s.Thickness = 2.8
                            s.Transparency = 0
                            s.Parent = d
                            local s2 = d:FindFirstChild("PrismInputGlow") or Instance.new("UIStroke")
                            s2.Name = "PrismInputGlow"
                            s2.Color = RED_GLOW
                            s2.Thickness = 5.5
                            s2.Transparency = 0.45
                            s2.Parent = d
                        end
                        if d:IsA("TextLabel") and d.AbsoluteSize.Y < 42 then
                            d.TextColor3 = RED_SOFT
                            d.TextStrokeTransparency = 0.4
                            d.TextStrokeColor3 = Color3.fromRGB(50, 0, 8)
                        end
                    end
                end
            end
        end

        for i = 1, 30 do
            task.delay(i * 0.3, forceStyleAll)
        end
        forceStyleAll()

        game.DescendantAdded:Connect(function(d)
            task.defer(function()
                pcall(function()
                    local bub = d:FindFirstAncestorWhichIsA("BillboardGui")
                    if bub and (bub.Name:lower():find("bubble") or bub.Name:lower():find("chat")) then
                        styleBubble(bub)
                    end
                    if d:IsA("Frame") or d:IsA("TextBox") then
                        forceStyleAll()
                    end
                end)
            end)
        end)
    end)
end)

task.spawn(function()
    pcall(function()
        local RunService = game:GetService("RunService")
        local Players = game:GetService("Players")
        local lp = Players.LocalPlayer
        if not lp then return end

        if not _G._CyrisEmoteSmoothness or _G._CyrisEmoteSmoothness < 0.35 then
            _G._CyrisEmoteSmoothness = 0.7
        end

        _G._PrismStateHysteresis = function(hum, last)
            if not hum then return last or "Idle" end
            local hs = hum:GetState()
            if hs == Enum.HumanoidStateType.Jumping then return "Jump" end
            if hs == Enum.HumanoidStateType.Freefall then
                local hrp = hum.RootPart
                if hrp and hrp.AssemblyLinearVelocity.Y > 0.4 then return "Jump" end
                return "Fall"
            end
            if hs == Enum.HumanoidStateType.Climbing then return "Climb" end
            if hs == Enum.HumanoidStateType.Swimming then
                return (hum.MoveDirection.Magnitude > 0.1) and "Swim" or "SwimIdle"
            end
            local hrp = hum.RootPart
            local horiz = 0
            if hrp then
                local v = hrp.AssemblyLinearVelocity
                horiz = Vector2.new(v.X, v.Z).Magnitude
            end
            if last == "Run" then
                if horiz >= 8 then return "Run" end
                if horiz >= 2.2 then return "Walk" end
                return "Idle"
            elseif last == "Walk" then
                if horiz >= 12 then return "Run" end
                if horiz >= 1.6 then return "Walk" end
                return "Idle"
            else
                if horiz >= 12 then return "Run" end
                if horiz >= 2 then return "Walk" end
                return "Idle"
            end
        end

        local function getApi()
            return rawget(_G, "_HaloReanimateAPI") or ReanimateAPI
        end

        local function isReanimated()
            local api = getApi()
            local ok, res = pcall(function()
                return api and api.is_reanimated and api.is_reanimated() == true
            end)
            return ok and res == true
        end

        local function animPlaying()
            local api = getApi()
            local ok, res = pcall(function() return api.is_animation_playing() end)
            return ok and res == true
        end

        local function getClone()
            local api = getApi()
            local clone = nil
            pcall(function()
                if api and api.get_clone then clone = api.get_clone(lp) end
            end)
            return clone or lp.Character
        end

        local function isAnimJoint(inst)
            return inst:IsA("Motor6D") or inst:IsA("AnimationConstraint")
        end

        local function capturePose(model)
            local poses = {}
            if not model then return poses end
            for _, d in ipairs(model:GetDescendants()) do
                if isAnimJoint(d) then
                    local ok, tr = pcall(function() return d.Transform end)
                    if ok and typeof(tr) == "CFrame" then poses[d] = tr end
                end
            end
            return poses
        end

        local function jointPartName(joint)
            local nm = nil
            pcall(function()
                if joint:IsA("Motor6D") then
                    nm = joint.Part1 and joint.Part1.Name
                else
                    local att1 = joint.Attachment1
                    if att1 and att1.Parent then nm = att1.Parent.Name end
                end
            end)
            return nm
        end

        local function trackerOwns(nm)
            if not nm then return false end
            if nm == "Head" and (_G._HaloHeadTrackerEnabled or _G._HaloHeadStretching) then return true end
            if _G._HaloTrackActive and _G._HaloDoTrack and (nm == "UpperTorso" or nm == "LowerTorso" or nm == "Torso" or nm == "HumanoidRootPart") then return true end
            local stretchL = _G._HaloLeftArmStretching
            local stretchR = _G._HaloRightArmStretching
            if (_G._HaloArmAiming and _G._HaloLeftArmPointerEnabled or stretchL) and (nm == "LeftUpperArm" or nm == "LeftLowerArm" or nm == "LeftHand" or nm == "Left Arm") then return true end
            if (_G._HaloArmAiming and _G._HaloRightArmPointerEnabled or stretchR) and (nm == "RightUpperArm" or nm == "RightLowerArm" or nm == "RightHand" or nm == "Right Arm") then return true end
            return false
        end

        local function smoothness()
            return math.clamp(tonumber(_G._CyrisEmoteSmoothness) or 0.65, 0, 1)
        end
        local function emoteBlend()
            local sm = smoothness()
            if sm < 0.03 then return 0 end
            return math.max(0.14, sm * 1.15)
        end
        local function stateBlend()
            local sm = smoothness()
            if sm < 0.03 then return 0 end
            return math.max(0.11, sm * 0.42)
        end

        local holdConn = nil
        local function stopHold()
            if holdConn then pcall(function() holdConn:Disconnect() end) holdConn = nil end
        end

        local blend = nil       -- active blend {from, skip, last, t0, dur, state}
        local staticConn = nil  -- only used when no animation is driving the joints

        local function stopBlend()
            blend = nil
            if staticConn then pcall(function() staticConn:Disconnect() end) staticConn = nil end
        end

        _G._PrismBlendStep = function()
            local b = blend
            if not b then return end
            local ok = pcall(function()
                local a = (os.clock() - b.t0) / b.dur
                if a >= 1 then blend = nil return end
                a = b.state and (1 - (1 - a) ^ 3) or (a * a * (3 - 2 * a))
                for joint, fromCF in pairs(b.from) do
                    if joint.Parent and not b.skip[joint] then
                        local cur = joint.Transform
                        local lw = b.last[joint]
                        if lw == nil or cur ~= lw then
                            joint.Transform = fromCF:Lerp(cur, a)
                            b.last[joint] = joint.Transform
                        end
                    end
                end
            end)
            if not ok then blend = nil end
        end

        local function startCrossfade(from, duration, isState)
            stopBlend()
            stopHold()
            if not from or not next(from) then return end
            duration = tonumber(duration) or 0
            if duration < 0.05 or not isReanimated() then return end

            local skip = {}
            for joint in pairs(from) do
                if trackerOwns(jointPartName(joint)) then skip[joint] = true end
            end
            local b = { from = from, skip = skip, last = {}, t0 = os.clock(), dur = duration, state = isState and true or false }

            if animPlaying() then
                blend = b
            else
                local to = {}
                for joint in pairs(from) do
                    if joint.Parent then
                        local ok, tr = pcall(function() return joint.Transform end)
                        if ok then to[joint] = tr end
                    end
                end
                staticConn = RunService.Heartbeat:Connect(function()
                    local a = (os.clock() - b.t0) / b.dur
                    if a >= 1 or not isReanimated() or animPlaying() then stopBlend() return end
                    a = b.state and (1 - (1 - a) ^ 3) or (a * a * (3 - 2 * a))
                    for joint, fromCF in pairs(from) do
                        local t = to[joint]
                        if t and joint.Parent and not skip[joint] then
                            pcall(function() joint.Transform = fromCF:Lerp(t, a) end)
                        end
                    end
                end)
            end
        end

        _G._PrismCapturePose = function()
            if not isReanimated() then return nil end
            local p = capturePose(getClone())
            _G._PrismManualFrom = { pose = p, t = os.clock() }
            return p
        end
        _G._PrismHoldPose = function(p, maxSeconds)
            stopHold()
            if not p or not next(p) then return end
            for joint, cf in pairs(p) do
                if joint.Parent then pcall(function() joint.Transform = cf end) end
            end
            local t0 = os.clock()
            local limit = tonumber(maxSeconds) or 1.5
            holdConn = RunService.Heartbeat:Connect(function()
                if animPlaying() or (os.clock() - t0) > limit or not isReanimated() then
                    stopHold()
                    return
                end
                for joint, cf in pairs(p) do
                    if joint.Parent then pcall(function() joint.Transform = cf end) end
                end
            end)
        end

        local function takeFrom(isState)
            local m = _G._PrismManualFrom
            if m and m.pose and next(m.pose) and (os.clock() - m.t) < (isState and 0.5 or 3) then
                _G._PrismManualFrom = nil
                return m.pose
            end
            local p = _G._HaloPendingBlendPose
            if p and next(p) and (os.clock() - (_G._HaloPendingBlendPoseTime or 0)) < 0.6 then
                _G._HaloPendingBlendPose = nil
                return p
            end
            return capturePose(getClone())
        end

        local function original(api, name)
            api._prismOrig = api._prismOrig or {}
            if api._prismOrig[name] == nil and type(api[name]) == "function" then
                api._prismOrig[name] = api[name]
            end
            return api._prismOrig[name]
        end

        local function wrapPlay(api, name)
            local old = original(api, name)
            if type(old) ~= "function" then return end
            api[name] = function(...)
                local re = isReanimated()
                local isState = currentStateAnim ~= nil
                local from = re and takeFrom(isState) or nil
                local r = old(...)
                if re and isReanimated() then
                    startCrossfade(from, isState and stateBlend() or emoteBlend(), isState)
                end
                return r
            end
        end

        local function hookApi()
            local api = getApi()
            if type(api) ~= "table" then return false end
            wrapPlay(api, "play_raw_animation")
            wrapPlay(api, "play_animation")

            local oldStop = original(api, "stop_animation_for_transition")
            if type(oldStop) == "function" then
                api.stop_animation_for_transition = function()
                    local from = nil
                    if isReanimated() and animPlaying() then from = capturePose(getClone()) end
                    local r = oldStop()
                    if from and next(from) then
                        _G._HaloPendingBlendPose = from
                        _G._HaloPendingBlendPoseTime = os.clock()
                    end
                    return r
                end
            end
            return true
        end

        if type(PlayAnimation) == "function" then
            local oldPlay = PlayAnimation
            PlayAnimation = function(animName, speed, isCustom)
                local pose = nil
                pcall(function() pose = _G._PrismCapturePose() end)
                local r = oldPlay(animName, speed, isCustom)
                if pose and State and State.selectedAnim ~= nil then
                    pcall(_G._PrismHoldPose, pose, 1.5)
                end
                return r
            end
        end

        for _ = 1, 80 do
            if hookApi() then break end
            task.wait(0.1)
        end

    end)
end)

-- BG FILL
task.spawn(function()
    pcall(function()
        local lp = game:GetService("Players").LocalPlayer
        for _ = 1, 60 do
            local sg = nil
            pcall(function() if ScreenGui and ScreenGui.Parent then sg = ScreenGui end end)
            if not sg and lp then
                local pg = lp:FindFirstChildOfClass("PlayerGui")
                if pg then sg = pg:FindFirstChild("ReanimHaloMenu") end
            end
            local menu = sg and (sg:FindFirstChild("ReanimMenu") or (Menu and Menu.Parent and Menu))
            if menu then
                local bg = menu:FindFirstChild("CustomBackground")
                if bg and bg:IsA("ImageLabel") then
                    bg.ScaleType = Enum.ScaleType.Crop
                    bg.Size = UDim2.new(1, 0, 1, 0)
                    bg.Position = UDim2.new(0, 0, 0, 0)
                    bg.ImageTransparency = 0.12
                    return
                end
            end
            task.wait(0.1)
        end
    end)
end)


-- Arm trackers: left click turns aiming on, left click again turns it off.
-- Runs even when no emote is playing, and only while aiming so smoothness stays intact.
task.spawn(function()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UIS = game:GetService("UserInputService")
    local lp = Players.LocalPlayer
    if not lp then return end
    _G._HaloArmAiming = false

    local function armsEnabled()
        return _G._HaloLeftArmPointerEnabled or _G._HaloRightArmPointerEnabled
    end

    UIS.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        if not armsEnabled() then return end
        _G._HaloArmAiming = not _G._HaloArmAiming
        pcall(function()
            if Notify then
                Notify(_G._HaloArmAiming and "Arms aiming" or "Arms off", 1.5)
            end
        end)
    end)

    local function getRig()
        local api = rawget(_G, "_HaloReanimateAPI") or rawget(_G, "ReanimateAPI")
        local clone = nil
        pcall(function()
            if api and api.get_clone then clone = api.get_clone(lp) end
        end)
        return clone or lp.Character
    end

    local function findJoint(rig, partName, r6Name)
        for _, d in ipairs(rig:GetDescendants()) do
            if d:IsA("Motor6D") and d.Part1 and (d.Part1.Name == partName or (r6Name ~= "" and d.Part1.Name == r6Name)) then
                return d
            end
            if d:IsA("AnimationConstraint") then
                local att = d.Attachment1
                if att and att.Parent and (att.Parent.Name == partName or (r6Name ~= "" and att.Parent.Name == r6Name)) then
                    return d
                end
            end
        end
    end

    local function jointWorld(joint)
        if joint:IsA("Motor6D") and joint.Part0 then
            return joint.Part0.CFrame * joint.C0
        end
        local att = joint.Attachment0
        if att and att.Parent then return att.WorldCFrame end
    end

    local function aimJoint(joint, targetPos)
        local base = jointWorld(joint)
        if not base then return end
        local aim = targetPos - base.Position
        if aim.Magnitude < 0.05 then return end
        aim = aim.Unit
        local childBone = Vector3.new(0, -1, 0)
        local localAim = base.Rotation:Inverse() * aim
        local axis = childBone:Cross(localAim)
        if axis.Magnitude > 0.001 then
            local ang = math.acos(math.clamp(childBone.Unit:Dot(localAim.Unit), -1, 1))
            joint.Transform = CFrame.fromAxisAngle(axis.Unit, ang)
        elseif childBone:Dot(localAim) < 0 then
            joint.Transform = CFrame.fromAxisAngle(Vector3.new(1, 0, 0), math.pi)
        else
            joint.Transform = CFrame.new()
        end
    end

    local function mouseWorld()
        local cam = workspace.CurrentCamera
        local mouse = lp:GetMouse()
        if not cam or not mouse then return nil end
        local ray = cam:ViewportPointToRay(mouse.X, mouse.Y)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        local filter = {}
        local rig = getRig()
        if rig then table.insert(filter, rig) end
        if lp.Character then table.insert(filter, lp.Character) end
        params.FilterDescendantsInstances = filter
        local hit = workspace:Raycast(ray.Origin, ray.Direction * 1500, params)
        if hit then return hit.Position end
        return ray.Origin + ray.Direction * 1500
    end

    local function stretchLower(joint, amt)
        if not joint or not amt or amt <= 1.01 then return end
        local len = 1
        if joint:IsA("Motor6D") and joint.Part1 and joint.Part1:IsA("BasePart") then
            len = joint.Part1.Size.Y
        else
            local att = joint.Attachment1
            if att and att.Parent and att.Parent:IsA("BasePart") then
                len = att.Parent.Size.Y
            end
        end
        local extra = CFrame.new(0, -len * (amt - 1), 0)
        joint.Transform = extra
    end

    local function restoreHeadSize(rig)
        local head = rig and rig:FindFirstChild("Head")
        if not (head and head:IsA("BasePart")) then return end
        local api = rawget(_G, "_HaloReanimateAPI") or rawget(_G, "ReanimateAPI")
        local real = nil
        pcall(function()
            if api and api.get_real_character then real = api.get_real_character(lp) end
        end)
        local realHead = real and real:FindFirstChild("Head")
        if not (realHead and realHead:IsA("BasePart")) then return end
        if (head.Size - realHead.Size).Magnitude > 0.02 then
            head.Size = realHead.Size
        end
        local mesh = head:FindFirstChildOfClass("SpecialMesh")
        local realMesh = realHead:FindFirstChildOfClass("SpecialMesh")
        if mesh and realMesh then
            mesh.Scale = realMesh.Scale
        end
    end

    local function trackHead(rig)
        if rig then
            local oldNeck = rig:FindFirstChild("HaloNeck")
            if oldNeck then pcall(function() oldNeck:Destroy() end) end
            local saved = _G._HaloNeckBackup and _G._HaloNeckBackup[rig]
            if saved then
                for _, item in ipairs(saved) do
                    pcall(function()
                        if item.motor and item.motor.Parent then
                            item.motor.Part0 = item.part0
                            item.motor.Part1 = item.part1
                        elseif item.constraint and item.constraint.Parent then
                            item.constraint.Enabled = true
                        end
                    end)
                end
                _G._HaloNeckBackup[rig] = nil
            end
        end
        restoreHeadSize(rig)
        if not (_G._HaloHeadTrackerEnabled or _G._HaloHeadStretching) then return end
        local headJoint = findJoint(rig, "Head", "Head")
        if not headJoint then return end
        local rot = CFrame.new()
        if _G._HaloHeadTrackerEnabled then
            local cam = workspace.CurrentCamera
            local torso = rig:FindFirstChild("UpperTorso") or rig:FindFirstChild("Torso")
            if cam and torso then
                local rel = torso.CFrame:VectorToObjectSpace(cam.CFrame.LookVector)
                local pitch = math.clamp(math.asin(math.clamp(rel.Y, -1, 1)), math.rad(-45), math.rad(50))
                local yaw = math.clamp(math.atan2(-rel.X, -rel.Z), math.rad(-70), math.rad(70))
                local target = CFrame.Angles(pitch, yaw, 0)
                local smoothed = _G._HaloHeadTrackerSmoothedCF or target
                smoothed = smoothed:Lerp(target, 0.3)
                _G._HaloHeadTrackerSmoothedCF = smoothed
                rot = smoothed
            end
        end
        if _G._HaloHeadStretching then
            local amt = math.clamp(_G._HaloHeadStretchAmount or 1, 1, 2.2)
            headJoint.Transform = CFrame.new(0, (amt - 1) * 0.12, 0) * rot
        else
            headJoint.Transform = rot
        end
    end

    local function apply()
        local rig = getRig()
        if not rig then return end
        if _G._HaloTrackActive and type(_G._HaloDoTrack) == "function" then
            pcall(_G._HaloDoTrack)
        end
        local aiming = _G._HaloArmAiming and armsEnabled()
        local stretching = _G._HaloLeftArmStretching or _G._HaloRightArmStretching
        if aiming then
            local target = mouseWorld()
            if target then
                local function arm(upper, lower, hand, r6, on, stretchOn)
                    if not on and not stretchOn then return end
                    if on then
                        local sh = findJoint(rig, upper, r6)
                        if sh then aimJoint(sh, target) end
                        local el = findJoint(rig, lower, "")
                        local wr = findJoint(rig, hand, "")
                        if el then el.Transform = CFrame.new() end
                        if wr then wr.Transform = CFrame.new() end
                        if stretchOn and el then
                            stretchLower(el, _G._HaloArmStretchAmount or 2.5)
                        end
                    elseif stretchOn then
                        local el = findJoint(rig, lower, "")
                        if el then stretchLower(el, _G._HaloArmStretchAmount or 2.5) end
                    end
                end
                arm("RightUpperArm", "RightLowerArm", "RightHand", "Right Arm", _G._HaloRightArmPointerEnabled, _G._HaloRightArmStretching)
                arm("LeftUpperArm", "LeftLowerArm", "LeftHand", "Left Arm", _G._HaloLeftArmPointerEnabled, _G._HaloLeftArmStretching)
            end
        elseif stretching then
            if _G._HaloRightArmStretching then
                stretchLower(findJoint(rig, "RightLowerArm", ""), _G._HaloArmStretchAmount or 2.5)
            end
            if _G._HaloLeftArmStretching then
                stretchLower(findJoint(rig, "LeftLowerArm", ""), _G._HaloArmStretchAmount or 2.5)
            end
        end
        trackHead(rig)
    end

    local function needDrive()
        return _G._HaloHeadTrackerEnabled or _G._HaloHeadStretching or _G._HaloTrackActive
            or _G._HaloArmAiming or _G._HaloLeftArmStretching or _G._HaloRightArmStretching
    end

    local tail
    local lastHeadFix = 0
    RunService.Heartbeat:Connect(function()
        local now = os.clock()
        if now - lastHeadFix > 0.5 then
            lastHeadFix = now
            pcall(function()
                restoreHeadSize(getRig())
            end)
        end
        if tail then pcall(function() tail:Disconnect() end) tail = nil end
        if not needDrive() then return end
        tail = RunService.PreSimulation:Connect(function()
            pcall(apply)
        end)
    end)
end)

-- Anti-crash. Off until Settings -> Anti Crash -> Enable.
-- Never touches player bodies. Only removes obvious crash spam.
_G._HaloAntiCrash = false
task.spawn(function()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local Lighting = game:GetService("Lighting")
    local lp = Players.LocalPlayer
    if not lp then return end

    local blocked = 0
    local lastNotify = 0
    local wasOn = false
    local lightBackup = nil
    local recent = {}

    local function on()
        return _G._HaloAntiCrash == true
    end

    local function ownModel(inst)
        local char = lp.Character
        if char and (inst == char or inst:IsDescendantOf(char)) then return true end
        local api = rawget(_G, "_HaloReanimateAPI") or rawget(_G, "ReanimateAPI")
        local clone = nil
        pcall(function()
            if api and api.get_clone then clone = api.get_clone(lp) end
        end)
        if clone and (inst == clone or inst:IsDescendantOf(clone)) then return true end
        return false
    end

    local function inAnyCharacter(inst)
        if ownModel(inst) then return true end
        for _, p in ipairs(Players:GetPlayers()) do
            local c = p.Character
            if c and (inst == c or inst:IsDescendantOf(c)) then
                return true
            end
        end
        return false
    end

    local function bad(n)
        return type(n) ~= "number" or n ~= n or n == math.huge or n == -math.huge
    end

    local function kill(inst)
        if not inst or not inst.Parent then return end
        if inAnyCharacter(inst) then return end
        if inst.Name == "PrismVoiceMeter" then return end
        pcall(function() inst:Destroy() end)
        blocked = blocked + 1
    end

    local function obviousCrash(inst)
        if inst:IsA("Explosion") then return true end
        if inst:IsA("BasePart") then
            local s, pos = inst.Size, inst.Position
            if bad(s.X) or bad(s.Y) or bad(s.Z) or bad(pos.X) or bad(pos.Y) or bad(pos.Z) then
                return true
            end
            if math.abs(pos.X) > 100000 or math.abs(pos.Y) > 100000 or math.abs(pos.Z) > 100000 then
                return true
            end
            if s.X > 500 or s.Y > 500 or s.Z > 500 then
                return true
            end
        elseif inst:IsA("ParticleEmitter") then
            if inst.Rate > 80 then return true end
        elseif inst:IsA("Fire") or inst:IsA("Smoke") then
            if inst.Size > 50 then return true end
        elseif inst:IsA("SpecialMesh") then
            local sc = inst.Scale
            if bad(sc.X) or sc.X > 200 or sc.Y > 200 or sc.Z > 200 then return true end
        elseif inst:IsA("Beam") then
            if inst.Width0 > 80 or inst.Width1 > 80 then return true end
        elseif inst:IsA("Sound") then
            if bad(inst.PlaybackSpeed) or inst.Volume > 50 then return true end
        end
        return false
    end

    local function check(inst)
        if not on() or not inst then return end
        -- Bodies, clothes, hats, and voice stay. Do not touch them.
        if inAnyCharacter(inst) then
            if ownModel(inst) and (inst:IsA("BodyMover") or inst:IsA("LinearVelocity") or inst:IsA("AngularVelocity") or inst:IsA("VectorForce")) then
                pcall(function() inst:Destroy() end)
                blocked = blocked + 1
            end
            return
        end
        if obviousCrash(inst) then
            kill(inst)
            return
        end
        -- Only a sudden dump of parts straight into Workspace counts as a crash.
        if not (inst:IsA("BasePart") or inst:IsA("ParticleEmitter") or inst:IsA("Fire") or inst:IsA("Smoke") or inst:IsA("Beam") or inst:IsA("Trail")) then
            return
        end
        if inst.Parent ~= workspace then return end
        local now = os.clock()
        recent[#recent+1] = {now, inst}
        local n = 0
        local i = 1
        while i <= #recent do
            local item = recent[i]
            if now - item[1] > 0.4 or not item[2] or not item[2].Parent then
                table.remove(recent, i)
            else
                n = n + 1
                i = i + 1
            end
        end
        if n >= 25 then
            for _, item in ipairs(recent) do
                local obj = item[2]
                if obj and obj.Parent == workspace and not inAnyCharacter(obj) then
                    kill(obj)
                end
            end
            table.clear(recent)
        end
    end

    workspace.DescendantAdded:Connect(function(inst)
        if not on() then return end
        task.defer(function()
            pcall(check, inst)
        end)
    end)

    RunService.Heartbeat:Connect(function()
        local enabled = on()
        if enabled and not wasOn then
            pcall(function()
                lightBackup = Lighting.GlobalShadows
                Lighting.GlobalShadows = false
            end)
            table.clear(recent)
        elseif (not enabled) and wasOn then
            pcall(function()
                if lightBackup ~= nil then Lighting.GlobalShadows = lightBackup end
            end)
        end
        wasOn = enabled
        if not enabled then return end

        local hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            pcall(function()
                local v = hrp.AssemblyLinearVelocity
                if bad(v.X) or v.Magnitude > 500 then
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    hrp.AssemblyAngularVelocity = Vector3.zero
                end
            end)
        end

        if blocked > 0 then
            blocked = 0
        end
    end)
end)
-- Prism hub, commands, fly, esp. No neck.
task.defer(function()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local TweenService = game:GetService("TweenService")
    local TeleportService = game:GetService("TeleportService")
    local plr = Players.LocalPlayer

    local lastMsg, lastAt = "", 0
    local flyOn, noclipOn = false, false
    local flyConn, attachWeld = nil, nil
    local espOn = false
    local espFolder = {}
    local binds = {}
    local autoexec = {}
    pcall(function()
        local raw
        if type(readfile) == "function" then raw = readfile("PrismAutoExec.json") end
        if type(raw) == "string" and raw ~= "" then
            local data = game:GetService("HttpService"):JSONDecode(raw)
            if type(data) == "table" then autoexec = data end
        end
    end)

    local function note(a, b)
        pcall(function()
            if Notify then Notify(a, b, 2) else print(a, b or "") end
        end)
    end

    local function findPlayer(name)
        if not name or name == "" then return nil end
        name = name:lower()
        local best
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= plr then
                local n, d = p.Name:lower(), p.DisplayName:lower()
                if n == name or d == name then return p end
                if n:find(name, 1, true) or d:find(name, 1, true) then best = best or p end
            end
        end
        return best
    end

    local function humRoot()
        local api = rawget(_G, "_HaloReanimateAPI") or rawget(_G, "ReanimateAPI")
        local char = nil
        pcall(function()
            if api and api.get_clone then char = api.get_clone(plr) end
        end)
        if not (char and char.Parent) then
            char = workspace:FindFirstChild("Reanimation")
        end
        if not (char and char.Parent) then
            char = plr.Character
        end
        if not char then return nil, nil end
        local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
        return hrp, char:FindFirstChildOfClass("Humanoid")
    end

    local function clearAttach()
        if attachWeld then pcall(function() attachWeld:Destroy() end) attachWeld = nil end
        local _, hum = humRoot()
        if hum then hum.PlatformStand = false end
    end

    local function setFly(on)
        flyOn = on
        _G._HaloFlyOn = on
        if flyConn then flyConn:Disconnect() flyConn = nil end
        if not on then
            local hrp, hum = humRoot()
            if hum then
                hum.PlatformStand = false
                pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
            end
            if hrp then
                pcall(function()
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    hrp.AssemblyAngularVelocity = Vector3.zero
                end)
            end
            note("Fly", "OFF")
            return
        end
        note("Fly", "ON  WASD / space / ctrl")
        local last = os.clock()
        flyConn = RunService.Stepped:Connect(function()
            if not flyOn then return end
            local now = os.clock()
            local dt = math.clamp(now - last, 0.001, 0.05)
            last = now
            local hrp, hum = humRoot()
            if not hrp then return end
            if hum then
                hum.PlatformStand = true
                pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end)
            end
            pcall(function()
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end)
            local cam = workspace.CurrentCamera
            if not cam then return end
            local dir = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.yAxis end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                dir = dir - Vector3.yAxis
            end
            if dir.Magnitude > 0.05 then dir = dir.Unit else dir = Vector3.zero end
            local speed = _G._HaloFlySpeed or 80
            local pos = hrp.Position + dir * speed * dt
            hrp.CFrame = CFrame.new(pos) * (cam.CFrame - cam.CFrame.Position)
        end)
    end

    RunService.Stepped:Connect(function()
        if not noclipOn then return end
        local hrp = humRoot()
        local c = hrp and hrp.Parent
        if not c then return end
        for _, part in ipairs(c:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end)

    local function setEsp(on)
        espOn = on
        for _, h in pairs(espFolder) do
            pcall(function() h:Destroy() end)
        end
        table.clear(espFolder)
        if not on then note("ESP", "OFF") return end
        local function tag(p)
            if p == plr or not p.Character then return end
            local hl = Instance.new("Highlight")
            hl.Name = "HaloESP"
            hl.FillColor = Color3.fromRGB(255, 40, 70)
            hl.OutlineColor = Color3.fromRGB(255, 220, 230)
            hl.FillTransparency = 0.55
            hl.OutlineTransparency = 0
            hl.Adornee = p.Character
            hl.Parent = p.Character
            espFolder[p.UserId] = hl
        end
        for _, p in ipairs(Players:GetPlayers()) do tag(p) end
        note("ESP", "ON")
    end
    Players.PlayerAdded:Connect(function(p)
        p.CharacterAdded:Connect(function()
            if espOn then task.wait(0.4) setEsp(true) end
        end)
    end)

    local function showMenu()
        if Menu then
            Menu.Visible = true
            pcall(function()
                Menu.Size = UDim2.new(0, 460, 0, 560)
            end)
        end
    end

    local function openCopier()
        local gui = plr:FindFirstChildOfClass("PlayerGui")
        local old = gui and gui:FindFirstChild("PrismCopier")
        if old then old:Destroy() end
        local sg = Instance.new("ScreenGui")
        sg.Name = "PrismCopier"
        sg.ResetOnSpawn = false
        sg.Parent = gui
        local f = Instance.new("Frame")
        f.Size = UDim2.fromOffset(280, 320)
        f.Position = UDim2.new(0.5, -140, 0.5, -160)
        f.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
        f.Parent = sg
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, 12)
        local title = Instance.new("TextLabel")
        title.BackgroundTransparency = 1
        title.Size = UDim2.new(1, -30, 0, 28)
        title.Font = Enum.Font.GothamBold
        title.Text = "Animation Copier"
        title.TextColor3 = Color3.new(1, 1, 1)
        title.TextSize = 14
        title.Parent = f
        local close = Instance.new("TextButton")
        close.Size = UDim2.fromOffset(24, 24)
        close.Position = UDim2.new(1, -28, 0, 4)
        close.Text = "X"
        close.BackgroundColor3 = Color3.fromRGB(40, 40, 44)
        close.TextColor3 = Color3.new(1, 1, 1)
        close.Parent = f
        Instance.new("UICorner", close).CornerRadius = UDim.new(0, 6)
        close.MouseButton1Click:Connect(function() sg:Destroy() end)
        local list = Instance.new("ScrollingFrame")
        list.Size = UDim2.new(1, -16, 1, -40)
        list.Position = UDim2.fromOffset(8, 34)
        list.BackgroundTransparency = 1
        list.ScrollBarThickness = 4
        list.CanvasSize = UDim2.fromOffset(0, 0)
        list.Parent = f
        local lay = Instance.new("UIListLayout", list)
        lay.Padding = UDim.new(0, 4)
        local y = 0
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= plr then
                local b = Instance.new("TextButton")
                b.Size = UDim2.new(1, -8, 0, 28)
                b.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
                b.Text = "Copy " .. p.DisplayName
                b.TextColor3 = Color3.new(1, 1, 1)
                b.Font = Enum.Font.Gotham
                b.TextSize = 12
                b.Parent = list
                Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
                b.MouseButton1Click:Connect(function()
                    local ch = p.Character
                    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
                    local animator = hum and hum:FindFirstChildOfClass("Animator")
                    local mine = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
                    local myAnim = mine and (mine:FindFirstChildOfClass("Animator") or Instance.new("Animator", mine))
                    if not animator or not myAnim then note("Copier", "No animator") return end
                    local n = 0
                    for _, tr in ipairs(animator:GetPlayingAnimationTracks()) do
                        local id = tr.Animation and tr.Animation.AnimationId
                        if id and id ~= "" then
                            local anim = Instance.new("Animation")
                            anim.AnimationId = id
                            local ok, track = pcall(function() return myAnim:LoadAnimation(anim) end)
                            if ok and track then track:Play(0.15) n = n + 1 end
                        end
                    end
                    note("Copier", n > 0 and ("Copied " .. n) or "Nothing playing")
                end)
                y = y + 32
            end
        end
        list.CanvasSize = UDim2.fromOffset(0, y)
    end

    local function openPrism()
        local gui = plr:FindFirstChildOfClass("PlayerGui")
        local old = gui and gui:FindFirstChild("PrismChat")
        if old then old:Destroy() end
        local sg = Instance.new("ScreenGui")
        sg.Name = "PrismChat"
        sg.ResetOnSpawn = false
        sg.Parent = gui
        local f = Instance.new("Frame")
        f.Size = UDim2.fromOffset(320, 70)
        f.Position = UDim2.new(0.5, -160, 1, -110)
        f.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
        f.BackgroundTransparency = 0.1
        f.Parent = sg
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, 12)
        local box = Instance.new("TextBox")
        box.Size = UDim2.new(1, -16, 1, -16)
        box.Position = UDim2.fromOffset(8, 8)
        box.BackgroundTransparency = 1
        box.PlaceholderText = "Prism chat..."
        box.Text = ""
        box.TextColor3 = Color3.fromRGB(255, 220, 225)
        box.Font = Enum.Font.Gotham
        box.TextSize = 14
        box.ClearTextOnFocus = false
        box.Parent = f
        box.FocusLost:Connect(function(enter)
            if not enter then return end
            local text = box.Text
            box.Text = ""
            if text == "" then return end
            pcall(function()
                local ch = game:GetService("TextChatService"):FindFirstChild("TextChannels")
                local gen = ch and ch:FindFirstChild("RBXGeneral")
                if gen then gen:SendAsync(text) end
            end)
        end)
    end

    local hiddenSet = {}
    local function applyHide(target, hidden)
        if not target then return end
        hiddenSet[target.UserId] = hidden or nil
        local char = target.Character
        if char then
            for _, d in ipairs(char:GetDescendants()) do
                if d:IsA("BasePart") then
                    d.LocalTransparencyModifier = hidden and 1 or 0
                elseif d:IsA("Decal") or d:IsA("Texture") then
                    d.Transparency = hidden and 1 or 0
                elseif d:IsA("BillboardGui") or d:IsA("ParticleEmitter") or d:IsA("Trail") then
                    d.Enabled = not hidden
                end
            end
        end
        pcall(function()
            if hidden then
                game:GetService("SoundService").LocalMuted[target.UserId] = true
            else
                game:GetService("SoundService").LocalMuted[target.UserId] = nil
            end
        end)
        if hidden and not target:GetAttribute("PrismHideHook") then
            target:SetAttribute("PrismHideHook", true)
            target.CharacterAdded:Connect(function()
                if not hiddenSet[target.UserId] then return end
                task.wait(0.4)
                applyHide(target, true)
            end)
        end
    end

    local function doTp(target)
        if not target then note("TP", "No player") return end
        local char = target.Character
        local th = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head"))
        if not th then note("TP", "They're not spawned") return end
        local goal = th.CFrame * CFrame.new(0, 3, 2)
        task.spawn(function()
            local t0 = os.clock()
            while os.clock() - t0 < 0.45 do
                local hrp = humRoot()
                if hrp then
                    hrp.CFrame = goal
                    pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero end)
                end
                RunService.Heartbeat:Wait()
            end
        end)
        note("TP", target.DisplayName)
    end

    local function doView(target)
        local cam = workspace.CurrentCamera
        local thum = target and target.Character and target.Character:FindFirstChildOfClass("Humanoid")
        if not (cam and thum) then note("View", "No character") return end
        _G._HaloViewUser = target.UserId
        cam.CameraType = Enum.CameraType.Custom
        cam.CameraSubject = thum
        note("View", target.DisplayName)
    end

    local cmds = {
        {".reanimate", "Open the Reanimate menu", false},
        {".emotes", "Open the emotes menu", false},
        {".antivcbypass", "Toggle VC bypass", false},
        {".crashbypass", "Toggle anti crash", false},
        {".fly", "Fly with WASD, space, shift down", false},
        {".unfly", "Turn fly off", false},
        {".flyspeed <value>", "Set fly speed", true},
        {".spin", "Spin your character", false},
        {".night", "Set the time to night", false},
        {".day", "Set the time to day", false},
        {".time <value>", "Set clock time 0-24", true},
        {".fog <value>", "Set fog distance", true},
        {".fullbright", "Brighten the world", false},
        {".invisible", "Make yourself invisible", false},
        {".visible", "Show yourself again", false},
        {".sit", "Sit down", false},
        {".dance", "Play a dance", false},
        {".fov <value>", "Set camera FOV", true},
        {".freeze", "Anchor yourself", false},
        {".thaw", "Unanchor yourself", false},
        {".heal", "Fill your health", false},
        {".noclip", "Walk through walls", false},
        {".infzoom", "Remove the zoom limit", false},
        {".espmenu", "Toggle player ESP", false},
        {".animcopier", "Copy someone's playing animation", false},
        {".prismchat", "Open the chat box", false},
        {".rj", "Rejoin this server", false},
        {".rejoin", "Rejoin this server", false},
        {".respawn", "Respawn your character", false},
        {".re", "Respawn and stay in place", false},
        {".unview", "Stop spectating", false},
        {".drop", "Let go of a player", false},
        {".tp <player>", "Teleport to a player", true},
        {".hide <player>", "Hide them and mute their VC", true},
        {".unhide <player>", "Bring them back", true},
        {".view <player>", "Spectate a player", true},
        {".speed <value>", "Set your walk speed", true},
        {".jumppower <value>", "Set your jump power", true},
        {".gravity <value>", "Set the gravity", true},
        {".headsit <player>", "Sit on a player's head", true},
        {".backback <player>", "Hold onto their back", true},
    }

    local function run(raw)
        if type(raw) ~= "string" then return false end
        local msg = raw:gsub("^%s+", ""):gsub("%s+$", "")
        local pre = msg:sub(1, 1)
        if pre ~= "." and pre ~= "?" then return false end
        if msg == lastMsg and os.clock() - lastAt < 0.35 then return true end
        lastMsg, lastAt = msg, os.clock()
        local body = msg:sub(2)
        local name, arg = body:match("^(%S+)%s*(.*)$")
        if not name then return false end
        name = name:lower()
        arg = arg and arg:gsub("^%s+", ""):gsub("%s+$", "") or ""
        local function known()
            return true
        end
        if name == "rj" or name == "rejoin" then
            note("Rejoining", "")
            task.delay(0.3, function()
                pcall(function() TeleportService:Teleport(game.PlaceId, plr) end)
            end)
            return known()
        elseif name == "reanimate" or name == "emotes" then
            showMenu()
            return known()
        elseif name == "antivcbypass" then
            pcall(function()
                if type(_G._PrismEnableShieldVC) == "function" then _G._PrismEnableShieldVC() end
            end)
            return known()
        elseif name == "crashbypass" then
            _G._HaloAntiCrash = not _G._HaloAntiCrash
            note("Anti crash", _G._HaloAntiCrash and "ON" or "OFF")
            return known()
        elseif name == "fly" then
            setFly(not flyOn)
            return known()
        elseif name == "unfly" then
            setFly(false)
            return known()
        elseif name == "flyspeed" then
            local n = tonumber(arg)
            if not n then note("Fly speed", "Type .flyspeed 80") return known() end
            _G._HaloFlySpeed = n
            note("Fly speed", tostring(n))
            return known()
        elseif name == "spin" then
            _G._HaloSpin = not _G._HaloSpin
            note("Spin", _G._HaloSpin and "ON" or "OFF")
            return known()
        elseif name == "night" then
            game:GetService("Lighting").ClockTime = 0
            note("Time", "Night")
            return known()
        elseif name == "day" then
            game:GetService("Lighting").ClockTime = 14
            note("Time", "Day")
            return known()
        elseif name == "time" then
            local n = tonumber(arg)
            if not n then note("Time", "Type .time 14") return known() end
            game:GetService("Lighting").ClockTime = n % 24
            note("Time", tostring(n))
            return known()
        elseif name == "fog" then
            local n = tonumber(arg) or 100
            local L = game:GetService("Lighting")
            L.FogStart = 0
            L.FogEnd = math.max(0, n)
            note("Fog", tostring(n))
            return known()
        elseif name == "fullbright" then
            local L = game:GetService("Lighting")
            L.Brightness = 2
            L.ClockTime = 14
            L.FogEnd = 100000
            L.GlobalShadows = false
            L.OutdoorAmbient = Color3.new(1, 1, 1)
            note("Light", "Fullbright")
            return known()
        elseif name == "invisible" then
            _G._HaloCharTrans = 1
            note("Invisible", "ON")
            return known()
        elseif name == "visible" then
            _G._HaloCharTrans = 0
            local hrp = humRoot()
            local c = hrp and hrp.Parent
            if c then
                for _, d in ipairs(c:GetDescendants()) do
                    if d:IsA("BasePart") then d.LocalTransparencyModifier = 0 end
                end
            end
            note("Invisible", "OFF")
            return known()
        elseif name == "sit" then
            local _, hum = humRoot()
            if hum then hum.Sit = true end
            return known()
        elseif name == "dance" then
            local _, hum = humRoot()
            if hum then
                local animator = hum:FindFirstChildOfClass("Animator")
                if not animator then animator = Instance.new("Animator") animator.Parent = hum end
                local anim = Instance.new("Animation")
                anim.AnimationId = "rbxassetid://507771019"
                local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
                if ok and track then track.Looped = true track:Play(0.1) end
            end
            note("Dance", "ON")
            return known()
        elseif name == "fov" then
            local n = tonumber(arg)
            local cam = workspace.CurrentCamera
            if not (cam and n) then note("FOV", "Type .fov 80") return known() end
            cam.FieldOfView = math.clamp(n, 10, 120)
            note("FOV", tostring(n))
            return known()
        elseif name == "freeze" then
            local hrp, hum = humRoot()
            if hrp then hrp.Anchored = true end
            if hum then hum.WalkSpeed = 0 hum.JumpPower = 0 end
            note("Freeze", "ON")
            return known()
        elseif name == "thaw" then
            local hrp, hum = humRoot()
            if hrp then hrp.Anchored = false end
            if hum then hum.WalkSpeed = 16 hum.JumpPower = 50 end
            note("Freeze", "OFF")
            return known()
        elseif name == "heal" then
            local _, hum = humRoot()
            if hum then hum.Health = hum.MaxHealth end
            note("Heal", "Done")
            return known()
        elseif name == "noclip" then
            noclipOn = not noclipOn
            note("Noclip", noclipOn and "ON" or "OFF")
            return known()
        elseif name == "infzoom" then
            plr.CameraMaxZoomDistance = 100000
            plr.CameraMinZoomDistance = 0.5
            note("Zoom", "Unlocked")
            return known()
        elseif name == "espmenu" then
            setEsp(not espOn)
            return known()
        elseif name == "animcopier" then
            openCopier()
            return known()
        elseif name == "prismchat" then
            openPrism()
            return known()
        elseif name == "respawn" then
            pcall(function() plr:LoadCharacter() end)
            return known()
        elseif name == "re" then
            local hrp = humRoot()
            local cf = hrp and hrp.CFrame
            local conn
            conn = plr.CharacterAdded:Connect(function(char)
                if conn then conn:Disconnect() end
                local r = char:WaitForChild("HumanoidRootPart", 8)
                if r and cf then r.CFrame = cf end
            end)
            pcall(function() plr:LoadCharacter() end)
            return known()
        elseif name == "unview" then
            _G._HaloViewUser = nil
            local cam = workspace.CurrentCamera
            local _, hum = humRoot()
            if cam and hum then
                cam.CameraType = Enum.CameraType.Custom
                cam.CameraSubject = hum
            end
            note("View", "Yourself")
            return known()
        elseif name == "drop" then
            clearAttach()
            note("Dropped", "")
            return known()
        elseif name == "speed" then
            local n = tonumber(arg)
            if not n then note("Speed", "Type .speed 32") return known() end
            _G._HaloSpeedLock = n
            local _, hum = humRoot()
            if hum then hum.WalkSpeed = n end
            note("Speed", tostring(n))
            return known()
        elseif name == "jumppower" then
            local n = tonumber(arg)
            if not n then note("Jump", "Type .jumppower 80") return known() end
            _G._HaloJumpLock = n
            local _, hum = humRoot()
            if hum then hum.JumpPower = n hum.UseJumpPower = true end
            note("Jump", tostring(n))
            return known()
        elseif name == "gravity" then
            local n = tonumber(arg)
            if not n then note("Gravity", "Type .gravity 196") return known() end
            workspace.Gravity = n
            note("Gravity", tostring(n))
            return known()
        end
        local target = findPlayer(arg)
        if name == "tp" or name == "hide" or name == "unhide" or name == "view" or name == "headsit" or name == "backback" then
            if not target then note("No player", arg) return known() end
            local hrp, hum = humRoot()
            local th = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
            local thead = target.Character and target.Character:FindFirstChild("Head")
            if name == "tp" then
                doTp(target)
            elseif name == "hide" then
                applyHide(target, true)
                pcall(function() permHidePlayer(target) end)
                note("Hide", target.DisplayName)
            elseif name == "unhide" then
                applyHide(target, false)
                pcall(function() unpermHidePlayer(target) end)
                note("Unhide", target.DisplayName)
            elseif name == "view" then
                doView(target)
            elseif name == "headsit" and hrp and thead and hum then
                clearAttach()
                hum.PlatformStand = true
                local w = Instance.new("Weld")
                w.Name = "HaloAttach"
                w.Part0 = thead
                w.Part1 = hrp
                w.C0 = CFrame.new(0, 1.7, 0)
                w.Parent = hrp
                attachWeld = w
            elseif name == "backback" and hrp and th and hum then
                clearAttach()
                hum.PlatformStand = true
                local w = Instance.new("Weld")
                w.Name = "HaloAttach"
                w.Part0 = th
                w.Part1 = hrp
                w.C0 = CFrame.new(0, 0.4, 1.3)
                w.Parent = hrp
                attachWeld = w
            end
            return known()
        end
        return false
    end
    _G._HaloCmd = run

    pcall(function()
        local tcs = game:GetService("TextChatService")
        if tcs and tcs.SendingMessage then
            tcs.SendingMessage:Connect(function(message)
                local text = message and message.Text
                if type(text) == "string" and (text:sub(1, 1) == "." or text:sub(1, 1) == "?") then
                    if run(text) then
                        pcall(function() message.Text = "" end)
                    end
                end
            end)
        end
    end)

    RunService.Heartbeat:Connect(function()
        local _, hum = humRoot()
        if not hum then return end
        if type(_G._HaloSpeedLock) == "number" then hum.WalkSpeed = _G._HaloSpeedLock end
        if type(_G._HaloJumpLock) == "number" then
            hum.UseJumpPower = true
            hum.JumpPower = _G._HaloJumpLock
        end
        local watch = _G._HaloViewUser
        if watch then
            local cam = workspace.CurrentCamera
            local who = Players:GetPlayerByUserId(watch)
            local thum = who and who.Character and who.Character:FindFirstChildOfClass("Humanoid")
            if cam and thum then
                cam.CameraSubject = thum
            end
        end
        if _G._HaloSpin then
            local spinRoot = humRoot()
            if spinRoot then
                spinRoot.CFrame = spinRoot.CFrame * CFrame.Angles(0, math.rad(22), 0)
            end
        end
    end)

    plr.Chatted:Connect(function(msg)
        run(msg)
    end)

    local pg = plr:WaitForChild("PlayerGui")
    local oldGui = pg:FindFirstChild("PrismHub")
    if oldGui then oldGui:Destroy() end

    local function mount()
        local sg = Instance.new("ScreenGui")
        sg.Name = "PrismHub"
        sg.ResetOnSpawn = false
        sg.IgnoreGuiInset = true
        sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        sg.DisplayOrder = 50
        sg.Parent = pg

        local function corner(o, r)
            local c = Instance.new("UICorner")
            c.CornerRadius = r and UDim.new(0, r) or UDim.new(1, 0)
            c.Parent = o
            return c
        end
        local function stroke(o, col, th, tr)
            local s = Instance.new("UIStroke")
            s.Color = col or Color3.fromRGB(255, 255, 255)
            s.Thickness = th or 1
            s.Transparency = tr or 0.82
            s.Parent = o
            return s
        end
        local function txt(parent, text, size, x, y, w, h, bold)
            local l = Instance.new("TextLabel")
            l.BackgroundTransparency = 1
            l.Position = UDim2.fromOffset(x, y)
            l.Size = UDim2.fromOffset(w, h)
            l.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
            l.Text = text
            l.TextSize = size
            l.TextColor3 = Color3.fromRGB(255, 255, 255)
            l.TextXAlignment = Enum.TextXAlignment.Left
            l.TextYAlignment = Enum.TextYAlignment.Center
            l.ZIndex = parent.ZIndex + 1
            l.Parent = parent
            return l
        end

        local shell = Instance.new("Frame")
        shell.Name = "Shell"
        shell.AnchorPoint = Vector2.new(0.5, 0.5)
        shell.Position = UDim2.fromScale(0.5, 0.5)
        shell.Size = UDim2.fromOffset(980, 600)
        shell.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
        shell.BorderSizePixel = 0
        shell.Visible = false
        shell.ClipsDescendants = true
        shell.Parent = sg
        corner(shell, 18)
        stroke(shell, Color3.fromRGB(255, 255, 255), 1, 0.86)

        local bg = Instance.new("ImageLabel")
        bg.Name = "Bg"
        bg.BackgroundTransparency = 1
        bg.Size = UDim2.fromScale(1, 1)
        bg.ScaleType = Enum.ScaleType.Crop
        bg.ImageTransparency = 0.08
        bg.ZIndex = 1
        bg.Parent = shell
        corner(bg, 18)

        local shade = Instance.new("Frame")
        shade.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        shade.BackgroundTransparency = 0.42
        shade.Size = UDim2.fromScale(1, 1)
        shade.ZIndex = 2
        shade.BorderSizePixel = 0
        shade.Parent = shell

        local dust = Instance.new("Frame")
        dust.BackgroundTransparency = 1
        dust.Size = UDim2.fromScale(1, 1)
        dust.ZIndex = 3
        dust.ClipsDescendants = true
        dust.Parent = shell
        local motes = {}
        for i = 1, 36 do
            local p = Instance.new("Frame")
            p.AnchorPoint = Vector2.new(0.5, 0.5)
            p.Size = UDim2.fromOffset(i % 5 == 0 and 3 or 2, i % 5 == 0 and 3 or 2)
            p.Position = UDim2.fromScale(math.random(), math.random())
            p.BackgroundColor3 = (i % 4 == 0) and Color3.fromRGB(255, 170, 190) or Color3.fromRGB(255, 255, 255)
            p.BackgroundTransparency = 0.25 + (i % 5) * 0.1
            p.BorderSizePixel = 0
            p.ZIndex = 3
            p.Parent = dust
            corner(p)
            motes[i] = {f = p, x = math.random(), y = math.random(), s = 0.012 + (i % 7) * 0.004, d = (i % 2 == 0) and 1 or -1}
        end

        local sidebar = Instance.new("Frame")
        sidebar.Size = UDim2.new(0, 210, 1, 0)
        sidebar.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
        sidebar.BackgroundTransparency = 0.18
        sidebar.BorderSizePixel = 0
        sidebar.ZIndex = 5
        sidebar.Parent = shell
        local sideLine = Instance.new("Frame")
        sideLine.Size = UDim2.new(0, 1, 1, 0)
        sideLine.Position = UDim2.new(1, -1, 0, 0)
        sideLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        sideLine.BackgroundTransparency = 0.88
        sideLine.BorderSizePixel = 0
        sideLine.ZIndex = 6
        sideLine.Parent = sidebar

        local mark = Instance.new("ImageLabel")
        mark.BackgroundTransparency = 1
        mark.Size = UDim2.fromOffset(28, 28)
        mark.Position = UDim2.fromOffset(18, 22)
        mark.Image = "rbxassetid://3944373221"
        mark.ImageColor3 = Color3.fromRGB(255, 255, 255)
        mark.ZIndex = 7
        mark.Parent = sidebar
        local brand = txt(sidebar, "PRISM", 18, 54, 20, 140, 32, true)
        brand.ZIndex = 7

        local navHost = Instance.new("Frame")
        navHost.BackgroundTransparency = 1
        navHost.Position = UDim2.fromOffset(12, 78)
        navHost.Size = UDim2.new(1, -24, 1, -170)
        navHost.ZIndex = 6
        navHost.Parent = sidebar
        local navLay = Instance.new("UIListLayout", navHost)
        navLay.Padding = UDim.new(0, 2)

        local body = Instance.new("Frame")
        body.BackgroundTransparency = 1
        body.Position = UDim2.fromOffset(210, 0)
        body.Size = UDim2.new(1, -210, 1, 0)
        body.ZIndex = 5
        body.Parent = shell

        local welcome = txt(body, "Welcome, " .. plr.DisplayName, 26, 28, 22, 520, 36, true)
        welcome.ZIndex = 8
        local close = Instance.new("TextButton")
        close.Size = UDim2.fromOffset(32, 32)
        close.Position = UDim2.new(1, -46, 0, 20)
        close.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
        close.BackgroundTransparency = 0.2
        close.Text = "x"
        close.Font = Enum.Font.GothamBold
        close.TextSize = 16
        close.TextColor3 = Color3.fromRGB(230, 230, 235)
        close.ZIndex = 9
        close.Parent = body
        corner(close, 8)

        local pageHost = Instance.new("Frame")
        pageHost.BackgroundTransparency = 1
        pageHost.Position = UDim2.fromOffset(20, 74)
        pageHost.Size = UDim2.new(1, -40, 1, -96)
        pageHost.ZIndex = 6
        pageHost.Parent = body

        local function page()
            local f = Instance.new("Frame")
            f.BackgroundTransparency = 1
            f.Size = UDim2.fromScale(1, 1)
            f.Visible = false
            f.ZIndex = 6
            f.Parent = pageHost
            return f
        end
        local function card(parent, x, y, w, h)
            local f = Instance.new("Frame")
            f.Position = UDim2.fromOffset(x, y)
            f.Size = UDim2.fromOffset(w, h)
            f.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
            f.BackgroundTransparency = 0.22
            f.BorderSizePixel = 0
            f.ZIndex = 7
            f.Parent = parent
            corner(f, 16)
            stroke(f, Color3.fromRGB(255, 255, 255), 1, 0.9)
            return f
        end
        local function button(parent, text, x, y, w, h, fn)
            local b = Instance.new("TextButton")
            b.Position = UDim2.fromOffset(x, y)
            b.Size = UDim2.fromOffset(w, h)
            b.BackgroundColor3 = Color3.fromRGB(236, 236, 242)
            b.Text = text
            b.Font = Enum.Font.GothamBold
            b.TextSize = 13
            b.TextColor3 = Color3.fromRGB(12, 12, 16)
            b.AutoButtonColor = true
            b.ZIndex = 9
            b.Parent = parent
            corner(b, 10)
            b.MouseButton1Click:Connect(fn)
            return b
        end

        local pages = {}
        local navButtons = {}
        local function show(name)
            for n, f in pairs(pages) do
                f.Visible = n == name
            end
            for n, b in pairs(navButtons) do
                b.BackgroundTransparency = (n == name) and 0.55 or 1
            end
        end

        local home = page()
        pages.Home = home
        local c1 = card(home, 8, 8, 340, 200)
        txt(c1, "Server", 18, 18, 14, 280, 24, true).ZIndex = 8
        txt(c1, "Current session", 13, 18, 40, 280, 18, false).TextColor3 = Color3.fromRGB(160, 160, 168)
        local serverInfo = txt(c1, "", 14, 18, 78, 300, 90, false)
        serverInfo.TextYAlignment = Enum.TextYAlignment.Top
        serverInfo.TextWrapped = true
        serverInfo.ZIndex = 8

        local c2 = card(home, 360, 8, 340, 200)
        txt(c2, "Executor", 18, 18, 14, 280, 24, true).ZIndex = 8
        txt(c2, "exec environment", 13, 18, 40, 280, 18, false).TextColor3 = Color3.fromRGB(160, 160, 168)
        local execLbl = txt(c2, "Session", 22, 18, 90, 300, 36, true)
        execLbl.ZIndex = 8

        local c3 = card(home, 8, 220, 340, 200)
        txt(c3, "Player", 18, 18, 14, 280, 24, true).ZIndex = 8
        txt(c3, "Player stats", 13, 18, 40, 280, 18, false).TextColor3 = Color3.fromRGB(160, 160, 168)
        local playerInfo = txt(c3, "", 14, 18, 78, 300, 90, false)
        playerInfo.TextYAlignment = Enum.TextYAlignment.Top
        playerInfo.ZIndex = 8

        local c4 = card(home, 360, 220, 340, 200)
        txt(c4, "Quick", 18, 18, 14, 280, 24, true).ZIndex = 8
        txt(c4, "Open the tools", 13, 18, 40, 280, 18, false).TextColor3 = Color3.fromRGB(160, 160, 168)
        button(c4, "Reanimation", 18, 78, 146, 36, function() showMenu() end)
        button(c4, "Commands", 176, 78, 146, 36, function() show("Commands") end)
        button(c4, "Fly", 18, 126, 146, 36, function() run(".fly") end)
        button(c4, "VC Bypass", 176, 126, 146, 36, function() run(".antivcbypass") end)

        local tools = page()
        pages.Tools = tools
        local toolList = {
            {"Reanimation", function() showMenu() end},
            {"VC Bypass", function() run(".antivcbypass") end},
            {"Anti Crash", function() run(".crashbypass") end},
            {"Fly", function() run(".fly") end},
            {"Noclip", function() run(".noclip") end},
            {"Infinite Zoom", function() run(".infzoom") end},
            {"ESP", function() run(".espmenu") end},
            {"Prism Chat", function() run(".prismchat") end},
            {"Anim Copier", function() run(".animcopier") end},
            {"Rejoin", function() run(".rj") end},
        }
        for i, item in ipairs(toolList) do
            local col = (i - 1) % 2
            local row = math.floor((i - 1) / 2)
            local tcard = card(tools, 8 + col * 352, 8 + row * 78, 340, 68)
            txt(tcard, item[1], 16, 16, 18, 180, 30, true).ZIndex = 8
            button(tcard, "Open", 230, 16, 90, 36, item[2])
        end

        local cmdPage = page()
        pages.Commands = cmdPage
        local search = Instance.new("TextBox")
        search.Size = UDim2.new(1, -16, 0, 36)
        search.Position = UDim2.fromOffset(8, 4)
        search.BackgroundColor3 = Color3.fromRGB(16, 16, 18)
        search.BackgroundTransparency = 0.15
        search.Text = ""
        search.PlaceholderText = "Search commands..."
        search.PlaceholderColor3 = Color3.fromRGB(140, 140, 148)
        search.TextColor3 = Color3.new(1, 1, 1)
        search.Font = Enum.Font.Gotham
        search.TextSize = 14
        search.ClearTextOnFocus = false
        search.ZIndex = 8
        search.Parent = cmdPage
        corner(search, 10)
        stroke(search, Color3.fromRGB(255, 255, 255), 1, 0.88)
        local scroller = Instance.new("ScrollingFrame")
        scroller.Position = UDim2.fromOffset(8, 48)
        scroller.Size = UDim2.new(1, -16, 1, -56)
        scroller.BackgroundTransparency = 1
        scroller.ScrollBarThickness = 3
        scroller.BorderSizePixel = 0
        scroller.CanvasSize = UDim2.fromOffset(0, 0)
        scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scroller.ScrollingEnabled = true
        scroller.ScrollingDirection = Enum.ScrollingDirection.Y
        scroller.ZIndex = 7
        scroller.Parent = cmdPage
        local slay = Instance.new("UIListLayout", scroller)
        slay.Padding = UDim.new(0, 8)
        slay.SortOrder = Enum.SortOrder.LayoutOrder
        local spad = Instance.new("UIPadding", scroller)
        spad.PaddingBottom = UDim.new(0, 28)
        spad.PaddingRight = UDim.new(0, 4)

        local function paint()
            for _, ch in ipairs(scroller:GetChildren()) do
                if ch:IsA("Frame") then ch:Destroy() end
            end
            local q = search.Text:lower()
            local h = 0
            for _, row in ipairs(cmds) do
                if q == "" or row[1]:lower():find(q, 1, true) or row[2]:lower():find(q, 1, true) then
                    local cardf = Instance.new("Frame")
                    cardf.Size = UDim2.new(1, -8, 0, 58)
                    cardf.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
                    cardf.BackgroundTransparency = 0.2
                    cardf.ZIndex = 8
                    cardf.Parent = scroller
                    corner(cardf, 12)
                    stroke(cardf, Color3.fromRGB(255, 255, 255), 1, 0.9)
                    local bar = Instance.new("Frame")
                    bar.Size = UDim2.new(0, 3, 1, -16)
                    bar.Position = UDim2.fromOffset(10, 8)
                    bar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                    bar.BorderSizePixel = 0
                    bar.ZIndex = 9
                    bar.Parent = cardf
                    corner(bar, 2)
                    local a = txt(cardf, row[1], 14, 22, 8, 360, 22, true)
                    a.Size = UDim2.new(1, row[3] and -250 or -120, 0, 22)
                    a.TextTruncate = Enum.TextTruncate.AtEnd
                    a.ZIndex = 9
                    local b = txt(cardf, row[2], 12, 22, 30, 360, 18, false)
                    b.Size = UDim2.new(1, row[3] and -250 or -120, 0, 18)
                    b.TextTruncate = Enum.TextTruncate.AtEnd
                    b.TextColor3 = Color3.fromRGB(170, 170, 176)
                    b.ZIndex = 9
                    local argBox
                    if row[3] then
                        argBox = Instance.new("TextBox")
                        argBox.Size = UDim2.fromOffset(120, 28)
                        argBox.Position = UDim2.new(1, -214, 0.5, -14)
                        argBox.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
                        argBox.Text = ""
                        argBox.PlaceholderText = row[1]:find("value") and "value" or "player"
                        argBox.PlaceholderColor3 = Color3.fromRGB(140, 140, 148)
                        argBox.TextColor3 = Color3.new(1, 1, 1)
                        argBox.Font = Enum.Font.Gotham
                        argBox.TextSize = 12
                        argBox.ClearTextOnFocus = false
                        argBox.ZIndex = 11
                        argBox.Parent = cardf
                        corner(argBox, 8)
                    end
                    local exec = Instance.new("TextButton")
                    exec.Size = UDim2.fromOffset(78, 28)
                    exec.Position = UDim2.new(1, -88, 0.5, -14)
                    exec.BackgroundColor3 = Color3.fromRGB(236, 236, 242)
                    exec.Text = "Execute"
                    exec.TextColor3 = Color3.fromRGB(12, 12, 16)
                    exec.Font = Enum.Font.GothamBold
                    exec.TextSize = 12
                    exec.ZIndex = 11
                    exec.Parent = cardf
                    corner(exec, 8)
                    local cmdName = row[1]
                    local needsArg = row[3]
                    exec.MouseButton1Click:Connect(function()
                        local ok, err = pcall(function()
                            local base = cmdName:match("^(%S+)") or cmdName
                            if needsArg then
                                local extra = argBox and argBox.Text:gsub("^%s+", ""):gsub("%s+$", "") or ""
                                if extra == "" then
                                    note("Command", "Type a " .. (argBox.PlaceholderText or "value"))
                                    return
                                end
                                run(base .. " " .. extra)
                            else
                                run(base)
                            end
                        end)
                        if not ok then note("Command", tostring(err)) end
                    end)
                    h = h + 66
                end
            end
            scroller.CanvasSize = UDim2.fromOffset(0, math.max(h, 66))
        end
        search:GetPropertyChangedSignal("Text"):Connect(paint)
        paint()

        local playersPage = page()
        pages.Players = playersPage
        local plist = Instance.new("ScrollingFrame")
        plist.Position = UDim2.fromOffset(0, 40)
        plist.Size = UDim2.new(1, 0, 1, -40)
        plist.BackgroundTransparency = 1
        plist.ScrollBarThickness = 4
        plist.BorderSizePixel = 0
        plist.CanvasSize = UDim2.fromOffset(0, 0)
        plist.AutomaticCanvasSize = Enum.AutomaticSize.Y
        plist.ZIndex = 7
        plist.Parent = playersPage
        local play = Instance.new("UIListLayout", plist)
        play.Padding = UDim.new(0, 8)
        local emptyLbl = txt(playersPage, "", 14, 140, 8, 400, 24, false)
        emptyLbl.TextColor3 = Color3.fromRGB(160, 160, 168)
        emptyLbl.ZIndex = 8
        local function refreshPlayers()
            for _, ch in ipairs(plist:GetChildren()) do
                if ch:IsA("Frame") then ch:Destroy() end
            end
            local count = 0
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= plr then
                    count = count + 1
                    local who = p
                    local rowf = Instance.new("Frame")
                    rowf.Size = UDim2.new(1, -12, 0, 92)
                    rowf.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
                    rowf.BackgroundTransparency = 0.15
                    rowf.ZIndex = 8
                    rowf.Parent = plist
                    corner(rowf, 12)
                    stroke(rowf, Color3.fromRGB(255, 255, 255), 1, 0.9)
                    local av = Instance.new("ImageLabel")
                    av.Size = UDim2.fromOffset(44, 44)
                    av.Position = UDim2.fromOffset(12, 10)
                    av.BackgroundColor3 = Color3.fromRGB(30, 30, 34)
                    av.Image = "rbxthumb://type=AvatarHeadShot&id=" .. who.UserId .. "&w=150&h=150"
                    av.ZIndex = 9
                    av.Parent = rowf
                    corner(av)
                    local nm = txt(rowf, who.DisplayName, 15, 66, 8, 400, 22, true)
                    nm.ZIndex = 9
                    local un = txt(rowf, "@" .. who.Name, 12, 66, 30, 400, 16, false)
                    un.TextColor3 = Color3.fromRGB(160, 160, 168)
                    un.ZIndex = 9
                    local function act(label, x, fn)
                        local b = Instance.new("TextButton")
                        b.Position = UDim2.fromOffset(x, 54)
                        b.Size = UDim2.fromOffset(120, 28)
                        b.BackgroundColor3 = Color3.fromRGB(236, 236, 242)
                        b.Text = label
                        b.Font = Enum.Font.GothamBold
                        b.TextSize = 13
                        b.TextColor3 = Color3.fromRGB(12, 12, 16)
                        b.AutoButtonColor = true
                        b.Active = true
                        b.ZIndex = 20
                        b.Parent = rowf
                        corner(b, 8)
                        b.MouseButton1Click:Connect(fn)
                    end
                    act("TP", 12, function() doTp(who) end)
                    act("View", 140, function() doView(who) end)
                    act("Hide", 268, function()
                        applyHide(who, true)
                        note("Hide", who.DisplayName)
                    end)
                    act("Show", 396, function()
                        applyHide(who, false)
                        note("Show", who.DisplayName)
                    end)
                end
            end
            emptyLbl.Text = count == 0 and "No other players in this server." or (count .. " players")
        end
        button(playersPage, "Refresh", 8, 4, 110, 30, refreshPlayers)
        refreshPlayers()
        Players.PlayerAdded:Connect(function()
            task.wait(0.4)
            refreshPlayers()
        end)
        Players.PlayerRemoving:Connect(function()
            task.wait(0.2)
            refreshPlayers()
        end)

        local rePage = page()
        pages.Reanim = rePage
        local rc = card(rePage, 8, 8, 692, 220)
        txt(rc, "Reanimation", 22, 22, 20, 400, 30, true).ZIndex = 8
        local rd = txt(rc, "Open the reanimation menu. Idle, walk, run, and jump play from the states tab.", 14, 22, 60, 500, 50, false)
        rd.TextWrapped = true
        rd.TextColor3 = Color3.fromRGB(180, 180, 186)
        rd.ZIndex = 8
        button(rc, "Open reanimation", 22, 140, 200, 42, function() showMenu() end)

        local function buildExtra()
            local function makeArea(name)
                local pg = page()
                pages[name] = pg
                local scroller = Instance.new("ScrollingFrame")
                scroller.Size = UDim2.fromScale(1, 1)
                scroller.BackgroundTransparency = 1
                scroller.ScrollBarThickness = 4
                scroller.BorderSizePixel = 0
                scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
                scroller.CanvasSize = UDim2.fromOffset(0, 0)
                scroller.ZIndex = 7
                scroller.Parent = pg
                local stack = Instance.new("UIListLayout", scroller)
                stack.Padding = UDim.new(0, 10)
                stack.SortOrder = Enum.SortOrder.LayoutOrder
                local pad = Instance.new("UIPadding", scroller)
                pad.PaddingTop = UDim.new(0, 4)
                pad.PaddingBottom = UDim.new(0, 12)
                pad.PaddingLeft = UDim.new(0, 4)
                pad.PaddingRight = UDim.new(0, 4)
                return scroller
            end
            local resArea = makeArea("Resolution")
            local visArea = makeArea("Visuals")
            local extraArea = makeArea("Extras")
            local areaHost = resArea
            local sc = resArea
            local order = 0
            local function section(h)
                order = order + 1
                local f = Instance.new("Frame")
                f.LayoutOrder = order
                f.Size = UDim2.new(1, -8, 0, h)
                f.BackgroundColor3 = Color3.fromRGB(16, 16, 18)
                f.BackgroundTransparency = 0.16
                f.BorderSizePixel = 0
                f.ZIndex = 8
                f.Parent = areaHost
                corner(f, 14)
                stroke(f, Color3.fromRGB(255, 255, 255), 1, 0.9)
                return f
            end
            local function heading(parent, title, sub)
                local t = txt(parent, title, 16, 16, 12, 640, 22, true)
                t.ZIndex = 9
                local s = txt(parent, sub, 12, 16, 34, 660, 16, false)
                s.TextColor3 = Color3.fromRGB(158, 158, 166)
                s.ZIndex = 9
            end
            local function input(parent, x, y, w, placeholder)
                local box = Instance.new("TextBox")
                box.Position = UDim2.fromOffset(x, y)
                box.Size = UDim2.fromOffset(w, 32)
                box.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
                box.Text = ""
                box.PlaceholderText = placeholder or ""
                box.PlaceholderColor3 = Color3.fromRGB(130, 130, 138)
                box.TextColor3 = Color3.new(1, 1, 1)
                box.Font = Enum.Font.Gotham
                box.TextSize = 13
                box.ClearTextOnFocus = false
                box.ZIndex = 10
                box.Parent = parent
                corner(box, 8)
                return box
            end

            local resCard = section(214)
            heading(resCard, "Resolution", "normal PC sizes, ultrawide, then max stretch")
            local resHost = Instance.new("Frame")
            resHost.BackgroundTransparency = 1
            resHost.Position = UDim2.fromOffset(14, 58)
            resHost.Size = UDim2.new(1, -28, 0, 144)
            resHost.ZIndex = 9
            resHost.Parent = resCard
            local resGrid = Instance.new("UIGridLayout", resHost)
            resGrid.CellSize = UDim2.fromOffset(156, 30)
            resGrid.CellPadding = UDim2.fromOffset(8, 8)
            resGrid.SortOrder = Enum.SortOrder.LayoutOrder
            local baseAspect = 16 / 9
            local function fromPixels(w, h)
                return (w / h) / baseAspect
            end
            local presets = {
                {"1280x720", 1280, 720, 1},
                {"1366x768", 1366, 768, 1},
                {"1600x900", 1600, 900, 1},
                {"1920x1080", 1920, 1080, 1},
                {"2560x1440", 2560, 1440, 1},
                {"3840x2160", 3840, 2160, 1},
                {"1680x1050", 1680, 1050, 0.9},
                {"2560x1080", 2560, 1080, 0.72},
                {"3440x1440", 3440, 1440, 0.7},
                {"5120x1440", 5120, 1440, 0.48},
                {"Max stretch", 1, 1, 0.3},
                {"Native", 0, 0, 1},
            }
            local function applyWindow(w, h)
                local function attempt(fn)
                    if type(fn) ~= "function" then return false end
                    local ok = pcall(fn, w, h)
                    if ok then return true end
                    ok = pcall(fn, Vector2.new(w, h))
                    return ok
                end
                if attempt(setwindowsize) or attempt(setresolution) then return true end
                if type(syn) == "table" and attempt(syn.set_window_size) then return true end
                if type(fluxus) == "table" and attempt(fluxus.set_window_size) then return true end
                return false
            end
            local resButtons = {}
            local function paintRes(name)
                for n, b in pairs(resButtons) do
                    local on = n == name
                    b.BackgroundColor3 = on and Color3.fromRGB(236, 236, 242) or Color3.fromRGB(32, 32, 36)
                    b.TextColor3 = on and Color3.fromRGB(12, 12, 16) or Color3.fromRGB(230, 230, 235)
                end
            end
            for i, preset in ipairs(presets) do
                local b = Instance.new("TextButton")
                b.LayoutOrder = i
                b.BackgroundColor3 = Color3.fromRGB(32, 32, 36)
                b.Text = preset[1]
                b.Font = Enum.Font.GothamBold
                b.TextSize = 12
                b.TextColor3 = Color3.fromRGB(230, 230, 235)
                b.AutoButtonColor = false
                b.ZIndex = 10
                b.Parent = resHost
                corner(b, 8)
                resButtons[preset[1]] = b
                local label, w, h, yScale = preset[1], preset[2], preset[3], preset[4]
                b.MouseButton1Click:Connect(function()
                    paintRes(label)
                    if label == "Native" or yScale >= 0.98 then
                        _G._HaloStretchCF = nil
                        local cam = workspace.CurrentCamera
                        if cam then cam.FieldOfView = 70 end
                        if w > 1 then applyWindow(w, h) end
                        note("Resolution", label == "Native" and "Native" or (label .. "  normal"))
                        return
                    end
                    _G._HaloStretchCF = CFrame.new(0, 0, 0, 1, 0, 0, 0, yScale, 0, 0, 0, 1)
                    applyWindow(w, h)
                    note("Resolution", label)
                end)
            end

            areaHost = visArea
            local transCard = section(108)
            heading(transCard, "Transparency", "Local character only. 0 is solid, 1 is invisible.")
            local transBox = input(transCard, 16, 60, 220, "0 to 1")
            button(transCard, "Apply", 248, 60, 90, 32, function()
                local n = tonumber(transBox.Text)
                if not n then note("Transparency", "Type 0 to 1") return end
                _G._HaloCharTrans = math.clamp(n, 0, 1)
                note("Transparency", tostring(_G._HaloCharTrans))
            end)

            local shadeCard = section(108)
            heading(shadeCard, "Shaders", "Bloom, color, and sun rays. Saturation is optional.")
            local satBox = input(shadeCard, 16, 60, 160, "saturation")
            satBox.Text = "0.2"
            local function setShaders(on)
                local Lighting = game:GetService("Lighting")
                for _, name in ipairs({"PrismBloom", "PrismColor", "PrismBlur", "PrismRays"}) do
                    local old = Lighting:FindFirstChild(name)
                    if old then old:Destroy() end
                end
                if not on then note("Shaders", "Off") return end
                local bloom = Instance.new("BloomEffect")
                bloom.Name = "PrismBloom"
                bloom.Intensity = 0.7
                bloom.Size = 22
                bloom.Threshold = 0.85
                bloom.Parent = Lighting
                local cc = Instance.new("ColorCorrectionEffect")
                cc.Name = "PrismColor"
                cc.Saturation = tonumber(satBox.Text) or 0.2
                cc.Contrast = 0.08
                cc.TintColor = Color3.fromRGB(255, 236, 240)
                cc.Parent = Lighting
                local blur = Instance.new("BlurEffect")
                blur.Name = "PrismBlur"
                blur.Size = 0
                blur.Parent = Lighting
                local rays = Instance.new("SunRaysEffect")
                rays.Name = "PrismRays"
                rays.Intensity = 0.06
                rays.Spread = 0.6
                rays.Parent = Lighting
                note("Shaders", "On")
            end
            button(shadeCard, "On", 188, 60, 80, 32, function() setShaders(true) end)
            button(shadeCard, "Off", 276, 60, 80, 32, function() setShaders(false) end)

            areaHost = extraArea
            local botCard = section(96)
            heading(botCard, "Mic Up bots", "Brings non-player characters to you and fires bot remotes.")
            button(botCard, "Bring to me", 16, 58, 140, 28, function()
                local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                if not hrp then note("Bots", "No character") return end
                local moved = 0
                for _, m in ipairs(workspace:GetChildren()) do
                    if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") and not Players:GetPlayerFromCharacter(m) then
                        local root = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
                        if root and root:IsA("BasePart") then
                            root.CFrame = hrp.CFrame * CFrame.new((moved % 4) * 3, 0, -4 - math.floor(moved / 4) * 3)
                            moved = moved + 1
                        end
                    end
                end
                for _, r in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
                    if r:IsA("RemoteEvent") and r.Name:lower():find("bot") then
                        pcall(function() r:FireServer() end)
                        pcall(function() r:FireServer("main") end)
                    end
                end
                note("Bots", moved > 0 and ("Moved " .. moved) or "Fired bot remotes")
            end)

            local afkCard = section(96)
            heading(afkCard, "Drift AFK", "Clicks and jumps on a timer so the drift game doesn't idle you.")
            button(afkCard, "Toggle AFK", 16, 58, 130, 28, function()
                _G._HaloDriftAFK = not _G._HaloDriftAFK
                note("AFK", _G._HaloDriftAFK and "ON" or "OFF")
            end)

            local snakeCard = section(96)
            heading(snakeCard, "Snake", "A local trail that follows your cursor. Only you can see it.")
            button(snakeCard, "Toggle snake", 16, 58, 140, 28, function()
                _G._HaloSnake = not _G._HaloSnake
                note("Snake", _G._HaloSnake and "ON" or "OFF")
            end)

            local r6Card = section(96)
            heading(r6Card, "R6 anims", "Puts the normal R6 idle, walk, and jump on your character.")
            button(r6Card, "Apply R6", 16, 58, 120, 28, function()
                local ids = {
                    idle = "rbxassetid://180435571",
                    walk = "rbxassetid://180426354",
                    run = "rbxassetid://180426354",
                    jump = "rbxassetid://125750702",
                    fall = "rbxassetid://180436148",
                    climb = "rbxassetid://180436334",
                    sit = "rbxassetid://178130996",
                }
                local function apply(char)
                    if not char then return end
                    local animate = char:FindFirstChild("Animate")
                    if animate then
                        for name, id in pairs(ids) do
                            local folder = animate:FindFirstChild(name)
                            if folder then
                                for _, anim in ipairs(folder:GetChildren()) do
                                    if anim:IsA("Animation") then anim.AnimationId = id end
                                end
                            end
                        end
                    end
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    local animator = hum and hum:FindFirstChildOfClass("Animator")
                    if animator then
                        local anim = Instance.new("Animation")
                        anim.AnimationId = ids.idle
                        local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
                        if ok and track then track.Looped = true track:Play(0.2) end
                    end
                end
                apply(plr.Character)
                pcall(function()
                    local api = rawget(_G, "_HaloReanimateAPI") or rawget(_G, "ReanimateAPI")
                    if api and api.get_real_character then apply(api.get_real_character(plr)) end
                    if api and api.get_clone then apply(api.get_clone(plr)) end
                end)
                note("R6", "Applied")
            end)

            local posCard = section(210)
            heading(posCard, "Position saver", "Save a spot, then click it to go back.")
            local posName = input(posCard, 16, 58, 280, "name this spot")
            local posList = Instance.new("ScrollingFrame")
            posList.Position = UDim2.fromOffset(16, 100)
            posList.Size = UDim2.new(1, -32, 0, 96)
            posList.BackgroundTransparency = 1
            posList.ScrollBarThickness = 3
            posList.BorderSizePixel = 0
            posList.AutomaticCanvasSize = Enum.AutomaticSize.Y
            posList.CanvasSize = UDim2.fromOffset(0, 0)
            posList.ZIndex = 9
            posList.Parent = posCard
            local posLay = Instance.new("UIListLayout", posList)
            posLay.Padding = UDim.new(0, 4)
            _G._HaloPositions = _G._HaloPositions or {}
            local function redrawPos()
                for _, c in ipairs(posList:GetChildren()) do
                    if c:IsA("TextButton") then c:Destroy() end
                end
                for _, spot in ipairs(_G._HaloPositions) do
                    local b = Instance.new("TextButton")
                    b.Size = UDim2.new(1, -4, 0, 26)
                    b.BackgroundColor3 = Color3.fromRGB(236, 236, 242)
                    b.Text = "Go   " .. spot.name
                    b.Font = Enum.Font.GothamBold
                    b.TextSize = 12
                    b.TextColor3 = Color3.fromRGB(12, 12, 16)
                    b.ZIndex = 10
                    b.Parent = posList
                    corner(b, 6)
                    b.MouseButton1Click:Connect(function()
                        local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                        if hrp and spot.cf then hrp.CFrame = spot.cf end
                    end)
                end
            end
            button(posCard, "Save spot", 308, 58, 110, 32, function()
                local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                if not hrp then return end
                local name = posName.Text
                if name == "" then name = "Spot " .. (#_G._HaloPositions + 1) end
                table.insert(_G._HaloPositions, { name = name, cf = hrp.CFrame })
                redrawPos()
                note("Saved", name)
            end)

            local execCard = section(196)
            heading(execCard, "Internal executor", "Run Lua, save it, or download a URL into PrismWorkspace.")
            local codeBox = Instance.new("TextBox")
            codeBox.Position = UDim2.fromOffset(16, 58)
            codeBox.Size = UDim2.new(1, -32, 0, 78)
            codeBox.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
            codeBox.Text = ""
            codeBox.PlaceholderText = "lua to run, or a raw url to download"
            codeBox.PlaceholderColor3 = Color3.fromRGB(130, 130, 138)
            codeBox.TextColor3 = Color3.new(1, 1, 1)
            codeBox.Font = Enum.Font.Code
            codeBox.TextSize = 13
            codeBox.ClearTextOnFocus = false
            codeBox.TextXAlignment = Enum.TextXAlignment.Left
            codeBox.TextYAlignment = Enum.TextYAlignment.Top
            codeBox.MultiLine = true
            codeBox.ZIndex = 10
            codeBox.Parent = execCard
            corner(codeBox, 8)
            button(execCard, "Run", 16, 148, 80, 30, function()
                local src = codeBox.Text
                local fn, err = loadstring(src)
                if not fn then note("Exec", tostring(err)) return end
                task.spawn(function()
                    local ok, e = pcall(fn)
                    if not ok then note("Exec", tostring(e)) end
                end)
            end)
            button(execCard, "Save", 104, 148, 80, 30, function()
                if type(writefile) ~= "function" then note("Save", "No writefile") return end
                pcall(function() if makefolder then makefolder("PrismWorkspace") end end)
                local ok = pcall(function() writefile("PrismWorkspace/code.lua", codeBox.Text) end)
                note("Save", ok and "PrismWorkspace/code.lua" or "Failed")
            end)
            button(execCard, "Download", 192, 148, 110, 30, function()
                local url = codeBox.Text:gsub("%s+", "")
                if not url:find("^https?://") then note("Download", "Paste a url") return end
                task.spawn(function()
                    local body
                    pcall(function() body = game:HttpGet(url) end)
                    if type(body) ~= "string" or body == "" then note("Download", "Failed") return end
                    if type(writefile) ~= "function" then note("Download", "No writefile") return end
                    pcall(function() if makefolder then makefolder("PrismWorkspace") end end)
                    local ok = pcall(function() writefile("PrismWorkspace/download.lua", body) end)
                    note("Download", ok and "Saved download.lua" or "Failed")
                end)
            end)

            local snakeParts = {}
            local function clearSnake()
                for _, p in ipairs(snakeParts) do pcall(function() p:Destroy() end) end
                table.clear(snakeParts)
            end
            pcall(function() RunService:UnbindFromRenderStep("PrismResolution") end)
            RunService:BindToRenderStep("PrismResolution", Enum.RenderPriority.Last.Value, function()
                local cam = workspace.CurrentCamera
                local extra = _G._HaloStretchCF
                if cam and typeof(extra) == "CFrame" then
                    cam.CFrame = cam.CFrame * extra
                end
            end)
            pcall(function() RunService:UnbindFromRenderStep("PrismExtras") end)
            RunService:BindToRenderStep("PrismExtras", Enum.RenderPriority.Camera.Value + 1, function()
                local cam = workspace.CurrentCamera
                if _G._HaloSnake then
                    if #snakeParts == 0 and cam then
                        for i = 1, 22 do
                            local p = Instance.new("Part")
                            p.Name = "PrismSnake"
                            p.Anchored = true
                            p.CanCollide = false
                            p.CanQuery = false
                            p.CanTouch = false
                            p.Material = Enum.Material.Neon
                            p.Color = Color3.fromRGB(255, math.clamp(255 - i * 8, 40, 255), 255)
                            p.Size = Vector3.new(0.45, 0.45, 0.45)
                            p.Parent = cam
                            snakeParts[i] = p
                        end
                    end
                    local mouse = plr:GetMouse()
                    local hit = mouse and mouse.Hit and mouse.Hit.Position
                    if hit then
                        _G._HaloSnakeTrail = _G._HaloSnakeTrail or {}
                        local trail = _G._HaloSnakeTrail
                        table.insert(trail, 1, hit)
                        while #trail > #snakeParts do table.remove(trail) end
                        for i, p in ipairs(snakeParts) do
                            p.CFrame = CFrame.new(trail[i] or hit)
                        end
                    end
                elseif #snakeParts > 0 then
                    _G._HaloSnakeTrail = nil
                    clearSnake()
                end
            end)
            local afkClock = 0
            task.spawn(function()
                while true do
                    task.wait(0.4)
                    local n = _G._HaloCharTrans
                    if type(n) == "number" then
                        local chars = {}
                        if plr.Character then table.insert(chars, plr.Character) end
                        local clone = workspace:FindFirstChild("Reanimation")
                        if clone then table.insert(chars, clone) end
                        for _, char in ipairs(chars) do
                            for _, d in ipairs(char:GetDescendants()) do
                                if d:IsA("BasePart") then
                                    d.LocalTransparencyModifier = n
                                end
                            end
                        end
                    end
                    afkClock = afkClock + 0.4
                    if _G._HaloDriftAFK and afkClock >= 20 then
                        afkClock = 0
                        pcall(function()
                            local vu = game:GetService("VirtualUser")
                            vu:CaptureController()
                            vu:ClickButton2(Vector2.new())
                        end)
                        local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
                        if hum then hum.Jump = true end
                        pcall(function()
                            for _, r in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
                                if r:IsA("RemoteEvent") and r.Name:lower():find("afk") then
                                    r:FireServer(true)
                                end
                            end
                        end)
                    end
                end
            end)
        end
        buildExtra()

        local function saveAuto()
            pcall(function()
                if type(writefile) ~= "function" then return end
                writefile("PrismAutoExec.json", game:GetService("HttpService"):JSONEncode(autoexec))
            end)
        end
        local autoActs = {
            {"vc", "VC Bypass", "Turn VC bypass on when the script loads", function()
                pcall(function()
                    if type(_G._PrismEnableShieldVC) == "function" then _G._PrismEnableShieldVC() end
                end)
            end},
            {"crash", "Anti Crash", "Turn anti crash on when the script loads", function()
                _G._HaloAntiCrash = true
                note("Anti crash", "ON")
            end},
            {"fly", "Fly", "Start flying when the script loads", function() setFly(true) end},
            {"noclip", "Noclip", "Walk through walls when the script loads", function()
                noclipOn = true
                note("Noclip", "ON")
            end},
            {"esp", "ESP", "Highlight players when the script loads", function() setEsp(true) end},
            {"zoom", "Infinite Zoom", "Unlock zoom when the script loads", function()
                plr.CameraMaxZoomDistance = 100000
                plr.CameraMinZoomDistance = 0.5
            end},
            {"night", "Night", "Set the time to night", function()
                game:GetService("Lighting").ClockTime = 0
            end},
            {"bright", "Fullbright", "Brighten the world", function()
                local L = game:GetService("Lighting")
                L.Brightness = 2
                L.ClockTime = 14
                L.FogEnd = 100000
                L.GlobalShadows = false
                L.OutdoorAmbient = Color3.new(1, 1, 1)
            end},
            {"invis", "Invisible", "Hide your character", function()
                _G._HaloCharTrans = 1
            end},
            {"spin", "Spin", "Spin when the script loads", function()
                _G._HaloSpin = true
            end},
            {"reanim", "Open Reanimate", "Open the reanimate menu", function() showMenu() end},
            {"chat", "Prism Chat", "Open the chat box", function() openPrism() end},
        }
        local autoPage = page()
        pages.Auto = autoPage
        local autoHead = txt(autoPage, "Auto Execute", 22, 8, 0, 400, 28, true)
        autoHead.ZIndex = 8
        local autoSub = txt(autoPage, "Turn these on and they run by themselves next time the script loads.", 13, 8, 28, 640, 18, false)
        autoSub.TextColor3 = Color3.fromRGB(160, 160, 168)
        autoSub.ZIndex = 8
        local autoScroll = Instance.new("ScrollingFrame")
        autoScroll.Position = UDim2.fromOffset(0, 56)
        autoScroll.Size = UDim2.new(1, 0, 1, -56)
        autoScroll.BackgroundTransparency = 1
        autoScroll.ScrollBarThickness = 4
        autoScroll.BorderSizePixel = 0
        autoScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        autoScroll.CanvasSize = UDim2.fromOffset(0, 0)
        autoScroll.ZIndex = 7
        autoScroll.Parent = autoPage
        local autoLay = Instance.new("UIListLayout", autoScroll)
        autoLay.Padding = UDim.new(0, 8)
        local autoPad = Instance.new("UIPadding", autoScroll)
        autoPad.PaddingBottom = UDim.new(0, 20)
        autoPad.PaddingRight = UDim.new(0, 6)
        for _, item in ipairs(autoActs) do
            local id, name, desc, fn = item[1], item[2], item[3], item[4]
            local rowf = Instance.new("Frame")
            rowf.Size = UDim2.new(1, -8, 0, 64)
            rowf.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
            rowf.BackgroundTransparency = 0.2
            rowf.ZIndex = 8
            rowf.Parent = autoScroll
            corner(rowf, 12)
            stroke(rowf, Color3.fromRGB(255, 255, 255), 1, 0.9)
            local a = txt(rowf, name, 15, 16, 8, 420, 22, true)
            a.ZIndex = 9
            local b = txt(rowf, desc, 12, 16, 32, 460, 18, false)
            b.TextColor3 = Color3.fromRGB(160, 160, 168)
            b.ZIndex = 9
            local tog = Instance.new("TextButton")
            tog.Size = UDim2.fromOffset(74, 30)
            tog.Position = UDim2.new(1, -90, 0.5, -15)
            tog.Font = Enum.Font.GothamBold
            tog.TextSize = 13
            tog.ZIndex = 10
            tog.Parent = rowf
            corner(tog, 8)
            local function paintToggle()
                local on = autoexec[id] == true
                tog.Text = on and "ON" or "OFF"
                tog.BackgroundColor3 = on and Color3.fromRGB(255, 70, 100) or Color3.fromRGB(236, 236, 242)
                tog.TextColor3 = on and Color3.new(1, 1, 1) or Color3.fromRGB(12, 12, 16)
            end
            paintToggle()
            tog.MouseButton1Click:Connect(function()
                autoexec[id] = not (autoexec[id] == true)
                saveAuto()
                paintToggle()
                if autoexec[id] then
                    pcall(fn)
                    note("Auto Execute", name .. " on")
                else
                    note("Auto Execute", name .. " off next load")
                end
            end)
        end
        task.delay(1.5, function()
            for _, item in ipairs(autoActs) do
                if autoexec[item[1]] == true then
                    pcall(item[4])
                end
            end
        end)

        local navItems = {
            {"Home", "Home"},
            {"Reanimate", "Reanim"},
            {"Commands", "Commands"},
            {"Players", "Players"},
            {"Auto Execute", "Auto"},
            {"Resolution", "Resolution"},
            {"Visuals", "Visuals"},
            {"Extras", "Extras"},
            {"Tools", "Tools"},
        }
        for _, item in ipairs(navItems) do
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(1, 0, 0, 26)
            b.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            b.BackgroundTransparency = 1
            b.Text = "   " .. item[1]
            b.Font = Enum.Font.Gotham
            b.TextSize = 14
            b.TextColor3 = Color3.fromRGB(230, 230, 235)
            b.TextXAlignment = Enum.TextXAlignment.Left
            b.ZIndex = 7
            b.Parent = navHost
            corner(b, 8)
            navButtons[item[2]] = b
            b.MouseButton1Click:Connect(function()
                if item[2] == "Players" then refreshPlayers() end
                show(item[2])
            end)
        end

        local foot = Instance.new("Frame")
        foot.Size = UDim2.new(1, -16, 0, 64)
        foot.Position = UDim2.new(0, 8, 1, -76)
        foot.BackgroundTransparency = 1
        foot.ZIndex = 7
        foot.Parent = sidebar
        local head = Instance.new("ImageLabel")
        head.Size = UDim2.fromOffset(40, 40)
        head.Position = UDim2.fromOffset(8, 12)
        head.BackgroundTransparency = 1
        head.Image = "rbxthumb://type=AvatarHeadShot&id=" .. plr.UserId .. "&w=150&h=150"
        head.ZIndex = 8
        head.Parent = foot
        corner(head)
        local dn = txt(foot, plr.DisplayName, 13, 56, 12, 140, 18, true)
        dn.ZIndex = 8
        local un = txt(foot, "@" .. plr.Name, 11, 56, 32, 140, 16, false)
        un.TextColor3 = Color3.fromRGB(150, 150, 158)
        un.ZIndex = 8

        local function fillStats()
            local ping = ""
            pcall(function()
                local ms = math.floor(plr:GetNetworkPing() * 1000)
                ping = "Latency: " .. ms .. "ms"
            end)
            serverInfo.Text = "Players: " .. #Players:GetPlayers() .. "/" .. tostring(Players.MaxPlayers)
                .. "\nPlace: " .. tostring(game.PlaceId)
                .. (ping ~= "" and ("\n" .. ping) or "")
            playerInfo.Text = "Account age: " .. tostring(plr.AccountAge) .. " days\nUser ID: " .. tostring(plr.UserId)
            local exec = "Session"
            pcall(function()
                if type(identifyexecutor) == "function" then
                    exec = identifyexecutor()
                elseif type(getexecutorname) == "function" then
                    exec = getexecutorname()
                end
            end)
            execLbl.Text = tostring(exec)
        end

        local loader = Instance.new("Frame")
        loader.Name = "Loader"
        loader.AnchorPoint = Vector2.new(0.5, 0.5)
        loader.Position = UDim2.fromScale(0.5, 0.5)
        loader.Size = UDim2.fromOffset(460, 280)
        loader.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
        loader.BorderSizePixel = 0
        loader.ClipsDescendants = true
        loader.ZIndex = 20
        loader.Parent = sg
        corner(loader, 18)
        stroke(loader, Color3.fromRGB(255, 255, 255), 1, 0.8)
        local lbg = bg:Clone()
        lbg.ZIndex = 20
        lbg.Parent = loader
        local lshade = Instance.new("Frame")
        lshade.Size = UDim2.fromScale(1, 1)
        lshade.BackgroundColor3 = Color3.new(0, 0, 0)
        lshade.BackgroundTransparency = 0.35
        lshade.BorderSizePixel = 0
        lshade.ZIndex = 21
        lshade.Parent = loader
        local orb = Instance.new("ImageLabel")
        orb.AnchorPoint = Vector2.new(0.5, 0.5)
        orb.Position = UDim2.new(0.5, 0, 0, 78)
        orb.Size = UDim2.fromOffset(72, 72)
        orb.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
        orb.BackgroundTransparency = 0.2
        orb.Image = "rbxassetid://3944373221"
        orb.ScaleType = Enum.ScaleType.Crop
        orb.ZIndex = 23
        orb.Parent = loader
        corner(orb)
        stroke(orb, Color3.fromRGB(255, 255, 255), 1.5, 0.4)
        local lt = txt(loader, "PRISM", 22, 0, 124, 460, 30, true)
        lt.TextXAlignment = Enum.TextXAlignment.Center
        lt.ZIndex = 23
        local status = txt(loader, "starting", 13, 0, 156, 460, 20, false)
        status.TextXAlignment = Enum.TextXAlignment.Center
        status.TextColor3 = Color3.fromRGB(180, 180, 186)
        status.ZIndex = 23
        local track = Instance.new("Frame")
        track.AnchorPoint = Vector2.new(0.5, 0)
        track.Position = UDim2.new(0.5, 0, 0, 200)
        track.Size = UDim2.fromOffset(280, 4)
        track.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        track.BackgroundTransparency = 0.8
        track.BorderSizePixel = 0
        track.ZIndex = 23
        track.Parent = loader
        corner(track, 4)
        local fill = Instance.new("Frame")
        fill.Size = UDim2.fromScale(0, 1)
        fill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        fill.BorderSizePixel = 0
        fill.ZIndex = 24
        fill.Parent = track
        corner(fill, 4)

        local dockIcon
        local function applyImage(img)
            if not img or img == "" then return end
            bg.Image = img
            lbg.Image = img
            orb.Image = img
            mark.Image = img
            mark.ImageColor3 = Color3.new(1, 1, 1)
            if dockIcon then
                dockIcon.Image = img
            end
        end

        local dock = Instance.new("TextButton")
        dock.AnchorPoint = Vector2.new(1, 1)
        dock.Position = UDim2.new(1, -28, 1, -28)
        dock.Size = UDim2.fromOffset(68, 68)
        dock.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
        dock.Text = ""
        dock.AutoButtonColor = false
        dock.ZIndex = 40
        dock.Parent = sg
        corner(dock)
        stroke(dock, Color3.fromRGB(255, 255, 255), 1.6, 0.25)
        dockIcon = Instance.new("ImageLabel")
        dockIcon.Size = UDim2.fromScale(1, 1)
        dockIcon.BackgroundTransparency = 1
        dockIcon.Image = "rbxassetid://3944373221"
        dockIcon.ScaleType = Enum.ScaleType.Crop
        dockIcon.ZIndex = 41
        dockIcon.Parent = dock
        corner(dockIcon)
        local ring = Instance.new("Frame")
        ring.AnchorPoint = Vector2.new(0.5, 0.5)
        ring.Position = UDim2.fromScale(0.5, 0.5)
        ring.Size = UDim2.fromOffset(78, 78)
        ring.BackgroundTransparency = 1
        ring.ZIndex = 39
        ring.Parent = dock
        local rs = stroke(ring, Color3.fromRGB(255, 255, 255), 1, 0.45)
        corner(ring)

        local function toggle()
            if loader.Visible then return end
            shell.Visible = not shell.Visible
        end
        dock.MouseButton1Click:Connect(toggle)
        close.MouseButton1Click:Connect(function() shell.Visible = false end)

        task.spawn(function()
            for _ = 1, 25 do
                local img
                pcall(function()
                    if Menu then
                        local custom = Menu:FindFirstChild("CustomBackground")
                        if custom and custom:IsA("ImageLabel") and custom.Image ~= "" then
                            img = custom.Image
                        end
                    end
                end)
                if not img then
                    pcall(function()
                        local get_asset = getcustomasset or getsynasset
                        if type(get_asset) == "function" and isfile and isfile("ReanimData/cyris_menu_bg.jpg") then
                            img = get_asset("ReanimData/cyris_menu_bg.jpg")
                        end
                    end)
                end
                if img then applyImage(img) break end
                task.wait(0.35)
            end
        end)

        local steps = {"loading core", "loading reanimation", "loading voice", "loading commands", "ready"}
        task.spawn(function()
            local loaderSound
            local loaderGone = false
            task.spawn(function()
                local ok, snd = pcall(function()
                    local get_asset = getcustomasset or getsynasset
                    if type(writefile) ~= "function" or type(get_asset) ~= "function" then return nil end
                    pcall(function() if makefolder then makefolder("PrismMusic") end end)
                    local path = "PrismMusic/loader_lofi.mp3"
                    if not (type(isfile) == "function" and isfile(path)) then
                        local HttpService = game:GetService("HttpService")
                        local fileName = "Loyalty Freak Music - LOFI AMBIENT SONGS ! - 08 Lack of Color - Sugar and coffee.mp3"
                        local url = "https://archive.org/download/loyalty-freak-music-lofi-ambient-songs/" .. HttpService:UrlEncode(fileName)
                        local body
                        if type(request) == "function" then
                            local rok, res = pcall(function()
                                return request({ Url = url, Method = "GET" })
                            end)
                            if rok and type(res) == "table" then
                                body = res.Body or res.body
                            end
                        end
                        if type(body) ~= "string" or #body < 1000 then
                            local gok, got = pcall(function() return game:HttpGet(url) end)
                            if gok then body = got end
                        end
                        if type(body) ~= "string" or #body < 1000 then return nil end
                        writefile(path, body)
                    end
                    local sid = get_asset(path)
                    if type(sid) ~= "string" then return nil end
                    local s = Instance.new("Sound")
                    s.Name = "PrismLoaderLofi"
                    s.SoundId = sid
                    s.Volume = 0.5
                    s.Looped = false
                    s.Parent = game:GetService("SoundService")
                    s.TimePosition = 0
                    s:Play()
                    return s
                end)
                if ok and snd then
                    loaderSound = snd
                    if loaderGone then
                        pcall(function()
                            snd:Stop()
                            snd:Destroy()
                        end)
                    end
                end
            end)
            local waited = os.clock()
            while not loaderSound and os.clock() - waited < 7 do
                task.wait(0.1)
            end
            for i, step in ipairs(steps) do
                status.Text = step
                TweenService:Create(fill, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    Size = UDim2.fromScale(i / #steps, 1)
                }):Play()
                task.wait(0.55)
            end
            task.wait(0.15)
            loaderGone = true
            if loaderSound then
                pcall(function()
                    loaderSound:Stop()
                    loaderSound:Destroy()
                end)
            end
            loader.Visible = false
            shell.Visible = true
            fillStats()
            show("Home")
        end)

        RunService.RenderStepped:Connect(function(dt)
            for _, m in ipairs(motes) do
                m.y = m.y - m.s * dt * 8
                m.x = m.x + m.d * dt * 0.015
                if m.y < -0.02 then
                    m.y = 1.02
                    m.x = math.random()
                end
                m.f.Position = UDim2.fromScale(m.x, m.y)
            end
            ring.Rotation = (ring.Rotation + dt * 40) % 360
            rs.Transparency = 0.25 + math.abs(math.sin(os.clock() * 2)) * 0.45
        end)

        UserInputService.InputBegan:Connect(function(inp, gp)
            if gp then return end
            if inp.KeyCode == Enum.KeyCode.RightShift then
                toggle()
            end
            for cmd, key in pairs(binds) do
                if inp.KeyCode == key then
                    run(cmd:gsub("%s+<[^>]+>", ""))
                end
            end
        end)

        task.delay(0.8, function()
            pcall(function()
                if Menu then Menu.Visible = false end
            end)
        end)
    end
    mount()
end)

--========================================================
--  PRISM'S NAMETAGS  --  appended module (executor edition)
--  Reads nametags from your Base44 app (by Roblox ID) and draws
--  them above every matching player's head. Click a nametag to
--  open the profile card + play their chosen music.
--
--  PURE APPEND: nothing above this line was changed. The module
--  is wrapped in task.spawn + pcall so it can NEVER break the
--  main Prism script.
--
--  Set CONFIG.API_URL below to your Base44 function URL:
--      https://<your-app-domain>/functions/getNametags
--========================================================
task.spawn(function()
    local ok, err = pcall(function()
--[[
========================================================================
  PRISM'S NAMETAGS  --  EXECUTOR EDITION  (v2)
========================================================================
  Runs through an executor (Synapse / Wave / Fluxus / Solara / ...).

  ####################################################################
  #  HOW "EVERYONE SEES IT" ACTUALLY WORKS WITH AN EXECUTOR          #
  ####################################################################
  An executor only runs on YOUR client. Roblox does NOT let a client
  create objects that other players can see. So ONE person running this
  can NEVER make nametags appear for everyone else -- that is a hard
  Roblox engine limitation, not a script bug.

  The way an executor community gets "everyone sees it" is:
        >>>  EVERYONE RUNS THE SCRIPT.  <<<
  When every player executes this, each player's client draws every
  other player's nametag on their own screen -- so everyone sees
  everyone's nametags.

  If you ever own / can edit the game, use the TRUE server-side script
  (prism_server_nametags.lua) instead: ONE copy in ServerScriptService
  shows for everyone with no executor at all.

  ####################################################################

  This script reads nametags from your Base44 app and shows them above
  every matching player's head. Click a nametag -> profile card opens
  with the avatar, bio, menu buttons, and their chosen music.

  SETUP
  -----
  1. In Base44, deploy the "getNametags" backend function (see the prompt).
     It lives at:  https://<your-app-domain>/functions/getNametags
  2. Paste that URL into CONFIG.API_URL below.
  3. Execute this script (or append it to the end of the Prism script).
  4. Share the SAME script with everyone in your server.
========================================================================
]]

local CONFIG = {
    -- >>> PUT YOUR BASE44 FUNCTION URL HERE <<<
    API_URL = "https://YOUR-APP.base44.app/functions/getNametags",

    REFRESH_INTERVAL  = 30,                      -- seconds between re-fetches (lower = snappier)
    NAMETAG_SIZE      = UDim2.fromOffset(220, 108),
    NAMETAG_OFFSET    = 3.4,                      -- studs above the head
    MAX_DISTANCE      = 180,                      -- hide nametags past this
    SHOW_LOCAL_PLAYER = false,                    -- show your own nametag?
    ENABLE_CLICK_MENU = true,                     -- click -> profile card + music
    ENABLE_MUSIC      = true,
    CACHE_IMAGES      = true,                     -- download external imgs once
    DEBUG             = false,
}

--========================================================
-- Services & state
--========================================================
local Players           = game:GetService("Players")
local HttpService       = game:GetService("HttpService")
local TweenService      = game:GetService("TweenService")
local SoundService      = game:GetService("SoundService")
local StarterGui        = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer

local NametagData = {}   -- [tostring(userId)] = tag table
local ActiveGuis  = {}   -- [player] = BillboardGui
local LastHash    = {}   -- [player] = json (skip needless rebuilds -> no flicker)
local CurrentSound       -- currently playing Sound instance
local CurrentCardGui     -- currently open profile card ScreenGui
local ImageCache  = {}   -- [url] = rbxasset path

local function log(...)
    if CONFIG.DEBUG then warn("[Prism Nametags]", ...) end
end

--========================================================
-- Executor-aware HTTP (works across executors)
--========================================================
local function httpGet(url)
    local methods = {
        function() return game:HttpGet(url) end,
        function() return game:HttpGetAsync(url) end,
        function() return request({ Url = url, Method = "GET" }).Body end,
        function() return http_request({ Url = url, Method = "GET" }).Body end,
        function() return syn.request({ Url = url, Method = "GET" }).Body end,
    }
    for _, fn in ipairs(methods) do
        local ok, res = pcall(fn)
        if ok and type(res) == "string" and #res > 0 then
            return true, res
        end
    end
    return false, nil
end

--========================================================
-- Helpers
--========================================================
local function toColor(hex, fallback)
    if type(hex) == "string" and #hex > 0 then
        local clean = hex:gsub("#", "")
        if #clean == 6 then
            local ok, c = pcall(function() return Color3.fromHex(clean) end)
            if ok then return c end
        end
    end
    return fallback or Color3.fromRGB(90, 150, 255)
end

--========================================================
-- Executor-aware image resolver
--   - plain number  -> Roblox asset id
--   - http(s) url   -> download + getcustomasset (executor)
--   - otherwise     -> fallback (e.g. rbxthumb avatar)
--========================================================
local function resolveImage(url, fallback)
    if type(url) == "string" and url:match("^%d+$") then
        return "rbxassetid://" .. url
    end

    if type(url) == "string" and url:match("^rbxassetid://") then
        return url
    end
    if type(url) == "string" and url:match("^rbxthumb://") then
        return url
    end

    if type(url) == "string" and url:match("^https?://") then
        if CONFIG.CACHE_IMAGES and ImageCache[url] then
            return ImageCache[url]
        end
        local ok, asset = pcall(function()
            local fname = "prism_" .. tostring(url:gsub("%W", ""):sub(-48)) .. ".png"
            if isfile and isfile(fname) then
                return getcustomasset(fname)
            end
            local got, data = httpGet(url)
            if not got then error("download failed") end
            writefile(fname, data)
            return getcustomasset(fname)
        end)
        if ok and asset then
            if CONFIG.CACHE_IMAGES then ImageCache[url] = asset end
            return asset
        end
    end

    return fallback
end

local function resolveAvatar(tag, userId)
    local fallback = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(userId) .. "&w=150&h=150"
    -- Prefer an explicit Roblox asset id field, then a numeric profilePicture.
    return resolveImage(tag.profilePictureAssetId, resolveImage(tag.profilePicture, fallback))
end

local function resolveBannerImage(tag)
    return resolveImage(tag.bannerImageAssetId, resolveImage(tag.bannerImage, nil))
end

--========================================================
-- Fetch nametags from Base44
--========================================================
local function fetchNametags()
    local ok, res = httpGet(CONFIG.API_URL)
    if not ok or type(res) ~= "string" or #res == 0 then
        log("fetch failed")
        return false
    end

    local ok2, data = pcall(function()
        return HttpService:JSONDecode(res)
    end)
    if not ok2 or type(data) ~= "table" then
        log("decode failed:", data)
        return false
    end

    local list = data.nametags or data.data or data
    if type(list) ~= "table" then return false end

    local newData = {}
    for _, tag in ipairs(list) do
        if type(tag) == "table" and tag.robloxId ~= nil then
            newData[tostring(tag.robloxId)] = tag
        end
    end

    NametagData = newData
    log("loaded", #list, "nametags")
    return true
end

--========================================================
-- Music
--========================================================
local function stopMusic()
    if CurrentSound then
        pcall(function()
            CurrentSound:Stop()
            CurrentSound:Destroy()
        end)
        CurrentSound = nil
    end
end

local function playMusic(tag)
    stopMusic()
    if not CONFIG.ENABLE_MUSIC then return end

    if tag.musicSource == "roblox" and tag.robloxAudioId and tostring(tag.robloxAudioId) ~= "" then
        local sound = Instance.new("Sound")
        sound.Name = "PrismNametagMusic"
        sound.SoundId = "rbxassetid://" .. tostring(tag.robloxAudioId)
        sound.Volume = 1
        sound.Looped = true
        sound.Parent = SoundService
        CurrentSound = sound
        pcall(function() sound:Play() end)
    end
    -- Spotify cannot play inside Roblox; the profile card shows a link instead.
end

local function notify(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", { Title = title, Text = text })
    end)
end

--========================================================
-- Profile card (opens on nametag click)
--========================================================
local function closeProfileCard()
    stopMusic()
    if CurrentCardGui then
        CurrentCardGui:Destroy()
        CurrentCardGui = nil
    end
end

local function openProfileCard(player, tag)
    closeProfileCard()

    local userId = tostring(player.UserId)
    local accent = toColor(tag.accentColor, Color3.fromRGB(90, 150, 255))

    local gui = Instance.new("ScreenGui")
    gui.Name = "PrismNametagCard"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 100
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    CurrentCardGui = gui

    -- dim backdrop
    local backdrop = Instance.new("TextButton")
    backdrop.Size = UDim2.fromScale(1, 1)
    backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
    backdrop.BackgroundTransparency = 0.4
    backdrop.Text = ""
    backdrop.AutoButtonColor = false
    backdrop.Parent = gui
    backdrop.MouseButton1Click:Connect(closeProfileCard)

    -- card
    local card = Instance.new("Frame")
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.fromScale(0.5, 0.5)
    card.Size = UDim2.fromOffset(320, 400)
    card.BackgroundColor3 = Color3.fromRGB(16, 17, 24)
    card.BorderSizePixel = 0
    card.Parent = gui
    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 18)
    cardCorner.Parent = card
    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = accent
    cardStroke.Thickness = 2
    cardStroke.Transparency = 0.3
    cardStroke.Parent = card

    -- entrance animation
    card.Size = UDim2.fromOffset(280, 360)
    TweenService:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.fromOffset(320, 400),
    }):Play()

    -- banner strip
    local banner = Instance.new("Frame")
    banner.Size = UDim2.new(1, 0, 0, 96)
    banner.BackgroundColor3 = toColor(tag.bannerColor, Color3.fromRGB(30, 32, 46))
    banner.BorderSizePixel = 0
    banner.Parent = card
    local bannerCorner = Instance.new("UICorner")
    bannerCorner.CornerRadius = UDim.new(0, 18)
    bannerCorner.Parent = banner
    local bannerFix = Instance.new("Frame")
    bannerFix.Size = UDim2.new(1, 0, 0, 18)
    bannerFix.Position = UDim2.new(0, 0, 1, -18)
    bannerFix.BackgroundColor3 = banner.BackgroundColor3
    bannerFix.BorderSizePixel = 0
    bannerFix.Parent = banner

    if tag.bannerType == "gradient" then
        local grad = Instance.new("UIGradient")
        grad.Color = ColorSequence.new(
            toColor(tag.bannerGradientFrom, accent),
            toColor(tag.bannerGradientTo, Color3.fromRGB(20, 20, 30))
        )
        grad.Parent = banner
    elseif tag.bannerType == "image" then
        local img = resolveBannerImage(tag)
        if img then
            local bimg = Instance.new("ImageLabel")
            bimg.Size = UDim2.fromScale(1, 1)
            bimg.BackgroundTransparency = 1
            bimg.Image = img
            bimg.ScaleType = Enum.ScaleType.Crop
            bimg.Parent = banner
            local bc = Instance.new("UICorner")
            bc.CornerRadius = UDim.new(0, 18)
            bc.Parent = bimg
        end
    end

    -- avatar
    local avatar = Instance.new("ImageLabel")
    avatar.AnchorPoint = Vector2.new(0.5, 0.5)
    avatar.Position = UDim2.new(0.5, 0, 0, 96)
    avatar.Size = UDim2.fromOffset(88, 88)
    avatar.BackgroundColor3 = Color3.fromRGB(24, 25, 34)
    avatar.Image = resolveAvatar(tag, userId)
    avatar.Parent = card
    local avCorner = Instance.new("UICorner")
    avCorner.CornerRadius = UDim.new(1, 0)
    avCorner.Parent = avatar
    local avStroke = Instance.new("UIStroke")
    avStroke.Color = accent
    avStroke.Thickness = 3
    avStroke.Parent = avatar

    -- name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Position = UDim2.fromOffset(16, 150)
    nameLabel.Size = UDim2.new(1, -32, 0, 26)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 20
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.Text = tag.displayName or tag.robloxUsername or player.Name
    nameLabel.Parent = card

    -- roblox id (muted)
    local idLabel = Instance.new("TextLabel")
    idLabel.Position = UDim2.fromOffset(16, 174)
    idLabel.Size = UDim2.new(1, -32, 0, 16)
    idLabel.BackgroundTransparency = 1
    idLabel.Font = Enum.Font.Gotham
    idLabel.TextSize = 12
    idLabel.TextColor3 = accent
    idLabel.TextXAlignment = Enum.TextXAlignment.Left
    idLabel.Text = "@" .. (tag.robloxUsername or player.Name) .. "  |  ID " .. userId
    idLabel.Parent = card

    -- bio
    local bio = Instance.new("TextLabel")
    bio.Position = UDim2.fromOffset(16, 196)
    bio.Size = UDim2.new(1, -32, 0, 60)
    bio.BackgroundTransparency = 1
    bio.Font = Enum.Font.Gotham
    bio.TextSize = 13
    bio.TextColor3 = Color3.fromRGB(200, 205, 220)
    bio.TextWrapped = true
    bio.TextXAlignment = Enum.TextXAlignment.Left
    bio.TextYAlignment = Enum.TextYAlignment.Top
    bio.Text = tag.bio or ""
    bio.Parent = card

    -- menu buttons
    local y = 262
    local items = tag.menuItems
    if type(items) == "table" then
        for _, item in ipairs(items) do
            if type(item) == "table" and item.label then
                local btn = Instance.new("TextButton")
                btn.Position = UDim2.fromOffset(16, y)
                btn.Size = UDim2.new(1, -32, 0, 30)
                btn.BackgroundColor3 = accent
                btn.BackgroundTransparency = 0.75
                btn.Text = tostring(item.label)
                btn.TextColor3 = Color3.fromRGB(255, 255, 255)
                btn.Font = Enum.Font.GothamMedium
                btn.TextSize = 14
                btn.AutoButtonColor = true
                btn.Parent = card
                local bc = Instance.new("UICorner")
                bc.CornerRadius = UDim.new(0, 8)
                bc.Parent = btn
                if item.url and item.url ~= "" then
                    btn.MouseButton1Click:Connect(function()
                        pcall(function() setclipboard(item.url) end)
                        notify(item.label, "Link copied: " .. tostring(item.url))
                    end)
                end
                y = y + 36
            end
        end
    end

    -- music controls
    if tag.musicSource == "roblox" and tag.robloxAudioId then
        playMusic(tag)
        local mute = Instance.new("TextButton")
        mute.Position = UDim2.new(1, -100, 0, 12)
        mute.Size = UDim2.fromOffset(88, 26)
        mute.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        mute.BackgroundTransparency = 0.5
        mute.Text = "Mute"
        mute.TextColor3 = Color3.fromRGB(255, 255, 255)
        mute.Font = Enum.Font.GothamMedium
        mute.TextSize = 13
        mute.Parent = card
        local mc = Instance.new("UICorner")
        mc.CornerRadius = UDim.new(0, 8)
        mc.Parent = mute
        local muted = false
        mute.MouseButton1Click:Connect(function()
            muted = not muted
            if muted then
                stopMusic()
                mute.Text = "Play"
            else
                playMusic(tag)
                mute.Text = "Mute"
            end
        end)
    elseif tag.musicSource == "spotify" and tag.spotifyUrl then
        local note = Instance.new("TextButton")
        note.Position = UDim2.new(1, -140, 0, 12)
        note.Size = UDim2.fromOffset(128, 26)
        note.BackgroundColor3 = Color3.fromRGB(30, 215, 96)
        note.BackgroundTransparency = 0.2
        note.Text = "Spotify link"
        note.TextColor3 = Color3.fromRGB(0, 0, 0)
        note.Font = Enum.Font.GothamBold
        note.TextSize = 13
        note.Parent = card
        local nc = Instance.new("UICorner")
        nc.CornerRadius = UDim.new(0, 8)
        nc.Parent = note
        note.MouseButton1Click:Connect(function()
            pcall(function() setclipboard(tag.spotifyUrl) end)
            notify("Spotify", "Link copied: " .. tostring(tag.spotifyUrl))
        end)
    end

    -- close button
    local close = Instance.new("TextButton")
    close.Position = UDim2.fromOffset(12, 12)
    close.Size = UDim2.fromOffset(26, 26)
    close.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    close.BackgroundTransparency = 0.5
    close.Text = "X"
    close.TextColor3 = Color3.fromRGB(255, 255, 255)
    close.Font = Enum.Font.GothamBold
    close.TextSize = 14
    close.Parent = card
    local cc = Instance.new("UICorner")
    cc.CornerRadius = UDim.new(1, 0)
    cc.Parent = close
    close.MouseButton1Click:Connect(closeProfileCard)
end

--========================================================
-- Build / remove a single nametag (BillboardGui)
--========================================================
local function removeNametag(player)
    local gui = ActiveGuis[player]
    if gui and gui.Parent then
        gui:Destroy()
    end
    ActiveGuis[player] = nil
    LastHash[player] = nil
end

local function buildNametag(player, tag)
    local char = player.Character
    if not char then return end
    local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    if not head then return end

    -- Skip rebuilding if nothing changed -> no flicker on refresh.
    local json = HttpService:JSONEncode(tag)
    if ActiveGuis[player] and ActiveGuis[player].Adornee == head and LastHash[player] == json then
        return
    end
    removeNametag(player)

    local userId = tostring(player.UserId)
    local accent = toColor(tag.accentColor, Color3.fromRGB(90, 150, 255))

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "PrismNametag"
    billboard.Size = CONFIG.NAMETAG_SIZE
    billboard.StudsOffset = Vector3.new(0, CONFIG.NAMETAG_OFFSET, 0)
    billboard.AlwaysOnTop = true
    billboard.LightInfluence = 0
    billboard.MaxDistance = CONFIG.MAX_DISTANCE
    billboard.ResetOnSpawn = false
    billboard.Adornee = head
    -- IMPORTANT: parent to the LocalPlayer's PlayerGui (exactly like the main
    -- script's own voice meter does) instead of the Head. That way the
    -- Shield/VC-bypass "foreign voice gui" sweep -- which destroys BillboardGuis
    -- that live under the Head and show an AvatarHeadShot -- can NEVER delete
    -- our nametags. The Adornee keeps it positioned above the head.
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not pg then pg = LocalPlayer:WaitForChild("PlayerGui", 10) end
    billboard.Parent = pg or head

    -- banner
    local banner = Instance.new("Frame")
    banner.Size = UDim2.new(1, 0, 0, 62)
    banner.BackgroundColor3 = toColor(tag.bannerColor, Color3.fromRGB(24, 26, 38))
    banner.BorderSizePixel = 0
    banner.Parent = billboard
    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(0, 12)
    bc.Parent = banner
    local bstroke = Instance.new("UIStroke")
    bstroke.Color = accent
    bstroke.Thickness = 1.5
    bstroke.Transparency = 0.2
    bstroke.Parent = banner

    if tag.bannerType == "gradient" then
        local grad = Instance.new("UIGradient")
        grad.Color = ColorSequence.new(
            toColor(tag.bannerGradientFrom, accent),
            toColor(tag.bannerGradientTo, Color3.fromRGB(18, 18, 26))
        )
        grad.Parent = banner
    elseif tag.bannerType == "image" then
        local img = resolveBannerImage(tag)
        if img then
            local bimg = Instance.new("ImageLabel")
            bimg.Size = UDim2.fromScale(1, 1)
            bimg.BackgroundTransparency = 1
            bimg.Image = img
            bimg.ScaleType = Enum.ScaleType.Crop
            bimg.Parent = banner
            local ic = Instance.new("UICorner")
            ic.CornerRadius = UDim.new(0, 12)
            ic.Parent = bimg
        end
    end

    -- avatar (overlapping banner bottom)
    local avatar = Instance.new("ImageLabel")
    avatar.AnchorPoint = Vector2.new(0.5, 0.5)
    avatar.Position = UDim2.new(0.5, 0, 0, 62)
    avatar.Size = UDim2.fromOffset(54, 54)
    avatar.BackgroundColor3 = Color3.fromRGB(20, 21, 30)
    avatar.Image = resolveAvatar(tag, userId)
    avatar.Parent = billboard
    local ac = Instance.new("UICorner")
    ac.CornerRadius = UDim.new(1, 0)
    ac.Parent = avatar
    local astroke = Instance.new("UIStroke")
    astroke.Color = accent
    astroke.Thickness = 2
    astroke.Parent = avatar

    -- name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Position = UDim2.fromOffset(0, 86)
    nameLabel.Size = UDim2.new(1, 0, 0, 18)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 15
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextStrokeTransparency = 0.4
    nameLabel.Text = tag.displayName or tag.robloxUsername or player.Name
    nameLabel.Parent = billboard

    -- music indicator
    if (tag.musicSource == "roblox" and tag.robloxAudioId) or (tag.musicSource == "spotify" and tag.spotifyUrl) then
        local note = Instance.new("TextLabel")
        note.AnchorPoint = Vector2.new(1, 0)
        note.Position = UDim2.new(1, -6, 0, 4)
        note.Size = UDim2.fromOffset(16, 16)
        note.BackgroundTransparency = 1
        note.Font = Enum.Font.GothamBold
        note.TextSize = 14
        note.TextColor3 = accent
        note.Text = "~"
        note.Parent = billboard
    end

    -- click area
    if CONFIG.ENABLE_CLICK_MENU then
        local click = Instance.new("TextButton")
        click.Size = UDim2.fromScale(1, 1)
        click.BackgroundTransparency = 1
        click.Text = ""
        click.Parent = billboard
        click.MouseButton1Click:Connect(function()
            openProfileCard(player, tag)
        end)
    end

    ActiveGuis[player] = billboard
    LastHash[player] = json
end

--========================================================
-- Refresh loop: match players to nametag data
--========================================================
local function refreshAll()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer or CONFIG.SHOW_LOCAL_PLAYER then
            local tag = NametagData[tostring(player.UserId)]
            if tag then
                buildNametag(player, tag)
            else
                removeNametag(player)
            end
        end
    end
end

--========================================================
-- Wire up players
--========================================================
local function onPlayerAdded(player)
    if player == LocalPlayer and not CONFIG.SHOW_LOCAL_PLAYER then return end
    player.CharacterAdded:Connect(function()
        task.wait(1)
        local tag = NametagData[tostring(player.UserId)]
        if tag then buildNametag(player, tag) end
    end)
    if player.Character then
        local tag = NametagData[tostring(player.UserId)]
        if tag then buildNametag(player, tag) end
    end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
    removeNametag(player)
end)

--========================================================
-- Boot
--========================================================
local function boot()
    log("starting...")
    fetchNametags()
    refreshAll()

    for _, player in ipairs(Players:GetPlayers()) do
        onPlayerAdded(player)
    end

    task.spawn(function()
        while true do
            task.wait(CONFIG.REFRESH_INTERVAL)
            if fetchNametags() then
                refreshAll()
            end
        end
    end)
end

boot()

-- expose manual controls (works with or without an executor's getgenv)
local function setGlobal(key, value)
    local ok = pcall(function() getgenv()[key] = value end)
    if not ok then _G[key] = value end
end
setGlobal("PrismNametagsRefresh", function()
    if fetchNametags() then refreshAll() end
end)
setGlobal("PrismNametagsClose", closeProfileCard)

    end)
    if not ok then
        warn("[Prism Nametags] module failed to start:", err)
    end
end)
