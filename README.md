<h1>Hexagon | NovAtel OEM7 API Windows Development Kit</h1>
Welcome to the support repository for the NovAtel OEM7 API (Lua interpreter) development kit. 

<p>
    <h2>OEM7 API General Information</h2>
    Please refer to <a href="https://novatel.com/products/firmware-options-pc-software/gnss-receiver-firmware-options/api">novatel.com</a>.
</p>
<p>
    <h2>Quick Start Steps</h2>
    Follow these steps to get started quickly. For greater detail, please refer to the <a href="https://github.com/novatel/oem7_api_dev_kit/wiki">Wiki</a>.
    <OL>
        <LI>Confirm that your receiver supports the OEM7 API, use the MODELFEATURES command to assist with this.</LI>
        <LI>Download the OEM7 API dev kit</LI>
        <LI>Copy the lua\TEMPLATE_PROJECT directory to make a new project directory under the lua folder, for example lua\My_Project</LI>
    <LI>Update <em>lua\My_Project\make_my_project.bat</em> to refer to your new project</LI>
        <LI>Edit the message in the Lua script lua\My_Project\lua\autoexec.lua</LI>
        <LI>Optional: Rename the script from autoexec.lua to something else such as my_script.lua, only if you do not want the script to automatically run when the receiver boots.</LI>
        <LI>Run the batch script lua\My_Project\make_my_project.bat to generate a .hex file you can upload to your receiver.</LI>
        <LI>Upload the .hex file to your receiver using the Upload tool of the NovAtel Application Suite (or the WebUI Firmware updater, if your receiver supports it).</LI>
        <LI>Use the LUAFILELIST command to confirm that your script was loaded</LI>
        <LI>Use the LUA START command to start your script (unless it was already started automatically)</LI>
    </OL>
</p>    
<p>
    <h3>Explore, Edit, Deploy your Scripts</h3>
    To start deploying your own OEM7 API scripts, please refer to the <a href="https://github.com/novatel/oem7_api_dev_kit/wiki">documentation wiki</a>.
</p>
<p>
    <h3>Get Support</h3>
    For support with NovAtel products, including the OEM7 API, please contact NovAtel Customer Service here:<BR>
    <a href="https://docs.novatel.com/OEM7/Content/Front_Matter/Customer_Support.htm">https://docs.novatel.com/OEM7/Content/Front_Matter/Customer_Support.htm</a>
</p>
