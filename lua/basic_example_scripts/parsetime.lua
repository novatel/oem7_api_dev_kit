-- /******************************************************************************
--  Copyright (c) 2021 NovAtel Inc.
-- 
--  Permission is hereby granted, free of charge, to any person obtaining a copy
--  of this software and associated documentation files (the "Software"), to deal
--  in the Software without restriction, including without limitation the rights
--  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
--  copies of the Software, and to permit persons to whom the Software is
--  furnished to do so, subject to the following conditions:
-- 
--  The above copyright notice and this permission notice shall be included in all
--  copies or substantial portions of the Software.
-- 
--  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
--  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
--  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
--  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
--  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
--  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
--  SOFTWARE.
-- *****************************************************************************/

--******************************************************************************
-- Script to demonstrate collection and parsing of NovAtel ASCII logs
--******************************************************************************

--******************************************************************************
-- Parse a string, looking for a TIMEA log
-- Inputs:
--   Buffer_     String containing input data

-- Returns:
--   nil if no TIMEA log is found
--   A table representing the data of a TIMEA log if a log is found
--******************************************************************************
function ParseTIMEA(Buffer_)

 -- Search for a TIMEA log.  
 -- string.find returns the start and stop index as well as any strings that are "captured" within the parentheses
  local FindTIMEAStart
  local FindTIMEAStop
  local TIMEAheader_string
  local TIMEAData
  
  FindTIMEAStart,FindTIMEAStop, TIMEAheader_string,TIMEAData 
    = Buffer_:find("#(TIMEA[^;]*;)([^%*]*%*).-\n")
    
  if FindTIMEAStart ~= nil then    
   -- Found a TIMEA log
    
   -- split the header_string into its elements
    local header_stringIter = TIMEAheader_string:gmatch("([^,]-)[,%;]")
    header_stringData = {}
    header_stringData['Message'] = header_stringIter()
    header_stringData['Port'] = header_stringIter()
    header_stringData['Sequence'] = header_stringIter()
    header_stringData['IdleTime'] = header_stringIter()
    header_stringData['TimeStatus'] = header_stringIter()
    header_stringData['Week'] = header_stringIter()
    header_stringData['Second'] = header_stringIter()
    header_stringData['ReceiverStatus'] = header_stringIter()
    header_stringData['Reserved'] = header_stringIter()
    header_stringData['ReceiverSWVersion'] = header_stringIter()     
    
   -- Split the data into its elements    
   -- gmatch returns an iterator function that can be called successively to get
   -- the next string matching the pattern.
    local DataIter = TIMEAData:gmatch("([^,]-)[,%*]")
    
   -- Create a table for the Time Data and assign the data fields into that table
    TimeData = {}
    TimeData['header_string'] = header_stringData
    TimeData['ClockStatus'] = DataIter()
    TimeData['Offset'] = DataIter()
    TimeData['OffsetStd'] = DataIter()
    TimeData['UTCOffset'] = DataIter()
    TimeData['UTCYear'] = DataIter()
    TimeData['UTCMonth'] = DataIter()
    TimeData['UTCDay'] = DataIter()
    TimeData['UTCHour'] = DataIter()
    TimeData['UTCMinute'] = DataIter()
    TimeData['UTCMillisecond'] = DataIter()
    TimeData['UTCStatus'] = DataIter()
    
    return TimeData 
  end
 -- NOTE:  There is an implicit return of nil for Lua functions
 --        that do not otherwise return a value
end

--******************************************************************************
-- Create a custom NovAtel-like log based on data from a TIMEA log that contains
-- the UTC Month
   -- Inputs:
   --   TimeData_     String containing input data

   -- Returns:
   --   Custom Log String
--******************************************************************************
local function CreateMonthLog(TimeData_,OutputPort_)
  local header_stringData = TimeData_['header_string']
  
  local MonthTable = { 'January','February','March','April','May','June','July','August','September','October','November','December' }

 -- Setup the header_string and Data. 
 -- Leave out the leading # and trailing * as the are not included in the CRC
  local CustomLog = 
    string.format("MONTHA,%s,%s,%s,%s,%s,%s,%s,%s,%s;%s",
                  OutputPort_,-- Note that the port is updated to the port where this log will be sent
                  header_stringData['Sequence'],
                  header_stringData['IdleTime'],
                  header_stringData['TimeStatus'],
                  header_stringData['Week'],
                  header_stringData['Second'],
                  header_stringData['ReceiverStatus'],
                  header_stringData['Reserved'],
                  header_stringData['ReceiverSWVersion'],
                  MonthTable[tonumber(TimeData['UTCMonth'])])
                
 -- the crc32.lua script is included with the NovAtel Lua Dev Kit
  local CRC = require("crc32").CalculateBlock(CustomLog,0) 
  
 -- Format together the leading #, the log data, the trailing * and calculated CRC.
  return string.format("#%s*%08x",CustomLog,CRC)
end

--******************************************************************************
-- Request TIMEA logs on SCOM1, parse them and produce a new NovAtel-like custom log
-- Inputs:
--   arg[1]     String representing the output port (e.g. 'COM1')
--******************************************************************************
local function main()
  
  local OutputPort = arg[1]
  
  if OutputPort == nil then
    print("No Ouput Port Specified")
    return
  end  
  
  local SocketLib = require("socket")
  local SocketSCOM1 = SocketLib.udp()

 -- Setup the sockets
  local TargetIP = "127.0.0.1"

  assert(SocketSCOM1:setsockname("*",0))
  assert(SocketSCOM1:setpeername(TargetIP,require("scom").GetSCOMPort(1)))
  assert(SocketSCOM1:settimeout(3))

 -- Request the TIMEA log on SCOM1
  SocketSCOM1:send("LOG TIMEA ONTIME 1\r")

  while true do
   -- Wait for TIMEA Logs
    local Buffer = SocketSCOM1:receive()
    if Buffer == nil then 
      print("... timed out")
      break
    end
    
    local TimeData = ParseTIMEA(Buffer)
        
    if TimeData ~= nil then
     -- Uncomment the lines below to dump out the parsed TIMEA data    
--      for Key,Value in pairs(TimeData) do
--        if type(Value) == "table" then
--          print(string.format("%s:",Key))
--          for SubKey,SubValue in pairs(Value) do
--            print(string.format("  %s: \"%s\"",SubKey,SubValue))  
--          end
--        else      
--          print(string.format("%s: \"%s\"",Key,Value))
--        end
--      end  
--      print("------------------------\n")
      
     -- Format the new log
      local MonthLog = CreateMonthLog(TimeData,OutputPort)
                
     -- Send the log out the port
     -- Note in firmware version OM7MR0400RN0000 the SEND command can only 
     -- send 100 bytes at once.  That is sufficient for this example, but 
     -- in an actual use case the log should be sent out in 100 byte chunks.
      SocketSCOM1:send(string.format('send %s \"%s\"\r',OutputPort,MonthLog))
    end
  end
end

--******************************************************************************
main()
