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
-- ****************************************************************************/
--
--*******************************************************************************
-- Simple script to demonstrate debugging Lua on an OEM Receiver
-- 
-- Instructions for use:
--    - Setup ZeroBrane a host PC.  https://studio.zerobrane.com/
--    - Make this script available to both the PC and an OEM receiver
--    - Establish an Ethernet connection between the PC and the OEM receiver
--    - Start the ZeroBrane Debug Server on the host PC
--    - Start the script on the OEM receiver, passing in the IP address of the host PC.
--      The receiver command to do this is as follows, where x.x.x.x is the PC IP address.
--        LUA PROMPT "debugloop.lua x.x.x.x" 
-- 
--*******************************************************************************

DebugHostIP = arg[1]
  
LoopCount = 0
  
require('mobdebug').start(DebugHostIP)
  
while true do
  print(LoopCount)
  require("socket").sleep(1)
  LoopCount = LoopCount + 1
end