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
-- Parse a string, looking for a RXSTATUSA log
-- Inputs:
--   raw_data_string     String containing input data

-- Returns:
--   nil if no RXSTATUSA log is found
--   A table representing the data of a RXSTATUSA log if a log is found
--******************************************************************************
function parse_rxstatusa(raw_data_string)
  -- Search for a RXSTATUSA log.
  -- string.find returns the start and stop index as well as any strings that are "captured" within the parentheses
  -- OEM7 Documentation for the RXSTATUS log is located here:
  -- https://docs.novatel.com/OEM7/Content/Logs/RXSTATUS.htm
  local find_log_start, find_log_stop, header_string, data_string = raw_data_string:find("#(RXSTATUSA[^;]*;)([^%*]*%*).-\n")
       
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
    log_fields['ReceiverError'] = data_iter()
    log_fields['ReceiverErrorExt'] = data_iter()
    log_fields['ReceiverStatus0'] = data_iter()
    log_fields['ReceiverStatus1'] = data_iter()
    log_fields['ReceiverStatus2'] = data_iter()
    log_fields['ReceiverStatus3'] = data_iter()
    log_fields['Aux1Status0'] = data_iter()
    log_fields['Aux1Status1'] = data_iter()
    log_fields['Aux1Status2'] = data_iter()
    log_fields['Aux1Status3'] = data_iter()
    log_fields['Aux2Status0'] = data_iter()
    log_fields['Aux2Status1'] = data_iter()
    log_fields['Aux2Status2'] = data_iter()
    log_fields['Aux2Status3'] = data_iter()
    log_fields['Aux3Status0'] = data_iter()
    log_fields['Aux3Status1'] = data_iter()
    log_fields['Aux3Status2'] = data_iter()
    log_fields['Aux3Status3'] = data_iter()
    log_fields['Aux4Status0'] = data_iter()
    log_fields['Aux4Status1'] = data_iter()
    log_fields['Aux4Status2'] = data_iter()
    log_fields['Aux4Status3'] = data_iter()

    return log_fields 
  end
  -- NOTE:  There is an implicit return of nil for Lua functions
  --        that do not otherwise return a value
end