-- /******************************************************************************
--  Copyright (c) 2020 NovAtel Inc.
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
-- Script to demonstrate signaling position type via COM2 RTS pin
--******************************************************************************

-- Configurable commands below. Verify you can manually use these on your model.
SERIAL_CONFIG_COMMAND="SERIALCONFIG COM2 9600 N 8 1 CTS ON\r"
LOG_BESTPOS_COMMAND="LOG BESTPOSA ONTIME 5\r"
LOG_PPPPOS_COMMAND="LOG PPPPOSA ONTIME 5\r"
BAD_POSITION_COMMAND="COMCONTROL COM2 RTS FORCELOW\r"
WARNING_POSITION_COMMAND="COMCONTROL COM2 RTS TOGGLEPPS\r"
GOOD_POSITION_COMMAND="COMCONTROL COM2 RTS FORCEHIGH\r"

--******************************************************************************
-- Parse a string, looking for a PPPPOSA log
-- Inputs:
--   raw_data_string     String containing input data

-- Returns:
--   nil if no PPPPOSA log is found
--   A table representing the data of a PPPPOSA log if a log is found
--******************************************************************************
function parse_pppposa(raw_data_string)
  -- Search for a PPPPOSA log.  
  -- string.find returns the start and stop index as well as any strings that are "captured" within the parentheses
  -- OEM7 Documentation for the PPPPOS log is located here:
  -- https://docs.novatel.com/OEM7/Content/Logs/PPPPOS.htm
  local find_log_start, find_log_stop, header_string, data_string = raw_data_string:find("#(PPPPOSA[^;]*;)([^%*]*%*).-\n")
       
  if find_log_start ~= nil then    
    -- Found a PPPPOSA log, split the header into its elements
    local HeaderIter = header_string:gmatch("([^,]-)[,%;]")
    header_fields = {}
    header_fields['Message'] = HeaderIter()
    header_fields['Port'] = HeaderIter()
    header_fields['Sequence'] = HeaderIter()
    header_fields['IdleTime'] = HeaderIter()
    header_fields['TimeStatus'] = HeaderIter()
    header_fields['Week'] = HeaderIter()
    header_fields['Second'] = HeaderIter()
    header_fields['ReceiverStatus'] = HeaderIter()
    header_fields['Reserved'] = HeaderIter()
    header_fields['ReceiverSWVersion'] = HeaderIter()     
        
    -- Split the data into its elements    
    -- gmatch returns an iterator function that can be called successively to get
    -- the next string matching the pattern.
    local data_iter = data_string:gmatch("([^,]-)[,%*]")
        
    -- Create a table for the Time data_string and assign the data fields into that table
    log_fields = {}
    log_fields['header'] = header_fields
    log_fields['SolutionStatus'] = data_iter()
    log_fields['PositionType'] = data_iter()
    log_fields['Latitude'] = data_iter()
    log_fields['Longitude'] = data_iter()
    log_fields['HeightASL'] = data_iter()
    log_fields['Undulation'] = data_iter()
    log_fields['DatumId'] = data_iter()
    log_fields['LatStdDeviation'] = data_iter()
    log_fields['LongStdDeviation'] = data_iter()
    log_fields['HgtStdDeviation'] = data_iter()
    log_fields['BaseStationId'] = data_iter()
    log_fields['DifferentialAge'] = data_iter()
    log_fields['SolutionAge'] = data_iter()
    log_fields['NumTrackedSVs'] = data_iter()
    log_fields['NumSVsInSolution'] = data_iter()
    log_fields['Reserved1'] = data_iter()
    log_fields['ExtendedSolutionStatus'] = data_iter()
    log_fields['Reserved2'] = data_iter()
    log_fields['GPSGlonassSignalMask'] = data_iter()

    return log_fields 
  end
  -- NOTE:  There is an implicit return of nil for Lua functions
  --        that do not otherwise return a value
end

function set_custom_status(log_fields, scom_socket)
  -- Set custom status based on log data provided
  -- Works with PPPPOSA and BESTPOSA

  if log_fields ~= nil then
    local type = log_fields['PositionType']
    local time_status = log_fields['header']['TimeStatus']
    print(string.format("%s-%s: %s,%s",  log_fields['header']['Week'], log_fields['header']['Second'], time_status, type))
    
    if type == "PPP" or type == "PPP_BASIC" then
      if time_status == "FINE" or time_status == "FINESTEERING" then
        -- If the Time Status is FINE or FINESTEERING, then the immediate position is good
        scom_socket:send(GOOD_POSITION_COMMAND)
      else
        -- If the Time Status is not FINE or FINESTEERING, but we're in PPP(_BASIC) then issue warning
        scom_socket:send(WARNING_POSITION_COMMAND)
      end
      return
    end
    
    if type == "PPP_CONVERGING" or type == "PPP_BASIC_CONVERGING" then
      scom_socket:send(WARNING_POSITION_COMMAND)
      return
    end
    
    -- If here, then the position type is not a PPP type at all
    scom_socket:send(BAD_POSITION_COMMAND)
  end
end
   
   --******************************************************************************
   -- Request log defined in LOG_PPPPOS_COMMAND
   -- Monitor reply data and set custom status depending on conditions defined in
   -- set_custom_status() function.
   --******************************************************************************
local function main()
  print("Starting ppp script")

  -- establish SCOM port for script communcations with Lua
  local socket_lib = require("socket")
  local scom_socket = socket_lib.udp()

  -- Setup the sockets
  local target_ip = "127.0.0.1"
  assert(scom_socket:setsockname("*",0))
  assert(scom_socket:setpeername(target_ip,require("scom").GetSCOMPort(1)))
  assert(scom_socket:settimeout(3))

  -- Setup 
  scom_socket:send(SERIAL_CONFIG_COMMAND)
  scom_socket:send(BAD_POSITION_COMMAND)

  -- Request the log on SCOM1
  scom_socket:send(LOG_PPPPOS_COMMAND)

  while true do
    -- Wait for Logs
    local raw_data_string = scom_socket:receive()
    if raw_data_string ~= nil then 
      set_custom_status(parse_pppposa(raw_data_string), scom_socket)
    end
   end
end
   
--******************************************************************************
main()
   