class GunicornMonitor < Scout::Plugin
    OPTIONS=<<-EOS
      gunicorn_pid_file:
        name: Location of PID file for gunicorn
        notes: The default is to check for a PID file in /etc/supervisor/conf.d/reef-*.conf
    EOS

    def get_worker_pids(master_pid_file)
        gunicorn_pid = File.open(master_pid_file).read.strip

        return `ps --ppid #{gunicorn_pid} -o pid --no-headers`.split(' ')
    end

    def idle_worker_count(worker_pids)
        idle_workers = 0

        worker_pids.each do |pid|
            before = cpu_time(pid)
            sleep 0.5
            after = cpu_time(pid)
            if before == after
                idle_workers += 1
            end
        end

        return idle_workers
    end

    def cpu_time(pid)
        proc_info = File.open("/proc/#{pid}/stat").read
        proc_info = proc_info.split(' ')
        user_time = proc_info[13].to_i
        kernel_time = proc_info[14].to_i

        return user_time + kernel_time
    end

    def build_report
        gunicorn_pid_file = option(:gunicorn_pid_file) || `cat /etc/supervisor/conf.d/reef-*.conf | grep pidfile | cut -c9-`.strip()

        if !File.exist?(gunicorn_pid_file)
           error(:subject=>"gunicorn_pid_file: #{gunicorn_pid_file} does not exist -- check options")
           return
        end

        res={}

        worker_pids = get_worker_pids(gunicorn_pid_file)
        res[:idle_workers] = idle_worker_count(worker_pids)

        report(res)
    end
end