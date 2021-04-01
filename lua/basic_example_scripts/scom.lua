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

Socket = require("socket")

local SCOMPort = {}
SCOMPort[1] = 49154
SCOMPort[2] = 49155
SCOMPort[3] = 49156
SCOMPort[4] = 49157
local SCOMPortNumMax = 4

--******************************************************************************
-- Open an SCOM socket
-- Inputs:
--   iIPaddr_     the IP address to bind the socket to
--   iSCOMPort_   the SCOM Port number to bind the socket to
--   iTimeoutSec_ optional, the number of seconds for timeout on blocking operations
-- Returns:
--   The connected socket object 
--******************************************************************************
local function OpenSCOM(iIPaddr_, iSCOMPort_, iTimeoutSec_)
  -- UDP Socket
   local log_sk = Socket.udp()
  -- Socket name
   assert(log_sk:setsockname("*",0))
  -- IP address and port number to bind to
   assert(log_sk:setpeername(iIPaddr_, tonumber(iSCOMPort_)))
  -- Timeout socket set after which, the receive API stops blocking
   if (iTimeoutSec_ ~= nil) then
      assert(log_sk:settimeout(iTimeoutSec_))
   end
   return log_sk
end


--******************************************************************************
-- Close an SCOM socket
-- Inputs:
--   iSock_     the socket object to close
--******************************************************************************
local function CloseSCOM(iSock_)
   assert(iSock_:close())
end


--******************************************************************************
-- Get an SCOM Port number
-- Inputs:
--   iSCOMNum_    the number (1..4) of the SCOM to get
-- Returns:
--   The Port number of the requested SCOM 
--******************************************************************************
local function GetSCOMPort(iSCOMNum_)
   if iSCOMNum_ <= SCOMPortNumMax then
      return SCOMPort[iSCOMNum_]
   else
      return nil
   end
end

--******************************************************************************
local SCOM = {}
SCOM.GetSCOMPort  = GetSCOMPort
SCOM.OpenSCOM     = OpenSCOM
SCOM.CloseSCOM    = CloseSCOM

return SCOM
