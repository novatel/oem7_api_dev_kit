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
--
--******************************************************************************
-- Simple script to demonstrate how to pass arguments into the Lua interpreter
--
-- Example command to start the script on an OEM receiver:
--   lua prompt "scriptargs.lua 1 20 hi 300"
-- 
--******************************************************************************
 
-- Print the script name
print(string.format('Script Name: "%s"',arg[0]))

FormatString = '%-10s%-10s%-15s%-15s'
print(string.format(FormatString,'Arg#','Type','String','Number'))

-- Iterate through the arguments
Sum = 0
NumberOfTwenties = 0 
for i = 1,4 do   
 -- Print some information about the argument
 -- NOTE: The type of these arguments is always "string"
  print(string.format(FormatString,i,type(arg[i]),arg[i],tonumber(arg[i])))
  
 -- Check if the string represents a number
  if (tonumber(arg[i]) ~= nil) then
    -- If the string represents a number, Lua will automatically 
    -- convert the strint to a number for arithmetic
     Sum = Sum + arg[i]
  end  
  
 -- Since the arg values are always of type "string" 
 -- a direct comparison with a number will always fail
  if (arg[i] == 20) then 
     NumberOfTwenties = NumberOfTwenties + 1 
  end
end
print('')
print(string.format("Sum of Number Arguments: %d",Sum))
print(string.format("Number of 20s found: %d",NumberOfTwenties))

