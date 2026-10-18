--========================================================================
-- PS99 DEEP COMPREHENSIVE DIAGNOSTIC TOOL (CẬP NHẬT TOÀN DIỆN)
-- Quét chuyên sâu toàn bộ thông tin Hang, Rương, Trứng, Remotes, Save & Scripts
-- Tự động chia nhỏ gửi Discord Webhook đầy đủ + Lưu file + Copy Clipboard
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
    print("[PS99 Dump] " .. str)
end

-- HÀM GỬI HTTP WEBHOOK ĐA NỀN TẢNG
local function rawHttpRequest(targetUrl, bodyContent)
    local fn = request or http_request or (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request)
    if not fn then return false, "No request function" end
    
    local ok, res = pcall(function()
        return fn({
            Url = targetUrl,
            url = targetUrl,
            Method = "POST",
            method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            headers = { ["Content-Type"] = "application/json" },
            Body = bodyContent,
            body = bodyContent
        })
    end)
    if ok and res then
        local status = type(res) == "table" and (res.StatusCode or res.status_code or res.Status) or nil
        if status == 200 or status == 204 or (status == nil and res.Body ~= nil) then
            return true
        end
    end
    return false
end

local function sendWebhookDirect(rawUrl, bodyContent)
    local targets = {}
    if string.find(rawUrl, "discord%.com") or string.find(rawUrl, "discordapp%.com") then
        table.insert(targets, (string.gsub(string.gsub(rawUrl, "discord%.com", "webhook.lewisakura.moe"), "discordapp%.com", "webhook.lewisakura.moe")))
        table.insert(targets, (string.gsub(string.gsub(rawUrl, "discord%.com", "discord.yeesen.dev"), "discordapp%.com", "discord.yeesen.dev")))
    end
    table.insert(targets, rawUrl)
    
    for _, targetUrl in ipairs(targets) do
        local ok = rawHttpRequest(targetUrl, bodyContent)
        if ok then return true, targetUrl end
        task.wait(0.2)
    end
    return false, "Failed all targets"
end

-- HÀM CHIA NHỎ DỮ LIỆU ĐỂ GỬI DISCORD KHÔNG BỊ TRUNCATE / BAD REQUEST
local function splitIntoChunks(str, maxLen)
    maxLen = maxLen or 1700
    local chunks = {}
    local current = ""
    for line in string.gmatch(str .. "\n", "([^\n]*)\n") do
        if #line > maxLen then
            if current ~= "" then
                table.insert(chunks, current)
                current = ""
            end
            for i = 1, #line, maxLen do
                table.insert(chunks, string.sub(line, i, i + maxLen - 1))
            end
        elseif #current + #line + 1 > maxLen then
            table.insert(chunks, current)
            current = line
        else
            current = (current == "") and line or (current .. "\n" .. line)
        end
    end
    if current ~= "" then
        table.insert(chunks, current)
    end
    return chunks
end

local function sendChunkedWebhook(rawUrl, fullContent)
    local chunks = splitIntoChunks(fullContent, 1700)
    local total = #chunks
    log(string.format("==> Đang gửi dữ liệu về Discord (%d phần)...", total))
    
    for i, chunk in ipairs(chunks) do
        local jsonBody = HttpService:JSONEncode({
            username = "PS99 Deep Dump (" .. tostring(i) .. "/" .. tostring(total) .. ")",
            embeds = {
                {
                    title = "📋 BÁO CÁO TOÀN DIỆN PS99 (Phần " .. i .. "/" .. total .. ")",
                    description = "```yaml\n" .. chunk .. "\n```",
                    color = (i == 1 and 3447003 or (i == total and 5763719 or 9807270)),
                    footer = { text = string.format("Phần %d/%d • Tài khoản: %s", i, total, Player.Name) },
                    timestamp = DateTime.now():ToIsoDate()
                }
            }
        })
        sendWebhookDirect(rawUrl, jsonBody)
        task.wait(0.4)
    end
end

-- BẮT ĐẦU THU THẬP THÔNG TIN
log("==================================================================")
log("             BÁO CÁO TOÀN DIỆN PS99: HANG, RƯƠNG & TRỨNG         ")
log("==================================================================")
log("Thời gian tạo: " .. os.date("!%Y-%m-%d %H:%M:%S UTC"))
log("Tài khoản: " .. Player.Name .. " (UserId: " .. tostring(Player.UserId) .. ")")
log("DisplayName: " .. tostring(Player.DisplayName))
log("PlaceId: " .. tostring(game.PlaceId) .. " | JobId: " .. tostring(game.JobId))

local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
if hrp then
    log(string.format("Tọa độ hiện tại: Vector3.new(%.1f, %.1f, %.1f)", hrp.Position.X, hrp.Position.Y, hrp.Position.Z))
    local cf = hrp.CFrame
    log(string.format("CFrame hiện tại: CFrame.new(%.1f, %.1f, %.1f)", cf.X, cf.Y, cf.Z))
end

-- LẤY REPLICATEDSTORAGE MODULES
local Library, Client, Directory, Save, EggCmds, Network
pcall(function()
    Library = RS:FindFirstChild("Library") or RS:WaitForChild("Library", 3)
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
if not Network and RS:FindFirstChild("Network") then Network = RS.Network end

-- 1. SAVE DATA / TIỀN TỆ & THÔNG SỐ NGƯỜI CHƠI
log("\n[1. SAVE DATA & THÔNG SỐ NGƯỜI CHƠI]")
pcall(function()
    if Save and Save.Get then
        local s = Save.Get()
        if s then
            log("• Diamonds: " .. tostring(s.Diamonds or 0))
            log("• Coins: " .. tostring(s.Coins or 0))
            
            -- Quét các key liên quan đến Diamond Mountain, Trail, Caves, Eggs
            local interestingKeys = {}
            for k, v in pairs(s) do
                local lK = string.lower(tostring(k))
                if string.find(lK, "trail") or string.find(lK, "cave") or string.find(lK, "mountain")
                   or string.find(lK, "summit") or string.find(lK, "diamond") or string.find(lK, "egg")
                   or string.find(lK, "hatch") or string.find(lK, "cooldown") or string.find(lK, "chest") then
                    table.insert(interestingKeys, k)
                end
            end
            table.sort(interestingKeys)
            log("• Các Keys Save liên quan được tìm thấy: [" .. table.concat(interestingKeys, ", ") .. "]")
            
            for _, k in ipairs(interestingKeys) do
                local val = s[k]
                if type(val) == "table" then
                    local preview = {}
                    local count = 0
                    for subK, subV in pairs(val) do
                        count = count + 1
                        if count <= 6 then
                            table.insert(preview, tostring(subK) .. "=" .. tostring(subV))
                        end
                    end
                    log("  - Save." .. k .. " (Size " .. count .. "): [" .. table.concat(preview, ", ") .. (count > 6 and "..." or "") .. "]")
                else
                    log("  - Save." .. k .. " = " .. tostring(val))
                end
            end
        end
    else
        log("• Không thể lấy Save.Get()")
    end
end)

-- 2. TOÀN BỘ REMOTES TRONG REPLICATEDSTORAGE LIÊN QUAN
log("\n[2. REMOTES TRONG REPLICATEDSTORAGE.NETWORK]")
pcall(function()
    local netFolder = RS:FindFirstChild("Network")
    if netFolder then
        local remotesFound = {}
        for _, rem in pairs(netFolder:GetChildren()) do
            local lName = string.lower(rem.Name)
            if string.find(lName, "egg") or string.find(lName, "hatch") or string.find(lName, "purchase")
               or string.find(lName, "buy") or string.find(lName, "breakable") or string.find(lName, "chest")
               or string.find(lName, "damage") or string.find(lName, "hit") or string.find(lName, "trail")
               or string.find(lName, "cave") or string.find(lName, "mountain") or string.find(lName, "summit")
               or string.find(lName, "roll") or string.find(lName, "claim") or string.find(lName, "reward") then
                table.insert(remotesFound, string.format("• [%s] %s", rem.ClassName, rem.Name))
            end
        end
        table.sort(remotesFound)
        log("Tổng cộng tìm thấy " .. #remotesFound .. " Remotes:")
        for _, rStr in ipairs(remotesFound) do
            log("  " .. rStr)
        end
    else
        log("• Không tìm thấy ReplicatedStorage.Network")
    end
end)

-- 3. MODULE EGGCMDS & THƯ VIỆN DIRECTORY
log("\n[3. KIỂM TRA MODULE EGGCMDS & DIRECTORY]")
pcall(function()
    if EggCmds then
        local funcNames = {}
        for k, v in pairs(EggCmds) do
            table.insert(funcNames, k .. " (" .. type(v) .. ")")
        end
        table.sort(funcNames)
        log("• EggCmds exports: [" .. table.concat(funcNames, ", ") .. "]")

        for _, eggName in ipairs({"Frostline Egg", "Diamond Summit Egg", "Eagle Crag Egg", "Candy Cane Egg"}) do
            local avail = EggCmds.IsEggAvailable and EggCmds.IsEggAvailable(eggName)
            local unlocked = EggCmds.IsUnlocked and EggCmds.IsUnlocked(eggName)
            local locked = EggCmds.IsEggLocked and EggCmds.IsEggLocked(eggName)
            local canAfford = EggCmds.CanAfford and EggCmds.CanAfford(eggName)
            log(string.format("  - %s: Available=%s, Unlocked=%s, Locked=%s, CanAfford=%s",
                eggName, tostring(avail), tostring(unlocked), tostring(locked), tostring(canAfford)))
        end
    else
        log("• Không require được EggCmds")
    end

    if Directory then
        if Directory:FindFirstChild("Eggs") then
            local eggDir = require(Directory.Eggs)
            local eggKeys = {}
            for k, _ in pairs(eggDir) do
                table.insert(eggKeys, tostring(k))
            end
            table.sort(eggKeys)
            log("• Directory.Eggs tổng cộng: " .. #eggKeys .. " loại trứng")
            local dmEggs = {}
            for _, k in ipairs(eggKeys) do
                local lK = string.lower(k)
                if string.find(lK, "diamond") or string.find(lK, "frost") or string.find(lK, "crag") or string.find(lK, "summit") then
                    table.insert(dmEggs, k)
                end
            end
            log("  - Trứng Đỉnh Núi tìm thấy: [" .. table.concat(dmEggs, ", ") .. "]")
        end
        if Directory:FindFirstChild("Breakables") then
            local breakDir = require(Directory.Breakables)
            local dmBreak = {}
            for k, _ in pairs(breakDir) do
                local lK = string.lower(tostring(k))
                if string.find(lK, "trail") or string.find(lK, "mountain") or string.find(lK, "summit") or string.find(lK, "cave") then
                    table.insert(dmBreak, tostring(k))
                end
            end
            log("• Directory.Breakables Đỉnh Núi: [" .. table.concat(dmBreak, ", ") .. "]")
        end
    end
end)

-- 4. PHÂN TÍCH RƯƠNG TRONG WORKSPACE (__THINGS.Breakables)
local Things = workspace:FindFirstChild("__THINGS")
local Breakables = Things and Things:FindFirstChild("Breakables")
local CustomEggs = Things and Things:FindFirstChild("CustomEggs")

log("\n[4. PHÂN TÍCH CHI TIẾT RƯƠNG (WORKSPACE.__THINGS.Breakables)]")
if Breakables then
    local allB = Breakables:GetChildren()
    log("Tổng số Breakables đang có: " .. #allB)
    local trailChests = {}
    for _, b in pairs(allB) do
        local areaId = tostring(b:GetAttribute("AreaID") or "")
        local bId = tostring(b:GetAttribute("BreakableID") or "")
        local lA = string.lower(areaId)
        local lB = string.lower(bId)
        
        local isNear = false
        local bPos = nil
        pcall(function()
            local p = b:IsA("BasePart") and b or b:FindFirstChildWhichIsA("BasePart", true)
            if p then bPos = p.Position end
        end)
        local dist = (bPos and hrp) and (bPos - hrp.Position).Magnitude or 999999

        if string.find(lA, "trail") or string.find(lB, "trail") or string.find(lB, "diamond") or string.find(lB, "chest") or dist < 250 then
            table.insert(trailChests, {
                obj = b,
                id = b.Name,
                areaId = areaId,
                bId = bId,
                dist = dist,
                pos = bPos
            })
        end
    end

    table.sort(trailChests, function(a, b) return a.dist < b.dist end)
    log("Số rương Đỉnh Núi / Rương gần phát hiện: " .. #trailChests)
    for i, c in ipairs(trailChests) do
        local attrs = {}
        for aK, aV in pairs(c.obj:GetAttributes()) do
            table.insert(attrs, aK .. "=" .. tostring(aV))
        end
        local children = {}
        for _, ch in pairs(c.obj:GetChildren()) do
            table.insert(children, ch.Name .. " (" .. ch.ClassName .. ")")
        end
        local posStr = c.pos and string.format("Vector3.new(%.1f, %.1f, %.1f)", c.pos.X, c.pos.Y, c.pos.Z) or "Nil"
        log(string.format("• [#%d] UID: %s | BreakableID: %s | AreaID: %s | Cách: %.1f studs", i, c.id, c.bId, c.areaId, c.dist))
        log("  - Pos: " .. posStr)
        log("  - Attributes: [" .. table.concat(attrs, ", ") .. "]")
        log("  - Children: [" .. table.concat(children, ", ") .. "]")
    end
else
    log("• Không tìm thấy workspace.__THINGS.Breakables")
end

-- 5. PHÂN TÍCH TRỨNG TRONG HANG (__THINGS.CustomEggs)
log("\n[5. PHÂN TÍCH CHI TIẾT TRỨNG (WORKSPACE.__THINGS.CustomEggs)]")
if CustomEggs then
    local allEggs = CustomEggs:GetChildren()
    log("Tổng số CustomEggs: " .. #allEggs)
    for i, egg in ipairs(allEggs) do
        local eggPos = nil
        pcall(function()
            local p = egg:IsA("BasePart") and egg or egg:FindFirstChildWhichIsA("BasePart", true)
            if p then eggPos = p.Position end
        end)
        local dist = (eggPos and hrp) and (eggPos - hrp.Position).Magnitude or 999999
        local posStr = eggPos and string.format("Vector3.new(%.1f, %.1f, %.1f)", eggPos.X, eggPos.Y, eggPos.Z) or "Nil"

        local attrs = {}
        for aK, aV in pairs(egg:GetAttributes()) do
            table.insert(attrs, aK .. "=" .. tostring(aV))
        end

        local textLabelsFound = {}
        local promptsFound = {}
        pcall(function()
            for _, desc in pairs(egg:GetDescendants()) do
                if desc:IsA("TextLabel") and desc.Visible and desc.Text ~= "" then
                    table.insert(textLabelsFound, desc.Name .. "='" .. desc.Text .. "' (Parent: " .. desc.Parent.Name .. ")")
                elseif desc:IsA("ProximityPrompt") then
                    table.insert(promptsFound, string.format("Prompt: Action='%s', Object='%s', Enabled=%s, Hold=%.1f, Dist=%.1f (Parent: %s)",
                        desc.ActionText, desc.ObjectText, tostring(desc.Enabled), desc.HoldDuration, desc.MaxActivationDistance, desc.Parent.Name))
                end
            end
        end)

        local childList = {}
        for _, ch in pairs(egg:GetChildren()) do
            table.insert(childList, ch.Name .. " (" .. ch.ClassName .. ")")
        end

        log(string.format("• [#%d] Tên/UID: %s | Cách: %.1f studs", i, egg.Name, dist))
        log("  - Pos: " .. posStr)
        log("  - Attributes: [" .. table.concat(attrs, ", ") .. "]")
        log("  - Children: [" .. table.concat(childList, ", ") .. "]")
        if #textLabelsFound > 0 then
            log("  - TextLabels: [" .. table.concat(textLabelsFound, " | ") .. "]")
        end
        if #promptsFound > 0 then
            log("  - ProximityPrompts: [" .. table.concat(promptsFound, " | ") .. "]")
        end
    end
else
    log("• Không tìm thấy workspace.__THINGS.CustomEggs")
end

-- 6. TỔNG HỢP TRẠNG THÁI 6 HANG NÚI KIM CƯƠNG
log("\n[6. TRẠNG THÁI 6 HANG NÚI KIM CƯƠNG]")
for caveNum = 1, 6 do
    local chestInfo = "Không có rương"
    if Breakables then
        local tArea = "trail" .. tostring(caveNum)
        for _, b in pairs(Breakables:GetChildren()) do
            local areaId = string.lower(tostring(b:GetAttribute("AreaID") or ""))
            local bId = string.lower(tostring(b:GetAttribute("BreakableID") or ""))
            if areaId == tArea or string.find(bId, tArea) or (string.find(bId, "trail") and string.find(bId, tostring(caveNum))) then
                chestInfo = b.Name .. " (" .. bId .. ", Area=" .. areaId .. ")"
                break
            end
        end
    end

    local eggInfo = "Không có trứng"
    if CustomEggs then
        for _, egg in pairs(CustomEggs:GetChildren()) do
            local trailNum = egg:GetAttribute("DM_TrailEgg")
            if trailNum and tonumber(trailNum) == caveNum then
                local eggId = tostring(egg:GetAttribute("DM_EggId") or egg.Name)
                eggInfo = egg.Name .. " (" .. eggId .. ")"
                break
            end
        end
    end

    log(string.format("• Hang %d:", caveNum))
    log("  - Rương: " .. chestInfo)
    log("  - Trứng: " .. eggInfo)
end

-- 7. BIỂN BÁO & ĐỒNG HỒ ĐẾM NGƯỢC (WORLD SIGNS & TIMERS)
log("\n[7. TOÀN BỘ BIỂN BÁO & ĐỒNG HỒ ĐẾM NGƯỢC GẦN ĐÂY]")
local signCount = 0
for _, bb in pairs(workspace:GetDescendants()) do
    if (bb:IsA("BillboardGui") or bb:IsA("SurfaceGui")) and bb.Enabled then
        for _, tl in pairs(bb:GetDescendants()) do
            if tl:IsA("TextLabel") and tl.Visible and tl.Text ~= "" then
                local txt = tl.Text
                local lTxt = string.lower(txt)
                local pPart = bb.Adornee or bb.Parent
                local dist = (pPart and pPart:IsA("BasePart") and hrp) and (pPart.Position - hrp.Position).Magnitude or -1
                
                -- Lấy tất cả text có chứa số/thời gian hoặc trong bán kính 400 studs
                if string.find(txt, "%d+:%d+") or string.find(lTxt, "cooldown") or string.find(lTxt, "roll")
                   or string.find(lTxt, "returns") or string.find(lTxt, "opens") or string.find(lTxt, "closes")
                   or string.find(lTxt, "boss") or string.find(lTxt, "chest") or string.find(lTxt, "unlocked")
                   or (dist >= 0 and dist < 300 and string.find(lTxt, "trail")) then
                    signCount = signCount + 1
                    local pPath = bb.Parent and bb.Parent.Name or "None"
                    if bb.Parent and bb.Parent.Parent then pPath = bb.Parent.Parent.Name .. "/" .. pPath end
                    if bb.Parent and bb.Parent.Parent and bb.Parent.Parent.Parent then
                        pPath = bb.Parent.Parent.Parent.Name .. "/" .. pPath
                    end
                    log(string.format("• \"%s\" = \"%s\" (Cách %.1f studs, Path: %s)", tl.Name, txt, dist, pPath))
                end
            end
        end
    end
end
log("Tổng số biển báo / timer tìm thấy: " .. signCount)

-- 8. TẤT CẢ PROXIMITYPROMPT TRONG BÁN KÍNH 350 STUDS
log("\n[8. TẤT CẢ PROXIMITYPROMPT GẦN NHÂN VẬT (<350 STUDS)]")
local promptCount = 0
for _, desc in pairs(workspace:GetDescendants()) do
    if desc:IsA("ProximityPrompt") then
        local pPart = desc.Parent
        local pPos = nil
        if pPart and pPart:IsA("BasePart") then
            pPos = pPart.Position
        elseif pPart and pPart:IsA("Model") and pPart.PrimaryPart then
            pPos = pPart.PrimaryPart.Position
        elseif pPart then
            local bp = pPart:FindFirstChildWhichIsA("BasePart", true)
            if bp then pPos = bp.Position end
        end
        local dist = (pPos and hrp) and (pPos - hrp.Position).Magnitude or 999999
        if dist < 350 then
            promptCount = promptCount + 1
            local pathStr = desc.Parent and desc.Parent.Name or "None"
            if desc.Parent and desc.Parent.Parent then pathStr = desc.Parent.Parent.Name .. "/" .. pathStr end
            log(string.format("• Prompt: Action='%s', Object='%s', Enabled=%s, Dist=%.1f (Path: %s)",
                desc.ActionText, desc.ObjectText, tostring(desc.Enabled), dist, pathStr))
        end
    end
end
log("Tổng số ProximityPrompt gần: " .. promptCount)

log("\n==================================================================")
log("                       KẾT THÚC BÁO CÁO                          ")
log("==================================================================")

local fullLog = table.concat(logLines, "\n")

-- LƯU VÀO FILE LOCAL (NẾU EXECUTOR CÓ WRITEFILE)
pcall(function()
    if writefile then
        writefile("ps99_dump_full.txt", fullLog)
        log("=> ĐÃ LƯU FILE THÀNH CÔNG: ps99_dump_full.txt")
    end
end)

-- COPY VÀO BỘ NHỚ TẠM (CLIPBOARD)
pcall(function()
    if setclipboard then
        setclipboard(fullLog)
        log("=> ĐÃ COPY TOÀN BỘ VÀO BỘ NHỚ TẠM (CLIPBOARD)!")
    end
end)

-- GỬI VỀ DISCORD QUA CHUNKED EMBEDS (ĐẢM BẢO KHÔNG BỊ TRUNCATE)
pcall(function()
    sendChunkedWebhook(WEBHOOK, fullLog)
end)

-- THÔNG BÁO GIAO DIỆN
pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "✅ ĐÃ XUẤT TOÀN BỘ DỮ LIỆU!",
        Text = "Đã gửi Discord và copy vào Clipboard. Hãy dán log vào chat!",
        Duration = 6
    })
end)
