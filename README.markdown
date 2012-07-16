Lightweight tasks module for ATS
================================

This is a cooperative tasks module for ATS where the tasks are implemented using
ucontext switches. 

Install
-------

Clone in the ATS 'contrib' directory with the name 'task':

    cd $ATSHOME/contrib
    git clone git://github.com/doublec/ats-task task
    cd task
    make

Usage
-----

The first step is to create a task scheduler and install this as the
global scheduler:

    var sch = scheduler_new ()
    val () = set_global_scheduler (sch)

Once this is done tasks can be spawned. 'task_spawn' takes a stack size
and a linear closure (cloptr1) that is run when the task is scheduled:

    val () = task_spawn (16384, lam () => {
                            val () = print ("hello\n")
                            val () = task_yield ()
                            val () = print ("world\n")
                         })

Tasks can yield using 'task_yield' which results in switching to the next
task waiting to run, and scheduling itself to run again later.

The task scheduler needs to be activated with:

    val () = run_global_scheduler ()

The scheduler exits when no more tasks are queued. The global scheduler must
be unset and free'd:

    val () = unset_global_scheduler (sch)
    val () = scheduler_free (sch)

A compile error reults if the scheduler is not unset or free'd.

TODO
----

* Make set_global_scheduler set it for the current CPU thread, allowing 
  a scheduler to run per CPU.
* Integrate with my ATS libevent wrapper to allow writing libevent based
  applications in a non-callback style. This was my original motivation
  for writing this library.
* Add intertask communication via channels.

Contact
-------
* Github: http://github.com/doublec/ats-task
* Email: chris.double@double.co.nz
* Weblog: http://www.bluishcoder.co.nz
