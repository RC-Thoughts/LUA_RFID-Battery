--[[
	---------------------------------------------------------
    RFID application reads Arduino + RC522 MIFARE tags from
	battery and stores information to logfile.

	Logging includes date/time, modelname, batteryname,
	capacity, used mAh and battery cycle-count.

	RC-Thoughts Jeti RFID-Sensor and RFID-Battery application
	is compatible with Revo Bump and does not disturb
	Robbe BID usage (Onki's solution)

	Logfile is in csv-format for full compatibility.

	Requires RFID-Sensor with firmware 1.7 or up

	Italian translation courtesy from Fabrizio Zaini
	---------------------------------------------------------
	RFID application is part of RC-Thoughts Jeti Tools.
	---------------------------------------------------------
	Released under MIT-license by Tero @ RC-Thoughts.com 2017
	---------------------------------------------------------
--]]
----------------------------------------------------------------------
-- Locals for the application
local rfidId, rfidParam, rfidSens, mahId, mahParam, mahSens
local tagId, tagCapa, tagCount, tagCells, rfidTime, modName, modNameAudio
local voltId, voltParam, voltSens, voltAlarm, voltThreshold, annGo, annSw
local thresholdTime, nextPlayTime, vVoltPlayed, voltageChecked
local capaAlarm, capaAlarmTr, alarmVoice, vPlayed
local tagValid, tVoltStrRFID, tCurVoltRFID, rfidRun, annTime = false,0,0,false,0
local rfidTrig, battDspCapa, battDspCount, redAlert = 0,0,0,false
local tSetAlm, tSetAlmVolt, mahLog, tagCellsDsp = 0,0,false,0
local battDspName, battLog, percVal = "-", "-", "-"
local battName1, battName2, battName3, battName4, battName5
local battName6, battName7, battName8, battName9, battName10
local battName11, battName12, battName13, battName14, battName15
local battId1, battId2, battId3, battId4, battId5
local battId6, battId7, battId8, battId9, battId10
local battId11, battId12, battId13, battId14, battId15
local rptAlmlist = {}
local rptAlmVoltlist = {}
local sensorLa1list = {"..."}
local sensorId1list = {"..."}
local sensorPa1list = {"..."}
local sensorLa2list = {"..."}
local sensorId2list = {"..."}
local sensorPa2list = {"..."}
local sensorLa3list = {"..."}
local sensorId3list = {"..."}
local sensorPa3list = {"..."}
----------------------------------------------------------------------
-- Function for translation file-reading
local function readFile(path)
	local f = io.open(path,"r")
	local lines={}
	if(f) then
		while 1 do
			local buf=io.read(f,512)
			if(buf ~= "")then
				lines[#lines+1] = buf
				else
				break
			end
		end
		io.close(f)
		return table.concat(lines,"")
	end
end
----------------------------------------------------------------------
-- Read translations
local function setLanguage()
	local lng=system.getLocale();
	local file = readFile("Apps/Lang/RCT-Rfid.jsn")
	local obj = json.decode(file)
	if(obj) then
		trans8 = obj[lng] or obj[obj.default]
	end
end
----------------------------------------------------------------------
-- Read available sensors for user to select
local sensors = system.getSensors()
for i,sensor in ipairs(sensors) do
	if (sensor.label ~= "") then
		table.insert(sensorLa1list, string.format("%s", sensor.label))
		table.insert(sensorId1list, string.format("%s", sensor.id))
		table.insert(sensorPa1list, string.format("%s", sensor.param))
		table.insert(sensorLa2list, string.format("%s", sensor.label))
		table.insert(sensorId2list, string.format("%s", sensor.id))
		table.insert(sensorPa2list, string.format("%s", sensor.param))
		table.insert(sensorLa3list, string.format("%s", sensor.label))
		table.insert(sensorId3list, string.format("%s", sensor.id))
		table.insert(sensorPa3list, string.format("%s", sensor.param))
	end
end
----------------------------------------------------------------------
-- Draw the telemetry windows
local function printBattery()
	local txtr,txtg,txtb
	local bgr,bgg,bgb = lcd.getBgColor()
	if (bgr+bgg+bgb)/3 >128 then
		txtr,txtg,txtb = 0,0,0
		else
		txtr,txtg,txtb = 255,255,255
	end
	if (battDspName == "-" or battDspName == "E") then
		if(battDspName == "E") then
			lcd.drawText((150 - lcd.getTextWidth(FONT_BOLD,trans8.emptyTag))/2,3,trans8.emptyTag,FONT_BOLD)
		else
			lcd.drawText((150 - lcd.getTextWidth(FONT_BOLD,trans8.noPack))/2,3,trans8.noPack,FONT_BOLD)
		end
		lcd.drawText((57 - lcd.getTextWidth(FONT_BIG,"-"))/2,25,"-",FONT_BIG)
		lcd.drawText((210 - lcd.getTextWidth(FONT_BIG,"-"))/2,25,"-",FONT_BIG)
		lcd.drawText((210 - lcd.getTextWidth(FONT_MINI,trans8.telCapacity))/2,51,trans8.telCapacity,FONT_MINI)
		lcd.drawText((57 - lcd.getTextWidth(FONT_MINI,trans8.telCycles))/2,51,trans8.telCycles,FONT_MINI)
	else
		if (percVal == "-" or mahId == 0 ) then
			lcd.drawText((150 - lcd.getTextWidth(FONT_BOLD,battDspName))/2,3,battDspName,FONT_BOLD)
			lcd.drawText((57 - lcd.getTextWidth(FONT_BIG,string.format("%.0f",battDspCount)))/2,25,string.format("%.0f",battDspCount),FONT_BIG)
			lcd.drawText((210 - lcd.getTextWidth(FONT_BIG,string.format("%.0f",battDspCapa)))/2,25,string.format("%.0f",battDspCapa),FONT_BIG)
			lcd.drawText((210 - lcd.getTextWidth(FONT_MINI,trans8.telCapacity))/2,51,trans8.telCapacity,FONT_MINI)
			lcd.drawText((57 - lcd.getTextWidth(FONT_MINI,trans8.telCycles))/2,51,trans8.telCycles,FONT_MINI)
		else
			lcd.drawRectangle(5,9,26,41)
			lcd.drawFilledRectangle(12,6,12,4)
			chgY = (50-(percVal*0.39))
			chgH = (percVal*0.39)-1
			if(redAlert) then
				lcd.setColor(240,0,0)
			else
				lcd.setColor(0,196,0)
			end
			lcd.drawFilledRectangle(6,chgY,24,chgH)
			lcd.setColor(txtr,txtg,txtb)
			lcd.drawText(43,4,battDspName,FONT_MINI)
			if (redAlert) then
				lcd.drawText(144 - lcd.getTextWidth(FONT_MAXI,string.format("LOW")),15,string.format("LOW"),FONT_MAXI)
			else
				lcd.drawText(144 - lcd.getTextWidth(FONT_MAXI,string.format("%.1f%%",percVal)),15,string.format("%.1f%%",percVal),FONT_MAXI)
			end
			lcd.drawText(41,52,string.format("%.0f %s",battDspCount,trans8.telCycShort),FONT_MINI)
			lcd.drawText(85,52,string.format("%.0f %s",battDspCapa,trans8.telCapShort),FONT_MINI)
			lcd.drawText((36 - lcd.getTextWidth(FONT_NORMAL,string.format("%.0f%s",tagCellsDsp,"S")))/2,49,string.format("%.0f%s",tagCellsDsp,"S"),FONT_NORMAL)
		end
	end
end
----------------------------------------------------------------------
-- Store settings when changed by user
local function battName1Changed(value)
	battName1=value
	battName1 = battName1:gsub("[^%w ]", "")
	table.remove (battNames, 1)
	table.insert (battNames, 1, value)
	system.pSave("battNames",{battName1,battName2,battName3,battName4,battName5,battName6,battName7,battName8,battName9,battName10})
	system.registerTelemetry(1,trans8.telLabel,2,printBattery)
end

local function battName2Changed(value)
	battName2=value
	battName = battName2:gsub("[^%w ]", "")
	table.remove (battNames, 2)
	table.insert (battNames, 2, value)
	system.pSave("battNames",{battName1,battName2,battName3,battName4,battName5,battName6,battName7,battName8,battName9,battName10})
	system.registerTelemetry(1,trans8.telLabel,2,printBattery)
end

local function battName3Changed(value)
	battName3=value
	battName3 = battName3:gsub("[^%w ]", "")
	table.remove (battNames, 3)
	table.insert (battNames, 3, value)
	system.pSave("battNames",{battName1,battName2,value,battName4,battName5,battName6,battName7,battName8,battName9,battName10})
	system.registerTelemetry(1,trans8.telLabel,2,printBattery)
end

local function battName4Changed(value)
	battName4=value
	battName4 = battName4:gsub("[^%w ]", "")
	table.remove (battNames, 4)
	table.insert (battNames, 4, value)
	system.pSave("battNames",{battName1,battName2,value,battName4,battName5,battName6,battName7,battName8,battName9,battName10})
	system.registerTelemetry(1,trans8.telLabel,2,printBattery)
end

local function battName5Changed(value)
	battName5=value
	battName5 = battName5:gsub("[^%w ]", "")
	table.remove (battNames, 5)
	table.insert (battNames, 5, value)
	system.pSave("battNames",{battName1,battName2,battName3,battName4,battName5,battName6,battName7,battName8,battName9,battName10})
	system.registerTelemetry(1,trans8.telLabel,2,printBattery)
end

local function battName6Changed(value)
	battName6=value
	battName6 = battName6:gsub("[^%w ]", "")
	table.remove (battNames, 6)
	table.insert (battNames, 6, value)
	system.pSave("battNames",{battName1,battName2,battName3,battName4,battName5,battName6,battName7,battName8,battName9,battName10})
	system.registerTelemetry(1,trans8.telLabel,2,printBattery)
end

local function battName7Changed(value)
	battName7=value
	battName7 = battName7:gsub("[^%w ]", "")
	table.remove (battNames, 7)
	table.insert (battNames, 7, value)
	system.pSave("battNames",{battName1,battName2,battName3,battName4,battName5,battName6,battName7,battName8,battName9,battName10})
	system.registerTelemetry(1,trans8.telLabel,2,printBattery)
end

local function battName8Changed(value)
	battName8=value
	battName8 = battName8:gsub("[^%w ]", "")
	table.remove (battNames, 8)
	table.insert (battNames, 8, value)
	system.pSave("battNames",{battName1,battName2,battName3,battName4,battName5,battName6,battName7,battName8,battName9,battName10})
	system.registerTelemetry(1,trans8.telLabel,2,printBattery)
end

local function battName9Changed(value)
	battName9=value
	battName9 = battName9:gsub("[^%w ]", "")
	table.remove (battNames, 9)
	table.insert (battNames, 9, value)
	system.pSave("battNames",{battName1,battName2,battName3,battName4,battName5,battName6,battName7,battName8,battName9,battName10})
	system.registerTelemetry(1,trans8.telLabel,2,printBattery)
end

local function battName10Changed(value)
	battName10=value
	battName10 = battName10:gsub("[^%w ]", "")
	table.remove (battNames, 10)
	table.insert (battNames, 10, value)
	system.pSave("battNames",{battName1,battName2,battName3,battName4,battName5,battName6,battName7,battName8,battName9,battName10})
	system.registerTelemetry(1,trans8.telLabel,2,printBattery)
end

local function battName11Changed(value)
	battName11=value
	battName11 = battName11:gsub("[^%w ]", "")
	table.remove (battNames, 11)
	table.insert (battNames, 11, value)
	system.pSave("battNames",{battName1,battName2,battName3,battName4,battName5,battName6,battName7,battName8,battName9,battName10,battName11,battName12,battName13,battName14,battName15})
	system.registerTelemetry(1,trans8.telLabel,2,printBattery)
end

local function battName12Changed(value)
	battName12=value
	battName12 = battName12:gsub("[^%w ]", "")
	table.remove (battNames, 12)
	table.insert (battNames, 12, value)
	system.pSave("battNames",{battName1,battName2,battName3,battName4,battName5,battName6,battName7,battName8,battName9,battName10,battName11,battName12,battName13,battName14,battName15})
	system.registerTelemetry(1,trans8.telLabel,2,printBattery)
end

local function battName13Changed(value)
	battName13=value
	battName13 = battName13:gsub("[^%w ]", "")
	table.remove (battNames, 13)
	table.insert (battNames, 13, value)
	system.pSave("battNames",{battName1,battName2,battName3,battName4,battName5,battName6,battName7,battName8,battName9,battName10,battName11,battName12,battName13,battName14,battName15})
	system.registerTelemetry(1,trans8.telLabel,2,printBattery)
end

local function battName14Changed(value)
	battName14=value
	battName14 = battName14:gsub("[^%w ]", "")
	table.remove (battNames, 14)
	table.insert (battNames, 14, value)
	system.pSave("battNames",{battName1,battName2,battName3,battName4,battName5,battName6,battName7,battName8,battName9,battName10,battName11,battName12,battName13,battName14,battName15})
	system.registerTelemetry(1,trans8.telLabel,2,printBattery)
end

local function battName15Changed(value)
	battName15=value
	battName15 = battName15:gsub("[^%w ]", "")
	table.remove (battNames, 15)
	table.insert (battNames, 15, value)
	system.pSave("battNames",{battName1,battName2,battName3,battName4,battName5,battName6,battName7,battName8,battName9,battName10,battName11,battName12,battName13,battName14,battName15})
	system.registerTelemetry(1,trans8.telLabel,2,printBattery)
end
--
local function battId1Changed(value)
	battId1 = value
	table.remove (battIds, 1)
	table.insert (battIds, 1, value)
	system.pSave("battIds",{battId1,battId2,battId3,battId4,battId5,battId6,battId7,battId8,battId9,battId10})
	system.registerTelemetry(1,trans8.telLabel,2,printBattery)
end

local function battId2Changed(value)
	battId2 = value
	table.remove (battIds, 2)
	table.insert (battIds, 2, value)
	system.pSave("battIds",{battId1,battId2,battId3,battId4,battId5,battId6,battId7,battId8,battId9,battId10})
	system.registerTelemetry(1,trans8.telLabel,2,printBattery)
end

local function battId3Changed(value)
	battId3 = value
	table.remove (battIds, 3)
	table.insert (battIds, 3, value)
	system.pSave("battIds",{battId1,battId2,battId3,battId4,battId5,battId6,battId7,battId8,battId9,battId10})
	system.registerTelemetry(1,trans8.telLabel,2,printBattery)
end

local function battId4Changed(value)
	battId4 = value
	table.remove (battIds, 4)
	table.insert (battIds, 4, value)
	system.pSave("battIds",{battId1,battId2,battId3,battId4,battId5,battId6,battId7,battId8,battId9,battId10})
	system.registerTelemetry(1,trans8.telLabel,2,printBattery)
end

local function battId5Changed(value)
	battId5 = value
	table.remove (battIds, 5)
	table.insert (battIds, 5, value)
	system.pSave("battIds",{battId1,battId2,battId3,battId4,battId5,battId6,battId7,battId8,battId9,battId10})
	system.registerTelemetry(1,trans8.telLabel,2,printBattery)
end

local function battId6Changed(value)
	battId6 = value
	table.remove (battIds, 6)
	table.insert (battIds, 6, value)
	system.pSave("battIds",{battId1,battId2,battId3,battId4,battId5,battId6,battId7,battId8,battId9,battId10})
	system.registerTelemetry(1,trans8.telLabel,2,printBattery)
end

local function battId7Changed(value)
	battId7 = value
	table.remove (battIds, 7)
	table.insert (battIds, 7, value)
	system.pSave("battIds",{battId1,battId2,battId3,battId4,battId5,battId6,battId7,battId8,battId9,battId10})
	system.registerTelemetry(1,trans8.telLabel,2,printBattery)
end

local function battId8Changed(value)
	battId8 = value
	table.remove (battIds, 8)
	table.insert (battIds, 8, value)
	system.pSave("battIds",{battId1,battId2,battId3,battId4,battId5,battId6,battId7,battId8,battId9,battId10})
	system.registerTelemetry(1,trans8.telLabel,2,printBattery)
end

local function battId9Changed(value)
	battId9 = value
	table.remove (battIds, 9)
	table.insert (battIds, 9, value)
	system.pSave("battIds",{battId1,battId2,battId3,battId4,battId5,battId6,battId7,battId8,battId9,battId10})
	system.registerTelemetry(1,trans8.telLabel,2,printBattery)
end

local function battId10Changed(value)
	battId10 = value
	table.remove (battIds, 10)
	table.insert (battIds, 10, value)
	system.pSave("battIds",{battId1,battId2,battId3,battId4,battId5,battId6,battId7,battId8,battId9,battId10})
	system.registerTelemetry(1,trans8.telLabel,2,printBattery)
end

local function battId11Changed(value)
	battId11 = value
	table.remove (battIds, 11)
	table.insert (battIds, 11, value)
	system.pSave("battIds",{battId1,battId2,battId3,battId4,battId5,battId6,battId7,battId8,battId9,battId10,battId11,battId12,battId13,battId14,battId15})
	system.registerTelemetry(1,trans8.telLabel,2,printBattery)
end

local function battId12Changed(value)
	battId12 = value
	table.remove (battIds, 12)
	table.insert (battIds, 12, value)
	system.pSave("battIds",{battId1,battId2,battId3,battId4,battId5,battId6,battId7,battId8,battId9,battId10,battId11,battId12,battId13,battId14,battId15})
	system.registerTelemetry(1,trans8.telLabel,2,printBattery)
end

local function battId13Changed(value)
	battId13 = value
	table.remove (battIds, 13)
	table.insert (battIds, 13, value)
	system.pSave("battIds",{battId1,battId2,battId3,battId4,battId5,battId6,battId7,battId8,battId9,battId10,battId11,battId12,battId13,battId14,battId15})
	system.registerTelemetry(1,trans8.telLabel,2,printBattery)
end

local function battId14Changed(value)
	battId14 = value
	table.remove (battIds, 14)
	table.insert (battIds, 14, value)
	system.pSave("battIds",{battId1,battId2,battId3,battId4,battId5,battId6,battId7,battId8,battId9,battId10,battId11,battId12,battId13,battId14,battId15})
	system.registerTelemetry(1,trans8.telLabel,2,printBattery)
end

local function battId15Changed(value)
	battId15 = value
	table.remove (battIds, 15)
	table.insert (battIds, 15, value)
	system.pSave("battIds",{battId1,battId2,battId3,battId4,battId5,battId6,battId7,battId8,battId9,battId10,battId11,battId12,battId13,battId14,battId15})
	system.registerTelemetry(1,trans8.telLabel,2,printBattery)
end
--
local function modNameChanged(value)
	modName=value
	system.pSave("modName",value)
	system.registerTelemetry(1,trans8.telLabel,2,printBattery)
end

local function modNameAudioChanged(value)
	modNameAudio=value
	system.pSave("modNameAudio",value)
end
--
local function capaAlarmChanged(value)
	capaAlarm=value
	system.pSave("capaAlarm",value)
	alarm1Tr = string.format("%.1f", capaAlarm)
	system.pSave("capaAlarmTr", capaAlarmTr)
	system.registerTelemetry(1,trans8.telLabel,2,printBattery)
end

local function rptAlmChanged(value)
	rptAlm=value
	system.pSave("rptAlm",value)
end

local function alarmVoiceChanged(value)
	alarmVoice=value
	system.pSave("alarmVoice",value)
end
--
local function voltAlarmChanged(value)
	voltAlarm=value
	system.pSave("voltAlarm",value)
	system.registerTelemetry(1,trans8.telLabel,2,printBattery)
end

local function voltThresholdChanged(value)
	voltThreshold=value
	system.pSave("voltThreshold",value)
end

local function rptAlmVoltChanged(value)
	rptAlmVolt=value
	system.pSave("rptAlmVolt",value)
end

local function alarmVoiceVoltChanged(value)
	alarmVoiceVolt=value
	system.pSave("alarmVoiceVolt",value)
end

--
local function sensorIDChanged(value)
	rfidSens=value
	system.pSave("rfidSens",value)
	rfidId = string.format("%s", sensorId1list[rfidSens])
	rfidParam = string.format("%s", sensorPa1list[rfidSens])
	if (rfidId == "...") then
		rfidId = 0
		rfidParam = 0
	end
	system.pSave("rfidId",rfidId)
	system.pSave("rfidParam",rfidParam)
end

local function sensorMahChanged(value)
	mahSens=value
	system.pSave("mahSens",value)
	mahId = string.format("%s", sensorId2list[mahSens])
	mahParam = string.format("%s", sensorPa2list[mahSens])
	if (mahId == "...") then
		mahId = 0
		mahParam = 0
	end
	system.pSave("mahId", mahId)
	system.pSave("mahParam", mahParam)
end

local function sensorVoltChanged(value)
	voltSens=value
	system.pSave("voltSens",value)
	voltId = string.format("%s", sensorId3list[voltSens])
	voltParam = string.format("%s", sensorPa3list[voltSens])
	if (voltId == "...") then
		voltId = 0
		voltParam = 0
	end
	system.pSave("voltId", voltId)
	system.pSave("voltParam", voltParam)
end
--
local function annSwChanged(value)
	annSw = value
	system.pSave("annSw",value)
end
----------------------------------------------------------------------
-- Draw the main form (Application inteface)
local function initForm(subform)
	if(subform == 1) then
		form.setButton(1,":tools",HIGHLIGHTED)
		form.setButton(2,"1-5",ENABLED)
		form.setButton(3,"6-10",ENABLED)
		form.setButton(4,"11-15",ENABLED)

		form.addRow(1)
		form.addLabel({label="---     RC-Thoughts Jeti Tools      ---",font=FONT_BIG})

		form.addRow(1)
		form.addLabel({label=trans8.labelCommon,font=FONT_BOLD})

		form.addRow(2)
		form.addLabel({label=trans8.modName,width=140})
		form.addTextbox(modName,18,modNameChanged,{width=167})

		form.addRow(2)
		form.addLabel({label=trans8.modNameAudio})
		form.addAudioFilebox(modNameAudio,modNameAudioChanged)

		form.addRow(2)
		form.addLabel({label=trans8.sensorID})
		form.addSelectbox(sensorLa1list,rfidSens,true,sensorIDChanged)

		form.addRow(2)
		form.addLabel({label=trans8.sensorMah})
		form.addSelectbox(sensorLa2list,mahSens,true,sensorMahChanged)

		form.addRow(2)
		form.addLabel({label=trans8.sensorVolt})
		form.addSelectbox(sensorLa3list,voltSens,true,sensorVoltChanged)

		form.addRow(1)
		form.addLabel({label=trans8.labelAlarm,font=FONT_BOLD})

		form.addRow(2)
		form.addLabel({label=trans8.AlmVal})
		form.addIntbox(capaAlarm,0,100,0,0,1,capaAlarmChanged)

		form.addRow(2)
		form.addLabel({label=trans8.selAudio})
		form.addAudioFilebox(alarmVoice,alarmVoiceChanged)

		form.addRow(2)
		form.addLabel({label=trans8.rptAlm,width=200})
		form.addSelectbox(rptAlmlist,rptAlm,false,rptAlmChanged)

		form.addRow(1)
		form.addLabel({label=trans8.labelAlarmVolt,font=FONT_BOLD})

		form.addRow(2)
		form.addLabel({label=trans8.AlmValVolt,width=200})
		form.addIntbox(voltAlarm,0,450,0,2,1,voltAlarmChanged)

		form.addRow(2)
		form.addLabel({label=trans8.voltThreshold,width=200})
		form.addIntbox(voltThreshold,0,860,0,2,1,voltThresholdChanged)

		form.addRow(2)
		form.addLabel({label=trans8.selAudio})
		form.addAudioFilebox(alarmVoiceVolt,alarmVoiceVoltChanged)

		form.addRow(2)
		form.addLabel({label=trans8.rptAlm,width=200})
		form.addSelectbox(rptAlmVoltlist,rptAlmVolt,false,rptAlmVoltChanged)

		form.addRow(2)
		form.addLabel({label=trans8.annSw,width=220})
		form.addInputbox(annSw,true,annSwChanged)

		form.addRow(1)
		form.addLabel({label="Powered by RC-Thoughts.com - v."..rfidVersion.." ",font=FONT_MINI, alignRight=true})

		form.setFocusedRow (1)
		formID = 1
		else

		if(subform == 2) then
			form.setButton(1,":tools",ENABLED)
			form.setButton(2,"1-5",HIGHLIGHTED)
			form.setButton(3,"6-10",ENABLED)
			form.setButton(4,"11-15",ENABLED)

			form.addRow(1)
			form.addLabel({label="---     RC-Thoughts Jeti Tools      ---",font=FONT_BIG})

			form.addRow(1)
			form.addLabel({label=trans8.labelBatt,font=FONT_BOLD})

			form.addRow(1)
			form.addLabel({label=trans8.spacer,font=FONT_MINI})

			form.addRow(2)
			form.addLabel({label=string.format("%s 1",trans8.battName),width=140})
			form.addTextbox(battName1,18,battName1Changed,{width=167})

			form.addRow(2)
			form.addLabel({label=trans8.battIDnum})
			form.addIntbox(battId1,0,10000,0,0,1,battId1Changed)

			form.addRow(1)
			form.addLabel({label=trans8.spacer,font=FONT_MINI, align=center})

			form.addRow(2)
			form.addLabel({label=string.format("%s 2",trans8.battName),width=140})
			form.addTextbox(battName2,18,battName2Changed,{width=167})

			form.addRow(2)
			form.addLabel({label=trans8.battIDnum})
			form.addIntbox(battId2,0,10000,0,0,1,battId2Changed)

			form.addRow(1)
			form.addLabel({label=trans8.spacer,font=FONT_MINI})

			form.addRow(2)
			form.addLabel({label=string.format("%s 3",trans8.battName),width=140})
			form.addTextbox(battName3,18,battName3Changed,{width=167})

			form.addRow(2)
			form.addLabel({label=trans8.battIDnum})
			form.addIntbox(battId3,0,10000,0,0,1,battId3Changed)

			form.addRow(1)
			form.addLabel({label=trans8.spacer,font=FONT_MINI})

			form.addRow(2)
			form.addLabel({label=string.format("%s 4",trans8.battName),width=140})
			form.addTextbox(battName4,18,battName4Changed,{width=167})

			form.addRow(2)
			form.addLabel({label=trans8.battIDnum})
			form.addIntbox(battId4,0,10000,0,0,1,battId4Changed)

			form.addRow(1)
			form.addLabel({label=trans8.spacer,font=FONT_MINI})

			form.addRow(2)
			form.addLabel({label=string.format("%s 5",trans8.battName),width=140})
			form.addTextbox(battName5,18,battName5Changed,{width=167})

			form.addRow(2)
			form.addLabel({label=trans8.battIDnum})
			form.addIntbox(battId5,0,10000,0,0,1,battId5Changed)

			form.addRow(1)
			form.addLabel({label=trans8.spacer,font=FONT_MINI})

			form.addRow(1)
			form.addLabel({label="Powered by RC-Thoughts.com - v."..rfidVersion.." ",font=FONT_MINI, alignRight=true})

			form.setFocusedRow (1)
			formID = 2
			else

			if(subform == 3) then
				form.setButton(1,":tools",ENABLED)
				form.setButton(2,"1-5",ENABLED)
				form.setButton(3,"6-10",HIGHLIGHTED)
				form.setButton(4,"11-15",ENABLED)

				form.addRow(1)
				form.addLabel({label="---     RC-Thoughts Jeti Tools      ---",font=FONT_BIG})

				form.addRow(1)
				form.addLabel({label=trans8.labelBatt,font=FONT_BOLD})

				form.addRow(1)
				form.addLabel({label=trans8.spacer,font=FONT_MINI})

				form.addRow(2)
				form.addLabel({label=string.format("%s 6",trans8.battName),width=140})
				form.addTextbox(battName6,18,battName6Changed,{width=167})

				form.addRow(2)
				form.addLabel({label=trans8.battIDnum})
				form.addIntbox(battId6,0,10000,0,0,1,battId6Changed)

				form.addRow(1)
				form.addLabel({label=trans8.spacer,font=FONT_MINI})

				form.addRow(2)
				form.addLabel({label=string.format("%s 7",trans8.battName),width=140})
				form.addTextbox(battName7,18,battName7Changed,{width=167})

				form.addRow(2)
				form.addLabel({label=trans8.battIDnum})
				form.addIntbox(battId7,0,10000,0,0,1,battId7Changed)

				form.addRow(1)
				form.addLabel({label=trans8.spacer,font=FONT_MINI})

				form.addRow(2)
				form.addLabel({label=string.format("%s 8",trans8.battName),width=140})
				form.addTextbox(battName8,18,battName8Changed,{width=167})

				form.addRow(2)
				form.addLabel({label=trans8.battIDnum})
				form.addIntbox(battId8,0,10000,0,0,1,battId8Changed)

				form.addRow(1)
				form.addLabel({label=trans8.spacer,font=FONT_MINI})

				form.addRow(2)
				form.addLabel({label=string.format("%s 9",trans8.battName),width=140})
				form.addTextbox(battName9,18,battName9Changed,{width=167})

				form.addRow(2)
				form.addLabel({label=trans8.battIDnum})
				form.addIntbox(battId9,0,10000,0,0,1,battId9Changed)

				form.addRow(1)
				form.addLabel({label=trans8.spacer,font=FONT_MINI})

				form.addRow(2)
				form.addLabel({label=string.format("%s 10",trans8.battName),width=140})
				form.addTextbox(battName10,18,battName10Changed,{width=167})

				form.addRow(2)
				form.addLabel({label=trans8.battIDnum})
				form.addIntbox(battId10,0,10000,0,0,1,battId10Changed)

				form.addRow(1)
				form.addLabel({label=trans8.spacer,font=FONT_MINI})

				form.addRow(1)
				form.addLabel({label="Powered by RC-Thoughts.com - v."..rfidVersion.." ",font=FONT_MINI, alignRight=true})

				form.setFocusedRow (1)
				formID = 3
				else

				if(subform == 4) then
					form.setButton(1,":tools",ENABLED)
					form.setButton(2,"1-5",ENABLED)
					form.setButton(3,"6-10",ENABLED)
					form.setButton(4,"11-15",HIGHLIGHTED)

					form.addRow(1)
					form.addLabel({label="---     RC-Thoughts Jeti Tools      ---",font=FONT_BIG})

					form.addRow(1)
					form.addLabel({label=trans8.labelBatt,font=FONT_BOLD})

					form.addRow(1)
					form.addLabel({label=trans8.spacer,font=FONT_MINI})

					form.addRow(2)
					form.addLabel({label=string.format("%s 11",trans8.battName),width=140})
					form.addTextbox(battName11,18,battName11Changed,{width=167})

					form.addRow(2)
					form.addLabel({label=trans8.battIDnum})
					form.addIntbox(battId11,0,10000,0,0,1,battId11Changed)

					form.addRow(1)
					form.addLabel({label=trans8.spacer,font=FONT_MINI})

					form.addRow(2)
					form.addLabel({label=string.format("%s 12",trans8.battName),width=140})
					form.addTextbox(battName12,18,battName12Changed,{width=167})

					form.addRow(2)
					form.addLabel({label=trans8.battIDnum})
					form.addIntbox(battId12,0,10000,0,0,1,battId12Changed)

					form.addRow(1)
					form.addLabel({label=trans8.spacer,font=FONT_MINI})

					form.addRow(2)
					form.addLabel({label=string.format("%s 13",trans8.battName),width=140})
					form.addTextbox(battName13,18,battName13Changed,{width=167})

					form.addRow(2)
					form.addLabel({label=trans8.battIDnum})
					form.addIntbox(battId13,0,10000,0,0,1,battId13Changed)

					form.addRow(1)
					form.addLabel({label=trans8.spacer,font=FONT_MINI})

					form.addRow(2)
					form.addLabel({label=string.format("%s 14",trans8.battName),width=140})
					form.addTextbox(battName14,18,battName14Changed,{width=167})

					form.addRow(2)
					form.addLabel({label=trans8.battIDnum})
					form.addIntbox(battId14,0,10000,0,0,1,battId14Changed)

					form.addRow(1)
					form.addLabel({label=trans8.spacer,font=FONT_MINI})

					form.addRow(2)
					form.addLabel({label=string.format("%s 15",trans8.battName),width=140})
					form.addTextbox(battName15,18,battName15Changed,{width=167})

					form.addRow(2)
					form.addLabel({label=trans8.battIDnum})
					form.addIntbox(battId15,0,10000,0,0,1,battId15Changed)

					form.addRow(1)
					form.addLabel({label=trans8.spacer,font=FONT_MINI})

					form.addRow(1)
					form.addLabel({label="Powered by RC-Thoughts.com - v."..rfidVersion.." ",font=FONT_MINI, alignRight=true})

					form.setFocusedRow (1)
					formID = 4
				end
			end
		end
	end
end
----------------------------------------------------------------------
-- Re-init correct form if navigation buttons are pressed
local function keyPressed(key)
	if(key == KEY_1) then
		form.reinit(1)
	end
	if(key == KEY_2) then
		form.reinit(2)
	end
	if(key == KEY_3) then
		form.reinit(3)
	end
	if(key == KEY_4) then
		form.reinit(4)
	end
end
----------------------------------------------------------------------
local function writeLog()
	local noBattLog = 0
	local logFile = "/Log/BattLog.csv"
	local dt = system.getDateTime()
	local dtStampLog = string.format("%d%02d%02dT%d%02d", dt.year, dt.mon, dt.day, dt.hour, dt.min)
	local mahCapaLog = string.format("%.0f",mahCapaLog)
	local battDspCapa = string.format("%.0f",battDspCapa)
	local battDspCount = string.format("%.0f",battDspCount)
	local logLine = string.format("%s,%s,%s,%s,%s,%s,,,", dtStampLog, modName, battLog, battDspCapa, mahCapaLog, battDspCount)
	local writeLog = io.open(logFile,"a")
	if(writeLog) then
		io.write(writeLog, logLine,"\n")
		io.close(writeLog)
	end
	system.messageBox(trans8.logWrite, 5)
end

local function getBattInfoFromTag()
	tagID = system.getSensorByID(rfidId, 1)
	tagCapa = system.getSensorByID(rfidId, 2)
	tagCount = system.getSensorByID(rfidId, 3)
	tagCells = system.getSensorByID(rfidId, 4)
	if(tagID and tagID.valid) then
		tagValid = true
		tagID = tagID.value
		tagCapa = tagCapa.value
		tagCount = tagCount.value
		tagCells = tagCells.value
		tagCellsDsp = tagCells
		if(rfidTrig == 0) then
			rfidTrig = (rfidTime + 30)
		end --rfidTrig == 0
		if(rfidTrig > 0 and rfidTrig < rfidTime) then
			noBattLog = 0
		else
			noBattLog = 1
		end --rfidTrig time check
		if(tagID == battId1) then
			battDspName = battName1
			battLog = battName1
		elseif (tagID == battId2) then
			battDspName = battName2
			battLog = battName2
		elseif (tagID == battId3) then
			battDspName = battName3
			battLog = battName3
		elseif (tagID == battId4) then
			battDspName = battName4
			battLog = battName4
		elseif (tagID == battId5) then
			battDspName = battName5
			battLog = battName5
		elseif (tagID == battId6) then
			battDspName = battName6
			battLog = battName6
		elseif (tagID == battId7) then
			battDspName = battName7
			battLog = battName7
		elseif (tagID == battId8) then
			battDspName = battName8
			battLog = battName8
		elseif (tagID == battId9) then
			battDspName = battName9
			battLog = battName9
		elseif (tagID == battId10) then
			battDspName = battName10
			battLog = battName10
		elseif (tagID == battId11) then
			battDspName = battName11
			battLog = battName11
		elseif (tagID == battId12) then
			battDspName = battName12
			battLog = battName12
		elseif (tagID == battId13) then
			battDspName = battName13
			battLog = battName13
		elseif (tagID == battId14) then
			battDspName = battName14
			battLog = battName14
		elseif (tagID == battId15) then
			battDspName = battName15
			battLog = battName15
		else
			battDspName = "-"
		end
		if(tagID == 0) then
			battDspName = "E"
			noBattLog = 1
		else
			battDspCount = tagCount
			battDspCapa = tagCapa
			rfidRun = true
		end -- tagID == 0
	else -- no tag sensor value
		battDspName = "-"
		rfidRun = false
		tagValid = false
	end -- tag sensor check
end

local function getAvailableCapacity(mahUsed)
	local capAvail = (((tagCapa - mahUsed) * 100) / tagCapa)
	if (capAvail < 0) then
		capAvail = 0
	elseif (capAvail > 100) then
		capAvail = 100
	end
	percVal = string.format("%.1f", capAvail)
	return capAvail
end

local function checkCapacity()
	if (not tagValid or mahSens <= 1) then
		percVal = "-"
		vPlayed = 0
		tSetAlm = 0
		redAlert = false
		return 0
	end
	mahCapa = system.getSensorByID(mahId, mahParam)
	if (not mahCapa or not mahCapa.valid) then
		percVal = "-"
		vPlayed = 0
		tSetAlm = 0
		redAlert = false
		return 0
	end
	local mahUsed = mahCapa.value
	mahCapaLog = mahUsed
	mahLog = true
	local capAvail = getAvailableCapacity(mahUsed)
	if (capAvail <= capaAlarm) then
		redAlert = true
		if(vPlayed == 0 or vPlayed == nil) then
			if (rptAlm == 2 and alarmVoice ~= "...") then
				system.playFile(alarmVoice,AUDIO_AUDIO_QUEUE)
				system.playFile(alarmVoice,AUDIO_AUDIO_QUEUE)
				system.playFile(alarmVoice,AUDIO_AUDIO_QUEUE)
				vPlayed = 1
			elseif (alarmVoice ~= "...") then
				system.playFile(alarmVoice,AUDIO_AUDIO_QUEUE)
				vPlayed = 1
			else
				if (system.getTimeCounter() > nextPlayTime) then
					system.playNumber(mahCapa.value,0,"mAh")
					nextPlayTime = system.getTimeCounter() + 10000
				end
			end --rptAlm and voice check
		end -- vPlayed check
	end -- capAvail check
end

local function checkCapacityOld()
	if (mahSens > 1) then
		mahCapa = system.getSensorByID(mahId, mahParam)
		if (mahCapa and mahCapa.valid) then
			mahCapaLog = mahCapa.value
			mahLog = true
			if(tagValid) then
				if(tSetAlm == 0) then
					tCurRFID = rfidTime
					tStrRFID = rfidTime + 5 --rfid stabilization time in seconds
					tSetAlm = 1
				else
					tCurRFID = system.getTime()
				end
				--(string.format("tagCapa = %d, mahCapa = %d", tagCapa, mahCapa.value))
				resRFID = getAvailableCapacity(mahCapa.value)
				--print("percVal = "..percVal)
				if(alarm1Tr == 0) then
					vPlayed = 0
					tStrRFID = 0
				else
					if(resRFID <= capaAlarm) then
						redAlert = true
						if(tStrRFID <= tCurRFID and tSetAlm == 1) then
							if(vPlayed == 0 or vPlayed == nil) then
								if (rptAlm == 2 and alarmVoice ~= "...") then
									system.playFile(alarmVoice,AUDIO_AUDIO_QUEUE)
									system.playFile(alarmVoice,AUDIO_AUDIO_QUEUE)
									system.playFile(alarmVoice,AUDIO_AUDIO_QUEUE)
									vPlayed = 1
								elseif (alarmVoice ~= "...") then
									system.playFile(alarmVoice,AUDIO_AUDIO_QUEUE)
									vPlayed = 1
								else
									if (system.getTimeCounter() > nextPlayTime) then
										system.playNumber(mahCapa.value,0,"mAh")
										nextPlayTime = system.getTimeCounter() + 10000
									end
								end --rptAlm and voice check
							end -- vPlayed check
						end -- tStrRFID and tSetAlm check
					else -- more capacity than alarm threshold
						vPlayed = 0
					end -- capacity check against threshold
				end --alarm1Tr check
			else --tag not valid
				percVal = "-"
				vPlayed = 0
				tSetAlm = 0
				redAlert = false
			end -- tag valid check
		end -- capacity sensor check
	end --mahSens check
end

local function resetVoltageAlarm()
	vVoltPlayed = false
	thresholdTime = 0
	redAlert = false
	voltageChecked = false
end

local function checkVoltage()
	if (not tagValid or voltSens <=0 or voltAlarm == 0) then
		resetVoltageAlarm()
		return nil
	end
	voltValue = system.getSensorByID(voltId, voltParam)
	if (not voltValue or not voltValue.valid) then
		resetVoltageAlarm()
		return nil
	end
	local trueVoltThreshold = voltThreshold/100
	if (voltageChecked and voltValue.value <= trueVoltThreshold) then
		resetVoltageAlarm()
	end
	voltSenValue = tonumber(string.format("%.2f", voltValue.value))
	tagCells = tonumber(string.format("%.2f", tagCells))
	voltAlarmVal = tonumber(string.format("%.2f", (voltAlarm/100)))
	tagCellsDbl = tonumber(string.format("%.2f", (tagCells + 1) * 4.2))
	--print("voltSenValue = "..voltSenValue.." tagCells="..tagCells.." tagCellsDbl = "..tagCellsDbl)
	if(voltSenValue > tagCellsDbl) then
		voltLimit = voltAlarmVal * tagCells * 2
		tagCellsDsp = (tagCells * 2)
	else
		voltLimit = tagCells * voltAlarmVal
		tagCellsDsp = tagCells
	end --check for two packs
	voltLimit = tonumber(string.format("%.2f", voltLimit))
	voltSenValue = voltSenValue * 100
	voltLimit = voltLimit * 100
	--print("voltLimit = "..voltLimit.." voltSenValue = "..voltSenValue)
	if (not voltageChecked and thresholdTime == 0 and voltValue.value > trueVoltThreshold) then
		thresholdTime = system.getTimeCounter() + 2000 -- 2 second delay to let voltage telemetry settle
	elseif (not voltageChecked and thresholdTime > 0 and system.getTimeCounter() > thresholdTime) then
		if (voltSenValue < voltLimit) then
			redAlert = true
			noBattLog = 1
			voltageChecked = true
			if(not vVoltPlayed and alarmVoiceVolt ~= "...") then
				if (rptAlmVolt == 2) then
					system.playFile(alarmVoiceVolt,AUDIO_AUDIO_QUEUE)
					system.playFile(alarmVoiceVolt,AUDIO_AUDIO_QUEUE)
					system.playFile(alarmVoiceVolt,AUDIO_AUDIO_QUEUE)
					vVoltPlayed = true
					system.messageBox(trans8.lowFlightpack, 10)
				else
					system.playFile(alarmVoiceVolt,AUDIO_AUDIO_QUEUE)
					vVoltPlayed = true
					system.messageBox(trans8.lowFlightpack, 10)
				end --alarm repeat check
			end -- alarm played check
		else
			voltageChecked = true
			vVoltPlayed = false
			thresholdTime = 0
		end
	end
end

local function checkVoltageOld()
	if (voltSens > 1 and tVoltStrRFID >= tCurVoltRFID) then
		voltValue = system.getSensorByID(voltId, voltParam)
		if (voltValue and voltValue.valid and voltValue.value <= voltThreshold/100) then
			vVoltPlayed = false
			redAlert = false
			tSetAlmVolt = 0
			thresholdTime = 0
		end
		if (thresholdTime == 0 and voltValue and voltValue.valid and voltValue.value > voltThreshold/100) then
			thresholdTime = system.getTimeCounter() + 2000
		elseif (voltValue and voltValue.valid and thresholdTime > 0 and system.getTimeCounter()>thresholdTime) then
			if(tagValid) then
				if(tSetAlmVolt == 0) then
					tCurVoltRFID = rfidTime
					tVoltStrRFID = rfidTime + 10
					tSetAlmVolt = 1
				else
					tCurVoltRFID = system.getTime()
				end
				if(voltAlarm == 0) then
					vVoltPlayed = false
					tVoltStrRFID = 0
				else
					voltSenValue = string.format("%.2f", voltValue.value)
					tagCells = string.format("%.2f", tagCells)
					voltAlarmVal = string.format("%.2f", (voltAlarm/100))
					tagCellsDbl = string.format("%.2f", (tagCells + 1) * 4.2)
					if(voltSenValue > tagCellsDbl) then
						voltLimit = voltAlarmVal * tagCells * 2
						tagCellsDsp = (tagCells * 2)
					else
						voltLimit = tagCells * voltAlarmVal
						tagCellsDsp = tagCells
					end --check for two packs
					voltLimit = string.format("%.2f", voltLimit)
					voltSenValue = voltSenValue * 100
					voltLimit = voltLimit * 100
					if(voltSenValue <= voltLimit) then
						redAlert = true
						noBattLog = 1
						if(tVoltStrRFID >= tCurVoltRFID and tSetAlmVolt == 1) then
							if(not vVoltPlayed and alarmVoiceVolt ~= "...") then
								if (rptAlmVolt == 2) then
									system.playFile(alarmVoiceVolt,AUDIO_AUDIO_QUEUE)
									system.playFile(alarmVoiceVolt,AUDIO_AUDIO_QUEUE)
									system.playFile(alarmVoiceVolt,AUDIO_AUDIO_QUEUE)
									vVoltPlayed = true
									system.messageBox(trans8.lowFlightpack, 10)
								else
									system.playFile(alarmVoiceVolt,AUDIO_AUDIO_QUEUE)
									vVoltPlayed = true
									system.messageBox(trans8.lowFlightpack, 10)
								end --alarm repeat check
							end -- alarm played check
						end -- time and set alarm check
					else
						vVoltPlayed = false
					end -- volts vs threshold check
				end -- volt alarm check (else)
			else -- tag not valid
				vVoltPlayed = false
				tSetAlmVolt = 0
				redAlert = false
			end
		else -- voltValue not valid
			vVoltPlayed = false
			tSetAlmVolt = 0
			redAlert = false
		end
	end -- selected  v sensor valid
end
----------------------------------------------------------------------
local function loop()
	-- RFID reading and battery-definition
	if(rfidSens > 1) then
		rfidTime = system.getTime()
		getBattInfoFromTag()

		-- Capacity percentage calculation and voice alert config
		checkCapacity()

		-- Low batteryvoltage measurement and voice alert config
		checkVoltage()

		-- Do cleanup and write log after cycle is finished
		-- No log if empty battery at start
		if (not rfidRun and mahLog) then
			if(noBattLog == 1) then
				noBattLog = 0
			else
				writeLog()
			end
			mahLog = false
			rfidTrig = 0
			tVoltStrRFID = 0
			tCurVoltRFID = 0
			tagCellsDsp = 0
			tagCountOrg = 0
			battLog = "-"
		end
	else -- no RFIDSensor
		-- If no tag then reset values
		mahLog = false
		noBattLog = 0
		rfidTrig = 0
		rfidTime = 0
		tVoltStrRFID = 0
		tCurVoltRFID = 0
		tagCellsDsp = 0
		tagCountOrg = 0
		battLog = "-"
	end
	annGo = system.getInputsVal(annSw)
	if(annGo == 1 and percVal ~= "-" and annTime < rfidTime) then
		system.playNumber(percVal, 0, "%", trans8.annCap)
		annTime = rfidTime + 3
	end
end
----------------------------------------------------------------------
-- Application initialization
local function init()
	thresholdTime = 0
	nextPlayTime = 0
	vVoltPlayed = false
	voltageChecked = false
	modNameAudio = system.pLoad("modNameAudio", "...")
	if (modNameAudio ~= "...") then
		system.playFile(modNameAudio, AUDIO_IMMEDIATE)
	end
	rfidId = system.pLoad("rfidId",0)
	rfidParam = system.pLoad("rfidParam",0)
	rfidSens = system.pLoad("rfidSens",0)
	mahId = system.pLoad("mahId",0)
	mahParam = system.pLoad("mahParam",0)
	mahSens = system.pLoad("mahSens",0)
	voltId = system.pLoad("voltId",0)
	voltParam = system.pLoad("voltParam",0)
	voltSens = system.pLoad("voltSens",0)
	voltAlarm = system.pLoad("voltAlarm",0)
	voltThreshold = system.pLoad("voltThreshold",0)
	modName = system.pLoad("modName", "")
	capaAlarm = system.pLoad("capaAlarm",0)
	capaAlarmTr = system.pLoad("capaAlarmTr",1)
	alarmVoice = system.pLoad("alarmVoice","...")
	alarmVoiceVolt = system.pLoad("alarmVoiceVolt","...")
	rptAlm = system.pLoad("rptAlm", 1)
	rptAlmVolt = system.pLoad("rptAlmVolt",1)
	annSw = system.pLoad("annSw")
	table.insert(rptAlmlist,trans8.neg)
	table.insert(rptAlmlist,trans8.pos)
	table.insert(rptAlmVoltlist,trans8.neg)
	table.insert(rptAlmVoltlist,trans8.pos)
	battIds = system.pLoad("battIds",{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0})
	battNames = system.pLoad("battNames",{"","","","","","","","","","","","","","",""})
	battId1 = battIds[1]
	battId2 = battIds[2]
	battId3 = battIds[3]
	battId4 = battIds[4]
	battId5 = battIds[5]
	battId6 = battIds[6]
	battId7 = battIds[7]
	battId8 = battIds[8]
	battId9 = battIds[9]
	battId10 = battIds[10]
	battId11 = battIds[11]
	battId12 = battIds[12]
	battId13 = battIds[13]
	battId14 = battIds[14]
	battId15 = battIds[15]
	battName1 = battNames[1]
	battName2 = battNames[2]
	battName3 = battNames[3]
	battName4 = battNames[4]
	battName5 = battNames[5]
	battName6 = battNames[6]
	battName7 = battNames[7]
	battName8 = battNames[8]
	battName9 = battNames[9]
	battName10 = battNames[10]
	battName11 = battNames[11]
	battName12 = battNames[12]
	battName13 = battNames[13]
	battName14 = battNames[14]
	battName15 = battNames[15]
	system.registerForm(1,MENU_APPS,trans8.appName,initForm,keyPressed)
	system.registerTelemetry(1,"RFID-Battery",2,printBattery)
end
----------------------------------------------------------------------
rfidVersion = "1.9"
setLanguage()
return {init=init, loop=loop, author="RC-Thoughts", version=rfidVersion, name=trans8.appName}
