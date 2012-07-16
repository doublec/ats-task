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
%{#
#include <ucontext.h>
#include "contrib/task/CATS/task.cats"
%}


#define ATS_STALOADFLAG 0 // no need for staloading at run-time

staload "libats/SATS/linqueue_arr.sats"

abst@ype ucontext_t = $extype "ucontext_t"


absviewtype task (l:addr)
viewtypedef task = [l:agz] task l

viewtypedef scheduler = QUEUE0 (task)

(* Heap allocation of schedulers *)
fun scheduler_new (): [l:agz] (free_gc_v (scheduler?, l), scheduler @ l | ptr l)
fun scheduler_free {l:agz} (pfgc: free_gc_v (scheduler?, l), pfat: scheduler @ l | p: ptr l): void

(* Used for innitializing stack allocated schedulers *)
fun scheduler_initialize (s: &scheduler? >> scheduler):<> void
fun scheduler_uninitialize (s: &scheduler >> scheduler?): void

fun scheduler_run (s: &scheduler): void

absview scheduler_v (l:addr)

fun settaskscheduler {l:agz} (pf: scheduler @ l | p: ptr l): (scheduler_v l | void) = "mac#settaskscheduler"
fun gettaskscheduler (): [l:agz] (scheduler @ l -<lin,prf> void, scheduler @ l | ptr l) = "mac#gettaskscheduler"
fun cleartaskscheduler {l:agz} (pf: scheduler_v l | (* *)): (scheduler @ l | void) = "mac#cleartaskscheduler"
fun setcontextstack {l:agz} {n:nat} (pf: !array_v (char?, n, l) | ucp: &ucontext_t, stack: ptr l, size: size_t n): void = "mac#setcontextstack"
fun getschedulerctx (): [l:agz] (ucontext_t @ l -<lin,prf> void, ucontext_t @ l | ptr l) = "mac#getschedulerctx"

viewtypedef task_fn = () -<cloptr1> void
fun task_create (func: task_fn): [l:agz] task l
fun task_free {l:agz} (tsk: task l): void
fun task_schedule {l:agz} (tsk: task l): void
fun task_yield (): void

