--
-- app_scheduler.lua
--
-- load app from specifcation, launch then monitor jobs, return
-- status with callback
--
-- by lalawue, 2018/06/20
--


local K_TMP_NAME = "/tmp/lua_process_loader_tmpfile"
local G_ALL_JOBS = {}


--
-- Basic Function
--

function string.split(input, delimiter, plain)
   input = tostring(input)
   delimiter = tostring(delimiter)
   if (delimiter=='') then return false end
   local pos,arr = 0, {}
   -- for each divider found
   for st,sp in function() return string.find(input, delimiter, pos, plain) end do
      table.insert(arr, string.sub(input, pos, st - 1))
      pos = sp + 1
   end
   table.insert(arr, string.sub(input, pos))
   return arr
end


--
-- Internal Function
-- 

function os.content_from_file( file_path )
   local fp = io.open(file_path)
   if fp then
      local content = fp:read("a")
      fp:close()
      return content
   end
end

function os.content_from_exec( cmd )
   local fp = io.popen( cmd )
   if fp then
      local content = fp:read("a")
      fp:close()
      return content
   end
end

function os.status_of_pid( pid )
   local content = os.content_from_exec( string.format("ps -v %d", pid) )

   local lines = string.split( content, "\n", true)
   if #lines >= 2 then
      local keys = string.split( lines[1], " +", false)
      local vals = string.split( lines[2], " +", false)

      local ps = {}
      
      for i, v in ipairs(keys) do
         local k = string.gsub(v, "%%", "")
         if k:len() > 2 then
            ps[string.lower(k)] = vals[i]
         end
      end

      return ps
   end
end



--
-- Public Function
--

function os.all_jobs()
   return G_ALL_JOBS
end

function os.launch_job( job )
   local sh_cmd = "cd '" .. job.job_path .. "'; "
      .. "./" .. job.job_app .. " > /dev/null & "
      .. "echo $! > " .. K_TMP_NAME
   --print( sh_cmd )
   os.execute( sh_cmd )
   job.app_pid = tonumber(os.content_from_file( K_TMP_NAME ))
   return job.app_pid
end

function os.kill_job( job, signal )
   if job.app_pid then
      signal = signal and signal or 9
      os.execute(string.format("kill -%d %d", signal, job.app_pid))
   end
end





--
-- Entry Function
-- 

local app_job_desc = os.content_from_file( ... )

if app_job_desc:len() <= 0 then
   print("Fail to load app job desc !")
   os.exit(0)
end

local job_spec = load( "return { " ..  app_job_desc .. " } ")()
if not job_spec then
   os.exit(0)
else
   app_job_desc = nil
   G_ALL_JOBS = job_spec.app_jobs
end

-- check desc function
local job_launch = job_spec.job_scheduler.job_launch
local job_monitor = job_spec.job_scheduler.job_monitor

if type(job_launch) ~= "function" or
   type(job_monitor) ~= "function"
then
   print("job_launch or job_monitor is not function")
   os.exit(0)
end

-- launch job
for _, job in ipairs( job_spec.app_jobs ) do
   job_launch( os, job )
end

-- monitor job
repeat
   for _, job in ipairs( job_spec.app_jobs ) do
      if job.app_pid > 0 then
         local ps = os.status_of_pid( job.app_pid )
         job_monitor( os, job, ps)
      end
   end
until false





