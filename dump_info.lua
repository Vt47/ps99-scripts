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

-- 1. QUÉT TẤT CẢ CÁC GUI LIÊN QUAN ĐẾN YETI & BOSS
log("\n--- 1. CÁC GUI TRÊN MÀN HÌNH LIÊN QUAN ĐẾN YETI / BOSS ---")
local foundGuiCount = 0
for _, g in pairs(Player.PlayerGui:GetDescendants()) do
    if (g:IsA("TextLabel") or g:IsA("TextButton")) and g.Visible and g.Text ~= "" then
        local t = string.lower(g.Text)
        if string.find(t, "yeti") or string.find(t, "returns") or string.find(t, "team up") or string.find(t, "damage") or string.find(t, "again in") then
            foundGuiCount = foundGuiCount + 1
            log(string.format("• GUI [%s]: \"%s\"", g.Name, g.Text))
            log(string.format("  Parent: %s", g.Parent and g.Parent.Name or "None"))
        end
    end
end
if foundGuiCount == 0 then log("Không có GUI nào chứa từ khóa Yeti.") end

-- 2. QUÉT CÁC BREAKABLES GẦN BẠN
log("\n--- 2. DANH SÁCH BREAKABLES TRONG BÁN KÍNH 120 STUDS ---")
local Things = workspace:FindFirstChild("__THINGS")
local Breakables = Things and Things:FindFirstChild("Breakables")
local bCount = 0
if Breakables then
    for _, b in pairs(Breakables:GetChildren()) do
        local part = b:IsA("BasePart") and b or (b:IsA("Model") and (b.PrimaryPart or b:FindFirstChildWhichIsA("BasePart")))
        local dist = (part and hrp) and (part.Position - hrp.Position).Magnitude or 9999
        if dist < 120 then
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

-- 3. QUÉT TRỨNG (EGGS)
log("\n--- 3. DANH SÁCH TRỨNG GẦN BẠN ---")
local EggsFolder = Things and Things:FindFirstChild("Eggs")
local eggCount = 0
if EggsFolder then
    for _, egg in pairs(EggsFolder:GetChildren()) do
        local part = egg:IsA("BasePart") and egg or (egg:IsA("Model") and (egg.PrimaryPart or egg:FindFirstChildWhichIsA("BasePart")))
        local dist = (part and hrp) and (part.Position - hrp.Position).Magnitude or 9999
        if dist < 150 then
            eggCount = eggCount + 1
            log(string.format("• Trứng: \"%s\" (Cách: %.1f studs)", egg.Name, dist))
        end
    end
    log(string.format("Tổng cộng: %d quả trứng gần bạn.", eggCount))
else
    log("Không tìm thấy workspace.__THINGS.Eggs")
end

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
