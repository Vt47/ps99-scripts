--========================================================================
-- PS99 DIAGNOSTIC SCANNER & DEBUGGER TOOL
-- Quét toàn bộ Breakables, Boss Yeti, GUI và Trứng trong game
-- Tự động gửi kết quả về Discord Webhook và copy vào Clipboard
--========================================================================

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Player = Players.LocalPlayer

local WEBHOOK = "https://discord.com/api/webhooks/1557705516178874429/DSxD6hH0VRjmXxBB44kQVM3VDhNvUwTp7h4uTCCtZK1k4vOLyOxLtjAfwxK2mCSS0MFb"
local req = request or http_request or (syn and syn.request) or (http and http.request)

local logLines = {}
local function log(str)
    table.insert(logLines, str)
    print("[PS99 Debug] " .. str)
end

log("=== BẮT ĐẦU QUÉT DỮ LIỆU PS99 ===")
log("Tài khoản: " .. Player.Name)
local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
if hrp then
    log(string.format("Tọa độ hiện tại: Vector3.new(%.1f, %.1f, %.1f)", hrp.Position.X, hrp.Position.Y, hrp.Position.Z))
end

-- 1. QUÉT TẤT CẢ CÁC GUI LIÊN QUAN ĐẾN YETI, BOSS, RƯƠNG HANG & TRỨNG
log("\n--- 1. CÁC GUI TRÊN MÀN HÌNH (BOSS, HANG, RƯƠNG, TRỨNG, COOLDOWN) ---")
local foundGuiCount = 0
for _, g in pairs(Player.PlayerGui:GetDescendants()) do
    if (g:IsA("TextLabel") or g:IsA("TextButton")) and g.Visible and g.Text ~= "" then
        local t = string.lower(g.Text)
        if string.find(t, "yeti") or string.find(t, "returns") or string.find(t, "team up")
           or string.find(t, "damage") or string.find(t, "again in") or string.find(t, "chest")
           or string.find(t, "trail") or string.find(t, "egg") or string.find(t, "luck")
           or string.find(t, "hatch") or string.find(t, "cave") or string.find(t, "unlock") then
            foundGuiCount = foundGuiCount + 1
            log(string.format("• GUI [%s]: \"%s\"", g.Name, g.Text))
            log(string.format("  Parent: %s", g.Parent and g.Parent.Name or "None"))
        end
    end
end
if foundGuiCount == 0 then log("Không có GUI nào liên quan trên màn hình.") end

-- 2. QUÉT CÁC BREAKABLES GẦN BẠN
log("\n--- 2. DANH SÁCH BREAKABLES TRONG BÁN KÍNH 180 STUDS ---")
local Things = workspace:FindFirstChild("__THINGS")
local Breakables = Things and Things:FindFirstChild("Breakables")
local bCount = 0
if Breakables then
    for _, b in pairs(Breakables:GetChildren()) do
        local part = b:IsA("BasePart") and b or (b:IsA("Model") and (b.PrimaryPart or b:FindFirstChildWhichIsA("BasePart", true)))
        local dist = (part and hrp) and (part.Position - hrp.Position).Magnitude or 9999
        if dist < 180 then
            bCount = bCount + 1
            log(string.format("• Breakable: \"%s\" (Cách: %.1f studs)", b.Name, dist))
            for k, v in pairs(b:GetAttributes()) do
                log(string.format("   - %s = %s", tostring(k), tostring(v)))
            end
        end
    end
    log(string.format("Tổng cộng: %d breakable gần bạn.", bCount))
else
    log("Không tìm thấy workspace.__THINGS.Breakables")
end

-- 3. QUÉT TRỨNG (EGGS) VÀ CÁC FOLDER TRONG __THINGS
log("\n--- 3. THƯ MỤC TRONG __THINGS & DANH SÁCH TRỨNG ---")
if Things then
    local tFolders = {}
    for _, ch in pairs(Things:GetChildren()) do
        table.insert(tFolders, ch.Name)
    end
    log("• Folders trong __THINGS: " .. table.concat(tFolders, ", "))
end

local eggFoundTotal = 0
-- Quét các folder trứng có thể có trong __THINGS
local possibleEggFolders = { "Eggs", "CustomEggs", "EggStands", "Instances" }
for _, fName in ipairs(possibleEggFolders) do
    local f = Things and Things:FindFirstChild(fName)
    if f then
        for _, egg in pairs(f:GetChildren()) do
            local part = egg:IsA("BasePart") and egg or (egg:IsA("Model") and (egg.PrimaryPart or egg:FindFirstChildWhichIsA("BasePart", true)))
            local dist = (part and hrp) and (part.Position - hrp.Position).Magnitude or 9999
            if dist < 180 then
                eggFoundTotal = eggFoundTotal + 1
                log(string.format("• Trứng trong [%s]: \"%s\" (Cách: %.1f studs)", fName, egg.Name, dist))
                for k, v in pairs(egg:GetAttributes()) do
                    log(string.format("     %s = %s", tostring(k), tostring(v)))
                end
            end
        end
    end
end

-- Quét toàn bộ Workspace tìm Model hoặc Part liên quan đến Trứng / Chest / Trail trong 150 studs
for _, obj in pairs(workspace:GetDescendants()) do
    if (obj:IsA("Model") or obj:IsA("BasePart")) and hrp then
        local lName = string.lower(obj.Name)
        if (string.find(lName, "egg") or string.find(lName, "trail") or string.find(lName, "summit")) and not string.find(lName, "anim") then
            local part = obj:IsA("BasePart") and obj or (obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)))
            local dist = part and (part.Position - hrp.Position).Magnitude or 9999
            if dist < 100 then
                log(string.format("• Workspace Object: \"%s\" (Class: %s, Cách: %.1f studs, Parent: %s)", obj.Name, obj.ClassName, dist, obj.Parent and obj.Parent.Name or "nil"))
            end
        end
    end
end

-- Quét ProximityPrompts gần bạn (để biết nút bấm tương tác mở trứng / hang)
for _, pp in pairs(workspace:GetDescendants()) do
    if pp:IsA("ProximityPrompt") and pp.Parent and hrp then
        local pPart = pp.Parent:IsA("BasePart") and pp.Parent or (pp.Parent:IsA("Model") and (pp.Parent.PrimaryPart or pp.Parent:FindFirstChildWhichIsA("BasePart", true)))
        local dist = pPart and (pPart.Position - hrp.Position).Magnitude or 9999
        if dist < 80 then
            log(string.format("• Nút bấm ProximityPrompt: Action=\"%s\", Object=\"%s\" (Cách: %.1f studs, Parent: %s)", pp.ActionText, pp.ObjectText, dist, pp.Parent.Name))
        end
    end
end

-- Quét Directory.Eggs trong ReplicatedStorage nếu có
pcall(function()
    local Lib = RS:FindFirstChild("Library")
    local Dir = Lib and Lib:FindFirstChild("Directory")
    if Dir and Dir:FindFirstChild("Eggs") then
        local EggModule = require(Dir.Eggs)
        log("\n--- 4. TÊN CÁC TRỨNG ĐẶC BIỆT TRONG DIRECTORY ---")
        local count = 0
        for eggId, _ in pairs(EggModule) do
            local s = string.lower(tostring(eggId))
            if string.find(s, "diamond") or string.find(s, "mountain") or string.find(s, "trail") or string.find(s, "cave") or string.find(s, "yeti") or string.find(s, "summit") then
                count = count + 1
                log(string.format("• Event Egg ID: \"%s\"", tostring(eggId)))
            end
        end
        if count == 0 then log("Không có egg event nào chứa từ khóa diamond/mountain/trail/cave.") end
    end
end)

local fullLog = table.concat(logLines, "\n")

-- Copy Clipboard
if setclipboard then
    setclipboard(fullLog)
    log("\n=> [THÀNH CÔNG] ĐÃ COPY TOÀN BỘ LOG VÀO BỘ NHỚ TẠM (CLIPBOARD)!")
end

-- Bật popup thông báo
pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "📋 Đã Quét Xong Log!",
        Text = "Đã copy vào Clipboard & gửi về Discord Webhook.",
        Duration = 5
    })
end)

-- Gửi Webhook
if req and WEBHOOK and WEBHOOK ~= "" then
    pcall(function()
        req({
            Url = WEBHOOK,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode({
                username = "PS99 Diagnostic Tool",
                content = "📋 **BÁO CÁO SCAN LOG TỪ GAME**\n```yaml\n" .. string.sub(fullLog, 1, 1900) .. "\n```"
            })
        })
    end)
end
