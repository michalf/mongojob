# MongoJob

MongoJob is a job queuing system inspired by [Resque](http://github.com/defunkt/resque), and using [MongoDB](http://mongodb.org) as a backend.

MongoJob is specifically designed to handle both long and short-term jobs.

# Current features and status

- Persistent, database-backed queues and jobs
- Worker based on EventMachine
- Multiple ways to invoke jobs by the worker: process forking, fiber (for non-blocking jobs), blocking (in-line)
- Pinging and reporting - workers report status every few seconds
- Jobs with status - jobs can report progress and set custom status
- Web interface with current workers, jobs etc.

## Still TODO

- MongoJob-deamon that monitors workers and jobs, kills timed-out ones
- Job rescheduling upon failure
- Cron-like job scheduling
- More complete web interface
- Command-line interface
- Documentation

# Warning

The library is in early stage of development. If you are looking for a robust job scheduling system, I bet [Resque](http://github.com/defunkt/resque) is much more stable now and I highly recommend it to anyone.


