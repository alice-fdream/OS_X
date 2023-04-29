local GUI = require("GUI")
local computer = require("computer")
local fs = require('filesystem')
local unicode = require('unicode')
local component = require('component')
local key = require('serialization')

local island = {}
island.isOpen = 0

function island.start()

	island.container = GUI.container((160/2) - (22/2), 1, 22, 3)
	island.dynamic_island_main = GUI.roundedButton(3, 1, 20, 3, 0x000000, 0xFFFFFF, 0x000000, 0x78f542, "")
	island.container:addChild(island.dynamic_island_main)
	island.label = GUI.text(1, 2, 0xFFFFFF, "")
	island.container:addChild(island.label)
	Desktop:addChild(island.container)
	island.overs = GUI.container(3, 4, 40, 20)
	island.container:addChild(island.overs)
end

function island.setProcess(process)
	island.close()
	island.overs:remove()
	island.overs = GUI.container(3, 4, 40, 20)
	island.container:addChild(island.overs)
	Desktop:draw()
	island.dynamic_island_main.width = unicode.len(process.json.main.name) + 2
	island.container.x = (160/2) - (island.dynamic_island_main.width / 2)
	island.label.localX = 4
	island.label.text = process.json.main.name
	island.dynamic_island_main.onTouch = function()
		process.isl_call(island.overs)
	end
	island.process = process
	Desktop:draw()
end

function island.resetProcess()
	island.close()
	island.overs:remove()
	island.overs = GUI.container(3, 4, 40, 20)
	island.container:addChild(island.overs)
	Desktop:draw()
	island.label.text = ""
	island.dynamic_island_main.onTouch = function()
	end
	Desktop:draw()
end



function island.open(width_crat, height)
    if island.isOpen == 0 then
    	island.isOpen = 1
    	island.args = {}
    	island.args.width_crat = width_crat
    	island.args.height = height
        local i = 1
        while true do
            if i == width_crat then
                break
            end
            island.container.localX = island.container.localX - 1
            island.container.width = island.container.width + 3
            island.dynamic_island_main.width = island.dynamic_island_main.width + 2
            island.label.localX = island.label.localX + 1
            i = i + 1
            
            Desktop:draw()
        end

        local i = 1
        while true do
            if i == height then
                break
            end
            island.container.height = island.container.height + 1
            island.dynamic_island_main.height = island.dynamic_island_main.height + 1
            i = i + 1
            
            Desktop:draw()
        end
    else
    	island.close()
    end
end

function island.close()
	if island.isOpen == 1 then
		island.isOpen = 0
    	local width_crat = island.args.width_crat
    	local height = island.args.height
    	
    	
        local i = 1
        while true do
            if i == height then
                break
            end
            island.container.height = island.container.height - 1
            island.dynamic_island_main.height = island.dynamic_island_main.height - 1
            i = i + 1
            
            Desktop:draw()
        end
    	
        local i = 1
        while true do
            if i == width_crat then
                break
            end
            island.container.localX = island.container.localX + 1
            island.container.width = island.container.width - 3
            island.dynamic_island_main.width = island.dynamic_island_main.width - 2
            island.label.localX = island.label.localX - 1
            i = i + 1
            
            Desktop:draw()
        end

	end
end




return island