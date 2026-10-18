--========================================================================
-- PS99 DIAMOND MOUNTAIN - SUMMIT AFK & YETI BOSS SUITE (DELTA EXECUTOR)
-- Tối ưu hóa 100% cho Delta Executor (Mobile & PC)
-- Tích hợp:
--   - Giao diện UI tùy biến mượt mà, hỗ trợ cảm ứng kéo thả & nút thu nhỏ
--   - Auto Teleport & Đánh Yeti Boss khi hồi sinh + Đếm số Yeti đã diệt
--   - Lựa chọn 6 Hang Mở Trứng / Phá Rương (Mountain Trails 1-6)
--   - Auto Hatch Egg + Skip Animation (Bỏ qua hoạt ảnh mở trứng)
--   - Tự động Tele về bãi Farm tiền khi không mở trứng hoặc sau khi Yeti chết
--   - Tự do lưu vị trí bãi Farm & tọa độ các hang
--   - Hút Orbs / Lootbags, Anti-AFK 20 phút, Auto-Reconnect
--   - Webhook Discord thông báo thời gian thực + Báo cáo 15 phút
--========================================================================

-- Khởi tạo biến toàn cục
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- Kiểm tra HTTP request
local req = request or http_request or (syn and syn.request) or (http and http.request)

-- Load game framework
local Library = RS:WaitForChild("Library", 10)
local Client = Library and Library:WaitForChild("Client", 10)
local Directory = Library and Library:WaitForChild("Directory", 10)

local Save = Client and require(Client:WaitForChild("Save", 10))
local PetDirectory = Directory and require(Directory:WaitForChild("Pets", 10))
local Network = Client and Client:FindFirstChild("Network") and require(Client.Network)
if not Network and RS:FindFirstChild("Network") then
    Network = RS.Network
end

--========================================================================
-- CẤU HÌNH TRẠNG THÁI (SETTINGS & STATE)
--========================================================================

local STATE = {
    -- [YETI BOSS]
    AutoYeti = true,             -- Tự động tele đánh Yeti khi hồi sinh
    AutoClickYeti = true,        -- Tự click / gửi pet đánh Yeti liên tục
    YetiKilledCount = 0,        -- Số lượng Yeti đã hạ gục
    YetiCooldownAlert = true,    -- Báo webhook khi diệt xong Yeti
    IsFightingYeti = false,      -- Cờ trạng thái đang đánh Yeti

    -- [HANG NÚI & TRỨNG]
    SelectedCave = 1,            -- Hang đang chọn (1 -> 6)
    AutoCaveChests = false,      -- Tự động phá rương trong hang
    AutoHatch = false,           -- Tự động mở trứng
    SkipAnimation = true,        -- Bỏ qua hiệu ứng mở trứng
    SelectedEggName = "Nearest", -- Tên trứng ("Nearest" = Trứng gần nhất)

    -- [BÃI FARM TIỀN]
    AutoFarmMoney = true,        -- Auto tele về farm tiền khi không mở trứng / Yeti chết
    AutoHitBreakables = true,    -- Tự động đập đá/rương ở bãi farm
    FarmCFrame = nil,            -- Tọa độ bãi farm (lưu tùy chỉnh)

    -- [TỌA ĐỘ 6 HANG NÚI]
    CaveCFrames = {
        [1] = nil,
        [2] = nil,
        [3] = nil,
        [4] = nil,
        [5] = nil,
        [6] = nil,
    },

    -- [HỆ THỐNG AFK & HÚT ĐỒ]
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

    -- [THỐNG KÊ PHIÊN]
    SessionStart = os.time(),
    StartingDiamonds = 0,
    TotalHuge = 0,
    TotalTitanic = 0,
    TotalGargantuan = 0,
    ObtainedPets = {},
    CurrentAction = "Đang khởi động..."
}

--========================================================================
-- HÀM TIỆN ÍCH
--========================================================================

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

local function getSave()
    local ok, data = pcall(function()
        return Save and Save.Get and Save.Get()
    end)
    return (ok and data) or nil
end

local function getDiamonds(data)
    data = data or getSave()
    if not data or not data.Inventory or not data.Inventory.Currency then return 0 end
    for _, curr in pairs(data.Inventory.Currency) do
        if curr.id == "Diamonds" then
            return tonumber(curr._am) or 0
        end
    end
    return 0
end

local function getHRP()
    local char = Player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function safeTeleport(cframe)
    if not cframe then return end
    local hrp = getHRP()
    if hrp then
        hrp.CFrame = cframe + Vector3.new(0, 3, 0)
    end
end

-- Lấy số liệu ban đầu
STATE.StartingDiamonds = getDiamonds()

-- Lưu vị trí ban đầu làm bãi farm mặc định nếu chưa set
task.spawn(function()
    task.wait(2)
    local hrp = getHRP()
    if hrp and not STATE.FarmCFrame then
        STATE.FarmCFrame = hrp.CFrame
    end
end)

--========================================================================
-- GỬI WEBHOOK DISCORD
--========================================================================

local function sendWebhook(title, description, color, mention, fields)
    if not req or not STATE.Webhook or STATE.Webhook == "" then return end

    local embed = {
        description = description,
        color = color or 5793266,
        footer = {
            text = "PS99 Summit Suite | " .. Player.Name,
            icon_url = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. Player.UserId .. "&width=150&height=150&format=png"
        },
        timestamp = DateTime.now():ToIsoDate()
    }
    if title and title ~= "" then embed.title = title end
    if fields and #fields > 0 then embed.fields = fields end

    local payload = {
        username = "Diamond Mountain Boss & Farm",
        embeds = { embed }
    }
    if mention and mention ~= "" then payload.content = mention end

    pcall(function()
        req({
            Url = STATE.Webhook,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(payload)
        })
    end)
end

--========================================================================
-- LOGIC 1: PHÁT HIỆN & ĐÁNH YETI BOSS
--========================================================================

local function findYeti()
    local Things = workspace:FindFirstChild("__THINGS")
    if Things then
        local Breakables = Things:FindFirstChild("Breakables")
        if Breakables then
            for _, b in pairs(Breakables:GetChildren()) do
                local lower = string.lower(b.Name)
                if string.find(lower, "yeti") or string.find(lower, "abominable") then
                    local part = b:IsA("BasePart") and b or (b:IsA("Model") and (b.PrimaryPart or b:FindFirstChildWhichIsA("BasePart")))
                    if part then return b, part.CFrame end
                end
            end
        end
    end

    -- Tìm trong Workspace
    for _, obj in pairs(workspace:GetChildren()) do
        if obj:IsA("Model") then
            local lower = string.lower(obj.Name)
            if string.find(lower, "yeti") or string.find(lower, "abominable") then
                local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                if part then return obj, part.CFrame end
            end
        end
    end

    return nil, nil
end

local function attackTarget(target)
    if not target then return end
    pcall(function()
        if Network and Network.Fire then
            Network.Fire("Breakables_PlayerAttackBreakable", target.Name, "1")
        end
        if VirtualUser then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton1(Vector2.new())
        end
    end)
end

-- Vòng lặp quản lý Yeti & Điều phối Teleport
task.spawn(function()
    while true do
        task.wait(0.5)

        if STATE.AutoYeti then
            local yetiInstance, yetiCFrame = findYeti()

            if yetiInstance and yetiCFrame then
                -- Yeti đang sống!
                if not STATE.IsFightingYeti then
                    STATE.IsFightingYeti = true
                    STATE.CurrentAction = "⚔️ Đang tấn công Yeti Boss!"
                    safeTeleport(yetiCFrame + Vector3.new(0, 2, 5))
                end

                -- Tấn công Yeti
                if STATE.AutoClickYeti then
                    attackTarget(yetiInstance)
                end
            else
                -- Yeti không có mặt hoặc vừa chết
                if STATE.IsFightingYeti then
                    -- Yeti vừa bị tiêu diệt xong!
                    STATE.IsFightingYeti = false
                    STATE.YetiKilledCount = STATE.YetiKilledCount + 1
                    STATE.CurrentAction = "🏆 Yeti đã bị hạ gục! Đang chuyển khu vực..."

                    if STATE.YetiCooldownAlert then
                        sendWebhook(
                            "💥 ĐÃ HẠ GỤC YETI BOSS!",
                            "Tài khoản **" .. Player.Name .. "** đã đánh bại Yeti thành công!\n**Tổng số Yeti đã diệt:** `" .. STATE.YetiKilledCount .. " con`",
                            16766720
                        )
                    end

                    task.wait(1.5)

                    -- KIỂM TRA ĐIỀU KIỆN TELEPORT SAU KHI YETI CHẾT
                    if STATE.AutoHatch then
                        -- Nếu bật mở trứng: tele về hang đã chọn
                        local cavePos = STATE.CaveCFrames[STATE.SelectedCave]
                        if cavePos then
                            safeTeleport(cavePos)
                            STATE.CurrentAction = "🥚 Đang mở trứng tại Hang " .. STATE.SelectedCave
                        end
                    elseif STATE.AutoFarmMoney then
                        -- Nếu KHÔNG mở trứng: tele thẳng về bãi farm tiền
                        if STATE.FarmCFrame then
                            safeTeleport(STATE.FarmCFrame)
                            STATE.CurrentAction = "💰 Đang cày tiền tại Bãi Farm"
                        end
                    end
                else
                    -- Bình thường khi không có Yeti:
                    if STATE.AutoHatch then
                        STATE.CurrentAction = "🥚 Đang mở trứng tại Hang " .. STATE.SelectedCave
                    elseif STATE.AutoFarmMoney then
                        STATE.CurrentAction = "💰 Đang cày tiền tại Bãi Farm"
                    else
                        STATE.CurrentAction = "💤 Đang chờ lệnh..."
                    end
                end
            end
        end
    end
end)

--========================================================================
-- LOGIC 2: HANG MỞ TRỨNG & PHÁ RƯƠNG (TRAILS 1-6)
--========================================================================

local function getNearestEgg()
    local Things = workspace:FindFirstChild("__THINGS")
    local EggsFolder = Things and Things:FindFirstChild("Eggs")
    local hrp = getHRP()
    if not hrp or not EggsFolder then return nil end

    local nearest, minDist = nil, 60
    for _, egg in pairs(EggsFolder:GetChildren()) do
        local part = egg:IsA("BasePart") and egg or (egg:IsA("Model") and (egg.PrimaryPart or egg:FindFirstChildWhichIsA("BasePart")))
        if part then
            local dist = (part.Position - hrp.Position).Magnitude
            if dist < minDist then
                minDist = dist
                nearest = egg
            end
        end
    end
    return nearest
end

-- Hook bỏ qua animation mở trứng (Skip Animation)
local function applySkipAnimation(enabled)
    pcall(function()
        local EggsFrontend = Player.PlayerScripts.Scripts.Game:FindFirstChild("Egg Opening Frontend")
        if EggsFrontend and getsenv then
            getsenv(EggsFrontend).PlayEggAnimation = function() return end
        end
    end)
    pcall(function()
        local eggGui = PlayerGui:FindFirstChild("EggOpening")
        if eggGui then
            eggGui.Enabled = not enabled
        end
    end)
end

-- Vòng lặp Auto Hatch Egg
task.spawn(function()
    while true do
        task.wait(0.3)

        -- Chỉ mở trứng khi được bật VÀ hiện tại không đang bận đánh Yeti
        if STATE.AutoHatch and not STATE.IsFightingYeti then
            if STATE.SkipAnimation then
                applySkipAnimation(true)
            end

            pcall(function()
                local eggName = STATE.SelectedEggName
                if eggName == "Nearest" or eggName == "" then
                    local nearest = getNearestEgg()
                    if nearest then
                        eggName = nearest.Name
                    end
                end

                if eggName and eggName ~= "Nearest" and Network and Network.Invoke then
                    Network.Invoke("Eggs_RequestPurchase", eggName, 1)
                end
            end)
        end
    end
end)

-- Vòng lặp Auto Phá Rương trong Hang
task.spawn(function()
    while true do
        task.wait(0.5)

        if STATE.AutoCaveChests and not STATE.IsFightingYeti then
            pcall(function()
                local hrp = getHRP()
                local Things = workspace:FindFirstChild("__THINGS")
                local Breakables = Things and Things:FindFirstChild("Breakables")

                if hrp and Breakables then
                    local nearestChest, minDist = nil, 90
                    for _, b in pairs(Breakables:GetChildren()) do
                        local lower = string.lower(b.Name)
                        if string.find(lower, "chest") or string.find(lower, "crate") then
                            local part = b:IsA("BasePart") and b or (b:IsA("Model") and (b.PrimaryPart or b:FindFirstChildWhichIsA("BasePart")))
                            if part then
                                local dist = (part.Position - hrp.Position).Magnitude
                                if dist < minDist then
                                    minDist = dist
                                    nearestChest = b
                                end
                            end
                        end
                    end

                    if nearestChest and Network and Network.Fire then
                        Network.Fire("Breakables_PlayerAttackBreakable", nearestChest.Name, "1")
                    end
                end
            end)
        end
    end
end)

--========================================================================
-- LOGIC 3: BÃI FARM TIỀN & ĐẬP BREAKABLES
--========================================================================

task.spawn(function()
    while true do
        task.wait(0.5)

        -- Chỉ đập đá ở bãi farm khi:
        -- 1. Bật AutoFarmMoney
        -- 2. Không đang mở trứng (hoặc AutoHatch tắt)
        -- 3. Không đang đánh Yeti
        if STATE.AutoFarmMoney and not STATE.AutoHatch and not STATE.IsFightingYeti then
            pcall(function()
                local hrp = getHRP()
                local Things = workspace:FindFirstChild("__THINGS")
                local Breakables = Things and Things:FindFirstChild("Breakables")

                if hrp and Breakables and STATE.AutoHitBreakables then
                    local nearest, minDist = nil, 100
                    for _, b in pairs(Breakables:GetChildren()) do
                        local part = b:IsA("BasePart") and b or (b:IsA("Model") and (b.PrimaryPart or b:FindFirstChildWhichIsA("BasePart")))
                        if part then
                            local dist = (part.Position - hrp.Position).Magnitude
                            if dist < minDist then
                                minDist = dist
                                nearest = b
                            end
                        end
                    end

                    if nearest and Network and Network.Fire then
                        Network.Fire("Breakables_PlayerAttackBreakable", nearest.Name, "1")
                    end
                end
            end)
        end
    end
end)

--========================================================================
-- LOGIC 4: TIỆN ÍCH AFK (HÚT ĐỒ, ANTI-AFK, RECONNECT, EXPEDITIONS)
--========================================================================

-- Hút Orbs & Lootbags
task.spawn(function()
    local Things = workspace:WaitForChild("__THINGS", 15)
    local Orbs = Things and Things:WaitForChild("Orbs", 10)
    local Lootbags = Things and Things:WaitForChild("Lootbags", 10)

    while true do
        task.wait(0.4)
        if STATE.AutoCollectDrops then
            pcall(function()
                local hrp = getHRP()
                if not hrp then return end

                if Orbs then
                    for _, orb in pairs(Orbs:GetChildren()) do
                        if orb:IsA("BasePart") then orb.CFrame = hrp.CFrame end
                    end
                end

                if Lootbags then
                    for _, bag in pairs(Lootbags:GetChildren()) do
                        if bag:IsA("Model") then
                            local part = bag.PrimaryPart or bag:FindFirstChildWhichIsA("BasePart")
                            if part then part.CFrame = hrp.CFrame end
                        elseif bag:IsA("BasePart") then
                            bag.CFrame = hrp.CFrame
                        end
                    end
                end
            end)
        end
    end
end)

-- Chống kick 20 phút (Anti-AFK)
Player.Idled:Connect(function()
    if STATE.AntiAFK then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
end)

-- Auto Reconnect
pcall(function()
    GuiService.ErrorMessageChanged:Connect(function()
        if STATE.AutoReconnect and GuiService:GetErrorCode().Value > 0 then
            sendWebhook("⚠️ MẤT KẾT NỐI", "Đang thử Reconnect vào server sau 10 giây...", 15158332)
            task.wait(10)
            TeleportService:Teleport(game.PlaceId, Player)
        end
    end)
end)

-- Auto Claim Expeditions
task.spawn(function()
    while true do
        task.wait(60)
        if STATE.AutoClaimExpeditions and Network and Network.Invoke then
            pcall(function()
                Network.Invoke("Expeditions: Claim All")
                Network.Invoke("Expedition: Claim All")
            end)
        end
    end
end)

-- Low CPU Mode
local function applyLowCpu(enabled)
    pcall(function()
        RunService:Set3dRenderingEnabled(not enabled)
    end)
    if setfpscap then
        pcall(function()
            setfpscap(enabled and 15 or 60)
        end)
    end
end

--========================================================================
-- LOGIC 5: THEO DÕI PET QUÝ VÀ BÁO CÁO 15 PHÚT
--========================================================================

local function getPetType(petId)
    local info = PetDirectory and PetDirectory[petId]
    if info then
        if info.gargantuan then return "Gargantuan" end
        if info.titanic then return "Titanic" end
        if info.huge then return "Huge" end
    end
    local lower = string.lower(tostring(petId))
    if string.find(lower, "gargantuan") then return "Gargantuan" end
    if string.find(lower, "titanic") then return "Titanic" end
    if string.find(lower, "huge") then return "Huge" end
    return nil
end

local function recordPet(pet, amount)
    local pType = getPetType(pet.id)
    if not pType then return end

    amount = tonumber(amount) or 1
    if pType == "Huge" then STATE.TotalHuge = STATE.TotalHuge + amount
    elseif pType == "Titanic" then STATE.TotalTitanic = STATE.TotalTitanic + amount
    elseif pType == "Gargantuan" then STATE.TotalGargantuan = STATE.TotalGargantuan + amount end

    local name = tostring(pet.id)
    STATE.ObtainedPets[name] = (STATE.ObtainedPets[name] or 0) + amount

    local icon = pType == "Titanic" and "🔴" or (pType == "Gargantuan" and "🟡" or "🟣")
    local color = pType == "Titanic" and 15158332 or (pType == "Gargantuan" and 16766720 or 10181046)

    local mention = ""
    if (pType == "Huge" and STATE.MentionOnHuge) or ((pType == "Titanic" or pType == "Gargantuan") and STATE.MentionOnTitanic) then
        if STATE.DiscordUserId ~= "" then mention = "<@" .. STATE.DiscordUserId .. ">" end
    end

    sendWebhook(
        icon .. " TRÚNG " .. string.upper(pType) .. " MỚI!",
        "Tài khoản **" .. Player.Name .. "** vừa nhận được: **" .. name .. "** `+" .. amount .. "`!\n" ..
        "**Tổng Session:** 🟣 Huge: `" .. STATE.TotalHuge .. "` | 🔴 Titanic: `" .. STATE.TotalTitanic .. "` | 🟡 Gargantuan: `" .. STATE.TotalGargantuan .. "`\n" ..
        "**Số Yeti đã hạ gục:** `" .. STATE.YetiKilledCount .. "`",
        color,
        mention
    )
end

-- Vòng lặp quét pet
task.spawn(function()
    local lastSnapshot = {}
    local init = getSave()
    if init and init.Inventory and init.Inventory.Pet then
        for u, p in pairs(init.Inventory.Pet) do
            lastSnapshot[u] = tonumber(p._am) or 1
        end
    end

    while true do
        task.wait(2)
        local d = getSave()
        if d and d.Inventory and d.Inventory.Pet then
            local current = {}
            for u, p in pairs(d.Inventory.Pet) do
                local amt = tonumber(p._am) or 1
                current[u] = amt
                local old = lastSnapshot[u]
                if not old then
                    recordPet(p, amt)
                elseif amt > old then
                    recordPet(p, amt - old)
                end
            end
            lastSnapshot = current
        end
    end
end)

-- Báo cáo 15 phút
task.spawn(function()
    while true do
        task.wait(STATE.ReportInterval)

        local d = getSave()
        local currentDiamonds = getDiamonds(d)
        local diff = currentDiamonds - STATE.StartingDiamonds
        local elapsed = math.max(1, os.time() - STATE.SessionStart)
        local rate = math.floor((diff / elapsed) * 3600)

        local fields = {
            {
                name = "💎 Kim Cương",
                value = "Hiện tại: `" .. formatNumber(currentDiamonds) .. "`\nĐã cày: `" .. (diff >= 0 and "+" or "") .. formatNumber(diff) .. "`\nTốc độ: `" .. formatNumber(rate) .. "/h`",
                inline = true
            },
            {
                name = "👹 Yeti Boss",
                value = "Đã hạ gục: **" .. STATE.YetiKilledCount .. " con**",
                inline = true
            },
            {
                name = "🐾 Tổng Pet Quý",
                value = "🟣 Huge: **" .. STATE.TotalHuge .. "**\n🔴 Titanic: **" .. STATE.TotalTitanic .. "**\n🟡 Gargantuan: **" .. STATE.TotalGargantuan .. "**",
                inline = false
            },
            {
                name = "⏱️ Phiên Treo",
                value = "Thời gian: `" .. formatDuration(elapsed) .. "`\nTrạng thái: `" .. STATE.CurrentAction .. "`",
                inline = false
            }
        }

        sendWebhook("📊 BÁO CÁO 15 PHÚT - SUMMIT AFK", "Báo cáo tiến trình leo đỉnh núi & săn Yeti.", 3447003, nil, fields)
    end
end)

--========================================================================
-- GIAO DIỆN NGƯỜI DÙNG (CUSTOM DELTA SCREEN-GUI)
-- Tối ưu cho cảm ứng Mobile & Chuột PC, có nút tròn thu nhỏ
--========================================================================

-- Xóa UI cũ nếu có
pcall(function()
    local old = CoreGui:FindFirstChild("PS99_Summit_Suite") or PlayerGui:FindFirstChild("PS99_Summit_Suite")
    if old then old:Destroy() end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PS99_Summit_Suite"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Chọn parent CoreGui hoặc PlayerGui
pcall(function()
    ScreenGui.Parent = CoreGui
end)
if not ScreenGui.Parent then
    ScreenGui.Parent = PlayerGui
end

-- 1. NÚT TRÒN THU NHỎ / MỞ RỘNG (FLOATING MOBILE BUTTON)
local ToggleButton = Instance.new("TextButton")
ToggleButton.Name = "ToggleButton"
ToggleButton.Size = UDim2.new(0, 52, 0, 52)
ToggleButton.Position = UDim2.new(0, 15, 0.4, 0)
ToggleButton.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
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

-- Cho phép kéo thả nút tròn trên điện thoại
local isDraggingBtn = false
local dragStartBtn, startPosBtn
ToggleButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDraggingBtn = true
        dragStartBtn = input.Position
        startPosBtn = ToggleButton.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                isDraggingBtn = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if isDraggingBtn and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStartBtn
        ToggleButton.Position = UDim2.new(startPosBtn.X.Scale, startPosBtn.X.Offset + delta.X, startPosBtn.Y.Scale, startPosBtn.Y.Offset + delta.Y)
    end
end)

-- 2. KHUNG CHÍNH (MAIN FRAME)
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 540, 0, 360)
MainFrame.Position = UDim2.new(0.5, -270, 0.5, -180)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(45, 50, 65)
MainStroke.Thickness = 1.5
MainStroke.Parent = MainFrame

-- Kéo thả khung chính
local isDraggingMain = false
local dragStartMain, startPosMain
MainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if input.Position.Y - MainFrame.AbsolutePosition.Y < 45 then
            isDraggingMain = true
            dragStartMain = input.Position
            startPosMain = MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    isDraggingMain = false
                end
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

-- Sự kiện click nút tròn để mở/đóng khung chính
ToggleButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

-- THANH TIÊU ĐỀ (TOP BAR)
local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 42)
TopBar.BackgroundColor3 = Color3.fromRGB(24, 27, 36)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame

local TopBarCorner = Instance.new("UICorner")
TopBarCorner.CornerRadius = UDim.new(0, 12)
TopBarCorner.Parent = TopBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -60, 1, 0)
TitleLabel.Position = UDim2.new(0, 14, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "💎 PS99 SUMMIT SUITE | YETI & FARM"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 14
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TopBar

local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.new(0, 30, 0, 30)
CloseButton.Position = UDim2.new(1, -36, 0.5, -15)
CloseButton.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
CloseButton.Text = "✕"
CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseButton.Font = Enum.Font.GothamBold
CloseButton.TextSize = 14
CloseButton.Parent = TopBar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 8)
CloseCorner.Parent = CloseButton

CloseButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
end)

-- THANH BÊN (SIDEBAR TABS)
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 135, 1, -42)
Sidebar.Position = UDim2.new(0, 0, 0, 42)
Sidebar.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame

local SidebarLayout = Instance.new("UIListLayout")
SidebarLayout.Padding = UDim.new(0, 4)
SidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
SidebarLayout.Parent = Sidebar

local SidebarPad = Instance.new("UIPadding")
SidebarPad.PaddingTop = UDim.new(0, 8)
SidebarPad.Parent = Sidebar

-- VÙNG NỘI DUNG (CONTENT CONTAINER)
local ContentContainer = Instance.new("Frame")
ContentContainer.Size = UDim2.new(1, -145, 1, -52)
ContentContainer.Position = UDim2.new(0, 140, 0, 47)
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
    Page.CanvasSize = UDim2.new(0, 0, 0, 380)
    Page.Parent = ContentContainer

    local Layout = Instance.new("UIListLayout")
    Layout.Padding = UDim.new(0, 8)
    Layout.Parent = Page

    local Pad = Instance.new("UIPadding")
    Pad.PaddingRight = UDim.new(0, 6)
    Pad.Parent = Page

    Pages[name] = Page
    return Page
end

-- CÁC TRANG NỘI DUNG
local DashboardPage = createPage("Dashboard")
local YetiPage = createPage("Yeti")
local TrailsPage = createPage("Trails")
local FarmPage = createPage("Farm")
local SettingsPage = createPage("Settings")

-- HÀM TẠO NÚT TAB TRÊN THANH BÊN
local TabButtons = {}
local function addTabButton(text, pageName)
    local TabBtn = Instance.new("TextButton")
    TabBtn.Size = UDim2.new(1, -12, 0, 36)
    TabBtn.BackgroundColor3 = Color3.fromRGB(28, 31, 42)
    TabBtn.Text = text
    TabBtn.TextColor3 = Color3.fromRGB(180, 190, 210)
    TabBtn.Font = Enum.Font.GothamMedium
    TabBtn.TextSize = 12
    TabBtn.Parent = Sidebar

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 8)
    Corner.Parent = TabBtn

    TabBtn.MouseButton1Click:Connect(function()
        for pName, pFrame in pairs(Pages) do
            pFrame.Visible = (pName == pageName)
        end
        for _, btn in pairs(TabButtons) do
            btn.BackgroundColor3 = Color3.fromRGB(28, 31, 42)
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

-- Mặc định chọn Dashboard
btnDash.BackgroundColor3 = Color3.fromRGB(50, 110, 220)
btnDash.TextColor3 = Color3.fromRGB(255, 255, 255)
DashboardPage.Visible = true

-- HÀM TIỆN ÍCH TẠO WIDGET UI
local function createToggle(parent, title, defaultVal, callback)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(1, 0, 0, 40)
    Frame.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
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
    Label.TextSize = 12
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Frame

    local ToggleBtn = Instance.new("TextButton")
    ToggleBtn.Size = UDim2.new(0, 44, 0, 24)
    ToggleBtn.Position = UDim2.new(1, -52, 0.5, -12)
    ToggleBtn.BackgroundColor3 = defaultVal and Color3.fromRGB(40, 180, 90) or Color3.fromRGB(70, 75, 90)
    ToggleBtn.Text = defaultVal and "BẬT" or "TẮT"
    ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    ToggleBtn.Font = Enum.Font.GothamBold
    ToggleBtn.TextSize = 11
    ToggleBtn.Parent = Frame

    local BtnCorner = Instance.new("UICorner")
    BtnCorner.CornerRadius = UDim.new(0, 6)
    BtnCorner.Parent = ToggleBtn

    local isToggled = defaultVal
    ToggleBtn.MouseButton1Click:Connect(function()
        isToggled = not isToggled
        ToggleBtn.BackgroundColor3 = isToggled and Color3.fromRGB(40, 180, 90) or Color3.fromRGB(70, 75, 90)
        ToggleBtn.Text = isToggled and "BẬT" or "TẮT"
        callback(isToggled)
    end)

    return Frame
end

local function createActionButton(parent, text, color, callback)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, 36)
    Btn.BackgroundColor3 = color or Color3.fromRGB(50, 110, 220)
    Btn.Text = text
    Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    Btn.Font = Enum.Font.GothamBold
    Btn.TextSize = 12
    Btn.Parent = parent

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 8)
    Corner.Parent = Btn

    Btn.MouseButton1Click:Connect(callback)
    return Btn
end

local function createInfoCard(parent, title, defaultText)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(1, 0, 0, 42)
    Frame.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
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
    Value.Size = UDim2.new(0.5, -15, 1, 0)
    Value.Position = UDim2.new(0.5, 0, 0, 0)
    Value.BackgroundTransparency = 1
    Value.Text = defaultText
    Value.TextColor3 = Color3.fromRGB(255, 255, 255)
    Value.Font = Enum.Font.GothamBold
    Value.TextSize = 12
    Value.TextXAlignment = Enum.TextXAlignment.Right
    Value.Parent = Frame

    return Value
end

--========================================================================
-- TRANG 1: DASHBOARD (TỔNG QUAN)
--========================================================================

local lblAction = createInfoCard(DashboardPage, "⚡ Hoạt Động:", STATE.CurrentAction)
local lblYetiCount = createInfoCard(DashboardPage, "👹 Số Yeti Đã Diệt:", "0 con")
local lblDiamonds = createInfoCard(DashboardPage, "💎 Kim Cương:", formatNumber(STATE.StartingDiamonds))
local lblDiffDiamonds = createInfoCard(DashboardPage, "📈 Cày Được:", "+0 (+0/h)")
local lblUptime = createInfoCard(DashboardPage, "⏱️ Thời Gian Treo:", "00h 00m 00s")
local lblPets = createInfoCard(DashboardPage, "🐾 Huge / Titanic:", "0 / 0")

-- Vòng lặp cập nhật Dashboard
task.spawn(function()
    while true do
        task.wait(1)
        if DashboardPage.Visible then
            lblAction.Text = STATE.CurrentAction
            lblYetiCount.Text = STATE.YetiKilledCount .. " con"

            local curDiamonds = getDiamonds()
            local diff = curDiamonds - STATE.StartingDiamonds
            local elapsed = math.max(1, os.time() - STATE.SessionStart)
            local rate = math.floor((diff / elapsed) * 3600)

            lblDiamonds.Text = formatNumber(curDiamonds)
            lblDiffDiamonds.Text = (diff >= 0 and "+" or "") .. formatNumber(diff) .. " (" .. formatNumber(rate) .. "/h)"
            lblUptime.Text = formatDuration(elapsed)
            lblPets.Text = "🟣 " .. STATE.TotalHuge .. " | 🔴 " .. STATE.TotalTitanic
        end
    end
end)

--========================================================================
-- TRANG 2: YETI BOSS
--========================================================================

createToggle(YetiPage, "👹 Auto Tele & Đánh Yeti Khi Hồi Sinh", STATE.AutoYeti, function(v)
    STATE.AutoYeti = v
end)

createToggle(YetiPage, "⚔️ Auto Click / Tấn Công Dồn Dập Vào Yeti", STATE.AutoClickYeti, function(v)
    STATE.AutoClickYeti = v
end)

createToggle(YetiPage, "🔔 Báo Webhook Khi Hạ Gục Yeti", STATE.YetiCooldownAlert, function(v)
    STATE.YetiCooldownAlert = v
end)

createActionButton(YetiPage, "🔄 Đặt Lại Bộ Đếm Yeti (Reset Count)", Color3.fromRGB(180, 80, 50), function()
    STATE.YetiKilledCount = 0
    lblYetiCount.Text = "0 con"
end)

--========================================================================
-- TRANG 3: HANG NÚI & MỞ TRỨNG (TRAILS 1-6)
--========================================================================

-- Khung chọn Hang 1 -> Hang 6
local CaveSelectorFrame = Instance.new("Frame")
CaveSelectorFrame.Size = UDim2.new(1, 0, 0, 45)
CaveSelectorFrame.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
CaveSelectorFrame.Parent = TrailsPage

local CaveCorner = Instance.new("UICorner")
CaveCorner.CornerRadius = UDim.new(0, 8)
CaveCorner.Parent = CaveSelectorFrame

local CaveLabel = Instance.new("TextLabel")
CaveLabel.Size = UDim2.new(0, 80, 1, 0)
CaveLabel.Position = UDim2.new(0, 10, 0, 0)
CaveLabel.BackgroundTransparency = 1
CaveLabel.Text = "Chọn Hang:"
CaveLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
CaveLabel.Font = Enum.Font.GothamMedium
CaveLabel.TextSize = 12
CaveLabel.TextXAlignment = Enum.TextXAlignment.Left
CaveLabel.Parent = CaveSelectorFrame

local caveButtons = {}
for i = 1, 6 do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 38, 0, 28)
    btn.Position = UDim2.new(0, 85 + (i - 1) * 44, 0.5, -14)
    btn.BackgroundColor3 = (STATE.SelectedCave == i) and Color3.fromRGB(50, 110, 220) or Color3.fromRGB(35, 40, 55)
    btn.Text = "H" .. i
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.Parent = CaveSelectorFrame

    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(0, 6)
    bCorner.Parent = btn

    btn.MouseButton1Click:Connect(function()
        STATE.SelectedCave = i
        for idx, b in ipairs(caveButtons) do
            b.BackgroundColor3 = (idx == i) and Color3.fromRGB(50, 110, 220) or Color3.fromRGB(35, 40, 55)
        end
    end)
    table.insert(caveButtons, btn)
end

createActionButton(TrailsPage, "📍 Lưu Vị Trí Hang Đang Đứng Cho Hang Đã Chọn", Color3.fromRGB(40, 140, 90), function()
    local hrp = getHRP()
    if hrp then
        STATE.CaveCFrames[STATE.SelectedCave] = hrp.CFrame
        sendWebhook("📍 ĐÃ LƯU TỌA ĐỘ", "Đã lưu tọa độ Hang " .. STATE.SelectedCave .. " thành công!", 5763719)
    end
end)

createActionButton(TrailsPage, "🚀 Teleport Tới Hang Đã Chọn Ngay", Color3.fromRGB(80, 100, 160), function()
    local pos = STATE.CaveCFrames[STATE.SelectedCave]
    if pos then
        safeTeleport(pos)
    else
        warn("[PS99] Bạn chưa lưu tọa độ cho Hang " .. STATE.SelectedCave .. "!")
    end
end)

createToggle(TrailsPage, "📦 Auto Phá Rương (Chests) Trong Hang", STATE.AutoCaveChests, function(v)
    STATE.AutoCaveChests = v
end)

createToggle(TrailsPage, "🥚 Auto Mở Trứng (Auto Hatch Egg)", STATE.AutoHatch, function(v)
    STATE.AutoHatch = v
    if not v and STATE.AutoFarmMoney and not STATE.IsFightingYeti then
        if STATE.FarmCFrame then safeTeleport(STATE.FarmCFrame) end
    end
end)

createToggle(TrailsPage, "⏩ Bỏ Qua Hoạt Ảnh Mở Trứng (Skip Animation)", STATE.SkipAnimation, function(v)
    STATE.SkipAnimation = v
    applySkipAnimation(v)
end)

--========================================================================
-- TRANG 4: BÃI FARM TIỀN (FARM ZONE)
--========================================================================

createToggle(TrailsPage, "💰 Tự Động Về Farm Tiền (Khi không mở trứng)", STATE.AutoFarmMoney, function(v)
    STATE.AutoFarmMoney = v
    if v and not STATE.AutoHatch and not STATE.IsFightingYeti then
        if STATE.FarmCFrame then safeTeleport(STATE.FarmCFrame) end
    end
end)

createToggle(FarmPage, "⛏️ Auto Đánh Đá / Breakables Bãi Farm", STATE.AutoHitBreakables, function(v)
    STATE.AutoHitBreakables = v
end)

createActionButton(FarmPage, "📍 Lưu Vị Trí Đang Đứng Làm Bãi Farm", Color3.fromRGB(40, 140, 90), function()
    local hrp = getHRP()
    if hrp then
        STATE.FarmCFrame = hrp.CFrame
        sendWebhook("📍 ĐÃ LƯU BÃI FARM", "Đã lưu vị trí bãi cày tiền thành công!", 5763719)
    end
end)

createActionButton(FarmPage, "🚀 Teleport Về Bãi Farm Ngay", Color3.fromRGB(80, 100, 160), function()
    if STATE.FarmCFrame then
        safeTeleport(STATE.FarmCFrame)
    end
end)

--========================================================================
-- TRANG 5: CÀI ĐẶT AFK & TIẾT KIỆM TÀI NGUYÊN
--========================================================================

createToggle(SettingsPage, "🛡️ Anti-AFK (Chống văng 20 phút)", STATE.AntiAFK, function(v)
    STATE.AntiAFK = v
end)

createToggle(SettingsPage, "🔄 Auto Reconnect Khi Đứt Mạng", STATE.AutoReconnect, function(v)
    STATE.AutoReconnect = v
end)

createToggle(SettingsPage, "🧲 Auto Hút Orbs & Nhặt Lootbags", STATE.AutoCollectDrops, function(v)
    STATE.AutoCollectDrops = v
end)

createToggle(SettingsPage, "🏆 Auto Nhận Expeditions Đỉnh Núi", STATE.AutoClaimExpeditions, function(v)
    STATE.AutoClaimExpeditions = v
end)

createToggle(SettingsPage, "🔋 Low CPU Mode (Màn Đen Tiết Kiệm Pin/Máy)", STATE.LowCpuMode, function(v)
    STATE.LowCpuMode = v
    applyLowCpu(v)
end)

createActionButton(SettingsPage, "📡 Gửi Báo Cáo Thử Nghiệm Tới Discord", Color3.fromRGB(100, 70, 180), function()
    sendWebhook("🔔 TEST WEBHOOK THÀNH CÔNG", "Kết nối từ Delta Executor tới Discord hoạt động hoàn hảo!", 5763719)
end)

-- Phím tắt RightShift cho PC để toggle UI
pcall(function()
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.KeyCode == Enum.KeyCode.RightShift then
            MainFrame.Visible = not MainFrame.Visible
        end
    end)
end)

print("[PS99 Summit Suite] Giao diện người dùng Delta đã tải thành công!")
