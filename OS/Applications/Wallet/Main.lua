local GUI = require("GUI")
local computer = require("computer")
local fs = require("filesystem")
local event = require("event")
local unicode = require("unicode")
local system = require("system")
local component = require("component")
local serial = require("serialization")
local modem = component.modem
local island = require("island")

modem.open(1023)

local wallet = GUI.defaultWindow(1, 2, 80, 25)

if wallet.json.app_config.bank == nil or wallet.json.app_config.bank == "" then
    wallet:addChild(GUI.text(2, 4, 0xFFFFFF, "Банк не подключен"))
else
    if wallet.json.app_config.card == nil or wallet.json.app_config.card == "" then
        wallet:addChild(GUI.text(2, 4, 0xFFFFFF, "Карта отсутствует"))
    else
    	
    end
end

function wallet.isl_call(overs)
    if wallet.json.app_config.bank == nil or wallet.json.app_config.bank == "" then
        overs:addChild(GUI.roundedButton(2, 4, 33, 3, 0xaa51b0, 0xFFFFFF, 0x880000, 0xFFFFFF, "Подключиться")).onTouch = function()
            system.prompt("Название банка", 17, 8)
            island.overs.callback = function(input)
                local request = {}
                request.bank = input
                request.token = "connect"

                modem.broadcast(1023, serial.serialize(request))
                local _, _, from, port, _, message = event.pull(2, "modem_message")
                if not message then
                    error("Банк не отвечает")
                else
                    local data = serial.unserialize(message)
                    if data.bank and data.address then
                        wallet.json.app_config.bank = data.address
                        local st = io.open("/OS/Applications/Wallet/Permissions/config", "w")
                        st:write(serial.serialize(wallet.json))
                        st:close()
                        wallet.actionButton.onTouch()
                        exe("Wallet")
                    end
                end
            end
        end
    elseif wallet.json.app_config.card == nil or wallet.json.app_config.card == "" then
        overs:addChild(GUI.roundedButton(2, 4, 33, 3, 0xaa51b0, 0xFFFFFF, 0x880000, 0xFFFFFF, "Добавить карту")).onTouch = function()
            system.prompt("Придумайте PIN-CODE", 17, 8)
            island.overs.callback = function(input)
                system.prompt("Введите владельца карты", 17, 8)
                island.overs.callback = function(cardholder)
                    local request = {}
                    request.token = "add_card"
                    request.pin = input
                    request.valid = cardholder
                    modem.send(wallet.json.app_config.bank, 1023, serial.serialize(request))
                    local _, _, from, port, _, message = event.pull(2, "modem_message")
                    if not message then
                        error("Банк не отвечает")
                    else
                        local data = serial.unserialize(message)
                        wallet.json["app_config"].card = data.card
                        local st = io.open("/OS/Applications/Wallet/Permissions/config", "w")
                        st:write(serial.serialize(wallet.json))
                        st:close()
                        GUI.alert("Карта создана")
                        wallet.actionButton.onTouch()
                        exe("Wallet")
                    end
                end
            end
        end
    end
    island.open(14, 8)
end


Desktop:draw()

