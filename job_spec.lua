--
-- app_jobs specification example
--

local spec_example = {
   

   -- spec name   
   spec_name = "app_job_example",
   
   
   -- pre-defined app jobs
   app_jobs = {
      {
         name = "job_1",
         dir = "/working/dir/",
         env = "VAL1=AAA;VAL2=BBB;",
         app = "$PWD/busy_app.out 10000",
      },
      {
         name = "job_2",
         dir = "/working/dir",
         env = "",
         app = "./busy_app.out 1000000",
      },
      {
         name = "job_3",
         dir = "/working/dir",
         env = nil,
         app = "./busy_app.out 100000",
      },
   },


   -- for launch and monitor app jobs
   jobs_scheduler = {

      -- 
      -- Pre-defined variables and functions, will overide same name
      --
      -- variables
      -- 
      -- * sched.v_app_jobs: user defined jobs, you can add new job in runtime
      -- * sched.v_running_jobs: running jobs, with pid > 0, key is pid
      -- * sched.v_running_job_count: running jobs count, valid in jos_monitor
      --
      -- 
      -- functions
      -- 
      -- * sched.f_start_job( job ): start a new job, can run new job at runtime
      -- * sched.f_kill_job( job, signal_number ): kill job
      -- 
      -- * sched.f_sleep( number ): sleep seconds
      -- * sched.f_exit( code ): exit this program
      --

      -- 
      -- User-defined functions [ MUST ]
      -- 
      -- * sched.jobs_launch( sched ): run only once at the beginning
      -- * sched.jobs_monitor( sched ): get job running status before running, loop forever
      -- 

      v_my_pre_defined_value = 123456,
      v_my_pre_defined_timeout = 20,
      
      f_my_print = function(fmt, ...)
         print(string.format(fmt, ...))
      end,

      

      -- run only once, param 'sched' was jobs_scheduler
      jobs_launch = function ( sched )

         sched.f_my_print("my pre-defined value: %d", sched.v_my_pre_defined_value)
         sched.v_my_pre_defined_value = os.time()

         -- you can reset job.env or job.path before .f_start_job
         for _, job in ipairs(sched.v_app_jobs) do
            
            job.dir = os.getenv("PWD")
            
            sched.f_start_job( job )
            sched.f_my_print("[%s] pid: %d", job.name, job.pid)
            
            if job.name == "job_1" then
               job.count = 0       -- create new value
               sched.f_sleep( 1.5 )
            end
         end

         
      end,

      

      -- loop forever, will refresh job process status before running
      jobs_monitor = function ( sched )

         local time_out = false
         sched.f_my_print("## --- monitor uptime %d, in <%s> --- ",
                          os.time() - sched.v_my_pre_defined_value, os.date("%c"))

         for pid, job in pairs(sched.v_running_jobs) do
            sched.f_my_print("[%s] cpu:%s, mem:%s", job.name, job.ps.cpu, job.ps.mem)

            if job.name == "job_1" then
               if job.count < sched.v_my_pre_defined_timeout then
                  job.count = job.count + 1
               else
                  time_out = true
               end
            end
         end

         if sched.v_running_job_count<#sched.v_app_jobs or time_out then
            sched.f_my_print("exit with running jobs count %d", sched.v_running_job_count)
            sched.f_exit( 1 )
         else
            sched.f_sleep( 1.2 )
         end
      end,
   }
}

return spec_example
