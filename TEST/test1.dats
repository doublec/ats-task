staload "contrib/task/SATS/task.sats"
dynload "contrib/task/DATS/task.dats"

implement main (argc, argv) = {
  var sch: scheduler?
  val () = scheduler_initialize (sch)

  val (pf | ()) = settaskscheduler (view@ sch | &sch)

  val t1 = task_create (lam () => {
                          val () = print ("hello\n")
                          val () = task_yield ()
                          val () = print ("world\n")
                        })
  var !stack with pf_stack = @[char?][16384]()
  val (pff, at | s) = getschedulerctx ()
  val () = setcontextstack (pf_stack | !s, stack, 16384)
  prval () = pff (at)
  val () = task_schedule (t1)

  val t2 = task_create (lam () => {
                          val () = print ("Test1\n")
                          val () = task_yield ()
                          val () = print ("Test2\n")
                        })
  var !stack with pf_stack = @[char?][16384]()
  val (pff, at | s) = getschedulerctx ()
  val () = setcontextstack (pf_stack | !s, stack, 16384)
  prval () = pff (at)
  val () = task_schedule (t2)

  val (pff_s, pf_s | s) = gettaskscheduler ()
  val () = scheduler_run (!s)
  prval () = pff_s (pf_s)

  val (pf | _) = cleartaskscheduler (pf | (* *))
  prval () = view@ sch := pf

  val () = scheduler_uninitialize (sch)

  val () = printf ("done\n", @()) 
}

