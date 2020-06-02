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
--
--******************************************************************************
-- Simple script to demonstrate SoftLoad on Lua.  
--
-- NOTE: This script is intended to be run on a PC, not the receiver.
-- 
--******************************************************************************


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

----------------------------------------------------------------------------------------
TargetIP = arg[1]
SoftLoadFileName = arg[2]

-- Use SCOM1 for commands and logs
local SocketSCOM1 = require("socket").udp()

assert(SocketSCOM1:setsockname("*",0))
assert(SocketSCOM1:setpeername(TargetIP,require("scom").GetSCOMPort(1)))
assert(SocketSCOM1:settimeout(3))

-- Start the softload process
SocketSCOM1:send("softloadreset\r")
assert(WaitForPrompt(SocketSCOM1))

for Line in io.lines(SoftLoadFileName) do 
  print("Sending line: " .. Line)
  SocketSCOM1:send("softloadsrec \"" .. Line .. "\"\r")
  
 -- TODO Interpret the data in the S3 records and combine into SOFTLOADDATA commands.
  
  assert(WaitForPrompt(SocketSCOM1))
end

SocketSCOM1:send("softloadcommit\r")
assert(WaitForPrompt(SocketSCOM1))

-- TODO Monitor the SOFTLOADSTATUS log for the COMPLETE status