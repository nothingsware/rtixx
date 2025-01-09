local Library = {}
Library.MainColor = Color3.new(0.098, 0.098, 0.098)
Library.BackgroundColor = Color3.new(0.137, 0.137, 0.137)
Library.AccentColor = Color3.new(0.298, 0.447, 0.894)
Library.OutlineColor = Color3.new(0.176, 0.176, 0.176)
Library.TextColor = Color3.new(0.9, 0.9, 0.9)
Library.Font = Enum.Font.Gotham
Library.RegistryMap = {}

local ProtectGui = protectgui or (syn and syn.protect_gui) or (function(gui)
    gui.Parent = cloneref(game:GetService("CoreGui"))
end)

local TweenService = game:GetService("TweenService")
local UserInputService = cloneref(game:GetService("UserInputService"))
local HttpService = cloneref(game:GetService("HttpService"))
local CoreGui = cloneref(game:GetService("CoreGui"))

local ScreenGui = Instance.new("ScreenGui")
ProtectGui(ScreenGui)
ScreenGui.Name = "KeySystem"
ScreenGui.Parent = CoreGui

function Library:SaveKey(KeyPath, FileName, key)
    if not (isfolder and makefolder and writefile) then
        warn("File system functions are not available.")
        return
    end
    if not isfolder(KeyPath) then
        makefolder(KeyPath)
    end
    writefile(KeyPath .. "/" .. FileName, HttpService:JSONEncode({key = key}))
end

function Library:LoadKey(KeyPath, FileName)
    if not (isfolder and readfile) then
        warn("File system functions are not available.")
        return nil
    end
    if isfolder(KeyPath) and isfile(KeyPath .. "/" .. FileName) then
        local data = HttpService:JSONDecode(readfile(KeyPath .. "/" .. FileName))
        return data.key
    end
    return nil
end

function Library:Create(Class, Properties)
    local Object = Instance.new(Class)
    for Property, Value in next, Properties do
        Object[Property] = Value
    end
    return Object
end

function Library:CreateLabel(Properties)
    local Label = self:Create('TextLabel', {
        BackgroundTransparency = 1,
        Font = self.Font,
        TextColor3 = self.TextColor,
        TextSize = 14,
        TextStrokeTransparency = 1,
    })
    
    for Property, Value in next, Properties do
        Label[Property] = Value
    end
    
    return Label
end

function Library:MakeDraggable(Object)
    local DragToggle = nil
    local DragSpeed = 0.25
    local DragStart = nil
    local StartPos = nil

    function UpdateInput(Input)
        local Delta = Input.Position - DragStart
        local Position = UDim2.new(StartPos.X.Scale, StartPos.X.Offset + Delta.X,
                                 StartPos.Y.Scale, StartPos.Y.Offset + Delta.Y)
        TweenService:Create(Object, TweenInfo.new(DragSpeed), {Position = Position}):Play()
    end

    Object.InputBegan:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 then
            DragToggle = true
            DragStart = Input.Position
            StartPos = Object.Position
            Input.Changed:Connect(function()
                if Input.UserInputState == Enum.UserInputState.End then
                    DragToggle = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseMovement and DragToggle then
            UpdateInput(Input)
        end
    end)
end

function Library:AddToRegistry(Object, Properties)
    self.RegistryMap[Object] = { Properties = Properties }
end

function Library:AnimateButton(Button)
    local OriginalColor = Button.BackgroundColor3
    local OriginalTextColor = Button.TextColor3

    Button.MouseEnter:Connect(function()
        local Tween = TweenService:Create(Button, TweenInfo.new(0.3), {
            BackgroundColor3 = self.AccentColor,
            TextColor3 = Color3.new(1, 1, 1)
        })
        Tween:Play()
    end)

    Button.MouseLeave:Connect(function()
        local Tween = TweenService:Create(Button, TweenInfo.new(0.3), {
            BackgroundColor3 = OriginalColor,
            TextColor3 = OriginalTextColor
        })
        Tween:Play()
    end)
end

function Library:Destroy()
    local existing = cloneref(game:GetService("CoreGui")):FindFirstChild("KeySystem")
    if existing then
        existing:Destroy()
    end
end

function Library:CreateWindow(Title, Size)
    local Window = {}
    local Library = self

    local Outer = Library:Create('Frame', {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Library.OutlineColor,
        BorderSizePixel = 0,
        Position = UDim2.fromScale(0.5, 0.5),
        Size = Size or UDim2.fromOffset(300, 150),
        Visible = false,  -- Start invisible for animation
        ZIndex = 1,
        Parent = ScreenGui
    })

    local Inner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor,
        BorderColor3 = Library.OutlineColor,
        BorderMode = Enum.BorderMode.Inset,
        Position = UDim2.new(0, 1, 0, 1),
        Size = UDim2.new(1, -2, 1, -2),
        ZIndex = 1,
        Parent = Outer
    })

    local TitleLabel = Library:CreateLabel({
        Position = UDim2.new(0, 10, 0, 0),
        Size = UDim2.new(0, 0, 0, 25),
        Text = Title,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 1,
        Parent = Inner
    })

    local MainSection = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor,
        BorderColor3 = Library.OutlineColor,
        Position = UDim2.new(0, 8, 0, 25),
        Size = UDim2.new(1, -16, 1, -33),
        ZIndex = 1,
        Parent = Inner
    })

    -- Animate window appearance
    Outer.Visible = true
    Outer.BackgroundTransparency = 1
    Outer:TweenSizeAndPosition(
        Outer.Size,
        Outer.Position,
        Enum.EasingDirection.Out,
        Enum.EasingStyle.Back,
        0.5,
        true,
        nil
    )
    TweenService:Create(Outer, TweenInfo.new(0.5), {BackgroundTransparency = 0}):Play()

    Library:MakeDraggable(Outer)

    function Window:Close()
        local closeTween = TweenService:Create(Outer, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 0, 0, 0)
        })
        closeTween:Play()
        closeTween.Completed:Connect(function()
            Outer:Destroy()
        end)
    end

    function Window:AddTextBox(Text, Position)
        local TextBoxContainer = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor,
            BorderColor3 = Library.OutlineColor,
            Position = Position,
            Size = UDim2.new(0.8, 0, 0, 30),
            ZIndex = 2,
            Parent = MainSection
        })

        local Corner = Library:Create('UICorner', {
            CornerRadius = UDim.new(0, 4),
            Parent = TextBoxContainer
        })

        local TextBox = Library:Create('TextBox', {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 10, 0, 0),
            Size = UDim2.new(1, -20, 1, 0),
            Font = Library.Font,
            PlaceholderText = Text,
            PlaceholderColor3 = Color3.new(0.7, 0.7, 0.7),
            Text = "",
            TextColor3 = Library.TextColor,
            TextSize = 14,
            ZIndex = 3,
            Parent = TextBoxContainer
        })
        
        TextBox.Focused:Connect(function()
            local Tween = TweenService:Create(TextBoxContainer, TweenInfo.new(0.2), {
                BackgroundColor3 = Library.AccentColor,
                BorderColor3 = Library.AccentColor
            })
            Tween:Play()
        end)

        TextBox.FocusLost:Connect(function()
            local Tween = TweenService:Create(TextBoxContainer, TweenInfo.new(0.2), {
                BackgroundColor3 = Library.MainColor,
                BorderColor3 = Library.OutlineColor
            })
            Tween:Play()
        end)
        
        return TextBox
    end
    
    function Window:AddButton(Text, Position, Callback)
        local Button = Library:Create('TextButton', {
            BackgroundColor3 = Library.MainColor,
            BorderColor3 = Library.OutlineColor,
            Position = Position,
            Size = UDim2.new(0.35, 0, 0, 30),
            Font = Library.Font,
            Text = Text,
            TextColor3 = Library.TextColor,
            TextSize = 14,
            ZIndex = 2,
            AutoButtonColor = false,
            Parent = MainSection
        })
        
        local Corner = Library:Create('UICorner', {
            CornerRadius = UDim.new(0, 4),
            Parent = Button
        })
        
        Library:AnimateButton(Button)
        Button.MouseButton1Click:Connect(Callback)
        return Button
    end

    function Window:AddToggle(Text, Position, DefaultState)
        local Toggle = Library:Create('Frame', {
            BackgroundTransparency = 1,
            Position = UDim2.new(Position.X.Scale, Position.X.Offset, Position.Y.Scale, Position.Y.Offset + 10),
            Size = UDim2.new(0.8, 0, 0, 20),
            ZIndex = 2,
            Parent = MainSection
        })
    
        local Checkbox = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor,
            BorderColor3 = Library.OutlineColor,
            Position = UDim2.new(0, 0, 0, 0),
            Size = UDim2.new(0, 20, 0, 20),
            ZIndex = 3,
            Parent = Toggle
        })
    
        local CheckboxCorner = Library:Create('UICorner', {
            CornerRadius = UDim.new(0, 4),
            Parent = Checkbox
        })
    
        local Checkmark = Library:Create('TextLabel', {
            BackgroundTransparency = 1,
            Position = UDim2.new(0.1, 0, 0.1, 0),
            Size = UDim2.new(0.8, 0, 0.8, 0),
            Font = Enum.Font.GothamBold,
            Text = "✓",
            TextColor3 = Library.AccentColor,
            TextSize = 14,
            TextTransparency = DefaultState and 0 or 1,
            ZIndex = 4,
            Parent = Checkbox
        })
    
        local Label = Library:CreateLabel({
            Position = UDim2.new(0, 30, 0, 0),
            Size = UDim2.new(0.7, 0, 1, 0),
            Text = Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 3,
            Parent = Toggle
        })
    
        local State = DefaultState
        local Connection
    
        Connection = Toggle.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                State = not State
                TweenService:Create(Checkmark, TweenInfo.new(0.2), {
                    TextTransparency = State and 0 or 1
                }):Play()
            end
        end)
    
        return {
            GetState = function() return State end,
            SetState = function(NewState)
                State = NewState
                TweenService:Create(Checkmark, TweenInfo.new(0.2), {
                    TextTransparency = State and 0 or 1
                }):Play()
            end,
            Destroy = function()
                Connection:Disconnect()
                Toggle:Destroy()
            end
        }
    end

    Window.Outer = Outer
    return Window
end

return Library
