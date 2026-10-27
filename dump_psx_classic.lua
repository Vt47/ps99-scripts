--[[
    ========================================================================
    🔍 PS99 PSX CLASSIC (UPDATE 99) - DEEP EGG & REMOTE DIAGNOSTIC TOOL
    ========================================================================
    Công cụ quét chuyên sâu:
      1. Toàn bộ Remotes trong ReplicatedStorage.Network liên quan đến Trứng / Mở Trứng
      2. Module Client.EggCmds (các hàm và thuộc tính)
      3. Danh sách các folder và Model trứng trong Workspace & __THINGS quanh nhân vật
      4. Thử nghiệm trực tiếp các Remote mở trứng và ghi lại kết quả / lỗi trả về
      5. Tự động Copy vào Clipboard và hiện khung Text trên màn hình để xem trực tiếp
    ========================================================================
]]

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")
local Player = Players.LocalPlayer

local logLines = {}
local function log(str)
    table.insert(logLines, str)
    print("[PSX DUMP] " .. str)
end

log("==================================================================")
log("       PS99 UPDATE 99 (PSX CLASSIC) - BÁO CÁO TRỨNG & REMOTES     ")
log("==================================================================")
log("Thời gian: " .. os.date("%Y-%m-%d %H:%M:%S"))
log("Tài khoản: " .. Player.Name .. " (UserId: " .. tostring(Player.UserId) .. ")")
log("PlaceId: " .. tostring(game.PlaceId) .. " | JobId: " .. tostring(game.JobId))

local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
if hrp then
    log(string.format("Tọa độ nhân vật: Vector3.new(%.1f, %.1f, %.1f)", hrp.Position.X, hrp.Position.Y, hrp.Position.Z))
end

--========================================================================
-- 1. QUÉT REPLICATEDSTORAGE.NETWORK
--========================================================================
log("\n[1. REMOTES TRONG REPLICATEDSTORAGE.NETWORK]")
local netFolder = RS:FindFirstChild("Network")
local eggRemotes = {}
if netFolder then
    for _, item in pairs(netFolder:GetChildren()) do
        local lName = string.lower(item.Name)
        if string.find(lName, "egg") or string.find(lName, "hatch") or string.find(lName, "buy") or string.find(lName, "purchase") or string.find(lName, "classic") or string.find(lName, "event") then
            table.insert(eggRemotes, string.format("• [%s] %s", item.ClassName, item.Name))
        end
    end
    table.sort(eggRemotes)
    log("Tìm thấy " .. #eggRemotes .. " Remotes liên quan:")
    for _, r in ipairs(eggRemotes) do log("  " .. r) end
else
    log("❌ Không tìm thấy ReplicatedStorage.Network!")
end

--========================================================================
-- 2. QUÉT MODULE CLIENT & DIRECTORY
--========================================================================
log("\n[2. MODULES CLIENT & EGGCMDS]")
local Library = RS:FindFirstChild("Library") or RS:WaitForChild("Library", 3)
local Client = Library and Library:FindFirstChild("Client")
local Directory = Library and Library:FindFirstChild("Directory")
local NetworkMod = Client and Client:FindFirstChild("Network") and require(Client.Network)
local EggCmds = Client and Client:FindFirstChild("EggCmds") and require(Client.EggCmds)
local Save = Client and Client:FindFirstChild("Save") and require(Client.Save)

if EggCmds then
    local funcs = {}
    for k, v in pairs(EggCmds) do
        table.insert(funcs, k .. " (" .. type(v) .. ")")
    end
    table.sort(funcs)
    log("• EggCmds exports: [" .. table.concat(funcs, ", ") .. "]")
    if EggCmds.GetMaxHatch then
        pcall(function() log("  - EggCmds.GetMaxHatch() = " .. tostring(EggCmds.GetMaxHatch())) end)
    end
else
    log("❌ Không require được Client.EggCmds")
end

if Directory and Directory:FindFirstChild("Eggs") then
    pcall(function()
        local eggDir = require(Directory.Eggs)
        local keys = {}
        for k, _ in pairs(eggDir) do
            local lK = string.lower(tostring(k))
            if string.find(lK, "spotted") or string.find(lK, "cracked") or string.find(lK, "classic") or string.find(lK, "wood") then
                table.insert(keys, tostring(k))
            end
        end
        log("• Trứng tìm thấy trong Directory.Eggs: [" .. table.concat(keys, ", ") .. "]")
    end)
end

--========================================================================
-- 3. QUÉT VẬT THỂ VÀ TRỨNG TRONG WORKSPACE QUANH NHÂN VẬT
--========================================================================
log("\n[3. QUÉT WORKSPACE VÀ TRỨNG GẦN NHÂN VẬT (BÁN KÍNH 80 STUDS)]")
local Things = workspace:FindFirstChild("__THINGS")
if Things then
    local thingsFolders = {}
    for _, ch in pairs(Things:GetChildren()) do
        table.insert(thingsFolders, ch.Name .. " (" .. ch.ClassName .. ", " .. #ch:GetChildren() .. " con)")
    end
    log("• Folders trong workspace.__THINGS: [" .. table.concat(thingsFolders, " | ") .. "]")
end

-- Quét mọi vật thể quanh người chơi 80 studs có tên hoặc con chứa "Egg" hoặc BillboardGui
local nearbyEggs = {}
pcall(function()
    for _, desc in pairs(workspace:GetDescendants()) do
        if desc:IsA("Model") or desc:IsA("BasePart") or desc:IsA("BillboardGui") then
            local p = desc:IsA("BasePart") and desc or desc:FindFirstChildWhichIsA("BasePart", true)
            if p and hrp then
                local dist = (p.Position - hrp.Position).Magnitude
                if dist < 80 then
                    local lName = string.lower(desc.Name)
                    local pName = desc.Parent and string.lower(desc.Parent.Name) or ""
                    if string.find(lName, "egg") or string.find(pName, "egg") or desc:IsA("BillboardGui") then
                        local info = string.format("• [#%s] %s | Cách: %.1f studs | Parent: %s", desc.ClassName, desc.Name, dist, desc.Parent and desc.Parent.Name or "None")
                        local attrs = {}
                        for aK, aV in pairs(desc:GetAttributes()) do
                            table.insert(attrs, aK .. "=" .. tostring(aV))
                        end
                        if #attrs > 0 then info = info .. " | Attrs: [" .. table.concat(attrs, ", ") .. "]" end
                        table.insert(nearbyEggs, info)
                    end
                end
            end
        end
    end
end)
log("Số vật thể liên quan gần nhân vật: " .. #nearbyEggs)
for i = 1, math.min(#nearbyEggs, 15) do
    log("  " .. nearbyEggs[i])
end

--========================================================================
-- 4. TEST TRỰC TIẾP TỪNG REMOTE MỞ TRỨNG (DRY-RUN CALLS)
--========================================================================
log("\n[4. THỰC NGHIỆM GỌI CÁC REMOTE MỞ TRỨNG]")

local testCases = {
    {"Eggs_Hatch", "Spotted Egg", 1},
    {"Eggs_Hatch", "Cracked Egg", 1},
    {"Eggs_Hatch", "2 - Spotted Egg", 1},
    {"Eggs_Hatch", 2, 1},
    {"Eggs_RequestPurchase", "Spotted Egg", 1},
    {"Eggs_RequestPurchase", "Cracked Egg", 1},
    {"Eggs_RequestPurchase", "2 - Spotted Egg", 1},
    {"Eggs_RequestPurchase", 2, 1},
    {"CustomEggs_Hatch", "Spotted Egg", 1},
    {"CustomEggs_Hatch", "Cracked Egg", 1},
}

-- Thêm các remote được tìm thấy trong ReplicatedStorage.Network
if netFolder then
    for _, rem in pairs(netFolder:GetChildren()) do
        local lN = string.lower(rem.Name)
        if (string.find(lN, "egg") or string.find(lN, "hatch")) and not string.find(lN, "badge") then
            local already = false
            for _, tc in ipairs(testCases) do if tc[1] == rem.Name then already = true break end end
            if not already then
                table.insert(testCases, {rem.Name, "Spotted Egg", 1})
                table.insert(testCases, {rem.Name, "Cracked Egg", 1})
            end
        end
    end
end

for _, tc in ipairs(testCases) do
    local rName, eggTarget, amt = tc[1], tc[2], tc[3]
    
    -- Thử qua Network.Invoke
    if NetworkMod and type(NetworkMod.Invoke) == "function" then
        local ok, res = pcall(function() return NetworkMod.Invoke(rName, eggTarget, amt) end)
        log(string.format("• Network.Invoke(\"%s\", \"%s\", %d) => ok=%s, return=%s", rName, tostring(eggTarget), amt, tostring(ok), tostring(res)))
    end

    -- Thử trực tiếp qua RemoteFunction nếu có
    if netFolder then
        local rf = netFolder:FindFirstChild(rName)
        if rf and rf:IsA("RemoteFunction") then
            local ok, res = pcall(function() return rf:InvokeServer(eggTarget, amt) end)
            log(string.format("  ↳ RS.Network.%s:InvokeServer(\"%s\", %d) => ok=%s, return=%s", rName, tostring(eggTarget), amt, tostring(ok), tostring(res)))
        end
    end
    task.wait(0.05)
end

log("\n==================================================================")
log("                       KẾT THÚC BÁO CÁO                          ")
log("==================================================================")

local fullReport = table.concat(logLines, "\n")

-- 1. Lưu file
pcall(function()
    if writefile then
        writefile("psx_classic_dump.txt", fullReport)
        log("=> Đã lưu vào file: psx_classic_dump.txt")
    end
end)

-- 2. Copy vào Clipboard
pcall(function()
    if setclipboard then
        setclipboard(fullReport)
        log("=> ĐÃ COPY TOÀN BỘ VÀO BỘ NHỚ TẠM (CLIPBOARD)!")
    end
end)

-- 3. Tạo GUI xem trực tiếp trên màn hình (đặc biệt hữu dụng cho Android Cloud Emulator)
pcall(function()
    local parent = (typeof(gethui) == "function" and gethui()) or CoreGui or Player:WaitForChild("PlayerGui")
    if parent:FindFirstChild("PSX_Dump_Viewer") then parent.PSX_Dump_Viewer:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "PSX_Dump_Viewer"
    gui.ResetOnSpawn = false

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 360, 0, 260)
    frame.Position = UDim2.new(0.5, -180, 0.25, 0)
    frame.BackgroundColor3 = Color3.fromRGB(15, 18, 26)
    frame.BorderSizePixel = 0
    frame.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame

    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, -60, 0, 32)
    header.Position = UDim2.new(0, 10, 0, 0)
    header.BackgroundTransparency = 1
    header.Text = "📋 BÁO CÁO THÔNG TIN PSX CLASSIC"
    header.TextColor3 = Color3.fromRGB(255, 220, 80)
    header.Font = Enum.Font.GothamBold
    header.TextSize = 12
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.Parent = frame

    local btnClose = Instance.new("TextButton")
    btnClose.Size = UDim2.new(0, 26, 0, 26)
    btnClose.Position = UDim2.new(1, -30, 0, 3)
    btnClose.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    btnClose.Text = "✕"
    btnClose.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnClose.Font = Enum.Font.GothamBold
    btnClose.TextSize = 12
    btnClose.Parent = frame

    local btnCopy = Instance.new("TextButton")
    btnCopy.Size = UDim2.new(1, -20, 0, 32)
    btnCopy.Position = UDim2.new(0, 10, 1, -40)
    btnCopy.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
    btnCopy.Text = "📋 BẤM VÀO ĐÂY ĐỂ COPY TOÀN BỘ LOG"
    btnCopy.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnCopy.Font = Enum.Font.GothamBold
    btnCopy.TextSize = 12
    btnCopy.Parent = frame

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -20, 1, -80)
    scroll.Position = UDim2.new(0, 10, 0, 35)
    scroll.BackgroundColor3 = Color3.fromRGB(22, 26, 38)
    scroll.BorderSizePixel = 0
    scroll.CanvasSize = UDim2.new(0, 0, 0, #logLines * 16)
    scroll.Parent = frame

    local txtBox = Instance.new("TextBox")
    txtBox.Size = UDim2.new(1, -10, 1, 0)
    txtBox.Position = UDim2.new(0, 5, 0, 0)
    txtBox.BackgroundTransparency = 1
    txtBox.Text = fullReport
    txtBox.TextColor3 = Color3.fromRGB(200, 220, 240)
    txtBox.Font = Enum.Font.Code
    txtBox.TextSize = 10
    txtBox.TextXAlignment = Enum.TextXAlignment.Left
    txtBox.TextYAlignment = Enum.TextYAlignment.Top
    txtBox.ClearTextOnFocus = false
    txtBox.MultiLine = true
    txtBox.Parent = scroll

    btnClose.Activated:Connect(function() gui:Destroy() end)
    btnCopy.Activated:Connect(function()
        if setclipboard then
            setclipboard(fullReport)
            btnCopy.Text = "✅ ĐÃ COPY VÀO BỘ NHỚ TẠM!"
            btnCopy.BackgroundColor3 = Color3.fromRGB(30, 120, 60)
        else
            btnCopy.Text = "❌ Executor không hỗ trợ setclipboard"
        end
    end)

    gui.Parent = parent
end)

pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "🔍 ĐÃ QUÉT XONG THÔNG TIN!",
        Text = "Đã copy vào Clipboard. Hãy dán vào chat!",
        Duration = 6
    })
end)
