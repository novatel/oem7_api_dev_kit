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