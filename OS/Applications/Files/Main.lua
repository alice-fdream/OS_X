-- local variables for API functions. any changes to the line below will be lost on re-generation
local io_open, exe, require = io.open, exe, require

local GUI = require("GUI")
local buffer = require("NyaDraw")
local computer = require("computer")
local fs = require("filesystem")
local event = require("event")
local unicode = require("unicode")
local system = require("system")
local island = require("island")

-- Program important variables
local Files = GUI.defaultWindow(6, 6, 80, 25)
Files.dir_root = "/"
Files.current_caller = 1
Files.history = {}
---------------------------------------------------------------------
-- DEBUG
local alert = GUI.alert


Files.overview = GUI.container(1, 4, Files.width, 20)
local view = GUI.container(1, 1, Files.overview.width, Files.overview.height)
Files.overview:addChild(view)
Files:addChild(Files.overview)

local function refresh()
    Files.overview:remove()

    Files.overview = GUI.container(1, 4, Files.width, 19)
    local view = GUI.container(1, 1, Files.overview.width, 1000)
    Files.overview:addChild(view)
    Files:addChild(Files.overview)

    Files:addChild(GUI.roundedButton(Files.width - 10, 1, 6, 3, 0xaa51b0, 0xFFFFFF, 0x880000, 0xFFFFFF, "<-")).onTouch = function()
        if Files.current_caller ~= 1 then
            Files.overview:remove()
            Files.dir_root = Files.history[Files.current_caller]
            Files.current_caller = Files.current_caller - 1
            refresh()
        end
    end

    Files:addChild(GUI.roundedButton(Files.width - 17, 1, 6, 3, 0xaa51b0, 0xFFFFFF, 0x880000, 0xFFFFFF, "<>")).onTouch = function()
        Files.overview:remove()
        refresh()
    end

    -- Scroll view
    view.eventHandler = function(Desktop, view, ename, idds, x, y, chsc)
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

    -- Start draw objects
    local x1 = 5
    local y1 = 2

    for file in fs.list(Files.dir_root) do
        local object = GUI.container(x1, y1, 6, 3)
        object:addChild(GUI.image(1, 1, buffer.loadImage("/OS/Applications/Files/Icon.pic")))
        object:addChild(GUI.text(1, 3, 0xFFFFFF, file))
        view:addChild(object)

        local folder = GUI.framedButton(x1 - 1, y1 - 1, 8, 5, 0xFFFFFF, 0xFFFFFF, 0x000000, 0x000000, "")
        view:addChild(folder).onTouch = function(Desktop, folder, enm, iddp, x, y, click)
            if enm == "touch" then
                if click == 0 then
                    if unicode.sub(file, -1, -1) == "/" then
                        Files.current_caller = Files.current_caller + 1
                        Files.history[Files.current_caller] = Files.dir_root
                        Files.dir_root = Files.dir_root .. file
                        Files.overview:remove()
                        refresh()
                    end
                else
                    -- Menu eject
                    if unicode.sub(file, -1, -1) == "/" then
                        local alt = GUI.addContextMenu(Desktop, x, y)
                        alt:addItem("Открыть").onTouch = function()
                            Files.current_caller = Files.current_caller + 1
                            Files.history[Files.current_caller] = Files.dir_root
                            Files.dir_root = Files.dir_root .. file
                            Files.overview:remove()
                            refresh()
                        end
                        alt:addItem("Переименовать").onTouch = function()
                            system.prompt("Переименовать")
                            island.overs.callback = function(inp)
                                fs.rename(Files.dir_root .. file, Files.dir_root .. inp)
                                refresh()
                            end
                            Desktop:draw()
                        end
                        alt:addItem("Удалить").onTouch = function()
                            fs.remove(Files.dir_root .. file)
                            refresh()
                        end
                        alt:addSeparator()
                        alt:addItem("Свойства").onTouch = function()
                            drawAbout(Files.dir_root .. file)
                        end
                    else
                        local alt = GUI.addContextMenu(Desktop, x, y)
                        alt:addItem("Редактировать").onTouch = function()
                            exe("Editor", Files.dir_root .. file)
                            Desktop:draw(true)
                        end
                        alt:addItem("Переименовать").onTouch = function()
                            system.prompt("Переименовать")
                            island.overs.callback = function(input)
                                fs.rename(Files.dir_root .. file, Files.dir_root .. input)
                                refresh()
                            end
                            Desktop:draw()
                        end
                        alt:addItem("Скопировать").onTouch = function()
                            local container = GUI.addBackgroundContainer(Desktop, true, true, "Копировать")
                            local filesystemChooser =
                                container.layout:addChild(
                                GUI.filesystemChooser(
                                    2,
                                    2,
                                    30,
                                    3,
                                    0xE1E1E1,
                                    0x888888,
                                    0x3C3C3C,
                                    0x888888,
                                    nil,
                                    "ОК",
                                    "Назад",
                                    "Куда копировать",
                                    "/"
                                )
                            )
                            filesystemChooser:setMode(GUI.IO_MODE_OPEN, GUI.IO_MODE_DIRECTORY)
                            filesystemChooser.onSubmit = function(path)
                                fs.copy(Files.dir_root .. file, path .. file)
                                container:remove()
                            end
                        end
                        alt:addItem("Переместить").onTouch = function()
                            local container = GUI.addBackgroundContainer(Desktop, true, true, "Переместить")
                            local filesystemChooser =
                                container.layout:addChild(
                                GUI.filesystemChooser(
                                    2,
                                    2,
                                    30,
                                    3,
                                    0xE1E1E1,
                                    0x888888,
                                    0x3C3C3C,
                                    0x888888,
                                    nil,
                                    "ОК",
                                    "Назад",
                                    "Куда переместить",
                                    "/"
                                )
                            )
                            filesystemChooser:setMode(GUI.IO_MODE_OPEN, GUI.IO_MODE_DIRECTORY)
                            filesystemChooser.onSubmit = function(path)
                                fs.copy(Files.dir_root .. file, path .. file)
                                fs.remove(Files.dir_root .. file)
                                container:remove()
                            end
                            refresh()
                        end
                        alt:addItem("Удалить").onTouch = function()
                            fs.remove(Files.dir_root .. file)
                            refresh()
                        end
                        alt:addSeparator()
                        alt:addItem("Свойства").onTouch = function()
                            drawAbout(Files.dir_root .. file)
                        end
                    end
                end
            end
        end

        -- Math render
        x1 = x1 + 15

        if x1 >= 80 then
            x1 = 5
            y1 = y1 + 6
        end
    end

    Desktop:draw()
end

function drawAbout(path)
    local about = GUI.defaultWindow(6, 6, 40, 20)
    if unicode.sub(path, -1, -1) == "/" then
        about:addChild(GUI.image(17, 4, buffer.loadImage("/OS/Applications/Files/Icon.pic")))
        about:addChild(GUI.text(2, 8, 0xFFFFFF, "Путь: " .. path))
        if fs.size(path) ~= 0 then
            about:addChild(GUI.text(2, 9, 0xFFFFFF, "Размер: " .. (fs.size(path) / 1000) .. "КБ"))
        else
            about:addChild(GUI.text(2, 9, 0xFFFFFF, "Размер: 0Б"))
        end
    else
        about:addChild(GUI.image(17, 4, buffer.loadImage("/OS/Applications/Files/Images/File.pic")))
        about:addChild(GUI.text(2, 8, 0xFFFFFF, "Путь файла: " .. path))
        if fs.size(path) ~= 0 then
            about:addChild(GUI.text(2, 9, 0xFFFFFF, "Размер: " .. (fs.size(path) / 1000) .. "КБ"))
        else
            about:addChild(GUI.text(2, 9, 0xFFFFFF, "Размер: 0Б"))
        end
    end
    Desktop:addChild(about)
    Desktop:draw()
end

function Files.isl_call(overs)
    overs:addChild(GUI.roundedButton(2, 4, 16, 3, 0xaa51b0, 0xFFFFFF, 0x880000, 0xFFFFFF, "Создать файл")).onTouch = function()
        system.prompt("Имя файла")
        island.overs.callback = function(inp)
            if fs.exists(Files.dir_root .. inp) then
                alert("Файл уже существует")
            else
                local file = io_open(Files.dir_root .. inp, "w")
                file:write(
                    "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n"
                )
                file:close()
                refresh()
            end
        end
    end
    overs:addChild(GUI.roundedButton(24, 4, 17, 3, 0xaa51b0, 0xFFFFFF, 0x880000, 0xFFFFFF, "Создать папку")).onTouch = function()
        system.prompt("Имя папки")
        island.overs.callback = function(inp)
            if fs.exists(Files.dir_root .. inp) then
              alert("Папка уже существует")
          else
                fs.makeDirectory(Files.dir_root .. inp)
                refresh()
         end
        end
    end
    island.open(12, 8)
end



refresh()
