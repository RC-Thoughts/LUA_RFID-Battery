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
	Released under MIT-license by Tero @ RC-Thoughts.com 2016
	---------------------------------------------------------
--]]
----------------------------------------------------------------------
-- Locals for the application
local rfidId, rfidParam, rfidSens, mahId, mahParam, mahSens, rfidTime
local capaAlarm, capaAlarmTr, alarmVoice, vPlayed, tagId, tagCapa
local tagValid, tSetAlm, percVal = 0,0,"-"
local sensorLa1list = {"..."}
local sensorId1list = {"..."}
local sensorPa1list = {"..."}
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
	end
end
----------------------------------------------------------------------
-- Draw the telemetry windows
local function printBattery()
	if (tagID == 0) then
		lcd.drawText((150 - lcd.getTextWidth(FONT_BOLD,trans8.emptyTag))/2,24,trans8.emptyTag,FONT_BOLD)
		elseif (mahId == 0) then
		lcd.drawText((150 - lcd.getTextWidth(FONT_BOLD,trans8.noCurr))/2,24,trans8.noCurr,FONT_BOLD)
		elseif (percVal ~= "-") then
		lcd.drawRectangle(6,9,26,55)                                    
		lcd.drawFilledRectangle(13,6,12,4)
		chgY = (65-(percVal*0.54))
		chgH = ((percVal*0.54)-1)
		lcd.drawFilledRectangle(7,chgY,24,chgH)
		lcd.drawText(148 - lcd.getTextWidth(FONT_MAXI,string.format("%.1f%%",percVal)),15,string.format("%.1f%%",percVal),FONT_MAXI)
		else
		lcd.drawText((150 - lcd.getTextWidth(FONT_BOLD,trans8.noPack))/2,24,trans8.noPack,FONT_BOLD)
	end
end
----------------------------------------------------------------------
-- Store settings when changed by user
--
local function capaAlarmChanged(value)
	capaAlarm=value
	system.pSave("capaAlarm",value)
	alarm1Tr = string.format("%.1f", capaAlarm)
	system.pSave("capaAlarmTr", capaAlarmTr)
	system.registerTelemetry(1,trans8.telLabel,2,printBattery)
end

local function alarmVoiceChanged(value)
	alarmVoice=value
	system.pSave("alarmVoice",value)
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
	mahId = string.format("%s", sensorId1list[mahSens])
	mahParam = string.format("%s", sensorPa1list[mahSens])
	if (mahId == "...") then
		mahId = 0
		mahParam = 0
	end
	system.pSave("mahId", mahId)
	system.pSave("mahParam", mahParam)
end
----------------------------------------------------------------------
-- Draw the main form (Application inteface)
local function initForm(subform)
	form.setButton(1,":tools")
	
	form.addRow(1)
	form.addLabel({label="---   RC-Thoughts Jeti Tools    ---",font=FONT_BIG})
	
	form.addRow(1)
	form.addLabel({label=trans8.labelCommon,font=FONT_BOLD})
	
	form.addRow(2)
	form.addLabel({label=trans8.sensorID})
	form.addSelectbox(sensorLa1list,rfidSens,true,sensorIDChanged)
	
	form.addRow(2)
	form.addLabel({label=trans8.sensorMah})
	form.addSelectbox(sensorLa1list,mahSens,true,sensorMahChanged)
	
	form.addRow(1)
	form.addLabel({label=trans8.labelAlarm,font=FONT_BOLD})
	
	form.addRow(2)
	form.addLabel({label=trans8.AlmVal})
	form.addIntbox(capaAlarm,0,100,0,0,1,capaAlarmChanged)
	
	form.addRow(2)
	form.addLabel({label=trans8.selAudio})
	form.addAudioFilebox(alarmVoice,alarmVoiceChanged)
	
	form.addRow(1)
	form.addLabel({label="Powered by RC-Thoughts.com - v."..rfidVersion.." ",font=FONT_MINI, alignRight=true})
	
	form.setFocusedRow (1)
end
----------------------------------------------------------------------
local function loop()
	-- RFID reading and battery-definition
	if(rfidSens > 1) then
		rfidTime = system.getTime()
		tagID = system.getSensorByID(rfidId, 1)
		tagCapa = system.getSensorByID(rfidId, 2)
		if(tagID and tagID.valid) then
			tagValid = 1
			tagID = tagID.value
			tagCapa = tagCapa.value
			else
			percVal = "-"
			tagValid = 0
		end
		-- Capacity percentage calculation and voice alert config
		if (mahSens > 1) then
			mahCapa = system.getSensorByID(mahId, mahParam)
			if (mahCapa and mahCapa.valid) then
				mahCapa = mahCapa.value
				mahCapaLog = mahCapa
				if(tagValid == 1) then
					if(tSetAlm == 0) then
						tCurRFID = rfidTime
						tStrRFID = rfidTime + 5
						tSetAlm = 1
						else
						tCurRFID = system.getTime()
					end
					resRFID = (((tagCapa - mahCapa) * 100) / tagCapa) 
					if (resRFID < 0) then
						resRFID = 0
						else
						if (resRFID > 100) then
							resRFID = 100
						end
					end
					percVal = string.format("%.1f", resRFID)
					if(alarm1Tr == 0) then
						vPlayed = 0
						tStrRFID = 0
						else
						if(resRFID <= capaAlarm) then
							if(tStrRFID <= tCurRFID and tSetAlm == 1) then
								if(vPlayed == 0 or vPlayed == nil and alarmVoice ~= "...") then
									system.playFile(alarmVoice,AUDIO_AUDIO_QUEUE)
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
end
----------------------------------------------------------------------
-- Application initialization
local function init()
	rfidId = system.pLoad("rfidId",0)
	rfidParam = system.pLoad("rfidParam",0)
	rfidSens = system.pLoad("rfidSens",0)
	mahId = system.pLoad("mahId",0)
	mahParam = system.pLoad("mahParam",0)
	mahSens = system.pLoad("mahSens",0)
	capaAlarm = system.pLoad("capaAlarm",0)
	capaAlarmTr = system.pLoad("capaAlarmTr",1)
	alarmVoice = system.pLoad("alarmVoice","...")
	system.registerForm(1,MENU_APPS,trans8.appName,initForm,keyPressed)
	system.registerTelemetry(1,"RFID-Battery",2,printBattery)
end
----------------------------------------------------------------------
rfidVersion = "1.7"
setLanguage()
return {init=init, loop=loop, author="RC-Thoughts", version=rfidVersion, name=trans8.appName}	