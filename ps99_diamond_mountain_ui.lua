--========================================================================
-- PS99 DIAMOND MOUNTAIN - SUMMIT AFK & YETI BOSS SUITE (DELTA EXECUTOR)
-- Phiên bản V6: Khắc phục triệt để lỗi "You can claim again in 18h37m",
-- nhận diện "The Shiny Yeti / Team up to beat it", không click nút Send Pets.
--========================================================================

-- 1. DIỆT SẠCH PHIÊN BẢN CŨ TRONG BỘ NHỚ KHI EXCUTE LẠI
local CURRENT_SESSION_ID = tick()
_G.PS99_SUMMIT_SESSION = CURRENT_SESSION_ID
_G.PS99_SUMMIT_RUNNING = false
task.wait(0.3)
_G.PS99_SUMMIT_RUNNING = true

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local RS = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")

local Player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local Camera = workspace.CurrentCamera

pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "💎 PS99 Summit Suite V6",
        Text = "Đang chạy phiên bản V6 tối ưu...",
        Duration = 3
    })
end)

-- Tìm nơi chứa GUI cho Delta Executor
local function getSafeGuiParent()
    if typeof(gethui) == "function" then
        local h = gethui()
        if h then return h end
    end
    local success, core = pcall(function() return game:GetService("CoreGui") end)
    if success and core then
        local canWrite = pcall(function()
            local t = Instance.new("Folder")
            t.Parent = core
            t:Destroy()
        end)
        if canWrite then return core end
    end
    return Player:WaitForChild("PlayerGui")
end

local GuiParent = getSafeGuiParent()

pcall(function()
    local containers = {}
    if typeof(gethui) == "function" then table.insert(containers, gethui()) end
    if game:GetService("CoreGui") then table.insert(containers, game:GetService("CoreGui")) end
    if Player:FindFirstChild("PlayerGui") then table.insert(containers, Player.PlayerGui) end

    for _, c in ipairs(containers) do
        for _, child in pairs(c:GetChildren()) do
            if child.Name == "PS99_Summit_Suite" then child:Destroy() end
        end
    end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PS99_Summit_Suite"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 999999
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = GuiParent

--========================================================================
-- TRẠNG THÁI VÀ CẤU HÌNH (STATE)
--========================================================================

local STATE = {
    -- [YETI BOSS]
    AutoYeti = true,
    AutoClickYeti = true,
    YetiKilledCount = 0,
    YetiCooldownAlert = true,
    IsFightingYeti = false,
    CurrentYetiObj = nil,
    YetiArenaCFrame = CFrame.new(-30054.5, 756.8, 31135.3),
    YetiStatusText = "⏳ Đang quét...",

    -- [HANG NÚI & TRỨNG]
    SelectedCave = 1,
    AutoCaveChests = false,
    AutoHatch = false,
    ShowHatchPopup = true,
    SkipAnimation = true,
    SelectedEggName = "Nearest",
    HatchAmount = 1,

    -- [BÃI FARM TIỀN]
    AutoFarmMoney = true,
    AutoHitBreakables = true,
    FarmCFrame = CFrame.new(-30114.6, 753.6, 30950.0),

    -- [TỌA ĐỘ 6 HANG NÚI]
    CaveCFrames = {
        [1] = nil,
        [2] = nil,
        [3] = nil,
        [4] = nil,
        [5] = nil,
        [6] = nil,
    },

    -- [AFK & TIỆN ÍCH]
    AntiAFK = true,
    AutoReconnect = true,
    AutoCollectDrops = true,
    AutoClaimExpeditions = true,
    LowCpuMode = false,

    -- [DISCORD WEBHOOK]
    Webhook = "https://discord.com/api/webhooks/1557705516178874429/DSxD6hH0VRjmXxBB44kQVM3VDhNvUwTp7h4uTCCtZK1k4vOLyOxLtjAfwxK2mCSS0MFb",
    DiscordUserId = "",
    MentionOnHuge = true,
    MentionOnTitanic = true,
    ReportInterval = 15 * 60,

    -- [THỐNG KÊ]
    SessionStart = os.time(),
    StartingDiamonds = 0,
    TotalHuge = 0,
    TotalTitanic = 0,
    TotalGargantuan = 0,
    TotalHatchedEggs = 0,
    CurrentAction = "Sẵn sàng"
}

--========================================================================
-- HỆ THỐNG LƯU VÀ TỰ ĐỘNG TẢI CẤU HÌNH (AUTO-SAVE / AUTO-LOAD CONFIG)
--========================================================================

local CONFIG_FILE = "PS99_Summit_Config.json"

local function cframeToTable(cf)
    if not cf or typeof(cf) ~= "CFrame" then return nil end
    return { cf:GetComponents() }
end

local function tableToCFrame(tbl)
    if not tbl or type(tbl) ~= "table" or #tbl < 12 then return nil end
    return CFrame.new(unpack(tbl))
end

local function saveConfig()
    pcall(function()
        if not writefile then return end
        local caveTbl = {}
        for i = 1, 6 do
            if STATE.CaveCFrames[i] then
                caveTbl[tostring(i)] = cframeToTable(STATE.CaveCFrames[i])
            end
        end
        local data = {
            SelectedCave = STATE.SelectedCave,
            FarmCFrame = cframeToTable(STATE.FarmCFrame),
            YetiArenaCFrame = cframeToTable(STATE.YetiArenaCFrame),
            CaveCFrames = caveTbl,
            AutoYeti = STATE.AutoYeti,
            AutoClickYeti = STATE.AutoClickYeti,
            AutoCaveChests = STATE.AutoCaveChests,
            AutoHatch = STATE.AutoHatch,
            AutoFarmMoney = STATE.AutoFarmMoney,
            AutoHitBreakables = STATE.AutoHitBreakables,
            ShowHatchPopup = STATE.ShowHatchPopup,
            SkipAnimation = STATE.SkipAnimation,
            SelectedEggName = STATE.SelectedEggName,
            TotalHatchedEggs = STATE.TotalHatchedEggs
        }
        writefile(CONFIG_FILE, HttpService:JSONEncode(data))
    end)
end

local function loadConfig()
    pcall(function()
        if not readfile or not isfile or not isfile(CONFIG_FILE) then return end
        local raw = readfile(CONFIG_FILE)
        if not raw or raw == "" then return end
        local data = HttpService:JSONDecode(raw)
        if not data or type(data) ~= "table" then return end
        
        if data.SelectedCave then STATE.SelectedCave = tonumber(data.SelectedCave) or STATE.SelectedCave end
        if data.FarmCFrame then
            local cf = tableToCFrame(data.FarmCFrame)
            if cf then STATE.FarmCFrame = cf end
        end
        if data.YetiArenaCFrame then
            local cf = tableToCFrame(data.YetiArenaCFrame)
            if cf then STATE.YetiArenaCFrame = cf end
        end
        if data.CaveCFrames and type(data.CaveCFrames) == "table" then
            for i = 1, 6 do
                local cfData = data.CaveCFrames[tostring(i)]
                if cfData then
                    local cf = tableToCFrame(cfData)
                    if cf then STATE.CaveCFrames[i] = cf end
                end
            end
        end
        if data.AutoYeti ~= nil then STATE.AutoYeti = data.AutoYeti end
        if data.AutoClickYeti ~= nil then STATE.AutoClickYeti = data.AutoClickYeti end
        if data.AutoCaveChests ~= nil then STATE.AutoCaveChests = data.AutoCaveChests end
        if data.AutoHatch ~= nil then STATE.AutoHatch = data.AutoHatch end
        if data.AutoFarmMoney ~= nil then STATE.AutoFarmMoney = data.AutoFarmMoney end
        if data.AutoHitBreakables ~= nil then STATE.AutoHitBreakables = data.AutoHitBreakables end
        if data.ShowHatchPopup ~= nil then STATE.ShowHatchPopup = data.ShowHatchPopup end
        if data.SkipAnimation ~= nil then STATE.SkipAnimation = data.SkipAnimation end
        if data.SelectedEggName and data.SelectedEggName ~= "" then STATE.SelectedEggName = data.SelectedEggName end
        if data.TotalHatchedEggs then STATE.TotalHatchedEggs = tonumber(data.TotalHatchedEggs) or 0 end
    end)
end

loadConfig()

--========================================================================
-- CÁC HÀM TIỆN ÍCH TỌA ĐỘ, RƯƠNG & TRỨNG HANG NÚI
--========================================================================

local function getPartFromInstance(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst end
    if inst:IsA("Model") then
        if inst.PrimaryPart then return inst.PrimaryPart end
        return inst:FindFirstChildWhichIsA("BasePart", true)
    end
    if inst:IsA("Folder") then
        return inst:FindFirstChildWhichIsA("BasePart", true)
    end
    return inst:FindFirstChildWhichIsA("BasePart", true)
end

local function safeTeleportTo(targetPos, lookTarget)
    if not targetPos then return end
    pcall(function()
        local char = Player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hrp then
            local pos = (typeof(targetPos) == "CFrame") and targetPos.Position or targetPos
            local cf = CFrame.new(pos)
            if lookTarget then
                local lPos = (typeof(lookTarget) == "CFrame") and lookTarget.Position or lookTarget
                cf = CFrame.lookAt(pos, Vector3.new(lPos.X, pos.Y, lPos.Z))
            elseif typeof(targetPos) == "CFrame" then
                cf = targetPos
            end
            if hum and hum.SeatPart then
                hum.Sit = false
                task.wait(0.05)
            end
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            hrp.CFrame = cf + Vector3.new(0, 2, 0)
        end
    end)
end

local function safeTeleport(cframe)
    safeTeleportTo(cframe, nil)
end

-- Tìm CFrame và đối tượng Rương của Hang đang chọn (Trail 1-6)
local function getCaveChest(caveNum)
    caveNum = caveNum or STATE.SelectedCave
    local targetArea = "trail" .. tostring(caveNum)
    local Things = workspace:FindFirstChild("__THINGS")
    local Breakables = Things and Things:FindFirstChild("Breakables")
    if Breakables then
        -- 1. Ưu tiên khớp chính xác AreaID hoặc ParentID với trailX
        for _, b in pairs(Breakables:GetChildren()) do
            local areaId = string.lower(tostring(b:GetAttribute("AreaID") or ""))
            local parentId = string.lower(tostring(b:GetAttribute("ParentID") or ""))
            local bId = string.lower(tostring(b:GetAttribute("BreakableID") or ""))
            local bClass = string.lower(tostring(b:GetAttribute("BreakableClass") or ""))
            
            local matchArea = (areaId == targetArea or parentId == targetArea or string.find(areaId, targetArea) or string.find(parentId, targetArea))
            local isChest = (bClass == "chest" or string.find(bId, "chest") or string.find(string.lower(b.Name), "chest"))
            
            if matchArea and (isChest or bId ~= "yeti") then
                local part = getPartFromInstance(b)
                if part then
                    return b, part.CFrame
                end
            end
        end
        
        -- 2. Khớp BreakableID chứa trail và caveNum (e.g. trailchest5)
        for _, b in pairs(Breakables:GetChildren()) do
            local bId = string.lower(tostring(b:GetAttribute("BreakableID") or ""))
            local areaId = string.lower(tostring(b:GetAttribute("AreaID") or ""))
            if string.find(bId, "trail") and (string.find(bId, tostring(caveNum)) or string.find(areaId, tostring(caveNum))) then
                local part = getPartFromInstance(b)
                if part then
                    return b, part.CFrame
                end
            end
        end
    end
    return nil, nil
end

-- Tìm CFrame và đối tượng Trứng của Hang đang chọn (Trail 1-6)
local function getCaveEgg(caveNum)
    caveNum = caveNum or STATE.SelectedCave
    local Things = workspace:FindFirstChild("__THINGS")
    local CustomEggs = Things and Things:FindFirstChild("CustomEggs")
    local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")

    if CustomEggs then
        -- 1. Ưu tiên khớp theo attribute DM_TrailEgg
        for _, egg in pairs(CustomEggs:GetChildren()) do
            local trailNum = egg:GetAttribute("DM_TrailEgg")
            if trailNum and tonumber(trailNum) == tonumber(caveNum) then
                local part = getPartFromInstance(egg)
                local eggId = egg:GetAttribute("DM_EggId")
                if not eggId or eggId == "" then eggId = egg.Name end
                if part then
                    return egg, part.CFrame, eggId
                end
            end
        end

        -- 2. Khớp tên có chứa trailX hoặc caveX
        for _, egg in pairs(CustomEggs:GetChildren()) do
            local eName = string.lower(egg.Name)
            if string.find(eName, "trail" .. tostring(caveNum)) or string.find(eName, "cave" .. tostring(caveNum)) then
                local part = getPartFromInstance(egg)
                local eggId = egg:GetAttribute("DM_EggId") or egg.Name
                if part then
                    return egg, part.CFrame, eggId
                end
            end
        end

        -- 3. Nếu đang đứng trong hang / gần trứng (< 160 studs), lấy ngay quả trứng CustomEgg gần nhất
        if hrp then
            local nearestEgg, minDist = nil, 160
            for _, egg in pairs(CustomEggs:GetChildren()) do
                local part = getPartFromInstance(egg)
                if part then
                    local dist = (part.Position - hrp.Position).Magnitude
                    if dist < minDist then
                        minDist = dist
                        nearestEgg = egg
                    end
                end
            end
            if nearestEgg then
                local part = getPartFromInstance(nearestEgg)
                local eggId = nearestEgg:GetAttribute("DM_EggId") or nearestEgg.Name
                return nearestEgg, part.CFrame, eggId
            end
        end
    end

    local Eggs = Things and Things:FindFirstChild("Eggs")
    if Eggs then
        for _, egg in pairs(Eggs:GetChildren()) do
            local trailNum = egg:GetAttribute("DM_TrailEgg")
            if trailNum and tonumber(trailNum) == tonumber(caveNum) then
                local part = getPartFromInstance(egg)
                local eggId = egg:GetAttribute("DM_EggId") or egg.Name
                if part then
                    return egg, part.CFrame, eggId
                end
            end
        end
    end

    return nil, nil, nil
end

--========================================================================
-- GIAO DIỆN NGƯỜI DÙNG (UI)
--========================================================================

local ToggleButton = Instance.new("TextButton")
ToggleButton.Name = "ToggleButton"
ToggleButton.Size = UDim2.new(0, 50, 0, 50)
ToggleButton.Position = UDim2.new(0, 15, 0.45, 0)
ToggleButton.BackgroundColor3 = Color3.fromRGB(24, 28, 40)
ToggleButton.Text = "💎"
ToggleButton.TextSize = 24
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.Font = Enum.Font.GothamBold
ToggleButton.Parent = ScreenGui

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(1, 0)
ToggleCorner.Parent = ToggleButton

local ToggleStroke = Instance.new("UIStroke")
ToggleStroke.Color = Color3.fromRGB(80, 140, 255)
ToggleStroke.Thickness = 2
ToggleStroke.Parent = ToggleButton

local isDraggingBtn = false
local dragStartBtn, startPosBtn
ToggleButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDraggingBtn = true
        dragStartBtn = input.Position
        startPosBtn = ToggleButton.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then isDraggingBtn = false end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if isDraggingBtn and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStartBtn
        ToggleButton.Position = UDim2.new(startPosBtn.X.Scale, startPosBtn.X.Offset + delta.X, startPosBtn.Y.Scale, startPosBtn.Y.Offset + delta.Y)
    end
end)

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.Size = UDim2.new(0, 510, 0, 360)
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Visible = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(45, 52, 70)
MainStroke.Thickness = 1.5
MainStroke.Parent = MainFrame

local isDraggingMain = false
local dragStartMain, startPosMain
MainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if input.Position.Y - MainFrame.AbsolutePosition.Y < 45 then
            isDraggingMain = true
            dragStartMain = input.Position
            startPosMain = MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then isDraggingMain = false end
            end)
        end
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if isDraggingMain and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStartMain
        MainFrame.Position = UDim2.new(startPosMain.X.Scale, startPosMain.X.Offset + delta.X, startPosMain.Y.Scale, startPosMain.Y.Offset + delta.Y)
    end
end)

local function toggleGui() MainFrame.Visible = not MainFrame.Visible end
ToggleButton.Activated:Connect(toggleGui)

-- TopBar
local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 42)
TopBar.BackgroundColor3 = Color3.fromRGB(24, 27, 38)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame

local TopBarCorner = Instance.new("UICorner")
TopBarCorner.CornerRadius = UDim.new(0, 12)
TopBarCorner.Parent = TopBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -60, 1, 0)
TitleLabel.Position = UDim2.new(0, 12, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "💎 PS99 SUMMIT SUITE V6 | YETI & FARM"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 13
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TopBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -36, 0.5, -15)
CloseBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.Parent = TopBar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 8)
CloseCorner.Parent = CloseBtn
CloseBtn.Activated:Connect(function() MainFrame.Visible = false end)

-- Sidebar
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 125, 1, -42)
Sidebar.Position = UDim2.new(0, 0, 0, 42)
Sidebar.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame

local SidebarLayout = Instance.new("UIListLayout")
SidebarLayout.Padding = UDim.new(0, 4)
SidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
SidebarLayout.Parent = Sidebar

local SidebarPad = Instance.new("UIPadding")
SidebarPad.PaddingTop = UDim.new(0, 8)
SidebarPad.Parent = Sidebar

local ContentContainer = Instance.new("Frame")
ContentContainer.Size = UDim2.new(1, -135, 1, -50)
ContentContainer.Position = UDim2.new(0, 130, 0, 46)
ContentContainer.BackgroundTransparency = 1
ContentContainer.Parent = MainFrame

local Pages = {}
local function createPage(name)
    local Page = Instance.new("ScrollingFrame")
    Page.Name = name
    Page.Size = UDim2.new(1, 0, 1, 0)
    Page.BackgroundTransparency = 1
    Page.ScrollBarThickness = 4
    Page.ScrollBarImageColor3 = Color3.fromRGB(80, 140, 255)
    Page.Visible = false
    Page.CanvasSize = UDim2.new(0, 0, 0, 440)
    Page.Parent = ContentContainer

    local Layout = Instance.new("UIListLayout")
    Layout.Padding = UDim.new(0, 6)
    Layout.Parent = Page

    local Pad = Instance.new("UIPadding")
    Pad.PaddingRight = UDim.new(0, 6)
    Pad.Parent = Page

    Pages[name] = Page
    return Page
end

local DashboardPage = createPage("Dashboard")
local YetiPage = createPage("Yeti")
local TrailsPage = createPage("Trails")
local FarmPage = createPage("Farm")
local SettingsPage = createPage("Settings")

local TabButtons = {}
local function addTabButton(text, pageName)
    local TabBtn = Instance.new("TextButton")
    TabBtn.Size = UDim2.new(1, -10, 0, 34)
    TabBtn.BackgroundColor3 = Color3.fromRGB(28, 32, 44)
    TabBtn.Text = text
    TabBtn.TextColor3 = Color3.fromRGB(180, 190, 210)
    TabBtn.Font = Enum.Font.GothamMedium
    TabBtn.TextSize = 11
    TabBtn.Parent = Sidebar

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 8)
    Corner.Parent = TabBtn

    TabBtn.Activated:Connect(function()
        for pName, pFrame in pairs(Pages) do
            pFrame.Visible = (pName == pageName)
        end
        for _, btn in pairs(TabButtons) do
            btn.BackgroundColor3 = Color3.fromRGB(28, 32, 44)
            btn.TextColor3 = Color3.fromRGB(180, 190, 210)
        end
        TabBtn.BackgroundColor3 = Color3.fromRGB(50, 110, 220)
        TabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    end)

    table.insert(TabButtons, TabBtn)
    return TabBtn
end

local btnDash = addTabButton("📊 Tổng Quan", "Dashboard")
addTabButton("👹 Yeti Boss", "Yeti")
addTabButton("⛰️ Hang & Trứng", "Trails")
addTabButton("💰 Bãi Farm Tiền", "Farm")
addTabButton("⚙️ Cài Đặt AFK", "Settings")

btnDash.BackgroundColor3 = Color3.fromRGB(50, 110, 220)
btnDash.TextColor3 = Color3.fromRGB(255, 255, 255)
DashboardPage.Visible = true

local function createToggle(parent, title, defaultVal, callback)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(1, 0, 0, 38)
    Frame.BackgroundColor3 = Color3.fromRGB(24, 28, 40)
    Frame.Parent = parent

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 8)
    Corner.Parent = Frame

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -60, 1, 0)
    Label.Position = UDim2.new(0, 10, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = title
    Label.TextColor3 = Color3.fromRGB(230, 230, 230)
    Label.Font = Enum.Font.GothamMedium
    Label.TextSize = 11
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Frame

    local ToggleBtn = Instance.new("TextButton")
    ToggleBtn.Size = UDim2.new(0, 42, 0, 22)
    ToggleBtn.Position = UDim2.new(1, -50, 0.5, -11)
    ToggleBtn.BackgroundColor3 = defaultVal and Color3.fromRGB(40, 180, 90) or Color3.fromRGB(70, 75, 90)
    ToggleBtn.Text = defaultVal and "BẬT" or "TẮT"
    ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    ToggleBtn.Font = Enum.Font.GothamBold
    ToggleBtn.TextSize = 10
    ToggleBtn.Parent = Frame

    local BtnCorner = Instance.new("UICorner")
    BtnCorner.CornerRadius = UDim.new(0, 6)
    BtnCorner.Parent = ToggleBtn

    local isToggled = defaultVal
    ToggleBtn.Activated:Connect(function()
        isToggled = not isToggled
        ToggleBtn.BackgroundColor3 = isToggled and Color3.fromRGB(40, 180, 90) or Color3.fromRGB(70, 75, 90)
        ToggleBtn.Text = isToggled and "BẬT" or "TẮT"
        callback(isToggled)
        saveConfig()
    end)
    return Frame
end

local function createActionButton(parent, text, color, callback)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, 34)
    Btn.BackgroundColor3 = color or Color3.fromRGB(50, 110, 220)
    Btn.Text = text
    Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    Btn.Font = Enum.Font.GothamBold
    Btn.TextSize = 11
    Btn.Parent = parent

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 8)
    Corner.Parent = Btn

    Btn.Activated:Connect(callback)
    return Btn
end

local function createInfoCard(parent, title, defaultText)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(1, 0, 0, 38)
    Frame.BackgroundColor3 = Color3.fromRGB(24, 28, 40)
    Frame.Parent = parent

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 8)
    Corner.Parent = Frame

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(0.5, 0, 1, 0)
    Title.Position = UDim2.new(0, 10, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = title
    Title.TextColor3 = Color3.fromRGB(160, 170, 190)
    Title.Font = Enum.Font.GothamMedium
    Title.TextSize = 11
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = Frame

    local Value = Instance.new("TextLabel")
    Value.Size = UDim2.new(0.5, -12, 1, 0)
    Value.Position = UDim2.new(0.5, 0, 0, 0)
    Value.BackgroundTransparency = 1
    Value.Text = defaultText
    Value.TextColor3 = Color3.fromRGB(255, 255, 255)
    Value.Font = Enum.Font.GothamBold
    Value.TextSize = 11
    Value.TextXAlignment = Enum.TextXAlignment.Right
    Value.Parent = Frame

    return Value
end

-- TRANG 1: DASHBOARD
local lblAction = createInfoCard(DashboardPage, "⚡ Hoạt Động:", STATE.CurrentAction)
local lblYetiStatus = createInfoCard(DashboardPage, "👹 Tình Trạng Yeti:", STATE.YetiStatusText)
local lblYetiCount = createInfoCard(DashboardPage, "🏆 Số Yeti Đã Diệt:", "0 con")
local lblHatchedEggs = createInfoCard(DashboardPage, "🥚 Số Trứng Đã Mở:", "0 quả")
local lblDiamonds = createInfoCard(DashboardPage, "💎 Kim Cương:", "Đang tải...")
local lblDiffDiamonds = createInfoCard(DashboardPage, "📈 Cày Được:", "+0 (+0/h)")
local lblUptime = createInfoCard(DashboardPage, "⏱️ Thời Gian Treo:", "00h 00m 00s")
local lblPets = createInfoCard(DashboardPage, "🐾 Huge / Titanic:", "0 / 0")

-- TRANG 2: YETI BOSS
createToggle(YetiPage, "👹 Auto Tele & Đánh Yeti Khi Hồi Sinh", STATE.AutoYeti, function(v) STATE.AutoYeti = v end)
createToggle(YetiPage, "⚡ Auto Click & Xuất Pet Đánh Yeti", STATE.AutoClickYeti, function(v) STATE.AutoClickYeti = v end)
createToggle(YetiPage, "🔔 Báo Webhook Khi Hạ Gục Yeti", STATE.YetiCooldownAlert, function(v) STATE.YetiCooldownAlert = v end)

createActionButton(YetiPage, "📍 Lưu Vị Trí Đấu Trường Yeti (Đứng Tại Bãi Boss)", Color3.fromRGB(40, 140, 90), function()
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        STATE.YetiArenaCFrame = hrp.CFrame
        saveConfig()
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "📍 Lưu Đấu Trường Yeti",
                Text = "Đã ghim tọa độ đấu trường Yeti thành công!",
                Duration = 3
            })
        end)
    end
end)

createActionButton(YetiPage, "🚀 Tele Tới Đấu Trường Yeti Ngay", Color3.fromRGB(80, 100, 160), function()
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if STATE.YetiArenaCFrame and hrp then
        hrp.CFrame = STATE.YetiArenaCFrame + Vector3.new(0, 3, 0)
    end
end)

createActionButton(YetiPage, "🔄 Đặt Lại Bộ Đếm Yeti (Reset Count)", Color3.fromRGB(180, 80, 50), function()
    STATE.YetiKilledCount = 0
    lblYetiCount.Text = "0 con"
end)

createActionButton(YetiPage, "🔄 Reconnect Server (Làm Sạch Lỗi Click Bản Cũ)", Color3.fromRGB(200, 60, 60), function()
    TeleportService:Teleport(game.PlaceId, Player)
end)

-- TRANG 3: HANG NÚI & TRỨNG
local lblSelectedEgg = createInfoCard(TrailsPage, "🥚 Trứng Đã Chọn:", STATE.SelectedEggName)

createActionButton(TrailsPage, "🔍 Quét Quả Trứng Đang Đứng Trước Mặt", Color3.fromRGB(40, 160, 120), function()
    local eggObj, eggCF, eggId = getCaveEgg(STATE.SelectedCave)
    local found = eggId
    if not found then
        local Things = workspace:FindFirstChild("__THINGS")
        local CustomEggs = Things and Things:FindFirstChild("CustomEggs")
        local EggsFolder = Things and Things:FindFirstChild("Eggs")
        local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local minDist = 90
            local function scanList(f)
                if not f then return end
                for _, egg in pairs(f:GetChildren()) do
                    local part = getPartFromInstance(egg)
                    if part then
                        local dist = (part.Position - hrp.Position).Magnitude
                        if dist < minDist then
                            minDist = dist
                            found = egg:GetAttribute("DM_EggId") or egg.Name
                        end
                    end
                end
            end
            scanList(CustomEggs)
            if not found then scanList(EggsFolder) end
        end
    end
    if not found then
        for _, obj in pairs(workspace:GetChildren()) do
            if obj:IsA("Model") and string.find(string.lower(obj.Name), "egg") then
                found = obj.Name
                break
            end
        end
    end
    if found then
        STATE.SelectedEggName = found
        lblSelectedEgg.Text = found
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "🥚 Đã Tìm Thấy Trứng!",
                Text = "Đã chọn: " .. found .. " (Hang " .. STATE.SelectedCave .. ")",
                Duration = 3
            })
        end)
    else
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "⚠️ Chưa Thấy Trứng",
                Text = "Hãy đứng lại sát quả trứng trong hang rồi bấm lại nút này nhé!",
                Duration = 3
            })
        end)
    end
end)

local CaveSelectorFrame = Instance.new("Frame")
CaveSelectorFrame.Size = UDim2.new(1, 0, 0, 42)
CaveSelectorFrame.BackgroundColor3 = Color3.fromRGB(24, 28, 40)
CaveSelectorFrame.Parent = TrailsPage

local CaveCorner = Instance.new("UICorner")
CaveCorner.CornerRadius = UDim.new(0, 8)
CaveCorner.Parent = CaveSelectorFrame

local CaveLabel = Instance.new("TextLabel")
CaveLabel.Size = UDim2.new(0, 75, 1, 0)
CaveLabel.Position = UDim2.new(0, 8, 0, 0)
CaveLabel.BackgroundTransparency = 1
CaveLabel.Text = "Chọn Hang:"
CaveLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
CaveLabel.Font = Enum.Font.GothamMedium
CaveLabel.TextSize = 11
CaveLabel.TextXAlignment = Enum.TextXAlignment.Left
CaveLabel.Parent = CaveSelectorFrame

local caveButtons = {}
for i = 1, 6 do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 36, 0, 26)
    btn.Position = UDim2.new(0, 80 + (i - 1) * 42, 0.5, -13)
    btn.BackgroundColor3 = (STATE.SelectedCave == i) and Color3.fromRGB(50, 110, 220) or Color3.fromRGB(35, 40, 55)
    btn.Text = "H" .. i
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.Parent = CaveSelectorFrame

    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(0, 6)
    bCorner.Parent = btn

    btn.Activated:Connect(function()
        STATE.SelectedCave = i
        for idx, b in ipairs(caveButtons) do
            b.BackgroundColor3 = (idx == i) and Color3.fromRGB(50, 110, 220) or Color3.fromRGB(35, 40, 55)
        end
        local eggObj, eggCF, eggId = getCaveEgg(i)
        if eggId then
            STATE.SelectedEggName = eggId
            lblSelectedEgg.Text = eggId
        else
            STATE.SelectedEggName = ""
            lblSelectedEgg.Text = "Hang " .. i .. " (Tự quét khi vào)"
        end
        if eggCF then
            STATE.CaveCFrames[i] = eggCF
        else
            local chestObj, chestCF = getCaveChest(i)
            if chestCF then STATE.CaveCFrames[i] = chestCF end
        end
        saveConfig()
    end)
    table.insert(caveButtons, btn)
end

createActionButton(TrailsPage, "📍 Lưu Vị Trí Hang Đang Đứng Cho Hang Đã Chọn", Color3.fromRGB(40, 140, 90), function()
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        STATE.CaveCFrames[STATE.SelectedCave] = hrp.CFrame
        saveConfig()
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "📍 Lưu Tọa Độ",
                Text = "Đã lưu vị trí Hang " .. STATE.SelectedCave .. " thành công!",
                Duration = 3
            })
        end)
    end
end)

createActionButton(TrailsPage, "🚀 Teleport Tới Hang Đã Chọn Ngay", Color3.fromRGB(80, 100, 160), function()
    local pos = STATE.CaveCFrames[STATE.SelectedCave]
    if not pos then
        local _, eggCF = getCaveEgg(STATE.SelectedCave)
        if eggCF then pos = eggCF end
    end
    if not pos then
        local _, chestCF = getCaveChest(STATE.SelectedCave)
        if chestCF then pos = chestCF end
    end
    if pos then
        safeTeleport(pos)
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "🚀 Dịch Chuyển Hang",
                Text = "Đã tới Hang " .. STATE.SelectedCave .. " thành công!",
                Duration = 2.5
            })
        end)
    else
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "⚠️ Chưa Có Tọa Độ Hang " .. STATE.SelectedCave,
                Text = "Hang chưa mở hoặc chưa có trong game!",
                Duration = 3
            })
        end)
    end
end)

createToggle(TrailsPage, "📦 Auto Phá Rương (Chests) Trong Hang", STATE.AutoCaveChests, function(v) STATE.AutoCaveChests = v end)
createToggle(TrailsPage, "🥚 Auto Mở Trứng (Auto Hatch Egg)", STATE.AutoHatch, function(v) STATE.AutoHatch = v end)
createToggle(TrailsPage, "🎁 Hiện Pop-up Kết Quả (Tự đóng sau 1.2s)", STATE.ShowHatchPopup, function(v) STATE.ShowHatchPopup = v end)
createToggle(TrailsPage, "⏩ Bỏ Qua Cắt Cảnh (Skip Cutscene Animation)", STATE.SkipAnimation, function(v) STATE.SkipAnimation = v end)

-- TRANG 4: BÃI FARM TIỀN
createToggle(FarmPage, "💰 Tự Động Về Farm Tiền (Khi không mở trứng)", STATE.AutoFarmMoney, function(v) STATE.AutoFarmMoney = v end)
createToggle(FarmPage, "⛏️ Auto Đánh Đá / Breakables Bãi Farm", STATE.AutoHitBreakables, function(v) STATE.AutoHitBreakables = v end)

createActionButton(FarmPage, "📍 Lưu Vị Trí Đang Đứng Làm Bãi Farm", Color3.fromRGB(40, 140, 90), function()
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        STATE.FarmCFrame = hrp.CFrame
        saveConfig()
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "📍 Lưu Bãi Farm",
                Text = "Đã lưu bãi cày tiền hiện tại thành công!",
                Duration = 3
            })
        end)
    end
end)

createActionButton(FarmPage, "🚀 Teleport Về Bãi Farm Ngay", Color3.fromRGB(80, 100, 160), function()
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if STATE.FarmCFrame and hrp then hrp.CFrame = STATE.FarmCFrame + Vector3.new(0, 3, 0) end
end)

-- TRANG 5: CÀI ĐẶT
createToggle(SettingsPage, "🛡️ Anti-AFK (Chống văng 20 phút)", STATE.AntiAFK, function(v) STATE.AntiAFK = v end)
createToggle(SettingsPage, "🔄 Auto Reconnect Khi Đứt Mạng", STATE.AutoReconnect, function(v) STATE.AutoReconnect = v end)
createToggle(SettingsPage, "🧲 Auto Hút Orbs & Nhặt Lootbags", STATE.AutoCollectDrops, function(v) STATE.AutoCollectDrops = v end)
createToggle(SettingsPage, "🏆 Auto Nhận Expeditions Đỉnh Núi", STATE.AutoClaimExpeditions, function(v) STATE.AutoClaimExpeditions = v end)
createToggle(SettingsPage, "🔋 Low CPU Mode (Màn Đen Tiết Kiệm Pin)", STATE.LowCpuMode, function(v)
    STATE.LowCpuMode = v
    pcall(function() RunService:Set3dRenderingEnabled(not v) end)
end)

-- NÚT DUMP LOG DEBUG
createActionButton(SettingsPage, "📋 Quét & Gửi Log Debug Về Discord", Color3.fromRGB(40, 160, 120), function()
    pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/Vt47/ps99-scripts/main/dump_info.lua"))()
    end)
end)

pcall(function()
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.KeyCode == Enum.KeyCode.RightShift then toggleGui() end
    end)
end)

--========================================================================
-- HỆ THỐNG XỬ LÝ NGẦM CHUYÊN SÂU
--========================================================================

task.spawn(function()
    local req = request or http_request or (syn and syn.request) or (http and http.request)

    local function sendWebhook(title, description, color, mention)
        if not req or not STATE.Webhook or STATE.Webhook == "" then return end
        pcall(function()
            local embed = {
                description = description,
                color = color or 5793266,
                footer = { text = "PS99 Summit Suite | " .. Player.Name },
                timestamp = DateTime.now():ToIsoDate()
            }
            if title and title ~= "" then embed.title = title end
            req({
                Url = STATE.Webhook,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode({
                    username = "Diamond Mountain Monitor",
                    content = mention or "",
                    embeds = { embed }
                })
            })
        end)
    end

    local Library, Client, Directory, Save, PetDirectory, Network, EggCmds
    pcall(function()
        Library = RS:WaitForChild("Library", 8)
        if Library then
            Client = Library:FindFirstChild("Client")
            Directory = Library:FindFirstChild("Directory")
            if Client and Client:FindFirstChild("Save") then Save = require(Client.Save) end
            if Directory and Directory:FindFirstChild("Pets") then PetDirectory = require(Directory.Pets) end
            if Client and Client:FindFirstChild("Network") then Network = require(Client.Network) end
            if Client and Client:FindFirstChild("EggCmds") then EggCmds = require(Client.EggCmds) end
        end
    end)
    if not Network and RS:FindFirstChild("Network") then Network = RS.Network end

    local function formatNumber(n)
        n = tonumber(n) or 0
        local sign = n < 0 and "-" or ""
        n = math.abs(n)
        if n >= 1e12 then return sign .. string.format("%.2fT", n / 1e12)
        elseif n >= 1e9 then return sign .. string.format("%.2fB", n / 1e9)
        elseif n >= 1e6 then return sign .. string.format("%.2fM", n / 1e6)
        elseif n >= 1e3 then return sign .. string.format("%.2fK", n / 1e3) end
        return sign .. tostring(math.floor(n))
    end

    local function formatDuration(seconds)
        seconds = math.max(0, math.floor(seconds))
        local h = math.floor(seconds / 3600)
        local m = math.floor((seconds % 3600) / 60)
        local s = seconds % 60
        return string.format("%02dh %02dm %02ds", h, m, s)
    end

    local function getDiamonds()
        local data
        pcall(function() if Save and Save.Get then data = Save.Get() end end)
        if not data or not data.Inventory or not data.Inventory.Currency then return 0 end
        for _, curr in pairs(data.Inventory.Currency) do
            if curr.id == "Diamonds" then return tonumber(curr._am) or 0 end
        end
        return 0
    end

    STATE.StartingDiamonds = getDiamonds()

    task.wait(1)
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp and not STATE.FarmCFrame then
        STATE.FarmCFrame = hrp.CFrame
        saveConfig()
    end


    -- BỘ QUÉT TÌM YETI CHÍNH XÁC (DỰA TRÊN DỮ LIỆU THỰC TẾ BREAKABLES & GUI YETI)
    local function checkYetiBoss()
        -- 1. Kiểm tra Breakables thực tế trong workspace.__THINGS.Breakables TRƯỚC TIÊN
        -- Dữ liệu scan chứng minh 100%: Yeti là một Breakable có BreakableID = "Yeti" và AreaID = "Yeti"
        local Things = workspace:FindFirstChild("__THINGS")
        local Breakables = Things and Things:FindFirstChild("Breakables")
        if Breakables then
            for _, b in pairs(Breakables:GetChildren()) do
                local bId = tostring(b:GetAttribute("BreakableID") or "")
                local areaId = tostring(b:GetAttribute("AreaID") or "")
                if string.lower(bId) == "yeti" or string.lower(areaId) == "yeti" then
                    local part = b:IsA("BasePart") and b or (b:IsA("Model") and (b.PrimaryPart or b:FindFirstChildWhichIsA("BasePart", true)))
                    if part then
                        return b, part.CFrame, nil
                    elseif STATE.YetiArenaCFrame then
                        return b, STATE.YetiArenaCFrame, nil
                    end
                end
            end
        end

        -- 2. Quét PlayerGui (Khi người chơi ở xa chưa stream Breakables đỉnh núi)
        local isCooldown = false
        local cdString = nil
        local isBossActiveGui = false

        pcall(function()
            for _, g in pairs(Player.PlayerGui:GetDescendants()) do
                if (g:IsA("TextLabel") or g:IsA("TextButton")) and g.Visible and g.Text ~= "" then
                    local pName = g.Parent and g.Parent.Name or ""
                    local t = string.lower(g.Text)

                    -- Bỏ qua hoàn toàn bảng quà tặng Free Gifts, vé rút thưởng, menu bên lề, tab, quest
                    if pName == "Free" or pName == "ItemChances" or g.Name == "ClaimTimer"
                       or pName == "Content" or pName == "Contents" or pName == "BlogEntry"
                       or pName == "TextHolder" or string.find(string.lower(g.Name), "quest")
                       or string.find(string.lower(pName), "quest") then
                        -- Bỏ qua
                    else
                        -- A. Cooldown Yeti thật
                        if string.find(t, "yeti") and (string.find(t, "returns in") or string.find(t, "again in") or string.find(t, "respawn in") or string.find(t, "next yeti") or string.find(t, "fight the yeti again")) then
                            isCooldown = true
                            cdString = string.match(g.Text, "%d+:%d+") or g.Text
                            break
                        end

                        -- B. Nhận diện Yeti Boss Đang Giao Tranh (CHỈ chấp nhận khi Parent là "Yeti" và có chữ damage/shiny/golden)
                        if pName == "Yeti" and (string.find(t, "damage") or string.find(t, "golden yeti") or string.find(t, "shiny yeti") or string.find(t, "rainbow yeti"))
                           and not string.find(t, "returns") and not string.find(t, "again in") and not string.find(t, "leaderboard") and not string.find(t, "fight the yeti") then
                            isBossActiveGui = true
                        end
                    end
                end
            end
        end)

        -- Nếu đang có banner đếm ngược Yeti Cooldown -> Yeti CHẮC CHẮN chưa hồi sinh
        if isCooldown then
            return nil, nil, cdString
        end

        -- Nếu trên màn hình có thanh máu giao tranh (The Golden Yeti / The Shiny Yeti / Parent Yeti):
        if isBossActiveGui and STATE.YetiArenaCFrame then
            return "YetiActiveFromGui", STATE.YetiArenaCFrame, nil
        end

        -- 3. Kiểm tra Model Boss trong Workspace (LOẠI BỎ Leaderboard, tượng, pet)
        for _, obj in pairs(workspace:GetChildren()) do
            if obj:IsA("Model") then
                local l = string.lower(obj.Name)
                if (string.find(l, "yeti") or string.find(l, "abominable"))
                   and not string.find(l, "leaderboard")
                   and not string.find(l, "board")
                   and not string.find(l, "statue")
                   and not string.find(l, "sign")
                   and not string.find(l, "egg")
                   and not string.find(l, "pet")
                   and not Players:GetPlayerFromCharacter(obj) then
                    local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
                    if part then return obj, part.CFrame, nil end
                end
            end
        end

        return nil, nil, nil
    end

    -- TẤN CÔNG YETI BẰNG NETWORK (KHÔNG CHẠM VÀO MÀN HÌNH NÉ NÚT SEND PETS)
    local function performAttackYeti(targetObj)
        if not STATE.AutoClickYeti then return end

        if Network and Network.Fire then
            pcall(function()
                local targetUID = nil
                if typeof(targetObj) == "Instance" then
                    targetUID = targetObj.Name
                else
                    local Things = workspace:FindFirstChild("__THINGS")
                    local Breakables = Things and Things:FindFirstChild("Breakables")
                    if Breakables then
                        for _, b in pairs(Breakables:GetChildren()) do
                            local bId = tostring(b:GetAttribute("BreakableID") or "")
                            local areaId = tostring(b:GetAttribute("AreaID") or "")
                            if string.lower(bId) == "yeti" or string.lower(areaId) == "yeti" then
                                targetUID = b.Name
                                break
                            end
                        end
                        if not targetUID and STATE.YetiArenaCFrame then
                            for _, b in pairs(Breakables:GetChildren()) do
                                local part = b:IsA("BasePart") and b or (b:IsA("Model") and (b.PrimaryPart or b:FindFirstChildWhichIsA("BasePart", true)))
                                if part and (part.Position - STATE.YetiArenaCFrame.Position).Magnitude < 90 then
                                    targetUID = b.Name
                                    break
                                end
                            end
                        end
                    end
                end

                if targetUID then
                    Network.Fire("Breakables_PlayerAttackBreakable", targetUID, "1")
                    Network.Fire("Breakables_PlayerAttackBreakable", targetUID, {})
                end
            end)
        end
    end

    -- VÒNG LẶP SĂN YETI
    task.spawn(function()
        while _G.PS99_SUMMIT_RUNNING and _G.PS99_SUMMIT_SESSION == CURRENT_SESSION_ID do
            task.wait(0.4)
            if STATE.AutoYeti then
                local yetiObj, yetiPos, cdTimer = checkYetiBoss()

                if yetiObj and yetiPos then
                    STATE.YetiStatusText = "🔥 Đang Sống!"
                    STATE.CurrentYetiObj = yetiObj
                    if not STATE.IsFightingYeti then
                        STATE.IsFightingYeti = true
                        STATE.CurrentAction = "⚔️ Đang săn Yeti Boss!"
                        if not STATE.YetiArenaCFrame and typeof(yetiPos) == "CFrame" then
                            STATE.YetiArenaCFrame = yetiPos
                        end
                        safeTeleport(yetiPos + Vector3.new(0, 2, 6))
                    end
                else
                    STATE.CurrentYetiObj = nil
                    if cdTimer then
                        STATE.YetiStatusText = "⏳ Đang Chờ (" .. cdTimer .. ")"
                    else
                        STATE.YetiStatusText = "⏳ Chưa hồi sinh"
                    end

                    if STATE.IsFightingYeti then
                        STATE.IsFightingYeti = false
                        STATE.YetiKilledCount = STATE.YetiKilledCount + 1
                        STATE.CurrentAction = "🏆 Yeti đã bị hạ gục!"

                        if STATE.YetiCooldownAlert then
                            sendWebhook(
                                "💥 ĐÃ HẠ GỤC YETI BOSS!",
                                "Tài khoản **" .. Player.Name .. "** đã tiêu diệt Yeti thành công!\n**Tổng số Yeti:** `" .. STATE.YetiKilledCount .. " con`",
                                16766720
                            )
                        end

                        task.wait(1.5)

                        if STATE.AutoHatch or STATE.AutoCaveChests then
                            local cavePos = STATE.CaveCFrames[STATE.SelectedCave]
                            if not cavePos then
                                local _, ccf = getCaveChest(STATE.SelectedCave)
                                cavePos = ccf
                            end
                            if not cavePos then
                                local _, ecf = getCaveEgg(STATE.SelectedCave)
                                cavePos = ecf
                            end
                            if cavePos then
                                safeTeleport(cavePos)
                                STATE.CurrentAction = "🚀 Quay lại Hang " .. STATE.SelectedCave
                            end
                        elseif STATE.AutoFarmMoney then
                            if STATE.FarmCFrame then
                                safeTeleport(STATE.FarmCFrame)
                                STATE.CurrentAction = "💰 Cày tiền tại Bãi Farm"
                            end
                        end
                    else
                        if STATE.AutoHatch or STATE.AutoCaveChests then
                            STATE.CurrentAction = "🚀 Đang xử lý Hang " .. STATE.SelectedCave
                        elseif STATE.AutoFarmMoney then
                            STATE.CurrentAction = "💰 Cày tiền tại Bãi Farm"
                        else
                            STATE.CurrentAction = "💤 Đang chờ lệnh..."
                        end
                    end
                end
            else
                STATE.IsFightingYeti = false
                STATE.CurrentYetiObj = nil
            end
        end
    end)

    -- VÒNG LẶP AUTO CLICK YETI TỐC ĐỘ CAO (~12 CLICKS / GIÂY)
    task.spawn(function()
        while _G.PS99_SUMMIT_RUNNING and _G.PS99_SUMMIT_SESSION == CURRENT_SESSION_ID do
            task.wait(0.08)
            if STATE.AutoYeti and STATE.AutoClickYeti and STATE.IsFightingYeti then
                performAttackYeti(STATE.CurrentYetiObj)
            end
        end
    end)

    -- TÌM TÊN TRỨNG CHÍNH XÁC TRONG HANG
    local function getRealEggName()
        if STATE.SelectedEggName and STATE.SelectedEggName ~= "Nearest" and STATE.SelectedEggName ~= "" then
            return STATE.SelectedEggName
        end

        local eggObj, eggCF, eggId = getCaveEgg(STATE.SelectedCave)
        if eggId then
            STATE.SelectedEggName = eggId
            return eggId, eggObj
        end

        local Things = workspace:FindFirstChild("__THINGS")
        local CustomEggs = Things and Things:FindFirstChild("CustomEggs")
        local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")

        -- Quét quả trứng gần nhất trong CustomEggs
        if CustomEggs and hrp then
            local nearest, minDist = nil, 140
            for _, egg in pairs(CustomEggs:GetChildren()) do
                local part = getPartFromInstance(egg)
                if part then
                    local dist = (part.Position - hrp.Position).Magnitude
                    if dist < minDist then
                        minDist = dist
                        nearest = egg
                    end
                end
            end
            if nearest then
                local eId = nearest:GetAttribute("DM_EggId")
                if not eId or eId == "" then eId = nearest.Name end
                return eId, nearest
            end
        end

        return nil, nil
    end

    -- XỬ LÝ POP-UP VÀ BỎ QUA CẮT CẢNH MỞ TRỨNG (NON-DESTRUCTIVE)
    local function handleEggOpeningVisuals()
        pcall(function()
            if STATE.SkipAnimation then
                local ps = Player:FindFirstChild("PlayerScripts")
                local gameScripts = ps and ps:FindFirstChild("Scripts") and ps.Scripts:FindFirstChild("Game")
                if gameScripts then
                    local eggFrontend = gameScripts:FindFirstChild("Egg Opening Frontend")
                    if eggFrontend and getsenv then
                        local env = getsenv(eggFrontend)
                        if env and env.PlayEggAnimation then
                            env.PlayEggAnimation = function() return end
                        end
                    end
                end
            end

            -- Tự động đóng pop-up OK / Continue / Dismiss kết quả mở trứng
            task.spawn(function()
                task.wait(0.3)
                for _, btn in pairs(Player.PlayerGui:GetDescendants()) do
                    if (btn:IsA("TextButton") or btn:IsA("ImageButton")) and btn.Visible then
                        local bName = string.lower(btn.Name)
                        local bText = btn:IsA("TextButton") and string.lower(btn.Text) or ""
                        if bText == "ok" or bText == "continue" or bName == "ok" or bName == "close" or bName == "dismiss" or bName == "next" then
                            pcall(function()
                                if btn.MouseButton1Click then btn.MouseButton1Click:Fire() end
                                if btn.Activated then btn.Activated:Fire() end
                            end)
                        end
                    end
                end
            end)
        end)
    end

    -- HÀM MỞ TRỨNG TỔNG HỢP (MULTI-ENGINE EGG HATCHER)
    local function attemptHatchEgg(eggObj, eggId, amt)
        if not eggId and not eggObj then return false end
        amt = amt or 1
        local hatched = false

        -- ENGINE 1: MODULE NỘI BỘ GAME (Library.Client.EggCmds)
        if EggCmds then
            pcall(function()
                if EggCmds.Purchase then
                    EggCmds.Purchase(eggId, amt)
                    hatched = true
                elseif EggCmds.Open then
                    EggCmds.Open(eggId, amt)
                    hatched = true
                elseif EggCmds.RequestPurchase then
                    EggCmds.RequestPurchase(eggId, amt)
                    hatched = true
                elseif EggCmds.Hatch then
                    EggCmds.Hatch(eggId, amt)
                    hatched = true
                end
            end)
            if not hatched and eggObj and eggObj.Name ~= eggId then
                pcall(function()
                    if EggCmds.Purchase then
                        EggCmds.Purchase(eggObj.Name, amt)
                        hatched = true
                    elseif EggCmds.Open then
                        EggCmds.Open(eggObj.Name, amt)
                        hatched = true
                    end
                end)
            end
        end

        -- ENGINE 2: TẤT CẢ CANDIDATE REMOTES QUA NETWORK.INVOKE
        if not hatched and Network and Network.Invoke then
            local candidateFuncs = {
                "Eggs_RequestPurchase",
                "CustomEggs_RequestPurchase",
                "CustomEggs_Purchase",
                "CustomEggs_Hatch",
                "Eggs_Hatch",
                "Eggs_Purchase",
                "TrailEggs_RequestPurchase",
                "TrailEgg_RequestPurchase",
                "Trail_RequestPurchase"
            }
            for _, rName in ipairs(candidateFuncs) do
                -- Thử với eggId
                pcall(function()
                    local r = Network.Invoke(rName, eggId, amt)
                    if r ~= nil and r ~= false then hatched = true end
                end)
                if hatched then break end

                -- Thử 3 tham số (golden/charged flag)
                pcall(function()
                    local r = Network.Invoke(rName, eggId, amt, false)
                    if r ~= nil and r ~= false then hatched = true end
                end)
                if hatched then break end

                -- Thử với UID eggObj.Name
                if eggObj and eggObj.Name ~= eggId then
                    pcall(function()
                        local r = Network.Invoke(rName, eggObj.Name, amt)
                        if r ~= nil and r ~= false then hatched = true end
                    end)
                    if hatched then break end
                end
            end
        end

        -- ENGINE 3: TẤT CẢ CANDIDATE REMOTES QUA NETWORK.FIRE
        if not hatched and Network and Network.Fire then
            local candidateEvents = {
                "Eggs_RequestPurchase",
                "CustomEggs_RequestPurchase",
                "CustomEggs_Purchase",
                "CustomEggs_Hatch",
                "Eggs_Hatch",
                "Eggs_Purchase"
            }
            for _, rName in ipairs(candidateEvents) do
                pcall(function()
                    Network.Fire(rName, eggId, amt)
                end)
                if eggObj and eggObj.Name ~= eggId then
                    pcall(function()
                        Network.Fire(rName, eggObj.Name, amt)
                    end)
                end
            end
        end

        -- ENGINE 4: KÍCH HOẠT NÚT BẤM GUI MỞ TRỨNG TRÊN MÀN HÌNH
        pcall(function()
            for _, g in pairs(Player.PlayerGui:GetDescendants()) do
                if (g:IsA("TextButton") or g:IsA("ImageButton")) and g.Visible then
                    local bName = string.lower(g.Name)
                    local bText = g:IsA("TextButton") and string.lower(g.Text) or ""
                    if bName == "1egg" or bName == "3egg" or bName == "autohatch" or bName == "hatch"
                       or bText == "1 egg" or bText == "3 eggs" or bText == "auto hatch" or bText == "buy" then
                        if g.MouseButton1Click then g.MouseButton1Click:Fire() end
                        if g.Activated then g.Activated:Fire() end
                        hatched = true
                    end
                end
            end
        end)

        -- ENGINE 5: KÍCH HOẠT PROXIMITYPROMPT NẾU CÓ
        if eggObj then
            for _, pp in pairs(eggObj:GetDescendants()) do
                if pp:IsA("ProximityPrompt") and pp.Enabled then
                    pcall(function()
                        if fireproximityprompt then
                            fireproximityprompt(pp)
                            hatched = true
                        end
                    end)
                end
            end
        end

        return hatched
    end

    -- BỘ ĐẾM THÚ CƯNG TRONG KHO ĐỂ THEO DÕI SỐ TRỨNG ĐÃ MỞ CHÍNH XÁC
    local lastPetCount = nil
    local function getInventoryPetCount()
        if not Save or not Save.Get then return nil end
        local count = 0
        local ok = pcall(function()
            local s = Save.Get()
            if s and s.Inventory and s.Inventory.Pet then
                for _, pData in pairs(s.Inventory.Pet) do
                    count = count + (pData._am or 1)
                end
            end
        end)
        return ok and count or nil
    end
    lastPetCount = getInventoryPetCount()

    -- VÒNG LẶP ĐIỀU PHỐI HANG, RƯƠNG & TRỨNG CHUYÊN SÂU (UNIFIED COORDINATOR)
    task.spawn(function()
        while _G.PS99_SUMMIT_RUNNING and _G.PS99_SUMMIT_SESSION == CURRENT_SESSION_ID do
            task.wait(0.25)
            
            -- Chỉ hoạt động khi không bận giao tranh Yeti Boss
            if not STATE.IsFightingYeti then
                local char = Player.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                
                -- BƯỚC 1: KIỂM TRA RƯƠNG TRONG HANG NẾU BẬT AUTO PHÁ RƯƠNG
                local chestObj, chestCF = nil, nil
                if STATE.AutoCaveChests then
                    chestObj, chestCF = getCaveChest(STATE.SelectedCave)
                end
                
                if chestObj and chestCF and hrp then
                    if not STATE.CaveCFrames[STATE.SelectedCave] then
                        STATE.CaveCFrames[STATE.SelectedCave] = chestCF
                        saveConfig()
                    else
                        STATE.CaveCFrames[STATE.SelectedCave] = chestCF
                    end
                    local dist = (chestCF.Position - hrp.Position).Magnitude
                    
                    -- Nếu đang đứng ngoài hang hoặc cách rương > 14 studs, tự động teleport vào sát rương
                    if dist > 14 then
                        local standPos = chestCF.Position + Vector3.new(0, 1, 5)
                        safeTeleportTo(standPos, chestCF.Position)
                        task.wait(0.2)
                    end
                    
                    STATE.CurrentAction = "📦 Đang phá Rương Hang " .. STATE.SelectedCave
                    
                    if Network and Network.Fire then
                        pcall(function()
                            Network.Fire("Breakables_PlayerAttackBreakable", chestObj.Name, "1")
                            Network.Fire("Breakables_PlayerAttackBreakable", chestObj.Name, {})
                        end)
                    end
                    
                -- BƯỚC 2: RƯƠNG ĐÃ BỊ PHÁ (HOẶC TẮT PHÁ RƯƠNG) -> TIẾN HÀNH MỞ TRỨNG HANG
                elseif STATE.AutoHatch and hrp then
                    local eggObj, eggCF, eggId = getCaveEgg(STATE.SelectedCave)
                    if not eggId then
                        eggId, eggObj = getRealEggName()
                    end
                    if eggObj and not eggCF then
                        local part = getPartFromInstance(eggObj)
                        if part then eggCF = part.CFrame end
                    end
                    
                    if eggCF then
                        if not STATE.CaveCFrames[STATE.SelectedCave] then
                            STATE.CaveCFrames[STATE.SelectedCave] = eggCF
                            saveConfig()
                        else
                            STATE.CaveCFrames[STATE.SelectedCave] = eggCF
                        end
                        local dist = (eggCF.Position - hrp.Position).Magnitude
                        
                        -- Teleport đứng ngay trên bệ trứng (<= 4 studs) để kích hoạt toàn bộ cơ chế của game
                        if dist > 4 then
                            local standPos = eggCF.Position + Vector3.new(0, 1.2, 0)
                            safeTeleportTo(standPos, eggCF.Position)
                            task.wait(0.2)
                        end
                    elseif STATE.CaveCFrames[STATE.SelectedCave] then
                        local dist = (STATE.CaveCFrames[STATE.SelectedCave].Position - hrp.Position).Magnitude
                        if dist > 15 then
                            safeTeleport(STATE.CaveCFrames[STATE.SelectedCave])
                            task.wait(0.2)
                        end
                    end
                    
                    if eggId and eggId ~= "Nearest" and eggId ~= "" then
                        STATE.CurrentAction = "🥚 Mở trứng: " .. eggId .. " (H" .. STATE.SelectedCave .. ")"
                        
                        local amt = STATE.HatchAmount or 1
                        local hatchedThisCycle = attemptHatchEgg(eggObj, eggId, amt)
                        
                        -- Cập nhật bộ đếm số trứng đã mở
                        local curPetCount = getInventoryPetCount()
                        if curPetCount and lastPetCount then
                            if curPetCount > lastPetCount then
                                local deltaPets = curPetCount - lastPetCount
                                STATE.TotalHatchedEggs = STATE.TotalHatchedEggs + deltaPets
                            end
                            lastPetCount = curPetCount
                        elseif hatchedThisCycle then
                            STATE.TotalHatchedEggs = STATE.TotalHatchedEggs + amt
                        end
                        
                        handleEggOpeningVisuals()
                    else
                        STATE.CurrentAction = "⏳ Chờ Hang " .. STATE.SelectedCave .. " mở cửa..."
                        -- Nếu hang chưa mở và có bật cày tiền, tạm thời về bãi cày tiền trong khi chờ
                        if STATE.AutoFarmMoney and STATE.FarmCFrame then
                            local dist = (STATE.FarmCFrame.Position - hrp.Position).Magnitude
                            if dist > 35 then
                                safeTeleport(STATE.FarmCFrame)
                                task.wait(0.3)
                            end
                            if STATE.AutoHitBreakables then
                                local Things = workspace:FindFirstChild("__THINGS")
                                local Breakables = Things and Things:FindFirstChild("Breakables")
                                if Breakables then
                                    local nearest, minDist = nil, 100
                                    for _, b in pairs(Breakables:GetChildren()) do
                                        local part = getPartFromInstance(b)
                                        if part then
                                            local d = (part.Position - hrp.Position).Magnitude
                                            if d < minDist then minDist = d; nearest = b end
                                        end
                                    end
                                    if nearest and Network and Network.Fire then
                                        pcall(function()
                                            Network.Fire("Breakables_PlayerAttackBreakable", nearest.Name, "1")
                                            Network.Fire("Breakables_PlayerAttackBreakable", nearest.Name, {})
                                        end)
                                    end
                                end
                            end
                        else
                            task.wait(0.8)
                        end
                    end
                    
                -- BƯỚC 3: NẾU KHÔNG MỞ TRỨNG & KHÔNG PHÁ RƯƠNG NHƯNG BẬT CÀY TIỀN
                elseif STATE.AutoFarmMoney and hrp then
                    if STATE.FarmCFrame then
                        local dist = (STATE.FarmCFrame.Position - hrp.Position).Magnitude
                        if dist > 35 then
                            safeTeleport(STATE.FarmCFrame)
                            task.wait(0.3)
                        end
                    end
                    
                    if STATE.AutoHitBreakables then
                        STATE.CurrentAction = "💰 Cày tiền tại Bãi Farm"
                        local Things = workspace:FindFirstChild("__THINGS")
                        local Breakables = Things and Things:FindFirstChild("Breakables")
                        if Breakables then
                            local nearest, minDist = nil, 100
                            for _, b in pairs(Breakables:GetChildren()) do
                                local part = getPartFromInstance(b)
                                if part then
                                    local dist = (part.Position - hrp.Position).Magnitude
                                    if dist < minDist then
                                        minDist = dist
                                        nearest = b
                                    end
                                end
                            end
                            if nearest and Network and Network.Fire then
                                pcall(function()
                                    Network.Fire("Breakables_PlayerAttackBreakable", nearest.Name, "1")
                                    Network.Fire("Breakables_PlayerAttackBreakable", nearest.Name, {})
                                end)
                            end
                        end
                    end
                else
                    STATE.CurrentAction = "💤 Đang chờ lệnh..."
                end
            end
        end
    end)

    -- HÚT ORBS & LOOTBAGS
    task.spawn(function()
        while _G.PS99_SUMMIT_RUNNING and _G.PS99_SUMMIT_SESSION == CURRENT_SESSION_ID do
            task.wait(0.4)
            if STATE.AutoCollectDrops then
                pcall(function()
                    local c = Player.Character
                    local h = c and c:FindFirstChild("HumanoidRootPart")
                    local Things = workspace:FindFirstChild("__THINGS")
                    if h and Things then
                        local Orbs = Things:FindFirstChild("Orbs")
                        if Orbs then
                            for _, o in pairs(Orbs:GetChildren()) do
                                if o:IsA("BasePart") then o.CFrame = h.CFrame end
                            end
                        end
                        local Lootbags = Things:FindFirstChild("Lootbags")
                        if Lootbags then
                            for _, bag in pairs(Lootbags:GetChildren()) do
                                local p = bag:IsA("BasePart") and bag or (bag:IsA("Model") and (bag.PrimaryPart or bag:FindFirstChildWhichIsA("BasePart")))
                                if p then p.CFrame = h.CFrame end
                            end
                        end
                    end
                end)
            end
        end
    end)

    -- Anti-AFK
    Player.Idled:Connect(function()
        if STATE.AntiAFK and _G.PS99_SUMMIT_RUNNING and VirtualUser then
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end
    end)

    -- Auto Reconnect
    pcall(function()
        GuiService.ErrorMessageChanged:Connect(function()
            if STATE.AutoReconnect and _G.PS99_SUMMIT_RUNNING and GuiService:GetErrorCode().Value > 0 then
                sendWebhook("⚠️ MẤT KẾT NỐI", "Đang thử Reconnect vào server sau 10 giây...", 15158332)
                task.wait(10)
                TeleportService:Teleport(game.PlaceId, Player)
            end
        end)
    end)

    -- CẬP NHẬT DASHBOARD
    task.spawn(function()
        while _G.PS99_SUMMIT_RUNNING and _G.PS99_SUMMIT_SESSION == CURRENT_SESSION_ID do
            task.wait(1)
            pcall(function()
                lblAction.Text = STATE.CurrentAction
                lblYetiStatus.Text = STATE.YetiStatusText
                lblYetiCount.Text = STATE.YetiKilledCount .. " con"
                lblHatchedEggs.Text = formatNumber(STATE.TotalHatchedEggs) .. " quả"
                local curD = getDiamonds()
                local diff = curD - STATE.StartingDiamonds
                local elapsed = math.max(1, os.time() - STATE.SessionStart)
                local rate = math.floor((diff / elapsed) * 3600)
                lblDiamonds.Text = formatNumber(curD)
                lblDiffDiamonds.Text = (diff >= 0 and "+" or "") .. formatNumber(diff) .. " (" .. formatNumber(rate) .. "/h)"
                lblUptime.Text = formatDuration(elapsed)
                lblPets.Text = "🟣 " .. STATE.TotalHuge .. " | 🔴 " .. STATE.TotalTitanic
            end)
        end
    end)
end)
