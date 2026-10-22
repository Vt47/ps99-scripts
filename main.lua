--========================================================================
-- PS99 DIAMOND MOUNTAIN - SUMMIT AFK & YETI BOSS SUITE (DELTA EXECUTOR)
-- Phiên bản V6: Khắc phục triệt để lỗi "You can claim again in 18h37m",
-- nhận diện "The Shiny Yeti / Team up to beat it", không click nút Send Pets.
--========================================================================

-- 1. DIỆT SẠCH TOÀN BỘ PHIÊN BẢN CŨ TRONG BỘ NHỚ KHI EXECUTE LẠI (CLEAN TEARDOWN)
pcall(function()
    if _G.PS99_SUMMIT_CLEANUP and type(_G.PS99_SUMMIT_CLEANUP) == "function" then
        _G.PS99_SUMMIT_CLEANUP()
    end
end)

_G.PS99_SUMMIT_RUNNING = false
_G.PS99_SUMMIT_SESSION = 0

-- Dọn dẹp giao diện GUI cũ ngay từ dòng đầu tiên
pcall(function()
    local containers = {}
    if typeof(gethui) == "function" then table.insert(containers, gethui()) end
    local cg = game:GetService("CoreGui")
    if cg then table.insert(containers, cg) end
    local p = game:GetService("Players").LocalPlayer
    if p and p:FindFirstChild("PlayerGui") then table.insert(containers, p.PlayerGui) end

    for _, c in ipairs(containers) do
        for _, child in pairs(c:GetChildren()) do
            if child.Name == "PS99_Summit_Suite" or string.find(string.lower(child.Name), "ps99_summit") then
                child:Destroy()
            end
        end
    end
end)

-- Chờ một thoáng để toàn bộ vòng lặp cũ nhận diện session 0 và tự hủy hoàn toàn
task.wait(0.25)

local CURRENT_SESSION_ID = tick()
_G.PS99_SUMMIT_SESSION = CURRENT_SESSION_ID
_G.PS99_SUMMIT_RUNNING = true

-- Quản lý tất cả Event Connections để ngắt sạch khi execute lại
local Connections = {}
local function registerConn(conn)
    if conn then table.insert(Connections, conn) end
    return conn
end

_G.PS99_SUMMIT_CLEANUP = function()
    _G.PS99_SUMMIT_RUNNING = false
    _G.PS99_SUMMIT_SESSION = 0

    -- Ngắt toàn bộ Event Connections (UserInput, ScriptContext, Idled, ErrorMessage...)
    for _, conn in ipairs(Connections) do
        pcall(function()
            if conn and conn.Connected then
                conn:Disconnect()
            end
        end)
    end
    table.clear(Connections)

    -- Xóa sạch mọi Giao diện GUI cũ của script trên màn hình
    pcall(function()
        local containers = {}
        if typeof(gethui) == "function" then table.insert(containers, gethui()) end
        local cg = game:GetService("CoreGui")
        if cg then table.insert(containers, cg) end
        local p = game:GetService("Players").LocalPlayer
        if p and p:FindFirstChild("PlayerGui") then table.insert(containers, p.PlayerGui) end

        for _, c in ipairs(containers) do
            for _, child in pairs(c:GetChildren()) do
                if child.Name == "PS99_Summit_Suite" or string.find(string.lower(child.Name), "ps99_summit") then
                    child:Destroy()
                end
            end
        end
    end)
end

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

local VIM
pcall(function()
    VIM = game:GetService("VirtualInputManager")
end)

local Player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local Camera = workspace.CurrentCamera

local Library, Client, Directory, Save, PetDirectory, Network, EggCmds
local lblAction, lblCaveTimer, lblYetiStatus, lblYetiCount, lblHatchedEggs, lblDiamonds, lblDiffDiamonds, lblUptime, lblPets, lblSelectedCaves
local formatNumber, formatDuration, getDiamonds, getPetCategory, getPetVariantText, triggerRarePetAlert
local getSelectedCavesList, formatSelectedCavesText, getBestActiveCave, pickNextCaveAfterHatch, updateCaveButtonsUI
local getTravelingMerchant, handleTravelingMerchantPurchase, manualBuyTravelingMerchant
pcall(function()
    Library = RS:FindFirstChild("Library") or RS:WaitForChild("Library", 5)
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
    IsPaused = false,
    -- [TRAVELING MERCHANT]
    AutoTravelingMerchant = true,
    IsBuyingMerchant = false,
    LastMerchantName = "",
    LastMerchantTime = 0,
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
    SelectedCaves = {
        [1] = true,
        [2] = false,
        [3] = false,
        [4] = false,
        [5] = false,
        [6] = false,
    },
    AutoCaveChests = false,
    IsAttackingCaveChest = false,
    CurrentChestObj = nil,
    CurrentChestCF = nil,
    AutoHatch = false,
    AutoMaxHatch = true,
    HatchAmount = 58,
    ShowHatchPopup = true,
    SkipAnimation = true,
    SelectedEggName = "Nearest",
    CaveHatchedForThisCycle = {
        [1] = false,
        [2] = false,
        [3] = false,
        [4] = false,
        [5] = false,
        [6] = false,
    },

    -- [PHIÊN MỞ TRỨNG HANG NÚI - CAVE HATCH SESSION]
    CaveHatchActive = false,
    CaveHatchCaveNum = 1,
    CaveHatchStartTime = 0,
    CaveHatchDuration = 300,
    CaveHatchEggId = nil,
    CaveHatchEggObj = nil,
    CaveHatchEggCF = nil,

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
    Webhook = "",
    DiscordUserId = "",
    NotifyOnHuge = true,
    MentionOnHuge = true,
    MentionOnTitanic = true,
    PeriodicReport = true,
    ReportInterval = 15 * 60,
    ExecuteAlert = true,

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
-- HỆ THỐNG GHI NHẬT KÝ HOẠT ĐỘNG & BẮT LỖI (LIVE ACTIVITY & ERROR LOGGER)
--========================================================================
local ACTIVITY_LOGS = {}
local MAX_LOGS = 300
local LOG_FILE = "ps99_activity_log.txt"
local updateLogsUI = nil
local lastErrorWebhookTime = 0

-- Hàm gửi thông báo Webhook Discord toàn cục
local function sendWebhook(title, description, color, mention, fields, thumbnail)
    if not STATE.Webhook or STATE.Webhook == "" then return end
    local fn = request or http_request or (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request)
    if not fn then return end
    pcall(function()
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
        if fields and type(fields) == "table" and #fields > 0 then
            embed.fields = fields
        end
        if thumbnail and type(thumbnail) == "string" and thumbnail ~= "" then
            embed.thumbnail = { url = thumbnail }
        end

        local payload = {
            username = "Diamond Mountain Monitor",
            avatar_url = "https://images-ext-1.discordapp.net/external/t2pE8-hL3w1d6T4z4M6C3Vw.png",
            content = mention or "",
            embeds = { embed }
        }
        local jsonBody = HttpService:JSONEncode(payload)
        local targets = {}
        if string.find(STATE.Webhook, "discord%.com") or string.find(STATE.Webhook, "discordapp%.com") then
            table.insert(targets, (string.gsub(string.gsub(STATE.Webhook, "discord%.com", "webhook.lewisakura.moe"), "discordapp%.com", "webhook.lewisakura.moe")))
            table.insert(targets, (string.gsub(string.gsub(STATE.Webhook, "discord%.com", "discord.yeesen.dev"), "discordapp%.com", "discord.yeesen.dev")))
        end
        table.insert(targets, STATE.Webhook)

        for _, targetUrl in ipairs(targets) do
            local ok, res = pcall(function()
                return fn({
                    Url = targetUrl,
                    url = targetUrl,
                    Method = "POST",
                    method = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    headers = { ["Content-Type"] = "application/json" },
                    Body = jsonBody,
                    body = jsonBody
                })
            end)
            if ok and res then
                local status = type(res) == "table" and (res.StatusCode or res.status_code or res.Status) or nil
                if status == 200 or status == 204 or (status == nil and res.Body ~= nil) then
                    break
                end
            end
            task.wait(0.2)
        end
    end)
end

local function logActivity(category, message)
    local timeStr = os.date("%H:%M:%S")
    local line = string.format("[%s] [%s] %s", timeStr, tostring(category):upper(), tostring(message))
    
    table.insert(ACTIVITY_LOGS, line)
    if #ACTIVITY_LOGS > MAX_LOGS then
        table.remove(ACTIVITY_LOGS, 1)
    end

    -- In ra Console Roblox (F9)
    print("[PS99 Log] " .. line)

    -- Tự động lưu file máy tính ps99_activity_log.txt (nếu executor hỗ trợ)
    pcall(function()
        if appendfile then
            appendfile(LOG_FILE, line .. "\n")
        elseif writefile and #ACTIVITY_LOGS % 10 == 0 then
            writefile(LOG_FILE, table.concat(ACTIVITY_LOGS, "\n"))
        end
    end)

    -- Tự động báo về Discord nếu xảy ra lỗi hệ thống nghiêm trọng (tối đa 1 lần mỗi 30s)
    if tostring(category):upper() == "LỖI_HỆ_THỐNG" and sendWebhook and (os.time() - lastErrorWebhookTime > 30) then
        lastErrorWebhookTime = os.time()
        sendWebhook("⚠️ PHÁT HIỆN LỖI SCRIPT (AUTO ERROR LOG)", "```text\n" .. tostring(message) .. "\n```", 16724787)
    end

    -- Cập nhật giao diện nếu tab Nhật Ký đang mở
    if updateLogsUI then
        pcall(updateLogsUI)
    end
end

-- ========================================================
-- TIỆN ÍCH TOÀN CỤC: ĐỊNH DẠNG SỐ, THỜI GIAN & KIM CƯƠNG
-- ========================================================
formatNumber = function(n)
    n = tonumber(n) or 0
    local sign = n < 0 and "-" or ""
    n = math.abs(n)
    if n >= 1e12 then return sign .. string.format("%.2fT", n / 1e12)
    elseif n >= 1e9 then return sign .. string.format("%.2fB", n / 1e9)
    elseif n >= 1e6 then return sign .. string.format("%.2fM", n / 1e6)
    elseif n >= 1e3 then return sign .. string.format("%.2fK", n / 1e3) end
    return sign .. tostring(math.floor(n))
end

formatDuration = function(seconds)
    seconds = math.max(0, math.floor(seconds))
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    return string.format("%02dh %02dm %02ds", h, m, s)
end

getDiamonds = function()
    local amt = 0
    pcall(function()
        if Save and Save.Get then
            local data = Save.Get()
            if data and data.Inventory and data.Inventory.Currency then
                for _, curr in pairs(data.Inventory.Currency) do
                    if curr.id == "Diamonds" then
                        amt = tonumber(curr._am) or 0
                        break
                    end
                end
            end
        end
    end)
    return amt
end

-- ========================================================
-- QUẢN LÝ & PHÂN LOẠI THÚ CƯNG HIẾM (HUGE / TITANIC / GARGANTUAN)
-- ========================================================
getPetCategory = function(petId)
    if not petId then return nil end
    pcall(function()
        if PetDirectory then
            local info = PetDirectory[petId] or (PetDirectory.Get and PetDirectory:Get(petId))
            if info then
                if info.gargantuan == true then return "Gargantuan" end
                if info.titanic == true then return "Titanic" end
                if info.huge == true then return "Huge" end
            end
        end
    end)
    local lower = string.lower(tostring(petId))
    if string.find(lower, "gargantuan") then return "Gargantuan" end
    if string.find(lower, "titanic") then return "Titanic" end
    if string.find(lower, "huge") then return "Huge" end
    return nil
end

getPetVariantText = function(petData)
    local parts = {}
    local isRainbow = (petData.pt == 2) or petData.rainbow or (string.find(string.lower(tostring(petData.id or "")), "rainbow") ~= nil)
    local isGolden = (petData.pt == 1) or petData.golden or (string.find(string.lower(tostring(petData.id or "")), "golden") ~= nil)
    local isShiny = (petData.sh == true) or petData.shiny or (string.find(string.lower(tostring(petData.id or "")), "shiny") ~= nil)

    if isRainbow then
        table.insert(parts, "🌈 Rainbow")
    elseif isGolden then
        table.insert(parts, "🟡 Golden")
    else
        table.insert(parts, "⚪ Regular")
    end

    if isShiny then
        table.insert(parts, "✨ Shiny")
    end

    return table.concat(parts, " + ")
end

triggerRarePetAlert = function(petData, amount)
    if not STATE.NotifyOnHuge then return end
    amount = tonumber(amount) or 1
    local petId = tostring(petData.id or "Unknown Pet")
    local cat = getPetCategory(petId)
    if not cat then return end

    local isTest = string.find(petId, "%[TEST%]") ~= nil
    local variantStr = getPetVariantText(petData)
    local serial = petData._un or petData.sn
    local serialStr = (serial and tonumber(serial)) and (" #" .. tostring(serial)) or ""

    -- Chỉ cập nhật thống kê khi là pet thật từ game
    if not isTest then
        if cat == "Gargantuan" then
            STATE.TotalGargantuan = STATE.TotalGargantuan + amount
        elseif cat == "Titanic" then
            STATE.TotalTitanic = STATE.TotalTitanic + amount
        elseif cat == "Huge" then
            STATE.TotalHuge = STATE.TotalHuge + amount
        end

        pcall(function()
            if lblPets then
                lblPets.Text = "🟣 " .. STATE.TotalHuge .. " | 🔴 " .. STATE.TotalTitanic
            end
        end)
    end

    -- Báo Pop-up trong game (Roblox Core Notification)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = (isTest and "🧪 [TEST] " or "🎉 ") .. cat:upper() .. " PET!",
            Text = petId .. "\n" .. variantStr .. serialStr .. (amount > 1 and (" x" .. amount) or ""),
            Duration = 12
        })
    end)

    -- Ghi vào Live Activity Log
    logActivity("HUGE_ALERT", string.format("%s BẠN VỪA NHẬN ĐƯỢC %s: %s [%s]%s x%d!", isTest and "🧪 [TEST]" or "🎉", cat:upper(), petId, variantStr, serialStr, amount))

    -- Cấu hình màu sắc & Biểu tượng Webhook
    local embedColor = 10181046 -- Tím (Huge: #9B59B6)
    local iconEmoji = "🟣"
    local shouldMention = STATE.MentionOnHuge

    if cat == "Titanic" then
        embedColor = 15158332 -- Đỏ (Titanic: #E74C3C)
        iconEmoji = "🔴"
        shouldMention = STATE.MentionOnTitanic
    elseif cat == "Gargantuan" then
        embedColor = 16766720 -- Vàng (Gargantuan: #FFAA00)
        iconEmoji = "🟡"
        shouldMention = STATE.MentionOnTitanic
    end

    local mentionText = ""
    if shouldMention and not isTest then
        if STATE.DiscordUserId and STATE.DiscordUserId ~= "" then
            mentionText = "<@" .. tostring(STATE.DiscordUserId) .. ">"
        else
            mentionText = "@everyone"
        end
    end

    -- Tìm ảnh đại diện của Thú cưng
    local petThumbUrl = nil
    pcall(function()
        if PetDirectory then
            local dir = PetDirectory[petId] or (PetDirectory.Get and PetDirectory:Get(petId))
            if dir and dir.thumbnail then
                local assetId = string.match(tostring(dir.thumbnail), "%d+")
                if assetId then
                    petThumbUrl = "https://www.roblox.com/asset-thumbnail/image?assetId=" .. assetId .. "&width=420&height=420&format=png"
                end
            end
        end
    end)

    local elapsed = math.max(1, os.time() - (STATE.SessionStart or os.time()))
    local curDiamonds = getDiamonds()
    local startDiamonds = STATE.StartingDiamonds or curDiamonds
    local diffDiamonds = curDiamonds - startDiamonds
    local eggLoc = STATE.SelectedEggName or (STATE.SelectedCave and ("Hang " .. tostring(STATE.SelectedCave))) or "Đỉnh Núi PS99"

    local fields = {
        {
            name = "🐾 Thú Cưng",
            value = "**" .. petId .. "**" .. serialStr,
            inline = true
        },
        {
            name = "✨ Biến Thể",
            value = "`" .. variantStr .. "`",
            inline = true
        },
        {
            name = "👤 Tài Khoản",
            value = "`" .. Player.Name .. "`",
            inline = true
        },
        {
            name = "🥚 Nguồn / Trứng",
            value = "`" .. tostring(eggLoc) .. "`",
            inline = true
        },
        {
            name = "💎 Kim Cương",
            value = "`" .. formatNumber(curDiamonds) .. "` (" .. (diffDiamonds >= 0 and "+" or "") .. formatNumber(diffDiamonds) .. ")",
            inline = true
        },
        {
            name = "⏳ Thời Gian Treo",
            value = "`" .. formatDuration(elapsed) .. "`",
            inline = true
        },
        {
            name = "🏆 Thống Kê Phiên Này",
            value = "🟣 Huge: **" .. STATE.TotalHuge .. "** | 🔴 Titanic: **" .. STATE.TotalTitanic .. "** | 🟡 Gargantuan: **" .. STATE.TotalGargantuan .. "**",
            inline = false
        },
        {
            name = "📦 Tổng Trứng Đã Mở",
            value = "`" .. formatNumber(STATE.TotalHatchedEggs) .. "` quả",
            inline = true
        }
    }
    if serial and tonumber(serial) then
        table.insert(fields, {
            name = "🔢 Số Serial",
            value = "`#" .. tostring(serial) .. "`",
            inline = true
        })
    end

    local alertTitle = string.format("%s TRÚNG %s MỚI! %s", iconEmoji, cat:upper(), iconEmoji)
    if isTest then alertTitle = "🧪 [TEST] " .. alertTitle end

    local alertDesc = string.format("🎉 **Chúc mừng!** Tài khoản **%s** vừa nhận được một thú cưng **%s** cực phẩm!\n**Thú cưng:** `%s`\n**Biến thể:** `%s`", Player.Name, cat:upper(), petId, variantStr)

    sendWebhook(alertTitle, alertDesc, embedColor, mentionText, fields, petThumbUrl)
end

-- Tự động lắng nghe và ghi lại bất kỳ lỗi Script / Engine nào
pcall(function()
    local ScriptContext = game:GetService("ScriptContext")
    registerConn(ScriptContext.Error:Connect(function(msg, stack, scriptInstance)
        if _G.PS99_SUMMIT_RUNNING and _G.PS99_SUMMIT_SESSION == CURRENT_SESSION_ID then
            logActivity("LỖI_HỆ_THỐNG", tostring(msg) .. " | " .. tostring(stack))
        end
    end))
end)

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
            SelectedCaves = STATE.SelectedCaves,
            FarmCFrame = cframeToTable(STATE.FarmCFrame),
            YetiArenaCFrame = cframeToTable(STATE.YetiArenaCFrame),
            CaveCFrames = caveTbl,
            AutoYeti = STATE.AutoYeti,
            AutoClickYeti = STATE.AutoClickYeti,
            AutoCaveChests = STATE.AutoCaveChests,
            AutoHatch = STATE.AutoHatch,
            AutoMaxHatch = STATE.AutoMaxHatch,
            HatchAmount = STATE.HatchAmount,
            AutoFarmMoney = STATE.AutoFarmMoney,
            AutoHitBreakables = STATE.AutoHitBreakables,
            AutoTravelingMerchant = STATE.AutoTravelingMerchant,
            ShowHatchPopup = STATE.ShowHatchPopup,
            SkipAnimation = STATE.SkipAnimation,
            SelectedEggName = STATE.SelectedEggName,
            ExecuteAlert = STATE.ExecuteAlert,
            NotifyOnHuge = STATE.NotifyOnHuge,
            MentionOnHuge = STATE.MentionOnHuge,
            MentionOnTitanic = STATE.MentionOnTitanic,
            PeriodicReport = STATE.PeriodicReport,
            Webhook = STATE.Webhook,
            DiscordUserId = STATE.DiscordUserId
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
        if data.SelectedCaves and type(data.SelectedCaves) == "table" then
            STATE.SelectedCaves = {}
            local hasAny = false
            for i = 1, 6 do
                local val = data.SelectedCaves[i]
                if val == nil then val = data.SelectedCaves[tostring(i)] end
                if val == true then
                    STATE.SelectedCaves[i] = true
                    hasAny = true
                else
                    STATE.SelectedCaves[i] = false
                end
            end
            if not hasAny then
                STATE.SelectedCaves[STATE.SelectedCave or 1] = true
            end
        end
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
        if data.AutoMaxHatch ~= nil then STATE.AutoMaxHatch = data.AutoMaxHatch end
        if data.HatchAmount ~= nil then STATE.HatchAmount = tonumber(data.HatchAmount) or STATE.HatchAmount end
        if data.AutoFarmMoney ~= nil then STATE.AutoFarmMoney = data.AutoFarmMoney end
        if data.AutoHitBreakables ~= nil then STATE.AutoHitBreakables = data.AutoHitBreakables end
        if data.AutoTravelingMerchant ~= nil then STATE.AutoTravelingMerchant = data.AutoTravelingMerchant end
        if data.ShowHatchPopup ~= nil then STATE.ShowHatchPopup = data.ShowHatchPopup end
        if data.SkipAnimation ~= nil then STATE.SkipAnimation = data.SkipAnimation end
        if data.SelectedEggName and data.SelectedEggName ~= "" then STATE.SelectedEggName = data.SelectedEggName end
        if data.ExecuteAlert ~= nil then STATE.ExecuteAlert = data.ExecuteAlert end
        if data.NotifyOnHuge ~= nil then STATE.NotifyOnHuge = data.NotifyOnHuge end
        if data.MentionOnHuge ~= nil then STATE.MentionOnHuge = data.MentionOnHuge end
        if data.MentionOnTitanic ~= nil then STATE.MentionOnTitanic = data.MentionOnTitanic end
        if data.PeriodicReport ~= nil then STATE.PeriodicReport = data.PeriodicReport end
        if data.Webhook and data.Webhook ~= "" then STATE.Webhook = data.Webhook end
        if data.DiscordUserId ~= nil then STATE.DiscordUserId = data.DiscordUserId end
    end)
end

loadConfig()
-- Đảm bảo mỗi lần execute script thì số trứng đã mở luôn được đặt lại về 0
STATE.TotalHatchedEggs = 0

-- Chống ngắt kết nối AFK bằng cách vô hiệu hóa kết nối Idled của CoreScript (Layer 1)
local getcons = getconnections or get_signal_cons
local function disableIdledConnections()
    pcall(function()
        if getcons then
            for _, conn in ipairs(getcons(Player.Idled)) do
                pcall(function()
                    if type(conn.Disable) == "function" then
                        conn:Disable()
                    elseif type(conn.disable) == "function" then
                        conn:disable()
                    elseif type(conn.Disconnect) == "function" then
                        conn:Disconnect()
                    elseif type(conn.disconnect) == "function" then
                        conn:disconnect()
                    end
                end)
            end
        end
    end)
end
if STATE.AntiAFK then
    disableIdledConnections()
end

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

--========================================================================
-- ĐIỀU PHỐI HANG, RƯƠNG & TRỨNG (CHUẨN HÓA 100% DỰA TRÊN DUMP_INFO)
--========================================================================

-- Lấy danh sách số thứ tự các hang đang được chọn (1-6)
getSelectedCavesList = function()
    local list = {}
    if not STATE.SelectedCaves or type(STATE.SelectedCaves) ~= "table" then
        STATE.SelectedCaves = { [STATE.SelectedCave or 1] = true }
    end
    for i = 1, 6 do
        if STATE.SelectedCaves[i] == true then
            table.insert(list, i)
        end
    end
    if #list == 0 then
        local def = tonumber(STATE.SelectedCave) or 1
        STATE.SelectedCaves[def] = true
        table.insert(list, def)
    end
    return list
end

-- Định dạng danh sách hang thành chuỗi hiển thị gọn gàng (VD: "Hang 3, Hang 4, Hang 5")
formatSelectedCavesText = function()
    local list = getSelectedCavesList()
    local names = {}
    for _, c in ipairs(list) do
        table.insert(names, "Hang " .. c)
    end
    return table.concat(names, ", ")
end

-- Lấy đối tượng và CFrame Rương Boss của Hang (Trail 1-6, ưu tiên rương gần nhân vật nhất)
local function getCaveChest(caveNum)
    caveNum = tonumber(caveNum) or STATE.SelectedCave
    local Things = workspace:FindFirstChild("__THINGS")
    local Breakables = Things and Things:FindFirstChild("Breakables")
    if not Breakables then return nil, nil end

    local targetArea = "trail" .. tostring(caveNum)

    local nearestChest = nil
    local nearestCF = nil
    local minDist = math.huge

    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local myPos = hrp and hrp.Position or Vector3.new(0, 0, 0)

    for _, b in pairs(Breakables:GetChildren()) do
        local areaId = string.lower(tostring(b:GetAttribute("AreaID") or ""))
        local bId = string.lower(tostring(b:GetAttribute("BreakableID") or ""))
        
        -- Khớp AreaID chính xác: Trail1, Trail2, ... Trail6 hoặc BreakableID có trail + caveNum
        local matchArea = (areaId == targetArea or string.find(areaId, targetArea) or string.find(areaId, "trail " .. tostring(caveNum)))
        local matchBId = (string.find(bId, "trail") and (string.find(bId, tostring(caveNum)) or matchArea)) or (bId == "diamondmountaintrailchest" and matchArea)

        if (matchArea or matchBId) and bId ~= "yeti" then
            local part = b:IsA("BasePart") and b or b:FindFirstChildWhichIsA("BasePart", true)
            if part then
                local dist = (part.Position - myPos).Magnitude
                if dist < minDist then
                    minDist = dist
                    nearestChest = b
                    nearestCF = part.CFrame
                end
            end
        end
    end

    return nearestChest, nearestCF
end

-- Lấy hàm tính số trứng tối đa (Max Hatch Slots)
local function getMaxHatchAmount()
    local maxAmt = nil
    -- 1. Gọi trực tiếp Client.EggCmds.GetMaxHatch()
    pcall(function()
        if EggCmds and typeof(EggCmds.GetMaxHatch) == "function" then
            maxAmt = tonumber(EggCmds.GetMaxHatch())
        end
    end)
    -- 2. Đọc từ Save.Get().EggSlotsPurchased hoặc EggHatchCount
    pcall(function()
        if Save and Save.Get then
            local s = Save.Get()
            if s then
                local slots = tonumber(s.EggSlotsPurchased)
                local count = tonumber(s.EggHatchCount)
                if slots and slots > 0 then
                    local calc = slots + 6
                    if not maxAmt or calc > maxAmt then maxAmt = calc end
                end
                if count and count > 0 then
                    if not maxAmt or count > maxAmt then maxAmt = count end
                end
            end
        end
    end)
    -- 3. Fallback về cấu hình hoặc 58 (số lượng max của người chơi)
    local cfgAmt = tonumber(STATE.HatchAmount) or 58
    if not maxAmt or maxAmt < cfgAmt then
        maxAmt = cfgAmt
    end
    return math.max(1, maxAmt or 58)
end

local handleEggOpeningVisuals = function() end

-- Bảng tên trứng mặc định của 6 Hang Núi Kim Cương
local CAVE_DEFAULT_EGGS = {
    [1] = "Frosted Geode Egg",
    [2] = "Diamond Cat Egg",
    [3] = "Boulder Ridge Egg",
    [4] = "Eagle Crag Egg",
    [5] = "Frostline Egg",
    [6] = "Diamond Summit Egg",
}

-- Lấy Model gốc của Trứng TRONG HANG (CHỈ LẤY TRỨNG THUỘC TRAIL / CAVE, LOẠI BỎ TRỨNG NGOÀI NÚI)
local function getCaveEggModel(caveNum)
    caveNum = tonumber(caveNum) or STATE.SelectedCave
    local Things = workspace:FindFirstChild("__THINGS")
    local CustomEggs = Things and Things:FindFirstChild("CustomEggs")
    if not CustomEggs then return nil, nil, nil end

    local expectedEggName = CAVE_DEFAULT_EGGS[caveNum]
    local caveCF = STATE.CaveCFrames[caveNum]

    -- Hàm lấy CFrame an toàn (Tuyệt đối không gọi GetPivot trên Highlight hay đối tượng phi vật lý)
    local function getEggCFrame(egg)
        if not egg or (not egg:IsA("Model") and not egg:IsA("BasePart")) then return nil end
        local part = egg:FindFirstChild("Center") or egg:FindFirstChild("Egg") or getPartFromInstance(egg)
        if part then return part.CFrame end
        if egg:IsA("Model") then
            local ok, piv = pcall(function() return egg:GetPivot() end)
            if ok and piv then return piv end
        end
        return nil
    end

    -- Hàm nhận diện trứng mua bằng Acorns bên ngoài núi (BẮT BUỘC LOẠI BỎ)
    local function isOutsideAcornEgg(egg)
        if not egg:IsA("Model") and not egg:IsA("BasePart") then return true end
        if egg:FindFirstChild("Acorns", true) then return true end
        if egg:GetAttribute("DM_GargRow") ~= nil then return true end
        for _, desc in pairs(egg:GetDescendants()) do
            if desc:IsA("TextLabel") and desc.Parent and desc.Parent.Name == "Acorns" then
                return true
            end
        end
        return false
    end

    -- ƯU TIÊN SỐ 1 TUYỆT ĐỐI: Khớp DM_TrailEgg == caveNum (Đây chính là quả trứng nằm trong Hang / Trail!)
    for _, egg in pairs(CustomEggs:GetChildren()) do
        if egg:IsA("Model") or egg:IsA("BasePart") then
            local trailNum = egg:GetAttribute("DM_TrailEgg")
            if trailNum and tonumber(trailNum) == tonumber(caveNum) then
                local cf = getEggCFrame(egg)
                if cf then
                    local attrEggId = egg:GetAttribute("DM_EggId")
                    local cleanEggName = (attrEggId and tostring(attrEggId)) or expectedEggName or tostring(egg.Name)
                    return egg, cf, cleanEggName
                end
            end
        end
    end

    -- ƯU TIÊN SỐ 2: Quả trứng nằm trong bán kính 120 studs quanh Rương Hang (chắc chắn ở trong Hang)
    if caveCF then
        for _, egg in pairs(CustomEggs:GetChildren()) do
            if (egg:IsA("Model") or egg:IsA("BasePart")) and not isOutsideAcornEgg(egg) then
                local cf = getEggCFrame(egg)
                if cf then
                    local dist = (cf.Position - caveCF.Position).Magnitude
                    if dist < 120 then
                        local attrEggId = egg:GetAttribute("DM_EggId")
                        local cleanEggName = (attrEggId and tostring(attrEggId)) or expectedEggName or tostring(egg.Name)
                        return egg, cf, cleanEggName
                    end
                end
            end
        end
    end

    -- ƯU TIÊN SỐ 3: Tìm quả trứng khớp tên nhưng BẮT BUỘC KHÔNG PHẢI trứng Acorns ngoài núi
    for _, egg in pairs(CustomEggs:GetChildren()) do
        if (egg:IsA("Model") or egg:IsA("BasePart")) and not isOutsideAcornEgg(egg) then
            local attrEggId = egg:GetAttribute("DM_EggId")
            local nameMatch = (expectedEggName and attrEggId and string.lower(tostring(attrEggId)) == string.lower(expectedEggName))
                           or (expectedEggName and string.lower(tostring(egg.Name)) == string.lower(expectedEggName))
            if nameMatch then
                local cf = getEggCFrame(egg)
                if cf then
                    local cleanEggName = (attrEggId and tostring(attrEggId)) or expectedEggName or tostring(egg.Name)
                    return egg, cf, cleanEggName
                end
            end
        end
    end

    return nil, nil, expectedEggName
end

-- Kiểm tra xem 1 GuiObject có thực sự hiển thị trên màn hình hay không
local function isGuiObjectVisible(gui)
    if not gui or not gui:IsA("GuiObject") then return false end
    if not gui.Visible then return false end

    local current = gui.Parent
    local hasLayerCollector = false
    while current and current ~= workspace and current ~= game do
        if current:IsA("LayerCollector") then
            if not current.Enabled then return false end
            hasLayerCollector = true
            break
        elseif current:IsA("GuiObject") then
            if not current.Visible then return false end
        end
        current = current.Parent
    end

    return hasLayerCollector
end

-- Kiểm tra xem Trứng có đang mở (không bị khóa bởi TextLabel 'Locked', PriceHUDLocked, hoặc Attribute)
local function isEggUnlocked(eggObj)
    if not eggObj or not eggObj.Parent or not eggObj:IsDescendantOf(workspace) then return false end

    local isLocked = false
    pcall(function()
        -- 1. Kiểm tra Attribute Locked trên Model trứng
        if eggObj:GetAttribute("Locked") == true or eggObj:GetAttribute("IsLocked") == true then
            isLocked = true
            return
        end

        -- 2. Duyệt qua các đối tượng con của trứng
        for _, desc in pairs(eggObj:GetDescendants()) do
            -- Nếu có GuiObject hoặc LayerCollector chuyên dụng báo Locked đang THỰC SỰ HIỂN THỊ
            if desc.Name == "PriceHUDLocked" or desc.Name == "LockedHUD" or desc.Name == "LockHUD" then
                if desc:IsA("LayerCollector") and desc.Enabled then
                    isLocked = true
                    return
                elseif desc:IsA("GuiObject") and isGuiObjectVisible(desc) then
                    isLocked = true
                    return
                end
            end

            -- Nếu có TextLabel với chữ "Locked" đang THỰC SỰ HIỂN THỊ trên màn hình
            if desc:IsA("TextLabel") and string.find(string.lower(desc.Text or ""), "locked") then
                if isGuiObjectVisible(desc) then
                    isLocked = true
                    return
                end
            end
        end
    end)

    return not isLocked
end

-- Lấy thông tin biển báo / cooldown của Hang từ Trails/X/Sign
local function getCaveSignInfo(caveNum)
    caveNum = tonumber(caveNum) or STATE.SelectedCave
    local isCooldown = false
    local isUnlocked = false
    local remainingSec = nil
    local signText = ""

    pcall(function()
        for _, desc in pairs(workspace:GetDescendants()) do
            if desc.Name == "Sign" and desc.Parent then
                local pName = desc.Parent.Name
                local gpName = desc.Parent.Parent and desc.Parent.Parent.Name or ""
                if pName == tostring(caveNum) or pName == "Trail" .. tostring(caveNum)
                   or (gpName == "Trails" and pName == tostring(caveNum)) then
                    for _, tl in pairs(desc:GetDescendants()) do
                        if tl:IsA("TextLabel") and tl.Visible and tl.Text ~= "" then
                            local txt = tl.Text
                            local lTxt = string.lower(txt)
                            signText = txt
                            local m, s = string.match(txt, "(%d+):(%d+)")
                            if m and s then
                                remainingSec = tonumber(m) * 60 + tonumber(s)
                            end
                            if string.find(lTxt, "next roll") or string.find(lTxt, "cooldown") or string.find(lTxt, "returns in") or string.find(lTxt, "opens in") or string.find(lTxt, "next chest") or string.find(lTxt, "locked") or string.find(lTxt, "closed") then
                                isCooldown = true
                            elseif (m and s) and not string.find(lTxt, "boss chest") and not string.find(lTxt, "close") and not string.find(lTxt, "open") then
                                isCooldown = true
                            elseif string.find(lTxt, "boss chest") or string.find(lTxt, "unlocked") or string.find(lTxt, "close") then
                                isUnlocked = true
                            end
                        end
                    end
                end
            end
        end
    end)

    -- Tự động reset cờ chu kỳ đã mở trứng khi rương Boss mới xuất hiện hoặc hang mở khóa
    if STATE.CaveHatchedForThisCycle and STATE.CaveHatchedForThisCycle[caveNum] then
        local cObj = getCaveChest(caveNum)
        if cObj or (isUnlocked and not isCooldown) then
            STATE.CaveHatchedForThisCycle[caveNum] = false
        end
    end

    return isUnlocked, isCooldown, remainingSec, signText
end

-- Lấy đối tượng Trứng Hang (CHỈ TRẢ VỀ KHI TRỨNG THẬT SỰ MỞ & KHÔNG BỊ KHÓA)
local function getCaveEgg(caveNum)
    caveNum = tonumber(caveNum) or STATE.SelectedCave

    -- 1. Nếu đã hoàn thành phiên mở trứng ở chu kỳ này -> Trứng đã đóng, chờ rương/chu kỳ mới
    if STATE.CaveHatchedForThisCycle and STATE.CaveHatchedForThisCycle[caveNum] then
        return nil, nil, nil
    end

    -- 2. Nếu rương Boss của Hang vẫn còn -> Chưa đến lượt mở trứng
    local cObj = getCaveChest(caveNum)
    if cObj then
        return nil, nil, nil
    end

    -- 3. Tìm Model Trứng thường của Hang
    local eggObj, eggCF, eggId = getCaveEggModel(caveNum)
    if not eggObj or not eggCF then
        return nil, nil, nil
    end

    -- 4. Kiểm tra Trứng có bị Khóa (Locked) hay không
    if not isEggUnlocked(eggObj) then
        return nil, nil, nil
    end

    return eggObj, eggCF, eggId
end

-- Kiểm tra trạng thái Hang: "chest", "egg", "closed"
local function isCaveOpen(caveNum)
    caveNum = tonumber(caveNum) or STATE.SelectedCave

    -- Nếu đang trong phiên mở trứng liên tục của chính hang này
    if STATE.CaveHatchActive and STATE.CaveHatchCaveNum == caveNum then
        local elapsed = os.time() - STATE.CaveHatchStartTime
        local rem = math.max(0, STATE.CaveHatchDuration - elapsed)
        if STATE.CaveHatchEggObj and isEggUnlocked(STATE.CaveHatchEggObj) then
            return true, "egg", STATE.CaveHatchEggObj, STATE.CaveHatchEggCF, STATE.CaveHatchEggId, rem
        end
    end

    -- 1. Kiểm tra Rương trong Hang
    local chestObj, chestCF = getCaveChest(caveNum)
    if chestObj and chestCF then
        return true, "chest", chestObj, chestCF, nil, nil
    end

    -- 2. Kiểm tra Trứng trong Hang
    local eggObj, eggCF, eggId = getCaveEgg(caveNum)
    if eggObj and eggCF and eggId then
        return true, "egg", eggObj, eggCF, eggId, 300
    end

    -- 3. Kiểm tra Biển báo Cooldown
    local isUnlocked, isCooldown, remSec, signText = getCaveSignInfo(caveNum)
    if isCooldown then
        return false, "closed", nil, nil, nil, remSec
    end

    if isUnlocked then
        return true, "open", nil, nil, nil, remSec
    end

    return false, "closed", nil, nil, nil, nil
end

-- Đếm ngược / Trạng thái hiển thị Dashboard
local function getCaveOpenCountdown(caveNum)
    caveNum = tonumber(caveNum) or STATE.SelectedCave
    local selected = getSelectedCavesList()

    if STATE.CaveHatchActive and STATE.CaveHatchCaveNum then
        local elapsed = os.time() - STATE.CaveHatchStartTime
        local rem = math.max(0, STATE.CaveHatchDuration - elapsed)
        local m = math.floor(rem / 60)
        local s = rem % 60
        return string.format("🟢 H%d: Mở Trứng (Còn %d:%02d)", STATE.CaveHatchCaveNum, m, s)
    end

    local cObj = getCaveChest(caveNum)
    if cObj then
        return string.format("🟢 H%d: Có Rương Boss", caveNum)
    end

    local eObj, _, eId = getCaveEgg(caveNum)
    if eObj then
        return string.format("🟢 H%d: Trứng Sẵn Sàng (%s)", caveNum, tostring(eId))
    end

    -- Nếu có nhiều hang được chọn, kiểm tra xem có hang nào khác trong danh sách đang sẵn sàng không
    if #selected > 1 then
        for _, c in ipairs(selected) do
            if c ~= caveNum then
                local otherChest = getCaveChest(c)
                if otherChest then
                    return string.format("🟢 H%d: Có Rương Boss", c)
                end
                local otherEgg = getCaveEgg(c)
                if otherEgg then
                    return string.format("🟢 H%d: Trứng Sẵn Sàng", c)
                end
            end
        end
    end

    local isUnlocked, isCooldown, remSec, signText = getCaveSignInfo(caveNum)
    if isCooldown and remSec and remSec > 0 then
        local m = math.floor(remSec / 60)
        local s = remSec % 60
        return string.format("⏳ H%d: Mở sau %d:%02d", caveNum, m, s)
    elseif isCooldown and signText ~= "" then
        return string.format("⏳ H%d: %s", caveNum, signText)
    elseif isUnlocked then
        return string.format("🟢 H%d: Sẵn Sàng (Hang Mở)", caveNum)
    end

    return "⏳ Đang Chờ Hồi / Quét..."
end

-- Tìm hang ưu tiên tiếp theo trong danh sách các hang đã chọn
getBestActiveCave = function()
    local selected = getSelectedCavesList()
    if #selected == 1 then
        return selected[1], nil
    end

    local startIdx = 1
    for idx, c in ipairs(selected) do
        if c == STATE.SelectedCave then
            startIdx = idx
            break
        end
    end

    -- 1. Ưu tiên cao nhất: Bất kỳ hang nào trong danh sách đang có RƯƠNG BOSS
    for i = 0, #selected - 1 do
        local checkIdx = ((startIdx - 1 + i) % #selected) + 1
        local c = selected[checkIdx]
        local chestObj, chestCF = getCaveChest(c)
        if chestObj and chestCF then
            return c, "chest", chestObj, chestCF
        end
    end

    -- 2. Ưu tiên nhì: Hang nào đang có TRỨNG MỞ ĐƯỢC (chưa hoàn thành phiên 5p ở chu kỳ này)
    for i = 0, #selected - 1 do
        local checkIdx = ((startIdx - 1 + i) % #selected) + 1
        local c = selected[checkIdx]
        if not (STATE.CaveHatchedForThisCycle and STATE.CaveHatchedForThisCycle[c]) then
            local eggObj, eggCF, eggId = getCaveEgg(c)
            if eggObj and eggCF and eggId then
                return c, "egg", eggObj, eggCF, eggId
            end
        end
    end

    -- 3. Tất cả các hang đã chọn đều đang cooldown / đã hoàn thành mở trứng chu kỳ này
    return STATE.SelectedCave or selected[1], "cooldown"
end

-- Chọn hang kế tiếp sau khi hoàn tất phiên mở trứng 5 phút
pickNextCaveAfterHatch = function(finishedCave)
    local selected = getSelectedCavesList()
    if #selected <= 1 then return finishedCave end

    local startIdx = 1
    for idx, c in ipairs(selected) do
        if c == finishedCave then
            startIdx = idx
            break
        end
    end

    -- Quét từ hang kế tiếp sau finishedCave
    for i = 1, #selected do
        local checkIdx = ((startIdx - 1 + i) % #selected) + 1
        local c = selected[checkIdx]
        -- Kiểm tra rương trước
        local chestObj, chestCF = getCaveChest(c)
        if chestObj and chestCF then
            return c
        end
        -- Kiểm tra trứng
        if not (STATE.CaveHatchedForThisCycle and STATE.CaveHatchedForThisCycle[c]) then
            local eggObj, eggCF, eggId = getCaveEgg(c)
            if eggObj and eggCF and eggId then
                return c
            end
        end
    end

    -- Nếu tất cả đang cooldown, chọn hang kế tiếp theo thứ tự vòng tròn
    local nextIdx = (startIdx % #selected) + 1
    return selected[nextIdx]
end

local findAnyCaveChest = function(startCave)
    startCave = tonumber(startCave) or STATE.SelectedCave or 1
    local cObj, cCF = getCaveChest(startCave)
    if cObj and cCF then return startCave, cObj, cCF end
    for i = 1, 5 do
        local cNum = ((startCave - 1 + i) % 6) + 1
        local o, cf = getCaveChest(cNum)
        if o and cf then return cNum, o, cf end
    end
    return nil, nil, nil
end

updateCaveButtonsUI = function() end

--========================================================================
-- ĐIỀU PHỐI VÀ TỰ ĐỘNG SĂN TRAVELING MERCHANT (CỖ XE THƯƠNG NHÂN DU MỤC)
--========================================================================

getTravelingMerchant = function()
    -- 1. Quét trực tiếp dưới Workspace (con trực tiếp)
    for _, obj in pairs(workspace:GetChildren()) do
        if obj:IsA("Model") and string.find(string.lower(obj.Name), "travelingmerchant") then
            local pad = obj:FindFirstChild("Pad")
            local cf = pad and pad.CFrame or obj:GetPivot()
            local timerText = ""
            local sign = obj:FindFirstChild("Sign")
            if sign then
                for _, tl in pairs(sign:GetDescendants()) do
                    if tl:IsA("TextLabel") and tl.Text ~= "" and string.find(string.lower(tl.Text), "leave") then
                        timerText = tl.Text
                        break
                    end
                end
            end
            return obj, cf, obj.Name, pad, timerText
        end
    end

    -- 2. Quét sâu trong Workspace nếu xe nằm trong thư mục con (Debris/Map/Things...)
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and string.find(string.lower(obj.Name), "travelingmerchant") then
            local pad = obj:FindFirstChild("Pad")
            local cf = pad and pad.CFrame or obj:GetPivot()
            local timerText = ""
            local sign = obj:FindFirstChild("Sign")
            if sign then
                for _, tl in pairs(sign:GetDescendants()) do
                    if tl:IsA("TextLabel") and tl.Text ~= "" and string.find(string.lower(tl.Text), "leave") then
                        timerText = tl.Text
                        break
                    end
                end
            end
            return obj, cf, obj.Name, pad, timerText
        end
    end

    return nil, nil, nil, nil, nil
end

-- ========================================================
-- CÁC HÀM BỔ TRỢ TƯƠNG TÁC GIAO DIỆN TRAVELING MERCHANT
-- ========================================================

local function clickGuiButton(btn)
    if not btn or not (btn:IsA("GuiButton") or btn:IsA("GuiObject")) then return false end

    local absPos = btn.AbsolutePosition
    local absSize = btn.AbsoluteSize
    local centerX = math.floor(absPos.X + (absSize.X / 2))
    local centerY = math.floor(absPos.Y + (absSize.Y / 2))

    -- 1. firesignal (Activated, MouseButton1Click, Down, Up)
    if firesignal then
        pcall(function() firesignal(btn.Activated) end)
        pcall(function() firesignal(btn.MouseButton1Click) end)
        pcall(function() firesignal(btn.MouseButton1Down) end)
        task.wait(0.01)
        pcall(function() firesignal(btn.MouseButton1Up) end)
    end

    -- 2. getconnections
    if getconnections then
        for _, sig in ipairs({"Activated", "MouseButton1Click", "MouseButton1Down"}) do
            pcall(function()
                for _, conn in pairs(getconnections(btn[sig])) do
                    conn:Fire()
                end
            end)
        end
    end

    -- 3. VirtualInputManager (Mouse click tại tọa độ tâm nút)
    if VIM then
        pcall(function()
            VIM:SendMouseButtonEvent(centerX, centerY, 0, true, game, 0)
            task.wait(0.02)
            VIM:SendMouseButtonEvent(centerX, centerY, 0, false, game, 0)
        end)
        -- 4. VirtualInputManager (Touch event cho Android / CloudEmulator)
        pcall(function()
            VIM:SendTouchEvent(1, 0, centerX, centerY)
            task.wait(0.02)
            VIM:SendTouchEvent(1, 2, centerX, centerY)
        end)
    end

    -- 5. VirtualUser click dự phòng
    if VirtualUser then
        pcall(function()
            VirtualUser:Button1Down(Vector2.new(centerX, centerY))
            task.wait(0.02)
            VirtualUser:Button1Up(Vector2.new(centerX, centerY))
        end)
    end

    -- 6. GuiService SelectedObject
    if GuiService then
        pcall(function()
            GuiService.SelectedObject = btn
        end)
    end

    return true
end

local function getGuiText(obj)
    if not obj then return "" end
    if obj:IsA("TextButton") or obj:IsA("TextLabel") or obj:IsA("TextBox") then
        return obj.Text or ""
    end
    for _, ch in ipairs(obj:GetChildren()) do
        if ch:IsA("TextLabel") and ch.Text ~= "" then
            return ch.Text
        end
    end
    return ""
end

local function isMobileControl(desc)
    local cur = desc
    while cur and cur ~= game do
        local n = cur.Name
        if n == "TouchGui" or n == "TouchControlFrame" or n == "DynamicThumbstickFrame" or n == "ControlFrame" then
            return true
        end
        cur = cur.Parent
    end
    return false
end

local function isCloseButton(btn)
    if not btn or not (btn:IsA("TextButton") or btn:IsA("ImageButton")) then return false end
    local btnText = string.lower(getGuiText(btn))
    local btnName = string.lower(btn.Name)
    local bg = btn.BackgroundColor3

    if btnText == "x" or btnText == "✕" or btnText == "x" then
        return true
    end

    if string.find(btnName, "close") or string.find(btnName, "exit") then
        return true
    end

    -- Nút màu đỏ
    if bg.R > 0.65 and bg.G < 0.35 and bg.B < 0.35 then
        return true
    end

    return false
end

local function isCardSoldOut(btn)
    local cur = btn.Parent
    local cardFrame = nil
    local depth = 0
    while cur and cur ~= game and depth < 4 do
        if cur:IsA("GuiObject") then
            -- Thẻ slot riêng lẻ luôn có chiều ngang nhỏ hơn 240px (vì màn hình chia 3 cột)
            if cur.AbsoluteSize.X >= 40 and cur.AbsoluteSize.X <= 240 and cur.AbsoluteSize.Y >= 40 and cur.AbsoluteSize.Y <= 280 then
                cardFrame = cur
                break
            end
        end
        cur = cur.Parent
        depth = depth + 1
    end

    -- Nếu tìm được thẻ slot, chỉ quét con của ĐÚNG thẻ này để xem có chữ "Sold Out" hay không
    if cardFrame then
        for _, desc in ipairs(cardFrame:GetDescendants()) do
            if desc:IsA("TextLabel") and desc.Visible then
                local txt = string.lower(desc.Text or "")
                if string.find(txt, "sold out") then
                    return true
                end
            end
        end
    end

    return false
end

local function findAllMerchantBuyButtons()
    local pGui = Player:FindFirstChild("PlayerGui")
    if not pGui then return {} end

    local buyButtons = {}

    for _, desc in ipairs(pGui:GetDescendants()) do
        if not isMobileControl(desc) and (desc:IsA("TextButton") or desc:IsA("ImageButton")) and desc.Visible then
            local absSize = desc.AbsoluteSize
            -- Kích thước nút bấm mua tiêu chuẩn trong ô thẻ
            if absSize.X >= 30 and absSize.X <= 380 and absSize.Y >= 15 and absSize.Y <= 110 then
                if not isCloseButton(desc) and not isCardSoldOut(desc) then
                    local bg = desc.BackgroundColor3
                    local isGreen = (bg.G > 0.38 and bg.G > bg.R * 1.15 and bg.G > bg.B * 1.15)

                    local txt = getGuiText(desc)
                    local hasPriceText = string.find(txt, "%d") or string.find(string.lower(txt), "k") or string.find(string.lower(txt), "m") or string.find(string.lower(txt), "b")

                    local btnName = string.lower(desc.Name)
                    local isNamedButton = (btnName == "buy" or btnName == "button" or btnName == "action" or string.find(btnName, "slot") or string.find(btnName, "purchase"))

                    local isExcluded = string.find(btnName, "robux") or string.find(string.lower(txt), "r$")

                    if not isExcluded and (isGreen or hasPriceText or isNamedButton) then
                        table.insert(buyButtons, {
                            button = desc,
                            price = txt
                        })
                    end
                end
            end
        end
    end

    return buyButtons
end

local function checkAndConfirmPopup()
    local pGui = Player:FindFirstChild("PlayerGui")
    if not pGui then return false end

    local confirmed = false
    for _, desc in ipairs(pGui:GetDescendants()) do
        if not isMobileControl(desc) and (desc:IsA("TextButton") or desc:IsA("ImageButton")) and desc.Visible then
            local t = string.lower(getGuiText(desc))
            local n = string.lower(desc.Name)
            if t == "yes" or t == "confirm" or t == "đồng ý" or t == "ok" or n == "yes" or n == "confirm" or n == "accept" then
                if not string.find(n, "close") and t ~= "x" then
                    clickGuiButton(desc)
                    confirmed = true
                    task.wait(0.08)
                end
            end
        end
    end
    return confirmed
end

local function closeMerchantShop()
    local pGui = Player:FindFirstChild("PlayerGui")
    if not pGui then return false end

    for _, desc in ipairs(pGui:GetDescendants()) do
        if not isMobileControl(desc) and (desc:IsA("TextButton") or desc:IsA("ImageButton")) and desc.Visible then
            if isCloseButton(desc) then
                local anc = desc.Parent
                local isMerchantClose = false
                local depth = 0
                while anc and anc ~= pGui and depth < 8 do
                    local aName = string.lower(anc.Name)
                    if string.find(aName, "merchant") or string.find(aName, "travel") or string.find(aName, "shop") or string.find(aName, "cart") or string.find(aName, "window") then
                        isMerchantClose = true
                        break
                    end
                    for _, ch in ipairs(anc:GetChildren()) do
                        if ch:IsA("TextLabel") and string.find(string.lower(ch.Text or ""), "merchant") then
                            isMerchantClose = true
                            break
                        end
                    end
                    if isMerchantClose then break end
                    anc = anc.Parent
                    depth = depth + 1
                end

                if isMerchantClose then
                    clickGuiButton(desc)
                    task.wait(0.2)
                    return true
                end
            end
        end
    end

    return false
end

handleTravelingMerchantPurchase = function(merchantObj, padCF)
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp or not merchantObj then return false, "Không tìm thấy nhân vật hoặc cỗ xe!" end

    local prevCF = hrp.CFrame
    local merchantName = merchantObj.Name

    STATE.IsBuyingMerchant = true
    logActivity("MERCHANT", "Phát hiện " .. merchantName .. "! Bắt đầu quy trình tự động mở shop và mua sạch vật phẩm...")
    STATE.CurrentAction = "🛒 Đang mở và mua sạch shop " .. merchantName .. "..."

    local ok, retErr = pcall(function()
        local pad = merchantObj:FindFirstChild("Pad") or merchantObj:FindFirstChildWhichIsA("BasePart")
        local padPos = pad and pad.Position or (padCF and padCF.Position) or merchantObj:GetPivot().Position

        -- 1. Giữ nhân vật cố định trên bục Pad trong 1.5 giây để game mở giao diện shop
        local standCF = CFrame.new(padPos + Vector3.new(0, 1.5, 0))
        for step = 1, 6 do
            if hrp then
                hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                hrp.CFrame = standCF
                if pad and firetouchinterest then
                    pcall(function()
                        firetouchinterest(hrp, pad, 0)
                        task.wait(0.02)
                        firetouchinterest(hrp, pad, 1)
                    end)
                end
            end
            task.wait(0.25)
        end

        logActivity("MERCHANT", "Đã tiếp cận bục Pad thành công. Đang tiến hành mua hàng...")

        -- 2. HÀM GỌI TOÀN BỘ NETWORK REMOTES CHO TẤT CẢ CÁC SLOTS (1 đến 6)
        -- Lưu ý: Merchant_RequestPurchase là RemoteFunction nên CHỈ dùng Invoke/InvokeServer (KHÔNG dùng FireServer)
        local function fireAllPurchaseRemotes()
            if Network and Network.Invoke then
                for slot = 1, 6 do
                    pcall(function()
                        local ok, res = pcall(function()
                            return Network.Invoke("Merchant_RequestPurchase", "TravelingMerchant", slot)
                        end)
                        if ok and res ~= nil then
                            logActivity("MERCHANT", "Remote [TravelingMerchant, Slot " .. slot .. "] -> " .. tostring(res))
                        end
                    end)
                    pcall(function()
                        Network.Invoke("Merchant_RequestPurchase", slot)
                    end)
                    pcall(function()
                        Network.Invoke("TravelingMerchant_RequestPurchase", slot)
                    end)
                    task.wait(0.03)
                end
            end

            pcall(function()
                local netFolder = RS:FindFirstChild("Network")
                if netFolder then
                    local rf = netFolder:FindFirstChild("Merchant_RequestPurchase")
                    if rf and rf:IsA("RemoteFunction") then
                        for slot = 1, 6 do
                            pcall(function() rf:InvokeServer("TravelingMerchant", slot) end)
                            pcall(function() rf:InvokeServer(slot) end)
                            task.wait(0.02)
                        end
                    end
                end
            end)
        end

        -- Đợt remote 1: Mua ngay lập tức bằng RemoteFunction
        fireAllPurchaseRemotes()
        task.wait(0.3)

        -- 3. QUÉT VÀ CLICK TRỰC TIẾP TẤT CẢ NÚT MUA TRÊN GIAO DIỆN MÀN HÌNH (3 ĐỢT)
        for attempt = 1, 3 do
            if hrp then
                hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                hrp.CFrame = standCF
            end

            local buyItems = findAllMerchantBuyButtons()
            if #buyItems > 0 then
                logActivity("MERCHANT", "Tìm thấy " .. #buyItems .. " nút mua trên màn hình (Đợt " .. attempt .. "). Bắt đầu bấm...")
                for idx, item in ipairs(buyItems) do
                    local btn = item.button
                    local priceStr = item.price
                    logActivity("MERCHANT", "Bấm mua món #" .. idx .. (priceStr ~= "" and (" [" .. priceStr .. "]") or "") .. "...")
                    clickGuiButton(btn)
                    task.wait(0.15)
                    checkAndConfirmPopup()
                    task.wait(0.08)
                end
            else
                logActivity("MERCHANT", "Không tìm thấy thêm nút mua nào trên GUI (Đợt " .. attempt .. ").")
            end

            -- Đồng thời gọi lại Network Remotes song song
            fireAllPurchaseRemotes()
            task.wait(0.4)
        end

        -- Chờ giao dịch cuối cùng được server xác nhận
        task.wait(0.6)

        -- 4. TỰ ĐỘNG ĐÓNG BẢNG SHOP (Click nút X đỏ trên giao diện)
        logActivity("MERCHANT", "Hoàn tất các đợt mua! Đang đóng cửa sổ shop...")
        closeMerchantShop()
        task.wait(0.3)
        closeMerchantShop()
        task.wait(0.2)

        -- 5. Teleport trở lại vị trí cũ an toàn
        safeTeleport(prevCF)
        task.wait(0.4)
    end)

    STATE.IsBuyingMerchant = false

    if not ok then
        logActivity("MERCHANT", "Lỗi xử lý shop " .. merchantName .. ": " .. tostring(retErr))
    else
        logActivity("MERCHANT", "Đã hoàn thành phiên mua Traveling Merchant " .. merchantName .. " và quay về vị trí an toàn!")
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "🛒 Traveling Merchant",
                Text = "Đã hoàn thành mua Traveling Merchant và quay lại vị trí!",
                Duration = 4
            })
        end)
    end

    return true, "Đã xử lý Traveling Merchant thành công!"
end

manualBuyTravelingMerchant = function()
    local mObj, mCF, mName, mPad, timerText = getTravelingMerchant()
    if not mObj then
        return false, "Hiện không có Traveling Merchant nào xuất hiện trên server!"
    end
    STATE.LastMerchantName = mName
    STATE.LastMerchantTime = os.time()
    task.spawn(function()
        handleTravelingMerchantPurchase(mObj, mCF)
    end)
    return true, "Đang bay tới " .. mName .. " để mua hàng..."
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

registerConn(UserInputService.InputChanged:Connect(function(input)
    if isDraggingBtn and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStartBtn
        ToggleButton.Position = UDim2.new(startPosBtn.X.Scale, startPosBtn.X.Offset + delta.X, startPosBtn.Y.Scale, startPosBtn.Y.Offset + delta.Y)
    end
end))

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.Size = UDim2.new(0, 520, 0, 375)
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

registerConn(UserInputService.InputChanged:Connect(function(input)
    if isDraggingMain and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStartMain
        MainFrame.Position = UDim2.new(startPosMain.X.Scale, startPosMain.X.Offset + delta.X, startPosMain.Y.Scale, startPosMain.Y.Offset + delta.Y)
    end
end))

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
Sidebar.Size = UDim2.new(0, 130, 1, -42)
Sidebar.Position = UDim2.new(0, 0, 0, 42)
Sidebar.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame

local SidebarLayout = Instance.new("UIListLayout")
SidebarLayout.Padding = UDim.new(0, 4)
SidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
SidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
SidebarLayout.Parent = Sidebar

local SidebarPad = Instance.new("UIPadding")
SidebarPad.PaddingTop = UDim.new(0, 8)
SidebarPad.Parent = Sidebar

local ContentContainer = Instance.new("Frame")
ContentContainer.Size = UDim2.new(1, -140, 1, -50)
ContentContainer.Position = UDim2.new(0, 135, 0, 46)
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
    Page.CanvasSize = UDim2.new(0, 0, 0, 480)
    Page.AutomaticCanvasSize = Enum.AutomaticSize.Y
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
local LogsPage = createPage("Logs")
local SettingsPage = createPage("Settings")

-- HÀNG NÚT ĐIỀU KHIỂN NHANH TRÊN ĐẦU SIDEBAR (RECONNECT + DỪNG TẤT CẢ)
local TopControlFrame = Instance.new("Frame")
TopControlFrame.Name = "ATopControlFrame"
TopControlFrame.Size = UDim2.new(1, -10, 0, 34)
TopControlFrame.BackgroundTransparency = 1
TopControlFrame.LayoutOrder = 1
TopControlFrame.Parent = Sidebar

local btnSidebarReconnect = Instance.new("TextButton")
btnSidebarReconnect.Name = "BtnSidebarReconnect"
btnSidebarReconnect.Size = UDim2.new(0.485, 0, 1, 0)
btnSidebarReconnect.Position = UDim2.new(0, 0, 0, 0)
btnSidebarReconnect.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
btnSidebarReconnect.Text = "🔄 Reconnect"
btnSidebarReconnect.TextColor3 = Color3.fromRGB(255, 255, 255)
btnSidebarReconnect.Font = Enum.Font.GothamBold
btnSidebarReconnect.TextSize = 9
btnSidebarReconnect.Parent = TopControlFrame

local btnReconCorner = Instance.new("UICorner")
btnReconCorner.CornerRadius = UDim.new(0, 8)
btnReconCorner.Parent = btnSidebarReconnect

btnSidebarReconnect.Activated:Connect(function()
    TeleportService:Teleport(game.PlaceId, Player)
end)

local btnStopAll = Instance.new("TextButton")
btnStopAll.Name = "BtnStopAll"
btnStopAll.Size = UDim2.new(0.485, 0, 1, 0)
btnStopAll.Position = UDim2.new(0.515, 0, 0, 0)
btnStopAll.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
btnStopAll.Text = "🛑 Dừng Lại"
btnStopAll.TextColor3 = Color3.fromRGB(255, 255, 255)
btnStopAll.Font = Enum.Font.GothamBold
btnStopAll.TextSize = 9
btnStopAll.Parent = TopControlFrame

local btnStopCorner = Instance.new("UICorner")
btnStopCorner.CornerRadius = UDim.new(0, 8)
btnStopCorner.Parent = btnStopAll

btnStopAll.Activated:Connect(function()
    STATE.IsPaused = not STATE.IsPaused
    if STATE.IsPaused then
        STATE.IsFightingYeti = false
        STATE.IsBuyingMerchant = false
        STATE.CurrentYetiObj = nil
        STATE.IsAttackingCaveChest = false
        STATE.CurrentChestUID = nil
        STATE.CaveHatchActive = false
        STATE.CurrentAction = "🛑 ĐÃ DỪNG TOÀN BỘ HOẠT ĐỘNG (PAUSED)"
        btnStopAll.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
        btnStopAll.Text = "▶️ Tiếp Tục"
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "🛑 Tạm Dừng Toàn Bộ",
                Text = "Đã dừng mọi hoạt động farm, nhân vật đứng yên!",
                Duration = 2.5
            })
        end)
        logActivity("HỆ_THỐNG", "Người dùng đã bấm DỪNG TOÀN BỘ hoạt động.")
    else
        STATE.CurrentAction = "🚀 Đang tiếp tục hoạt động..."
        btnStopAll.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
        btnStopAll.Text = "🛑 Dừng Lại"
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "▶️ Tiếp Tục Hoạt Động",
                Text = "Bot đã tiếp tục tự động farm!",
                Duration = 2.5
            })
        end)
        logActivity("HỆ_THỐNG", "Người dùng đã bấm TIẾP TỤC hoạt động.")
    end
end)

local TabButtons = {}
local tabOrderCounter = 2
local function addTabButton(text, pageName)
    local TabBtn = Instance.new("TextButton")
    TabBtn.Size = UDim2.new(1, -10, 0, 34)
    TabBtn.BackgroundColor3 = Color3.fromRGB(28, 32, 44)
    TabBtn.Text = text
    TabBtn.TextColor3 = Color3.fromRGB(180, 190, 210)
    TabBtn.Font = Enum.Font.GothamMedium
    TabBtn.TextSize = 11
    TabBtn.LayoutOrder = tabOrderCounter
    TabBtn.Parent = Sidebar
    tabOrderCounter = tabOrderCounter + 1

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
        if pageName == "Logs" and updateLogsUI then
            pcall(updateLogsUI)
        end
    end)

    table.insert(TabButtons, TabBtn)
    return TabBtn
end

local btnDash = addTabButton("📊 Tổng Quan", "Dashboard")
addTabButton("👹 Yeti Boss", "Yeti")
addTabButton("⛰️ Hang & Trứng", "Trails")
addTabButton("💰 Bãi Farm Tiền", "Farm")
addTabButton("📜 Nhật Ký", "Logs")
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

local function createTextInput(parent, title, placeholder, defaultVal, callback)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(1, 0, 0, 56)
    Frame.BackgroundColor3 = Color3.fromRGB(24, 28, 40)
    Frame.Parent = parent

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 8)
    Corner.Parent = Frame

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -20, 0, 20)
    Label.Position = UDim2.new(0, 10, 0, 4)
    Label.BackgroundTransparency = 1
    Label.Text = title
    Label.TextColor3 = Color3.fromRGB(210, 215, 230)
    Label.Font = Enum.Font.GothamMedium
    Label.TextSize = 11
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Frame

    local Box = Instance.new("TextBox")
    Box.Size = UDim2.new(1, -20, 0, 24)
    Box.Position = UDim2.new(0, 10, 0, 26)
    Box.BackgroundColor3 = Color3.fromRGB(16, 18, 26)
    Box.TextColor3 = Color3.fromRGB(255, 255, 255)
    Box.PlaceholderColor3 = Color3.fromRGB(120, 125, 140)
    Box.PlaceholderText = placeholder or "Dán vào đây..."
    Box.Text = defaultVal or ""
    Box.Font = Enum.Font.Gotham
    Box.TextSize = 10
    Box.ClearTextOnFocus = false
    Box.Parent = Frame

    local BoxCorner = Instance.new("UICorner")
    BoxCorner.CornerRadius = UDim.new(0, 5)
    BoxCorner.Parent = Box

    local BoxStroke = Instance.new("UIStroke")
    BoxStroke.Color = Color3.fromRGB(45, 55, 80)
    BoxStroke.Thickness = 1
    BoxStroke.Parent = Box

    Box.FocusLost:Connect(function(enterPressed)
        if callback then
            callback(Box.Text)
        end
    end)

    return Box
end

-- TRANG 1: DASHBOARD
lblAction = createInfoCard(DashboardPage, "⚡ Hoạt Động:", STATE.CurrentAction)
lblCaveTimer = createInfoCard(DashboardPage, "⏳ Thời Gian Mở Hang:", "Đang quét...")
lblYetiStatus = createInfoCard(DashboardPage, "👹 Tình Trạng Yeti:", STATE.YetiStatusText)
lblYetiCount = createInfoCard(DashboardPage, "🏆 Số Yeti Đã Diệt:", "0 con")
lblHatchedEggs = createInfoCard(DashboardPage, "🥚 Số Trứng Đã Mở:", "0 quả")
lblDiamonds = createInfoCard(DashboardPage, "💎 Kim Cương:", "Đang tải...")
lblDiffDiamonds = createInfoCard(DashboardPage, "📈 Cày Được:", "+0 (+0/h)")
lblUptime = createInfoCard(DashboardPage, "⏱️ Thời Gian Treo:", "00h 00m 00s")
lblPets = createInfoCard(DashboardPage, "🐾 Huge / Titanic:", "0 / 0")

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

-- TRANG 3: HANG NÚI & TRỨNG
local lblSelectedEgg = createInfoCard(TrailsPage, "🥚 Trứng Đã Chọn:", STATE.SelectedEggName)
local lblCaveTimerTrails = createInfoCard(TrailsPage, "⏳ Thời Gian Mở Hang:", "Đang quét...")

createActionButton(TrailsPage, "🔍 Quét Quả Trứng Đang Đứng Trước Mặt", Color3.fromRGB(40, 160, 120), function()
    local eggObj, eggCF, eggId = getCaveEggModel(STATE.SelectedCave)
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
                            local aId = egg:GetAttribute("DM_EggId")
                            if aId and tostring(aId) ~= "" then
                                found = tostring(aId)
                            elseif not string.match(egg.Name, "^[0-9a-fA-F]{20,}$") then
                                found = egg.Name
                            elseif CAVE_DEFAULT_EGGS[STATE.SelectedCave] then
                                found = CAVE_DEFAULT_EGGS[STATE.SelectedCave]
                            end
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
local btnResetOne = nil

for i = 1, 6 do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 36, 0, 26)
    btn.Position = UDim2.new(0, 80 + (i - 1) * 42, 0.5, -13)
    btn.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
    btn.Text = "H" .. i
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.Parent = CaveSelectorFrame

    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(0, 6)
    bCorner.Parent = btn

    btn.Activated:Connect(function()
        if not STATE.SelectedCaves or type(STATE.SelectedCaves) ~= "table" then
            STATE.SelectedCaves = { [STATE.SelectedCave or 1] = true }
        end
        local isCurrentlySelected = (STATE.SelectedCaves[i] == true)
        if isCurrentlySelected then
            local count = 0
            for idx = 1, 6 do
                if STATE.SelectedCaves[idx] then count = count + 1 end
            end
            if count > 1 then
                STATE.SelectedCaves[i] = false
                if STATE.SelectedCave == i then
                    local remList = getSelectedCavesList()
                    STATE.SelectedCave = remList[1] or 1
                end
            else
                pcall(function()
                    StarterGui:SetCore("SendNotification", {
                        Title = "⚠️ Lưu Ý",
                        Text = "Cần giữ ít nhất 1 hang được chọn!",
                        Duration = 2
                    })
                end)
            end
        else
            STATE.SelectedCaves[i] = true
            STATE.SelectedCave = i
        end
        if updateCaveButtonsUI then updateCaveButtonsUI() end
        saveConfig()
    end)
    table.insert(caveButtons, btn)
end

lblSelectedCaves = createInfoCard(TrailsPage, "⛰️ Danh Sách Mở Lần Lượt:", formatSelectedCavesText())

local QuickSelectFrame = Instance.new("Frame")
QuickSelectFrame.Size = UDim2.new(1, 0, 0, 30)
QuickSelectFrame.BackgroundTransparency = 1
QuickSelectFrame.Parent = TrailsPage

local btnSelectAll = Instance.new("TextButton")
btnSelectAll.Size = UDim2.new(0.485, 0, 1, 0)
btnSelectAll.Position = UDim2.new(0, 0, 0, 0)
btnSelectAll.BackgroundColor3 = Color3.fromRGB(40, 100, 180)
btnSelectAll.Text = "⭐ Chọn Toàn Bộ H1 - H6"
btnSelectAll.TextColor3 = Color3.fromRGB(255, 255, 255)
btnSelectAll.Font = Enum.Font.GothamBold
btnSelectAll.TextSize = 10
btnSelectAll.Parent = QuickSelectFrame
local c1 = Instance.new("UICorner") c1.CornerRadius = UDim.new(0, 6) c1.Parent = btnSelectAll

btnResetOne = Instance.new("TextButton")
btnResetOne.Size = UDim2.new(0.485, 0, 1, 0)
btnResetOne.Position = UDim2.new(0.515, 0, 0, 0)
btnResetOne.BackgroundColor3 = Color3.fromRGB(60, 65, 80)
btnResetOne.Text = "🎯 Chỉ Chọn Hang " .. tostring(STATE.SelectedCave)
btnResetOne.TextColor3 = Color3.fromRGB(255, 255, 255)
btnResetOne.Font = Enum.Font.GothamBold
btnResetOne.TextSize = 10
btnResetOne.Parent = QuickSelectFrame
local c2 = Instance.new("UICorner") c2.CornerRadius = UDim.new(0, 6) c2.Parent = btnResetOne

btnSelectAll.Activated:Connect(function()
    for idx = 1, 6 do
        STATE.SelectedCaves[idx] = true
    end
    if updateCaveButtonsUI then updateCaveButtonsUI() end
    saveConfig()
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "⭐ Đã Chọn Toàn Bộ",
            Text = "Bot sẽ mở lần lượt từ Hang 1 đến Hang 6!",
            Duration = 2.5
        })
    end)
end)

btnResetOne.Activated:Connect(function()
    local cur = STATE.SelectedCave or 1
    for idx = 1, 6 do
        STATE.SelectedCaves[idx] = (idx == cur)
    end
    if updateCaveButtonsUI then updateCaveButtonsUI() end
    saveConfig()
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "🎯 Đã Chọn 1 Hang",
            Text = "Chỉ mở duy nhất Hang " .. cur .. "!",
            Duration = 2.5
        })
    end)
end)

updateCaveButtonsUI = function()
    if caveButtons and #caveButtons == 6 then
        for idx, b in ipairs(caveButtons) do
            local isSelected = STATE.SelectedCaves and STATE.SelectedCaves[idx]
            local isCurrent = (STATE.SelectedCave == idx)
            if isCurrent then
                b.BackgroundColor3 = Color3.fromRGB(0, 160, 255)
                b.Text = "★H" .. idx
            elseif isSelected then
                b.BackgroundColor3 = Color3.fromRGB(45, 90, 180)
                b.Text = "✓H" .. idx
            else
                b.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
                b.Text = "H" .. idx
            end
        end
    end
    if lblSelectedCaves then
        lblSelectedCaves.Text = formatSelectedCavesText()
    end
    if btnResetOne then
        btnResetOne.Text = "🎯 Chỉ Chọn Hang " .. tostring(STATE.SelectedCave)
    end
    local _, _, eggId = getCaveEggModel(STATE.SelectedCave)
    if eggId then
        STATE.SelectedEggName = eggId
        if lblSelectedEgg then lblSelectedEgg.Text = "Hang " .. STATE.SelectedCave .. ": " .. eggId end
    else
        if lblSelectedEgg then lblSelectedEgg.Text = "Hang " .. STATE.SelectedCave .. " (Tự quét khi vào)" end
    end
    local countdownStr = getCaveOpenCountdown(STATE.SelectedCave)
    if lblCaveTimer then lblCaveTimer.Text = countdownStr end
    if lblCaveTimerTrails then lblCaveTimerTrails.Text = countdownStr end
end
updateCaveButtonsUI()

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
        local _, eggCF = getCaveEggModel(STATE.SelectedCave)
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
createToggle(TrailsPage, "🥚 Auto Mở Trứng (Auto Hatch Egg)", STATE.AutoHatch, function(v)
    STATE.AutoHatch = v
    if not v then
        STATE.CaveHatchActive = false
    end
end)
createToggle(TrailsPage, "🔥 Mở Trứng Tối Đa (Max " .. getMaxHatchAmount() .. " Quả / Lần)", STATE.AutoMaxHatch, function(v)
    STATE.AutoMaxHatch = v
    saveConfig()
end)
createActionButton(TrailsPage, "🔄 Đặt Lại Chu Kỳ Toàn Bộ Hang Đang Chọn", Color3.fromRGB(160, 90, 40), function()
    for idx = 1, 6 do
        STATE.CaveHatchedForThisCycle[idx] = false
    end
    STATE.CaveHatchActive = false
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "🔄 Đặt Lại Chu Kỳ",
            Text = "Đã đặt lại chu kỳ cho toàn bộ các Hang (" .. formatSelectedCavesText() .. ")!",
            Duration = 3
        })
    end)
    logActivity("MỞ_TRỨNG", "Người dùng đã thủ công đặt lại chu kỳ mở trứng cho các Hang (" .. formatSelectedCavesText() .. ").")
end)
createToggle(TrailsPage, "🎁 Hiện Pop-up Kết Quả (Tự đóng sau 1.2s)", STATE.ShowHatchPopup, function(v) STATE.ShowHatchPopup = v end)
createToggle(TrailsPage, "⏩ Bỏ Qua Cắt Cảnh (Skip Cutscene Animation)", STATE.SkipAnimation, function(v)
    STATE.SkipAnimation = v
    saveConfig()
    if v and handleEggOpeningVisuals then handleEggOpeningVisuals() end
end)
createToggle(TrailsPage, "🛒 Auto Săn Traveling Merchant (TP & Mua Sạch)", STATE.AutoTravelingMerchant, function(v)
    STATE.AutoTravelingMerchant = v
    saveConfig()
end)
createActionButton(TrailsPage, "⚡ TP & Mua Sạch Traveling Merchant Ngay (Thủ công)", Color3.fromRGB(180, 90, 40), function()
    local ok, msg = manualBuyTravelingMerchant()
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = ok and "🛒 Traveling Merchant" or "⚠️ Không Tìm Thấy",
            Text = msg,
            Duration = 3
        })
    end)
end)

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

-- TRANG 5: NHẬT KÝ HOẠT ĐỘNG & BẮT LỖI (ACTIVITY & ERROR LOGS)
createActionButton(LogsPage, "📋 Sao Chép Toàn Bộ Log (Clipboard)", Color3.fromRGB(40, 140, 90), function()
    local text = #ACTIVITY_LOGS > 0 and table.concat(ACTIVITY_LOGS, "\n") or "[Trống - Chưa có nhật ký]"
    local copied = false
    if setclipboard then
        pcall(function() setclipboard(text) copied = true end)
    elseif toclipboard then
        pcall(function() toclipboard(text) copied = true end)
    end
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = copied and "📋 Đã Sao Chép Log" or "⚠️ Không Thể Copy",
            Text = copied and ("Đã sao chép " .. #ACTIVITY_LOGS .. " dòng nhật ký vào clipboard!") or "Executor không hỗ trợ hàm setclipboard.",
            Duration = 3
        })
    end)
end)

createActionButton(LogsPage, "📤 Gửi Nhật Ký Về Discord Webhook", Color3.fromRGB(80, 100, 160), function()
    if not STATE.Webhook or STATE.Webhook == "" then
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "⚠️ Chưa Có Webhook",
                Text = "Vui lòng nhập link Discord Webhook ở tab Cài Đặt AFK!",
                Duration = 3
            })
        end)
        return
    end
    local count = #ACTIVITY_LOGS
    if count == 0 then
        sendWebhook("📜 BÁO CÁO NHẬT KÝ", "*(Chưa có nhật ký nào được ghi)*", 3447003)
        return
    end

    local chunk = {}
    local startIdx = math.max(1, count - 35)
    for i = startIdx, count do
        table.insert(chunk, ACTIVITY_LOGS[i])
    end
    local logText = "```text\n" .. table.concat(chunk, "\n") .. "\n```"
    sendWebhook("📜 BÁO CÁO NHẬT KÝ HOẠT ĐỘNG", "Tài khoản: **" .. Player.Name .. "**\nTổng số dòng: `" .. count .. "`\n" .. logText, 3447003)

    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "📤 Đã Gửi Log Discord",
            Text = "Đã gửi " .. #chunk .. " dòng nhật ký gần nhất về Discord!",
            Duration = 3
        })
    end)
end)

createActionButton(LogsPage, "🗑️ Xóa Sạch Nhật Ký", Color3.fromRGB(180, 60, 60), function()
    ACTIVITY_LOGS = {}
    pcall(function()
        if writefile then writefile(LOG_FILE, "") end
    end)
    if updateLogsUI then updateLogsUI() end
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "🗑️ Đã Xóa Nhật Ký",
            Text = "Đã dọn sạch toàn bộ nhật ký trong bộ nhớ và file log.",
            Duration = 2.5
        })
    end)
end)

local ConsoleFrame = Instance.new("Frame")
ConsoleFrame.Name = "ConsoleFrame"
ConsoleFrame.Size = UDim2.new(1, 0, 0, 240)
ConsoleFrame.BackgroundColor3 = Color3.fromRGB(14, 16, 24)
ConsoleFrame.Parent = LogsPage

local ConsoleCorner = Instance.new("UICorner")
ConsoleCorner.CornerRadius = UDim.new(0, 8)
ConsoleCorner.Parent = ConsoleFrame

local ConsoleStroke = Instance.new("UIStroke")
ConsoleStroke.Color = Color3.fromRGB(45, 55, 80)
ConsoleStroke.Thickness = 1
ConsoleStroke.Parent = ConsoleFrame

local ConsoleScroll = Instance.new("ScrollingFrame")
ConsoleScroll.Name = "ConsoleScroll"
ConsoleScroll.Size = UDim2.new(1, -12, 1, -12)
ConsoleScroll.Position = UDim2.new(0, 6, 0, 6)
ConsoleScroll.BackgroundTransparency = 1
ConsoleScroll.ScrollBarThickness = 4
ConsoleScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 140, 255)
ConsoleScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
ConsoleScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
ConsoleScroll.Parent = ConsoleFrame

local logDisplayLabel = Instance.new("TextLabel")
logDisplayLabel.Name = "LogDisplayLabel"
logDisplayLabel.Size = UDim2.new(1, -4, 0, 0)
logDisplayLabel.AutomaticSize = Enum.AutomaticSize.Y
logDisplayLabel.BackgroundTransparency = 1
logDisplayLabel.Font = Enum.Font.Code
logDisplayLabel.TextSize = 10
logDisplayLabel.TextColor3 = Color3.fromRGB(200, 215, 235)
logDisplayLabel.TextXAlignment = Enum.TextXAlignment.Left
logDisplayLabel.TextYAlignment = Enum.TextYAlignment.Top
logDisplayLabel.TextWrapped = true
logDisplayLabel.Text = "[HỆ THỐNG] Đang chờ sự kiện hoạt động..."
logDisplayLabel.Parent = ConsoleScroll

updateLogsUI = function()
    if not logDisplayLabel or not logDisplayLabel.Parent then return end
    local count = #ACTIVITY_LOGS
    if count == 0 then
        logDisplayLabel.Text = "[HỆ THỐNG] (Chưa có nhật ký nào được ghi nhận)"
        return
    end
    local maxDisplay = 50
    local startIdx = math.max(1, count - maxDisplay + 1)
    local lines = {}
    for i = startIdx, count do
        table.insert(lines, ACTIVITY_LOGS[i])
    end
    logDisplayLabel.Text = table.concat(lines, "\n")
    pcall(function()
        ConsoleScroll.CanvasPosition = Vector2.new(0, 999999)
    end)
end

-- TRANG 6: CÀI ĐẶT
local webhookBox = createTextInput(SettingsPage, "🔗 Discord Webhook URL (Bảo mật - Tự lưu vào máy):", "Dán link Webhook vào đây...", STATE.Webhook, function(v)
    STATE.Webhook = v
    saveConfig()
end)

local userBox = createTextInput(SettingsPage, "👤 Discord User ID (Tag cá nhân khi trúng Huge):", "Ví dụ: 123456789012345678 (hoặc để trống)", STATE.DiscordUserId, function(v)
    STATE.DiscordUserId = v
    saveConfig()
end)

createActionButton(SettingsPage, "💾 Lưu Cấu Hình Webhook Ngay", Color3.fromRGB(40, 140, 90), function()
    if webhookBox then STATE.Webhook = webhookBox.Text end
    if userBox then STATE.DiscordUserId = userBox.Text end
    saveConfig()
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "✅ Đã Lưu Webhook",
            Text = "Đã lưu Webhook vào file cấu hình trên máy thành công!",
            Duration = 3
        })
    end)
end)

createToggle(SettingsPage, "🛡️ Anti-AFK (Chống văng 20 phút)", STATE.AntiAFK, function(v)
    STATE.AntiAFK = v
    if v then disableIdledConnections() end
end)
createToggle(SettingsPage, "🔄 Auto Reconnect Khi Đứt Mạng", STATE.AutoReconnect, function(v) STATE.AutoReconnect = v end)
createToggle(SettingsPage, "🔔 Báo Webhook Khi Mở/Execute Script", STATE.ExecuteAlert, function(v) STATE.ExecuteAlert = v saveConfig() end)
createToggle(SettingsPage, "🟣 Báo Webhook Khi Trúng Huge / Titanic", STATE.NotifyOnHuge, function(v) STATE.NotifyOnHuge = v saveConfig() end)
createToggle(SettingsPage, "📢 Tag @everyone Khi Trúng Huge", STATE.MentionOnHuge, function(v) STATE.MentionOnHuge = v STATE.MentionOnTitanic = v saveConfig() end)
createToggle(SettingsPage, "📊 Báo Cáo Định Kỳ 15 Phút Về Discord", STATE.PeriodicReport, function(v) STATE.PeriodicReport = v saveConfig() end)
createToggle(SettingsPage, "🧲 Auto Hút Orbs & Nhặt Lootbags", STATE.AutoCollectDrops, function(v) STATE.AutoCollectDrops = v end)
createToggle(SettingsPage, "🏆 Auto Nhận Expeditions Đỉnh Núi", STATE.AutoClaimExpeditions, function(v) STATE.AutoClaimExpeditions = v end)
createToggle(SettingsPage, "🔋 Low CPU Mode (Màn Đen Tiết Kiệm Pin)", STATE.LowCpuMode, function(v)
    STATE.LowCpuMode = v
    pcall(function() RunService:Set3dRenderingEnabled(not v) end)
end)

-- NÚT TEST THỬ WEBHOOK BÁO HUGE
createActionButton(SettingsPage, "🧪 Test Thử Webhook Báo Huge", Color3.fromRGB(130, 80, 200), function()
    pcall(function()
        if triggerRarePetAlert then
            triggerRarePetAlert({
                id = "Huge Summit Ice Dragon [TEST]",
                pt = 2,
                sh = true,
                _un = 1234,
                _am = 1
            }, 1)
        end
    end)
end)

-- NÚT DUMP LOG DEBUG
createActionButton(SettingsPage, "📋 Quét & Gửi Log Debug Về Discord", Color3.fromRGB(40, 160, 120), function()
    pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/Vt47/ps99-scripts/main/dump_info.lua"))()
    end)
end)

pcall(function()
    registerConn(UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.KeyCode == Enum.KeyCode.RightShift then toggleGui() end
    end))
end)

--========================================================================
-- HỆ THỐNG XỬ LÝ NGẦM CHUYÊN SÂU
--========================================================================

task.spawn(function()
    pcall(function()
        if not Library then Library = RS:FindFirstChild("Library") or RS:WaitForChild("Library", 8) end
        if Library then
            if not Client then Client = Library:FindFirstChild("Client") end
            if not Directory then Directory = Library:FindFirstChild("Directory") end
            if not Save and Client and Client:FindFirstChild("Save") then Save = require(Client.Save) end
            if not PetDirectory and Directory and Directory:FindFirstChild("Pets") then PetDirectory = require(Directory.Pets) end
            if not Network and Client and Client:FindFirstChild("Network") then Network = require(Client.Network) end
            if not EggCmds and Client and Client:FindFirstChild("EggCmds") then EggCmds = require(Client.EggCmds) end
        end
    end)
    if not Network and RS:FindFirstChild("Network") then Network = RS.Network end

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
        -- 1. Quét PlayerGui trước xem có banner đếm ngược Yeti Cooldown hay không
        -- Nếu đang có thông báo đếm ngược -> Yeti CHẮC CHẮN chưa hồi sinh / đang cooldown
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
                        -- A. Cooldown Yeti thật ("The Yeti returns in 4:04", "You can fight the Yeti again in 4:04")
                        if string.find(t, "yeti") and (string.find(t, "returns in") or string.find(t, "again in") or string.find(t, "respawn in") or string.find(t, "next yeti") or string.find(t, "fight the yeti again")) then
                            isCooldown = true
                            cdString = string.match(g.Text, "%d+:%d+") or g.Text
                            break
                        end

                        -- B. Nhận diện Yeti Boss Đang Giao Tranh
                        if (pName == "Yeti" or string.find(string.lower(pName), "yeti")) and (string.find(t, "damage") or string.find(t, "yeti"))
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

        -- 2. Kiểm tra Breakables thực tế trong workspace.__THINGS.Breakables
        local Things = workspace:FindFirstChild("__THINGS")
        local Breakables = Things and Things:FindFirstChild("Breakables")
        if Breakables then
            -- Quét BreakableID / AreaID có chữ "yeti"
            for _, b in pairs(Breakables:GetChildren()) do
                local bId = string.lower(tostring(b:GetAttribute("BreakableID") or ""))
                local areaId = string.lower(tostring(b:GetAttribute("AreaID") or ""))
                if string.find(bId, "yeti") or string.find(areaId, "yeti") then
                    local part = b:IsA("BasePart") and b or (b:IsA("Model") and (b.PrimaryPart or b:FindFirstChildWhichIsA("BasePart", true)))
                    if part then
                        return b, part.CFrame, nil
                    elseif STATE.YetiArenaCFrame then
                        return b, STATE.YetiArenaCFrame, nil
                    end
                end
            end

            -- Quét mọi Breakables nằm trong bán kính 100 studs quanh đấu trường Yeti (đỉnh Diamond Mountain)
            if STATE.YetiArenaCFrame then
                for _, b in pairs(Breakables:GetChildren()) do
                    local part = b:IsA("BasePart") and b or (b:IsA("Model") and (b.PrimaryPart or b:FindFirstChildWhichIsA("BasePart", true)))
                    if part and (part.Position - STATE.YetiArenaCFrame.Position).Magnitude < 100 then
                        return b, part.CFrame, nil
                    end
                end
            end
        end

        -- 3. Nếu trên màn hình có thanh máu giao tranh (The Golden Yeti / The Shiny Yeti / Parent Yeti):
        if isBossActiveGui and STATE.YetiArenaCFrame then
            return "YetiActiveFromGui", STATE.YetiArenaCFrame, nil
        end

        -- 4. Kiểm tra Model Boss trong Workspace (LOẠI BỎ Leaderboard, tượng, pet)
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
    local yetiMissingChecks = 0
    task.spawn(function()
        while _G.PS99_SUMMIT_RUNNING and _G.PS99_SUMMIT_SESSION == CURRENT_SESSION_ID do
            task.wait(0.4)
            if not STATE.IsPaused and STATE.AutoYeti then
                local yetiObj, yetiPos, cdTimer = checkYetiBoss()

                if yetiObj and yetiPos then
                    yetiMissingChecks = 0
                    STATE.YetiStatusText = "🔥 Đang Sống!"
                    STATE.CurrentYetiObj = yetiObj

                    -- Ưu tiên Yeti Boss, NHƯNG nếu đang trong hang mở trứng, rương hoặc mua Traveling Merchant thì không ngắt quãng
                    local inCaveSession = (STATE.CaveHatchActive and STATE.AutoHatch) or (STATE.IsAttackingCaveChest and STATE.AutoCaveChests) or STATE.IsBuyingMerchant
                    if not inCaveSession and not STATE.IsFightingYeti then
                        STATE.IsFightingYeti = true
                        STATE.CurrentAction = "⚔️ Đang săn Yeti Boss!"
                        logActivity("YETI_BOSS", "Phát hiện Yeti Boss xuất hiện! Dịch chuyển lên đỉnh núi tấn công...")
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

                    -- XÁC NHẬN YETI ĐÃ CHẾT: Cần có cooldown timer trên màn hình HOẶC quét vắng mặt >= 5 lần liên tiếp (~2s)
                    if STATE.IsFightingYeti then
                        yetiMissingChecks = yetiMissingChecks + 1
                        local isConfirmedDead = (cdTimer ~= nil) or (yetiMissingChecks >= 5)

                        if isConfirmedDead then
                            yetiMissingChecks = 0
                            STATE.IsFightingYeti = false
                            STATE.YetiKilledCount = STATE.YetiKilledCount + 1
                            STATE.CurrentAction = "🏆 Yeti đã bị hạ gục!"
                            logActivity("YETI_BOSS", "Đã hạ gục Yeti Boss thành công! Tổng số đã diệt: " .. STATE.YetiKilledCount .. " con.")

                            if STATE.YetiCooldownAlert then
                                sendWebhook(
                                    "💥 ĐÃ HẠ GỤC YETI BOSS!",
                                    "Tài khoản **" .. Player.Name .. "** đã tiêu diệt Yeti thành công!\n**Tổng số Yeti:** `" .. STATE.YetiKilledCount .. " con`",
                                    16766720
                                )
                            end

                            task.wait(1.0)

                            if STATE.CaveHatchActive and STATE.CaveHatchEggCF and isEggUnlocked(STATE.CaveHatchEggObj) then
                                safeTeleport(STATE.CaveHatchEggCF)
                                STATE.CurrentAction = "🚀 Quay lại tiếp tục mở trứng Hang " .. STATE.CaveHatchCaveNum
                            else
                                if STATE.CaveHatchActive then
                                    STATE.CaveHatchActive = false
                                    if STATE.CaveHatchedForThisCycle then
                                        STATE.CaveHatchedForThisCycle[STATE.CaveHatchCaveNum] = true
                                    end
                                end
                                if STATE.AutoCaveChests or STATE.AutoHatch then
                                    if getBestActiveCave then
                                        local bestCave = getBestActiveCave()
                                        if bestCave then STATE.SelectedCave = bestCave end
                                    end
                                    local cObj, cCF = getCaveChest(STATE.SelectedCave)
                                    if cObj and cCF and STATE.AutoCaveChests then
                                        safeTeleport(cCF)
                                        STATE.CurrentAction = "🚀 Quay lại phá Rương Hang " .. STATE.SelectedCave
                                    else
                                        local isOpen, phase, obj, cf = isCaveOpen(STATE.SelectedCave)
                                        if isOpen and cf then
                                            safeTeleport(cf)
                                            STATE.CurrentAction = "🚀 Quay lại Hang " .. STATE.SelectedCave
                                        elseif STATE.FarmCFrame then
                                            safeTeleport(STATE.FarmCFrame)
                                            local cavesStr = formatSelectedCavesText and formatSelectedCavesText() or ("Hang " .. STATE.SelectedCave)
                                            STATE.CurrentAction = "⏳ Các Hang (" .. cavesStr .. ") chưa mở / đang cooldown. Về bãi farm tiền..."
                                        end
                                    end
                                elseif STATE.FarmCFrame then
                                    safeTeleport(STATE.FarmCFrame)
                                    STATE.CurrentAction = "💰 Về Bãi Farm an toàn"
                                end
                            end
                        else
                            -- Vẫn đang trong trận đánh: Không được teleport hay rời sàn đấu!
                            STATE.CurrentAction = "⚔️ Đang tiêu diệt Yeti Boss..."
                        end
                    else
                        yetiMissingChecks = 0
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

        local eggObj, eggCF, eggId = getCaveEggModel(STATE.SelectedCave)
        if eggId then
            STATE.SelectedEggName = eggId
            return eggId, eggObj
        end

        return nil, nil
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

    -- ========================================================
    -- RADAR QUÉT KHO & PHÁT HIỆN THÚ CƯNG HIẾM (HUGE / TITANIC / GARGANTUAN)
    -- ========================================================
    local previousPetSnapshot = {}
    local isPetBaselineReady = false

    local function makePetSnapshot()
        local snapshot = {}
        if not Save or not Save.Get then return snapshot end
        pcall(function()
            local s = Save.Get()
            if s and s.Inventory and s.Inventory.Pet then
                for uid, pet in pairs(s.Inventory.Pet) do
                    snapshot[tostring(uid)] = {
                        id = pet.id,
                        pt = pet.pt,
                        sh = pet.sh,
                        golden = pet.golden,
                        rainbow = pet.rainbow,
                        shiny = pet.shiny,
                        sn = pet.sn or pet._un,
                        _am = tonumber(pet._am) or 1
                    }
                end
            end
        end)
        return snapshot
    end

    -- Vòng lặp radar quét kho thời gian thực (chu kỳ 1.0 giây)
    task.spawn(function()
        local baselineWaitCount = 0
        while _G.PS99_SUMMIT_RUNNING and _G.PS99_SUMMIT_SESSION == CURRENT_SESSION_ID do
            task.wait(1.0)

            local currentSnapshot = makePetSnapshot()
            if not isPetBaselineReady then
                baselineWaitCount = baselineWaitCount + 1
                -- Chốt danh sách pet đang có sẵn trong túi để không báo ảo
                if next(currentSnapshot) ~= nil or baselineWaitCount >= 4 then
                    previousPetSnapshot = currentSnapshot
                    isPetBaselineReady = true
                    local initialCount = 0
                    for _ in pairs(currentSnapshot) do initialCount = initialCount + 1 end
                    logActivity("THEO_DÕI_PET", "Radar thú cưng kích hoạt thành công! Đã nạp " .. initialCount .. " pet sẵn có trong kho. Sẵn sàng thông báo Huge/Titanic mới.")
                end
            else
                for uid, currentPet in pairs(currentSnapshot) do
                    local oldPet = previousPetSnapshot[uid]
                    if not oldPet then
                        -- Thú cưng hoàn toàn mới vừa xuất hiện trong kho!
                        local cat = getPetCategory(currentPet.id)
                        if cat then
                            triggerRarePetAlert(currentPet, currentPet._am or 1)
                        end
                    else
                        local increase = (currentPet._am or 1) - (oldPet._am or 1)
                        if increase > 0 then
                            -- Thú cưng tăng thêm số lượng
                            local cat = getPetCategory(currentPet.id)
                            if cat then
                                triggerRarePetAlert(currentPet, increase)
                            end
                        end
                    end
                end
                previousPetSnapshot = currentSnapshot
            end
        end
    end)

    -- BÁO CÁO THỐNG KÊ ĐỊNH KỲ VỀ DISCORD MỖI 15 PHÚT
    task.spawn(function()
        local lastReportTime = os.time()
        while _G.PS99_SUMMIT_RUNNING and _G.PS99_SUMMIT_SESSION == CURRENT_SESSION_ID do
            task.wait(10)
            if STATE.PeriodicReport and (os.time() - lastReportTime >= (STATE.ReportInterval or 900)) then
                lastReportTime = os.time()
                pcall(function()
                    local elapsed = math.max(1, os.time() - (STATE.SessionStart or os.time()))
                    local curD = getDiamonds()
                    local diff = curD - (STATE.StartingDiamonds or curD)
                    local rate = math.floor((diff / elapsed) * 3600)

                    local fps = 60
                    pcall(function() fps = math.floor(1 / math.max(0.001, RunService.RenderStepped:Wait())) end)
                    local ping = 0
                    pcall(function()
                        local ssi = game:GetService("Stats"):FindFirstChild("Network") and game:GetService("Stats").Network:FindFirstChild("ServerStatsItem")
                        local pi = ssi and ssi:FindFirstChild("Data Ping")
                        if pi then ping = math.floor(pi:GetValue()) end
                    end)

                    local repFields = {
                        {
                            name = "💎 Kim Cương (Diamonds)",
                            value = "Bắt đầu: `" .. formatNumber(STATE.StartingDiamonds or 0) .. "`\nHiện tại: `" .. formatNumber(curD) .. "`\nKiếm được: `" .. (diff >= 0 and "+" or "") .. formatNumber(diff) .. "`\n⚡ Tốc độ: `" .. formatNumber(rate) .. "/h`",
                            inline = false
                        },
                        {
                            name = "🐾 Thống Kê Thú Cưng Quý (Phiên Này)",
                            value = "🟣 Huge: **" .. STATE.TotalHuge .. "**\n🔴 Titanic: **" .. STATE.TotalTitanic .. "**\n🟡 Gargantuan: **" .. STATE.TotalGargantuan .. "**\n📦 Trứng đã mở: **" .. formatNumber(STATE.TotalHatchedEggs) .. "** quả",
                            inline = false
                        },
                        {
                            name = "⚙️ Trạng Thái Hoạt Động",
                            value = "⏱️ Thời gian treo: `" .. formatDuration(elapsed) .. "`\n🎯 Hành động: `" .. tostring(STATE.CurrentAction) .. "`\n📶 Ping: `" .. ping .. " ms` | 🖥️ FPS: `" .. fps .. "`\n🔋 Low CPU Mode: `" .. (STATE.LowCpuMode and "BẬT" or "TẮT") .. "`",
                            inline = false
                        }
                    }

                    sendWebhook(
                        "📊 BÁO CÁO ĐỊNH KỲ 15 PHÚT - PS99 SUMMIT SUITE",
                        "Tiến trình AFK tự động tại khu vực **Diamond Mountain** của tài khoản **" .. Player.Name .. "**.",
                        3447003,
                        nil,
                        repFields
                    )
                end)
            end
        end
    end)

    -- XỬ LÝ POP-UP VÀ BỎ QUA TOÀN BỘ CẮT CẢNH MỞ TRỨNG (ANIMATION BYPASS)
    handleEggOpeningVisuals = function()
        pcall(function()
            if STATE.SkipAnimation then
                -- 1. Hook / Override ModuleScript 'Egg Opening Frontend'
                local ps = Player:FindFirstChild("PlayerScripts")
                local eggFrontend = ps and (
                    (ps:FindFirstChild("Scripts") and ps.Scripts:FindFirstChild("Game") and ps.Scripts.Game:FindFirstChild("Egg Opening Frontend"))
                    or ps:FindFirstChild("Egg Opening Frontend", true)
                )

                if eggFrontend then
                    -- Phương pháp A: getsenv
                    if getsenv then
                        pcall(function()
                            local env = getsenv(eggFrontend)
                            if env then
                                if env.PlayEggAnimation then
                                    if hookfunction then
                                        pcall(function() hookfunction(env.PlayEggAnimation, function(...) return end) end)
                                    end
                                    env.PlayEggAnimation = function(...) return end
                                end
                                if env.PlayAnimation then
                                    if hookfunction then
                                        pcall(function() hookfunction(env.PlayAnimation, function(...) return end) end)
                                    end
                                    env.PlayAnimation = function(...) return end
                                end
                                if env.Hatch then env.Hatch = function(...) return end end
                                if env.OpenEgg then env.OpenEgg = function(...) return end end
                            end
                        end)
                    end
                    -- Phương pháp B: require
                    pcall(function()
                        local mod = require(eggFrontend)
                        if typeof(mod) == "table" then
                            if mod.PlayEggAnimation then
                                if hookfunction then
                                    pcall(function() hookfunction(mod.PlayEggAnimation, function(...) return end) end)
                                end
                                mod.PlayEggAnimation = function(...) return end
                            end
                            if mod.PlayAnimation then
                                if hookfunction then
                                    pcall(function() hookfunction(mod.PlayAnimation, function(...) return end) end)
                                end
                                mod.PlayAnimation = function(...) return end
                            end
                            if mod.Hatch then mod.Hatch = function(...) return end end
                            if mod.OpenEgg then mod.OpenEgg = function(...) return end end
                        end
                    end)
                end

                -- Hook Client.EggCmds nếu có
                pcall(function()
                    if EggCmds and typeof(EggCmds) == "table" then
                        if EggCmds.PlayEggAnimation then EggCmds.PlayEggAnimation = function(...) return end end
                        if EggCmds.PlayAnimation then EggCmds.PlayAnimation = function(...) return end end
                    end
                end)

                -- 2. Đóng / ẩn các ScreenGui cutscene mở trứng trong PlayerGui
                local pg = Player:FindFirstChild("PlayerGui")
                if pg then
                    for _, gName in ipairs({"EggOpening", "Eggs", "EggOpeningFrontend", "EggHatch", "Hatch", "CustomEggOpening", "EggOpeningUi"}) do
                        local g = pg:FindFirstChild(gName)
                        if g and g:IsA("ScreenGui") and g.Enabled then
                            g.Enabled = false
                        end
                    end
                end

                -- 3. Reset camera nếu camera bị khoá vào cutscene
                local cam = workspace.CurrentCamera
                if cam and cam.CameraType ~= Enum.CameraType.Custom then
                    cam.CameraType = Enum.CameraType.Custom
                    local char = Player.Character
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    if hum then
                        cam.CameraSubject = hum
                    end
                end
            end

            -- Tự động đóng pop-up thông báo an toàn ("Ok!", "Ok", "Continue")
            task.spawn(function()
                task.wait(0.1)
                for _, btn in pairs(Player.PlayerGui:GetDescendants()) do
                    if btn:IsA("TextButton") and btn.Visible then
                        local bText = string.lower(btn.Text)
                        if bText == "ok" or bText == "ok!" or bText == "continue" then
                            local isSafeModal = true
                            local curr = btn.Parent
                            local depth = 0
                            while curr and depth < 6 do
                                local pName = string.lower(curr.Name)
                                if string.find(pName, "shop") or string.find(pName, "pass") or string.find(pName, "robux") or string.find(pName, "product") or string.find(pName, "enchant") or string.find(pName, "inventory") or string.find(pName, "merchant") or string.find(pName, "exclusive") then
                                    isSafeModal = false
                                    break
                                end
                                curr = curr.Parent
                                depth = depth + 1
                            end

                            if isSafeModal then
                                pcall(function()
                                    if firesignal then
                                        firesignal(btn.Activated)
                                        firesignal(btn.MouseButton1Click)
                                    elseif btn.MouseButton1Click then
                                        btn.MouseButton1Click:Fire()
                                    end
                                end)
                            end
                        end
                    end
                end
            end)
        end)
    end

    -- Kích hoạt chặn animation ngay lập tức khi khởi động
    if STATE.SkipAnimation then
        handleEggOpeningVisuals()
    end

    -- HÀM MỞ TRỨNG CUSTOM EGG CHUẨN CỦA ĐỈNH NÚI
    local function hatchCustomEgg(eggObj, eggId, amt)
        if not amt or amt <= 0 then
            amt = STATE.AutoMaxHatch and getMaxHatchAmount() or (tonumber(STATE.HatchAmount) or 58)
        end

        local cleanEggName = nil
        if eggId and typeof(eggId) == "string" and string.len(eggId) > 0 and not string.match(eggId, "^[0-9a-fA-F]{20,}$") then
            cleanEggName = eggId
        elseif eggObj and eggObj:GetAttribute("DM_EggId") then
            cleanEggName = tostring(eggObj:GetAttribute("DM_EggId"))
        elseif STATE.CaveHatchCaveNum and CAVE_DEFAULT_EGGS[STATE.CaveHatchCaveNum] then
            cleanEggName = CAVE_DEFAULT_EGGS[STATE.CaveHatchCaveNum]
        elseif STATE.SelectedCave and CAVE_DEFAULT_EGGS[STATE.SelectedCave] then
            cleanEggName = CAVE_DEFAULT_EGGS[STATE.SelectedCave]
        end

        local okHatch = false

        -- 1. Gọi RemoteFunction CustomEggs_Hatch với UID của Model Trứng (Chuẩn xác nhất cho CustomEggs)
        if Network and Network.Invoke then
            if eggObj and eggObj.Name then
                pcall(function()
                    local res = Network.Invoke("CustomEggs_Hatch", eggObj.Name, amt)
                    if res ~= nil then okHatch = true end
                end)
            end

            -- 2. Gọi RemoteFunction CustomEggs_Hatch với tên chữ của quả trứng
            if cleanEggName and cleanEggName ~= (eggObj and eggObj.Name) then
                pcall(function()
                    local res = Network.Invoke("CustomEggs_Hatch", cleanEggName, amt)
                    if res ~= nil then okHatch = true end
                end)
            end

            -- 3. Fallback: Thử gọi Eggs_Hatch nếu CustomEggs_Hatch không phản hồi
            if not okHatch and cleanEggName then
                pcall(function()
                    local res = Network.Invoke("Eggs_Hatch", cleanEggName, amt)
                    if res ~= nil then okHatch = true end
                end)
            end
        end

        -- 4. Fallback qua EggCmds nếu có
        if not okHatch and EggCmds and typeof(EggCmds) == "table" then
            pcall(function()
                if EggCmds.Hatch then
                    if eggObj and eggObj.Name then EggCmds.Hatch(eggObj.Name, amt) end
                    if cleanEggName then EggCmds.Hatch(cleanEggName, amt) end
                    okHatch = true
                elseif EggCmds.Purchase then
                    if eggObj and eggObj.Name then EggCmds.Purchase(eggObj.Name, amt) end
                    if cleanEggName then EggCmds.Purchase(cleanEggName, amt) end
                    okHatch = true
                end
            end)
        end

        -- 5. Fallback ProximityPrompt trên quả trứng trong hang
        if not okHatch and eggObj then
            pcall(function()
                for _, pp in pairs(eggObj:GetDescendants()) do
                    if pp:IsA("ProximityPrompt") and pp.Enabled then
                        if fireproximityprompt then
                            fireproximityprompt(pp)
                            okHatch = true
                        end
                    end
                end
            end)
        end

        return okHatch
    end

    -- CÀY BREAKABLES BÃI FARM
    local function farmBreakablesAtMoneyArea(hrp)
        if not STATE.AutoHitBreakables or not hrp then return end
        local Things = workspace:FindFirstChild("__THINGS")
        local Breakables = Things and Things:FindFirstChild("Breakables")
        if not Breakables then return end

        local nearest, minDist = nil, 60
        for _, b in pairs(Breakables:GetChildren()) do
            local part = b:IsA("BasePart") and b or b:FindFirstChildWhichIsA("BasePart", true)
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
                Network.Fire("Breakables_PlayerDealDamage", nearest.Name)
                local uidNum = tonumber(nearest.Name)
                if uidNum then
                    Network.Fire("Breakables_PlayerDealDamage", uidNum)
                end
            end)
        end
    end

    -- XỬ LÝ HANG KHI COOLDOWN
    local lastFarmLogTime = 0
    local function handleCaveCooldown(targetCave, hrp)
        local yetiObj, yetiPos = checkYetiBoss()
        if STATE.AutoYeti and yetiObj and yetiPos then
            if not STATE.IsFightingYeti then
                STATE.IsFightingYeti = true
                STATE.CurrentYetiObj = yetiObj
                STATE.CurrentAction = "⚔️ Hang " .. targetCave .. " đang cooldown -> Bay đi săn Yeti Boss!"
                safeTeleport(yetiPos + Vector3.new(0, 2, 6))
            end
        elseif STATE.AutoFarmMoney and hrp then
            local cavesStr = formatSelectedCavesText and formatSelectedCavesText() or ("Hang " .. tostring(targetCave))
            STATE.CurrentAction = "⏳ Chờ các Hang (" .. cavesStr .. ") hồi chiêu... Đang cày tiền bãi farm"
            if STATE.FarmCFrame then
                local dist = (STATE.FarmCFrame.Position - hrp.Position).Magnitude
                -- Chỉ teleport khi nhân vật cách xa bãi farm hơn 25 studs (từ trong hang ra bãi)
                if dist > 25 then
                    if os.time() - lastFarmLogTime > 60 then
                        logActivity("BÃI_FARM", "Các Hang (" .. cavesStr .. ") đang hồi chiêu. Dịch chuyển về bãi farm cày tiền.")
                        lastFarmLogTime = os.time()
                    end
                    safeTeleport(STATE.FarmCFrame)
                    task.wait(0.3)
                end
            end
            farmBreakablesAtMoneyArea(hrp)
        else
            local cavesStr = formatSelectedCavesText and formatSelectedCavesText() or ("Hang " .. tostring(targetCave))
            STATE.CurrentAction = "⏳ Chờ các Hang (" .. cavesStr .. ") hồi chiêu / rương mới..."
            -- Dù không bật AutoFarmMoney, nếu đang đứng xa bãi farm (trong hang) thì vẫn tp về bãi farm chờ để không bị kẹt trong hang đóng
            if STATE.FarmCFrame and hrp then
                local dist = (STATE.FarmCFrame.Position - hrp.Position).Magnitude
                if dist > 25 then
                    safeTeleport(STATE.FarmCFrame)
                    task.wait(0.3)
                end
            end
        end
    end

    -- ========================================================
    -- VÒNG LẶP ĐIỀU PHỐI CHUYÊN SÂU (HANG, RƯƠNG & TRỨNG ĐỈNH NÚI)
    -- ========================================================
    task.spawn(function()
        while _G.PS99_SUMMIT_RUNNING and _G.PS99_SUMMIT_SESSION == CURRENT_SESSION_ID do
            task.wait(0.25)

            local char = Player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")

            -- Nếu đang tạm dừng toàn bộ: đứng yên tuyệt đối, không di chuyển/tấn công
            if STATE.IsPaused then
                STATE.CurrentAction = "🛑 ĐÃ DỪNG TOÀN BỘ HOẠT ĐỘNG (PAUSED)"
            -- Nếu đang trong trận đánh Yeti hoặc đang mua hàng Traveling Merchant: coordinator nhường quyền
            elseif not STATE.IsFightingYeti and not STATE.IsBuyingMerchant and hrp then
                local targetCave = STATE.SelectedCave

                -- ========================================================
                -- GIAI ĐOẠN 1: ĐANG TRONG PHIÊN MỞ TRỨNG HANG LIÊN TỤC
                -- "nếu đang mở egg mà yeti xuất hiện vẫn ưu tiên mở trứng cho hết thời gian mới quay lại đánh yeti"
                -- "ko cần lên bệ trứng đứng cạnh là được rồi"
                -- ========================================================
                if STATE.CaveHatchActive and STATE.AutoHatch then
                    STATE.IsAttackingCaveChest = false
                    local elapsed = os.time() - STATE.CaveHatchStartTime
                    local timeLeft = math.max(0, STATE.CaveHatchDuration - elapsed)

                    -- Lấy bệ trứng (nếu không tìm thấy thì dùng bệ trứng đã lưu khi bắt đầu phiên)
                    local eggObj, eggCF, eggId = getCaveEggModel(STATE.CaveHatchCaveNum)
                    if not eggObj then eggObj = STATE.CaveHatchEggObj end
                    if not eggCF then eggCF = STATE.CaveHatchEggCF end
                    if not eggId or eggId == "" or string.match(tostring(eggId), "^[0-9a-fA-F]{20,}$") then
                        eggId = STATE.CaveHatchEggId or CAVE_DEFAULT_EGGS[STATE.CaveHatchCaveNum]
                    end

                    -- Kiểm tra xem Trứng có bị khóa hoặc biến mất hay không
                    -- Lưu ý: Chỉ kiểm tra sau khi đã bắt đầu mở ít nhất 3 giây để tránh giật khi vừa teleport vào bệ trứng
                    local isEggOpen = eggObj and isEggUnlocked(eggObj)
                    if elapsed >= 3 and not isEggOpen then
                        STATE.CaveHatchLockedCount = (STATE.CaveHatchLockedCount or 0) + 1
                    else
                        STATE.CaveHatchLockedCount = 0
                    end

                    local eggConfirmedLocked = (STATE.CaveHatchLockedCount or 0) >= 5 -- Bị khóa liên tục ~1.5 giây

                    if timeLeft <= 0 or eggConfirmedLocked then
                        -- KẾT THÚC HOẶC HỦY PHIÊN MỞ TRỨNG VÌ HẾT GIỜ HOẶC TRỨNG BỊ KHÓA
                        local finishedCave = STATE.CaveHatchCaveNum
                        STATE.CaveHatchActive = false
                        STATE.CaveHatchLockedCount = 0
                        if STATE.CaveHatchedForThisCycle then
                            STATE.CaveHatchedForThisCycle[finishedCave] = true
                        end

                        if eggConfirmedLocked and timeLeft > 0 then
                            STATE.CurrentAction = "🔒 Hang " .. finishedCave .. " đã đóng / Trứng bị khóa! Rời hang ngay..."
                            logActivity("MỞ_TRỨNG", "Hang " .. finishedCave .. " đã đóng hoặc trứng bị khóa. Thoát hang ngay lập tức!")
                        else
                            STATE.CurrentAction = "⏰ Kết thúc phiên mở trứng Hang " .. finishedCave .. "!"
                            logActivity("MỞ_TRỨNG", "Kết thúc phiên mở trứng Hang " .. finishedCave .. ". Chu kỳ đã hoàn tất.")
                        end

                        -- Tự động chuyển sang hang kế tiếp trong danh sách các hang đã chọn (nếu có chọn nhiều hang)
                        local nextCave = pickNextCaveAfterHatch(finishedCave)
                        local nextChest = nextCave and getCaveChest(nextCave)
                        local nextEgg = (nextCave and STATE.AutoHatch and not (STATE.CaveHatchedForThisCycle and STATE.CaveHatchedForThisCycle[nextCave])) and getCaveEgg(nextCave) or nil

                        if nextCave and nextCave ~= finishedCave and (nextChest or nextEgg) then
                            STATE.SelectedCave = nextCave
                            if updateCaveButtonsUI then updateCaveButtonsUI() end
                            logActivity("MỞ_TRỨNG", "Chuyển tiếp mục tiêu sang Hang " .. nextCave .. " (" .. formatSelectedCavesText() .. ")")
                            if nextChest then
                                local _, nextCF = getCaveChest(nextCave)
                                if nextCF then
                                    local standPos = nextCF.Position + Vector3.new(0, 0.5, 3.5)
                                    safeTeleportTo(standPos, nextCF.Position)
                                    task.wait(0.3)
                                end
                            elseif nextEgg then
                                local _, nextCF = getCaveEgg(nextCave)
                                if nextCF then
                                    local standPos = nextCF.Position + Vector3.new(0, 0.5, 3.5)
                                    safeTeleportTo(standPos, nextCF.Position)
                                    task.wait(0.3)
                                end
                            end
                        else
                            -- Kiểm tra ngay nếu Yeti đang sống thì bay lên hạ gục Yeti
                            local yetiObj, yetiPos = checkYetiBoss()
                            if STATE.AutoYeti and yetiObj and yetiPos then
                                STATE.IsFightingYeti = true
                                STATE.CurrentYetiObj = yetiObj
                                STATE.CurrentAction = "⚔️ Hang đóng/Hết giờ -> Lập tức bay lên tiêu diệt Yeti Boss!"
                                safeTeleport(yetiPos + Vector3.new(0, 2, 6))
                                task.wait(0.3)
                            elseif STATE.FarmCFrame then
                                -- Không có hang nào mở và không có Yeti -> LẬP TỨC DỊCH CHUYỂN VỀ BÃI FARM AN TOÀN!
                                STATE.CurrentAction = "💰 Hang đã đóng -> Dịch chuyển về Bãi Farm an toàn"
                                logActivity("BÃI_FARM", "Hang " .. finishedCave .. " đã đóng hoặc hết giờ. Dịch chuyển về Bãi Farm an toàn.")
                                safeTeleport(STATE.FarmCFrame)
                                task.wait(0.4)
                            end
                        end
                    else
                        -- ĐANG TRONG PHIÊN MỞ TRỨNG: ĐỨNG CẠNH TRỨNG (cách 3.5 studs, không trèo lên bệ)
                        if eggCF then
                            local dist = (eggCF.Position - hrp.Position).Magnitude
                            if dist > 6 then
                                local standPos = eggCF.Position + Vector3.new(0, 0.5, 3.5)
                                safeTeleportTo(standPos, eggCF.Position)
                                task.wait(0.2)
                            end
                        end

                        local mins = math.floor(timeLeft / 60)
                        local secs = timeLeft % 60
                        local timeStr = string.format("%d:%02d", mins, secs)
                        local curHatchAmt = STATE.AutoMaxHatch and getMaxHatchAmount() or (tonumber(STATE.HatchAmount) or 58)
                        STATE.CurrentAction = "🥚 Đang mở trứng Hang " .. STATE.CaveHatchCaveNum .. " (" .. tostring(eggId) .. " x" .. curHatchAmt .. ") | Còn: " .. timeStr

                        -- BỎ QUA ANIMATION TRƯỚC KHI GỌI REMOTE
                        handleEggOpeningVisuals()

                        -- GỌI HÀM MỞ TRỨNG (CustomEggs_Hatch)
                        local hatchedThisCycle = hatchCustomEgg(eggObj, eggId, curHatchAmt)

                        -- Cập nhật bộ đếm số trứng đã mở
                        local curPetCount = getInventoryPetCount()
                        if curPetCount and lastPetCount then
                            if curPetCount > lastPetCount then
                                local deltaPets = curPetCount - lastPetCount
                                STATE.TotalHatchedEggs = STATE.TotalHatchedEggs + deltaPets
                                logActivity("MỞ_TRỨNG", "Mở thành công +" .. deltaPets .. " thú cưng từ trứng " .. tostring(eggId) .. ". (Tổng: " .. STATE.TotalHatchedEggs .. ")")
                            end
                            lastPetCount = curPetCount
                        elseif hatchedThisCycle then
                            STATE.TotalHatchedEggs = STATE.TotalHatchedEggs + curHatchAmt
                        end

                        handleEggOpeningVisuals()
                    end

                -- ========================================================
                -- GIAI ĐOẠN 2: ĐIỀU PHỐI HANG ĐÃ CHỌN (RƯƠNG -> TRỨNG -> CHỜ COOLDOWN)
                -- ========================================================
                elseif (STATE.AutoCaveChests or STATE.AutoHatch) and hrp then
                    -- Nếu không đang tấn công dở rương, kiểm tra nếu hang hiện tại không có rương và không có trứng mở được thì chuyển sang hang tốt nhất
                    if not STATE.IsAttackingCaveChest then
                        local curChest = getCaveChest(targetCave)
                        local curEgg = (STATE.AutoHatch and not (STATE.CaveHatchedForThisCycle and STATE.CaveHatchedForThisCycle[targetCave])) and getCaveEgg(targetCave) or nil
                        if not curChest and not curEgg then
                            local bestCave, actionType = getBestActiveCave()
                            if bestCave and bestCave ~= targetCave and (actionType == "chest" or actionType == "egg") then
                                STATE.SelectedCave = bestCave
                                targetCave = bestCave
                                if updateCaveButtonsUI then updateCaveButtonsUI() end
                            end
                        end
                    end

                    local chestObj, chestCF = getCaveChest(targetCave)

                    -- TRƯỜNG HỢP 2A: PHÁT HIỆN RƯƠNG BOSS TRONG HANG
                    -- "Nếu Hang đang có Rương Boss: Teleport nhân vật đến đứng sát trước mặt rương Hang đó... chỉ cần tp sát rương là được rồi"
                    if chestObj and chestCF then
                        -- Phát hiện rương mới: Đặt lại cờ chu kỳ mở trứng cho hang
                        if STATE.CaveHatchedForThisCycle then
                            STATE.CaveHatchedForThisCycle[targetCave] = false
                        end

                        -- Khi phát hiện một rương mới (hoặc chuyển từ Rương 1 sang Rương 2, Rương 3)
                        if not STATE.IsAttackingCaveChest or STATE.CurrentChestUID ~= chestObj.Name then
                            STATE.CurrentChestUID = chestObj.Name
                            logActivity("RƯƠNG_HANG", "Phát hiện Rương Boss Hang " .. targetCave .. " (UID: " .. chestObj.Name .. "). Tiếp cận phá rương...")
                            local standPos = chestCF.Position + Vector3.new(0, 0.5, 3.5)
                            safeTeleportTo(standPos, chestCF.Position)
                            task.wait(0.2)
                        else
                            local dist = (chestCF.Position - hrp.Position).Magnitude
                            -- Nếu ở xa hơn 6 studs: Teleport đứng sát trước mặt rương (cách 3.5 studs)
                            if dist > 6 then
                                local standPos = chestCF.Position + Vector3.new(0, 0.5, 3.5)
                                safeTeleportTo(standPos, chestCF.Position)
                                task.wait(0.2)
                            end
                        end
                        STATE.IsAttackingCaveChest = true
                        STATE.CaveCFrames[targetCave] = chestCF

                        -- Gửi sát thương phá rương (Breakables_PlayerDealDamage)
                        if Network and Network.Fire then
                            pcall(function()
                                Network.Fire("Breakables_PlayerDealDamage", chestObj.Name)
                                local uidNum = tonumber(chestObj.Name)
                                if uidNum then
                                    Network.Fire("Breakables_PlayerDealDamage", uidNum)
                                end
                            end)
                        end

                        STATE.CurrentAction = "📦 Đang phá Rương Hang " .. targetCave .. " (UID: " .. chestObj.Name .. ")"

                    -- TRƯỜNG HỢP 2B: VỪA PHÁ XONG 1 RƯƠNG TRONG HANG -> TỰ ĐỘNG DỊCH CHUYỂN TỚI RƯƠNG TIẾP THEO
                    elseif STATE.IsAttackingCaveChest then
                        -- Chờ 1.2s để game kịp spawn rương kế tiếp (Ví dụ rương 1 of 3 -> 2 of 3)
                        task.wait(1.2)
                        local nextChest, nextCF = getCaveChest(targetCave)
                        if nextChest and nextCF then
                            -- RƯƠNG KẾ TIẾP ĐÃ XUẤT HIỆN -> DỊCH CHUYỂN TỚI NGAY LẬP TỨC!
                            STATE.CurrentChestUID = nextChest.Name
                            STATE.CaveCFrames[targetCave] = nextCF
                            logActivity("RƯƠNG_HANG", "Rương trước đã vỡ! Tự động dịch chuyển tới Rương tiếp theo Hang " .. targetCave .. " (UID: " .. nextChest.Name .. ")...")
                            local standPos = nextCF.Position + Vector3.new(0, 0.5, 3.5)
                            safeTeleportTo(standPos, nextCF.Position)
                            task.wait(0.2)
                        else
                            -- KHÔNG CÒN RƯƠNG NÀO NỮA -> TOÀN BỘ RƯƠNG ĐÃ VỠ XONG
                            STATE.IsAttackingCaveChest = false
                            STATE.CurrentChestUID = nil
                            logActivity("RƯƠNG_HANG", "Toàn bộ Rương Hang " .. targetCave .. " đã bị tiêu diệt xong!")
                        end

                    -- TRƯỜNG HỢP 2C: KHÔNG CÒN RƯƠNG VÀ BẬT AUTO HATCH -> BẮT ĐẦU MỞ TRỨNG
                    elseif STATE.AutoHatch then
                        local eggObj, eggCF, eggId = getCaveEgg(targetCave)

                        -- Fallback nếu getCaveEgg bị chậm 1 nhịp do UI vừa mở (BẮT BUỘC TRỨNG PHẢI MỞ VÀ KHÔNG BỊ KHÓA)
                        if not eggObj and not (STATE.CaveHatchedForThisCycle and STATE.CaveHatchedForThisCycle[targetCave]) then
                            local mObj, mCF, mId = getCaveEggModel(targetCave)
                            if mObj and mCF and isEggUnlocked(mObj) then
                                eggObj, eggCF, eggId = mObj, mCF, mId
                            end
                        end

                        if eggObj and eggCF and eggId then
                            STATE.CaveCFrames[targetCave] = eggCF

                            -- KÍCH HOẠT PHIÊN MỞ TRỨNG HANG
                            STATE.CaveHatchActive = true
                            STATE.CaveHatchCaveNum = targetCave
                            STATE.CaveHatchStartTime = os.time()
                            STATE.CaveHatchDuration = 300 -- 5 phút
                            STATE.CaveHatchEggId = eggId
                            STATE.CaveHatchEggObj = eggObj
                            STATE.CaveHatchEggCF = eggCF
                            STATE.CaveHatchLockedCount = 0
                            local hatchAmt = STATE.AutoMaxHatch and getMaxHatchAmount() or (tonumber(STATE.HatchAmount) or 58)
                            logActivity("MỞ_TRỨNG", "Bắt đầu phiên mở trứng Hang " .. targetCave .. " (" .. tostring(eggId) .. ") trong 5 phút. Tối đa: " .. hatchAmt .. " quả/lần.")

                            -- Đứng sát cạnh trứng (cách 3.5 studs, không trèo lên bệ)
                            local standPos = eggCF.Position + Vector3.new(0, 0.5, 3.5)
                            safeTeleportTo(standPos, eggCF.Position)
                            task.wait(0.2)
                            STATE.CurrentAction = "🎉 Rương đã vỡ! Bắt đầu mở trứng " .. eggId .. " Hang " .. targetCave
                        else
                            -- Hang chưa có trứng mở được (hoặc đã mở xong chu kỳ này / đang cooldown)
                            -- Kiểm tra xem có hang nào khác trong danh sách đang sẵn sàng không
                            local nextCandidate = pickNextCaveAfterHatch(targetCave)
                            if nextCandidate and nextCandidate ~= targetCave then
                                local cChest = getCaveChest(nextCandidate)
                                local cEgg = getCaveEgg(nextCandidate)
                                if cChest or cEgg then
                                    STATE.SelectedCave = nextCandidate
                                    if updateCaveButtonsUI then updateCaveButtonsUI() end
                                else
                                    handleCaveCooldown(targetCave, hrp)
                                end
                            else
                                handleCaveCooldown(targetCave, hrp)
                            end
                        end

                    -- TRƯỜNG HỢP 2D: KHÔNG CÒN RƯƠNG VÀ KHÔNG BẬT MỞ TRỨNG -> COOLDOWN HOẶC SANG HANG TIẾP THEO
                    else
                        local nextCandidate = pickNextCaveAfterHatch(targetCave)
                        if nextCandidate and nextCandidate ~= targetCave then
                            local cChest = getCaveChest(nextCandidate)
                            if cChest then
                                STATE.SelectedCave = nextCandidate
                                if updateCaveButtonsUI then updateCaveButtonsUI() end
                            else
                                handleCaveCooldown(targetCave, hrp)
                            end
                        else
                            handleCaveCooldown(targetCave, hrp)
                        end
                    end

                -- ========================================================
                -- GIAI ĐOẠN 3: CÀY TIỀN THUẦN TÚY TẠI BÃI FARM KHI KHÔNG CHẠY HANG
                -- ========================================================
                elseif STATE.AutoFarmMoney and hrp then
                    STATE.IsAttackingCaveChest = false
                    STATE.CurrentAction = "💰 Cày tiền tại Bãi Farm"
                    if STATE.FarmCFrame then
                        local dist = (STATE.FarmCFrame.Position - hrp.Position).Magnitude
                        if dist > 35 then
                            safeTeleport(STATE.FarmCFrame)
                            task.wait(0.3)
                        end
                    end
                    farmBreakablesAtMoneyArea(hrp)
                else
                    STATE.IsAttackingCaveChest = false
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

    -- ========================================================
    -- AUTO SĂN TRAVELING MERCHANT (TP VÀO BỤC & MUA SẠCH SHOP)
    -- ========================================================
    task.spawn(function()
        while _G.PS99_SUMMIT_RUNNING and _G.PS99_SUMMIT_SESSION == CURRENT_SESSION_ID do
            task.wait(3)
            if not STATE.IsPaused and STATE.AutoTravelingMerchant then
                local mObj, mCF, mName, mPad, timerText = getTravelingMerchant()
                if mObj and mName then
                    local isNewMerchant = (STATE.LastMerchantName ~= mName) or (os.time() - STATE.LastMerchantTime > 600)
                    if isNewMerchant then
                        -- ƯU TIÊN TUYỆT ĐỐI CHO HANG: Không ngắt quãng khi đang mở trứng hang hoặc phá rương hang
                        local inCaveSession = (STATE.CaveHatchActive and STATE.AutoHatch) or (STATE.IsAttackingCaveChest and STATE.AutoCaveChests)
                        if not inCaveSession and not STATE.IsFightingYeti and not STATE.IsBuyingMerchant then
                            STATE.LastMerchantName = mName
                            STATE.LastMerchantTime = os.time()
                            pcall(function()
                                handleTravelingMerchantPurchase(mObj, mCF)
                            end)
                        end
                    end
                end
            end
        end
    end)

    -- ========================================================
    -- BỘ CHỐNG AFK & AUTO RECONNECT 4 LỚP (BULLETPROOF ANTI-AFK ENGINE)
    -- ========================================================
    if not VIM then
        pcall(function()
            VIM = game:GetService("VirtualInputManager")
        end)
    end

    -- Lớp 1: Bắt sự kiện Idled dự phòng nếu getconnections chưa tắt kịp
    pcall(function()
        registerConn(Player.Idled:Connect(function()
            if STATE.AntiAFK and _G.PS99_SUMMIT_RUNNING and _G.PS99_SUMMIT_SESSION == CURRENT_SESSION_ID then
                disableIdledConnections()
                if VIM then
                    pcall(function()
                        VIM:SendKeyEvent(true, Enum.KeyCode.F15, false, game)
                        task.wait(0.01)
                        VIM:SendKeyEvent(false, Enum.KeyCode.F15, false, game)
                    end)
                end
                if VirtualUser then
                    pcall(function()
                        VirtualUser:CaptureController()
                        VirtualUser:ClickButton2(Vector2.new(50, 50))
                    end)
                end
            end
        end))
    end)

    -- Lớp 2: Chủ động phát tín hiệu hoạt động định kỳ mỗi 45s (Active Heartbeat)
    -- Liên tục reset bộ đếm idle của Roblox engine về 0, không bao giờ để chạm mốc 20 phút
    task.spawn(function()
        while _G.PS99_SUMMIT_RUNNING and _G.PS99_SUMMIT_SESSION == CURRENT_SESSION_ID do
            task.wait(45)
            if STATE.AntiAFK then
                disableIdledConnections()
                if VIM then
                    pcall(function()
                        VIM:SendKeyEvent(true, Enum.KeyCode.F15, false, game)
                        task.wait(0.02)
                        VIM:SendKeyEvent(false, Enum.KeyCode.F15, false, game)
                    end)
                end
                if VirtualUser then
                    pcall(function()
                        VirtualUser:CaptureController()
                        VirtualUser:ClickButton2(Vector2.new(60, 60))
                    end)
                end
                logActivity("ANTI_AFK", "Xung nhịp Heartbeat: Đã kích hoạt VirtualInput & reset Idle.")
            end
        end
    end)

    -- Lớp 3 & 4: Tự động Reconnect khi mất mạng hoặc bị ngắt kết nối (Loop retry bền bỉ)
    local isReconnecting = false
    local function triggerReconnect(reason)
        if isReconnecting or not STATE.AutoReconnect or not _G.PS99_SUMMIT_RUNNING then return end
        isReconnecting = true
        logActivity("RECONNECT", "CẢNH BÁO MẤT KẾT NỐI: " .. tostring(reason) .. ". Đang chuẩn bị Reconnect sau 5s...")
        task.spawn(function()
            sendWebhook("⚠️ MẤT KẾT NỐI", (reason or "Phát hiện mất kết nối!") .. "\nĐang tự động kết nối lại sau 5 giây...", 15158332)
            task.wait(5)
            while _G.PS99_SUMMIT_RUNNING and _G.PS99_SUMMIT_SESSION == CURRENT_SESSION_ID do
                pcall(function()
                    TeleportService:Teleport(game.PlaceId, Player)
                end)
                task.wait(8)
            end
        end)
    end

    pcall(function()
        registerConn(GuiService.ErrorMessageChanged:Connect(function()
            if _G.PS99_SUMMIT_RUNNING and _G.PS99_SUMMIT_SESSION == CURRENT_SESSION_ID then
                if GuiService:GetErrorCode().Value > 0 then
                    triggerReconnect("Mã lỗi mạng: " .. tostring(GuiService:GetErrorCode().Value))
                end
            end
        end))
    end)

    task.spawn(function()
        while _G.PS99_SUMMIT_RUNNING and _G.PS99_SUMMIT_SESSION == CURRENT_SESSION_ID do
            task.wait(3)
            if STATE.AutoReconnect and not isReconnecting then
                pcall(function()
                    local promptOverlay = CoreGui:FindFirstChild("RobloxPromptGui") and CoreGui.RobloxPromptGui:FindFirstChild("promptOverlay")
                    if promptOverlay then
                        local errorPrompt = promptOverlay:FindFirstChild("ErrorPrompt")
                        if errorPrompt and errorPrompt.Visible then
                            triggerReconnect("Phát hiện màn hình ngắt kết nối (Error Prompt)!")
                        end
                    end
                end)
            end
        end
    end)

    -- CẬP NHẬT DASHBOARD
    task.spawn(function()
        while _G.PS99_SUMMIT_RUNNING and _G.PS99_SUMMIT_SESSION == CURRENT_SESSION_ID do
            task.wait(1)
            pcall(function()
                if STATE.IsPaused then
                    lblAction.Text = "🛑 ĐÃ DỪNG TOÀN BỘ HOẠT ĐỘNG (PAUSED)"
                else
                    lblAction.Text = STATE.CurrentAction
                end
                local caveCountdownStr = getCaveOpenCountdown(STATE.SelectedCave)
                lblCaveTimer.Text = caveCountdownStr
                if lblCaveTimerTrails then
                    lblCaveTimerTrails.Text = caveCountdownStr
                end
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

    -- GỬI THÔNG BÁO WEBHOOK KHI EXECUTE THÀNH CÔNG
    task.spawn(function()
        task.wait(1.5)
        if not (_G.PS99_SUMMIT_RUNNING and _G.PS99_SUMMIT_SESSION == CURRENT_SESSION_ID) then return end
        if STATE.ExecuteAlert then
            local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            local posStr = hrp and string.format("Vector3.new(%.1f, %.1f, %.1f)", hrp.Position.X, hrp.Position.Y, hrp.Position.Z) or "Chưa xác định"
            local desc = string.format(
                "🟢 **Script đã khởi động và hoạt động thành công!**\n\n" ..
                "👤 **Tài khoản:** `%s`\n" ..
                "📍 **Vị trí hiện tại:** `%s`\n" ..
                "⛰️ **Hang mục tiêu:** `%s`\n" ..
                "👹 **Auto Săn Yeti:** `%s`\n" ..
                "📦 **Auto Phá Rương Hang:** `%s`\n" ..
                "🥚 **Auto Mở Trứng Hang:** `%s`\n" ..
                "💰 **Auto Cày Tiền:** `%s`\n" ..
                "🛒 **Auto Săn Merchant:** `%s`\n" ..
                "🛡️ **Anti-AFK 20m:** `%s`",
                Player.Name,
                posStr,
                formatSelectedCavesText and formatSelectedCavesText() or ("Hang " .. tostring(STATE.SelectedCave)),
                STATE.AutoYeti and "🟢 BẬT" or "🔴 TẮT",
                STATE.AutoCaveChests and "🟢 BẬT" or "🔴 TẮT",
                STATE.AutoHatch and "🟢 BẬT" or "🔴 TẮT",
                STATE.AutoFarmMoney and "🟢 BẬT" or "🔴 TẮT",
                STATE.AutoTravelingMerchant and "🟢 BẬT" or "🔴 TẮT",
                STATE.AntiAFK and "🟢 BẬT" or "🔴 TẮT"
            )
            sendWebhook("🚀 EXECUTE SCRIPT THÀNH CÔNG!", desc, 3066993)
            pcall(function()
                StarterGui:SetCore("SendNotification", {
                    Title = "🚀 PS99 Summit Suite",
                    Text = "Khởi động thành công! Đã gửi thông báo Discord.",
                    Duration = 4
                })
            end)
        end
        logActivity("KHỞI_ĐỘNG", "PS99 Summit Suite V6 khởi động thành công trên tài khoản " .. Player.Name)
    end)
end)
