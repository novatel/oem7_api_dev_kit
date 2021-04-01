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
-- Script to demonstrate how to setup a tunnel between an SCOM and COM port
-- 
--******************************************************************************
 
SocketLib = require("socket")

-- Use SCOM1 for commands and logs
local SocketSCOM1 = SocketLib.udp()
-- Use SCOM2 for the tunnel
local SocketSCOM2 = SocketLib.udp()

-- Setup the sockets
TargetIP = "127.0.0.1"

assert(SocketSCOM1:setsockname("*",0))
assert(SocketSCOM1:setpeername(TargetIP,scom.GetSCOMPort(1)))
assert(SocketSCOM1:settimeout(3))

assert(SocketSCOM2:setsockname("*",0))
assert(SocketSCOM2:setpeername(TargetIP,scom.GetSCOMPort(2)))
-- No time out on SCOM2

-- Create function to send a command and wait for a prompt
-- Returns the prompt on success, nil on failure
function WaitForPrompt(SocketSCOM_)
  while true do
    local Buffer = SocketSCOM_:receive()
    if Buffer == nil then 
      print("Timed out")
      return nil
    end
    
    local Start,Stop,Prompt = Buffer:find("(%[SCOM%d%])")
    
    if Prompt ~= nil then
      print("Prompt Received: ",Prompt)
      return Prompt
    end    
  end
  
  return nil  
end

-- Send a one-byte packet to SCOM2 so that it knows the IP address of the machine
-- running the Lua script
SocketSCOM2:send("\r")  

-- Setup the tunnel on the SCOM2 side
SocketSCOM1:send("interfacemode scom2 tcom2 none\r")
assert(WaitForPrompt(SocketSCOM1))

-- Setup the tunnel on the COM2 side
SocketSCOM1:send("interfacemode com2 tscom2 none\r")
assert(WaitForPrompt(SocketSCOM1))
SocketLib.sleep(1)

-- Setup an echo loop
-- This will have the effect that if the user enters characters
-- on COM2, they will be echoed back
while true do
 -- Receive characters from SCOM2
  local Buffer = SocketSCOM2:receive(1)
  print ("Buffer: ",Buffer)
 -- Echo those characters back to SCOM2
  SocketSCOM2:send(Buffer)  
end
