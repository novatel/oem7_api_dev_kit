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
 
local MCP23008 = {}
 
-- ***********************************************************************
local MCP23008HELP = [[
  MICROCHIP MCP23008 8-bit I2C-bus GPIO Expander Driver Script
   
  Public Methods:
    . SetDeviceAddress
    . GetDirection 
    . SetDirection
    . GetPolarityInversion
    . SetPolarityInversion
    . GetInterruptOnChange
    . SetInterruptOnChange
    . GetDefaultValue
    . SetDefaultValue
    . GetInterruptConfig
    . SetInterruptConfig
    . GetConfiguration
    . SetConfiguration
    . GetInterruptFlags
    . GetInterruptCapture
    . GetInputLevel
    . GetPortLevel
    . GetOutputLevel
    . SetOutputLevel
    . GetOutputLatch
]]
-- *********************************************************************** 

--------------------------------------------------------------------------
-- Used for ZeroBrane Studio
-------------------------------------------------------------------------- 
local base_arg = 1
base_arg = base_arg + 1
--DebugHostIP = arg[1]
DebugHostIP = "198.161.68.238"
--require('mobdebug').start(DebugHostIP)

--------------------------------------------------------------------------
-- Socket to talk to SCOM through UDP
--------------------------------------------------------------------------
SocketLib = require("socket")
scom = require("scom")
SocketSCOM1 = SocketLib.udp()

assert(SocketSCOM1:setsockname("*",0))
assert(SocketSCOM1:setpeername("127.0.0.1",scom.GetSCOMPort(1)))
assert(SocketSCOM1:settimeout(3))

--------------------------------------------------------------------------
-- GPIO attribute Macros matching to MCP23008 datasheet.  
--------------------------------------------------------------------------

local GPIO_HIGH                     = 1
local GPIO_LOW                      = 0
  
MCP23008.GPIO_HIGH                  = GPIO_HIGH
MCP23008.GPIO_LOW                   = GPIO_LOW
  
-- Direction  
MCP23008.GPIO_DIR_IN                = GPIO_HIGH
MCP23008.GPIO_DIR_OUT               = GPIO_LOW
  
-- Polarity Inversion 
MCP23008.GPIO_POL_INV               = GPIO_HIGH
MCP23008.GPIO_POL_NINV              = GPIO_LOW

  
-- Interupt on Change enable  
MCP23008.GPIO_IOC_EN                = GPIO_HIGH
MCP23008.GPIO_IOC_DIS               = GPIO_LOW
  
-- Default Value Enable 
MCP23008.GPIO_IOC_DEF_VAL           = GPIO_HIGH
MCP23008.GPIO_IOC_CHNG_VAL          = GPIO_LOW
  
-- Input Pullup Enable  
MCP23008.GPIO_PULLUP_EN             = GPIO_HIGH
MCP23008.GPIO_PULLUP_DIS            = GPIO_LOW


local sRegisterDisplayFormat = "-------- %s Reg Value : 0x%02X --------"
  
--------------------------------------------------------------------------
-- The device address of the I2C device,
--------------------------------------------------------------------------
-- MESSAGE FORMAT [0] [1] [0] [0] [A2] [A1] [A0] [R/W]
-- The device says that the device address is 0x40, with the last bit changing for 
-- read or write. This is handled by the USERI2C receiver commands, so the address
-- needs to be shifted over by one and becomres 0x20
local DeviceAddress              =  0x20
local REG_VALUE_MASK             =  0xFF
local CONFIG_REG_MASK            =  0x36

--------------------------------------------------------------------------
-- The register addresses for the MCP23008 GPIO Expander
--------------------------------------------------------------------------
local IO_DIRECTION_REG           =  0x00
local POLARITY_INVERSION_REG     =  0x01
local INTERRUPT_ON_CHANGE_REG    =  0x02
local DEFAULT_VALUE_REG          =  0x03
local INTERRUPT_CONTROL_REG      =  0x04
local CONFIGURATION_REG          =  0x05
local PULL_UP_CONFIG_REG         =  0x06
local INTERRUPT_FLAG_REG         =  0x07
local INTERRUPT_CAPTURE_REG      =  0x08
local IO_PORT_REG                =  0x09
local OUTPUT_LATCH_REG           =  0x0A

--------------------------------------------------------------------------
-- The register names for the MCP23008 GPIO Expander
--------------------------------------------------------------------------
local registers = {
      [IO_DIRECTION_REG]         =  "Direction",
      [POLARITY_INVERSION_REG]   =  "Input Polarity",
      [INTERRUPT_ON_CHANGE_REG]  =  "Interrupt On Change",
      [DEFAULT_VALUE_REG]        =  "Default Value",
      [INTERRUPT_CONTROL_REG]    =  "Interrupt Control",
      [CONFIGURATION_REG]        =  "Configuration",
      [PULL_UP_CONFIG_REG]       =  "Pull-Up Configuration",
      [INTERRUPT_FLAG_REG]       =  "Interrupt Flag",
      [INTERRUPT_CAPTURE_REG]    =  "Interrupt Capture",
      [IO_PORT_REG]              =  "GPIO Port",
      [OUTPUT_LATCH_REG]         =  "Output Latch"
                  }
--------------------------------------------------------------------------
-- TransactionID for each operation is determined by the nature of the 
-- operation (read or write) and the register it is operating on. In
-- hexadecimal, the TxID looks like*:
--
--    [3]   :  0 for reading, 1 for writing
--    [2]   :  1 for reading, 0 for writing
--    [1]   :  register ID hex digit 1
--    [0]   :  register ID hex digit 0
--
--    *  This TxID is arbitrary and does not affect the performance of the
--       receiver
--------------------------------------------------------------------------

local READ_REGISTER_MASK    =  (0x1 << 8)
local WRITE_REGISTER_MASK   =  (0x1 << 12)

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
        --print("Prompt Received: ",Prompt)
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
    HeaderData.Message = HeaderIter()
    HeaderData.Port = HeaderIter()
    HeaderData.Sequence = HeaderIter()
    HeaderData.IdleTime = HeaderIter()
    HeaderData.TimeStatus = HeaderIter()
    HeaderData.Week = HeaderIter()
    HeaderData.Second = HeaderIter()
    HeaderData.ReceiverStatus = HeaderIter()
    HeaderData.Reserved = HeaderIter()
    HeaderData.ReceiverSWVersion = HeaderIter()
  
    -- Split the data into its elements.
    -- Create a table for the USERI2CRESPONSEA Data and assign the
    -- data fields into that table.
    local DataIter = LOGData:gmatch("([^,]-)[,%*]")
  
    ResponseData = {}
    ResponseData.Header = HeaderData
    ResponseData.DeviceAddress = DataIter()
    ResponseData.RegisterAddress = DataIter()
    ResponseData.OperationStatus = DataIter()
    ResponseData.OperationMode = DataIter()
    ResponseData.TransactionID = DataIter()
    ResponseData.READLENGTH = DataIter()
    ResponseData.READDATA = DataIter()
  
    return ResponseData 
  end
end
--------------------------------------------------------------------------
-- Prints message response from receiver
--   Parameter In: 
--     1. PrintResponseData_: response data received from 
--        "ParseUSERI2CRESPONSEA"
--------------------------------------------------------------------------
function PrintResponseData(ResponseData_)

  local HeaderData = ResponseData_.Header
  
  print(string.format("Message:           %s", HeaderData.Message))
  print(string.format("Port:              %s", HeaderData.Port))    
  print(string.format("Sequence:          %s", HeaderData.Sequence))
  print(string.format("IdleTime:          %s", HeaderData.IdleTime))
  print(string.format("TimeStatus:        %s", HeaderData.TimeStatus))
  print(string.format("Week:              %s", HeaderData.Week))
  print(string.format("Second:            %s", HeaderData.Second))
  print(string.format("ReceiverStatus:    %s", HeaderData.ReceiverStatus))
  print(string.format("Reserved:          %s", HeaderData.Reserved))
  print(string.format("ReceiverSWVersion: %s", HeaderData.ReceiverSWVersion))
  
  print(string.format("DeviceAddress:     %s", ResponseData_.DeviceAddress))
  print(string.format("RegisterAddress:   %s", ResponseData_.RegisterAddress))
  print(string.format("OperationStatus:   %s", ResponseData_.OperationStatus))
  print(string.format("OperationMode:     %s", ResponseData_.OperationMode))
  print(string.format("TransactionID:     %s", ResponseData_.TransactionID))
  print(string.format("READLENGTH:        %s", ResponseData_.READLENGTH))
  print(string.format("READDATA:          %s", ResponseData_.READDATA))
   
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
      local HeaderData =  ResponseData.Header
      --PrintResponseData(ResponseData)
      return ResponseData
    end
  end  
end 
--------------------------------------------------------------------------
-- Function to Read a Register:
--   Parameter In: 
--     1. iRegisterAddr_, the register address to read ( 0x00 - 0xFF )
--   Returns: 
--      nil if operation fails
--      the register value if operation succeeds.  
--------------------------------------------------------------------------
local function ReadRegister(iRegisterAddr_)

  local iTransactionID = iRegisterAddr_ | READ_REGISTER_MASK
  
  -- Create command string o send to the receiver
  local sCommand = string.format('USERI2CREAD %02X 1 %02X 1 %5d\r',
                                  DeviceAddress, iRegisterAddr_, iTransactionID)
  
  --print("Issuing : ", sCommand)
  SocketSCOM1:send(sCommand)
  assert(WaitForPrompt(SocketSCOM1))
  
  -- socket.sleep(1)
  local ResponseData = GetAndParseResponse()
  
  if ResponseData == nil then
    print("No USERI2CRESPONSEA log is received.")
    return nil
  end
  
  if tonumber(string.format("0x%s", ResponseData.DeviceAddress)) ~= tonumber(DeviceAddress) or
      tonumber(string.format("0x%s", ResponseData.RegisterAddress)) ~= tonumber(iRegisterAddr_) or
      ResponseData.OperationStatus ~= "OK" or
      ResponseData.OperationMode ~= "READ" or
      tonumber(ResponseData.TransactionID) ~= tonumber(iTransactionID) then
      print("Response not correct.", ResponseData.DeviceAddress, ResponseData.RegisterAddress,
                                      ResponseData.OperationStatus, ResponseData.OperationMode,
                                      ResponseData.TransactionID)
     return nil
  end
  
  if tonumber(ResponseData.READLENGTH) ~= 1 then
    print("Invalid Read Response data. read ", ResponseData.READLENGTH)
    return nil
  else
    return tonumber(string.format('0x%s', ResponseData.READDATA))
  end
end


--------------------------------------------------------------------------
-- Function to Write a Register:
--   Parameter In: 
--     1. iRegisterAddr_, the register address to read (0x00 - 0xFF).
--     2. iRegisterData_, the value to write into this register
--   Returns: 
--     nil if operation fails
--     the register value if operation succeeds.  
--------------------------------------------------------------------------
local function WriteRegister(iRegisterAddr_, iRegisterData_, bVerify_)
  
  local bVerify = bVerify_ or false

  local iTransactionID = iRegisterAddr_ | WRITE_REGISTER_MASK
  
  -- Create command string o send to the receiver
  local sCommand = string.format('USERI2CWRITE %02X 1 %02X 1 %02X %5d\r', 
                    DeviceAddress, iRegisterAddr_, iRegisterData_, iTransactionID)
                          
  --print("Issuing :", sCommand)
  SocketSCOM1:send(sCommand)
  assert(WaitForPrompt(SocketSCOM1))
  
  -- socket.sleep(1)
  local ResponseData = GetAndParseResponse()
  
  if ResponseData == nil then
    print("No USERI2CRESPONSEA log is received.")
    return nil
  end
    
  if tonumber(string.format("0x%s", ResponseData.DeviceAddress)) ~= tonumber(DeviceAddress) or
      tonumber(string.format("0x%s", ResponseData.RegisterAddress)) ~= tonumber(iRegisterAddr_) or
      ResponseData.OperationStatus ~= "OK" or
      ResponseData.OperationMode ~= "WRITE" or
      tonumber(ResponseData.TransactionID) ~= tonumber(iTransactionID) then
      print("Response not correct.", ResponseData.DeviceAddress, ResponseData.RegisterAddress,
                                        ResponseData.OperationStatus, ResponseData.OperationMode,
                                        ResponseData.TransactionID)
    return nil
  end
    
  if tonumber(ResponseData.READLENGTH) ~= 0 then
    print("Invalid Response data. read ", ResponseData.READLENGTH)
    return nil
  end
  
  if bVerify_ then
    -- Read the register value back to confirm
    if tonumber(iRegisterData_) == tonumber(ReadRegister(iRegisterAddr_,  iTransactionID)) then
        return iRegisterData_
    else
        print("Return Back does not match", tonumber(iRegisterData_), 
                                            tonumber(ReadRegister(iRegisterAddr_,  iTransactionID)))
        return nil
    end
  end
  
  return iRegisterData_
  
end

--------------------------------------------------------------------------
--    Function to Display Bitwise Register Value. 
--    Parameter In:
--       sDisplayName_,  Name to display
--       iSet_,  The Set value of the bit
--       iMask_, Bitmask to of which bits to display. Default is to display 
--                all bits. Non-masked bits will display as "-"
--------------------------------------------------------------------------
local function DisplayBitmap(sDisplayName_, iSet_, iMask_)
  
  local iMask = iMask_ or REG_VALUE_MASK
  
  -- Counting the number of four-bit hex digits
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
--------------------------------------------------------------------------
--       Function to Set a register value and print it
--       Parameter In:
--          iRegID_, The ID of the Register to read
--          iBitMask_, Any bitmask used for displaying the data
--          iLevel_, The level to set the masked bits
--       Returns:  
--          nil if operation fails
--          register state if operation suceeds
--------------------------------------------------------------------------
local function SetRegisterValue(iRegID_, iBitMask_, iLevel_)
  
  if (iBitMask_ & ~REG_VALUE_MASK) ~= 0 then
    print(string.format("Invalid bitMask. This is a 8-bit IOExpander: 0x%02x", iBitMask_))
    return nil
  end
  
  if iLevel_ ~= GPIO_HIGH and iLevel_ ~= GPIO_LOW then
    print("Invalid level. Must be 1 or 0.", 
          iLevel_)
    return nil
  end
  
  -- Read current output level
  local iTemp = ReadRegister(iRegID_)

  if iTemp == nil then
    print( "Read Current Port Output Failed.")
    return nil
  end
  
  -- Write changes to register value
  if iLevel_ == GPIO_HIGH then
    iTemp = (iTemp | iBitMask_)
  else
    iTemp = (iTemp & (~iBitMask_))
  end
  
  -- Write back to register
  return WriteRegister(iRegID_, 
                      iTemp)
  
end
--************************************************************************
local SetDeviceAddressHELP = [[
  Function to Set the Device Address.
  Parameter In:
    iDeviceAddress_: The device address to set ( 0x00 - 0x7F ).
                      For PICkit activity board, the default
                      address is 0x20 (0x40 shifted by one place)
  Returns:  The set address
]]
--------------------------------------------------------------------------
function MCP23008:SetDeviceAddress(iDeviceAddress_)
  DeviceAddress = iDeviceAddress_
  print(string.format("Device Address Set to:  %2x", DeviceAddress))
  return DeviceAddress
end
--************************************************************************
local GetDirectionHELP = [[
  Function to Get GPIO Direction 
    1 = INPUT
    0 = OUTPUT
  Returns:
    nil if operation fails
    the direction state of all 8 ports if operation succeeds.
]]
--------------------------------------------------------------------------
function MCP23008:GetDirection()
  
  local iRet = ReadRegister(IO_DIRECTION_REG)
  print(string.format(sRegisterDisplayFormat, 
                      registers[IO_DIRECTION_REG], 
                      iRet))
  DisplayBitmap("Direction", 
                iRet)
  return iRet
end
--************************************************************************
local SetDirectionHELP = [[
  Function to Set the GPIO Direction:
    1 = INPUT
    0 = OUTPUT
  Parameter In:
    1. iBitMask_, the bits to control (0x00 - 0xFF). For example, if
                    we like to set GPIO 0 and 5, this value should be 0x21.
    2. iDirection_, the direction to set (GPIO_DIR_IN, GPIO_DIR_OUT)
  Returns:
    nil if operation fails
    the direction state of all 8 ports if operation succeed.
]]
--------------------------------------------------------------------------
function MCP23008:SetDirection(iBitMask_, iDirection_)
  return SetRegisterValue(IO_DIRECTION_REG, 
                          iBitMask_, 
                          iDirection_)
end
--************************************************************************
local GetPolarityInversionHELP = [[
  Function to Get GPIO Polarity Inversion:
    1 = input signal will be inverted in IO_PORT_REG
    0 = input signal will not be inverted
  Returns: 
    nil if operation fails
    the Polarity Inversion State of all 8 ports if operation succeeds.
    if port is configured as output, the return bit data represented by that port 
    is meaningless
]]
--------------------------------------------------------------------------
function MCP23008:GetPolarityInversion( )  

  local iRet = ReadRegister(POLARITY_INVERSION_REG)
  print(string.format(sRegisterDisplayFormat, 
                      registers[POLARITY_INVERSION_REG], 
                      iRet))
  DisplayBitmap("Polarity", 
                iRet)
  return iRet       
end
--************************************************************************
local SetPolarityInversionHELP = [[
  Function to Set the GPIO Polarity Inversion:
    1 = input signal will be inverted in IO_PORT_REG
    0 = input signal will not be inverted
  Parameter In: 
    1. iBitMask_, the bits to control ( 0x00 - 0xFF ). For example, if
                    we like to set GPIO 0 and 5, this value should be 0x21.  
    2. iConfigLevel_, the value to set the masked bits
  Returns: 
    nil if operation fails
    the polarity inversion state of all 8 ports if operation succeeds.
]]
--------------------------------------------------------------------------
function MCP23008:SetPolarityInversion(iBitMask_, iConfigLevel_)
  return SetRegisterValue(POLARITY_INVERSION_REG,
                          iBitMask_,
                          iConfigLevel_)
end
--************************************************************************
local GetInterruptOnChangeHELP = [[
  Function to get the Interrupt on Change register
    1 - Enable IOC event on pin
    0 - Disable IOC event on pin
  Returns:
    nil if operation fails
    interrupt on change register state if operation succeeds
]]
--------------------------------------------------------------------------
function MCP23008:GetInterruptOnChange()
  
  local iRet = ReadRegister(INTERRUPT_ON_CHANGE_REG)
  print(string.format(sRegisterDisplayFormat, 
                      registers[INTERRUPT_ON_CHANGE_REG], 
                      iRet))
  DisplayBitmap("IntOnChange", 
                iRet)
  return iRet
end
--************************************************************************
local SetInterruptOnChangeHELP = [[
  Function to set the Interrupt on Change register
    1 - Enable IOC event on pin
    0 - Disable IOC event on pin
  Parameter In: 
    1. iBitMask_, the bits to control ( 0x00 - 0xFF ). For example, if
                    we like to set GPIO 0 and 5, this value should be 0x21.  
    2. iConfigLevel_, the value to set the masked bits
  Returns:
    nil if operation fails
    interrupt on change register state if operation succeeds
]]
--------------------------------------------------------------------------
function MCP23008:SetInterruptOnChange(iBitMask_, iConfigLevel_)
  return SetRegisterValue(INTERRUPT_ON_CHANGE_REG, 
                          iBitMask_, 
                          iConfigLevel_)
end
--************************************************************************
local GetDefaultValueHELP = [[
  Function to get the Default Value register
    if Interrupt on Change is enabled and the Interrupt Control register
    is set, an interrupt will be triggered if the pin value is opposite 
    this register value
  Returns:
    nil if operation fails
    default value register state if operation succeeds
]]
--------------------------------------------------------------------------
function MCP23008:GetDefaultValue()
  
  local iRet = ReadRegister(DEFAULT_VALUE_REG)
  print(string.format(sRegisterDisplayFormat, 
                      registers[DEFAULT_VALUE_REG], 
                      iRet))
  DisplayBitmap("Default", 
                iRet)
  return iRet
end
--************************************************************************
local SetDefaultValueHELP = [[
  Function to set the Default Value register
    if Interrupt on Change is enabled and the Interrupt Control register
    is set, an interrupt will be triggered if the pin value is opposite 
    this register value
  Returns:
    nil if operation fails
    default value register state if operation succeeds
]]
--------------------------------------------------------------------------
function MCP23008:SetDefaultValue(iBitMask_, iConfigLevel_)
  return SetRegisterValue(DEFAULT_VALUE_REG,
                          iBitMask_,
                          iConfigLevel_)
end
--************************************************************************
local GetInterruptConfigHELP = [[
  Function to get the Interrupt Control register value
    1 - Default Value register is used for the Interrupt on Change comparison
    0 - Previous pin value is used for the Interrupt on Change comparison
  Returns:
    nil if operation fails
    interrupt control register state if operation succeeds
]]
--------------------------------------------------------------------------
function MCP23008:GetInterruptConfig()
  local iRet = ReadRegister(INTERRUPT_CONTROL_REG)
  print(string.format(sRegisterDisplayFormat, 
                      registers[INTERRUPT_CONTROL_REG], 
                      iRet))
  DisplayBitmap("IntConfig", 
                iRet)
  return iRet
end
--************************************************************************
local SetInterruptConfigHELP = [[
  Function to get the Interrupt Control register value
    1 - Default Value register is used for the Interrupt on Change comparison
    0 - Previous pin value is used for the Interrupt on Change comparison
  Parameter In: 
    1. iBitMask_, the bits to control ( 0x00 - 0xFF ). For example, if
                    we like to set GPIO 0 and 5, this value should be 0x21.  
    2. iConfigLevel_, the value to set the masked bits
  Returns:
    nil if operation fails
    interrupt control register state if operation succeeds
]]
--------------------------------------------------------------------------
function MCP23008:SetInterruptConfig(iBitMask_, iConfigLevel_)
  return SetRegisterValue(INTERRUPT_CONTROL_REG,
                          iBitMask_,
                          iConfigLevel_)
end
--*****************************************************************************
local GetConfigurationHELP = [[
  Function to Get MCP23008 Configuration register:
    Bit values are:
    Unused   :  X
    Unused   :  X
    SEQOP    :  Sequential operation toggle (active low). NovAtel USERI2CWRITE command doesn't seem to support this
    DISSLW   :  Slew rate control for SDA output toggle (active low)
    Usused   :  X
    ODR      :  Configures INT pins as open-drain output, overrides INTPOL bit if active (active high)
    INTPOL   :  Sets polarity of the INT output pin
    Unused   :  X
    
  Returns:
    nil if operation fails
    The configuration register state if operation succeeds
]]
--------------------------------------------------------------------------
function MCP23008:GetConfiguration()
  
  local iRet = ReadRegister(CONFIGURATION_REG)
  
  print(string.format(sRegisterDisplayFormat, 
                      registers[CONFIGURATION_REG], 
                      iRet))
  DisplayBitmap("Config",
                iRet,
                CONFIG_REG_MASK)
  return iRet
  
end
--************************************************************************
local SetConfigurationHELP = [[
  Function to Set MCP23008 Configuration register:
    Bit values are:
    Unused   :  X
    Unused   :  X
    SEQOP    :  Sequential operation toggle (active low). NovAtel USERI2CWRITE command doesn't seem to support this
    DISSLW   :  Slew rate control for SDA output toggle (active low)
    Usused   :  X
    ODR      :  Configures INT pins as open-drain output, overrides INTPOL bit if active (active high)
    INTPOL   :  Sets polarity of the INT output pin
    Unused   :  X
  Parameter In:
    1. iBitMask_, the bits to control ( 0x00 - 0xFF ). For example, if
                    we like to set GPIO 0 and 5, this value should be 0x21.  
    2. iConfig_, the value to set the masked bits
    
  Returns:
    nil if operation fails
    The configuration register state if operation succeeds
]]
--------------------------------------------------------------------------
function MCP23008:SetConfiguration(iBitMask_, iConfigLevel_)
  
  return SetRegisterValue(CONFIGURATION_REG,
                          iBitMask_,
                          iConfigLevel_)
  
end
--************************************************************************
local GetPullupConfigHELP = [[
  Function Gets the pull-up resistor configuration register
    1 - Pull-up enabled
    0 - Pull-up disabled
  Returns:
    null if operation fails
    the pull-up configuration register state if operation succeeds
]]
--------------------------------------------------------------------------
function MCP23008:GetPullupConfig()
  
  local iRet = ReadRegister(PULL_UP_CONFIG_REG)
  
  print(string.format(sRegisterDisplayFormat, 
                      registers[PULL_UP_CONFIG_REG], 
                      iRet))
  DisplayBitmap("Pull-ups",
                iRet)
  return iRet
end
--************************************************************************
local SetPullupConfigHELP = [[
  Function Sets the pull-up resistor configuration register
    1 - Pull-up enabled
    0 - Pull-up disabled
  Parameter In:
    1. iBitMask_, the bits to control ( 0x00 - 0xFF ). For example, if
                    we like to set GPIO 0 and 5, this value should be 0x21.  
    2. iConfig_, the value to set the masked bits
  Returns:
    null if operation fails
    the pull-up configuration register state if operation succeeds
]]
--------------------------------------------------------------------------
function MCP23008:SetPullupConfig(iBitMask_, iConfigLevel_)
  
  return SetRegisterValue(PULL_UP_CONFIG_REG,
                          iBitMask_,
                          iConfigLevel_)
end
--************************************************************************
local GetInterruptFlagsHELP = [[
  Function gets the interrupt flag register. Shows all pins that have 
    triggered an interrupt
    1 - interrupt triggered on pin
    0 - no interrupt triggered on pin
  Returns:
    null if operation fails
    interrut flag register state if operation succeeds
]]
--------------------------------------------------------------------------
function MCP23008:GetInterruptFlags()
  
  local iRet = ReadRegister(INTERRUPT_FLAG_REG)
  print(string.format(sRegisterDisplayFormat, 
                      registers[INTERRUPT_FLAG_REG], 
                      iRet))
  DisplayBitmap("IntFlags",
                iRet)
  return iRet
end
--************************************************************************
local GetInterruptCaptureHELP = [[
  Function to Get Interrupt Capture register
    captures the state of the port when an interrupt occurs. The register
    value will be preserved until the interrupt is cleared. If more 
    interrupts occur before clearing the first one, this register will not
    change, although the interrupt flags register will.
]]
--------------------------------------------------------------------------
function MCP23008:GetInterruptCapture()
  
  local iRet = ReadRegister(INTERRUPT_CAPTURE_REG)
  print(string.format(sRegisterDisplayFormat, 
                      registers[INTERRUPT_CAPTURE_REG], 
                      iRet))
  DisplayBitmap("IntCap",
                iRet)
  return iRet
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
function MCP23008:GetInputLevel()

  local iRet = ReadRegister(IO_PORT_REG)
  local iDirection = ReadRegister(IO_DIRECTION_REG)
  print(string.format(sRegisterDisplayFormat, 
                      registers[IO_PORT_REG], 
                      iRet))
  DisplayBitmap("Input",
                iRet,
                iDirection)
  return iRet
end
--************************************************************************
local GetPortLevelHELP = [[
  Function to Get GPIO Port Levels:
  Returns: 
    nil if operation fails
    the current level of all 8 ports if operation succeeds, input or output
    also shows which pins are set to output.
]]
--------------------------------------------------------------------------
function MCP23008:GetPortLevel()
   
  local iRet = ReadRegister(IO_PORT_REG)
  local iDirection = ReadRegister(IO_DIRECTION_REG)
  print(string.format(sRegisterDisplayFormat, 
                      registers[IO_PORT_REG], 
                      iRet))
  DisplayBitmap("All Ports",
                iRet)
  DisplayBitmap("Direction:",
                iDirection)
  return iRet
end
--************************************************************************
local GetOutputLevelHELP = [[
  Function to Get the Previously Set GPIO Output Latch Levels:
    Returns: 
      nil if operation fails
      the output level of all 8 ports if operation succeeds.
      If a pin is configured as Input, that pin's return data is meaningless.
]]
--------------------------------------------------------------------------
function MCP23008:GetOutputLevel()
  local iRet = ReadRegister(IO_PORT_REG)
  local iDirection = ReadRegister(IO_DIRECTION_REG)
  print(string.format(sRegisterDisplayFormat, 
                      registers[IO_PORT_REG], 
                      iRet))
  DisplayBitmap("Output",
                iRet,
                ~iDirection)
  return iRet
end


--************************************************************************
local SetOutputLevelHELP = [[
  Function to Set the GPIO Output Level (LOW or HIGH):
  Parameter In:
    1. iBitMask_, the bits to control (0x00 - 0xFF). For example, if
                    we want to set GPIO 0 and 5, this value should be 0x21.
    2. iLevel_, the output level to set (LEVEL_LOW, LEVEL_HIGH)
    
    If pin is set to Input, Output latch will change but not be reflected 
    on the port.
    
  Returns:
    nil if operation fails
    the final output level of all 8 ports if operation succeeds.
]]
--------------------------------------------------------------------------
function MCP23008:SetOutputLevel(iBitMask_, iLevel_)

  return SetRegisterValue(OUTPUT_LATCH_REG, 
                          iBitMask_,
                          iLevel_)
end
--************************************************************************
local GetOutputLatchHELP = [[
  Function to Get the Output Latch setting for Output Pins:
    
    Returns: 
        nil if operation fails
        the set output level of output pins if operation succeeds.
        if pin is configured as input, the return bit data represented by that port 
        is meaningless 
]]
--------------------------------------------------------------------------
function MCP23008:GetOutputLatch()
  
  local iRet = ReadRegister(OUTPUT_LATCH_REG)
  local iDirection = ReadRegister(IO_DIRECTION_REG)

  print(string.format(sRegisterDisplayFormat, 
                      registers[OUTPUT_LATCH_REG], 
                      iRet))
  DisplayBitmap("OutputLatches",
                iRet)
  return iRet

end
--************************************************************************

help = require("help")

help.register(MCP23008,                      MCP23008HELP)
help.register(MCP23008.SetDeviceAddress,     SetDeviceAddressHELP)
help.register(MCP23008.GetDirection,         GetDirectionHELP)
help.register(MCP23008.SetDirection,         SetDirectionHELP)
help.register(MCP23008.GetPolarityInversion, GetPolarityInversionHELP)
help.register(MCP23008.SetPolarityInversion, SetPolarityInversionHELP)
help.register(MCP23008.GetInterruptOnChange, GetInterruptOnChangeHELP)
help.register(MCP23008.SetInterruptOnChange, SetInterruptOnChangeHELP)
help.register(MCP23008.GetDefaultValue,      GetDefaultValueHELP)
help.register(MCP23008.SetDefaultValue,      SetDefaultValueHELP)
help.register(MCP23008.GetInterruptConfig,   GetInterruptConfigHELP)
help.register(MCP23008.SetInterruptConfig,   SetInterruptConfigHELP)
help.register(MCP23008.GetConfiguration,     GetConfigurationHELP)
help.register(MCP23008.SetConfiguration,     SetConfigurationHELP)
help.register(MCP23008.GetInterruptFlags,    GetInterruptFlagsHELP)
help.register(MCP23008.GetInterruptCapture,  GetInterruptCaptureHELP)
help.register(MCP23008.GetInputLevel,        GetInputLevelHELP)
help.register(MCP23008.GetPortLevel,         GetPortLevelHELP)
help.register(MCP23008.GetOutputLevel,       GetOutputLevelHELP)
help.register(MCP23008.SetOutputLevel,       SetOutputLevelHELP)
help.register(MCP23008.GetOutputLatch,       GetOutputLatchHELP)

return MCP23008