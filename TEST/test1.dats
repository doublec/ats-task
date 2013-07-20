staload "task/SATS/task.sats"
dynload "task/DATS/task.dats"

implement main (argc, argv) = {
  var sch = scheduler_new ()
  val () = set_global_scheduler (sch)

  val () = task_spawn (16384, lam () => {
                          val () = print ("hello\n")
                          val () = task_yield ()
                          val () = print ("world\n")
                       })

  val () = task_spawn (16384, lam () => {
                          val () = task_spawn (16384, lam () => {
                                                 val () = print ("Task start\n")
                                                 val () = task_yield ()
                                                 val () = print ("Task end\n")
                                               })
                          val () = print ("Test1\n")
                          val () = task_yield ()
                          val () = print ("Test2\n")
                       })

  val () = run_global_scheduler ()

  val () = unset_global_scheduler (sch)
  val () = scheduler_free (sch)

  val () = printf ("done\n", @()) 
}

