--
-- app_jobs specification example
--

spec_name = "app_job_example",

app_jobs = {
   
   {
      name = "job1",
      dir = "/Volumes/Datas/repos/_projs/lua_task",
      env = "TTT=HAHAHA; BB=CC;",
      app = "busy_app.out 10000",
      -- 
      pid = 0,            -- process id, after sched.launch_job
      ps = {},            -- process status, .cpu, .mem, in jobs_monitor
   },

   {
      name = "job2",
      dir = "/Volumes/Datas/repos/_projs/lua_task",
      env = "",
      app = "busy_app.out 1000000",
      -- 
      pid = 0,
      ps = {},
   },

   {
      name = "job3",
      dir = "/Volumes/Datas/repos/_projs/lua_task",
      env = nil,
      app = "busy_app.out 100000",
      -- 
      pid = 0,            -- process id, after sched.launch_job      
      ps = {},            -- process status, .cpu, .mem, in jobs_monitor
   },
},



jobs_scheduler = {

   -- sched interface
   --
   -- 
   -- variables
   -- 
   -- * sched.app_jobs 
   -- * sched.running_jobs
   --
   -- 
   -- functions
   -- 
   -- * sched.launch_job( job )
   -- * sched.kill_job( job, signal_number )
   -- 
   -- * sched.sleep( number )
   -- 
   
   jobs_launch = function ( sched )
      
      for _, job in ipairs(sched.app_jobs) do
         
         sched.launch_job( job )
         print( job.name, "pid:", job.pid)
         
         if job.name == "job1" then
            job.count = 1
            sched.sleep(1)
         end
      end
   end,
   

   jobs_monitor = function ( sched )

      local exit_app = false
      
      for _, job in ipairs(sched.running_jobs) do
         print( job.name, "pid: ", job.pid, "cpu:", job.ps.cpu, "mem:", job.ps.mem)

         if job.name == "job1" then
            if job.count > 10 then
               exit_app = true
            else
               job.count = job.count + 1
            end
         end
      end

      if exit_app then
         for _, job in ipairs(sched.running_jobs) do
            sched.kill_job(job)
         end
         sched.exit(1)
      else
         sched.sleep( 1.5 )
      end
   end,
}
