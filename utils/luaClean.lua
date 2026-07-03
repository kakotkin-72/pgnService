----------------------------------------------------------------
-- pgnService 2026.07
-- Чистка тегов в PGN-файле
-- (С) 2026 Владимир Какоткин
----------------------------------------------------------------

-- Упрощенная под JScript конфигурация
local m_cfg = "pgnService.cfg"

local CFG_SET = 1
local CFG_ECO = 2
local CFG_ELO = 3
local CFG_FID = 4
local CFG_FIX = 5
local CFG_LEN = 6
local CFG_LIM = 7
local CFG_CNT = 7

-- 1 = Разрешение на тег SetUp
-- 2 = Разрешение на тег ECO
-- 3 = Разрешение на теги WhiteElo и BlackElo
-- 4 = Разрешение на теги WhiteFideId и BlackFideId
-- 5 = Сжимать неопределенную дату
-- 6 = Максимальная длина строки для форматирования ходов
-- 7 = Количество первых партий для перемешивания и сортировки

local
function check()
  if (type(m_cfg) ~= "table") or (#m_cfg ~= CFG_CNT)
    then return false end

  for i = 1, CFG_CNT do
    if type(m_cfg[i]) ~= "number"
      then return false end
  end

  return true
end

if
  (not pcall(function() m_cfg = dofile(m_cfg) end)) or
  (not check())
then
  m_cfg = { 0, 0, 0, 0, 1, 60, 3000 } -- по умолчанию
end

-- Чтение всей конфигурации
local m_set = (m_cfg[CFG_SET] == 1) -- преобразование в boolean
local m_eco = (m_cfg[CFG_ECO] == 1)
local m_elo = (m_cfg[CFG_ELO] == 1)
local m_fid = (m_cfg[CFG_FID] == 1)
local m_fix = (m_cfg[CFG_FIX] == 1)
local m_len =  m_cfg[CFG_LEN]
local m_lim =  m_cfg[CFG_LIM]

-- Границы
m_len = math.min(math.max(m_len, 20), 180)
m_lim = math.min(math.max(m_lim, 0),  10000)

-- Основной код
local m_tags = {
  EVENT  = "Event",
  SITE   = "Site",
  DATE   = "Date",
  ROUND  = "Round",
  WHITE  = "White",
  BLACK  = "Black",
  RESULT = "Result",
  FEN    = "FEN",
}

local m_tmpl = {
  EVENT  = '[Event "?"]',
  SITE   = '[Site "?"]',
  DATE   = '[Date "????.??.??"]',
  ROUND  = '[Round "?"]',
  WHITE  = '[White "?"]',
  BLACK  = '[Black "?"]',
  RESULT = '[Result "*"]'
}

-- Для контроля и порядока вывода тегов в файл
local c_keys = {
  "EVENT", "SITE", "DATE", "ROUND", "WHITE", "BLACK", "RESULT",
  "FEN", "ECO", "WHITEELO", "BLACKELO", "WHITEFIDEID",
  "BLACKFIDEID"
}

if m_eco then m_tags.ECO         = "ECO"         end
if m_elo then m_tags.WHITEELO    = "WhiteElo"    end
if m_elo then m_tags.BLACKELO    = "BlackElo"    end
if m_fid then m_tags.WHITEFIDEID = "WhiteFideId" end
if m_fid then m_tags.BLACKFIDEID = "BlackFideId" end
if m_fix then m_tmpl.DATE        = '[Date "?"]'  end

local SYM_CLN  = (';'):byte()
local SYM_BRK  = ('['):byte()
local CLN_ZERO = 0
local CLN_TAGS = 1
local CLN_HEAD = 2
local CLN_CRLF = 2
local CLN_TEXT = 4

local m_note = CLN_ZERO
local m_read = false
local m_flow = false

local
function clone(src)
  local ret = {}
  for key, val in pairs(src) do
    ret[key] = val
  end
  return ret
end

local m_tval = clone(m_tmpl)

local
function dformat(line)
  line = line:gsub("%s+", "")
  line = line:gsub("%.+", ".")
  line = line:gsub("^%.", "")
  line = line:gsub("%.$", "")

  local
  function isleap(y)
    return ((y % 4 == 0) and (y % 100 ~= 0)) or (y % 400 == 0)
  end

  local retval = { "????", "??", "??" }
  local list = {}

  for item in (line .. "."):gmatch("([^.]*).") do
    table.insert(list, item)
    if #list == 3 then break end
  end

  local ysub = list[1] or ""
  local ynum = nil

  if ysub:match("^%d+$") then
    if #ysub == 2 then
      local val = tonumber(ysub)
      ysub = (val < 50) and ("20" .. ysub) or ("19" .. ysub)
    end

    if #ysub == 4 then
      ynum = tonumber(ysub)
      retval[1] = ysub
    end
  end

  local dcnt = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }

  if ynum and isleap(ynum) then
    dcnt[2] = 29
  end

  local msub = list[2] or ""
  local mnum = nil

  if (msub ~= "") and msub:match("^%d+$") then
    local mfmt = (#msub == 1) and ("0" .. msub) or msub
    local val = tonumber(mfmt)

    if (#mfmt == 2) and (val >= 1) and (val <= 12) then
      retval[2] = mfmt; mnum = val
    end
  end

  local dsub = list[3] or ""

  if (dsub ~= "") and dsub:match("^%d+$") then
    local dfmt = (#dsub == 1) and ("0" .. dsub) or dsub
    local val = tonumber(dfmt)

    local dmax = 31
    if mnum then dmax = dcnt[mnum] end

    if (#dfmt == 2) and (val >= 1) and (val <= dmax) then
      retval[3] = dfmt
    end
  end

  return table.concat(retval, ".")
end

local
function dfix(line)
  if not m_fix then return line end
  line = line:gsub("%?%?%?%?%.%?%?%.%?%?", "?")
  line = line:gsub("%.%?%?%.%?%?", "")
  return line
end

local
function sfix(line)
  if not m_set then return line end
  return '[SetUp "1"]\n' .. line
end

local
function lprobe(line)
  line = line:gsub('\\"%s*%]?$', "'\"]")

  if line:sub(-1) ~= ']' then
    if line:sub(-1) ~= '"' then line = line .. '"' end
    line = line .. ']'
  end

  line = line:gsub('\\"', "'")
  local tupp = nil

  local
  function tprobe(traw, vraw)
    local key = traw:upper()

    local tstd = m_tags[key] or traw
    if m_tags[key] then tupp = key end

    if key ~= "DATE" then
      vraw = vraw:gsub("^%s+", ""):gsub("%s+$", "")
      vraw = vraw:gsub("%s+([.,])", "%1")
      vraw = vraw:gsub("%s+", " ")

      if #vraw < 1 then vraw = "?" end
    else
      vraw = dformat(vraw)
    end

    return "[" .. tstd .. ' "' .. vraw .. '"]'
  end

  local lfix = line:gsub('^%[%s*([%w_]+)%s+"(.-)"%s*%]$', tprobe)
  return lfix, tupp
end

local
function hflush()
  if m_flow then print("") end

  for _, key in ipairs(c_keys) do
    local val = m_tval[key]
    if val then print(val) end
  end

  m_tval = clone(m_tmpl)

  print("")
  m_note = CLN_HEAD
  m_flow = true
end

-- Лимит на количество партий в этом скрипте не используется
for line in io.lines() do
  line = line:match("^[%s%c]*(.-)[%s%c]*$") -- концевые пробелы
  local sym = line:byte(1)

  if sym == SYM_BRK then
    local tag
    line, tag = lprobe(line)

    if m_tags[tag] then
      if     tag == "EVENT"       then m_tval.EVENT                   = line
      elseif tag == "SITE"        then m_tval.SITE                    = line
      elseif tag == "DATE"        then m_tval.DATE                    = dfix(line)
      elseif tag == "ROUND"       then m_tval.ROUND                   = line
      elseif tag == "WHITE"       then m_tval.WHITE                   = line
      elseif tag == "BLACK"       then m_tval.BLACK                   = line
      elseif tag == "RESULT"      then m_tval.RESULT                  = line
      elseif tag == "FEN"         then m_tval.FEN                     = sfix(line)
      elseif tag == "ECO"         and  m_eco  then m_tval.ECO         = line
      elseif tag == "WHITEELO"    and  m_elo  then m_tval.WHITEELO    = line
      elseif tag == "BLACKELO"    and  m_elo  then m_tval.BLACKELO    = line
      elseif tag == "WHITEFIDEID" and  m_fid  then m_tval.WHITEFIDEID = line
      elseif tag == "BLACKFIDEID" and  m_fid  then m_tval.BLACKFIDEID = line
      end
    end

    if m_note == CLN_HEAD then print("*") end
    m_note = CLN_TAGS
  elseif sym == SYM_CLN then
    if m_note == CLN_ZERO then
      print(line)
      m_flow = true
    end
  elseif line ~= "" then
    if (m_note == CLN_ZERO) or (m_note == CLN_TAGS)
      then hflush() end

    print(line)
    m_note = CLN_TEXT
    m_flow = true
  elseif line == "" then
    if m_note == CLN_TAGS then
      hflush()

      m_note = CLN_CRLF
      m_flow = true
    end
  end

  m_read = true
end

-- Подбор хвостов
if m_read then
  if m_note == CLN_TAGS then
    hflush(); print("*")
    m_flow = true
  elseif m_note == CLN_HEAD then
    print("*")
    m_flow = true
  end
end

if m_flow then print("") end

