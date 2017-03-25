--[[
	---------------------------------------------------------
    RFID application reads Arduino + RC522 MIFARE tags from
	battery and stores information to logfile.
	
	This is minimized DC/DS-16 version, requires firmware
	4.20 or newer. 
	
	RC-Thoughts Jeti RFID-Sensor and RFID-Battery application
	is compatible with Revo Bump and does not disturb 
	Robbe BID usage (Onki's solution)
	
	Requires RFID-Sensor with firmware 1.7 or up
	
	Italian translation courtesy from Fabrizio Zaini
	---------------------------------------------------------
	RFID application is part of RC-Thoughts Jeti Tools.
	---------------------------------------------------------
	Released under MIT-license by Tero @ RC-Thoughts.com 2017
	---------------------------------------------------------
--]]
collectgarbage()
----------------------------------------------------------------------
-- Locals for the application
local rfidVersion, tCurRFID, tStrRFID = "2.1", 0, 0
local rfidId, rfidParam, rfidSens, mahId, mahParam, mahSens
local capaAlarm, capaAlarmTr, alarmVoice, vPlayed, tagID
local rfidTime, annGo, annSw, tagCapa, alarm1Tr
local tagValid, tSetAlm, percVal, annTime = 0, 0, "-", 0
local sensorLa1list = { "..." }
local sensorId1list = { "..." }
local sensorPa1list = { "..." }
local trans8
----------------------------------------------------------------------
-- Read translations
local function setLanguage()
    local lng=system.getLocale()
    local file = io.readall("Apps/Lang/RCT-Rfid.jsn")
    local obj = json.decode(file)
    if(obj) then
        trans8 = obj[lng] or obj[obj.default]
    end
end
----------------------------------------------------------------------
-- Read available sensors for user to select
local function readSensors()
    local sensors = system.getSensors()
    local format = string.format
    local insert = table.insert
    for i, sensor in ipairs(sensors) do
        if (sensor.label ~= "") then
            insert(sensorLa1list, format("%s", sensor.label))
            insert(sensorId1list, format("%s", sensor.id))
            insert(sensorPa1list, format("%s", sensor.param))
        end
    end
end
----------------------------------------------------------------------
-- Draw the telemetry windows
local function printBattery()
    local lcd = lcd
    local drawText = lcd.drawText
    local getTextWidth = lcd.getTextWidth
    local bold = FONT_BOLD

    if (tagID == 0) then
        drawText((150 - getTextWidth(bold, trans8.emptyTag)) / 2, 24, trans8.emptyTag, bold)
    elseif (mahId == 0) then
        drawText((150 - getTextWidth(bold, trans8.noCurr)) / 2, 24, trans8.noCurr, bold)
    elseif (percVal ~= "-") then
        lcd.drawRectangle(6, 9, 26, 55)
        lcd.drawFilledRectangle(13, 6, 12, 4)
        local chgY = (65 - (percVal * 0.54))
        local chgH = ((percVal * 0.54) - 1)
        lcd.drawFilledRectangle(7, chgY, 24, chgH)
        drawText(148 - getTextWidth(FONT_MAXI, string.format("%.1f%%", percVal)), 15, string.format("%.1f%%", percVal), FONT_MAXI)
    else
        drawText((150 - getTextWidth(bold, trans8.noPack)) / 2, 24, trans8.noPack, bold)
    end
    collectgarbage()
end
----------------------------------------------------------------------
-- Store settings when changed by user
--
local function capaAlarmChanged(value)
    local pSave = system.pSave

    capaAlarm = value
    pSave("capaAlarm", value)

    alarm1Tr = string.format("%.1f", capaAlarm)
    pSave("capaAlarmTr", capaAlarmTr)
    system.registerTelemetry(1, trans8.telLabel, 2, printBattery)
end

local function alarmVoiceChanged(value)
    alarmVoice = value
    system.pSave("alarmVoice", value)
end

--
local function sensorIDChanged(value)
    local pSave = system.pSave
    local format = string.format

    rfidSens = value
    pSave("rfidSens", value)
    rfidId = format("%s", sensorId1list[rfidSens])
    rfidParam = format("%s", sensorPa1list[rfidSens])
    if (rfidId == "...") then
        rfidId = 0
        rfidParam = 0
    end
    pSave("rfidId", rfidId)
    pSave("rfidParam", rfidParam)
end

local function sensorMahChanged(value)
    local pSave = system.pSave
    local format = string.format

    mahSens = value
    pSave("mahSens", value)
    mahId = format("%s", sensorId1list[mahSens])
    mahParam = format("%s", sensorPa1list[mahSens])
    if (mahId == "...") then
        mahId = 0
        mahParam = 0
    end
    pSave("mahId", mahId)
    pSave("mahParam", mahParam)
end

local function annSwChanged(value)
    annSw = value
    system.pSave("annSw", value)
end
----------------------------------------------------------------------
-- Draw the main form (Application inteface)
local function initForm()
    local form = form
    local addRow = form.addRow
    local addLabel = form.addLabel

    form.setButton(1, ":tools")

    addRow(1)
    addLabel({ label = "---   RC-Thoughts Jeti Tools    ---", font = FONT_BIG })

    addRow(1)
    addLabel({ label = trans8.labelCommon, font = FONT_BOLD })

    addRow(2)
    addLabel({ label = trans8.sensorID })
    form.addSelectbox(sensorLa1list, rfidSens, true, sensorIDChanged)

    addRow(2)
    addLabel({ label = trans8.sensorMah })
    form.addSelectbox(sensorLa1list, mahSens, true, sensorMahChanged)

    addRow(1)
    addLabel({ label = trans8.labelAlarm, font = FONT_BOLD })

    addRow(2)
    addLabel({ label = trans8.AlmVal })
    form.addIntbox(capaAlarm, 0, 100, 0, 0, 1, capaAlarmChanged)

    addRow(2)
    addLabel({ label = trans8.selAudio })
    form.addAudioFilebox(alarmVoice, alarmVoiceChanged)

    addRow(2)
    addLabel({ label = trans8.annSw, width = 220 })
    form.addInputbox(annSw, true, annSwChanged)

    addRow(1)
    addLabel({ label = "Powered by RC-Thoughts.com - v." .. rfidVersion .. " ", font = FONT_MINI, alignRight = true })

    form.setFocusedRow(1)
end

----------------------------------------------------------------------
local function loop()
    local system = system
    -- RFID reading and battery-definition
    if (rfidSens > 1) then
        rfidTime = system.getTime()
        tagID = system.getSensorByID(rfidId, 1)
        tagCapa = system.getSensorByID(rfidId, 2)
        annGo = system.getInputsVal(annSw)
        if (tagID and tagID.valid) then
            tagValid = 1
            tagID = tagID.value
            tagCapa = tagCapa.value
        else
            percVal = "-"
            tagValid = 0
        end
        -- Capacity percentage calculation and voice alert config
        if (mahSens > 1) then
            local mahCapa = system.getSensorByID(mahId, mahParam)
            if (mahCapa and mahCapa.valid) then
                mahCapa = mahCapa.value
                if (tagValid == 1) then
                    if (tSetAlm == 0) then
                        tCurRFID = rfidTime
                        tStrRFID = rfidTime + 5
                        tSetAlm = 1
                    else
                        tCurRFID = system.getTime()
                    end
                    local resRFID = (((tagCapa - mahCapa) * 100) / tagCapa)
                    if (resRFID < 0) then
                        resRFID = 0
                    else
                        if (resRFID > 100) then
                            resRFID = 100
                        end
                    end
                    percVal = string.format("%.1f", resRFID)
                    if (alarm1Tr == 0) then
                        vPlayed = 0
                        tStrRFID = 0
                    else
                        if (resRFID <= capaAlarm) then
                            if (tStrRFID <= tCurRFID and tSetAlm == 1) then
                                if (vPlayed == 0 or vPlayed == nil and alarmVoice ~= "...") then
                                    system.playFile(alarmVoice, AUDIO_AUDIO_QUEUE)
                                    vPlayed = 1
                                end
                            end
                        else
                            vPlayed = 0
                        end
                    end
                else
                    percVal = "-"
                    vPlayed = 0
                    tSetAlm = 0
                end
            end
        end
    else
        rfidTime = 0
    end
    if (annGo == 1 and percVal ~= "-" and annTime < rfidTime) then
        system.playNumber(percVal, 0, "%", trans8.annCap)
        annTime = rfidTime + 10
    end
    collectgarbage()
end

----------------------------------------------------------------------
-- Application initialization
local function init()
    local pLoad = system.pLoad
    rfidId = pLoad("rfidId", 0)
    rfidParam = pLoad("rfidParam", 0)
    rfidSens = pLoad("rfidSens", 0)
    mahId = pLoad("mahId", 0)
    mahParam = pLoad("mahParam", 0)
    mahSens = pLoad("mahSens", 0)
    capaAlarm = pLoad("capaAlarm", 0)
    capaAlarmTr = pLoad("capaAlarmTr", 1)
    alarmVoice = pLoad("alarmVoice", "...")
    annSw = pLoad("annSw")
    readSensors()
    system.registerForm(1, MENU_APPS, trans8.appName, initForm, keyPressed)
    system.registerTelemetry(1, "RFID-Battery", 2, printBattery)
    collectgarbage()
end

----------------------------------------------------------------------
setLanguage()
collectgarbage()
return { init = init, loop = loop, author = "RC-Thoughts", version = rfidVersion, name = trans8.appName }