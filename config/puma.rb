threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

port ENV.fetch("PORT", 3000)

plugin :tmp_restart

# Jobs run inside the web process on the same database, so one service runs the whole app.
plugin :solid_queue unless ENV["SOLID_QUEUE_IN_PUMA"] == "false"

pidfile ENV["PIDFILE"] if ENV["PIDFILE"]
