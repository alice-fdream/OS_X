local GUI = require("GUI")
local computer = require("computer")
local fs = require("filesystem")
local event = require("event")
local unicode = require("unicode")
local system = require("system")
local island = require("island")

local textEditor = GUI.defaultWindow(1, 2, 160, 49)
local memory = {}
local caller = 1
local current_object = 0

textEditor.overview = GUI.container(2, 4, 158, 46)
textEditor.view = GUI.container(1, 1, textEditor.overview.width, textEditor.overview.height)
textEditor.overview:addChild(textEditor.view)



local file = ...

if file then
	local counter = 1
	for line in io.lines(file) do
		line = line:gsub("\t", "  "):gsub("\r\n", "\n")
		local input = GUI.input(1, counter, textEditor.overview.width, 1, 0x141313, 0xFFFFFF, 0x999999, 0x2e2b2b, 0xFFFFFF, line)
		memory[caller] = input
		textEditor.view:addChild(input)
		counter = counter + 1
		caller = counter
	end
	textEditor.view.height = counter
end

textEditor:addChild(textEditor.overview)
textEditor.view.eventHandler = function(Desktop, view, ename, idds, x, y, chsc)
	if ename == "scroll" then
		if chsc >= 1 then
			if view.localY ~= 1 then
				textEditor.view.localY = textEditor.view.localY + 1
				Desktop:draw()
			end
        else
            textEditor.view.localY = textEditor.view.localY - 1
            Desktop:draw()
        end
    end
end

function textEditor.isl_call(overs)
    overs:addChild(GUI.roundedButton(2, 4, 39, 3, 0xaa51b0, 0xFFFFFF, 0x880000, 0xFFFFFF, "Сохранить")).onTouch = function()
        local i = 1
        local buffer = ""
        while i <= textEditor.view.height - 1 do
            buffer = buffer .. memory[i].text .. "\n"
            i = i + 1
        end

        local trigger = io.open(file, "w")
        trigger:write(buffer)
        trigger:close()
        GUI.alert("Файл успешно сохранен")
        island.close()
    end
    island.open(12, 8)
end

Desktop:draw()