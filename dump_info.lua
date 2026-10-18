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

local function sendWebhook(rawUrl, bodyContent)
    local fn = request or http_request or (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request)
    if not fn then
        warn("[PS99] Executor không hỗ trợ hàm request() trực tiếp.")
        return false, "No request function"
    end
    
    local targets = {}
    if string.find(rawUrl, "discord%.com") or string.find(rawUrl, "discordapp%.com") then
        table.insert(targets, (string.gsub(string.gsub(rawUrl, "discord%.com", "webhook.lewisakura.moe"), "discordapp%.com", "webhook.lewisakura.moe")))
        table.insert(targets, (string.gsub(string.gsub(rawUrl, "discord%.com", "discord.yeesen.dev"), "discordapp%.com", "discord.yeesen.dev")))
    end
    table.insert(targets, rawUrl)
    
    for _, targetUrl in ipairs(targets) do
        local ok, res = pcall(function()
            return fn({
                Url = targetUrl,
                url = targetUrl,
                Method = "POST",
                method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = bodyContent,
                body = bodyContent
            })
        end)
        if ok and res then
            local status = type(res) == "table" and (res.StatusCode or res.status_code or res.Status) or nil
            if status == 200 or status == 204 or (status == nil and res.Body ~= nil) then
                print("[PS99] Gửi webhook thành công qua: " .. targetUrl)
                return true, targetUrl
            end
        end
        task.wait(0.2)
    end
    return false, "Failed all targets"
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
        local isAvail = false
        pcall(function()
            local Lib = RS:FindFirstChild("Library")
            local Client = Lib and Lib:FindFirstChild("Client")
            local EC = Client and Client:FindFirstChild("EggCmds") and require(Client.EggCmds)
            if EC and EC.IsEggAvailable then
                isAvail = (EC.IsEggAvailable(eggId) == true)
            end
        end)
        if isAvail then
            status = "🟢 MỞ - SẴN SÀNG MỞ TRỨNG: " .. eggId
        else
            status = "🔴 ĐÓNG / COOLDOWN (Trứng đang khóa: " .. eggId .. ")"
        end
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
                    local pPath = bb.Parent and bb.Parent.Name or "None"
                    if bb.Parent and bb.Parent.Parent then pPath = bb.Parent.Parent.Name .. "/" .. pPath end
                    log(string.format("• [World] \"%s\" = \"%s\" (Cách %.1f studs, Nơi: %s)", tl.Name, txt, dist, pPath))
                end
            end
        end
    end
end

-- 3. CHI TIẾT ATTRIBUTES VÀ TRẠNG THÁI CỦA CÁC QUẢ TRỨNG
log("\n[3. CHI TIẾT QUẢ TRỨNG TRONG HANG]")
if CustomEggs then
    for _, egg in pairs(CustomEggs:GetChildren()) do
        local attrs = {}
        for aK, aV in pairs(egg:GetAttributes()) do
            table.insert(attrs, aK .. "=" .. tostring(aV))
        end
        local chList = {}
        for _, ch in pairs(egg:GetChildren()) do
            table.insert(chList, ch.Name)
        end
        log(string.format("• Trứng: %s | Attrs: [%s] | Con: [%s]", egg.Name, table.concat(attrs, ", "), table.concat(chList, ", ")))
    end
end

-- 4. KIỂM TRA TRẠNG THÁI KHÓA/MỞ TRỨNG TỪ EGGCMDS
log("\n[4. KIỂM TRA EGGCMDS: KHÓA HAY MỞ?]")
pcall(function()
    local Lib = RS:FindFirstChild("Library")
    local Client = Lib and Lib:FindFirstChild("Client")
    local EggCmds = Client and Client:FindFirstChild("EggCmds") and require(Client.EggCmds)
    if EggCmds then
        for _, eggName in ipairs({"Frostline Egg", "Diamond Summit Egg"}) do
            local avail = EggCmds.IsEggAvailable and EggCmds.IsEggAvailable(eggName)
            local unlocked = EggCmds.IsUnlocked and EggCmds.IsUnlocked(eggName)
            local locked = EggCmds.IsEggLocked and EggCmds.IsEggLocked(eggName)
            log(string.format("• %s: Available=%s, Unlocked=%s, Locked=%s", eggName, tostring(avail), tostring(unlocked), tostring(locked)))
        end
    end
end)

local fullLog = table.concat(logLines, "\n")
if setclipboard then
    pcall(function()
        setclipboard(fullLog)
        log("\n=> ĐÃ COPY VÀO BỘ NHỚ TẠM!")
    end)
end

local sentOk = false
pcall(function()
    local jsonBody = HttpService:JSONEncode({
        username = "PS99 Quick Scanner",
        embeds = {
            {
                title = "📋 BÁO CÁO NHANH PS99 (HANG & TRỨNG)",
                description = "```yaml\n" .. fullLog .. "\n```",
                color = 3447003,
                footer = { text = "Tài khoản: " .. Player.Name },
                timestamp = DateTime.now():ToIsoDate()
            }
        }
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
