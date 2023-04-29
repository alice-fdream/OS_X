-- local variables for API functions. any changes to the line below will be lost on re-generation
local coroutine_create, coroutine_resume, io_open, pcall, loadfile, require =
    coroutine.create,
    coroutine.resume,
    io.open,
    pcall,
    loadfile,
    require

local buffer = require("NyaDraw")
local GUI = require("GUI")
local computer = require("computer")
local fs = require("filesystem")
local unicode = require("unicode")
local component = require("component")
local key = require("serialization")
local system = require("system")
local island = require("island")
------------------------------------------------------------------------------------------
buffer.setGPUProxy(require("component").gpu)
--------------------------------------------------------------------------------
Desktop = GUI.application()
Desktop.island = island
function error(msg)
    GUI.alert(msg)
end

function exe(app, args)
    if fs.exists("/OS/Applications/" .. app .. "/Permissions/config") then
        local file = io_open("/OS/Applications/" .. app .. "/Permissions/config")
        local json = file:read(1024)
        file:close()
        local json = key.unserialize(json)
        if json.safeness["sign_key"] then
            local file = io_open("/OS/Applications/" .. app .. "/" .. json.BFI["file"])
            local hash = file:read(1024)
            file:close()

            local result = 0
            -- local result = system.getRequest("http://26.5.8.154/lib.php?token=access_key&sub_token=check&key=" .. system.urlencode(json.safeness["sign_key"]) ..
            --"&author=".. system.urlencode(json.main["author"]) .. "&name=" .. system.urlencode(json.main["name"]) .. "&hash=" .. hash)
            if result == "1" then
                error("Неверный ключ сертификата")
            elseif result == "2" then
                error("Ошибка защиты авторских прав")
            elseif result == "3" then
                error("Попытка подмены кода приложения " .. app)
            else
                Desktop.coroutine =
                    coroutine_create(
                    function()
                        local startfile = "/OS/Applications/" .. app .. "/" .. json.BFI["file"]
                        local result, reason = loadfile(startfile)
                        if result then
                            Desktop.json = json
                            if not args then
                                result, reason = pcall(result)
                                Desktop.island.container:moveToFront()
                            elseif args then
                                result, reason = pcall(result, args)
                                Desktop.island.container:moveToFront()
                            end
                            if not result then
                                error("Ошибка в работе программы : " .. reason)
                            end
                        else
                            error("Ошибка в загрузке файла (" .. startfile .. ") " .. reason)
                        end
                    end
                )
                coroutine_resume(Desktop.coroutine)
            end
        end
    else
        GUI.alert("Отсутствует config")
    end
end

Desktop:addChild(GUI.panel(1, 1, Desktop.width, Desktop.height, 0x2D2D2D))
Desktop.toggle = 0
Desktop:addChild(
        GUI.roundedButton(2, 48, unicode.len(_OSVERSION) + 2, 3, 0x32b355, 0xFFFFFF, 0x880000, 0xFFFFFF, _OSVERSION)
    ).onTouch = function()
    if Desktop.toggle == 0 then
        Desktop.menu = GUI.container(2, 20, 40, 28)
        Desktop.menu:addChild(GUI.panel(1, 1, Desktop.menu.width, Desktop.menu.height, 0xFFFFFF, 0.7))
        Desktop:addChild(Desktop.menu)

        local overview = GUI.container(2, 2, 38, 26)
        overview.view = GUI.container(1, 1, 38, 100)
        overview.view:addChild(GUI.panel(1, 1, overview.width, 100, 0x000000, 0.6))
        Desktop.menu:addChild(overview)
        overview:addChild(overview.view)
        overview.view.eventHandler = function(Desktop, view, ename, idds, x, y, chsc)
        if ename == "scroll" then
            if chsc >= 1 then
                if view.localY ~= 1 then
                    view.localY = view.localY + 1
                    Desktop:draw()
                end
            else
                view.localY = view.localY - 1
                Desktop:draw()
            end
        end
    end
        local x1, y1 = 2, 2
        for app in fs.list("/OS/Applications/") do
            local config_path = "/OS/Applications/" .. app .. "Permissions/config"
            if fs.exists("/OS/Applications/" .. app .. "Permissions/config") then
                local try = io.open(config_path)
                local config = try:read(1024)
                try:close()
                config = key.unserialize(config)

                local container = GUI.container(x1, y1, 36, 5)
                container:addChild(GUI.image(1, 1, buffer.loadImage("/OS/Applications/" .. app .. config.BFI.icon)))
                container:addChild(GUI.text(8, 1, 0xFFFFFF, config.main.name .. " " .. config.main.version .. "v"))
                container:addChild(GUI.text(8, 2, 0xFFFFFF, "Автор: " .. config.main.author))
                container:addChild(GUI.text(8, 3, 0xFFFFFF, "ID: " .. unicode.sub(app, 0, -2)))
                overview.view:addChild(container).eventHandler = function(main, win, evn, _, x, y)
                    if evn == "touch" then
                    	exe(unicode.sub(app, 0, -2))
                    	Desktop.menu:remove()
        				Desktop.toggle = 0
       					Desktop:draw()
                    end
                end

                y1 = y1 + 5
            end
        end
        Desktop:draw()
        Desktop.toggle = 1
    else
        Desktop.menu:remove()
        Desktop.toggle = 0
        Desktop:draw()
    end
end

island.start()
Desktop:draw()
Desktop:start()
