--// Services
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local Players           = game:GetService("Players")
local Camera            = workspace.CurrentCamera

--// Locals
local LocalPlayer       = Players.LocalPlayer

--// Shorthands
local pcall, getgenv, next, setmetatable, string_upper
    = pcall, getgenv, next, setmetatable, string.upper

local Vector2New, CFrameNew, Color3FromRGB, DrawingNew, TweenInfoNew
    = Vector2.new, CFrame.new, Color3.fromRGB, Drawing.new, TweenInfo.new

local MouseMoveRel      = mousemoverel
    or (Input and Input.MouseMove) -- Fallback for older exploit APIs

--// Early out for re-execution checks
if not getgenv().AirHub or getgenv().AirHub.Aimbot then
    return
end

--// Variables
local ServiceConnections = {}
local RequiredDistance   = 2000
local Typing             = false
local Running            = false
local OriginalSensitivity
local Animation

--// Setup Aimbot environment
getgenv().AirHub.Aimbot = {
    Settings = {
        Enabled               = false,
        TeamCheck             = false,
        AliveCheck            = true,
        WallCheck             = false,
        Sensitivity           = 0, -- Time (seconds) before fully locking onto target
        ThirdPerson           = false,
        ThirdPersonSensitivity= 3, 
        TriggerKey            = "MouseButton2",
        Toggle                = false,
        LockPart              = "Head",
        
        -- ▼ NEW SETTING:
        -- If set to a specific player's name, only that player is targeted when Toggle = true.
        TargetPlayer          = "" 
    },

    FOVSettings = {
        Enabled      = true,
        Visible      = true,
        Amount       = 90,
        Color        = Color3FromRGB(255, 255, 255),
        LockedColor  = Color3FromRGB(255, 70, 70),
        Transparency = 0.5,
        Sides        = 60,
        Thickness    = 1,
        Filled       = false
    },

    FOVCircle = DrawingNew("Circle")
}

local Environment = getgenv().AirHub.Aimbot

--// Utility Functions

local function ConvertVector(vector3)
    return Vector2New(vector3.X, vector3.Y)
end

local function CancelLock()
    Environment.Locked = nil
    Environment.FOVCircle.Color = Environment.FOVSettings.Color
    UserInputService.MouseDeltaSensitivity = OriginalSensitivity
    
    if Animation then
        Animation:Cancel()
        Animation = nil
    end
end

--// Modified GetClosestPlayer to respect TargetPlayer if set and avoid switching once locked
local function GetClosestPlayer()
    local aimSettings = Environment.Settings

    -- If user provided a TargetPlayer and toggling is enabled, try to lock ONLY that player
    if aimSettings.Toggle and aimSettings.TargetPlayer and aimSettings.TargetPlayer ~= "" then
        -- If already locked on a valid target, skip re-locking logic
        if Environment.Locked then
            -- Verify current lock is still valid
            local character = Environment.Locked.Character
            local lockPart = character and character:FindFirstChild(aimSettings.LockPart)
            if lockPart then
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                if humanoid and (not aimSettings.AliveCheck or humanoid.Health > 0) then
                    local viewportPos, onScreen = Camera:WorldToViewportPoint(lockPart.Position)
                    if onScreen then
                        local dist = (UserInputService:GetMouseLocation() - ConvertVector(viewportPos)).Magnitude
                        if dist <= RequiredDistance then
                            return  -- Still valid, so keep current lock
                        end
                    end
                end
            end
            -- If not valid anymore, cancel lock and proceed to try relocking
            CancelLock()
        end

        local target = Players:FindFirstChild(aimSettings.TargetPlayer)
        
        if target and target.Character then
            local character = target.Character
            local lockPart = character:FindFirstChild(aimSettings.LockPart)
            local humanoid = character:FindFirstChildOfClass("Humanoid")

            if lockPart and humanoid then
                if aimSettings.TeamCheck and target.TeamColor == LocalPlayer.TeamColor then
                    return CancelLock()
                end

                if aimSettings.AliveCheck and humanoid.Health <= 0 then
                    return CancelLock()
                end

                if aimSettings.WallCheck then
                    local obstructing = Camera:GetPartsObscuringTarget(
                        {lockPart.Position},
                        character:GetDescendants()
                    )
                    if #obstructing > 0 then
                        return CancelLock()
                    end
                end

                local viewportPos, onScreen = Camera:WorldToViewportPoint(lockPart.Position)
                if not onScreen then
                    return CancelLock()
                end

                RequiredDistance = aimSettings.FOVSettings.Enabled 
                    and aimSettings.FOVSettings.Amount 
                    or 2000
                Environment.Locked = target
            else
                return CancelLock()
            end
        else
            return CancelLock()
        end

        return  -- End processing for toggle-target mode
    end

    -- Normal logic for non-toggle or no specific target
    if not Environment.Locked then
        RequiredDistance = Environment.FOVSettings.Enabled
            and Environment.FOVSettings.Amount
            or 2000

        for _, player in next, Players:GetPlayers() do
            if player == LocalPlayer then
                continue
            end

            local character = player.Character
            if not character then
                continue
            end

            local lockPart = character:FindFirstChild(aimSettings.LockPart)
            local humanoid = character:FindFirstChildOfClass("Humanoid")

            if not lockPart or not humanoid then
                continue
            end

            if aimSettings.TeamCheck and player.TeamColor == LocalPlayer.TeamColor then
                continue
            end

            if aimSettings.AliveCheck and humanoid.Health <= 0 then
                continue
            end

            if aimSettings.WallCheck then
                local obstructing = Camera:GetPartsObscuringTarget(
                    { lockPart.Position },
                    character:GetDescendants()
                )
                if #obstructing > 0 then
                    continue
                end
            end

            local viewportPos, onScreen = Camera:WorldToViewportPoint(lockPart.Position)
            if not onScreen then
                continue
            end

            local distance = (UserInputService:GetMouseLocation() - ConvertVector(viewportPos)).Magnitude
            if distance < RequiredDistance then
                RequiredDistance = distance
                Environment.Locked = player
            end
        end
    else
        -- Check if locked target is still valid
        local lockPart = Environment.Locked.Character 
            and Environment.Locked.Character:FindFirstChild(aimSettings.LockPart)
        if lockPart then
            local lockedPos = Camera:WorldToViewportPoint(lockPart.Position)
            local dist = (UserInputService:GetMouseLocation() - ConvertVector(lockedPos)).Magnitude
            if dist > RequiredDistance then
                CancelLock()
            end
        else
            CancelLock()
        end
    end
end

local function Load()
    OriginalSensitivity = UserInputService.MouseDeltaSensitivity

    ServiceConnections.RenderSteppedConnection = RunService.RenderStepped:Connect(function()
        -- Update FOV Circle visuals
        local fovSettings = Environment.FOVSettings
        local aimbotSettings = Environment.Settings

        if fovSettings.Enabled and aimbotSettings.Enabled then
            Environment.FOVCircle.Radius       = fovSettings.Amount
            Environment.FOVCircle.Thickness    = fovSettings.Thickness
            Environment.FOVCircle.Filled       = fovSettings.Filled
            Environment.FOVCircle.NumSides     = fovSettings.Sides
            Environment.FOVCircle.Color        = fovSettings.Color
            Environment.FOVCircle.Transparency = fovSettings.Transparency
            Environment.FOVCircle.Visible      = fovSettings.Visible

            local mousePos = UserInputService:GetMouseLocation()
            Environment.FOVCircle.Position = Vector2New(mousePos.X, mousePos.Y)
        else
            Environment.FOVCircle.Visible = false
        end

        -- If "running" (aimbot pressed), try to lock onto a target
        if Running and aimbotSettings.Enabled then
            GetClosestPlayer()

            if Environment.Locked and Environment.Locked.Character then
                local lockedPart = Environment.Locked.Character:FindFirstChild(aimbotSettings.LockPart)
                if lockedPart then
                    if aimbotSettings.ThirdPerson then
                        -- Third-person lock uses mousemoverel
                        local lockedPos = Camera:WorldToViewportPoint(lockedPart.Position)
                        local mousePos  = UserInputService:GetMouseLocation()
                        local xDelta    = (lockedPos.X - mousePos.X) * aimbotSettings.ThirdPersonSensitivity
                        local yDelta    = (lockedPos.Y - mousePos.Y) * aimbotSettings.ThirdPersonSensitivity

                        if MouseMoveRel then
                            MouseMoveRel(xDelta, yDelta)
                        end
                    else
                        -- First-person lock modifies camera CFrame
                        if aimbotSettings.Sensitivity > 0 then
                            Animation = TweenService:Create(
                                Camera,
                                TweenInfoNew(aimbotSettings.Sensitivity, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
                                { CFrame = CFrameNew(Camera.CFrame.Position, lockedPart.Position) }
                            )
                            Animation:Play()
                        else
                            Camera.CFrame = CFrameNew(Camera.CFrame.Position, lockedPart.Position)
                        end
                        UserInputService.MouseDeltaSensitivity = 0
                    end

                    -- Change FOV circle color while locked
                    Environment.FOVCircle.Color = fovSettings.LockedColor
                else
                    CancelLock()
                end
            end
        end
    end)

    -- Handle input began: toggle or hold to run
    ServiceConnections.InputBeganConnection = UserInputService.InputBegan:Connect(function(inputObj)
        if not Typing then
            local triggerKey = Environment.Settings.TriggerKey
            local isKeyboard = (inputObj.UserInputType == Enum.UserInputType.Keyboard)
            local isTriggerKey

            -- If it's a single char (like "Q"), compare KeyCode as uppercase
            if isKeyboard and #triggerKey == 1 then
                isTriggerKey = (inputObj.KeyCode == Enum.KeyCode[string_upper(triggerKey)])
            else
                isTriggerKey = (
                    (isKeyboard and inputObj.KeyCode == Enum.KeyCode[triggerKey])
                    or (not isKeyboard and inputObj.UserInputType == Enum.UserInputType[triggerKey])
                )
            end

            if isTriggerKey then
                if Environment.Settings.Toggle then
                    Running = not Running
                    if not Running then
                        CancelLock()
                    end
                else
                    Running = true
                end
            end
        end
    end)

    -- Handle input ended: stop if not toggle
    ServiceConnections.InputEndedConnection = UserInputService.InputEnded:Connect(function(inputObj)
        if not Typing then
            if not Environment.Settings.Toggle then
                local triggerKey = Environment.Settings.TriggerKey
                local isKeyboard = (inputObj.UserInputType == Enum.UserInputType.Keyboard)
                local isTriggerKey

                if isKeyboard and #triggerKey == 1 then
                    isTriggerKey = (inputObj.KeyCode == Enum.KeyCode[string_upper(triggerKey)])
                else
                    isTriggerKey = (
                        (isKeyboard and inputObj.KeyCode == Enum.KeyCode[triggerKey])
                        or (not isKeyboard and inputObj.UserInputType == Enum.UserInputType[triggerKey])
                    )
                end

                if isTriggerKey then
                    Running = false
                    CancelLock()
                end
            end
        end
    end)
end

--// Typing Check to avoid interfering while chatting
ServiceConnections.TypingStartedConnection = UserInputService.TextBoxFocused:Connect(function()
    Typing = true
end)

ServiceConnections.TypingEndedConnection = UserInputService.TextBoxFocusReleased:Connect(function()
    Typing = false
end)

--// Public Functions
Environment.Functions = {}

function Environment.Functions:Exit()
    for _, conn in next, ServiceConnections do
        conn:Disconnect()
    end

    Environment.FOVCircle:Remove()
    getgenv().AirHub.Aimbot.Functions = nil
    getgenv().AirHub.Aimbot = nil

    Load            = nil
    ConvertVector   = nil
    CancelLock      = nil
    GetClosestPlayer= nil
end

function Environment.Functions:Restart()
    for _, conn in next, ServiceConnections do
        conn:Disconnect()
    end
    Load()
end

function Environment.Functions:ResetSettings()
    Environment.Settings = {
        Enabled               = false,
        TeamCheck             = false,
        AliveCheck            = true,
        WallCheck             = false,
        Sensitivity           = 0,
        ThirdPerson           = false,
        ThirdPersonSensitivity= 3,
        TriggerKey            = "MouseButton2",
        Toggle                = false,
        LockPart              = "Head",
        TargetPlayer          = ""  -- Reset to empty
    }

    Environment.FOVSettings = {
        Enabled      = true,
        Visible      = true,
        Amount       = 90,
        Color        = Color3FromRGB(255, 255, 255),
        LockedColor  = Color3FromRGB(255, 70, 70),
        Transparency = 0.5,
        Sides        = 60,
        Thickness    = 1,
        Filled       = false
    }
end

setmetatable(Environment.Functions, {
    __newindex = function(_, key)
        warn("Attempt to add new index '".. tostring(key) .."' to Aimbot Functions is not allowed.")
    end
})

--// Initialize
Load()
