--========================================================================
-- PS99 DIAGNOSTIC SCANNER & EGG DEBUGGER TOOL (V2 CHUYÊN SÂU)
-- Quét toàn bộ Breakables, Boss Yeti, GUI, Remotes, Client Modules & Trứng
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

log("=== BẮT ĐẦU QUÉT DỮ LIỆU PS99 CHUYÊN SÂU ===")
log("Tài khoản: " .. Player.Name)
local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
if hrp then
    log(string.format("Tọa độ hiện tại: Vector3.new(%.1f, %.1f, %.1f)", hrp.Position.X, hrp.Position.Y, hrp.Position.Z))
end

local Things = workspace:FindFirstChild("__THINGS")

-- 1. QUÉT TOÀN BỘ CÁC REMOTES TRONG __THINGS.__REMOTES
log("\n--- 1. DANH SÁCH REMOTES TRONG __THINGS.__REMOTES ---")
local Remotes = Things and Things:FindFirstChild("__REMOTES")
if Remotes then
    local matchedRemotes = {}
    local allRemoteNames = {}
    for _, r in pairs(Remotes:GetChildren()) do
        table.insert(allRemoteNames, r.Name)
        local n = string.lower(r.Name)
        if string.find(n, "egg") or string.find(n, "hatch") or string.find(n, "buy")
           or string.find(n, "custom") or string.find(n, "trail") or string.find(n, "mountain")
           or string.find(n, "summit") or string.find(n, "purchase") or string.find(n, "open") then
            table.insert(matchedRemotes, string.format("• [%s] %s", r.ClassName, r.Name))
        end
    end
    if #matchedRemotes > 0 then
        log("Remotes liên quan đến Trứng / Mua / Hang:\n" .. table.concat(matchedRemotes, "\n"))
    else
        log("Không tìm thấy remote nào chứa từ khóa egg/hatch/custom/trail.")
    end
    log(string.format("Tổng số remotes trong game: %d. Danh sách tóm tắt: %s", #allRemoteNames, table.concat(allRemoteNames, ", ")))
else
    log("Không tìm thấy workspace.__THINGS.__REMOTES!")
end

-- 2. QUÉT CLIENT MODULES TRONG REPLICATEDSTORAGE.LIBRARY.CLIENT
log("\n--- 2. CÁC MODULE TRONG LIBRARY.CLIENT ---")
local Lib = RS:FindFirstChild("Library")
local Client = Lib and Lib:FindFirstChild("Client")
local Network = nil
if Client then
    local clientModNames = {}
    for _, mod in pairs(Client:GetChildren()) do
        table.insert(clientModNames, mod.Name)
        local mName = string.lower(mod.Name)
        if string.find(mName, "egg") or string.find(mName, "hatch") or string.find(mName, "custom") or string.find(mName, "network") then
            pcall(function()
                local reqMod = require(mod)
                if type(reqMod) == "table" then
                    local keys = {}
                    for k, v in pairs(reqMod) do
                        table.insert(keys, tostring(k) .. " (" .. typeof(v) .. ")")
                    end
                    log(string.format("• Module [%s] exports: %s", mod.Name, table.concat(keys, ", ")))
                end
            end)
        end
    end
    log("Tất cả Modules trong Client: " .. table.concat(clientModNames, ", "))
    pcall(function()
        if Client:FindFirstChild("Network") then Network = require(Client.Network) end
    end)
else
    log("Không tìm thấy Library.Client!")
end

-- 3. QUÉT CHI TIẾT ĐỐI TƯỢNG TRỨNG GẦN BẠN NHẤT
log("\n--- 3. CHI TIẾT TRỨNG GẦN NHẤT TRONG BÁN KÍNH 180 STUDS ---")
local nearestEggObj, nearestEggDist = nil, 180
local possibleEggFolders = { "CustomEggs", "Eggs", "RenderedEggs", "ZoneEggs" }
for _, fName in ipairs(possibleEggFolders) do
    local f = Things and Things:FindFirstChild(fName)
    if f then
        for _, egg in pairs(f:GetChildren()) do
            local part = egg:IsA("BasePart") and egg or (egg:IsA("Model") and (egg.PrimaryPart or egg:FindFirstChildWhichIsA("BasePart", true)))
            local dist = (part and hrp) and (part.Position - hrp.Position).Magnitude or 9999
            if dist < nearestEggDist then
                nearestEggDist = dist
                nearestEggObj = egg
            end
            if dist < 180 then
                log(string.format("• Trứng trong [%s]: \"%s\" (Cách: %.1f studs)", fName, egg.Name, dist))
                for k, v in pairs(egg:GetAttributes()) do
                    log(string.format("     Attr: %s = %s", tostring(k), tostring(v)))
                end
            end
        end
    end
end

if nearestEggObj then
    log("\n>> Cấu trúc bên trong quả trứng gần nhất: " .. nearestEggObj.Name)
    for _, ch in pairs(nearestEggObj:GetDescendants()) do
        local info = ch.ClassName
        if ch:IsA("BasePart") then
            info = string.format("BasePart (Pos: %.1f, %.1f, %.1f; Size: %.1f, %.1f, %.1f; CanCollide: %s)",
                ch.Position.X, ch.Position.Y, ch.Position.Z, ch.Size.X, ch.Size.Y, ch.Size.Z, tostring(ch.CanCollide))
        elseif ch:IsA("ProximityPrompt") then
            info = string.format("ProximityPrompt (Action: \"%s\", Object: \"%s\", Enabled: %s)", ch.ActionText, ch.ObjectText, tostring(ch.Enabled))
        end
        log(string.format("   - [%s] \"%s\" -> %s", ch.ClassName, ch.Name, info))
    end
end

-- 4. THỬ NGHIỆM GỌI CÁC CANDIDATE REMOTES ĐỂ MỞ TRỨNG (TEST CALLS)
log("\n--- 4. THỬ NGHIỆM GỌI REMOTES MỞ TRỨNG (LIVE TEST) ---")
if nearestEggObj and Network then
    local eggId = nearestEggObj:GetAttribute("DM_EggId") or nearestEggObj.Name
    local eggName = nearestEggObj.Name
    log(string.format("Target Egg: eggId=\"%s\", eggName=\"%s\"", tostring(eggId), tostring(eggName)))

    local candidateRemotes = {
        "Eggs_RequestPurchase",
        "CustomEggs_RequestPurchase",
        "CustomEggs_Purchase",
        "CustomEggs_Hatch",
        "Eggs_Hatch",
        "Eggs_Purchase",
        "TrailEggs_RequestPurchase",
        "TrailEgg_RequestPurchase",
        "Trail_RequestPurchase"
    }

    for _, rName in ipairs(candidateRemotes) do
        -- Test A: Invoke với eggId
        if Network.Invoke then
            local s, res1, res2, res3 = pcall(function()
                return Network.Invoke(rName, eggId, 1)
            end)
            log(string.format("Invoke(\"%s\", \"%s\", 1) => Success=%s | Res1=%s | Res2=%s | Res3=%s",
                rName, tostring(eggId), tostring(s), tostring(res1), tostring(res2), tostring(res3)))

            -- Test B: Invoke với eggName (UUID)
            if eggName ~= eggId then
                local s2, r2_1, r2_2 = pcall(function()
                    return Network.Invoke(rName, eggName, 1)
                end)
                log(string.format("Invoke(\"%s\", \"%s\", 1) => Success=%s | Res1=%s | Res2=%s",
                    rName, tostring(eggName), tostring(s2), tostring(r2_1), tostring(r2_2)))
            end
        end

        -- Test C: Fire với eggId
        if Network.Fire then
            local sf, errf = pcall(function()
                Network.Fire(rName, eggId, 1)
            end)
            log(string.format("Fire(\"%s\", \"%s\", 1) => Success=%s | Err=%s",
                rName, tostring(eggId), tostring(sf), tostring(errf)))
        end
    end
else
    log("Không đủ điều kiện test remotes (Không tìm thấy trứng gần hoặc Network nil).")
end

-- 5. QUÉT GIAO DIỆN HATCH TRÊN MÀN HÌNH (PLAYERGUI)
log("\n--- 5. CHI TIẾT NÚT BẤM / GUI LIÊN QUAN ĐẾN HATCH TRÊN MÀN HÌNH ---")
for _, g in pairs(Player.PlayerGui:GetDescendants()) do
    if (g:IsA("TextLabel") or g:IsA("TextButton") or g:IsA("ImageButton")) and g.Visible then
        local t = g:IsA("TextButton") and g.Text or (g:IsA("TextLabel") and g.Text or "")
        local lText = string.lower(t)
        local lName = string.lower(g.Name)
        if string.find(lText, "egg") or string.find(lText, "hatch") or string.find(lText, "buy")
           or string.find(lName, "egg") or string.find(lName, "hatch") or string.find(lName, "buy")
           or string.find(lName, "auto") or string.find(lText, "auto") then
            log(string.format("• GUI [%s] \"%s\" (Text=\"%s\", Parent=\"%s\")",
                g.ClassName, g.Name, t, g.Parent and g.Parent.Name or "nil"))
        end
    end
end

-- 6. TỔNG HỢP VÀ GỬI BÁO CÁO
local fullLog = table.concat(logLines, "\n")

if setclipboard then
    setclipboard(fullLog)
    log("\n=> [THÀNH CÔNG] ĐÃ COPY TOÀN BỘ LOG VÀO CLIPBOARD!")
end

pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "📋 Đã Quét Xong Log V2!",
        Text = "Đã copy vào Clipboard & gửi về Discord Webhook.",
        Duration = 5
    })
end)

if req and WEBHOOK and WEBHOOK ~= "" then
    pcall(function()
        -- Chia nhỏ nếu log quá dài (Discord giới hạn 2000 ký tự / tin)
        local maxLen = 1900
        for i = 1, math.min(#fullLog, 7600), maxLen do
            local chunk = string.sub(fullLog, i, i + maxLen - 1)
            req({
                Url = WEBHOOK,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode({
                    username = "PS99 Deep Egg Scanner",
                    content = "```yaml\n" .. chunk .. "\n```"
                })
            })
            task.wait(0.5)
        end
    end)
end
