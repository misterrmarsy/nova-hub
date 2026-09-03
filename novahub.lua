--[[
    NOVA HUB — powered by WindUI (loaded from GitHub raw, Xeno-friendly)
    Fetches scripts from your Discord bot's gist database. Client-side.
    Scripts open a detail page (image + title + description) before executing.
--]]

getgenv().HubAutoLoad = getgenv().HubAutoLoad or false

-- ================= CONFIG =================
local GIST_RAW_URL = "https://gist.githubusercontent.com/misterrmarsy/8112f01f9361a81f0aac480380c5f059/raw/script_database.json"
local WINDUI_URL = "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"
local HUB_NAME = "Nova Hub"
local HUB_VERSION = "3.2.0"
-- ==========================================

local HttpService = game:GetService("HttpService")
local Database = { scripts = {} }

local function log(msg)
    pcall(function() print("[NovaHub] " .. tostring(msg)) end)
end

print("=== Nova Hub v" .. HUB_VERSION .. " booting ===")
pcall(function()
    print("[NovaHub] player: " .. tostring(game:GetService("Players").LocalPlayer or "none"))
end)

-- ============ WINDUI LOAD (GitHub raw, robust) ============
local WindUI
local function ensureWindUI()
    if getgenv().WindUI then
        WindUI = getgenv().WindUI
        return true
    end
    log("Loading WindUI...")
    local ok, source = pcall(function()
        return game:HttpGet(WINDUI_URL, true)
    end)
    if not ok or not source or source == "" then
        return false, "Could not fetch WindUI source"
    end
    local fn, err = loadstring(source)
    if not fn then return false, "WindUI compile failed: " .. tostring(err) end
    local ok2, ret, rerr = pcall(fn)
    if not ok2 or type(ret) ~= "table" then
        return false, "WindUI init failed: " .. tostring(rerr or ret)
    end
    WindUI = ret
    getgenv().WindUI = ret
    log("WindUI loaded OK (v" .. tostring(ret.Version or "?") .. ")")
    return true
end

-- ============ DATABASE ============
local function fetchDatabase()
    local ok, res = pcall(function()
        return game:HttpGet(GIST_RAW_URL, true)
    end)
    if not ok or not res or res == "" then
        return false, "Cannot reach database"
    end
    local decoded
    ok, decoded = pcall(function()
        return HttpService:JSONDecode(res)
    end)
    if not ok or type(decoded) ~= "table" or not decoded.scripts then
        return false, "Invalid database"
    end
    Database = decoded
    return true
end

local function runScript(name, code)
    if not code then return false, "No code" end
    local fn = loadstring(code)
    if not fn then return false, "Compile failed: " .. name end
    local ok, err = pcall(fn)
    if not ok then return false, tostring(err) end
    return true
end

local function notify(title, content, ok)
    pcall(function()
        WindUI:Notify({
            Title = title,
            Content = content,
            Icon = ok and "check" or "alert-triangle",
            Duration = ok and 3 or 5,
        })
    end)
end

-- ============ WINDOW BUILD ============
local Window
local PreviewTab
local previewElements = {}

local function clearPreview()
    for _, el in ipairs(previewElements) do
        pcall(function() el:Destroy() end)
    end
    previewElements = {}
end

local function showPreview(script)
    clearPreview()

    local ok, err = pcall(function()
        local image = script.image
        if image and image ~= "" then
            local img = PreviewTab:Image({
                Image = image,
                AspectRatio = "16:9",
                Radius = 12,
            })
            table.insert(previewElements, img)
            PreviewTab:Space({ Columns = 1 })
        end

        local titleP = PreviewTab:Paragraph({
            Title = script.name or "Untitled",
            Desc = (script.category or "Misc") .. (script.addedAt and ("  \226\128\162  added " .. tostring(script.addedAt):sub(1, 10)) or ""),
            Image = "solar:bookmark-circle-bold",
            ImageSize = 24,
        })
        table.insert(previewElements, titleP)
        PreviewTab:Space({ Columns = 1 })

        local desc = PreviewTab:Paragraph({
            Title = "About",
            Desc = (script.description or "No description provided."),
        })
        table.insert(previewElements, desc)
        PreviewTab:Space({ Columns = 1 })

        local execBtn = PreviewTab:Button({
            Title = "Execute " .. (script.name or "Script"),
            Icon = "play",
            Color = Color3.fromHex("#10C550"),
            Justify = "Center",
            Callback = function()
                local ok, err = runScript(script.name, script.code)
                notify(ok and "Executed" or "Failed", ok and script.name or tostring(err), ok)
            end,
        })
        table.insert(previewElements, execBtn)

        PreviewTab:Space({ Columns = 1 })
    end)

    if not ok then
        log("Preview build error: " .. tostring(err))
    end

    local sok, serr = pcall(function() PreviewTab:Select() end)
    if not sok then
        log("Preview select error: " .. tostring(serr))
    end
end

local function buildWindow()
    Window = WindUI:CreateWindow({
        Title = HUB_NAME .. " v" .. HUB_VERSION,
        Author = "by Scratch Team",
        Folder = "NovaHub",
        Icon = "solar:folder-2-bold-duotone",
        NewElements = true,
    })

    -- Home tab
    local Home = Window:Tab({
        Title = "Home",
        Desc = HUB_NAME,
        Icon = "solar:home-2-bold",
        IconColor = Color3.fromHex("#257AF7"),
        IconShape = "Square",
        Border = true,
    })

    local HomeStatus = Home:Section({
        Title = "Status",
    })

    HomeStatus:Paragraph({
        Title = HUB_NAME .. " v" .. HUB_VERSION,
        Desc = "Loaded " .. tostring(#(Database.scripts or {})) .. " scripts from the database.",
        Justify = "Center",
    })

    Home:Space()

    Home:Button({
        Title = "Refresh Scripts",
        Icon = "refresh-cw",
        Justify = "Center",
        Callback = function()
            local ok, err = fetchDatabase()
            notify(ok and "Refreshed" or "Error", ok and "Database updated." or tostring(err), ok)
        end,
    })

    -- Preview tab (reused to show script details). Hidden from the sidebar
    -- but driven programmatically via showPreview() -> PreviewTab:Select().
    PreviewTab = Window:Tab({
        Title = "Script Preview",
        Icon = "solar:eye-bold",
        IconColor = Color3.fromHex("#ECA201"),
        IconShape = "Square",
        Border = true,
    })
    pcall(function()
        PreviewTab.UIElements.Main.Visible = false
    end)
    PreviewTab:Paragraph({
        Title = "Select a script to preview it here.",
        Justify = "Center",
    })

    -- Category tabs
    local categories = {}
    for _, s in ipairs(Database.scripts or {}) do
        local cat = s.category or "Misc"
        if not categories[cat] then categories[cat] = {} end
        table.insert(categories[cat], s)
    end

    for cat, scripts in pairs(categories) do
        local tab = Window:Tab({
            Title = cat,
            Desc = "(" .. #scripts .. ") scripts",
            Icon = "solar:code-square-bold",
            IconColor = Color3.fromHex("#10C550"),
            IconShape = "Square",
            Border = true,
        })

        local sec = tab:Section({
            Title = cat .. " (" .. #scripts .. ")",
        })

        for _, s in ipairs(scripts) do
            sec:Button({
                Title = s.name,
                Desc = s.description or "Click to view",
                Justify = "Center",
                Callback = function()
                    showPreview(s)
                end,
            })
            tab:Space()
        end
    end
end

-- ============ MAIN ============
log("Starting Nova Hub")

local ok, err = ensureWindUI()
if not ok then
    log("WindUI error: " .. tostring(err))
    return
end

ok, err = fetchDatabase()
if not ok then
    log("Database error: " .. tostring(err))
end

local buildOk, buildErr = pcall(buildWindow)
if not buildOk then
    log("Build window error: " .. tostring(buildErr))
end

log("Nova Hub ready")

if getgenv().HubAutoLoad then
    for _, s in ipairs(Database.scripts or {}) do
        if s.auto and s.code then
            task.spawn(function() runScript(s.name, s.code) end)
        end
    end
end
