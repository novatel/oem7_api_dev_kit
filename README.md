<h1>Hexagon | NovAtel OEM7 API Windows Development Kit</h1>
Welcome to the support repository for the NovAtel OEM7 API (Lua interpreter) development kit. 

<p>
    <h2>OEM7 API General Information</h2>
    The NovAtel OEM7 API is used to develop specialized applications using the Lua programming language to further extend the functionality of OEM7 family receivers. User-created Lua scripts run alongside the core receiver firmware using an embedded Lua script interpreter. The scripts can interact with the core firmware by sending commands to the receiver and retrieving logs for processing.
</p>

<p>
Please refer to the following API page at <a href="https://novatel.com/products/firmware-options-pc-software/gnss-receiver-firmware-options/api">novatel.com</a> for more information.
</p>

<p>
    <h2>Quick Start Steps</h2>
    Follow these steps to get started quickly. For greater detail, please refer to the <a href="https://docs.novatel.com/OEM7/Content/Lua/Overview.htm">NovAtel Documentation Portal</a>.
    <p></p>
    <OL>
    <LI><p>Confirm that your receiver supports the OEM7 API, use the <a href="https://docs.novatel.com/OEM7/Content/Logs/MODELFEATURES.htm">MODELFEATURES</a> command to assist with this, look for "AUTHORIZED API".</p></LI>
    <LI><p>Download the OEM7 API dev kit</p></LI>
    <LI><p>Copy the <em>lua\TEMPLATE_PROJECT</em> directory to make a new project directory under the lua folder, for example <em>lua\My_Project</em></p></LI>
    <LI><p>Update <em>lua\My_Project\make_my_project.bat</em> to refer to your new project</p></LI>
    <LI><p>Edit the message in the Lua script <em>lua\My_Project\lua\autoexec.lua</em></p></LI>
    <LI><p>Optional: Rename the script from <em>autoexec.lua</em> to something else such as <em>my_script.lua</em>, only if you do not want the script to automatically run when the receiver boots.</p></LI>
    <LI><p>Run the batch script <em>lua\My_Project\make_my_project.bat</em> to generate a .hex file you can upload to your receiver.</p></LI>
    <LI><p>Upload the .hex file to your receiver using the Upload tool of the <a href="https://novatel.com/products/firmware-options-pc-software/novatel-application-suite">NovAtel Application Suite</a> (or the WebUI Firmware updater, if your receiver supports it).</p></LI>
    <LI><p>Use the <a href="https://docs.novatel.com/OEM7/Content/Logs/LUAFILELIST.htm">LUAFILELIST</a> command to confirm that your script was loaded</p></LI>
    <LI><p>Use the <a href="https://docs.novatel.com/OEM7/Content/Commands/LUA.htm">LUA START</a> command to start your script (unless it was already started automatically)</p></LI>
    </OL>
</p>    

<p>
    <h3>Learn more about the OEM7 API</h3>
    For more detailed documentation, please refer to the OEM7 API <a href="https://docs.novatel.com/OEM7/Content/Lua/Overview.htm">documentation</a>.
</p>

<p>
    <h3>Get Support</h3>
    For support with NovAtel products, including the OEM7 API, please contact NovAtel Customer Service here:<BR>
    <a href="https://docs.novatel.com/OEM7/Content/Front_Matter/Customer_Support.htm">https://docs.novatel.com/OEM7/Content/Front_Matter/Customer_Support.htm</a>
</p>
