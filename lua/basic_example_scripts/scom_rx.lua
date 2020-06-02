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
-- Script to demonstrate latency and idle time calculation
--******************************************************************************

sock = require("socket")

-- Variables for number of bytes received, number of logs received and script uptime in milliseconds
num_bytes = 0
num_logs = 0
msec_prev = 0


------------------------------------------------------------------------------------------------------

-- LUA local function get_idle_time
-- log: Any LOG from NovAtel receiver in full ASCII format
local function get_idle_time(log)
   --print(log)-- Uncomment this to see the raw Log
    local pos = 0
    for word in string.gmatch(log, '([^,]+)') do
       pos = pos + 1
       if pos == 4 then
          return word
       end
    end
  
    return nil
end

-------------------------------------------------------------------------------------------------------

-- LUA script MAIN
-- ipaddr_: IP address of the receiver Ethernet interface, from IPSTATUS log or 127.0.0.1 if running locally
-- scomnum_: SCOM number to use (1-4)
local function main(ipaddr_, scomnum_)
  -- UDP Socket
   log_sk = sock.udp()
  -- Socket name
   assert(log_sk:setsockname("*",0))
  -- Receiver IP address and port number to bind to
   assert(log_sk:setpeername(ipaddr_, require('scom').GetSCOMPort(tonumber(scomnum_))))
  -- Timeout socket set after which, the receive API stops blocking
   assert(log_sk:settimeout(10))

  -- 'prime' the SCOM with our IP address.
   assert(log_sk:send("\r\n"))

  -- Simple logging of UPTIME log every 1 second
   log_sk:send("LOG UPTIMEA ONTIME 1\n")
  -- Get time stamp
   msec_cur   = socket.gettime() * 1000
   msec_start = msec_cur

   while true do
     -- Get UPTIME log from udp socket buffer
      buf = log_sk:receive()
     -- If no data is received, stop infinite loop
      if buf == nil then 
         print(" Socket receive timed out")
         break
      end

     -- Compute current time and latency
      msec_cur   = socket.gettime() * 1000
      msec_delta = msec_cur - msec_prev
      msec_prev  = msec_cur
     -- Compute the number of bytes received
      num_bytes = num_bytes + string.len(buf)
     -- Compute number of logs received
      num_logs = num_logs + 1

     -- Extract idle time from UPTIMEA log
      idle_time = get_idle_time(buf)

     -- Print computed latency and idle time
      if idle_time ~= nil then
         print(string.format("Latency: %fms, Idle Time: %f%%", msec_delta, idle_time))
      end
  
   end

  -- After time out, print a summary of the number of bytes received, number of logs received and number of milliseconds operating
   print(string.format("Received %d bytes; %d logs in %d msec", num_bytes, num_logs, msec_cur - msec_start))
   return 0
end

-------------------------------------------------------------------------------------------------------
main(arg[1], arg[2])
