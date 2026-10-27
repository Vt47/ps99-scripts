--[[
    ========================================================================
    ⚡ PET SIMULATOR 99 - PSX CLASSIC (UPDATE 99) FAST AUTO HATCH & ANTI-AFK
    ========================================================================
    Phiên bản: V1.1 (Cực kỳ ổn định - Plug & Play cho mọi Executor)
    Tác giả: Vt47
    Chức năng chính:
      - 🥚 Tự động mở trứng siêu tốc (Fast Auto Hatch)
      - 🚀 Bỏ qua 100% hoạt ảnh đập trứng (Skip Hatch Animation)
      - 🎯 Tự nhận diện quả trứng người chơi đang đứng gần (Auto Nearest Egg)
      - 🔢 Tự động tính số lượng mở tối đa (Auto Max Hatch Slots)
      - 🛡️ Chống văng game 24/7 (Anti-AFK & Auto-Reconnect)
      - 🔋 Chế độ tiết kiệm pin / Low CPU (Màn đen cắm qua đêm)
      - 📱 Giao diện hiện đại, kéo thả mượt mà, hỗ trợ cả Mobile & PC
    ========================================================================
]]

-- Đợi game tải xong hoàn toàn
if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VirtualUser = nil
pcall(function() VirtualUser = game:GetService("VirtualUser") end)
local GuiService = game:GetService("GuiService")
local TeleportService = game:GetService("TeleportService")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local Player = Players.LocalPlayer
while not Player do
    task.wait(0.1)
    Player = Players.LocalPlayer
end

pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "⚡ PS99 PSX Classic",
        Text = "Đang tải giao diện mở trứng...",
        Duration = 3
    })
end)

--========================================================================
-- 1. TÌM NƠI CHỨA GUI AN TOÀN CHO MỌI EXECUTOR (DELTA, CODEX, ARCEUS, PC)
--========================================================================
local function getSafeGuiParent()
    if typeof(gethui) == "function" then
        local ok, h = pcall(gethui)
        if ok and h then return h end
    end
    local ok, core = pcall(function() return CoreGui end)
    if ok and core then
        local canWrite = pcall(function()
            local t = Instance.new("Folder")
            t.Parent = core
            t:Destroy()
        end)
        if canWrite then return core end
    end
    return Player:WaitForChild("PlayerGui", 5) or Player:FindFirstChild("PlayerGui")
end

local GuiParent = getSafeGuiParent()

-- Xoá GUI cũ nếu đang chạy để không bị trùng lặp
pcall(function()
    local oldList = {}
    if typeof(gethui) == "function" then
        local ok, h = pcall(gethui)
        if ok and h and h:FindFirstChild("PS99_PSXClassic_FastHatch") then table.insert(oldList, h.PS99_PSXClassic_FastHatch) end
    end
    if CoreGui and CoreGui:FindFirstChild("PS99_PSXClassic_FastHatch") then table.insert(oldList, CoreGui.PS99_PSXClassic_FastHatch) end
    if Player:FindFirstChild("PlayerGui") and Player.PlayerGui:FindFirstChild("PS99_PSXClassic_FastHatch") then table.insert(oldList, Player.PlayerGui.PS99_PSXClassic_FastHatch) end
    for _, g in ipairs(oldList) do
        g:Destroy()
    end
end)

--========================================================================
-- 2. TÌM VÀ REQUIRE CÁC MODULE CỦA PET SIMULATOR 99
--========================================================================
local Library, Client, Directory, Save, EggCmds, Network

pcall(function()
    Library = RS:FindFirstChild("Library") or RS:WaitForChild("Library", 5)
    if Library then
        Client = Library:FindFirstChild("Client")
        Directory = Library:FindFirstChild("Directory")
        if Client then
            if Client:FindFirstChild("Save") then Save = require(Client.Save) end
            if Client:FindFirstChild("EggCmds") then EggCmds = require(Client.EggCmds) end
            if Client:FindFirstChild("Network") then Network = require(Client.Network) end
        end
    end
end)
if not Network and RS:FindFirstChild("Network") then
    Network = RS.Network
end

--========================================================================
-- 3. CẤU HÌNH & TRẠNG THÁI (STATE)
--========================================================================
local STATE = {
    AutoHatch = false,
    SkipAnimation = true,
    AutoMaxHatch = true,
    CustomHatchAmount = 1,
    LowCpuMode = false,
    CurrentEggName = "Đang tìm trứng gần nhất...",
    CurrentEggObj = nil,
    IsCustomEgg = false,
    TotalHatched = 0,
    HatchSpeed = 0.08, -- Tốc độ gọi mở trứng (giây)
    StartTime = os.time(),
}

--========================================================================
-- 4. HÀM TÍNH SỐ LƯỢNG MỞ TỐI ĐA (MAX HATCH SLOTS)
--========================================================================
local function getMaxHatch()
    local maxAmt = nil
    pcall(function()
        if EggCmds and typeof(EggCmds.GetMaxHatch) == "function" then
            maxAmt = tonumber(EggCmds.GetMaxHatch())
        end
    end)
    pcall(function()
        if Save and Save.Get then
            local s = Save.Get()
            if s then
                local slots = tonumber(s.EggSlotsPurchased)
                local count = tonumber(s.EggHatchCount)
                if slots and slots > 0 then
                    local calc = slots + 4
                    if not maxAmt or calc > maxAmt then maxAmt = calc end
                end
                if count and count > 0 then
                    if not maxAmt or count > maxAmt then maxAmt = count end
                end
            end
        end
    end)
    return math.max(1, maxAmt or 1)
end

--========================================================================
-- 5. BỎ QUA HOẠT ẢNH MỞ TRỨNG (SKIP ANIMATION)
--========================================================================
local function disableEggAnimations()
    pcall(function()
        if EggCmds and typeof(EggCmds) == "table" then
            if EggCmds.PlayEggAnimation then EggCmds.PlayEggAnimation = function(...) return end end
            if EggCmds.PlayAnimation then EggCmds.PlayAnimation = function(...) return end end
        end
    end)

    pcall(function()
        if typeof(getsenv) == "function" then
            local scriptsFolder = Player:FindFirstChild("PlayerScripts") and Player.PlayerScripts:FindFirstChild("Scripts")
            local gameScripts = scriptsFolder and scriptsFolder:FindFirstChild("Game")
            if gameScripts then
                for _, name in ipairs({"Egg Opening Frontend", "Egg Opening", "EggOpeningFrontend"}) do
                    local sc = gameScripts:FindFirstChild(name)
                    if sc then
                        local env = getsenv(sc)
                        if env and env.PlayEggAnimation then
                            env.PlayEggAnimation = function(...) return end
                        end
                    end
                end
            end
        end
    end)

    pcall(function()
        local pg = Player:FindFirstChild("PlayerGui")
        if pg then
            for _, gName in ipairs({"EggOpening", "Eggs", "EggOpeningFrontend", "EggHatch", "Hatch", "CustomEggOpening", "EggOpeningUi"}) do
                local g = pg:FindFirstChild(gName)
                if g and g:IsA("ScreenGui") and g.Enabled then
                    g.Enabled = false
                end
            end
        end
    end)

    pcall(function()
        local cam = workspace.CurrentCamera
        if cam and cam.CameraType ~= Enum.CameraType.Custom then
            cam.CameraType = Enum.CameraType.Custom
            local char = Player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then cam.CameraSubject = hum end
        end
    end)
end

local function autoDismissModals()
    pcall(function()
        local pg = Player:FindFirstChild("PlayerGui")
        if not pg then return end
        for _, btn in pairs(pg:GetDescendants()) do
            if btn:IsA("TextButton") and btn.Visible then
                local bText = string.lower(btn.Text)
                if bText == "ok" or bText == "ok!" or bText == "continue" then
                    local isSafe = true
                    local curr = btn.Parent
                    local depth = 0
                    while curr and depth < 5 do
                        local n = string.lower(curr.Name)
                        if string.find(n, "robux") or string.find(n, "shop") or string.find(n, "pass") or string.find(n, "product") or string.find(n, "exclusive") then
                            isSafe = false
                            break
                        end
                        curr = curr.Parent
                        depth = depth + 1
                    end
                    if isSafe then
                        if firesignal then
                            firesignal(btn.Activated)
                            firesignal(btn.MouseButton1Click)
                        elseif btn.MouseButton1Click then
                            btn.MouseButton1Click:Fire()
                        end
                    end
                end
            end
        end
    end)
end

--========================================================================
-- 6. QUÉT VÀ NHẬN DIỆN TRỨNG GẦN NHẤT
--========================================================================
local function getNearestEgg()
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil, nil, 9999, false end

    local Things = workspace:FindFirstChild("__THINGS")
    local bestEgg, bestEggId, bestDist, isCustom = nil, nil, 60, false

    local function checkEgg(egg, customFlag)
        if not egg then return end
        local part = egg:IsA("BasePart") and egg or egg:FindFirstChildWhichIsA("BasePart", true)
        if not part and egg:IsA("Model") then
            pcall(function()
                local piv = egg:GetPivot()
                if piv then
                    local d = (piv.Position - hrp.Position).Magnitude
                    if d < bestDist then
                        bestDist = d
                        bestEgg = egg
                        local attrId = egg:GetAttribute("DM_EggId") or egg:GetAttribute("EggId")
                        bestEggId = (attrId and tostring(attrId)) or egg.Name
                        isCustom = customFlag
                    end
                end
            end)
            return
        end
        if part then
            local d = (part.Position - hrp.Position).Magnitude
            if d < bestDist then
                bestDist = d
                bestEgg = egg
                local attrId = egg:GetAttribute("DM_EggId") or egg:GetAttribute("EggId")
                bestEggId = (attrId and tostring(attrId)) or egg.Name
                isCustom = customFlag
            end
        end
    end

    if Things then
        local EggsFolder = Things:FindFirstChild("Eggs")
        if EggsFolder then
            for _, egg in pairs(EggsFolder:GetChildren()) do checkEgg(egg, false) end
        end
        local CustomEggsFolder = Things:FindFirstChild("CustomEggs")
        if CustomEggsFolder then
            for _, egg in pairs(CustomEggsFolder:GetChildren()) do checkEgg(egg, true) end
        end
    end

    if not bestEgg then
        for _, obj in pairs(workspace:GetChildren()) do
            if obj.Name == "Eggs" or obj.Name == "CustomEggs" then
                for _, egg in pairs(obj:GetChildren()) do checkEgg(egg, false) end
            end
        end
    end

    return bestEgg, bestEggId, bestDist, isCustom
end

--========================================================================
-- 7. HÀM THỰC THI MỞ TRỨNG
--========================================================================
local function hatchEgg(eggObj, eggId, amount, isCustom)
    local amt = tonumber(amount) or 1
    local id = tostring(eggId)
    local success = false

    if Network and typeof(Network.Invoke) == "function" then
        if isCustom then
            pcall(function()
                local res = Network.Invoke("CustomEggs_Hatch", eggObj and eggObj.Name or id, amt)
                if res ~= nil then success = true end
            end)
            if not success and id then
                pcall(function()
                    local res = Network.Invoke("CustomEggs_Hatch", id, amt)
                    if res ~= nil then success = true end
                end)
            end
            if not success and id then
                pcall(function()
                    local res = Network.Invoke("Eggs_RequestPurchase", id, amt)
                    if res ~= nil then success = true end
                end)
            end
        else
            pcall(function()
                local res = Network.Invoke("Eggs_RequestPurchase", id, amt)
                if res ~= nil then success = true end
            end)
            if not success and eggObj and eggObj.Name then
                pcall(function()
                    local res = Network.Invoke("Eggs_RequestPurchase", eggObj.Name, amt)
                    if res ~= nil then success = true end
                end)
            end
            if not success then
                pcall(function()
                    local res = Network.Invoke("CustomEggs_Hatch", id, amt)
                    if res ~= nil then success = true end
                end)
            end
        end
    end

    if not success then
        local netFolder = RS:FindFirstChild("Network")
        if netFolder then
            local rfEggs = netFolder:FindFirstChild("Eggs_RequestPurchase")
            local rfCustom = netFolder:FindFirstChild("CustomEggs_Hatch")

            if isCustom and rfCustom then
                pcall(function() rfCustom:InvokeServer(eggObj and eggObj.Name or id, amt) success = true end)
            elseif rfEggs then
                pcall(function() rfEggs:InvokeServer(id, amt) success = true end)
            end
            if not success and rfCustom then
                pcall(function() rfCustom:InvokeServer(id, amt) success = true end)
            end
            if not success and rfEggs then
                pcall(function() rfEggs:InvokeServer(id, amt) success = true end)
            end
        end
    end

    if not success and EggCmds and typeof(EggCmds) == "table" then
        pcall(function()
            if EggCmds.Hatch then EggCmds.Hatch(id, amt) success = true
            elseif EggCmds.Purchase then EggCmds.Purchase(id, amt) success = true end
        end)
    end

    if not success and eggObj then
        pcall(function()
            for _, prompt in pairs(eggObj:GetDescendants()) do
                if prompt:IsA("ProximityPrompt") and prompt.Enabled and fireproximityprompt then
                    fireproximityprompt(prompt)
                    success = true
                    break
                end
            end
        end)
    end

    return success
end

--========================================================================
-- 8. TẠO GIAO DIỆN ĐIỀU KHIỂN (UI)
--========================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PS99_PSXClassic_FastHatch"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

pcall(function()
    if syn and syn.protect_gui then
        syn.protect_gui(ScreenGui)
    end
end)
ScreenGui.Parent = GuiParent

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 320, 0, 360)
MainFrame.Position = UDim2.new(0.5, -160, 0.25, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Thickness = 1.5
MainStroke.Color = Color3.fromRGB(50, 90, 180)
MainStroke.Parent = MainFrame

local function enableDragging(frame, dragHandle)
    local dragging = false
    local dragInput, dragStart, startPos
    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    dragHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 42)
Header.BackgroundColor3 = Color3.fromRGB(24, 30, 46)
Header.BorderSizePixel = 0
Header.Parent = MainFrame

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 12)
HeaderCorner.Parent = Header

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -70, 0, 22)
TitleLabel.Position = UDim2.new(0, 12, 0, 4)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "⚡ PS99 - PSX CLASSIC"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 13
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = Header

local SubTitle = Instance.new("TextLabel")
SubTitle.Size = UDim2.new(1, -70, 0, 14)
SubTitle.Position = UDim2.new(0, 12, 0, 24)
SubTitle.BackgroundTransparency = 1
SubTitle.Text = "UPDATE 99 | FAST AUTO HATCH & AFK"
SubTitle.TextColor3 = Color3.fromRGB(120, 160, 240)
SubTitle.Font = Enum.Font.GothamMedium
SubTitle.TextSize = 9
SubTitle.TextXAlignment = Enum.TextXAlignment.Left
SubTitle.Parent = Header

enableDragging(MainFrame, Header)

local btnMinimize = Instance.new("TextButton")
btnMinimize.Size = UDim2.new(0, 28, 0, 28)
btnMinimize.Position = UDim2.new(1, -34, 0, 7)
btnMinimize.BackgroundColor3 = Color3.fromRGB(36, 44, 68)
btnMinimize.Text = "−"
btnMinimize.TextColor3 = Color3.fromRGB(220, 220, 220)
btnMinimize.Font = Enum.Font.GothamBold
btnMinimize.TextSize = 14
btnMinimize.Parent = Header

local btnMinCorner = Instance.new("UICorner")
btnMinCorner.CornerRadius = UDim.new(0, 6)
btnMinCorner.Parent = btnMinimize

local FloatingBtn = Instance.new("TextButton")
FloatingBtn.Size = UDim2.new(0, 44, 0, 44)
FloatingBtn.Position = UDim2.new(0.02, 0, 0.45, 0)
FloatingBtn.BackgroundColor3 = Color3.fromRGB(30, 80, 200)
FloatingBtn.Text = "🥚"
FloatingBtn.TextSize = 22
FloatingBtn.Visible = false
FloatingBtn.Parent = ScreenGui

local FloatCorner = Instance.new("UICorner")
FloatCorner.CornerRadius = UDim.new(1, 0)
FloatCorner.Parent = FloatingBtn

enableDragging(FloatingBtn, FloatingBtn)

btnMinimize.Activated:Connect(function()
    MainFrame.Visible = false
    FloatingBtn.Visible = true
end)

FloatingBtn.Activated:Connect(function()
    MainFrame.Visible = true
    FloatingBtn.Visible = false
end)

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -20, 1, -52)
Content.Position = UDim2.new(0, 10, 0, 48)
Content.BackgroundTransparency = 1
Content.Parent = MainFrame

local ContentLayout = Instance.new("UIListLayout")
ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
ContentLayout.Padding = UDim.new(0, 7)
ContentLayout.Parent = Content

local InfoCard = Instance.new("Frame")
InfoCard.Size = UDim2.new(1, 0, 0, 68)
InfoCard.BackgroundColor3 = Color3.fromRGB(26, 32, 48)
InfoCard.LayoutOrder = 1
InfoCard.Parent = Content

local InfoCorner = Instance.new("UICorner")
InfoCorner.CornerRadius = UDim.new(0, 8)
InfoCorner.Parent = InfoCard

local lblEggTitle = Instance.new("TextLabel")
lblEggTitle.Size = UDim2.new(1, -16, 0, 16)
lblEggTitle.Position = UDim2.new(0, 8, 0, 6)
lblEggTitle.BackgroundTransparency = 1
lblEggTitle.Text = "🎯 Trứng Đang Đứng Cạnh:"
lblEggTitle.TextColor3 = Color3.fromRGB(160, 175, 205)
lblEggTitle.Font = Enum.Font.GothamMedium
lblEggTitle.TextSize = 10
lblEggTitle.TextXAlignment = Enum.TextXAlignment.Left
lblEggTitle.Parent = InfoCard

local lblCurrentEgg = Instance.new("TextLabel")
lblCurrentEgg.Size = UDim2.new(1, -16, 0, 20)
lblCurrentEgg.Position = UDim2.new(0, 8, 0, 22)
lblCurrentEgg.BackgroundTransparency = 1
lblCurrentEgg.Text = "Đang tìm kiếm..."
lblCurrentEgg.TextColor3 = Color3.fromRGB(255, 220, 80)
lblCurrentEgg.Font = Enum.Font.GothamBold
lblCurrentEgg.TextSize = 13
lblCurrentEgg.TextXAlignment = Enum.TextXAlignment.Left
lblCurrentEgg.Parent = InfoCard

local lblHatchedCount = Instance.new("TextLabel")
lblHatchedCount.Size = UDim2.new(1, -16, 0, 16)
lblHatchedCount.Position = UDim2.new(0, 8, 0, 46)
lblHatchedCount.BackgroundTransparency = 1
lblHatchedCount.Text = "📦 Đã mở: 0 quả  •  🛡️ Anti-AFK: ✅ BẬT"
lblHatchedCount.TextColor3 = Color3.fromRGB(120, 230, 140)
lblHatchedCount.Font = Enum.Font.Gotham
lblHatchedCount.TextSize = 10
lblHatchedCount.TextXAlignment = Enum.TextXAlignment.Left
lblHatchedCount.Parent = InfoCard

local btnToggleHatch = Instance.new("TextButton")
btnToggleHatch.Size = UDim2.new(1, 0, 0, 42)
btnToggleHatch.BackgroundColor3 = Color3.fromRGB(40, 170, 80)
btnToggleHatch.Text = "▶️ BẬT AUTO MỞ TRỨNG"
btnToggleHatch.TextColor3 = Color3.fromRGB(255, 255, 255)
btnToggleHatch.Font = Enum.Font.GothamBold
btnToggleHatch.TextSize = 13
btnToggleHatch.LayoutOrder = 2
btnToggleHatch.Parent = Content

local btnHatchCorner = Instance.new("UICorner")
btnHatchCorner.CornerRadius = UDim.new(0, 8)
btnHatchCorner.Parent = btnToggleHatch

btnToggleHatch.Activated:Connect(function()
    STATE.AutoHatch = not STATE.AutoHatch
    if STATE.AutoHatch then
        btnToggleHatch.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
        btnToggleHatch.Text = "🛑 DỪNG AUTO MỞ TRỨNG"
    else
        btnToggleHatch.BackgroundColor3 = Color3.fromRGB(40, 170, 80)
        btnToggleHatch.Text = "▶️ BẬT AUTO MỞ TRỨNG"
    end
end)

local function createToggleRow(order, title, initialVal, onToggle)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, 0, 0, 34)
    Row.BackgroundColor3 = Color3.fromRGB(24, 28, 42)
    Row.LayoutOrder = order
    Row.Parent = Content

    local RowCorner = Instance.new("UICorner")
    RowCorner.CornerRadius = UDim.new(0, 8)
    RowCorner.Parent = Row

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -65, 1, 0)
    Label.Position = UDim2.new(0, 10, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = title
    Label.TextColor3 = Color3.fromRGB(220, 220, 230)
    Label.Font = Enum.Font.GothamMedium
    Label.TextSize = 11
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Row

    local ToggleBtn = Instance.new("TextButton")
    ToggleBtn.Size = UDim2.new(0, 48, 0, 24)
    ToggleBtn.Position = UDim2.new(1, -54, 0.5, -12)
    ToggleBtn.BackgroundColor3 = initialVal and Color3.fromRGB(40, 160, 80) or Color3.fromRGB(60, 65, 80)
    ToggleBtn.Text = initialVal and "BẬT" or "TẮT"
    ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    ToggleBtn.Font = Enum.Font.GothamBold
    ToggleBtn.TextSize = 10
    ToggleBtn.Parent = Row

    local ToggleCorner = Instance.new("UICorner")
    ToggleCorner.CornerRadius = UDim.new(0, 6)
    ToggleCorner.Parent = ToggleBtn

    local isEnabled = initialVal
    ToggleBtn.Activated:Connect(function()
        isEnabled = not isEnabled
        ToggleBtn.BackgroundColor3 = isEnabled and Color3.fromRGB(40, 160, 80) or Color3.fromRGB(60, 65, 80)
        ToggleBtn.Text = isEnabled and "BẬT" or "TẮT"
        onToggle(isEnabled)
    end)
    return Row
end

createToggleRow(3, "🚀 Bỏ qua Hoạt Ảnh (Mở Siêu Tốc)", STATE.SkipAnimation, function(val)
    STATE.SkipAnimation = val
    if val then disableEggAnimations() end
end)

createToggleRow(4, "🔢 Tự Động Mở Max Trứng (Max Slots)", STATE.AutoMaxHatch, function(val)
    STATE.AutoMaxHatch = val
end)

local BlackScreenGui = nil
createToggleRow(5, "🔋 Chế Độ Màn Đen (Tiết Kiệm Pin / CPU)", STATE.LowCpuMode, function(val)
    STATE.LowCpuMode = val
    if val then
        if not BlackScreenGui then
            BlackScreenGui = Instance.new("ScreenGui")
            BlackScreenGui.Name = "PS99_LowCpu_BlackScreen"
            BlackScreenGui.DisplayOrder = 999999
            BlackScreenGui.ResetOnSpawn = false

            local bg = Instance.new("TextButton")
            bg.Size = UDim2.new(1, 0, 1, 0)
            bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            bg.BorderSizePixel = 0
            bg.Text = "🔋 MÀN ĐEN TIẾT KIỆM PIN ĐANG BẬT\n(Chạm 2 lần để tắt màn đen)"
            bg.TextColor3 = Color3.fromRGB(150, 150, 150)
            bg.Font = Enum.Font.GothamBold
            bg.TextSize = 14
            bg.Parent = BlackScreenGui

            bg.Activated:Connect(function()
                STATE.LowCpuMode = false
                if BlackScreenGui then BlackScreenGui:Destroy() BlackScreenGui = nil end
            end)

            BlackScreenGui.Parent = GuiParent
        end
    else
        if BlackScreenGui then BlackScreenGui:Destroy() BlackScreenGui = nil end
    end
end)

--========================================================================
-- 9. ANTI-AFK & AUTO-RECONNECT
--========================================================================
pcall(function()
    if typeof(getconnections) == "function" then
        for _, conn in pairs(getconnections(Player.Idled)) do
            if conn.Disable then conn:Disable() end
        end
    end
end)

Player.Idled:Connect(function()
    pcall(function()
        if VirtualUser then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(0, 0))
        end
    end)
end)

task.spawn(function()
    while true do
        task.wait(90)
        pcall(function()
            if VirtualUser then
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new(10, 10))
            end
        end)
    end
end)

pcall(function()
    GuiService.ErrorMessageChanged:Connect(function()
        local code = GuiService:GetErrorCode()
        if code and code.Value > 0 then
            task.wait(5)
            pcall(function() TeleportService:Teleport(game.PlaceId, Player) end)
        end
    end)
end)

task.spawn(function()
    while true do
        task.wait(5)
        pcall(function()
            local promptGui = CoreGui:FindFirstChild("RobloxPromptGui")
            if promptGui then
                local overlay = promptGui:FindFirstChild("promptOverlay")
                if overlay and overlay:FindFirstChild("ErrorPrompt") then
                    task.wait(3)
                    TeleportService:Teleport(game.PlaceId, Player)
                end
            end
        end)
    end
end)

--========================================================================
-- 10. VÒNG LẶP CHÍNH (QUÉT TRỨNG & MỞ LIÊN TỤC)
--========================================================================
task.spawn(function()
    while true do
        task.wait(0.5)
        pcall(function()
            local eggObj, eggId, dist, isCustom = getNearestEgg()
            if eggObj and dist <= 45 then
                STATE.CurrentEggObj = eggObj
                STATE.CurrentEggName = eggId or eggObj.Name
                STATE.IsCustomEgg = isCustom
                lblCurrentEgg.Text = string.format("🥚 %s (%.0fm)", tostring(STATE.CurrentEggName), dist)
                lblCurrentEgg.TextColor3 = Color3.fromRGB(80, 220, 140)
            else
                STATE.CurrentEggObj = nil
                STATE.CurrentEggName = nil
                lblCurrentEgg.Text = "❌ Đứng gần quả trứng để mở"
                lblCurrentEgg.TextColor3 = Color3.fromRGB(240, 140, 80)
            end
        end)
    end
end)

task.spawn(function()
    while true do
        task.wait(0.2)
        if STATE.SkipAnimation then
            disableEggAnimations()
            autoDismissModals()
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(STATE.HatchSpeed)
        if STATE.AutoHatch then
            pcall(function()
                if STATE.CurrentEggObj or STATE.CurrentEggName then
                    local eggObj = STATE.CurrentEggObj
                    local eggName = STATE.CurrentEggName
                    local isCustom = STATE.IsCustomEgg
                    local hatchAmt = STATE.AutoMaxHatch and getMaxHatch() or (tonumber(STATE.CustomHatchAmount) or 1)

                    local ok = hatchEgg(eggObj, eggName, hatchAmt, isCustom)
                    if ok then
                        STATE.TotalHatched = STATE.TotalHatched + hatchAmt
                        lblHatchedCount.Text = string.format("📦 Đã mở: %d quả  •  🛡️ Anti-AFK: ✅ BẬT", STATE.TotalHatched)
                    end
                end
            end)
        end
    end
end)

pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "⚡ PS99 PSX Classic Ready",
        Text = "Menu đã sẵn sàng! Đứng gần trứng và bấm BẬT.",
        Duration = 3
    })
end)
print("[PS99 Script] PSX Classic Fast Auto Hatch & Anti-AFK V1.1 loaded successfully!")
