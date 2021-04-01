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
-- This script demonstrates taking custom action depending on status reported 
-- by the BESTPOS log.
--
-- The end user must fully adapt and verify this for their application.
--
-- This is useful for simulating a "Position Valid" type signal on a PwrPak7
-- but this could also potentially be used on other OEM7 recivers as well.
--
-- By default, this script uses the COM3 TX pin and therefore this pix is not
-- available for RS-232 use while this script is in use. There are alternative
-- pin options defined below, the options are:
--    - COM1 TX
--    - COM2 TX
--    - COM3 TX
--    - MARK3 (NMARK pins use strobe logic, so they toggle for 10ns, every 1s)
--
-- To change what pin is signaled with, edit the below definitions of:
--    - "GOOD_POSITION_COMMAND", and
--    - "BAD_POSITION_COMMAND"
--
-- To change what part of BESTPOS is used to signal a "good" or "bad" state,
-- edit the below set_status_by_bestpos function. By default, the good state is 
-- defined as when the BESTPOS log reports a SOL_COMPUTED Solution Status.
--
-- Questions may be directed to support.novatel@hexagon.com
--******************************************************************************

-- Configurable commands below. Manually verify that you can use these on your model.
LOG_BESTPOS_COMMAND="LOG BESTPOSA ONTIME 3\r"
GOOD_POSITION_MARK3_COMMAND="EVENTOUTCONTROL MARK3 ENABLE POSITIVE 10\r"
BAD_POSITION_MARK3_COMMAND="EVENTOUTCONTROL MARK3 ENABLE NEGATIVE 999990\r"
GOOD_POSITION_COM1_COMMAND="COMCONTROL COM1 TX FORCEHIGH\r"
BAD_POSITION_COM1_COMMAND="COMCONTROL COM1 TX FORCELOW\r"
GOOD_POSITION_COM2_COMMAND="COMCONTROL COM2 TX FORCEHIGH\r"
BAD_POSITION_COM2_COMMAND="COMCONTROL COM2 TX FORCELOW\r"
GOOD_POSITION_COM3_COMMAND="COMCONTROL COM3 TX FORCEHIGH\r"
BAD_POSITION_COM3_COMMAND="COMCONTROL COM3 TX FORCELOW\r"

-- Select the desired behaviour here:
GOOD_POSITION_COMMAND=GOOD_POSITION_COM3_COMMAND
BAD_POSITION_COMMAND=BAD_POSITION_COM3_COMMAND

--******************************************************************************
-- Parse a string, looking for a BESTPOSA log
-- Inputs:
--   raw_data_string     String containing input data

-- Returns:
--   nil if no BESTPOSA log is found
--   A table representing the data of a BESTPOSA log if a log is found
--******************************************************************************
function parse_bestposa(raw_data_string)
    -- Search for a BESTPOSA log.  
    -- string.find returns the start and stop index as well as any strings that are "captured" within the parentheses
    -- OEM7 Documentation for the BESTPOS log is located here:
    -- https://docs.novatel.com/OEM7/Content/Logs/BESTPOS.htm
    local find_log_start, find_log_stop, header_string, data_string = raw_data_string:find("#(BESTPOSA[^;]*;)([^%*]*%*).-\n")
         
    if find_log_start ~= nil then
      -- Found a BESTPOSA log, split the header into its elements
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
      log_fields['Reserved'] = data_iter()
      log_fields['ExtendedSolutionStatus'] = data_iter()
      log_fields['GalileoBeidouSignalMask'] = data_iter()
      log_fields['GPSGlonassSignalMask'] = data_iter()
  
      return log_fields 
    end
    -- NOTE:  There is an implicit return of nil for Lua functions
    --        that do not otherwise return a value
  end

function set_status_by_bestpos(bestpos_log_fields, scom_socket)
  -- Take custom action on solution status of BESTPOSA log

  if bestpos_log_fields ~= nil then
    local solution_status = bestpos_log_fields['SolutionStatus']
    local time_status = bestpos_log_fields['header']['TimeStatus']
    print(string.format("%s-%s: %s,%s",  bestpos_log_fields['header']['Week'], bestpos_log_fields['header']['Second'], time_status, solution_status))

    -- If BESTPOS Solution Status is "SOL_COMPUTED", then take custom action to indicate that it is good
    if solution_status == "SOL_COMPUTED" then
        scom_socket:send(GOOD_POSITION_COMMAND)
        return
    end

    -- Alternatively, one might prefer to signal status based on the Time Status
    -- Refer here: https://docs.novatel.com/OEM7/Content/Messages/GPS_Reference_Time_Statu.htm
    --if time_status == "FINESTEERING" then
    --    scom_socket:send(GOOD_POSITION_COMMAND)
    --    return
    --end

    -- If here, then take custom action to indicate the status is not good
    scom_socket:send(BAD_POSITION_COMMAND)
  end
end
   
   --******************************************************************************
   -- Request log defined in LOG_BESTPOS_COMMAND
   -- Monitor reply data and set custom status depending on conditions defined in
   -- set_custom_status() function.
   --******************************************************************************
local function main()
  print("Starting BESTPOS signal script")

  -- establish SCOM port for script communcations with Lua
  local socket_lib = require("socket")
  local scom_socket = socket_lib.udp()

  -- Setup the sockets
  local target_ip = "127.0.0.1"
  assert(scom_socket:setsockname("*",0))
  assert(scom_socket:setpeername(target_ip,require("scom").GetSCOMPort(1)))
  assert(scom_socket:settimeout(3))

  -- Setup 
  scom_socket:send(BAD_POSITION_COMMAND)

  -- Request the log on SCOM1
  scom_socket:send(LOG_BESTPOS_COMMAND)

  while true do
    -- Wait for Logs
    local raw_data_string = scom_socket:receive()
    if raw_data_string ~= nil then 
      set_status_by_bestpos(parse_bestposa(raw_data_string), scom_socket)
    end
   end
end
   
--******************************************************************************
main()
   
