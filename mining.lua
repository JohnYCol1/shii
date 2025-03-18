local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TeleportService = game:GetService("TeleportService")

local player = Players.LocalPlayer

-- 🔧 TWEEN SPEED (Adjust movement speed)
local tweenSpeed = 3 

-- 🔹 Start & End Position
local returnPosition = CFrame.new(-532.117, 338.489, 10.078)

local mineTimeout = 8
local isRunning = true
local blacklist = {}
local criticalFallY = -500  -- Y-axis threshold to detect falling out of the map

-- 🔄 Reset character before starting (Client-Side)
local function resetCharacter()
    local character = player.Character
    if character and character:FindFirstChild("Humanoid") then
        character.Humanoid:TakeDamage(1000) -- Kill the player
        print("🔄 Character reset due to falling or script start.")
    end
end

-- 🕒 Wait for character and game assets to load
local function waitForCharacterLoad()
    repeat task.wait() until player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    repeat task.wait() until workspace:FindFirstChild("Harvestable")
    print("✅ Character and game assets loaded!")
end

-- 🔄 Auto-restart script upon joining a new server
Players.LocalPlayer.OnTeleport:Connect(function()
    waitForCharacterLoad()
    isRunning = true
end)

-- ⏳ Wait after respawn before continuing
local function waitForRespawn()
    player.CharacterAdded:Connect(function()
        print("🕒 Waiting for respawn...")
        task.wait(6) -- Adjust wait time if needed
        print("✅ Respawn complete, resuming script!")
    end)
end

-- 🚶 Move player to a position safely
local function tweenToPosition(targetCFrame)
    local character = player.Character
    if not character then return end
    if not isRunning then return end

    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then
        warn("⚠️ HumanoidRootPart not found! Retrying in 1 second...")
        task.wait(1)
        tweenToPosition(targetCFrame)
        return
    end

    local tweenInfo = TweenInfo.new(tweenSpeed, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    local tween = TweenService:Create(humanoidRootPart, tweenInfo, { CFrame = targetCFrame })
    
    tween:Play()
    tween.Completed:Wait()
end

-- 🔁 Press "E" repeatedly to mine ores
local function spamEKey()
    for i = 1, 15 do 
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        task.wait(math.random(0.3, 0.5)) 
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        task.wait(0.2) 
    end
    print("⚒️ Spammed E key to mine")
end

-- ⚒️ Get a valid, mineable ore
local function getMineableOre()
    local oreFolder = workspace:FindFirstChild("Harvestable")
    if not oreFolder then return nil end

    for _, ore in ipairs(oreFolder:GetChildren()) do
        if ore:IsA("Model") and ore.Name == "Mithril" and not blacklist[ore] then
            if ore.PrimaryPart then
                return ore
            end
        end
    end
    return nil
end

-- 🔍 Mine an ore by moving to it & spamming E
local function checkOreMineable(ore)
    local character = player.Character
    if not character then return false end
    if not isRunning then return false end
    if not ore or not ore.PrimaryPart then
        print("⚠️ No valid ores found! Returning to start position...")
        tweenToPosition(returnPosition)
        task.wait(2)
        return false
    end

    local oreCFrame = ore.PrimaryPart.CFrame
    print("🚶 Moving to ore at:", oreCFrame)
    tweenToPosition(oreCFrame + Vector3.new(0, 5, 0))

    local startTime = tick()
    while tick() - startTime < mineTimeout do
        spamEKey()
        if not ore.Parent then
            blacklist[ore] = true
            return true
        end
        task.wait(2)
    end

    blacklist[ore] = true
    print("⚠️ Ore did not disappear, adding to blacklist.")
    return false
end

-- 🚨 Detect if the character falls out of the map
local function detectFalling()
    while isRunning do
        local character = player.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            local rootPart = character.HumanoidRootPart
            
            -- If the player falls below the map threshold (-500 or lower)
            if rootPart.Position.Y <= criticalFallY then
                print("❌ Character fell out of the map! Resetting instantly...")
                resetCharacter()
                task.wait(8) -- Allow respawn before continuing
            end
        end
        task.wait(1)
    end
end

-- 🛑 Create a stop button
local function createStopButton()
    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then return end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Parent = playerGui

    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 100, 0, 50)
    button.Position = UDim2.new(0.9, 0, 0.1, 0)
    button.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    button.Text = "STOP"
    button.Parent = screenGui

    button.MouseButton1Click:Connect(function()
        isRunning = false
        screenGui:Destroy()
        print("⛔ Script Stopped. All functions disabled.")
    end)
end

-- 🔄 Reset character before starting script execution
wait(8)
resetCharacter()

-- 🕒 Wait for everything to load before starting
waitForCharacterLoad()
waitForRespawn()
task.spawn(detectFalling) -- Start falling detection in a separate task
createStopButton() -- Create stop button
wait(8)

-- 🎯 Main execution loop
while isRunning do
    local ore = getMineableOre()
    if ore then
        local success = checkOreMineable(ore)
        if success then
            task.wait(1)
        end
    else
        print("⚠️ No ores detected! Returning to start...")
        tweenToPosition(returnPosition)
        task.wait(2)
    end
end
