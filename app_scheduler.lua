--
-- app_scheduler.lua
--
-- load app from specifcation, launch then monitor jobs, return
-- status with callback
--
-- by lalawue, https://github.com/lalawue/app_scheduler
--



local FILE_READ_PARAM = _VERSION:sub(5) < "5.3" and "*a" or "a"
local PS_PREFIX_PARAM = "ps u -p "



local sched = {
   v_tmp_path = string.format("/tmp/app_scheduler_tmp.%d", os.time()),
   v_lock_path = "",            -- file to mark running
   v_stop_path = "",            -- file to mark stop

   v_spec_name = "",            -- app_job spec name
   v_app_jobs = {},             -- array
   v_running_jobs = {},         -- key is tostring(pid)

   f_jobs_launch = function() end,
   f_jobs_monitor = function() end,

   sandbox = {},                -- sandbox for user operation
}





--
-- Basic Function
--

local function _print_fmt(fmt, ...)
   print(string.format(fmt, ...))
end

local function _split(input, delimiter, plain)
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

local function _content_from_file( file_path )
   local fp = io.open(file_path, "r")
   if fp then
      local content = fp:read(FILE_READ_PARAM)
      fp:close()
      return content
   end
end

local function _content_from_exec( cmd )
   os.execute( string.format("%s > %s", cmd, sched.v_tmp_path) )
   local fp = io.open(sched.v_tmp_path, "r")
   if fp then
      local content = fp:read(FILE_READ_PARAM)
      fp:close()
      return content
   end
end

local function _check_exit_file_mark( sched )
   return sched.v_lock_path and _content_from_file(sched.v_stop_path)
end

-- mark pre-defined job
local function _check_job_integrity( job )
   job.name = job.name and job.name or "(-.-)"
   job.dir = job.dir and job.dir or "~"
   job.env = job.env and job.env or ""
   job.app = job.app or nil
   job.pid = 0
   job.ps = nil
end

-- collect running jobs process status
local function _collect_process_status_of_jobs( running_jobs )
   local pids = {}
   for pid, job in pairs(running_jobs) do
      pids[#pids + 1] = pid
      job.ps = nil              -- mark
   end

   local sh_cmd = string.format("%s %s", PS_PREFIX_PARAM, table.concat(pids, " -p "))
   --_print_fmt(cmd)

   local lines = _split( _content_from_exec( sh_cmd ), "\n", true)
   local pid_count = 0
   if #lines >= 2 then
      local keys = _split( lines[1], " +", false)

      for i=2, #lines do
         local vals = _split( lines[i], " +", false)
         
         if #vals >= #keys then
            pid_count = pid_count + 1
            local ps = {}
            for j, v in ipairs(keys) do
               local k = v:gsub("%%", ""):lower()
               if k:len() > 2 then
                  ps[k] = vals[j]
                  if k == "pid" then
                     running_jobs[vals[j]].ps = ps -- reset ps in job
                  end
               end
            end
         end
      end
   end

   -- clean stopped jobs
   for pid, job in pairs(running_jobs) do
      if not job.ps then
         running_jobs[pid].pid = 0
         running_jobs[pid] = nil
      end
   end

   -- return running jobs count
   return pid_count
end




--
-- Pre-defined Function
--

-- start job as process
function _sandbox_start_job( job )
   -- 1. cd to dir
   -- 2. set env in shell
   -- 3. run app in background
   -- 4. get pid from tmp file
   
   if job.app and (job.pid<=0 or not job.pid) then
      local sh_cmd = "cd '" .. (job.dir or "/") .. "';"
         .. (job.env or "") .. " "
         .. job.app .. " & "
         .. "echo $! > " .. sched.v_tmp_path
      -- _print_fmt( sh_cmd )
      os.execute( sh_cmd )
      local pid = tonumber( _content_from_file( sched.v_tmp_path ) )
      if pid > 0 then
         if not job.pid then
            sched.app_jobs[#sched.app_jobs + 1] = job
         end
         job.pid = pid
         sched.v_running_jobs[tostring(pid)] = job
         return job.pid
      end
   else
      _print_fmt("invalid app or app was started")
   end
   return 0
end

-- kill job process
function _sandbox_kill_job( job, sig_number )
   if job.pid > 0 then
      sig_number = sig_number and sig_number or 9
      os.execute(string.format("kill -%d %d", sig_number, job.pid))
      sched.v_running_jobs[tostring(job.pid)] = nil
      job.pid = 0
      job.ps = nil
   end
end

-- sleep seconds
function _sandbox_sleep( number )
   os.execute("sleep " .. number)
end

-- kill all running jobs, remove all temp file, then exit program
function _sandbox_exit( code )
   for _, job in pairs(sched.v_running_jobs) do
      _sandbox_kill_job(job)
   end
   os.remove(sched.v_lock_path)
   os.remove(sched.v_stop_path)
   os.remove(sched.v_tmp_path)
   os.exit( code )
end

-- reset with pre-defined value and function
local function _reset_sandbox_values( sandbox )
   sandbox.v_app_jobs = sched.v_app_jobs
   sandbox.v_running_jobs = sched.v_running_jobs
   sandbox.v_running_job_count = 0
   
   sandbox.f_start_job = _sandbox_start_job
   sandbox.f_kill_job = _sandbox_kill_job
   
   sandbox.f_sleep = _sandbox_sleep
   sandbox.f_exit = _sandbox_exit
end




--
-- Check Params
-- 

local arg_operation, arg_file_path = ...
if arg_file_path and
   (arg_operation:lower() == "start" or arg_operation:lower() == "stop")
then
   -- do nothing
else
   _print_fmt("see job_spec.lua demo, more in <https://github.com/lalawue/app_scheduler>\n")
   _print_fmt("[start | stop] job_spec.lua\n")
   os.exit(0)
end


-- Lua job desc structure, no more backtrace here
local jobs_spec = load( "return { " ..  _content_from_file( arg_file_path ) .. " } ")()
if not jobs_spec then
   _print_fmt("fail to load job spec !")
   os.exit(0)
else
   if type(jobs_spec.spec_name) ~= "string" or
      type(jobs_spec.jobs_scheduler.jobs_launch) ~= "function" or
      type(jobs_spec.jobs_scheduler.jobs_monitor) ~= "function"
   then
      _print_fmt("spec_name invalid, or job_launch, job_monitor not a function !")
      os.exit(0)
   end
   sched.v_spec_name = jobs_spec.spec_name
   sched.v_stop_path = string.format("/tmp/app_scheduler_stop.%s", jobs_spec.spec_name)
   sched.v_lock_path = string.format("/tmp/app_scheduler_lock.%s", jobs_spec.spec_name)
   
   sched.v_app_jobs = jobs_spec.app_jobs
   sched.f_jobs_launch = jobs_spec.jobs_scheduler.jobs_launch
   sched.f_jobs_monitor = jobs_spec.jobs_scheduler.jobs_monitor

   sched.sandbox = jobs_spec.jobs_scheduler

   jobs_spec = nil
end




--
-- Stop Job Procedure
-- 
if arg_operation == "stop" then
   
   -- check running file mark
   if not _content_from_file( sched.v_lock_path ) then
      _print_fmt("app_job [%s] was stopped", sched.v_spec_name)
      os.exit(0)
   end
   
   -- create stop file mark, check stopped state in 3 seconds
   _content_from_exec(string.format("touch %s", sched.v_stop_path))
   local i = 0
   local timeout = 3
   repeat
      _sandbox_sleep( 1 )
      _print_fmt("waiting app_job [%s] to stop, %d seconds", sched.v_spec_name, i)
      i = i + 1
   until (i>timeout) or (not _content_from_file( sched.v_lock_path ))
   
   -- check result
   if i > timeout then
      _print_fmt("app_job [%s] fail to stop, timeout %d seconds", sched.v_spec_name, timeout)
   else
      _print_fmt("app_job [%s] stopped", sched.v_spec_name)
   end

   -- exit
   _sandbox_exit( 0 )
end




--
-- Start Job Procedure
-- 

-- check job integrity, reset default job value
for _, job in ipairs(sched.v_app_jobs) do
   _check_job_integrity(job)
end

_print_fmt("app_job [%s] start ...", sched.v_spec_name)

-- reset sandbox values
_reset_sandbox_values( sched.sandbox )

-- launch jobs
sched.f_jobs_launch( sched.sandbox )

-- mark running state
_content_from_exec( string.format("touch %s", sched.v_lock_path) )

-- monitor jobs
while true do
   -- refresh process status
   sched.sandbox.v_running_job_count = _collect_process_status_of_jobs( sched.v_running_jobs )

   -- call monitor with sandbox
   sched.f_jobs_monitor( sched.sandbox )

   -- check stop file mark
   if _check_exit_file_mark( sched ) then
      _print_fmt("app_job [%s] exit !", sched.v_spec_name)
      sched.sandbox.f_exit( 0 )
   end
end
