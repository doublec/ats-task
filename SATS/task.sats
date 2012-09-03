(*
** Copyright (C) 2012 Chris Double.
**
** Permission to use, copy, modify, and distribute this software for any
** purpose with or without fee is hereby granted, provided that the above
** copyright notice and this permission notice appear in all copies.
** 
** THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
** WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
** MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
** ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
** WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
** ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
** OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
*)
#define ATS_STALOADFLAG 0 // no need for staloading at run-time

staload "libats/SATS/linqueue_arr.sats"

absviewtype task (l:addr)
viewtypedef task = [l:agz] task l

absviewtype scheduler (l:addr) = ptr l
viewtypedef scheduler = [l:agz] scheduler l

fun scheduler_new (): scheduler
fun scheduler_free (sch: scheduler): void

fun scheduler_run {l:agz} (s: !scheduler l): void

absviewtype scheduler_v (l:addr) = ptr l

fun set_global_scheduler {l:agz} (sch: !scheduler l >> scheduler_v l): void = "mac#set_global_scheduler"
fun get_global_scheduler ():<> [l:agz] (scheduler l -<lin,prf> void | scheduler l) = "mac#get_global_scheduler"
fun unset_global_scheduler {l:agz} (sch: !scheduler_v l >> scheduler l): void = "mac#unset_global_scheduler"
fun run_global_scheduler (): void 

(* Returns the current running task, and schedules the next running
   task but doesn't switch to it. Caller must later call 'global_scheduler_resume'
   to start running the next running task. During these two calls code can
   save the task and manually queue it later. When resumed it will execute at the
   pointer after 'global_scheduler_resume' was called. *)
fun global_scheduler_halt (): task
fun global_scheduler_resume (): void
fun global_scheduler_queue_task (tsk: task): void 

viewtypedef task_fn = () -<cloptr1> void
viewtypedef task_fn_lin = () -<lincloptr1> void

fun task_create {n:nat} (stack_size: size_t n, func: task_fn): [l:agz] task l
fun task_free {l:agz} (tsk: task l): void
fun task_schedule {l:agz} (tsk: task l): void
fun task_spawn {n:nat} (stack_size: size_t n, func: task_fn): void
fun task_spawn_lin {n:nat} (stack_size: size_t n, func: task_fn_lin): void

fun task_yield (): void
fun task_queue_count ():<> size_t
fun task_paused_count ():<> size_t

