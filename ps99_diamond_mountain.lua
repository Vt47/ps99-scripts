--========================================================================
-- PS99 ADVANCED DISCORD LOGGER & AFK SUITE (DIAMOND MOUNTAIN UPDATE)
-- Tối ưu cho bản cập nhật Diamond Mountain!
-- Tích hợp:
--   - Webhook thông báo thời gian thực (Huge, Titanic, Gargantuan, Items)
--   - Báo cáo định kỳ 15 phút (Uptime, Diamonds/giờ, Loot, Pet list, FPS/Ping)
--   - Chống văng game (Anti-AFK 20m) & Tự động kết nối lại (Auto-Reconnect)
--   - Tự động hút Orbs & nhặt Lootbags rơi ra từ Rubble Walls / Quái
--   - Tự động đánh Breakables / Rubble Walls khu vực Diamond Mountain
--   - Tự động nhận thưởng Expeditions (Cơ hội Huge Expedition Wolf)
--   - Chế độ siêu tiết kiệm CPU/GPU (Low CPU Mode / Toggle 3D Rendering)
--========================================================================

-- CẤU HÌNH SCRIPT (TÙY CHỈNH THEO NHU CẦU CỦA BẠN)
local CONFIG = {
    -- [DISCORD WEBHOOK]
    Webhook = "",
    
    -- Điền Discord User ID của bạn (Ví dụ: "123456789012345678") để bot ping thẳng vào bạn trên Discord
    -- Để trống "" nếu không muốn bị tag/ping
    DiscordUserId = "", 

    -- Tùy chọn ping chuông khi ra đồ quý:
    MentionOnHuge = true,        -- Tag khi nở ra Huge
    MentionOnTitanic = true,     -- Tag khi trúng Titanic / Gargantuan
    MentionOnRareItem = false,   -- Tag khi nhặt được vật phẩm cực hiếm (Exclusive Egg, v.v.)

    -- [THỜI GIAN KIỂM TRA & BÁO CÁO]
    CheckInterval = 2,           -- Kiểm tra túi đồ mỗi 2 giây
    ReportInterval = 15 * 60,    -- Gửi báo cáo định kỳ mỗi 15 phút (900 giây)

    -- [TÍNH NĂNG THEO DÕI (TRACKING)]
    TrackPets = true,            -- Theo dõi Huge, Titanic, Gargantuan
    TrackDiamonds = true,        -- Theo dõi Kim cương & tính tốc độ Diamonds/giờ (Rate/h)
    TrackItems = true,           -- Theo dõi vật phẩm rơi (Keys, Gift Bags, Chests, Eggs)

    -- [TÍNH NĂNG AFK & TỰ ĐỘNG HÓA]
    AntiAFK = true,              -- Bật chống văng game 20 phút của Roblox
    AutoReconnect = true,        -- Tự động vào lại game nếu mất kết nối (Disconnect/Error)
    AutoCollectDrops = true,     -- Tự động hút Orbs (Kim cương, EXP) và nhặt Lootbags
    AutoFarmBreakables = true,   -- Tự động điều khiển pet tấn công các tảng đá/tường vỡ (Rubble Walls)
    AutoClaimExpeditions = true, -- Tự động nhận thưởng Expeditions trên đỉnh núi Diamond Mountain

    -- [TIẾT KIỆM TÀI NGUYÊN MÁY KHI TREO LÂU]
    LowCpuMode = false,          -- Tắt dựng hình 3D (Màn hình đen nhẹ) giúp giảm 70-80% CPU/GPU khi AFK
    Toggle3DKey = Enum.KeyCode.RightShift, -- Phím tắt để bật/tắt lại màn hình bất kỳ lúc nào
    FpsCap = 60,                 -- Giới hạn FPS khi AFK (Ví dụ: 30 hoặc 15 để máy mát hơn, để 60 nếu muốn mượt)
}

--========================================================================
-- KIỂM TRA MÔI TRƯỜNG EXECUTOR
--========================================================================

local req = request or http_request or (syn and syn.request) or (http and http.request)
if not req then
    warn("[PS99 AFK Suite] Executor của bạn không hỗ trợ hàm HTTP Request!")
    return
end

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")

local Player = Players.LocalPlayer

--========================================================================
-- TẢI DỮ LIỆU GAME (PS99 CLIENT FRAMEWORK)
--========================================================================

local Library = RS:WaitForChild("Library", 10)
if not Library then
    warn("[PS99 AFK Suite] Không tìm thấy ReplicatedStorage.Library!")
    return
end

local Client = Library:WaitForChild("Client", 10)
local Directory = Library:WaitForChild("Directory", 10)

local Save = Client and require(Client:WaitForChild("Save", 10))
local PetDirectory = Directory and require(Directory:WaitForChild("Pets", 10))
local Network = Client and Client:FindFirstChild("Network") and require(Client.Network)

-- Fallback cho Network nếu nằm ở ReplicatedStorage
if not Network and RS:FindFirstChild("Network") then
    Network = RS.Network
end

--========================================================================
-- CÁC HÀM TIỆN ÍCH (HELPERS)
--========================================================================

local function formatNumber(n)
    n = tonumber(n) or 0
    local sign = ""
    if n < 0 then
        sign = "-"
        n = math.abs(n)
    end

    if n >= 1e12 then
        return sign .. string.format("%.2fT", n / 1e12)
    elseif n >= 1e9 then
        return sign .. string.format("%.2fB", n / 1e9)
    elseif n >= 1e6 then
        return sign .. string.format("%.2fM", n / 1e6)
    elseif n >= 1e3 then
        return sign .. string.format("%.2fK", n / 1e3)
    end
    return sign .. tostring(math.floor(n))
end

local function formatDuration(seconds)
    seconds = math.max(0, math.floor(seconds))
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    return string.format("%02dh %02dm %02ds", hours, minutes, secs)
end

local function getSave()
    local success, data = pcall(function()
        return Save and Save.Get and Save.Get()
    end)
    if success and data then
        return data
    end
    return nil
end

local function getDiamonds(data)
    if not data or not data.Inventory or not data.Inventory.Currency then
        return 0
    end
    for _, currency in pairs(data.Inventory.Currency) do
        if currency.id == "Diamonds" then
            return tonumber(currency._am) or 0
        end
    end
    return 0
end

local function getFpsAndPing()
    local fps = 60
    pcall(function()
        fps = math.floor(1 / math.max(0.001, RunService.RenderStepped:Wait()))
    end)
    local ping = 0
    pcall(function()
        local stats = game:GetService("Stats")
        local net = stats:FindFirstChild("Network")
        local serverStatsItem = net and net:FindFirstChild("ServerStatsItem")
        local pingItem = serverStatsItem and serverStatsItem:FindFirstChild("Data Ping")
        if pingItem then
            ping = math.floor(pingItem:GetValue())
        end
    end)
    return fps, ping
end

--========================================================================
-- GỬI WEBHOOK DISCORD
--========================================================================

local function sendWebhook(title, description, color, mention, fields)
    if not CONFIG.Webhook or CONFIG.Webhook == "" then return end

    local embed = {
        description = description,
        color = color or 5793266,
        footer = {
            text = "PS99 Diamond Mountain Suite | " .. Player.Name,
            icon_url = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. Player.UserId .. "&width=150&height=150&format=png"
        },
        timestamp = DateTime.now():ToIsoDate()
    }

    if title and title ~= "" then
        embed.title = title
    end

    if fields and type(fields) == "table" and #fields > 0 then
        embed.fields = fields
    end

    local payload = {
        username = "Diamond Mountain Monitor",
        avatar_url = "https://images-ext-1.discordapp.net/external/t2pE8-hL3w1d6T4z4M6C3Vw.png",
        embeds = { embed }
    }

    if mention and mention ~= "" then
        payload.content = mention
    end

    pcall(function()
        req({
            Url = CONFIG.Webhook,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode(payload)
        })
    end)
end

--========================================================================
-- QUẢN LÝ PET & PHÂN LOẠI
--========================================================================

local function getPetType(petId)
    if not petId then return nil end
    local info = PetDirectory and PetDirectory[petId]

    if info then
        if info.gargantuan == true then return "Gargantuan" end
        if info.titanic == true then return "Titanic" end
        if info.huge == true then return "Huge" end
    end

    -- Fallback kiểm tra chuỗi tên (đề phòng Pet mới chưa cập nhật vào PetDirectory)
    local lower = string.lower(tostring(petId))
    if string.find(lower, "gargantuan") then return "Gargantuan" end
    if string.find(lower, "titanic") then return "Titanic" end
    if string.find(lower, "huge") then return "Huge" end

    return nil
end

local function getVariant(pet)
    local parts = {}
    if pet.pt == 1 then
        table.insert(parts, "Golden")
    elseif pet.pt == 2 then
        table.insert(parts, "Rainbow")
    end

    if pet.sh == true then
        table.insert(parts, "Shiny")
    end

    if #parts == 0 then
        return "Normal"
    end
    return table.concat(parts, " ")
end

local function petDisplayName(pet)
    local variant = getVariant(pet)
    local baseName = tostring(pet.id)
    local serial = pet.sn and (" #" .. tostring(pet.sn)) or ""

    if variant == "Normal" then
        return baseName .. serial
    end
    return variant .. " " .. baseName .. serial
end

local function petAmount(pet)
    return tonumber(pet._am) or 1
end

--========================================================================
-- QUẢN LÝ VẬT PHẨM (ITEMS / KEYS / GIFTS)
--========================================================================

local VALUABLE_ITEMS = {
    ["Exclusive"] = true,
    ["Hype Egg"] = true,
    ["Titanic Christmas Present"] = true,
    ["Gargantuan Gift"] = true,
    ["Diamond Gift Bag"] = true,
    ["Large Gift Bag"] = true,
    ["Mini Chest"] = true,
    ["Crystal Key"] = true,
    ["Secret Key"] = true,
    ["Tech Key"] = true,
    ["Void Key"] = true,
    ["Huge Machine Egg"] = true,
}

local function isValuableItem(itemId)
    local str = tostring(itemId)
    for pattern, _ in pairs(VALUABLE_ITEMS) do
        if string.find(str, pattern) then
            return true
        end
    end
    return false
end

local function makeItemSnapshot(data)
    local snapshot = {}
    if not data or not data.Inventory then return snapshot end

    local categories = {"Lootbox", "Egg", "Misc"}
    for _, cat in ipairs(categories) do
        if data.Inventory[cat] then
            for uuid, item in pairs(data.Inventory[cat]) do
                local id = item.id or tostring(uuid)
                local amt = tonumber(item._am) or 1
                snapshot[cat .. ":" .. id] = (snapshot[cat .. ":" .. id] or 0) + amt
            end
        end
    end
    return snapshot
end

--========================================================================
-- SNAPSHOT INVENTORY (PETS)
--========================================================================

local function makePetSnapshot(data)
    local snapshot = {}
    if not data or not data.Inventory or not data.Inventory.Pet then
        return snapshot
    end

    for uuid, pet in pairs(data.Inventory.Pet) do
        snapshot[uuid] = {
            id = pet.id,
            pt = pet.pt,
            sh = pet.sh,
            sn = pet.sn,
            amount = petAmount(pet)
        }
    end
    return snapshot
end

--========================================================================
-- KHỞI TẠO SESSION
--========================================================================

local initialData = getSave()
if not initialData then
    sendWebhook(
        "❌ LỖI KHỞI ĐỘNG SCRIPT",
        "Không thể đọc dữ liệu Save.Get() của Pet Simulator 99.\nVui lòng đảm bảo game đã tải xong hoàn toàn trước khi chạy script.",
        15158332
    )
    return
end

local previousPetSnapshot = makePetSnapshot(initialData)
local previousItemSnapshot = makeItemSnapshot(initialData)
local startingDiamonds = getDiamonds(initialData)
local sessionStart = os.time()

local totals = {
    Huge = 0,
    Titanic = 0,
    Gargantuan = 0
}

local obtainedPets = {}
local obtainedItems = {}

--========================================================================
-- THÔNG BÁO KHI NHẬN ĐƯỢC PET HIẾM MỚI
--========================================================================

local function recordPet(pet, amount)
    local petType = getPetType(pet.id)
    if not petType then return end

    amount = tonumber(amount) or 1
    totals[petType] = (totals[petType] or 0) + amount

    local name = petDisplayName(pet)
    local key = petType .. "|" .. name

    obtainedPets[key] = obtainedPets[key] or {
        type = petType,
        name = name,
        amount = 0
    }
    obtainedPets[key].amount = obtainedPets[key].amount + amount

    local icon = "🟣"
    local color = 10181046
    local shouldMention = false

    if petType == "Titanic" then
        icon = "🔴"
        color = 15158332
        shouldMention = CONFIG.MentionOnTitanic
    elseif petType == "Gargantuan" then
        icon = "🟡"
        color = 16766720
        shouldMention = CONFIG.MentionOnTitanic
    else
        shouldMention = CONFIG.MentionOnHuge
    end

    local mentionText = ""
    if shouldMention and CONFIG.DiscordUserId and CONFIG.DiscordUserId ~= "" then
        mentionText = "<@" .. CONFIG.DiscordUserId .. ">"
    end

    local data = getSave()
    local diamonds = data and getDiamonds(data) or startingDiamonds
    local diamondChange = diamonds - startingDiamonds

    local elapsed = math.max(1, os.time() - sessionStart)
    local diamondsPerHour = math.floor((diamondChange / elapsed) * 3600)

    local fields = {
        {
            name = "🐾 Thú Cưng Nhận Được",
            value = "**" .. name .. "**\nPhân loại: `" .. petType .. "`\nSố lượng: `+" .. amount .. "`",
            inline = true
        },
        {
            name = "💎 Kim Cương (Diamonds)",
            value = "Hiện có: `" .. formatNumber(diamonds) .. "`\nThay đổi: `" .. (diamondChange >= 0 and "+" or "") .. formatNumber(diamondChange) .. "`\nTốc độ: `" .. formatNumber(diamondsPerHour) .. "/h`",
            inline = true
        },
        {
            name = "🏆 Tổng Thu Thập Phiên Này",
            value = "🟣 Huge: **" .. totals.Huge .. "**\n🔴 Titanic: **" .. totals.Titanic .. "**\n🟡 Gargantuan: **" .. totals.Gargantuan .. "**",
            inline = false
        }
    }

    sendWebhook(
        icon .. " TRÚNG " .. string.upper(petType) .. " MỚI!",
        "Chúc mừng! Tài khoản **" .. Player.Name .. "** vừa nhận được một thú cưng cực phẩm!",
        color,
        mentionText,
        fields
    )
end

--========================================================================
-- VÒNG LẶP THEO DÕI TÚI ĐỒ (PETS & ITEMS)
--========================================================================

task.spawn(function()
    while true do
        task.wait(CONFIG.CheckInterval)

        local data = getSave()
        if data and data.Inventory then
            -- 1. Quét Pet
            if CONFIG.TrackPets and data.Inventory.Pet then
                local currentPetSnapshot = makePetSnapshot(data)

                for uuid, currentPet in pairs(currentPetSnapshot) do
                    local old = previousPetSnapshot[uuid]
                    if not old then
                        recordPet(currentPet, currentPet.amount)
                    else
                        local increase = currentPet.amount - (old.amount or 0)
                        if increase > 0 then
                            recordPet(currentPet, increase)
                        end
                    end
                end
                previousPetSnapshot = currentPetSnapshot
            end

            -- 2. Quét Items / Quà / Chìa khóa
            if CONFIG.TrackItems then
                local currentItemSnapshot = makeItemSnapshot(data)

                for fullId, currentAmt in pairs(currentItemSnapshot) do
                    local oldAmt = previousItemSnapshot[fullId] or 0
                    local diff = currentAmt - oldAmt

                    if diff > 0 then
                        local parts = string.split(fullId, ":")
                        local itemId = parts[2] or fullId

                        obtainedItems[itemId] = (obtainedItems[itemId] or 0) + diff

                        -- Thông báo tức thì nếu là đồ siêu hiếm
                        if isValuableItem(itemId) and (string.find(itemId, "Exclusive") or string.find(itemId, "Titanic") or string.find(itemId, "Gargantuan")) then
                            sendWebhook(
                                "🎁 NHẬN ĐƯỢC VẬT PHẨM SIÊU HIẾM!",
                                "**Vật phẩm:** `" .. itemId .. "`\n**Số lượng:** `+" .. diff .. "`\n**Tổng sở hữu:** `" .. currentAmt .. "`",
                                16753920,
                                (CONFIG.MentionOnRareItem and CONFIG.DiscordUserId and CONFIG.DiscordUserId ~= "") and ("<@" .. CONFIG.DiscordUserId .. ">") or nil
                            )
                        end
                    end
                end
                previousItemSnapshot = currentItemSnapshot
            end
        end
    end
end)

--========================================================================
-- XÂY DỰNG BÁO CÁO PET & ITEM CHO 15 PHÚT
--========================================================================

local function buildPetReport()
    local lines = {}
    for _, item in pairs(obtainedPets) do
        local icon = "🟣"
        if item.type == "Titanic" then
            icon = "🔴"
        elseif item.type == "Gargantuan" then
            icon = "🟡"
        end
        table.insert(lines, icon .. " " .. item.name .. " `x" .. item.amount .. "`")
    end
    table.sort(lines)
    if #lines == 0 then return "*Chưa có pet quý hiếm nào*" end
    return table.concat(lines, "\n")
end

local function buildItemReport()
    local lines = {}
    for name, amt in pairs(obtainedItems) do
        local icon = "📦"
        if string.find(name, "Key") then icon = "🗝️"
        elseif string.find(name, "Chest") then icon = "🎁"
        elseif string.find(name, "Egg") then icon = "🥚"
        elseif string.find(name, "Bag") or string.find(name, "Gift") then icon = "💎" end

        table.insert(lines, icon .. " " .. name .. " `+" .. formatNumber(amt) .. "`")
    end
    table.sort(lines)
    if #lines == 0 then return "*Chưa thu thập thêm vật phẩm nào*" end
    if #lines > 12 then
        local trimmed = {}
        for i = 1, 12 do table.insert(trimmed, lines[i]) end
        table.insert(trimmed, "... *(và " .. (#lines - 12) .. " loại khác)*")
        return table.concat(trimmed, "\n")
    end
    return table.concat(lines, "\n")
end

--========================================================================
-- HÀM GỬI BÁO CÁO 15 PHÚT (PERIODIC STATUS REPORT)
--========================================================================

local function sendReport()
    local data = getSave()
    if not data then return end

    local diamonds = getDiamonds(data)
    local diamondChange = diamonds - startingDiamonds
    local elapsed = math.max(1, os.time() - sessionStart)
    local diamondsPerHour = math.floor((diamondChange / elapsed) * 3600)

    local fps, ping = getFpsAndPing()

    local fields = {
        {
            name = "💎 Kim Cương (Diamond Mountain)",
            value = "Bắt đầu: `" .. formatNumber(startingDiamonds) .. "`\nHiện tại: `" .. formatNumber(diamonds) .. "`\nThu hoạch: `" .. (diamondChange >= 0 and "+" or "") .. formatNumber(diamondChange) .. "`\n⚡ Tốc độ: `" .. (diamondsPerHour >= 0 and "+" or "") .. formatNumber(diamondsPerHour) .. "/giờ`",
            inline = false
        },
        {
            name = "🐾 Tổng Số Pet Quý Đã Nhận",
            value = "🟣 Huge: **" .. totals.Huge .. "**\n🔴 Titanic: **" .. totals.Titanic .. "**\n🟡 Gargantuan: **" .. totals.Gargantuan .. "**\n\n" .. buildPetReport(),
            inline = false
        },
        {
            name = "📦 Vật Phẩm Thu Hoạch Được",
            value = buildItemReport(),
            inline = false
        },
        {
            name = "⚙️ Trạng Thái Máy & Phiên Treo",
            value = "⏱️ Thời gian treo: `" .. formatDuration(elapsed) .. "`\n📶 Ping: `" .. ping .. " ms` | 🖥️ FPS: `" .. fps .. "`\n🔋 Low CPU Mode: `" .. (CONFIG.LowCpuMode and "ĐANG BẬT" or "TẮT") .. "`",
            inline = false
        }
    }

    sendWebhook(
        "📊 BÁO CÁO ĐỊNH KỲ - PET SIMULATOR 99",
        "Báo cáo tiến trình AFK tự động sau mỗi 15 phút tại khu vực **Diamond Mountain**.",
        3447003,
        nil,
        fields
    )
end

-- Vòng lặp gửi báo cáo định kỳ
task.spawn(function()
    while true do
        task.wait(CONFIG.ReportInterval)
        sendReport()
    end
end)

--========================================================================
-- MODULE 1: CHỐNG VĂNG GAME (ANTI-AFK / 20 MIN IDLE KICK)
--========================================================================

if CONFIG.AntiAFK then
    Player.Idled:Connect(function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end)

    -- Phản hồi định kỳ dự phòng mỗi 3 phút
    task.spawn(function()
        while true do
            task.wait(180)
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new(50, 50))
            end)
        end
    end)
end

--========================================================================
-- MODULE 2: TỰ ĐỘNG KẾT NỐI LẠI (AUTO-RECONNECT ON DISCONNECT)
--========================================================================

if CONFIG.AutoReconnect then
    local reconnected = false

    local function handleDisconnect()
        if reconnected then return end
        reconnected = true

        pcall(function()
            sendWebhook(
                "⚠️ CẢNH BÁO MẤT KẾT NỐI!",
                "Tài khoản **" .. Player.Name .. "** bị ngắt kết nối khỏi server.\nĐang chuẩn bị Reconnect tự động sau 10 giây...",
                15158332
            )
        end)

        task.wait(10)

        pcall(function()
            if #Players:GetPlayers() <= 1 then
                TeleportService:Teleport(game.PlaceId, Player)
            else
                TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, Player)
            end
        end)

        task.wait(15)
        pcall(function()
            TeleportService:Teleport(game.PlaceId, Player)
        end)
    end

    pcall(function()
        GuiService.ErrorMessageChanged:Connect(function()
            local code = GuiService:GetErrorCode()
            if code and code.Value > 0 then
                handleDisconnect()
            end
        end)
    end)

    task.spawn(function()
        while not reconnected do
            task.wait(5)
            pcall(function()
                local promptGui = CoreGui:FindFirstChild("RobloxPromptGui")
                if promptGui then
                    local overlay = promptGui:FindFirstChild("promptOverlay")
                    if overlay and overlay:FindFirstChild("ErrorPrompt") then
                        handleDisconnect()
                    end
                end
            end)
        end
    end)
end

--========================================================================
-- MODULE 3: HÚT ORBS & NHẶT LOOTBAGS RƠI TỪ ĐÁ / QUÁI
--========================================================================

if CONFIG.AutoCollectDrops then
    task.spawn(function()
        local Things = workspace:WaitForChild("__THINGS", 15)
        if not Things then return end

        local Orbs = Things:WaitForChild("Orbs", 10)
        local Lootbags = Things:WaitForChild("Lootbags", 10)

        while true do
            task.wait(0.4)
            pcall(function()
                local char = Player.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if not hrp then return end

                -- 1. Hút Orbs (EXP, Kim cương rơi)
                if Orbs then
                    for _, orb in pairs(Orbs:GetChildren()) do
                        if orb:IsA("BasePart") then
                            orb.CFrame = hrp.CFrame
                        end
                    end
                end

                -- 2. Hút và nhặt Lootbags
                if Lootbags then
                    for _, bag in pairs(Lootbags:GetChildren()) do
                        if bag:IsA("Model") then
                            local part = bag.PrimaryPart or bag:FindFirstChildWhichIsA("BasePart")
                            if part then
                                part.CFrame = hrp.CFrame
                            end
                        elseif bag:IsA("BasePart") then
                            bag.CFrame = hrp.CFrame
                        end
                    end
                end
            end)
        end
    end)
end

--========================================================================
-- MODULE 4: TỰ ĐỘNG ĐÁNH BREAKABLES / RUBBLE WALLS Ở GẦN
--========================================================================

if CONFIG.AutoFarmBreakables then
    task.spawn(function()
        local Things = workspace:WaitForChild("__THINGS", 15)
        local Breakables = Things and Things:WaitForChild("Breakables", 10)

        while true do
            task.wait(0.5)
            pcall(function()
                local char = Player.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if not hrp or not Breakables then return end

                local nearestBreakable = nil
                local minDistance = 120

                for _, b in pairs(Breakables:GetChildren()) do
                    local part = b:IsA("BasePart") and b or (b:IsA("Model") and (b.PrimaryPart or b:FindFirstChildWhichIsA("BasePart")))
                    if part then
                        local dist = (part.Position - hrp.Position).Magnitude
                        if dist < minDistance then
                            minDistance = dist
                            nearestBreakable = b
                        end
                    end
                end

                if nearestBreakable and Network and Network.Fire then
                    Network.Fire("Breakables_PlayerAttackBreakable", nearestBreakable.Name, "1")
                end
            end)
        end
    end)
end

--========================================================================
-- MODULE 5: TỰ ĐỘNG NHẬN EXPEDITIONS TRÊN ĐỈNH NÚI DIAMOND MOUNTAIN
--========================================================================

if CONFIG.AutoClaimExpeditions then
    task.spawn(function()
        while true do
            task.wait(60) -- Thử nhận mỗi 1 phút
            pcall(function()
                if Network and Network.Invoke then
                    Network.Invoke("Expeditions: Claim All")
                    Network.Invoke("Expedition: Claim All")
                end
            end)
        end
    end)
end

--========================================================================
-- MODULE 6: GIẢM TẢI CPU/GPU (LOW CPU MODE & 3D RENDERING TOGGLE)
--========================================================================

local function applyLowCpuMode(enabled)
    pcall(function()
        RunService:Set3dRenderingEnabled(not enabled)
    end)
    if setfpscap then
        pcall(function()
            setfpscap(enabled and (CONFIG.FpsCap or 15) or 60)
        end)
    end
end

if CONFIG.LowCpuMode then
    applyLowCpuMode(true)
end

-- Phím tắt chuyển đổi màn hình 3D (Mặc định RightShift)
pcall(function()
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.KeyCode == CONFIG.Toggle3DKey then
            CONFIG.LowCpuMode = not CONFIG.LowCpuMode
            applyLowCpuMode(CONFIG.LowCpuMode)
            print("[PS99 AFK] Đã chuyển chế độ Low CPU Mode:", CONFIG.LowCpuMode and "BẬT (Màn đen)" or "TẮT (Bình thường)")
        end
    end)
end)

--========================================================================
-- GỬI THÔNG BÁO BẮT ĐẦU CHẠY SCRIPT
--========================================================================

sendWebhook(
    "🟢 PS99 AFK SUITE ĐÃ KÍCH HOẠT THÀNH CÔNG!",
    "Script giám sát và tự động hóa cho bản cập nhật **Diamond Mountain** đã sẵn sàng hoạt động.",
    5763719,
    nil,
    {
        {
            name = "👤 Tài Khoản",
            value = "`" .. Player.Name .. "` (`" .. Player.DisplayName .. "`)",
            inline = true
        },
        {
            name = "💎 Kim Cương Ban Đầu",
            value = "`" .. formatNumber(startingDiamonds) .. "`",
            inline = true
        },
        {
            name = "⚡ Tính Năng AFK Đang Bật",
            value = "• Anti-AFK (20m Kick): `BẬT`\n• Auto-Reconnect: `BẬT`\n• Hút Orbs & Lootbags: `BẬT`\n• Đánh Rubble Walls: `BẬT`\n• Nhận Expeditions: `BẬT`\n• Low CPU Mode: `" .. (CONFIG.LowCpuMode and "BẬT" or "TẮT (RightShift để bật)") .. "`",
            inline = false
        },
        {
            name = "🎯 Mục Tiêu Giám Sát",
            value = "🟣 **Huge** | 🔴 **Titanic** | 🟡 **Gargantuan**\nĐịnh kỳ báo cáo: **Mỗi 15 phút**",
            inline = false
        }
    }
)

print("[PS99 Diamond Mountain AFK Suite] Đã khởi chạy thành công cho tài khoản " .. Player.Name .. "!")
