staload "contrib/task/SATS/task.sats"

staload _ = "prelude/DATS/pointer.dats"
staload _ = "prelude/DATS/array.dats"
staload _ = "prelude/DATS/option_vt.dats"

staload "libats/SATS/linqueue_arr.sats"
staload _ = "libats/DATS/linqueue_arr.dats"
staload _ = "prelude/DATS/array.dats"
staload _ = "libats/ngc/DATS/deque_arr.dats"

%{^
#include <ucontext.h>

void setcontextstate (ucontext_t* ctx, char* stack, int stack_size, ucontext_t* sch_ctx);
void set_global_scheduler (void* s);
void* get_global_scheduler ();
void unset_global_scheduler ();
%}

abst@ype ucontext_t = $extype "ucontext_t"

extern fun setcontext (ucp: &ucontext_t): int = "mac#setcontext"
extern fun getcontext (ucp: &ucontext_t? >> ucontext_t): int = "mac#getcontext"
extern fun makecontext (ucp: &ucontext_t, func: () -<fun1> void, argc: int (*, ... *)): void = "mac#makecontext" 
extern fun swapcontext (oucp: &ucontext_t, ucp: &ucontext_t): int = "mac#swapcontext"

viewtypedef scheduler_state = @{
                                 tasks= QUEUE0 (task),
                                 ctx= ucontext_t,
                                 running= Option_vt task
                              }

assume scheduler (l:addr) = @{ pfgc= free_gc_v (scheduler_state?, l), pfat= scheduler_state @ l, p= ptr l }

viewtypedef  task_state (l:addr, n:int) = @{ 
                                func= task_fn,
                                p_stack= ptr l,
                                pfgc_stack= free_gc_v (char?, n, l),
                                pfat_stack= array_v (char?, n, l),
                                stack_size= size_t n,
                                ctx= ucontext_t,
                                complete= bool
                              }
viewtypedef task_state = [n:nat] [l:agz] task_state (l, n)

assume task (l:addr) = @{ pfgc= free_gc_v (task_state?, l), pfat= task_state @ l, p= ptr l }


implement scheduler_new () = let
  val (pfgc, pfat | p) = ptr_alloc<scheduler_state> ()
  val () = queue_initialize<task> (!p.tasks, 10)
  val () = !p.running := None_vt 
  val r = getcontext (!p.ctx)
  val () = assertloc (r = 0)
in
  @{ pfgc= pfgc, pfat= pfat, p= p }
end

implement scheduler_free (sch) = {
  fn clear1 {m,n:int | n > 0} (q: &QUEUE (task, m, n) >> QUEUE (task, m, n - 1)): void = {
    val tsk = queue_remove<task> (q)
    val () = task_free (tsk)
  }
  fun clear {m,n:int | n >= 0} (q: &QUEUE (task, m, n) >> QUEUE (task, m, 0)): void = 
    if queue_size (q) > 0 then (clear1 (q); clear (q)) else ()

  prval pfat = sch.pfat
  val () = assertloc (queue_size (sch.p->tasks) >= 0) 
  val () = clear (sch.p->tasks) 
  val () = queue_uninitialize_vt {task} (sch.p->tasks)
  
  val () = case+ sch.p->running of
           | ~None_vt () => ()
           | ~Some_vt task => task_free (task)

  prval () = sch.pfat := pfat
  val () = ptr_free (sch.pfgc, sch.pfat | sch.p)
}

fn check_scheduler_cap (sch: &scheduler_state): void = {
  val sz = queue_size (sch.tasks)
  val cap = queue_cap (sch.tasks)
  val () = if cap > 0 && sz = cap then {
             val () = queue_update_capacity<task> (sch.tasks, cap * 2)
           }  
}
 
implement scheduler_run (sch) = {
  fun run (s: &scheduler_state): void =
    if queue_is_empty (s.tasks) then () else {
      val () = assertloc (option_vt_is_none (s.running))
      val () = option_vt_unnone (s.running)
      val tsk = queue_remove<task> (s.tasks)
      val (pff_running | running) = __borrow (tsk) where {
                                      extern castfn __borrow {l:agz} (tsk: !task l): (task l -<lin,prf> void | task l)
                                    }
      val () = s.running := Some_vt (tsk)
      prval pfat = running.pfat
      val r = swapcontext (s.ctx, running.p->ctx)
      val () = assertloc (r = 0)
      prval () = running.pfat := pfat
      prval () = pff_running (running)
      val () = assertloc (option_vt_is_some (s.running))
      val tsk = option_vt_unsome<task> (s.running)
      val () = s.running := None_vt ()

      prval pfat = tsk.pfat
      val () = if tsk.p->complete then {
                 prval () = tsk.pfat := pfat
                 val () = task_free (tsk)
               }
               else {
                 prval () = tsk.pfat := pfat
                 val () = check_scheduler_cap (s)
                 val () = assertloc (queue_size (s.tasks) < queue_cap (s.tasks)) 
                 val () = queue_insert<task> (s.tasks, tsk)
               }

      val () = run (s)
    }

  prval pfat = sch.pfat
  val () = run (!(sch.p))
  prval () = sch.pfat := pfat
}

implement run_global_scheduler () = {
  val (pff_s | s) = get_global_scheduler ()
  val () = scheduler_run (s)
  prval () = pff_s (s)
} 

%{
void setcontextstate (ucontext_t* ctx, char* stack, int stack_size, ucontext_t* sch_ctx) {
  ctx->uc_stack.ss_sp = stack;
  ctx->uc_stack.ss_size = stack_size;
  ctx->uc_link = sch_ctx;
}
%}

extern fun setcontextstate {l:agz} {n:nat} (pf: !array_v (char?, n, l) | ucp: &ucontext_t, stack: ptr l, size: size_t n, sch_ctx: &ucontext_t): void = "mac#setcontextstate"

(*
var task_scheduler: scheduler
val (pf_task_scheduler | ()) = vbox_make_view_ptr {scheduler?} (view@ task_scheduler | &task_scheduler)
*)

%{
void* task_scheduler = 0;

void set_global_scheduler (void* s) {
  task_scheduler = s;
}

void* get_global_scheduler () {
  return task_scheduler;
}

void unset_global_scheduler () {
  task_scheduler = 0;
}

%}

fn task_callback (tsk: &task_state): void = {
   val () = (tsk.func) ()
   val () = tsk.complete := true
}

implement task_create (ss, func) = let
  val (pfgc_stack, pfat_stack | p_stack) = array_ptr_alloc<char> (ss)
  sta n:int
  sta l:addr
  val (pfgc_task, pfat_task | p_task) = ptr_alloc<task_state (l,n)> ()
  val () = !p_task.func := func
  val () = !p_task.p_stack := p_stack
  val () = !p_task.pfgc_stack := pfgc_stack
  val () = !p_task.pfat_stack := pfat_stack
  val () = !p_task.stack_size := ss
  val () = !p_task.complete := false
  val r = getcontext (!p_task.ctx)
  val () = assertloc (r = 0)

  val (pff_sch | sch) = get_global_scheduler ()
  prval pfat = sch.pfat
  val () = setcontextstate (!p_task.pfat_stack | !p_task.ctx, !p_task.p_stack, !p_task.stack_size, sch.p->ctx)
  prval () = sch.pfat := pfat
  prval () = pff_sch (sch)

  val () = makecontext (!p_task.ctx, task_callback, 1, !p_task) where {
             extern fun makecontext (ucp: &ucontext_t, cb: (&task_state) -<fun1> void, argc: int, tsk: &task_state) : void = "mac#makecontext" 
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

implement task_schedule (tsk) = {
  val (pff_sch | sch) = get_global_scheduler ()
  prval pfat = sch.pfat
  val () = check_scheduler_cap (!(sch.p))
  val () = assertloc (queue_size (sch.p->tasks) < queue_cap (sch.p->tasks))
  val () = queue_insert<task> (sch.p->tasks, tsk)
  prval () = sch.pfat := pfat
  prval () = pff_sch (sch)
}

implement task_spawn (ss, func) = task_schedule (task_create (ss, func))

implement task_yield () = {
  val (pff_sch | sch) = get_global_scheduler ()
  prval pfat_sch = sch.pfat
  val () = assertloc (option_vt_is_some (sch.p->running))
  val tsk = option_vt_unsome<task> (sch.p->running)
  val (pff_running | running) = __borrow (tsk) where {
                                 extern castfn __borrow {l:agz} (tsk: !task l): (task l -<lin,prf> void | task l)
                                }
  val () = sch.p->running := Some_vt tsk
 
  prval pfat_tsk = running.pfat
  val r = swapcontext (running.p->ctx, sch.p->ctx)
  val () = assertloc (r = 0)
  prval () = running.pfat := pfat_tsk
  prval () = pff_running (running)
  prval () = sch.pfat := pfat_sch
  prval () = pff_sch (sch)
}
  

