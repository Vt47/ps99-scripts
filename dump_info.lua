--========================================================================
-- PS99 COMPACT CAVE & EGG DIAGNOSTIC TOOL
-- Quét nhanh trạng thái 6 Hang, Trứng, Cooldown & Remotes
-- Hỗ trợ gửi Discord Webhook siêu tương thích & tự động copy Clipboard
--========================================================================

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Player = Players.LocalPlayer

local WEBHOOK = "https://discord.com/api/webhooks/1557705516178874429/DSxD6hH0VRjmXxBB44kQVM3VDhNvUwTp7h4uTCCtZK1k4vOLyOxLtjAfwxK2mCSS0MFb"

local logLines = {}
local function log(str)
    table.insert(logLines, str)
    print("[PS99 Debug] " .. str)
end

local function sendWebhook(url, bodyContent)
    local fn = request or http_request or (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request)
    if not fn then
        warn("[PS99] Executor không hỗ trợ hàm request() trực tiếp.")
        return false, "No request function"
    end
    local payload = {
        Url = url,
        url = url,
        Method = "POST",
        method = "POST",
        Headers = {
            ["Content-Type"] = "application/json",
            ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36"
        },
        headers = {
            ["Content-Type"] = "application/json",
            ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36"
        },
        Body = bodyContent,
        body = bodyContent
    }
    return pcall(function()
        return fn(payload)
    end)
end

log("=== BÁO CÁO NHANH PS99 (CẬP NHẬT TRẠNG THÁI HANG & TRỨNG) ===")
log("Tài khoản: " .. Player.Name)
local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
if hrp then
    log(string.format("Tọa độ hiện tại: Vector3.new(%.1f, %.1f, %.1f)", hrp.Position.X, hrp.Position.Y, hrp.Position.Z))
end

local Things = workspace:FindFirstChild("__THINGS")
local Breakables = Things and Things:FindFirstChild("Breakables")
local CustomEggs = Things and Things:FindFirstChild("CustomEggs")

-- 1. TRẠNG THÁI CẢ 6 HANG NÚI
log("\n[1. TRẠNG THÁI 6 HANG NÚI]")
for caveNum = 1, 6 do
    local chestName, eggId = nil, nil
    if Breakables then
        local tArea = "trail" .. tostring(caveNum)
        for _, b in pairs(Breakables:GetChildren()) do
            local areaId = string.lower(tostring(b:GetAttribute("AreaID") or ""))
            local bId = string.lower(tostring(b:GetAttribute("BreakableID") or ""))
            if areaId == tArea or string.find(bId, tArea) or (string.find(bId, "trail") and string.find(bId, tostring(caveNum))) then
                chestName = b.Name .. " (" .. bId .. ")"
                break
            end
        end
    end

    if CustomEggs then
        for _, egg in pairs(CustomEggs:GetChildren()) do
            local trailNum = egg:GetAttribute("DM_TrailEgg")
            if trailNum and tonumber(trailNum) == caveNum then
                eggId = tostring(egg:GetAttribute("DM_EggId") or egg.Name)
                break
            end
        end
    end

    local status = "🔴 ĐÓNG (Cooldown / Chờ mở)"
    if chestName then
        status = "🟢 MỞ - CÓ RƯƠNG: " .. chestName
    elseif eggId then
        status = "🟢 MỞ - SẴN SÀNG MỞ TRỨNG: " .. eggId
    end
    log(string.format("• Hang %d: %s", caveNum, status))
end

-- 2. ĐỒNG HỒ ĐẾM NGƯỢC THỜI GIAN (COOLDOWN)
log("\n[2. THỜI GIAN ĐẾM NGƯỢC / COOLDOWN PHÁT HIỆN ĐƯỢC]")
local timerFound = 0
for _, bb in pairs(workspace:GetDescendants()) do
    if (bb:IsA("BillboardGui") or bb:IsA("SurfaceGui")) and bb.Enabled then
        for _, tl in pairs(bb:GetDescendants()) do
            if tl:IsA("TextLabel") and tl.Visible and tl.Text ~= "" then
                local txt = tl.Text
                local lTxt = string.lower(txt)
                if string.find(txt, "%d+:%d+") or string.find(lTxt, "cooldown") or string.find(lTxt, "returns in") or string.find(lTxt, "opens in") or string.find(lTxt, "closes in") then
                    timerFound = timerFound + 1
                    local pPart = bb.Adornee or bb.Parent
                    local dist = (pPart and pPart:IsA("BasePart") and hrp) and (pPart.Position - hrp.Position).Magnitude or -1
                    log(string.format("• [World] \"%s\" = \"%s\" (Cách %.1f studs)", tl.Name, txt, dist))
                end
            end
        end
    end
end

for _, g in pairs(Player.PlayerGui:GetDescendants()) do
    if g:IsA("TextLabel") and g.Visible and g.Text ~= "" then
        local txt = g.Text
        local lTxt = string.lower(txt)
        if string.find(txt, "%d+:%d+") and (string.find(lTxt, "yeti") or string.find(lTxt, "trail") or string.find(lTxt, "cave") or string.find(lTxt, "cooldown") or string.find(lTxt, "again in") or string.find(lTxt, "returns in")) then
            timerFound = timerFound + 1
            log(string.format("• [Screen] \"%s\" = \"%s\"", g.Name, txt))
        end
    end
end
if timerFound == 0 then log("• Không phát hiện đồng hồ đếm ngược nào lúc này.") end

-- 3. REMOTES & MODULE MỞ TRỨNG
log("\n[3. KIỂM TRA MODULE MỞ TRỨNG]")
pcall(function()
    local Lib = RS:FindFirstChild("Library")
    local Client = Lib and Lib:FindFirstChild("Client")
    if Client then
        if Client:FindFirstChild("EggCmds") then
            local EggCmds = require(Client.EggCmds)
            local kList = {}
            for k, _ in pairs(EggCmds) do table.insert(kList, tostring(k)) end
            log("• EggCmds keys: " .. table.concat(kList, ", "))
        else
            log("• Không tìm thấy Library.Client.EggCmds")
        end
        if Client:FindFirstChild("Network") then
            local Net = require(Client.Network)
            local kList = {}
            for k, _ in pairs(Net) do table.insert(kList, tostring(k)) end
            log("• Network keys: " .. table.concat(kList, ", "))
        end
    end
end)

-- 4. TEST GỌI THỬ MỞ TRỨNG THỰC TẾ TRÊN QUẢ TRỨNG HANG 5
log("\n[4. TEST GỌI MỞ TRỨNG HANG 5: Frostline Egg]")
pcall(function()
    local Lib = RS:FindFirstChild("Library")
    local Client = Lib and Lib:FindFirstChild("Client")
    local Network = Client and Client:FindFirstChild("Network") and require(Client.Network)
    local EggCmds = Client and Client:FindFirstChild("EggCmds") and require(Client.EggCmds)

    if EggCmds then
        for _, fnName in ipairs({"Purchase", "Open", "RequestPurchase", "Hatch"}) do
            if EggCmds[fnName] then
                local s, r = pcall(function() return EggCmds[fnName]("Frostline Egg", 1) end)
                log(string.format("• EggCmds.%s: %s, res=%s", fnName, tostring(s), tostring(r)))
            end
        end
    end

    if Network and Network.Invoke then
        for _, cName in ipairs({"Eggs_RequestPurchase", "CustomEggs_Purchase", "CustomEggs_RequestPurchase", "buy egg", "Eggs: Request Hatch"}) do
            local s, r1 = pcall(function() return Network.Invoke(cName, "Frostline Egg", 1) end)
            log(string.format("• Network.Invoke(\"%s\"): %s, res=%s", cName, tostring(s), tostring(r1)))
        end
    end
end)

local fullLog = table.concat(logLines, "\n")
if setclipboard then
    setclipboard(fullLog)
    log("\n=> ĐÃ COPY VÀO BỘ NHỚ TẠM!")
end

local sentOk = false
pcall(function()
    local jsonBody = HttpService:JSONEncode({
        username = "PS99 Quick Scanner",
        content = "📋 **BÁO CÁO NHANH PS99**\n```yaml\n" .. fullLog .. "\n```"
    })
    sentOk = sendWebhook(WEBHOOK, jsonBody)
end)

pcall(function()
    if sentOk then
        StarterGui:SetCore("SendNotification", {
            Title = "✅ Đã Gửi Discord!",
            Text = "Đã gửi log thành công vào Discord của bạn!",
            Duration = 5
        })
    else
        StarterGui:SetCore("SendNotification", {
            Title = "📋 Đã Copy Clipboard!",
            Text = "Đã copy log. Bạn chỉ cần dán vào chat!",
            Duration = 5
        })
    end
end)
