staload "contrib/task/SATS/task.sats"

staload _ = "prelude/DATS/pointer.dats"
staload _ = "prelude/DATS/array.dats"

staload "libats/SATS/linqueue_arr.sats"
staload _ = "libats/DATS/linqueue_arr.dats"
staload _ = "prelude/DATS/array.dats"
staload _ = "libats/ngc/DATS/deque_arr.dats"

%{^
#include <ucontext.h>

void setcontextstack (ucontext_t* ctx, char* stack, int stack_size);
ucontext_t* getschedulerctx();
void settaskscheduler (void* s);
void* gettaskscheduler ();
void cleartaskscheduler ();
void setcurrenttask (void* t);
void* getcurrenttask ();
%}

abst@ype ucontext_t = $extype "ucontext_t"

extern fun setcontext (ucp: &ucontext_t): int = "mac#setcontext"
extern fun getcontext (ucp: &ucontext_t? >> ucontext_t): int = "mac#getcontext"
extern fun makecontext (ucp: &ucontext_t, func: () -<fun1> void, argc: int (*, ... *)): void = "mac#makecontext" 
extern fun swapcontext (oucp: &ucontext_t, ucp: &ucontext_t): int = "mac#swapcontext"

%{
ucontext_t schedulerctx;

ucontext_t* getschedulerctx() {
  return &schedulerctx;
}

void setcontextstack (ucontext_t* ctx, char* stack, int stack_size) {
  printf ("Stack: %p, size: %d\n", stack, stack_size);
  ctx->uc_stack.ss_sp = stack;
  ctx->uc_stack.ss_size = stack_size;
  ctx->uc_link = getschedulerctx(); 
}
%}

extern fun setcontextstack {l:agz} {n:nat} (pf: !array_v (char?, n, l) | ucp: &ucontext_t, stack: ptr l, size: size_t n): void = "mac#setcontextstack"
extern fun getschedulerctx (): [l:agz] (ucontext_t @ l -<lin,prf> void, ucontext_t @ l | ptr l) = "mac#getschedulerctx"

viewtypedef  Task (l:addr, n:int) = @{ 
                                func= task_fn,
                                p_stack= ptr l,
                                pfgc_stack= free_gc_v (char?, n, l),
                                pfat_stack= array_v (char?, n, l),
                                stack_size= size_t n,
                                ctx= ucontext_t,
                                complete= bool
                              }
viewtypedef Task = [n:nat] [l:agz] Task (l, n)

assume task (l:addr) = @{ pfgc= free_gc_v (Task?, l), pfat= Task @ l, p= ptr l }

extern fun setcurrenttask {l:agz} (pf: !task l): void = "mac#setcurrenttask"
extern fun getcurrenttask (): [l:agz] (task l -<lin,prf> void | task l) = "mac#getcurrenttask"

implement scheduler_new () = let
  val (pfgc, pfat | p) = ptr_alloc<scheduler> ()
  val () = queue_initialize<task> (!p, 10)
in
  (pfgc, pfat | p)
end

implement scheduler_free (pfgc, pfat | p) = {
  fn clear1 {m,n:int | n > 0} (q: &QUEUE (task, m, n) >> QUEUE (task, m, n - 1)): void = {
    val tsk = queue_remove<task> (q)
    val () = task_free (tsk)
  }
  fun clear {m,n:int | n >= 0} (q: &QUEUE (task, m, n) >> QUEUE (task, m, 0)): void = 
    if queue_size (q) > 0 then (clear1 (q); clear (q)) else ()

  val () = assertloc (queue_size (!p) >= 0) 
  val () = clear (!p) 
  val () = queue_uninitialize_vt {task} (!p)
  val () = ptr_free (pfgc, pfat | p)
}

implement scheduler_initialize (s) = queue_initialize<task> (s, 10)

implement scheduler_uninitialize (s) = {
  fn clear1 {m,n:int | n > 0} (q: &QUEUE (task, m, n) >> QUEUE (task, m, n - 1)): void = {
    val tsk = queue_remove<task> (q)
    val () = task_free (tsk)
  }
  fun clear {m,n:int | n >= 0} (q: &QUEUE (task, m, n) >> QUEUE (task, m, 0)): void = 
    if queue_size (q) > 0 then (clear1 (q); clear (q)) else ()

  val () = assertloc (queue_size (s) >= 0) 
  val () = clear (s) 
  val () = queue_uninitialize_vt {task} (s)
}

implement scheduler_run (s) = 
  if queue_is_empty (s) then () else {
    val () = print_string ("a\n")
    val tsk = queue_remove<task> (s)
    val () = setcurrenttask (tsk)
    prval pfat = tsk.pfat
    val p = tsk.p
    val (pff_schedulerctx, pf_schedulerctx | p_schedulerctx) = getschedulerctx ()
    val r = swapcontext (!p_schedulerctx, !p.ctx)
    prval () = pff_schedulerctx (pf_schedulerctx)
    val () = print_string ("b\n")
    val () = assertloc (r = 0)
    val () = if !p.complete then {
               prval () = tsk.pfat := pfat
               val () = task_free (tsk)
             }
             else {
               prval () = tsk.pfat := pfat
               val cap = queue_cap (s)
               val sz = queue_size {task} (s)
               val () = if cap > 0 && sz = cap then {
                 val () = queue_update_capacity<task> (s, cap * 2)
               }  
               val () = assertloc (queue_size (s) < queue_cap (s)) 
               val () = queue_insert<task> (s, tsk)
             }
    val () = scheduler_run (s)
  }
 
(*
var task_scheduler: scheduler
val (pf_task_scheduler | ()) = vbox_make_view_ptr {scheduler?} (view@ task_scheduler | &task_scheduler)
*)

%{
void* task_scheduler = 0;

void settaskscheduler (void* s) {
  task_scheduler = s;
}

void* gettaskscheduler () {
  return task_scheduler;
}

void cleartaskscheduler () {
  task_scheduler = 0;
}

void* current_task = 0;

void setcurrenttask (void* t) {
  current_task = t;
}

void* getcurrenttask () {
  return current_task;
}

%}

fn task_callback (tsk: &Task): void = {
   val () = (tsk.func) ()
   val () = tsk.complete := true
}

implement task_create (func) = let
  val ss = size1_of_size (size_of_int 16384)
  val (pfgc_stack, pfat_stack | p_stack) = array_ptr_alloc<char> (ss)
  sta n:int
  sta l:addr
  val (pfgc_task, pfat_task | p_task) = ptr_alloc<Task (l,n)> ()
  val () = !p_task.func := func
  val () = !p_task.p_stack := p_stack
  val () = !p_task.pfgc_stack := pfgc_stack
  val () = !p_task.pfat_stack := pfat_stack
  val () = !p_task.stack_size := ss
  val () = !p_task.complete := false
  val r = getcontext (!p_task.ctx)
  val () = assertloc (r = 0)
  val () = setcontextstack (!p_task.pfat_stack | !p_task.ctx, !p_task.p_stack, !p_task.stack_size)
  val () = makecontext (!p_task.ctx, task_callback, 1, !p_task) where {
             extern fun makecontext (ucp: &ucontext_t, cb: (&Task) -<fun1> void, argc: int, tsk: &Task) : void = "mac#makecontext" 
           }
in
  @{ pfgc= pfgc_task, pfat= pfat_task, p= p_task }
end

implement task_free (tsk) = {
  prval pfat = tsk.pfat
  val () = cloptr_free (tsk.p->func)
  val () = array_ptr_free (tsk.p->pfgc_stack, tsk.p->pfat_stack | tsk.p->p_stack)
  prval () = tsk.pfat := pfat
  val () = ptr_free (tsk.pfgc, tsk.pfat | tsk.p)
}

fn check_scheduler_cap (sch: &scheduler): void = {
  val sz = queue_size (sch)
  val cap = queue_cap (sch)
  val () = if cap > 0 && sz = cap then {
             val () = queue_update_capacity<task> (sch, cap * 2)
           }  
}
 
implement task_schedule (tsk) = {
  val (pff, pf | p) = gettaskscheduler ()

  val () = check_scheduler_cap (!p)
  val () = assertloc (queue_size (!p) < queue_cap (!p))
  val () = queue_insert<task> (!p, tsk)
  prval () = pff (pf)
}

implement task_yield () = {
  val (pff_tsk | tsk) = getcurrenttask ()
  prval pfat = tsk.pfat
  val (pff_schedulerctx, pf_schedulerctx | p_schedulerctx) = getschedulerctx ()
  val r = swapcontext (tsk.p->ctx, !p_schedulerctx)
  val () = assertloc (r = 0)
  prval () = pff_schedulerctx (pf_schedulerctx)
  prval () = tsk.pfat := pfat
  prval () = pff_tsk (tsk)
}
  

