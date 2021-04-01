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
 
-- ***********************************************************************
local PCA9554HELP = [[
   NXP PCA9554 8-bit I2C-bus GPIO Expander Driver Script
]]
-- *********************************************************************** 
 
--------------------------------------------------------------------------
-- Used for ZeroBrane Studio
-------------------------------------------------------------------------- 
-- DebugHostIP = arg[1]  
-- require('mobdebug').start(DebugHostIP)

--------------------------------------------------------------------------
-- Socket to talk to SCOM through UDP
--------------------------------------------------------------------------
SocketLib = require("socket")
SocketSCOM1 = SocketLib.udp()

assert(SocketSCOM1:setsockname("*",0))
assert(SocketSCOM1:setpeername("127.0.0.1",scom.GetSCOMPort(1)))
assert(SocketSCOM1:settimeout(3))

--------------------------------------------------------------------------
-- GPIO attribute Macros matching to PCA9554 datasheet.  
--------------------------------------------------------------------------
GPIO_DIR_IN  = 1
GPIO_DIR_OUT = 0
GPIO_HIGH    = 1
GPIO_LOW     = 0
GPIO_POLINV  = 1
GPIO_POLNINV = 0

--------------------------------------------------------------------------
-- The device address of the I2C device, It is initialized to 0x38 which
-- is the default address of TotalPhase Aardvard I2C/SPI activity board.
--------------------------------------------------------------------------  
local DeviceAddress          = 0x38

local REG_VALUE_MASK         = 0xFF 

--------------------------------------------------------------------------
-- The register address for the PCA9554 GPIO Expander
--------------------------------------------------------------------------
local INPUT_PORT_REG         = 0x00
local OUTPUT_PORT_REG        = 0x01
local POLARITY_INVERSION_REG = 0x02
local CONFIGURATION_REG      = 0x03

--------------------------------------------------------------------------
-- TransactionID for each operation
--------------------------------------------------------------------------
local TID_GETDIRECTION       = 54321
local TID_SETDIRECTION       = 12345
local TID_GETOUTPUTLEVEL     = 67890
local TID_SETOUTPUTLEVEL     = 09876
local TID_GETINPUTLEVEL      = 13579
local TID_GETPOLARITYINV     = 24680
local TID_SETPOLARITYINV     = 08642

--------------------------------------------------------------------------
-- Function to send a command and wait for a prompt.
-- Returns the prompt on success, nil on failure
--------------------------------------------------------------------------
function WaitForPrompt(SocketSCOM_)
  while true do
    local Buffer = SocketSCOM_:receive()
    if Buffer == nil then 
      print("Timed out")
      return nil
    end
    
    local Start,Stop,Prompt = Buffer:find("(%[SCOM%d%])")
    
    if Prompt ~= nil then
      -- print("Prompt Received: ",Prompt)
      return Prompt
    end    
  end

  return nil  
end

--------------------------------------------------------------------------
-- Parse a string, looking for a USERI2CRESPONSEA log
-- Inputs:
--   Buffer_     String containing input data

-- Returns:
--   nil if no USERI2CRESPONSEA log is found
--   A table representing the data of a USERI2CRESPONSEA 
--   log if a log is found
--------------------------------------------------------------------------
function ParseUSERI2CRESPONSEA(Buffer_)

  -- Search for a USERI2CRESPONSEA log.      
  local FindStart, FindStop, LOGHeader, LOGData 
    = Buffer_:find("#(USERI2CRESPONSEA[^;]*;)([^%*]*%*).-\n")  
    
  if FindStart ~= nil then    
    -- Found a USERI2CRESPONSEA log.
    -- split the header into its elements.
    
    local HeaderIter = LOGHeader:gmatch("([^,]-)[,%;]")
    HeaderData = {}
    HeaderData['Message'] = HeaderIter()
    HeaderData['Port'] = HeaderIter()
    HeaderData['Sequence'] = HeaderIter()
    HeaderData['IdleTime'] = HeaderIter()
    HeaderData['TimeStatus'] = HeaderIter()
    HeaderData['Week'] = HeaderIter()
    HeaderData['Second'] = HeaderIter()
    HeaderData['ReceiverStatus'] = HeaderIter()
    HeaderData['Reserved'] = HeaderIter()
    HeaderData['ReceiverSWVersion'] = HeaderIter()     
    
    -- Split the data into its elements.
    -- Create a table for the USERI2CRESPONSEA Data and assign the 
    -- data fields into that table.        
    local DataIter = LOGData:gmatch("([^,]-)[,%*]")
    
    ResponseData = {}
    ResponseData['Header'] = HeaderData
    ResponseData['DeviceAddress'] = DataIter()
    ResponseData['RegisterAddress'] = DataIter()
    ResponseData['OperationStatus'] = DataIter()
    ResponseData['OperationMode'] = DataIter()
    ResponseData['TransactionID'] = DataIter()
    ResponseData['READLENGTH'] = DataIter()
    ResponseData['READDATA'] = DataIter()
    
    return ResponseData 
  end
end

--------------------------------------------------------------------------
-- Issue "LOG USERI2CRESPONSEA ONCE" command and then to wait to capture 
-- and parse the log. Timeout is defined by SocketSCOM1:settimeout(x)
 
-- Returns:
--   nil if no USERI2CRESPONSEA log is found
--   A table representing the data of a USERI2CRESPONSEA log if found
--------------------------------------------------------------------------
function GetAndParseResponse()
   
  -- Request the USERI2CRESPONSEA log on SCOM1
  SocketSCOM1:send("LOG USERI2CRESPONSEA ONCE\r")  
   
  while true do     
    -- Wait for USERI2CRESPONSEA Logs
    local Buffer = SocketSCOM1:receive()
    if Buffer == nil then 
      print("... timed out")
      break
    end   
      
    local ResponseData = ParseUSERI2CRESPONSEA(Buffer)
    if ResponseData ~= nil then 
      local HeaderData =  ResponseData['Header']
    
      -- print(string.format("Message:           %s", HeaderData['Message']))
      -- print(string.format("Port:              %s", HeaderData['Port']))    
      -- print(string.format("Sequence:          %s", HeaderData['Sequence']))
      -- print(string.format("IdleTime:          %s", HeaderData['IdleTime']))
      -- print(string.format("TimeStatus:        %s", HeaderData['TimeStatus']))
      -- print(string.format("Week:              %s", HeaderData['Week']))
      -- print(string.format("Second:            %s", HeaderData['Second']))
      -- print(string.format("ReceiverStatus:    %s", HeaderData['ReceiverStatus']))
      -- print(string.format("Reserved:          %s", HeaderData['Reserved']))
      -- print(string.format("ReceiverSWVersion: %s", HeaderData['ReceiverSWVersion']))
                                
      -- print(string.format("DeviceAddress:     %s", ResponseData['DeviceAddress']))
      -- print(string.format("RegisterAddress:   %s", ResponseData['RegisterAddress']))
      -- print(string.format("OperationStatus:   %s", ResponseData['OperationStatus']))
      -- print(string.format("OperationMode:     %s", ResponseData['OperationMode']))
      -- print(string.format("TransactionID:     %s", ResponseData['TransactionID']))
      -- print(string.format("READLENGTH:        %s", ResponseData['READLENGTH']))
      -- print(string.format("READDATA:          %s", ResponseData['READDATA']))                                

      return ResponseData
    end
 end
end 
  
--------------------------------------------------------------------------
-- Function to Read a Register:
--   Parameter In: 
--     1. iRegisterAddr_, the register address to read ( 0x00 - 0xFF ).   
--     2. iTransactionID_, the ID used for this transaction ( a 32 bit number ) 
--   Returns: 
--      nil if operation fails
--      the register value if operation succeeds.  
--------------------------------------------------------------------------
local function ReadRegister(iRegisterAddr_, iTransactionID_)  
   
  local sCommand = string.format('USERI2CREAD %02X 1 %02X 1 %5d\r', 
                   DeviceAddress, iRegisterAddr_, iTransactionID_)
  
  -- print("Issuing : ", sCommand)                        
  SocketSCOM1:send(sCommand)  
  assert(WaitForPrompt(SocketSCOM1))

  -- socket.sleep(1)
  local ResponseData = GetAndParseResponse()

  if ResponseData == nil then
    print("No USERI2CRESPONSEA log is received.")
    return nil
  end     

  if tonumber(string.format("0x%s", ResponseData['DeviceAddress'])) ~= tonumber(DeviceAddress) or
     tonumber(string.format("0x%s", ResponseData['RegisterAddress'])) ~= tonumber(iRegisterAddr_) or
     ResponseData['OperationStatus'] ~= "OK" or
     ResponseData['OperationMode'] ~= "READ" or
     tonumber(ResponseData['TransactionID']) ~= tonumber(iTransactionID_) then
    print("Response not correct.", ResponseData['DeviceAddress'], ResponseData['RegisterAddress'],
                                   ResponseData['OperationStatus'], ResponseData['OperationMode'],
                                   ResponseData['TransactionID'])
    return nil
  end

  if tonumber(ResponseData['READLENGTH']) ~= 1 then
    print("Invalid Read Response data. read ", ResponseData['READLENGTH'])
    return nil
  else
    return tonumber(string.format('0x%s', ResponseData['READDATA']))
  end
end

--------------------------------------------------------------------------
-- Function to Write a Register:
--   Parameter In: 
--     1. iRegisterAddr_, the register address to read (0x00 - 0xFF).
--     2. iRegisterData_, the value to write into this register   
--     3. iTransactionID_, the TID used for this transaction (a 32 bit number) 
--   Returns: 
--     nil if operation fails
--     the register value if operation succeeds.  
--------------------------------------------------------------------------
local function WriteRegister(iRegisterAddr_, iRegisterData_, iTransactionID_)  
   
  -- set direction command
  local sCommand = string.format('USERI2CWRITE %02X 1 %02X 1 %02X %5d\r', 
                   DeviceAddress, iRegisterAddr_, iRegisterData_, iTransactionID_)
                        
  -- print("Issuing :", sCommand)
  SocketSCOM1:send(sCommand)
  assert(WaitForPrompt(SocketSCOM1))

  -- socket.sleep(1)
  local ResponseData = GetAndParseResponse()
  
  if ResponseData == nil then
    print("No USERI2CRESPONSEA log is received.")
    return nil
  end
    
  if tonumber(string.format("0x%s", ResponseData['DeviceAddress'])) ~= tonumber(DeviceAddress) or
     tonumber(string.format("0x%s", ResponseData['RegisterAddress'])) ~= tonumber(iRegisterAddr_) or
     ResponseData['OperationStatus'] ~= "OK" or
     ResponseData['OperationMode'] ~= "WRITE" or
     tonumber(ResponseData['TransactionID']) ~= tonumber(iTransactionID_) then
     print("Response not correct.", ResponseData['DeviceAddress'], ResponseData['RegisterAddress'],
                                    ResponseData['OperationStatus'], ResponseData['OperationMode'],
                                    ResponseData['TransactionID'])
    return nil
  end
     
  if tonumber(ResponseData['READLENGTH']) ~= 0 then
    print("Invalid Response data. read ", ResponseData['READLENGTH'])
    return nil         
  end 

  -- Read the register value back to confirm
  if tonumber(iRegisterData_) == tonumber(ReadRegister(iRegisterAddr_,  iTransactionID_)) then
    return iRegisterData_
  else
    print("Return Back does not match", tonumber(iRegisterData_), 
                                        tonumber(ReadRegister(iRegisterAddr_,  iTransactionID_)))
  end  
end

--------------------------------------------------------------------------
-- Function to Display Bitwise Register Value. 
--   Inputs:
--     sDisplayName_,  Name to display
--     iSet_,  The Set value of the bit
--     iMask_, Bitmask to of which bits to display. Default is to display 
--             all bits. Non-masked bits will display as "-"
--------------------------------------------------------------------------
local function DisplayBitmap(sDisplayName_, iSet_, iMask_)
   
   local iMask = iMask_ or REG_VALUE_MASK
   -- TODO: Magic number
   local iBitmapLength = (#string.format("%02x", iSet_)) * 4
   local sDisplay={iBitmapLength}
      
   for i = 1, iBitmapLength do
      
      if ((iMask >> (iBitmapLength - i)) & 0x01) == 0x00 then
         sDisplay[i] = '-'
      elseif ((iSet_ >> (iBitmapLength - i)) & 0x01) == 0x01 then
         sDisplay[i] = '1'
      else
         sDisplay[i] = '0'
      end
      
   end

   print(string.format("%-15s: 7 6 5 4 3 2 1 0", "Bit Index"))
   io.write(string.format("%-15s: ", sDisplayName_))
                  
   for i = 1, #sDisplay do
      io.write(string.format("%s ", sDisplay[i]))
   end
   
   io.write("\n")
   
end

--************************************************************************
local SetDeviceAddressHELP = [[
   Function to Set the Device Address. 
     Inputs:
       iDeviceAddress_: The device address to set ( 0x00 - 0x7F ). 
                        For TotalPhase activity board, the default 
                        address is 0x38
     Returns:  The set address  
]]
--------------------------------------------------------------------------
local function SetDeviceAddress(iDeviceAddress_)
  
  DeviceAddress = iDeviceAddress_
  print(string.format("Device Address Set to:  %2x", DeviceAddress))
  return DeviceAddress
end

  
--************************************************************************
local GetDirectionHELP = [[
   Function to Get GPIO Direction:
     Returns: 
       nil if operation fails
       the direction state of all 8 ports if operation succeeds.  
]]
--------------------------------------------------------------------------
local function GetDirection()  
   
  local iRet = tonumber(ReadRegister(CONFIGURATION_REG,  TID_GETDIRECTION))
  print(string.format("-------- Direction Reg Value : 0x%2X --------", iRet))
  DisplayBitmap("Dir", iRet)
  return iRet      
end

--************************************************************************
local SetDirectionHELP = [[ 
   Function to Set the GPIO Direction (INPUT or OUTPUT):
     Parameter In:
       1. iBitMask_, the bits to control (0x00 - 0xFF). For example, if
                     we like to set GPIO 0 and 5, this value should be 0x21.  
       2. iDirection_, the direction to set (GPIO_DIR_IN, GPIO_DIR_OUT)
     Returns: 
       nil if operation fails
       the direction state of all 8 ports if operation succeed.    
]]
--------------------------------------------------------------------------
local function SetDirection(iBitMask_, iDirection_)
   
  if iBitMask_ > REG_VALUE_MASK then
    print("Invalid bitMask. This is a 8-bit IOExpander", iPinMask_)
    return nil      
  end
     
  if iDirection_ ~= GPIO_DIR_IN and iDirection_ ~= GPIO_DIR_OUT then
    print("Invalid direction", iDirection_)
    return nil      
  end   
   
  -- Read current direction 
  local iTemp = ReadRegister(CONFIGURATION_REG,  TID_GETDIRECTION)
   
  if iTemp == nil then
    print( "Read Current Port Direction Failed.")     
    return nil
  end 

  if iDirection_ == GPIO_DIR_IN then 
    iTemp = (iTemp & (~iBitMask_)) | (REG_VALUE_MASK & (iBitMask_))
  else
    iTemp = (iTemp) & (~iBitMask_)
  end
          
  if WriteRegister(CONFIGURATION_REG, iTemp, TID_SETDIRECTION) == nil then
     return nil
  end
  
  return GetDirection() 
end
     
--************************************************************************
local GetOutputLevelHELP = [[
   Function to Get GPIO OutPut Level:
     Returns: 
       nil if operation fails
       the output level of all 8 ports if operation succeeds.
       if port is configured as Input, the return data is meaningless
]]
--------------------------------------------------------------------------
local function GetOutputLevel()

  local iRet = ReadRegister(OUTPUT_PORT_REG, TID_GETOUTPUTLEVEL)
  local iDirection = ReadRegister(CONFIGURATION_REG,  TID_GETDIRECTION)
  
  print(string.format("-------- Output Reg Value : 0x%2X --------", iRet))   
  DisplayBitmap("Out", iRet, ~iDirection)
  return iRet
end

--************************************************************************
local SetOutputLevelHELP = [[ 
   Function to Set the GPIO Output Level (LOW or HIGH):
     Parameter In: 
       1. iBitMask_, the bits to control (0x00 - 0xFF). For example, if
                     we like to set GPIO 0 and 5, this value should be 0x21.  
       2. iLevel_, the output level to set (LEVEL_LOW, LEVEL_HIGH)
     Returns: 
       nil if operation fails
       the final output level of all 8 ports if operation succeeds.
]]    
--------------------------------------------------------------------------
local function SetOutputLevel(iBitMask_, iLevel_)

  if iBitMask_ > REG_VALUE_MASK then
    print("Invalid bitMask. This is a 8-bit IOExpander", iBitMask_)
    return nil      
  end
     
  if iLevel_ ~= GPIO_LOW and iLevel_ ~= GPIO_HIGH then
    print("Invalid Output Level", iLevel_)
    return nil      
  end   
   
  -- Read current output level 
  local iTemp = ReadRegister(OUTPUT_PORT_REG,  TID_GETDIRECTION)
   
  if iTemp == nil then
    print( "Read Current Port Output Failed.")     
    return nil
  end    

  if iLevel_ == GPIO_HIGH then 
     iTemp = (iTemp & (~iBitMask_)) | (REG_VALUE_MASK & (iBitMask_) )
  else
     iTemp = (iTemp & (~iBitMask_))
  end
    
  if WriteRegister(OUTPUT_PORT_REG, iTemp, TID_SETOUTPUTLEVEL) == nil then
    return nil
  end

  return GetOutputLevel()
end

--************************************************************************
local GetInputLevelHELP = [[ 
   Function to Get GPIO Input Level:
     Returns: 
       nil if operation fails
       the output level of all 8 ports if operation succeeds.
       if port is configured as output, the return bit data represented by that port 
       is meaningless 
]] 
--------------------------------------------------------------------------
local function GetInputLevel()

  local iRet = ReadRegister(INPUT_PORT_REG, TID_GETINPUTLEVEL)
  local iDirection = ReadRegister(CONFIGURATION_REG,  TID_GETDIRECTION)
   
  print(string.format("-------- Input Reg Value : 0x%2X --------", iRet))   
  DisplayBitmap("In ", iRet, iDirection)
   
  return iRet
end

--************************************************************************
local GetPolarityInversionHELP = [[ 
   Function to Get GPIO Polarity Inversion:
     Returns: 
       nil if operation fails
       the Polarity Inversion State of all 8 ports if operation succeeds.
]]  
--------------------------------------------------------------------------
local function GetPolarityInversion( )  
   
  local iRet = ReadRegister(POLARITY_INVERSION_REG, TID_GETPOLARITYINV)

  print(string.format("-------- Polarity Inversion Reg Value : 0x%2X --------", iRet))  
  DisplayBitmap("Pol", iRet)
  return iRet       
end
    
--************************************************************************
local SetPolarityInversionHELP = [[ 
   Function to Set the GPIO Polarity Inversion (INV or NINV):
     Parameter In: 
       1. iBitMask_, the bits to control ( 0x00 - 0xFF ). For example, if
                     we like to set GPIO 0 and 5, this value should be 0x21.  
       2. iPolarityInv_, the direction to set ( 0 - Output, 1 - Input )
     Returns: 
        nil if operation fails
        the polarity inversion state of all 8 ports if operation succeeds.
]]    
--------------------------------------------------------------------------
local function SetPolarityInversion(iBitMask_, iPolarityInversion_)
   
  if iBitMask_ > REG_VALUE_MASK then
    print("Invalid bitMask. This is a 8-bit IOExpander", iBitMask_)
    return nil      
  end
     
  if iPolarityInversion_ ~= GPIO_POLINV and iPolarityInversion_ ~= GPIO_POLNINV then
    print("Invalid polarity request", iPolarityInversion_)
    return nil      
  end   
   
  -- Read current polarity state 
  local iTemp = ReadRegister(POLARITY_INVERSION_REG, TID_GETPOLARITYINV)
   
  if iTemp == nil then
    print( "Read Current Port Direction Failed.")     
    return nil
  end  
  
  if iPolarityInversion_ == 1 then 
    iTemp = (iTemp & (~iBitMask_)) | (REG_VALUE_MASK & (iBitMask_) )
  else
    iTemp = (iTemp & (~iBitMask_))
  end
         
  -- set polarity state command
  if WriteRegister(POLARITY_INVERSION_REG, iTemp, TID_SETPOLARITYINV) == nil then
    return nil
  end
  
  return GetPolarityInversion()     
end


--******************************************************************************
local PCA9554 = {}

PCA9554.SetDeviceAddress     = SetDeviceAddress
PCA9554.GetDirection         = GetDirection 
PCA9554.SetDirection         = SetDirection
PCA9554.GetOutputLevel       = GetOutputLevel
PCA9554.SetOutputLevel       = SetOutputLevel 
PCA9554.GetInputLevel        = GetInputLevel
PCA9554.GetPolarityInversion = GetPolarityInversion
PCA9554.SetPolarityInversion = SetPolarityInversion

help = require("help")

help.register(PCA9554,                      PCA9554HELP)
help.register(PCA9554.SetDeviceAddress,     SetDeviceAddressHELP)
help.register(PCA9554.GetDirection,         GetDirectionHELP)
help.register(PCA9554.SetDirection,         SetDirectionHELP)
help.register(PCA9554.GetOutputLevel,       GetOutputLevelHELP)
help.register(PCA9554.SetOutputLevel,       SetOutputLevelHELP)
help.register(PCA9554.GetInputLevel,        GetInputLevelHELP)
help.register(PCA9554.GetPolarityInversion, GetPolarityInversionHELP)
help.register(PCA9554.SetPolarityInversion, SetPolarityInversionHELP)

return PCA9554

