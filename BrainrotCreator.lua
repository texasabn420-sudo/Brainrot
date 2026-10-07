-- Brainrot Equip UI - Improved v2
-- Changes vs original:
--  1. Search box in the Brainrot dropdown (103 items was unusable without it)
--  2. Sunset is now a true/false dropdown instead of a free-text field
--  3. Status label showing last fire result / errors
--  4. Main scroll uses an explicitly computed canvas (reliable across executors)
--  6. Dragging only from the title bar; fixed Input.Changed connection leak
--  7. Toggle button is draggable too
--  8. FIRE button debounced (0.8s) + remote resolved once and cached
--  9. Click-outside-to-close no longer blocked while typing in a search box
-- 10. Dropdowns render above the FIRE button (ZIndex layering) and flip
--     upward when there isn't room below; scroll list no longer slides
--     under the status label

local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

if CoreGui:FindFirstChild("BrainrotEquipUI") then
    CoreGui.BrainrotEquipUI:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BrainrotEquipUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = CoreGui

local ToggleButton = Instance.new("TextButton")
ToggleButton.Size = UDim2.new(0, 120, 0, 46)
ToggleButton.Position = UDim2.new(0.03, 0, 0.75, 0)
ToggleButton.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.Font = Enum.Font.SourceSansBold
ToggleButton.TextSize = 16
ToggleButton.Text = "Toggle Menu"
ToggleButton.Active = true
ToggleButton.Parent = ScreenGui

local UICornerToggle = Instance.new("UICorner")
UICornerToggle.CornerRadius = UDim.new(0, 10)
UICornerToggle.Parent = ToggleButton

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0.85, 0, 0.7, 0)
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
MainFrame.Visible = true
MainFrame.Active = true
MainFrame.Parent = ScreenGui

local UISizeConstraint = Instance.new("UISizeConstraint")
UISizeConstraint.MaxSize = Vector2.new(360, 480)
UISizeConstraint.MinSize = Vector2.new(280, 300)
UISizeConstraint.Parent = MainFrame

local UICornerMain = Instance.new("UICorner")
UICornerMain.CornerRadius = UDim.new(0, 14)
UICornerMain.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 40)
Title.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 16
Title.Text = "Split Or Steal Brainrot"
Title.Parent = MainFrame

local UICornerTitle = Instance.new("UICorner")
UICornerTitle.CornerRadius = UDim.new(0, 14)
UICornerTitle.Parent = Title

local ScrollFrame = Instance.new("ScrollingFrame")
ScrollFrame.Size = UDim2.new(1, -16, 1, -128)
ScrollFrame.Position = UDim2.new(0, 8, 0, 48)
ScrollFrame.BackgroundTransparency = 1
ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ScrollFrame.ScrollingEnabled = true
ScrollFrame.ScrollBarThickness = 4
ScrollFrame.ClipsDescendants = true
ScrollFrame.Parent = MainFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 8)
UIListLayout.Parent = ScrollFrame

local OverlayContainer = Instance.new("Frame")
OverlayContainer.Size = UDim2.new(1, 0, 1, 0)
OverlayContainer.BackgroundTransparency = 1
OverlayContainer.ZIndex = 2 -- above menu content so dropdowns render on top
OverlayContainer.Parent = MainFrame

local Inputs = {}
local DropdownFrames = {}

-- Safe Default Fallback Parameters
local SelectedBrainrot = "Cacto Hipopotamo"
local SelectedMutation = "Diamond"
local SelectedGrade = "D"
local SelectedRarity = "Common"
local SelectedSize = "Normal"
local SelectedSunset = "false"

--------------------------------------------------------------------------------
-- Draggable helper (no connection leaks, tracks the exact input)
--------------------------------------------------------------------------------
local function makeDraggable(frame, handle)
    local dragging = false
    local dragInput = nil
    local dragStart = Vector2.new()
    local startPos = UDim2.new()
    local endConn = nil

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragInput = input
            dragStart = input.Position
            startPos = frame.Position
            if endConn then endConn:Disconnect() end
            endConn = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    dragInput = nil
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput
            and (input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

makeDraggable(MainFrame, Title)
makeDraggable(ToggleButton, ToggleButton)

--------------------------------------------------------------------------------
-- Field builders
--------------------------------------------------------------------------------
local function createInputField(placeholder, defaultText, layoutOrder)
    local Container = Instance.new("Frame")
    Container.Size = UDim2.new(1, 0, 0, 44)
    Container.BackgroundTransparency = 1
    Container.LayoutOrder = layoutOrder
    Container.Parent = ScrollFrame

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0.4, 0, 1, 0)
    Label.BackgroundTransparency = 1
    Label.TextColor3 = Color3.fromRGB(200, 200, 200)
    Label.Font = Enum.Font.SourceSans
    Label.TextSize = 14
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Text = "  " .. placeholder
    Label.Parent = Container

    local TextBox = Instance.new("TextBox")
    TextBox.Size = UDim2.new(0.55, 0, 0, 36)
    TextBox.Position = UDim2.new(0.45, 0, 0.5, 0)
    TextBox.AnchorPoint = Vector2.new(0, 0.5)
    TextBox.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    TextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    TextBox.ClearTextOnFocus = false
    TextBox.Font = Enum.Font.SourceSans
    TextBox.TextSize = 14
    TextBox.Text = defaultText
    TextBox.Parent = Container

    local UICornerBox = Instance.new("UICorner")
    UICornerBox.CornerRadius = UDim.new(0, 8)
    UICornerBox.Parent = TextBox

    Inputs[placeholder] = TextBox
end

local function createDropdownField(placeholder, options, defaultVal, layoutOrder, onSelectCallback, searchable)
    local Container = Instance.new("Frame")
    Container.Size = UDim2.new(1, 0, 0, 44)
    Container.BackgroundTransparency = 1
    Container.LayoutOrder = layoutOrder
    Container.Parent = ScrollFrame

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0.4, 0, 1, 0)
    Label.BackgroundTransparency = 1
    Label.TextColor3 = Color3.fromRGB(200, 200, 200)
    Label.Font = Enum.Font.SourceSans
    Label.TextSize = 14
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Text = "  " .. placeholder
    Label.Parent = Container

    local DropdownBtn = Instance.new("TextButton")
    DropdownBtn.Size = UDim2.new(0.55, 0, 0, 36)
    DropdownBtn.Position = UDim2.new(0.45, 0, 0.5, 0)
    DropdownBtn.AnchorPoint = Vector2.new(0, 0.5)
    DropdownBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    DropdownBtn.TextColor3 = Color3.fromRGB(255, 215, 0)
    DropdownBtn.Font = Enum.Font.SourceSansBold
    DropdownBtn.TextSize = 14
    DropdownBtn.Text = defaultVal .. "  ▼"
    DropdownBtn.Parent = Container

    local UICornerDrop = Instance.new("UICorner")
    UICornerDrop.CornerRadius = UDim.new(0, 8)
    UICornerDrop.Parent = DropdownBtn

    local DropdownList = Instance.new("ScrollingFrame")
    DropdownList.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    DropdownList.BorderSizePixel = 1
    DropdownList.BorderColor3 = Color3.fromRGB(60, 60, 70)
    DropdownList.Visible = false
    DropdownList.ScrollingEnabled = true
    DropdownList.ScrollBarThickness = 5
    DropdownList.ZIndex = 3 -- above the FIRE button / status label
    DropdownList.Parent = OverlayContainer

    local DropListLayout = Instance.new("UIListLayout")
    DropListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    DropListLayout.Parent = DropdownList

    local optButtons = {}
    local searchBox = nil

    if searchable then
        searchBox = Instance.new("TextBox")
        searchBox.Size = UDim2.new(1, 0, 0, 32)
        searchBox.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
        searchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
        searchBox.PlaceholderText = "  Search..."
        searchBox.PlaceholderColor3 = Color3.fromRGB(130, 130, 140)
        searchBox.Font = Enum.Font.SourceSans
        searchBox.TextSize = 14
        searchBox.TextXAlignment = Enum.TextXAlignment.Left
        searchBox.Text = ""
        searchBox.ClearTextOnFocus = false
        searchBox.LayoutOrder = 0
        searchBox.ZIndex = 4
        searchBox.Parent = DropdownList

        searchBox:GetPropertyChangedSignal("Text"):Connect(function()
            local q = string.lower(searchBox.Text)
            local visibleCount = 0
            for _, b in ipairs(optButtons) do
                local show = (q == "") or (string.find(string.lower(b.Text), q, 1, true) ~= nil)
                b.Visible = show
                if show then visibleCount = visibleCount + 1 end
            end
            DropdownList.CanvasSize = UDim2.new(0, 0, 0, 34 + visibleCount * 32)
        end)
    end

    local function updateDropdownPosition()
        local screenPos = DropdownBtn.AbsolutePosition - MainFrame.AbsolutePosition
        local listH = 160
        -- open downward, but flip upward if there isn't room below
        local y = screenPos.Y + DropdownBtn.AbsoluteSize.Y + 2
        if y + listH > MainFrame.AbsoluteSize.Y - 4 then
            y = screenPos.Y - listH - 2
        end
        DropdownList.Position = UDim2.new(0, screenPos.X, 0, math.max(2, y))
        DropdownList.Size = UDim2.new(0, DropdownBtn.AbsoluteSize.X, 0, listH)
    end

    DropdownFrames[placeholder] = DropdownList

    DropdownBtn.MouseButton1Click:Connect(function()
        local isCurrentlyVisible = DropdownList.Visible
        for _, listFrame in pairs(DropdownFrames) do
            listFrame.Visible = false
        end
        if not isCurrentlyVisible then
            if searchBox then searchBox.Text = "" end -- reset filter on open
            updateDropdownPosition()
            DropdownList.Visible = true
        end
    end)

    ScrollFrame:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
        if DropdownList.Visible then
            updateDropdownPosition()
        end
    end)

    for idx, optName in ipairs(options) do
        local OptBtn = Instance.new("TextButton")
        OptBtn.Size = UDim2.new(1, 0, 0, 32)
        OptBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
        OptBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        OptBtn.Font = Enum.Font.SourceSans
        OptBtn.TextSize = 14
        OptBtn.TextXAlignment = Enum.TextXAlignment.Left
        OptBtn.Text = "  " .. optName
        OptBtn.LayoutOrder = idx
        OptBtn.ZIndex = 4
        OptBtn.Parent = DropdownList
        table.insert(optButtons, OptBtn)

        OptBtn.MouseButton1Click:Connect(function()
            DropdownBtn.Text = optName .. "  ▼"
            DropdownList.Visible = false
            onSelectCallback(optName)
        end)
    end

    DropdownList.CanvasSize = UDim2.new(0, 0, 0, (searchable and 34 or 0) + (#options * 32))
end

-- Full Scanned Explorer Item Database
local GameBrainrots = {
    "Cacto Hipopotamo", "Cappuccino Assassino", "Cavallo Virtuoso", "Checkito Blockito",
    "Chef Crabracadabra", "Chicleteira Amerceira", "Chillin Chili", "Dragon Cannelloni",
    "Esok Englandah", "Espanol Chilli", "Fluri Flura", "Franco Hotspot",
    "Fungatto Supremo", "Ganganzelli Trulala", "Gangster Footera", "Girafa Celestre",
    "Glorbo Fruttodrillo", "Gorillo Watermelondrillo", "Graipuss Medussi", "Happy Banana Cat",
    "Illuminati", "Imperion Eternus", "Job Job Argentinhur", "Ketchuru And Musturu",
    "Ketupat Kepat", "King Goatimus", "La Grande Combinasion", "La Vacca Saturno Saturnita",
    "Lionelo Cactuseli", "Lirili Larila", "Lucky 67", "Lucky Ballerina Capucina",
    "Lucky Bombardiro Crocodilo", "Lucky Bombombini Gusini", "Lucky Cappuccino Assassino", "Lucky Chef Bearelli",
    "Lucky Chef Crabracadabra", "Lucky Chycleteira Bicicleteira", "Lucky Doctor Pigeon", "Lucky Dragon Cannelloni",
    "Lucky Dunkino Giraffo", "Lucky Esok Sekolah", "Lucky Ganganzelli Trulala", "Lucky Gangster Footera",
    "Lucky General Gloomius", "Lucky Glorbo Fruttodrillo", "Lucky Gorillo Watermelondrillo", "Lucky Job Job Job Sahur",
    "Lucky La Grande Combinasion", "Lucky La Vacca Saturno Saturnita", "Lucky Noobini Pizzanini", "Lucky Odin Din Din Dun",
    "Lucky Orangutini Ananassini", "Lucky Orcalero Orcala", "Lucky Pakrahmatmamat", "Lucky Pipi Potato",
    "Lucky Rhino Toasterino", "Lucky Rosabella Chimparella", "Lucky Samurushi", "Lucky Strawberry Elephant",
    "Lucky Talpa Di Fero", "Lucky Tatatata Sahur", "Lucky Torrtuginni Dragonfrutini", "Lucky Tralalita Tralala",
    "Lucky Tung Tung Sahur", "Melonetti Angurino", "Meowl", "Noo My Examine",
    "Noobini Brasilini", "Nuclearo Dinosauro", "Nyan Cat", "Occhiolibro Supremo",
    "Onironi Samurai", "Oraginto Punchito", "Orangutini Ananassini", "Orcalero Orcala",
    "Pandaccini Bananini", "Pandini Wizardo", "Panino Mortale", "Pipi Kiwi",
    "Pot Hotspot", "Prince Goatimus", "Quesadilla Crocodila", "Rhino Toasterino",
    "Robotello 3000", "Sahur Shinobini", "Siuuuuu Sahur", "Skibidi Toilet",
    "Smurf Cat", "Squalino Piratino", "Squalobottini 7000", "Strawberrelli Flamingelli",
    "Strawberry Elephant", "Strawhatto Bloxito", "Sun Sun Sahur", "Sunset Palmarino",
    "Sunsetto", "Surf Surf Surf Sahur", "Svinina Bombardino", "Swag Soda",
    "Talpa Di Fero", "Tatatata Sahur", "Tigroligre Frutonni", "Tiki Tiki Tropicano",
    "Tim Cheese", "Tralalero Tralala", "Tric Trac Barabum", "Triplito Traleritos",
    "Trippi Troppi", "Trippi Troppi Troppa Trippa", "Trollface", "Trulimero Trulicina",
    "Ultrario Infinitario", "Vengironi Samurai", "Victor Vengeance", "Yess My Examine",
    "Zibra Zubra Zibralini"
}

createDropdownField("Brainrot Item", GameBrainrots, SelectedBrainrot, 1,
    function(choice) SelectedBrainrot = choice end, true)

local GameMutations = { "Diamond", "Golden", "Galaxy", "Hacked", "Lava", "Void", "Rainbow", "Infernal" }
createDropdownField("Mutations", GameMutations, SelectedMutation, 2,
    function(choice) SelectedMutation = choice end)

local GameGrades = { "D", "C", "B", "A", "S", "SS", "SSS" }
createDropdownField("Grade", GameGrades, SelectedGrade, 3,
    function(choice) SelectedGrade = choice end)

local GameRarities = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Divine", "Secret", "Brainrot God", "Event" }
createDropdownField("Rarity", GameRarities, SelectedRarity, 4,
    function(choice) SelectedRarity = choice end)

local GameSizes = { "Normal", "Mini", "Giant", "Huge", "Titanic" }
createDropdownField("Size", GameSizes, SelectedSize, 5,
    function(choice) SelectedSize = choice end)

createDropdownField("Sunset", { "false", "true" }, SelectedSunset, 6,
    function(choice) SelectedSunset = choice end)

-- Explicit canvas sizing: computed from the actual rows (44px each + 8px padding).
-- More reliable than AutomaticCanvasSize across executor environments.
local function refreshMainCanvas()
    local rows = 0
    for _, child in ipairs(ScrollFrame:GetChildren()) do
        if child:IsA("GuiObject") then
            rows = rows + 1
        end
    end
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, rows * 44 + math.max(0, rows - 1) * 8)
end
refreshMainCanvas()

--------------------------------------------------------------------------------
-- Status label + Fire button
--------------------------------------------------------------------------------
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -16, 0, 20)
StatusLabel.Position = UDim2.new(0, 8, 1, -80)
StatusLabel.BackgroundTransparency = 1
StatusLabel.TextColor3 = Color3.fromRGB(160, 160, 170)
StatusLabel.Font = Enum.Font.SourceSans
StatusLabel.TextSize = 13
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.TextTruncate = Enum.TextTruncate.AtEnd
StatusLabel.Text = "Ready"
StatusLabel.Parent = MainFrame

local EquipButton = Instance.new("TextButton")
EquipButton.Size = UDim2.new(1, -16, 0, 44)
EquipButton.Position = UDim2.new(0, 8, 1, -52)
EquipButton.BackgroundColor3 = Color3.fromRGB(0, 160, 100)
EquipButton.TextColor3 = Color3.fromRGB(255, 255, 255)
EquipButton.Font = Enum.Font.SourceSansBold
EquipButton.TextSize = 16
EquipButton.Text = "🔥 FIRE REMOTE (EQUIP)"
EquipButton.Parent = MainFrame

local UICornerEquip = Instance.new("UICorner")
UICornerEquip.CornerRadius = UDim.new(0, 10)
UICornerEquip.Parent = EquipButton

ToggleButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

-- Close any open dropdown when clicking elsewhere (search boxes excluded via bounds check)
UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        local pos = input.Position
        local clickedDropdown = false
        for _, listFrame in pairs(DropdownFrames) do
            if listFrame.Visible then
                local guiPos = listFrame.AbsolutePosition
                local guiSize = listFrame.AbsoluteSize
                if pos.X >= guiPos.X and pos.X <= (guiPos.X + guiSize.X)
                    and pos.Y >= guiPos.Y and pos.Y <= (guiPos.Y + guiSize.Y) then
                    clickedDropdown = true
                    break
                end
            end
        end
        if not clickedDropdown then
            for _, listFrame in pairs(DropdownFrames) do
                listFrame.Visible = false
            end
        end
    end
end)

--------------------------------------------------------------------------------
-- Remote resolution (cached) + fire
--------------------------------------------------------------------------------
local cachedRemote = nil
local function resolveRemote()
    if cachedRemote then return cachedRemote end
    local networkFolder = ReplicatedStorage:FindFirstChild("Network")
    if networkFolder then
        local r = networkFolder:FindFirstChild("EquipBrainrot")
        if r and r:IsA("RemoteEvent") then
            cachedRemote = r
            return r
        end
    end
    local brainrotsThings = ReplicatedStorage:FindFirstChild("BrainrotsThings")
    if brainrotsThings then
        local misc = brainrotsThings:FindFirstChild("Misc")
        local events = misc and misc:FindFirstChild("Events")
        local playerFolder = events and events:FindFirstChild("Player")
        local r = playerFolder and playerFolder:FindFirstChild("EquipBrainrot")
        if r and r:IsA("RemoteEvent") then
            cachedRemote = r
            return r
        end
    end
    return nil
end

local lastFire = 0
EquipButton.MouseButton1Click:Connect(function()
    if os.clock() - lastFire < 0.8 then return end -- debounce
    lastFire = os.clock()

    local targetRemote = resolveRemote()
    if not targetRemote then
        StatusLabel.Text = "Error: EquipBrainrot remote not found"
        StatusLabel.TextColor3 = Color3.fromRGB(230, 120, 120)
        warn("Brainrot UI Error: Could not locate a valid 'EquipBrainrot' RemoteEvent path.")
        return
    end

    local brainrotName = SelectedBrainrot

    local payload = {
        ["toolName"] = brainrotName,
        ["brainrotName"] = brainrotName,
        ["grade"] = SelectedGrade,
        ["rarity"] = SelectedRarity,
        ["variant"] = SelectedMutation,
        ["size"] = SelectedSize,
        ["sunset"] = (SelectedSunset == "true"),
    }

    local ok, err = pcall(function()
        targetRemote:FireServer(payload)
    end)

    if ok then
        StatusLabel.Text = "Fired: " .. brainrotName .. " [" .. SelectedMutation .. "]"
        StatusLabel.TextColor3 = Color3.fromRGB(120, 220, 140)
    else
        StatusLabel.Text = "Fire failed: " .. tostring(err)
        StatusLabel.TextColor3 = Color3.fromRGB(230, 120, 120)
    end

    local originalColor = EquipButton.BackgroundColor3
    EquipButton.BackgroundColor3 = ok and Color3.fromRGB(0, 210, 130) or Color3.fromRGB(180, 60, 60)
    task.wait(0.25)
    EquipButton.BackgroundColor3 = originalColor
end)

print("[BrainrotEquipUI] v2 loaded")
