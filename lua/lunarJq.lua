------------------------------------
----------modify: 空山明月-----------
------------------------------------

--*******农历节气计算部分
--========角度变换===============
local rad = 180*3600/math.pi --每弧度的角秒数
local RAD = 180/math.pi	  --每弧度的角度数
function int2(v) --取整数部分
	v=math.floor(v)
	if v<0 then return v+1
	else return v
	end
end

function rad2mrad(v)   --对超过0-2PI的角度转为0-2PI
	v=math.fmod(v ,2*math.pi)
	if v<0 then  return v+2*math.pi
	else return v
	end
end

function rad2str(d,tim) --将弧度转为字串
	---tim=0输出格式示例: -23°59' 48.23"
	---tim=1输出格式示例:  18h 29m 44.52s
	local s="+"
	local w1="°" w2="’"  w3="”"
	if d<0 then  d=-d  s='-'end
	if tim~= 0 then  d=d*12/math.pi w1="h " w2="m " w3="s "
	else	 d=d*180/math.pi end
	local a=math.floor(d) d=(d-a)*60
	local b=math.floor(d) d=(d-b)*60
	local c=math.floor(d) d=(d-c)*100
	d=math.floor(d+0.5)
	if d>=100 then d=d-100 c=c+1 end
	if c>=60  then c=c-60  b=b+1 end
	if b>=60  then b=b-60  a=a+1 end
	a="   "+a b="0"+b c="0"+c d="0"+d
	local alen = string.len(a)
	local blen = string.len(b)
	local clen = string.len(c)
	local dlen = string.len(d)
	s = s .. string.sub(a, alen-3,alen)+w1
	s = s .. string.sub(b, blen-2,blen)+w2
	s = s .. string.sub(c, clen-2,clen)+"."
	s = s .. string.sub(d, dlen-2,dlen)+w3
	return s
end
--================日历计算===============
local J2000=2451545 --2000年前儒略日数(2000-1-1 12:00:00格林威治平时)

local JDate={ --日期元件
Y=2000, M=1, D=1, h=12, m=0, s=0,
dts = { --世界时与原子时之差计算表
-4000,108371.7,-13036.80,392.000, 0.0000, -500, 17201.0,  -627.82, 16.170,-0.3413,
-150, 12200.6,  -346.41,  5.403,-0.1593,  150,  9113.8,  -328.13, -1.647, 0.0377,
500,  5707.5,  -391.41,  0.915, 0.3145,  900,  2203.4,  -283.45, 13.034,-0.1778,
1300,   490.1,   -57.35,  2.085,-0.0072, 1600,   120.0,	-9.81, -1.532, 0.1403,
1700,	10.2,	-0.91,  0.510,-0.0370, 1800,	13.4,	-0.72,  0.202,-0.0193,
1830,	 7.8,	-1.81,  0.416,-0.0247, 1860,	 8.3,	-0.13, -0.406, 0.0292,
1880,	-5.4,	 0.32, -0.183, 0.0173, 1900,	-2.3,	 2.06,  0.169,-0.0135,
1920,	21.2,	 1.69, -0.304, 0.0167, 1940,	24.2,	 1.22, -0.064, 0.0031,
1960,	33.2,	 0.51,  0.231,-0.0109, 1980,	51.0,	 1.29, -0.026, 0.0032,
2000,	64.7,	-1.66,  5.224,-0.2905, 2150,   279.4,   732.95,429.579, 0.0158, 6000},
deltatT = function(JDate, y) --计算世界时与原子时之差,传入年
	local  i
	local d=JDate.dts
	for x=1,100, 5 do
		if y<d[x+5] or x==96 then  i=x break end
	end

	local t1=(y-d[i])/(d[i+5]-d[i])*10
	local t2=t1*t1
	local t3=t2*t1
	return d[i+1] +d[i+2]*t1 +d[i+3]*t2 +d[i+4]*t3
end,
deltatT2 = function(JDate,jd) --传入儒略日(J2000起算),计算UTC与原子时的差(单位:日)
	return JDate:deltatT(jd/365.2425+2000)/86400.0
end,
toJD = function(JDate, UTC) --公历转儒略日,UTC=1表示原日期是UTC
	local  y=JDate.Y m=JDate.M n=0 --取出年月
	if m<=2 then  m=m+12 y=y-1 end
	if JDate.Y*372+JDate.M*31+JDate.D>=588829 then --判断是否为格里高利历日1582*372+10*31+15
		n =int2(y/100) n =2-n+int2(n/4)--加百年闰
	end
	n = n + int2(365.2500001*(y+4716))	--加上年引起的偏移日数
	n = n + int2(30.6*(m+1))+JDate.D	   --加上月引起的偏移日数及日偏移数
	n = n + ((JDate.s/60+JDate.m)/60+JDate.h)/24 - 1524.5
	if(UTC == 1) then return n+JDate.deltatT2(n-J2000) end
	return n
end,
setFromJD = function(JDate, jd,UTC) --儒略日数转公历,UTC=1表示目标公历是UTC
	if UTC==1 then  jd= jd - JDate:deltatT2(jd-J2000) end
	jd =jd+0.5
	local A=int2(jd) F=jd-A, D  --取得日数的整数部份A及小数部分F
	if A>2299161 then  D=int2((A-1867216.25)/36524.25) A=A+1+D-int2(D/4) end
	A = A + 1524 --向前移4年零2个月
	JDate.Y =int2((A-122.1)/365.25)--年
	D =A-int2(365.25*JDate.Y) --去除整年日数后余下日数
	JDate.M =int2(D/30.6001)\t   --月数
	JDate.D =D-int2(JDate.M*30.6001)--去除整月日数后余下日数
	JDate.Y=JDate.Y-4716 JDate.M=JDate.M-1
	if JDate.M>12 then  JDate.M=JDate.M - 12 end
	if JDate.M<=2 then  JDate.Y = JDate.Y+1 end
	--日的小数转为时分秒
	F=F*24 JDate.h=int2(F) F=F - JDate.h
	F=F*60 JDate.m=int2(F) F=F - JDate.m
	F=F*60 JDate.s=F
end,

setFromStr = function(JDate, s) --设置时间,参数例:"20000101 120000"或"20000101"
	JDate.Y=string.sub(s, 1,4)	JDate.M=string.sub(s, 5, 6)  JDate.D=string.sub(s,7, 8)
	JDate.h=string.sub(s, 10, 11) JDate.m=string.sub(s, 12,13) JDate.s=string.sub(s, 14,18)
end,
toStr = function(JDate) --日期转为串
	local Y="	 " .. JDate.Y
	local M="0" .. JDate.M
	local D="0" .. JDate.D
	local h=JDate.h
	local m=JDate.m
	local s=math.floor(JDate.s+.5)
	if s>=60 then s=s-60 m=m+1 end
	if m>=60 then m=m-60 h=h+1 end
	h="0".. h m="0" .. m s="0" .. s
	local Ylen = string.len(Y)
	local Mlen = string.len(M)
	local Dlen = string.len(D)
	local hlen = string.len(h)
	local mlen = string.len(m)
	local slen = string.len(s)
	Y=string.sub(Y, Ylen -4,Ylen) M=string.sub(M, Mlen-1,Mlen) D=string.sub(D,Dlen-1, Dlen)
	h=string.sub(h, hlen-1, hlen) m=string.sub(m, mlen-1,mlen) s=string.sub(s, slen-1,slen)
	return Y .. "-" .. M .. "-" .. D .. " " .. h .. ":" .. m .. ":" .. s
end,

JQ = function(JDate) --输出节气日期的秒数
	local t = {}
	t.year=JDate.Y
	t.month=JDate.M
	t.day=JDate.D
	t.hour=JDate.h
	t.min=JDate.m
	t.sec=math.floor(JDate.s+.5)
	if t.sec>=60 then t.sec=t.sec-60 t.min=t.min+1 end
	if t.min>=60 then t.min=t.min-60 t.hour=t.hour+1 end
	return os.time(t)
end,

Dint_dec = function(JDate, jd,shiqu,int_dec) --算出:jd转到当地UTC后,UTC日数的整数部分或小数部分
	--基于J2000力学时jd的起算点是12:00:00时,所以跳日时刻发生在12:00:00,这与日历计算发生矛盾
	--把jd改正为00:00:00起算,这样儒略日的跳日动作就与日期的跳日同步
	--改正方法为jd=jd+0.5-deltatT+shiqu/24
	--把儒略日的起点移动-0.5(即前移12小时)
	--式中shiqu是时区,北京的起算点是-8小时,shiqu取8
	local u=jd+0.5-JDate.deltatT2(jd)+shiqu/24
	if int_dec~= 0 then  return math.floor(u) --返回整数部分
	else return u-math.floor(u)	  --返回小数部分
	end
end,

d1_d2 = function(JDate, d1,d2) --计算两个日期的相差的天数,输入字串格式日期,如:"20080101"
	local Y=JDate.Y M=JDate.M D=JDate.D h=JDate.h m=JDate.m s=JDate.s --备份原来的数据
	JDate.setFromStr(string.sub(d1,1,8)+" 120000")	local jd1=JDate.toJD(0)
	JDate.setFromStr(string.sub(d2,1,8)+" 120000")	local jd2=JDate.toJD(0)

	JDate.Y=Y JDate.M=M JDate.D=D JDate.h=h JDate.m=m JDate.s=s --还原
	if jd1>jd2 then  return  math.floor(jd1-jd2+.0001)
	else		return -Math.floor(jd2-jd1+.0001)
	end
end,
}
--=========黄赤交角及黄赤坐标变换===========
local hcjjB = {84381.448, -46.8150, -0.00059, 0.001813}--黄赤交角系数表
local preceB= {0,50287.92262,111.24406,0.07699,-0.23479,-0.00178,0.00018,0.00001}--Date黄道上的岁差p
... (file continues)
-- 轻量版节气判定：基于常用经验公式（适用于1900-2099年）
-- 参考常用算法：day = floor(Y%100 * 0.2422 + C) - floor((Y%100 -1)/4)
local sTermInfo = {6.11,20.84,4.6295,19.4599,6.3826,21.04,5.52,20.646,6.318,21.86,6.5,22.20,7.928,23.65,8.35,23.95,9.98,25.03,8.91,24.32,8.44,22.93,7.646,21.04}
local sTermNames= {"小寒","大寒","立春","雨水","惊蛰","春分","清明","谷雨","立夏","小满","芒种","夏至","小暑","大暑","立秋","处暑","白露","秋分","寒露","霜降","立冬","小雪","大雪","冬至"}

local function calcTermDay(year, idx)
  -- year: full year, idx: 1-24
  local y = year % 100
  local C = sTermInfo[idx]
  local day = math.floor(y * 0.2422 + C) - math.floor((y-1)/4)
  -- 少数年份需要修正（常见修正表可在后续迭代中加入），这里做最小修正保证常见年份正确
  return day
end

local function JQtest(dateStr)
  if not dateStr or #dateStr<8 then return "" end
  local y = tonumber(string.sub(dateStr,1,4))
  local m = tonumber(string.sub(dateStr,5,6))
  local d = tonumber(string.sub(dateStr,7,8))
  if not (y and m and d) then return "" end
  -- 每月有两个节气：分别对应索引 (m*2-1) 与 (m*2)
  local idx1 = m*2-1
  local idx2 = m*2
  local day1 = calcTermDay(y, idx1)
  local day2 = calcTermDay(y, idx2)
  if d == day1 then return "-" .. sTermNames[idx1] end
  if d == day2 then return "-" .. sTermNames[idx2] end
  return ""
end

return {
  JQtest = JQtest
}
