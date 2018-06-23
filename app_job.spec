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
      pid = 0,            -- process id, after sched.f_start_job
      ps = {},            -- process status, .cpu, .mem, in jobs_monitor
   },

   {
      name = "job2",
      dir = "/Volumes/Datas/repos/_projs/lua_task",
      env = "",
      app = "busy_app.out 1000000",
   },

   {
      name = "job3",
      dir = "/Volumes/Datas/repos/_projs/lua_task",
      env = nil,
      app = "busy_app.out 100000",
   },
},



jobs_scheduler = {

   -- sched interface
   --
   -- 
   -- variables
   -- 
   -- * sched.v_app_jobs
   -- * sched.v_running_jobs ([key, value] is [pid, job])
   -- * sched.v_running_job_count
   --
   -- 
   -- functions
   -- 
   -- * sched.f_start_job( job )
   -- * sched.f_kill_job( job, signal_number )
   -- 
   -- * sched.f_sleep( number )
   -- * sched.f_exit( code )
   -- 

   jobs_launch = function ( sched )

      for _, job in ipairs(sched.v_app_jobs) do

         sched.f_start_job( job )
         print( job.name, "pid:", job.pid)
         
         if job.name == "job1" then
            job.count = 0       -- init value
            sched.f_sleep(1)
         end
      end
   end,


   jobs_monitor = function ( sched )

      local exit_app = false

      for pid, job in pairs(sched.v_running_jobs) do
         print( job.name, "pid: ", job.pid, "cpu:", job.ps.cpu, "mem:", job.ps.mem)

         if job.name == "job1" then
            if job.count < 10 then
               job.count = job.count + 1
            else
               exit_app = true
            end
         end
      end

      if sched.v_running_job_count<#sched.v_app_jobs or exit_app then
         print("befor exit ", exit_app)
         sched.f_exit( 1 )
      else
         sched.f_sleep( 1.5 )
      end
   end,
}
