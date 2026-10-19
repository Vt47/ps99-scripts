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

local Library, Client, Directory, Save, PetDirectory, Network, EggCmds
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
    IsAttackingCaveChest = false,
    CurrentChestObj = nil,
    CurrentChestCF = nil,
    AutoHatch = false,
    ShowHatchPopup = true,
    SkipAnimation = true,
    SelectedEggName = "Nearest",
    HatchAmount = 1,

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
    Webhook = "https://discord.com/api/webhooks/1557705516178874429/DSxD6hH0VRjmXxBB44kQVM3VDhNvUwTp7h4uTCCtZK1k4vOLyOxLtjAfwxK2mCSS0MFb",
    DiscordUserId = "",
    MentionOnHuge = true,
    MentionOnTitanic = true,
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
local function sendWebhook(title, description, color, mention)
    if not STATE.Webhook or STATE.Webhook == "" then return end
    local fn = request or http_request or (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request)
    if not fn then return end
    pcall(function()
        local embed = {
            description = description,
            color = color or 5793266,
            footer = { text = "PS99 Summit Suite | " .. Player.Name },
            timestamp = DateTime.now():ToIsoDate()
        }
        if title and title ~= "" then embed.title = title end
        local jsonBody = HttpService:JSONEncode({
            username = "Diamond Mountain Monitor",
            content = mention or "",
            embeds = { embed }
        })
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

-- Tự động lắng nghe và ghi lại bất kỳ lỗi Script / Engine nào
pcall(function()
    local ScriptContext = game:GetService("ScriptContext")
    ScriptContext.Error:Connect(function(msg, stack, scriptInstance)
        if _G.PS99_SUMMIT_RUNNING and _G.PS99_SUMMIT_SESSION == CURRENT_SESSION_ID then
            logActivity("LỖI_HỆ_THỐNG", tostring(msg) .. " | " .. tostring(stack))
        end
    end)
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
            ExecuteAlert = STATE.ExecuteAlert
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
        if data.ExecuteAlert ~= nil then STATE.ExecuteAlert = data.ExecuteAlert end
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

-- Lấy đối tượng và CFrame Rương Boss của Hang (Trail 1-6)
local function getCaveChest(caveNum)
    caveNum = tonumber(caveNum) or STATE.SelectedCave
    local Things = workspace:FindFirstChild("__THINGS")
    local Breakables = Things and Things:FindFirstChild("Breakables")
    if not Breakables then return nil, nil end

    local targetArea = "trail" .. tostring(caveNum)

    for _, b in pairs(Breakables:GetChildren()) do
        local areaId = string.lower(tostring(b:GetAttribute("AreaID") or ""))
        local bId = string.lower(tostring(b:GetAttribute("BreakableID") or ""))
        
        -- Khớp AreaID chính xác: Trail1, Trail2, ... Trail6 hoặc BreakableID có trail + caveNum
        local matchArea = (areaId == targetArea or string.find(areaId, targetArea) or string.find(areaId, "trail " .. tostring(caveNum)))
        local matchBId = (string.find(bId, "trail") and (string.find(bId, tostring(caveNum)) or matchArea)) or (bId == "diamondmountaintrailchest" and matchArea)

        if (matchArea or matchBId) and bId ~= "yeti" then
            local part = b:IsA("BasePart") and b or b:FindFirstChildWhichIsA("BasePart", true)
            if part then
                return b, part.CFrame
            end
        end
    end

    return nil, nil
end

-- Lấy đối tượng, CFrame và Tên Trứng CustomEgg của Hang (Trail 1-6)
local function getCaveEgg(caveNum)
    caveNum = tonumber(caveNum) or STATE.SelectedCave
    local Things = workspace:FindFirstChild("__THINGS")
    local CustomEggs = Things and Things:FindFirstChild("CustomEggs")
    if not CustomEggs then return nil, nil, nil end

    for _, egg in pairs(CustomEggs:GetChildren()) do
        local trailNum = egg:GetAttribute("DM_TrailEgg")
        if trailNum and tonumber(trailNum) == tonumber(caveNum) then
            local eggId = tostring(egg:GetAttribute("DM_EggId") or egg.Name)
            local part = egg:FindFirstChild("Center") or egg:FindFirstChild("Egg") or egg:FindFirstChildWhichIsA("BasePart", true)
            local cf = part and part.CFrame or egg:GetPivot()
            return egg, cf, eggId
        end
    end

    return nil, nil, nil
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
                            if string.find(lTxt, "next roll") or string.find(lTxt, "cooldown") or string.find(lTxt, "returns in") or string.find(lTxt, "opens in") then
                                isCooldown = true
                            elseif string.find(lTxt, "boss chest") or string.find(lTxt, "unlocked") then
                                isUnlocked = true
                            end
                        end
                    end
                end
            end
        end
    end)

    return isUnlocked, isCooldown, remainingSec, signText
end

-- Kiểm tra trạng thái Hang: "chest", "egg", "closed"
local function isCaveOpen(caveNum)
    caveNum = tonumber(caveNum) or STATE.SelectedCave

    -- Nếu đang trong phiên mở trứng liên tục của chính hang này
    if STATE.CaveHatchActive and STATE.CaveHatchCaveNum == caveNum then
        local elapsed = os.time() - STATE.CaveHatchStartTime
        local rem = math.max(0, STATE.CaveHatchDuration - elapsed)
        return true, "egg", STATE.CaveHatchEggObj, STATE.CaveHatchEggCF, STATE.CaveHatchEggId, rem
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

    if STATE.CaveHatchActive and STATE.CaveHatchCaveNum == caveNum then
        local elapsed = os.time() - STATE.CaveHatchStartTime
        local rem = math.max(0, STATE.CaveHatchDuration - elapsed)
        local m = math.floor(rem / 60)
        local s = rem % 60
        return string.format("🟢 Mở Trứng (Còn %d:%02d)", m, s)
    end

    local cObj = getCaveChest(caveNum)
    if cObj then
        return "🟢 Sẵn Sàng (Có Rương Boss)"
    end

    local eObj, _, eId = getCaveEgg(caveNum)
    if eObj then
        return "🟢 Sẵn Sàng (Trứng " .. tostring(eId) .. ")"
    end

    local isUnlocked, isCooldown, remSec, signText = getCaveSignInfo(caveNum)
    if isCooldown and remSec and remSec > 0 then
        local m = math.floor(remSec / 60)
        local s = remSec % 60
        return string.format("⏳ Mở sau %d:%02d", m, s)
    elseif isCooldown and signText ~= "" then
        return "⏳ " .. signText
    elseif isUnlocked then
        return "🟢 Sẵn Sàng (Hang Mở)"
    end

    return "⏳ Đang Chờ Hồi / Quét..."
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

local updateCaveButtonsUI = function() end

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

local btnSidebarReconnect = Instance.new("TextButton")
btnSidebarReconnect.Name = "BtnSidebarReconnect"
btnSidebarReconnect.Size = UDim2.new(1, -10, 0, 34)
btnSidebarReconnect.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
btnSidebarReconnect.Text = "🔄 Reconnect Server"
btnSidebarReconnect.TextColor3 = Color3.fromRGB(255, 255, 255)
btnSidebarReconnect.Font = Enum.Font.GothamBold
btnSidebarReconnect.TextSize = 10
btnSidebarReconnect.Parent = Sidebar

local btnReconCorner = Instance.new("UICorner")
btnReconCorner.CornerRadius = UDim.new(0, 8)
btnReconCorner.Parent = btnSidebarReconnect

btnSidebarReconnect.Activated:Connect(function()
    TeleportService:Teleport(game.PlaceId, Player)
end)

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
local lblCaveTimer = createInfoCard(DashboardPage, "⏳ Thời Gian Mở Hang:", "Đang quét...")
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

-- TRANG 3: HANG NÚI & TRỨNG
local lblSelectedEgg = createInfoCard(TrailsPage, "🥚 Trứng Đã Chọn:", STATE.SelectedEggName)
local lblCaveTimerTrails = createInfoCard(TrailsPage, "⏳ Thời Gian Mở Hang:", "Đang quét...")

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
        if STATE.SelectedCave ~= i then
            STATE.CaveHatchActive = false
        end
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
        local countdownStr = getCaveOpenCountdown(i)
        lblCaveTimer.Text = countdownStr
        if lblCaveTimerTrails then lblCaveTimerTrails.Text = countdownStr end
        saveConfig()
    end)
    table.insert(caveButtons, btn)
end

updateCaveButtonsUI = function(newCave)
    newCave = tonumber(newCave) or STATE.SelectedCave
    if caveButtons and #caveButtons == 6 then
        for idx, b in ipairs(caveButtons) do
            b.BackgroundColor3 = (idx == newCave) and Color3.fromRGB(50, 110, 220) or Color3.fromRGB(35, 40, 55)
        end
    end
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
createToggle(TrailsPage, "🥚 Auto Mở Trứng (Auto Hatch Egg)", STATE.AutoHatch, function(v)
    STATE.AutoHatch = v
    if not v then
        STATE.CaveHatchActive = false
    end
end)
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
createToggle(SettingsPage, "🛡️ Anti-AFK (Chống văng 20 phút)", STATE.AntiAFK, function(v)
    STATE.AntiAFK = v
    if v then disableIdledConnections() end
end)
createToggle(SettingsPage, "🔄 Auto Reconnect Khi Đứt Mạng", STATE.AutoReconnect, function(v) STATE.AutoReconnect = v end)
createToggle(SettingsPage, "🔔 Báo Webhook Khi Mở/Execute Script", STATE.ExecuteAlert, function(v) STATE.ExecuteAlert = v saveConfig() end)
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
            if STATE.AutoYeti then
                local yetiObj, yetiPos, cdTimer = checkYetiBoss()

                if yetiObj and yetiPos then
                    yetiMissingChecks = 0
                    STATE.YetiStatusText = "🔥 Đang Sống!"
                    STATE.CurrentYetiObj = yetiObj

                    -- Ưu tiên Yeti Boss, NHƯNG nếu đang trong hang mở trứng hoặc mở rương thì ưu tiên hoàn thành trước
                    local inCaveSession = (STATE.CaveHatchActive and STATE.AutoHatch) or (STATE.IsAttackingCaveChest and STATE.AutoCaveChests)
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

                            if STATE.CaveHatchActive and STATE.CaveHatchEggCF then
                                safeTeleport(STATE.CaveHatchEggCF)
                                STATE.CurrentAction = "🚀 Quay lại tiếp tục mở trứng Hang " .. STATE.CaveHatchCaveNum
                            elseif STATE.AutoCaveChests or STATE.AutoHatch then
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
                                        STATE.CurrentAction = "⏳ Hang " .. STATE.SelectedCave .. " chưa mở / đang cooldown. Về bãi farm tiền..."
                                    end
                                end
                            elseif STATE.AutoFarmMoney then
                                if STATE.FarmCFrame then
                                    safeTeleport(STATE.FarmCFrame)
                                    STATE.CurrentAction = "💰 Cày tiền tại Bãi Farm"
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

        local eggObj, eggCF, eggId = getCaveEgg(STATE.SelectedCave)
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

            -- Tự động đóng pop-up thông báo an toàn ("Ok!", "Ok", "Continue")
            task.spawn(function()
                task.wait(0.15)
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

    -- HÀM MỞ TRỨNG CUSTOM EGG CHUẨN CỦA ĐỈNH NÚI
    local function hatchCustomEgg(eggObj, eggId, amt)
        amt = amt or STATE.HatchAmount or 1
        local okHatch = false

        -- 1. Gọi RemoteFunction chuẩn của game: CustomEggs_Hatch
        if Network and Network.Invoke then
            pcall(function()
                if eggObj and eggObj.Name then
                    Network.Invoke("CustomEggs_Hatch", eggObj.Name, amt)
                    okHatch = true
                end
            end)
            pcall(function()
                if eggId and eggId ~= "" and eggId ~= (eggObj and eggObj.Name) then
                    Network.Invoke("CustomEggs_Hatch", eggId, amt)
                    okHatch = true
                end
            end)
        end

        -- 2. Tương tác ProximityPrompt trên quả trứng nếu có
        if eggObj then
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
            STATE.CurrentAction = "⏳ Chờ Hang " .. targetCave .. " hồi chiêu... Đang cày tiền bãi farm"
            if STATE.FarmCFrame then
                local dist = (STATE.FarmCFrame.Position - hrp.Position).Magnitude
                if dist > 35 then
                    logActivity("BÃI_FARM", "Hang " .. targetCave .. " đang hồi chiêu. Dịch chuyển về bãi farm cày tiền.")
                    safeTeleport(STATE.FarmCFrame)
                    task.wait(0.3)
                end
            end
            farmBreakablesAtMoneyArea(hrp)
        else
            STATE.CurrentAction = "⏳ Chờ Hang " .. targetCave .. " hồi chiêu / rương mới..."
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

            -- Nếu đang trong trận đánh Yeti: coordinator nhường quyền
            if not STATE.IsFightingYeti and hrp then
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

                    -- Kiểm tra biển báo xem hang có bị đóng sớm hay chuyển cooldown không
                    local isUnl, isCd, remSec = getCaveSignInfo(STATE.CaveHatchCaveNum)
                    if isCd and (not remSec or remSec > 10) then
                        timeLeft = 0 -- Server đã đóng hang
                    elseif remSec and remSec > 0 and remSec < timeLeft then
                        timeLeft = remSec
                    end

                    local eggObj, eggCF, eggId = getCaveEgg(STATE.CaveHatchCaveNum)
                    if not eggObj or eggObj.Parent == nil then
                        timeLeft = 0 -- Trứng đã biến mất
                    end

                    if timeLeft <= 0 or not eggObj then
                        -- KẾT THÚC PHIÊN MỞ TRỨNG
                        STATE.CaveHatchActive = false
                        STATE.CurrentAction = "⏰ Kết thúc phiên mở trứng Hang " .. STATE.CaveHatchCaveNum .. "!"
                        logActivity("MỞ_TRỨNG", "Kết thúc phiên mở trứng Hang " .. STATE.CaveHatchCaveNum .. ".")

                        -- Kiểm tra ngay nếu Yeti đang sống thì bay lên hạ gục Yeti
                        local yetiObj, yetiPos = checkYetiBoss()
                        if STATE.AutoYeti and yetiObj and yetiPos then
                            STATE.IsFightingYeti = true
                            STATE.CurrentYetiObj = yetiObj
                            STATE.CurrentAction = "⚔️ Hết giờ mở trứng -> Lập tức bay lên tiêu diệt Yeti Boss!"
                            safeTeleport(yetiPos + Vector3.new(0, 2, 6))
                        elseif STATE.AutoFarmMoney and STATE.FarmCFrame then
                            safeTeleport(STATE.FarmCFrame)
                            task.wait(0.4)
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
                        STATE.CurrentAction = "🥚 Đang mở trứng Hang " .. STATE.CaveHatchCaveNum .. " (" .. tostring(eggId) .. ") | Còn: " .. timeStr

                        -- GỌI HÀM MỞ TRỨNG (CustomEggs_Hatch)
                        local amt = STATE.HatchAmount or 1
                        local hatchedThisCycle = hatchCustomEgg(eggObj, eggId, amt)

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
                            STATE.TotalHatchedEggs = STATE.TotalHatchedEggs + amt
                        end

                        handleEggOpeningVisuals()
                    end

                -- ========================================================
                -- GIAI ĐOẠN 2: ĐIỀU PHỐI HANG ĐÃ CHỌN (RƯƠNG -> TRỨNG -> CHỜ COOLDOWN)
                -- ========================================================
                elseif (STATE.AutoCaveChests or STATE.AutoHatch) and hrp then
                    local chestObj, chestCF = nil, nil
                    if STATE.AutoCaveChests then
                        chestObj, chestCF = getCaveChest(targetCave)
                    end

                    -- TRƯỜNG HỢP 2A: PHÁT HIỆN RƯƠNG BOSS TRONG HANG
                    -- "Nếu Hang đang có Rương Boss: Teleport nhân vật đến đứng sát trước mặt rương Hang đó... chỉ cần tp sát rương là được rồi"
                    if chestObj and chestCF then
                        if not STATE.IsAttackingCaveChest then
                            logActivity("RƯƠNG_HANG", "Phát hiện Rương Boss Hang " .. targetCave .. " (UID: " .. chestObj.Name .. "). Tiếp cận phá rương...")
                        end
                        STATE.IsAttackingCaveChest = true
                        STATE.CaveCFrames[targetCave] = chestCF

                        local dist = (chestCF.Position - hrp.Position).Magnitude
                        -- Nếu ở xa hơn 6 studs: Teleport đứng sát trước mặt rương (cách 3.5 studs)
                        if dist > 6 then
                            local standPos = chestCF.Position + Vector3.new(0, 0.5, 3.5)
                            safeTeleportTo(standPos, chestCF.Position)
                            task.wait(0.2)
                        end

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

                    -- TRƯỜNG HỢP 2B: RƯƠNG ĐÃ VỠ VÀ BẬT AUTO HATCH -> BẮT ĐẦU MỞ TRỨNG HANG ĐÓ
                    elseif STATE.AutoHatch then
                        if STATE.IsAttackingCaveChest then
                            logActivity("RƯƠNG_HANG", "Rương Hang " .. targetCave .. " đã vỡ xong! Chuyển sang mở trứng.")
                        end
                        STATE.IsAttackingCaveChest = false
                        local eggObj, eggCF, eggId = getCaveEgg(targetCave)

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
                            logActivity("MỞ_TRỨNG", "Bắt đầu phiên mở trứng Hang " .. targetCave .. " (" .. tostring(eggId) .. ") trong 5 phút.")

                            -- Đứng sát cạnh trứng (cách 3.5 studs, không trèo lên bệ)
                            local standPos = eggCF.Position + Vector3.new(0, 0.5, 3.5)
                            safeTeleportTo(standPos, eggCF.Position)
                            task.wait(0.2)
                            STATE.CurrentAction = "🎉 Rương đã vỡ! Bắt đầu mở trứng " .. eggId .. " Hang " .. targetCave
                        else
                            -- Hang chưa có trứng và không có rương -> Đang cooldown
                            handleCaveCooldown(targetCave, hrp)
                        end

                    -- TRƯỜNG HỢP 2C: KHÔNG BẬT MỞ TRỨNG HOẶC HANG ĐANG COOLDOWN
                    else
                        STATE.IsAttackingCaveChest = false
                        handleCaveCooldown(targetCave, hrp)
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
    -- BỘ CHỐNG AFK & AUTO RECONNECT 4 LỚP (BULLETPROOF ANTI-AFK ENGINE)
    -- ========================================================
    local VIM
    pcall(function()
        VIM = game:GetService("VirtualInputManager")
    end)

    -- Lớp 1: Bắt sự kiện Idled dự phòng nếu getconnections chưa tắt kịp
    pcall(function()
        Player.Idled:Connect(function()
            if STATE.AntiAFK and _G.PS99_SUMMIT_RUNNING then
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
        end)
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
        GuiService.ErrorMessageChanged:Connect(function()
            if GuiService:GetErrorCode().Value > 0 then
                triggerReconnect("Mã lỗi mạng: " .. tostring(GuiService:GetErrorCode().Value))
            end
        end)
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
                lblAction.Text = STATE.CurrentAction
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
        if STATE.ExecuteAlert then
            local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            local posStr = hrp and string.format("Vector3.new(%.1f, %.1f, %.1f)", hrp.Position.X, hrp.Position.Y, hrp.Position.Z) or "Chưa xác định"
            local desc = string.format(
                "🟢 **Script đã khởi động và hoạt động thành công!**\n\n" ..
                "👤 **Tài khoản:** `%s`\n" ..
                "📍 **Vị trí hiện tại:** `%s`\n" ..
                "⛰️ **Hang mục tiêu:** `Hang %s`\n" ..
                "👹 **Auto Săn Yeti:** `%s`\n" ..
                "📦 **Auto Phá Rương Hang:** `%s`\n" ..
                "🥚 **Auto Mở Trứng Hang:** `%s`\n" ..
                "💰 **Auto Cày Tiền:** `%s`\n" ..
                "🛡️ **Anti-AFK 20m:** `%s`",
                Player.Name,
                posStr,
                tostring(STATE.SelectedCave),
                STATE.AutoYeti and "🟢 BẬT" or "🔴 TẮT",
                STATE.AutoCaveChests and "🟢 BẬT" or "🔴 TẮT",
                STATE.AutoHatch and "🟢 BẬT" or "🔴 TẮT",
                STATE.AutoFarmMoney and "🟢 BẬT" or "🔴 TẮT",
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
