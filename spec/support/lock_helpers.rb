module LockHelpers
  # Proves a concurrent transaction is queued on a lock instead of guessing with sleep.
  def wait_for_lock_waiter(timeout: 5)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    ActiveRecord::Base.connection_pool.with_connection do |connection|
      until connection.select_value("SELECT count(*) FROM pg_locks WHERE NOT granted").positive?
        raise "no transaction is waiting on a lock" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

        sleep 0.01
      end
    end
  end
end

RSpec.configure { it.include LockHelpers }
