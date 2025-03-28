-- 28.3.25
-- счетчик затаргетивших нас
local ADDON_NAME, core = ...

local cfg = mrcatsoul_WantedLevel or {}

local ONLY_PLAYERS_AT_COUNT = true  -- учитывать только игроков в счетчике со звездами
local NEUTRAL_AT_COUNT = false      -- учитывать нейтральных (желтые мобы) в счетчике

local ONLY_PLAYERS_AT_NAMES = false -- только игроки в списке имен
local ONLY_ENEMY_AT_NAMES = false   -- только враги в списке имен
local NEUTRAL_AT_NAMES = true       -- нейтральные в списке имен

local SIZE_DEF_COUNT = 25
local SIZE_DEF_NAMES = 11
local FONT_DEF_COUNT = "Interface\\addons\\"..ADDON_NAME.."\\trebucbd.ttf"
local FONT_DEF_NAMES = "Interface\\addons\\"..ADDON_NAME.."\\PTSansNarrow.ttf"
local OPACITY_DEF = 0.9
local DEF_RED, DEF_GREEN, DEF_BLUE = 1, 0.1, 0.1

--local skull = COMBATLOG_ICON_RAIDTARGET8 or "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8.blp:0|t"
local TEXTURE_DANG = "|TInterface\\addons\\"..ADDON_NAME.."\\dang.tga:0|t" 
local TEXTURE_STAR = "|TInterface\\addons\\"..ADDON_NAME.."\\star2.tga:0|t" 

local C_NamePlate = C_NamePlate
local IsShiftKeyDown = IsShiftKeyDown
local wipe = table.wipe

local UnitIsPlayer = UnitIsPlayer
local UnitIsUnit = UnitIsUnit
local UnitReaction = UnitReaction
local UnitGUID = UnitGUID
local UnitExists = UnitExists
local GetNumRaidMembers = GetNumRaidMembers
local GetNumPartyMembers = GetNumPartyMembers
local UnitName = UnitName
local UnitClass = UnitClass

local function tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

local unit_IDs = {
  "target", "focus", "targettarget", "focustarget", "pettarget", "pettargettarget", "targettargettarget", "focustargettarget", 
  "mouseover", "mouseovertarget", -- Если наводишь курсор на врага или его цель
  "boss1", "boss2", "boss3", "boss4", "boss5", -- Боссы в рейде/подземелье
  "boss1target", "boss2target", "boss3target", "boss4target", "boss5target",
  "arena1", "arena2", "arena3", "arena4", "arena5", -- Вражеские игроки на арене
  "arena1target", "arena2target", "arena3target", "arena4target", "arena5target",
  "player", "pet", -- Иногда питомец может иметь цель игрока
}

local classColors = {
  ["DEATHKNIGHT"] = "C41F3B",
  ["DRUID"] = "FF7D0A",
  ["HUNTER"] = "A9D271",
  ["MAGE"] = "40C7EB",
  ["PALADIN"] = "F58CBA",
  ["PRIEST"] = "FFFFFF",
  ["ROGUE"] = "FFF569",
  ["SHAMAN"] = "0070DE",
  ["WARLOCK"] = "8787ED",
  ["WARRIOR"] = "C79C6E",
}

local UIFrameFadeIn = UIFrameFadeIn
local UIFrameFadeOut = UIFrameFadeOut
local UIFrameFlashStop = UIFrameFlashStop

local function testflash(frame, speed, minalpha)
  if not UIFrameIsFading(frame) then
    if frame:GetAlpha() <= (minalpha + 0.01) then
      UIFrameFadeIn(frame, speed, minalpha, OPACITY_DEF or 1)
    elseif frame:GetAlpha() >= ((OPACITY_DEF or 1) - 0.01) then
      UIFrameFadeOut(frame, speed, OPACITY_DEF or 1, minalpha)
    end
  end
end

local nameplateToUnitId = {}

-- local function IsEnemy(unit)
  -- local reaction = UnitReaction(unit, "player")
  -- return (not ONLY_PLAYERS_AT_COUNT or UnitIsPlayer(unit)) and (NEUTRAL_AT_COUNT and reaction <= 4 or reaction <= 3)
-- end

--/dump UnitName("nameplate1target")
--/dump #C_NamePlate.GetNamePlates()
local function GetTargetedMe()
  local list = {}

  -- Проверка Nameplates
  if C_NamePlate then
    for nameplate, unit in pairs(nameplateToUnitId) do
      if UnitExists(unit) and UnitIsUnit("player", unit.."target") then
        list[UnitGUID(unit)] = {
          name = UnitName(unit) or "UNKNOWN",
          isPlayer = UnitIsPlayer(unit),
          reaction = UnitReaction(unit, "player"),
          class = select(2, UnitClass(unit))
        }
      end
    end
  end

  -- Проверка предопределённых юнитов
  for _, unit in ipairs(unit_IDs) do
    local guid = UnitGUID(unit)
    if guid and not list[guid] and UnitIsUnit("player", unit.."target") then
      list[guid] = {
        name = UnitName(unit) or "UNKNOWN",
        isPlayer = UnitIsPlayer(unit),
        reaction = UnitReaction(unit, "player"),
        class = select(2, UnitClass(unit))
      }
    end
  end

  -- Вложенная функция для проверки рейда/группы
  local function CheckUnits(prefix, count)
    local suffixes = { "", "target", "targettarget", "pet", "pettarget", "pettargettarget" }
    
    for i = 1, count do
      for _, suffix in ipairs(suffixes) do
        local unit = prefix..i..suffix
        local guid = UnitGUID(unit)

        if guid and not list[guid] and UnitIsUnit("player", unit.."target") then
          list[guid] = {
            name = UnitName(unit) or "UNKNOWN",
            isPlayer = UnitIsPlayer(unit),
            reaction = UnitReaction(unit, "player"),
            class = select(2, UnitClass(unit))
          }
        end
      end
    end
  end

  -- Проверка рейда или группы
  local raidMembers = GetNumRaidMembers()
  if raidMembers > 0 then
    CheckUnits("raid", raidMembers)
  else
    local partyMembers = GetNumPartyMembers()
    if partyMembers > 0 then
      CheckUnits("party", partyMembers)
    end
  end

  return list
end

local function StartMoving(self)
  if not IsShiftKeyDown() then return end
  self:StartMoving()
end

local function StopMoving(self)
  self:StopMovingOrSizing()
end

local function StartSizing(self, delta, sizeOnlyFont)
  if not IsShiftKeyDown() then return end
  sizeOnlyFont = true
  local size = sizeOnlyFont and select(2,self.text:GetFont()) or self:GetHeight()
  if delta == 1 then
    size = sizeOnlyFont and select(2,self.text:GetFont()) +0.5 or self:GetHeight() +2
  else
    size = sizeOnlyFont and select(2,self.text:GetFont()) -0.5 or self:GetHeight() -2
  end
  size = math.min(30, math.max(size, 8))
  cfg[self:GetName()].size = size
  --self:SetSize(size*3, size)
  print(size)
  self.text:SetFont(select(1,self.text:GetFont()), size)
  self:SetSize(self.text:GetStringWidth(),self.text:GetStringHeight())
end

do
  local f = CreateFrame("frame", ADDON_NAME.."_HatersCountFrame", UIParent) 
  f:SetMovable(true)
  f:EnableMouse(false)
  f:EnableMouseWheel(false)
  f:SetPoint("CENTER", 0, -120)
  f:SetFrameLevel(100)
  f:SetSize(SIZE_DEF_COUNT*3, SIZE_DEF_COUNT)
  f:SetFrameStrata("HIGH")
  f:SetClampedToScreen(true)
  f:SetAlpha(OPACITY_DEF)
  
  local t = f:CreateFontString(ADDON_NAME.."_HatersCountFrameText", "ARTWORK", "GameFontNormal")
  t:SetPoint("center")
  t:SetTextColor(DEF_RED, DEF_GREEN, DEF_BLUE)
  t:SetFont(FONT_DEF_COUNT, SIZE_DEF_COUNT)
  t:SetShadowOffset(1, -1)
  
  f.text = t
  core.countText = t
  core.countFrame = f

  f:RegisterEvent("MODIFIER_STATE_CHANGED")
  f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
  f:RegisterEvent("ADDON_LOADED")
  f:RegisterEvent("UNIT_TARGET")
  
  f:SetScript("OnEvent", function(self, event, ...) self[event](self, ...) end)
  f:SetScript("OnMouseDown", StartMoving)
  f:SetScript("OnMouseUp", StopMoving)
  f:SetScript("OnMouseWheel", StartSizing)

  function f:ADDON_LOADED(...)
    if ... == ADDON_NAME then
      core:initConfig()
      if cfg[f:GetName()]==nil then cfg[f:GetName()]={} end
      local size = cfg[f:GetName()].size or SIZE_DEF_COUNT
      f:SetSize(size*3, size)
      f.text:SetFont(select(1,f.text:GetFont()), size)
    end
  end
  
  function f:MODIFIER_STATE_CHANGED(...)
    if arg2==1 then
      f:EnableMouse(true)
      f:EnableMouseWheel(true)
    else
      StopMoving(f)
      f:EnableMouse(false)
      f:EnableMouseWheel(false)
    end
  end

  function f:NAME_PLATE_UNIT_ADDED(nameplateToken)
    if nameplateToken then
      local nameplate = C_NamePlate.GetNamePlateForUnit(nameplateToken)
      if nameplate then
        nameplateToUnitId[nameplate] = nameplateToken
      end
    end
  end
  
  function f:UNIT_TARGET()
    f:UpdateFrames()
  end
  
  function f:UpdateFrames()
    local list = GetTargetedMe()
    local hatersCount = 0
    local textNames = "Haters or fans:"
    
    for guid, data in pairs(list) do
      if (not cfg.settings.only_players_at_count or data.isPlayer) and (cfg.settings.neutral_at_count and data.reaction <= 4 or data.reaction <= 3) then
        hatersCount = hatersCount + 1
      end
      
      if data.isPlayer then
        if data.reaction <= 3 then
          textNames = textNames.."\n|cffff0000"..data.name.."|r"
        elseif not ONLY_ENEMY_AT_NAMES then
          textNames = textNames.."\n|cff"..classColors[data.class]..data.name.."|r"
        end
      elseif not cfg.settings.only_players_at_names then
        if data.reaction <= 3 then
          textNames = textNames.."\n|cffff0000"..data.name.."|r |cff989898(NPC)|r"
        elseif data.reaction == 4 and cfg.settings.neutral_at_names then
          textNames = textNames.."\n|cffffff00"..data.name.."|r |cff989898(NPC)|r"
        elseif data.reaction >= 5 and not cfg.settings.only_enemy_at_names then
          textNames = textNames.."\n|cff00ff00"..data.name.."|r |cff989898(NPC)|r"
        end
      end
    end
    
    if textNames:find("\n") then
      core.namesText:SetText(textNames)
      core.namesText:GetParent():SetSize(core.namesText:GetStringWidth(),core.namesText:GetStringHeight())
      --print(core.namesText:GetParent():GetName(),core.namesText:GetParent():GetSize())
    else
      core.namesText:SetText("|cff77ff77No haters or fans.")
      core.namesText:GetParent():SetSize(core.namesText:GetStringWidth(),core.namesText:GetStringHeight())
      --print(core.namesText:GetParent():GetName(),core.namesText:GetParent():GetSize())
    end
    
    if hatersCount > 0 then  
      local textCount = ""
      
      if cfg.settings.wanted_level_stars then
        if cfg.settings.count_number then textCount = hatersCount.." " end
        for i=1,hatersCount do
          textCount = textCount..TEXTURE_STAR
          if i==6 and cfg.settings.six_stars_max then
            break
          end
        end
      elseif cfg.settings.count_number then
        textCount = TEXTURE_DANG..""..hatersCount
      end
      
      --f.text:SetFont(FONT_DEF, cfg[f:GetName()].size)
      f.text:SetText(textCount)
      f:SetSize(f.text:GetStringWidth(),f.text:GetStringHeight())
      
      if hatersCount > 2 then
        f.text:SetTextColor(DEF_RED, DEF_GREEN, DEF_BLUE)
        testflash(f, 0.01, 0.1)
      elseif hatersCount > 1 then
        f.text:SetTextColor(DEF_RED, DEF_GREEN, DEF_BLUE)
        testflash(f, 0.01, 0.1)
      elseif hatersCount == 1 then
        f.text:SetTextColor(1, 0.6, 0.1)
        testflash(f, 0.2, 0.7)
      end
    else
      --f.text:SetFont(FONT_DEF, size/2)
      f:SetAlpha(OPACITY_DEF)
      f.text:SetTextColor(1, 1, 1)
      f.text:SetText("no haters")
      f:SetSize(f.text:GetStringWidth(),f.text:GetStringHeight())
    end
  end
  
  f:SetScript("onupdate", function(s,e)
    s.t = s.t and s.t + e or 0
    if s.t < 0.3 then return end
    s.t = 0
    s:UpdateFrames()
  end)
  
  f:SetScript("onhide", function(s)
    s:Show()
  end)
end

do
  local f = CreateFrame("frame", ADDON_NAME.."_TargetedMeNamesFrame", UIParent)
  f:SetFrameStrata("MEDIUM")
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
  f:SetMovable(true)
  f:EnableMouse(false)
  f:EnableMouseWheel(false)
  f:SetFrameLevel(100)
  f:SetSize(1, 1)
  f:SetClampedToScreen(true)
  
  local t = f:CreateFontString(ADDON_NAME.."_TargetedMeNamesFrameText", "OVERLAY")
  
  --t:SetPoint("center", UIParent, "center", 0, 100)
  --t:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 4, -65)
  t:SetAllPoints()
  t:SetFont(FONT_DEF_NAMES, SIZE_DEF_NAMES)
  t:SetShadowOffset(1, -1)
  t:SetJustifyH("LEFT")
  t:SetJustifyV("TOP")
  t:SetTextColor(1, 1, 0.7, 1)
  --t:SetParent(f)
  
  f.text = t
  core.namesText = t
  core.namesFrame = f
  
  f:RegisterEvent("MODIFIER_STATE_CHANGED")
  f:RegisterEvent("ADDON_LOADED")

  f:SetScript("OnEvent", function(self, event, ...) self[event](self, ...) end)
  f:SetScript("OnMouseDown", StartMoving)
  f:SetScript("OnMouseUp", StopMoving)
  f:SetScript("OnMouseWheel", StartSizing)
  -- f:SetScript("onshow", function()
    -- print("FSADFSDFSDFDSF")
    -- f.SetSize(f.text:GetStringWidth(),f.text:GetStringHeight())
  -- end)
  -- f:Show()

  function f:ADDON_LOADED(...)
    if ... == ADDON_NAME then
      core:initConfig()
      if cfg[f:GetName()]==nil then cfg[f:GetName()]={} end
      local size = cfg[f:GetName()].size or SIZE_DEF_NAMES
      f:SetSize(size*3, size)
      f.text:SetFont(select(1,f.text:GetFont()), size)
    end
  end
  
  function f:MODIFIER_STATE_CHANGED(...)
    if arg2==1 then
      f:EnableMouse(true)
      f:EnableMouseWheel(true)
    else
      StopMoving(f)
      f:EnableMouse(false)
      f:EnableMouseWheel(false)
    end
  end
end





-- опции
local options =
{
  {"only_players_at_count","Учитывать только игроков в счётчике со звёздами",nil,true},
  {"targetters_names","Отображать список имён тех кто нацеленен на нас",nil,true},
  {"only_players_at_names","Отображать только игроков в списке нацеленных на нас",nil,true},
  {"only_enemy_at_names","Отображать только врагов в списке нацеленных на нас",nil,false},
  {"count_number","Отображать числовое значение нацелов на нас",nil,true},
  {"wanted_level_stars","Отображать звёзды, каждая из которых равна единице вражеского нацела на нас",nil,true},
  {"six_stars_max","Отображать максимум 6 звёзд",nil,true},
  {"neutral_at_count","Учитывать нейтральных (желтых мобов) в счётчике со звёздами",nil,false},
  {"neutral_at_names","Отображать нейтральных мобов в списке нацеленных на нас",nil,false},
}

function core:UpdateVisual()
  --print("UpdateVisual")
  core.countFrame:Show()
  core.countText:Show()
  core.namesFrame:Show()
  core.namesText:Show()
  
  if not cfg.settings.targetters_names then
    core.namesFrame:Hide()
    core.namesText:Hide()
  end
  
  if not cfg.settings.count_number and not cfg.settings.wanted_level_stars then
    core.countFrame:Hide()
    core.countText:Hide()
  end
end

function core:initConfig()
  if core.init then return true end
  core.init = true
  
  cfg = mrcatsoul_WantedLevel or {}
  
  if cfg.settings == nil then cfg.settings = {} end

  -- [1] - settingName, [2] - checkboxText, [3] - tooltipText, [4] - значение по умолчанию, [5] - minValue, [6] - maxValue  
  for _,v in ipairs(options) do
    if cfg.settings[v[1]]==nil then
      cfg.settings[v[1]]=v[4]
      print(""..v[1]..": "..tostring(cfg.settings[v[1]]).." (задан параметр по умолчанию)")
    end
  end

  if mrcatsoul_WantedLevel == nil then 
    mrcatsoul_WantedLevel = cfg
    cfg = mrcatsoul_WantedLevel
    local t = GetTime()+4
    CreateFrame("frame"):SetScript("OnUpdate", function(self)
      if t<GetTime() then
        PlaySound("RaidWarning")
        RaidNotice_AddMessage(RaidWarningFrame, "|cff33ccff"..ADDON_NAME..": Фреймы перетаскиваются ПКМ мыши с зажатым SHIFT.\nИзменить размер: зажатый SHIFT + прокрутка мышью на фрейме. Для адекватной работы ставим AwesomeWotlk патч: |cffddff33https://github.com/FrostAtom/awesome_wotlk|r", ChatTypeInfo["RAID_WARNING"])
        RaidNotice_AddMessage(RaidWarningFrame, GetAddOnMetadata(ADDON_NAME, "Notes"), ChatTypeInfo["RAID_WARNING"])
        print("|cff33ccff["..ADDON_NAME.."]:|r "..GetAddOnMetadata(ADDON_NAME, "Notes").."")
        print("|cff33ccff["..ADDON_NAME.."]: Фреймы перетаскиваются ПКМ мыши с зажатым SHIFT. Изменить размер: зажатый SHIFT + прокрутка мышью на фрейме. Для адекватной работы ставим AwesomeWotlk патч: |cffddff33https://github.com/FrostAtom/awesome_wotlk|r")
        self:SetScript("OnUpdate", nil)
        self=nil
      end
    end)
  end

  core:UpdateVisual()
  core:CreateOptions()
end

function core:CreateOptions()
  if core.options then return end
  core.options=true
  core.optNum=0
  
  -- вроде отныне не говнокод для интерфейса настроек (27.1.25)
  -- [1] - settingName, [2] - checkboxText, [3] - tooltipText, [4] - значение по умолчанию, [5] - minValue, [6] - maxValue 
  for i,v in ipairs(options) do
    if v[4]~=nil then
      --print(v[1],type(v[4]),v[4])
      if type(v[4])=="boolean" then
        --print(v[1],v[4])
        core:createCheckbox(v[1], v[2], v[3], core.optNum)
        if options[i+1] and type(options[i+1][4])=="number" then
          core.optNum=core.optNum+3
        else
          core.optNum=core.optNum+2
        end
      elseif type(v[4])=="number" then
        --print(v[1])
        core:createEditBox(v[1], v[2], v[3], v[5], v[6], core.optNum)
        if options[i+1] and type(options[i+1][4])=="boolean" then
          core.optNum=core.optNum+1.5
        else
          core.optNum=core.optNum+2
        end
      end
    end
  end
end

--------------------------------------------------------------------------------
-- фрейм прокрутки для фрейма настроек. нужен чтобы прокручивать настройки вверх-вниз
--------------------------------------------------------------------------------
local width, height = 800, 500
local settingsScrollFrame = CreateFrame("ScrollFrame", ADDON_NAME.."SettingsScrollFrame", InterfaceOptionsFramePanelContainer, "UIPanelScrollFrameTemplate")
settingsScrollFrame.name = GetAddOnMetadata(ADDON_NAME, "Title") .. " " .. TEXTURE_STAR   -- Название во вкладке интерфейса
settingsScrollFrame:SetSize(width, height)
settingsScrollFrame:Hide()
settingsScrollFrame:SetVerticalScroll(10)
settingsScrollFrame:SetHorizontalScroll(10)
_G[ADDON_NAME.."SettingsScrollFrameScrollBar"]:SetPoint("topleft",settingsScrollFrame,"topright",-25,-25)
_G[ADDON_NAME.."SettingsScrollFrameScrollBar"]:SetFrameLevel(1000)
_G[ADDON_NAME.."SettingsScrollFrameScrollBarScrollDownButton"]:SetPoint("top",_G[ADDON_NAME.."SettingsScrollFrameScrollBar"],"bottom",0,7)

--------------------------------------------------------------------------------
-- фрейм настроек который должен быть помещен в фрейм прокрутки
--------------------------------------------------------------------------------
local settingsFrame = CreateFrame("button", nil, InterfaceOptionsFramePanelContainer)
settingsFrame:Hide()
settingsFrame:SetSize(width, height) -- Измените размеры фрейма настроек ++ 4.3.24
settingsFrame:SetAllPoints(InterfaceOptionsFramePanelContainer)

settingsFrame:RegisterEvent("ADDON_LOADED")
settingsFrame:SetScript("OnEvent", function(self, event, ...) self[event](self, ...) end)
function settingsFrame:ADDON_LOADED(addon)
  if addon==ADDON_NAME then
    core:initConfig()
  end
end

--------------------------------------------------------------------------------
-- связываем скролл-фрейм с фреймом настроек в котором все опции
--------------------------------------------------------------------------------
settingsScrollFrame:SetScrollChild(settingsFrame)

--------------------------------------------------
-- регистрируем фрейм настроек в близ настройках интерфейса (интерфейс->модификации) этой самой функцией 
--------------------------------------------------
InterfaceOptions_AddCategory(settingsScrollFrame)

--------------------------------------------------------------------------------
-- при показе/скрытии скролл-фрейма - показывается/скрывается фрейм настроек
--------------------------------------------------------------------------------
settingsScrollFrame:SetScript("OnShow", function()
  settingsFrame:Show()
end)

settingsScrollFrame:SetScript("OnHide", function()
  settingsFrame:Hide()
end)

--------------------------------------------------------------------------------
-- заголовок фрейма опций
--------------------------------------------------------------------------------
do
  local text = settingsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  text:SetPoint("TOPLEFT", 16, -16)
  text:SetFont(GameFontNormal:GetFont(), 18, 'OUTLINE')
  text:SetText(GetAddOnMetadata(ADDON_NAME, "Title").." "..TEXTURE_STAR.." v"..GetAddOnMetadata(ADDON_NAME, "Version").."")
  text:SetJustifyH("LEFT")
  text:SetJustifyV("BOTTOM")
  settingsFrame.TitleText = text
end

--------------------------------------------------------------------------------
-- тултип (подсказка) для заголовка фрейма опций
--------------------------------------------------------------------------------
do
  local tip = CreateFrame("button", nil, settingsFrame)
  tip:SetPoint("center",settingsFrame.TitleText,"center")
  tip:SetSize(settingsFrame.TitleText:GetStringWidth()+1,settingsFrame.TitleText:GetStringHeight()+1) -- Измените размеры фрейма настроек ++ 4.3.24
  
  --------------------------------------------------------------------------------
  -- действия при наведении мышкой на тултип
  --------------------------------------------------------------------------------
  tip:SetScript("OnEnter", function(self) -- при наведении мышкой на фрейм чекбокса (маусовер) ...
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
    GameTooltip:SetText(""..GetAddOnMetadata(ADDON_NAME, "Title").." "..TEXTURE_STAR.." v"..GetAddOnMetadata(ADDON_NAME, "Version").."\n\n"..GetAddOnMetadata(ADDON_NAME, "Notes").."", nil, nil, nil, nil, true)
    GameTooltip:Show() -- ... появится подсказка
  end)

  tip:SetScript("OnLeave", function(self) -- при снятии фокуса мышки с фрейма чекбокса ... 
    GameTooltip:Hide() -- ... подсказка скроется
  end)
end

---------------------------------------------------------------
-- функция создания чекбоксов. так как их будет много - нужно будет спамить её по кд
---------------------------------------------------------------
function core:createCheckbox(settingName,checkboxText,tooltipText,optNum) -- offsetY отступ от settingsFrame.TitleText
  local checkBox = CreateFrame("CheckButton",ADDON_NAME.."_"..settingName,settingsFrame,"UICheckButtonTemplate") -- фрейм чекбокса
  checkBox:SetPoint("TOPLEFT", settingsFrame.TitleText, "BOTTOMLEFT", 0, -10-(optNum*10))
  checkBox:SetSize(28,28)
  
  local textFrame = CreateFrame("Button",nil,checkBox) 
  textFrame:SetPoint("LEFT", checkBox, "RIGHT", 0, 0)

  local textRegion = textFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  textRegion:SetText(checkboxText)
  
  textRegion:SetJustifyH("LEFT")
  textRegion:SetJustifyV("BOTTOM")
  
  textRegion:SetAllPoints(textFrame)
  
  textFrame:SetSize(textRegion:GetStringWidth(),textRegion:GetStringHeight()) 
  textFrame:SetPoint("LEFT", checkBox, "RIGHT", 0, 0)
  
  checkBox:SetScript("OnClick", function(self) -- по клику по фрейму проставляется настройка, чекбокс
    cfg.settings[settingName] = checkBox:GetChecked() and true or false
    core:UpdateVisual()
  end)
  
  textFrame:SetScript("OnClick", function(self) -- по клику по фрейму проставляется настройка, текст
    if checkBox:GetChecked() then
      checkBox:SetChecked(false)
    else
      checkBox:SetChecked(true)
    end
    cfg.settings[settingName] = checkBox:GetChecked() and true or false
    core:UpdateVisual()
  end)
  
  textFrame:SetScript("OnShow", function(self)
    self:SetSize(textRegion:GetStringWidth()+1,textRegion:GetStringHeight())
  end)
  
  checkBox:SetScript("OnShow", function(self) 
    self:SetChecked(cfg.settings[settingName])
  end)
  
  checkBox:SetScript("OnEnter", function(self) -- при наведении мышкой на фрейм чекбокса (маусовер) ...
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(tooltipText or checkboxText, 1, 1, 1, nil, true)
    GameTooltip:Show() -- ... появится подсказка
  end)
  
  checkBox:SetScript("OnLeave", function(self) -- при снятии фокуса мышки с фрейма чекбокса ...
    GameTooltip:Hide() -- ... подсказка скроется
  end)
  
  textFrame:SetScript("OnEnter", function(self) -- при наведении мышкой на фрейм текста (маусовер) ...
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
    GameTooltip:SetText(tooltipText or checkboxText, 1, 1, 1, nil, true)
    GameTooltip:Show() -- ... появится подсказка
  end)
  
  textFrame:SetScript("OnLeave", function(self) -- при снятии фокуса мышки с фрейма текста ...
    GameTooltip:Hide() -- ... подсказка скроется
  end)
end
