--
--

app_jobs = {
   
   -- job 1   
   {
      job_name = "job1",
      job_path = "/Volumes/Datas/repos/_projs/lua_task",
      job_app = "busy_app.out 10000",
      app_pid = 0,              -- return from os.launch_job
   },

   -- job 1   
   {
      job_name = "job2",
      job_path = "/Volumes/Datas/repos/_projs/lua_task",
      job_app = "busy_app.out 1000000",
      app_pid = 0,              -- return from os.launch_job
   },
},



job_scheduler = {
   
   job_launch = function ( os, job )
      os.launch_job( job )
      print( job.job_name, "pid:", job.app_pid)
      job.count = 1
      os.execute("sleep 1")      
   end,
   
   job_monitor = function ( os, job, ps )
      
      print("cpu:", ps.cpu)
      os.execute("sleep 1")
      
      if job.job_name == "job1" then      
         job.count = job.count + 1
         if job.count > 5 then
            print("exit jobs")
            for _, job in ipairs( os.all_jobs() ) do
               os.kill_job(job, 9)
            end
            os.exit(0)
         end
      end
      
   end,
}
