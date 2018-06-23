--
-- app_scheduler.lua
--
-- load app from specifcation, launch then monitor jobs, return
-- status with callback
--
-- by lalawue, 2018/06/20
--

local sched = {
   v_tmp_path = string.format("/tmp/app_scheduler_%d.tmp", os.time()),
   v_lock_path = "",            -- file to mark running
   v_stop_path = "",            -- file to mark stop

   v_spec_name = "",            -- app_job spec name
   v_app_jobs = {},             -- user defined app jobs
   v_running_jobs = {},         -- running jobs
   v_running_pids = {},         -- pids collected from running jobs

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
      local content = fp:read("a")
      fp:close()
      return content
   end
end

local function _content_from_exec( cmd )
   local fp = io.popen( cmd )
   if fp then
      local content = fp:read("a")
      fp:close()
      return content
   end
end

local function _check_exit_file_mark( sched )
   return sched.v_lock_path and _content_from_file(sched.v_stop_path)
end

local function _check_job_integrity( job )
   job.name = job.name and job.name or "(-.-)"
   job.dir = job.dir and job.dir or "~"
   job.env = job.env and job.env or ""
   job.app = job.app or nil
   job.pid = 0
   job.ps = {}
end

-- remove stopped job from running_jobs, collect running pids
local function _check_running_jobs( sched )
   sched.v_running_pids = {}
   local count = #sched.v_running_jobs
   local i = 1
   -- move stopped job to the end
   while i <= count do
      local job = sched.v_running_jobs[i]
      if job.pid > 0 then
         i = i + 1
         sched.v_running_pids[#sched.v_running_pids + 1] = job.pid
      else
         local tmp = sched.v_running_jobs[count]
         sched.v_running_jobs[count] = job
         sched.v_running_jobs[i] = tmp
         count = count - 1
      end
   end
   -- remove from running_jobs
   for i = count + 1, #sched.v_running_jobs do
      sched.v_running_jobs[i].running_index = 0
      sched.v_running_jobs[i] = nil
   end
end

-- collect running pids process status
local function _process_status_of_running_jobs()
   if #sched.v_running_pids <= 0 then
      return
   end

   local pids = table.concat(sched.v_running_pids, " -p ")
   local sh_cmd = string.format("ps -v -p %s", pids)
   --_print_fmt(cmd)
   local content = _content_from_exec( sh_cmd )

   local lines = _split( content, "\n", true)
   if #lines >= 2 then
      local keys = _split( lines[1], " +", false)

      for i, job in ipairs(sched.v_running_jobs) do
         local vals = _split( lines[i + 1], " +", false)
         if not job.ps then
            job.ps = {}
         end
         for j, v in ipairs(keys) do
            local k = string.gsub(v, "%%", "")
            if k:len() > 2 then
               job.ps[string.lower(k)] = vals[j]
            end
         end
      end
   end
end



--
-- Public Function
--

function sched.sandbox.launch_job( job )
   -- 1. cd to DIR
   -- 2. set env in shell
   -- 3. run app in background
   -- 4. get returned pid from tmp file
   
   if job.app and job.pid <= 0 then
      local sh_cmd = "cd '" .. job.dir .. "';"
         .. job.env .. " "
         .. "./" .. job.app .. " > /dev/null & "
         .. "echo $! > " .. sched.v_tmp_path
      -- _print_fmt( sh_cmd )
      os.execute( sh_cmd )
      job.pid = tonumber(_content_from_file( sched.v_tmp_path ))
      if job.pid > 0 then
         if not job.running_index or job.running_index <= 0 then
            job.running_index = #sched.v_running_jobs + 1
            sched.v_running_jobs[job.running_index] = job
         end
         return job.pid
      end
   end
   return 0
end

function sched.sandbox.kill_job( job, sig_number )
   if job.pid > 0 then
      sig_number = sig_number and sig_number or 9
      os.execute(string.format("kill -%d %d", sig_number, job.pid))
      job.pid = 0
   end
end

function sched.sandbox.sleep( number )
   os.execute("sleep " .. number)
end

-- remove all temp file
function sched.sandbox.exit( code )
   os.remove(sched.v_lock_path)
   os.remove(sched.v_stop_path)
   os.remove(sched.v_tmp_path)
   os.exit( code )
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
   _print_fmt("[start | stop] app_job.spec")
   os.exit(0)
end


-- job desc content
local app_jobs_desc_content = _content_from_file( arg_file_path )
if app_jobs_desc_content:len() <= 0 then
   _print_fmt("fail to load app job desc !")
   os.exit(0)
end


-- Lua job desc structure
local jobs_spec = load( "return { " ..  app_jobs_desc_content .. " } ")()
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

   jobs_spec = nil
   app_jobs_desc_content = nil
end


--
-- Stop Job Procedure
-- 
if arg_operation == "stop" then
   if not _content_from_file( sched.v_lock_path ) then
      _print_fmt("app_job [%s] was stopped", sched.v_spec_name)
      os.exit(0)
   end
   _content_from_exec(string.format("touch %s", sched.v_stop_path))
   local i = 0
   repeat
      sched.sandbox.sleep(1)
      _print_fmt("waiting app_job [%s] to stop, %d seconds", sched.v_spec_name, i)
      i = i + 1
   until (i>15) or (not _content_from_file( sched.v_lock_path ))
   if i > 15 then
      _print_fmt("app_job [%s] fail to stop, timeout 15 seconds", sched.v_spec_name)
   else
      _print_fmt("app_job [%s] stopped", sched.v_spec_name)
   end
   sched.sandbox.exit(0)
end


--
-- Start Job Procedure
-- 

-- check job integrity
for _, job in ipairs(sched.v_app_jobs) do
   _check_job_integrity(job)
end

_print_fmt("app_job [%s] start ...", sched.v_spec_name)

-- launch job step
sched.sandbox.app_jobs = sched.v_app_jobs
sched.f_jobs_launch( sched.sandbox )

_content_from_exec( string.format("touch %s", sched.v_lock_path) ) -- mark running

-- monitor job step
sched.sandbox.running_jobs = sched.v_running_jobs
while true do
   _check_running_jobs( sched )
   _process_status_of_running_jobs( sched.v_running_jobs )
   
   sched.f_jobs_monitor( sched.sandbox )
   
   if _check_exit_file_mark( sched ) then
      _print_fmt("app_job [%s] received exit file mark !", sched.v_spec_name)
      sched.sandbox.exit(0)      
   end
end
