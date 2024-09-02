-- Version 1.0.1
local ffi = require("ffi")

o = obslua

BASEDIRECTORY= nil
sceneBasedName = false
sceneBasedFolder = false

require 'winapi'

function script_description()
	return [[OBSPlay, like Nvidia Shadowplay but for OBS! If you have Scene Based Prefix Enabled it will move the replay file to the 'Base Save Path' and rename the file to have a prefix of the scene name. 
If you have 'Scene Based Folder' it will move the replay file to 'BaseSavePath\SceneName' and will not change the prefix. 
Enable both to have it change the Prefix and move the recording to the 'Scene Based Folder'.
IMPORTANT: Leave Your Replay Buffer Prefix empty if you are using Scene Based Prefix.

Author: Kwozy]]
end

function script_load()
    o.obs_frontend_add_event_callback(obs_frontend_callback)
end

function script_unload()
   
end

-- Function To Separate the Replay Path From Its Name
-- For Example, C:\Users\UserName\Videos\Replay File Name   Becomes Replay File Name 
-- May Only Work On Windows, Has Not Been Tested On Other OS
function get_replay_name(path)

   return path:match( "([^/]+)$" )

end

-- Function To Retrive The Latest Replay
function get_last_replay()
    replay_buffer = o.obs_frontend_get_replay_buffer_output()
    cd = o.calldata_create()
    ph = o.obs_output_get_proc_handler(replay_buffer)
    o.proc_handler_call(ph, "get_last_replay", cd)
    path = o.calldata_string(cd, "path")
    o.calldata_destroy(cd)

    o.obs_output_release(replay_buffer)
    return path
end
	
function get_current_scene_name()
	-- current_scene = o.obs_frontend_get_current_scene()
	-- name = o.obs_source_get_name(current_scene)
	-- o.obs_source_release(current_scene)
	-- return name

	
	name = guess_process()

	-- print(name)

	return name
end 

function guess_process()
	ffi.cdef[[
		typedef void* HWND;
		typedef unsigned long DWORD;
		typedef int BOOL;
		HWND GetForegroundWindow();
		int GetWindowTextA(HWND hWnd, char* lpString, int nMaxCount);
		DWORD GetWindowThreadProcessId(HWND hWnd, DWORD* lpdwProcessId);

		BOOL EnumProcessModules(void* hProcess, void** lphModule, DWORD cb, DWORD* lpcbNeeded);
		DWORD GetModuleBaseNameA(void* hProcess, void* hModule, char* lpBaseName, DWORD nSize);

		void* OpenProcess(DWORD dwDesiredAccess, BOOL bInheritHandle, DWORD dwProcessId);
		BOOL CloseHandle(void* hObject);
	]]

	local user32 = ffi.load("user32")
	local kernel32 = ffi.load("kernel32")
	local psapi = ffi.load("psapi")

	-- Constants for process access rights
	local PROCESS_QUERY_INFORMATION = 0x0400
	local PROCESS_VM_READ = 0x0010

	-- Function to strip the ".exe" extension from a string
	local function strip_extension(exe_name)
		return exe_name:gsub("%.exe$", "")
	end

	-- Get the handle of the currently active window
	local hwnd = user32.GetForegroundWindow()

	if hwnd ~= nil then
		-- Get the process ID associated with the active window
		local pid = ffi.new("DWORD[1]")
		user32.GetWindowThreadProcessId(hwnd, pid)
		
		-- Open the process with query and read access
		local process_handle = kernel32.OpenProcess(PROCESS_QUERY_INFORMATION + PROCESS_VM_READ, false, pid[0])
		
		if process_handle ~= nil then
			-- Allocate memory for the module (executable) name
			local exe_name = ffi.new("char[256]")
			
			-- Get the module base name (the executable name)
			if psapi.GetModuleBaseNameA(process_handle, nil, exe_name, ffi.sizeof(exe_name)) > 0 then
				-- Strip the ".exe" extension and print the application name
				local app_name = strip_extension(ffi.string(exe_name))
				-- print("Active Application Name: " .. app_name)
				-- Close the handle to the process
				kernel32.CloseHandle(process_handle)

				-- if application name is Explore.EXE rename to Desktop
				if app_name == "Explorer.EXE" or app_name == "ApplicationFrameHost" then
					return "Desktop"
				end

				return app_name
			else
				-- print("Failed to get the application name.")
				-- Close the handle to the process
				kernel32.CloseHandle(process_handle)
				return "Desktop"
			end
			
			-- Close the handle to the process
			kernel32.CloseHandle(process_handle)
		else
			-- print("Failed to open the process.")
			return "Desktop"
		end
	else
		-- print("No active window found.")
		return "Desktop"
	end
end

-- Function Called By OBS
function obs_frontend_callback(event, private_data)
	if event == o.OBS_FRONTEND_EVENT_REPLAY_BUFFER_SAVED then	
		OBSPlay()
    end
end

-- The Main Program
function OBSPlay()
	last_Replay = get_last_replay()
	current_scene_name = get_current_scene_name()
	absBasePath = o.os_get_abs_path_ptr(BASEDIRECTORY)

	if last_Replay ~= nil then
		last_Replay_Name = get_replay_name(last_Replay)
			if sceneBasedName == true and sceneBasedFolder == true then

				if o.os_file_exists(absBasePath .. '\\' .. current_scene_name) == true then 	
				o.os_rename(last_Replay, absBasePath .. '\\' .. current_scene_name .. '\\'.. current_scene_name .. " " .. last_Replay_Name) 
				else
					o.os_mkdir(absBasePath .. '\\' .. current_scene_name .. '\\')	
					o.os_rename(last_Replay, absBasePath .. '\\' .. current_scene_name .. '\\'.. current_scene_name .. " " .. last_Replay_Name) 
				end
			elseif sceneBasedName == true then
				o.os_rename(last_Replay, absBasePath .. '\\' .. current_scene_name .. " " .. last_Replay_Name) 
			elseif sceneBasedFolder == true then
				o.os_rename(last_Replay, absBasePath .. '\\' .. current_scene_name .. '\\' .. last_Replay_Name) 
			end
		end
	end

function script_properties()
    local p = o.obs_properties_create()

    o.obs_properties_add_path(p, "baseSavePath", "Base Save Path",
        o.OBS_PATH_DIRECTORY,
        nil,
        nil
    )
	o.obs_properties_add_bool(p, "sceneBasedPrefix", "Scene Based File Prefix")
	o.obs_properties_add_bool(p, "sceneBasedDir", "Scene Based Folder")

    return p
end

function script_defaults(s)
	o.obs_data_set_default_bool(s, "sceneBasedPrefix", sceneBasedName)
	o.obs_data_set_default_bool(s, "sceneBasedDir", sceneBasedFolder)
end

function script_update(s)
    BASEDIRECTORY = o.obs_data_get_string(s, "baseSavePath")
	sceneBasedName = o.obs_data_get_bool(s, "sceneBasedPrefix")
	sceneBasedFolder = o.obs_data_get_bool(s, "sceneBasedDir")
end
