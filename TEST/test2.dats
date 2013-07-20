staload "prelude/SATS/unsafe.sats"
staload "libevent/SATS/libevent.sats"

staload "task/SATS/task.sats"
dynload "task/DATS/task.dats"

staload _ = "prelude/DATS/array.dats"

val [lbase:addr] b = event_base_new ()
val () = assertloc (~b)
var the_base: event_base1 = b
val (pf_the_base | ()) = vbox_make_view_ptr {event_base lbase} (view@ the_base | &the_base)

fun get_request_input_string (req: !evhttp_request1): [l:agz] strptr l = let
  extern fun __strndup {l:agz} (str: !strptr l, n: size_t): [l2:agz] strptr l2 = "mac#strndup"
  val (pff_buffer | buffer) = evhttp_request_get_input_buffer(req)
  val len = evbuffer_get_length(buffer)
  val (pff_src | src) = evbuffer_pullup(buffer, ssize_of_int(~1))
  val r = __strndup(src, len)
  prval () = pff_src(src)
  prval () = pff_buffer(buffer)
in
  r
end

fun evbuffer_of_string (s: string): [l:agz] evbuffer l = let
  val buffer = evbuffer_new ()
  val () = assertloc (~buffer)

  val s = string1_of_string (s)
  val r = evbuffer_add_string (buffer, s, string1_length (s))
  val () = assertloc (r = 0)
in
  buffer
end

dataviewtype http_result (l:addr) =
  | http_result_string (l) of ([l > null] strptr l)
  | http_result_error (null) of (int)

viewtypedef http_result1 = [l:addr] http_result l
viewtypedef http_callback = (http_result1) -<lincloptr1> void

dataviewtype http_data (lc:addr) = http_data_container (lc) of (evhttp_connection lc, http_callback)

fun handle_http {l:agz} (client: !evhttp_request1, c: http_data l):void = let
  val ~http_data_container (cn, cb) = c
  val code = if evhttp_request_isnot_null (client) then evhttp_request_get_response_code(client) else 501
in
  if code = HTTP_OK then {
    val result = get_request_input_string (client)
    val () = cb (http_result_string result)
    val () = cloptr_free (cb)
    val () = evhttp_connection_free (cn)
  }
  else {
    val () = cb (http_result_error (code))
    val () = cloptr_free (cb)
    val () = evhttp_connection_free (cn)
  }
end

typedef evhttp_callback (t1:viewt@ype) = (!evhttp_request1, t1) -> void
extern fun evhttp_request_new {a:viewt@ype} (callback: evhttp_callback (a), arg: a): evhttp_request0 = "mac#evhttp_request_new"

fun http_request (url: string, cb: http_callback): void = {
  val uri = evhttp_uri_parse (url)
  val () = assertloc (~uri)

  val (pff_host | host) = evhttp_uri_get_host (uri)
  val () = assertloc (strptr_isnot_null (host))

  val port = evhttp_uri_get_port (uri)
  val port = uint16_of_int (if port < 0 then 80 else port)

  val (pff_path | path) = evhttp_uri_get_path (uri)
  val () = assertloc (strptr_isnot_null (path))

  val () = printf("Trying %s:%d\n", @(castvwtp1 {string} (host), int_of_uint16 port))
  val [lc:addr] cn = make_connection (castvwtp1 {string} (host), port) where {
                       fun make_connection (host: string, port: uint16): evhttp_connection1 = let
                         prval vbox pf = pf_the_base
                       in
                         $effmask_ref evhttp_connection_base_new(the_base, null, host, port)
                       end
                     }
  val () = assertloc (~cn)

  (* Copy a reference to the connection so we can pass it to the callback when the request is made *)
  val c = __ref (cn) where { extern castfn __ref {l:agz} (b: !evhttp_connection l): evhttp_connection l }
  val container = http_data_container (c, cb)

  val client = evhttp_request_new {http_data lc} (handle_http, container) 
  val () = assertloc (~client)

  val (pff_headers | headers) = evhttp_request_get_output_headers(client)
  val r = evhttp_add_header(headers, "Host", castvwtp1 {string} (host))
  val () = assertloc (r = 0)

  val r = evhttp_make_request(cn, client, EVHTTP_REQ_GET, castvwtp1 {string} (path))
  val () = assertloc (r = 0)

  (* The connection is freed when the callback for the request is handled *)
  prval () = __unref (cn) where { extern prfun __unref {l:agz} (b: evhttp_connection l): void }

  prval () = pff_path (path)
  prval () = pff_host (host)
  prval () = pff_headers (headers)
  val () = evhttp_uri_free (uri)
}

fun download (url: string): http_result1 = let
  val tsk = global_scheduler_halt ()
  var result: http_result1
  prval (pff, pf) = __borrow (view@ result) where {
                      extern prfun __borrow {l:addr} (r: !http_result1? @ l >> (http_result1 @ l))
                                      : (http_result1 @ l -<lin,prf> void, http_result1? @ l)
                    }
  val () = http_request (url, llam (r) => {
                                val () = global_scheduler_queue_task (tsk)
                                val () = result := r
                                prval () = pff (pf)
                              })
  val () = global_scheduler_resume ()
in
  result
end
   
fn do_main (): void = {
  fn print_result (r: http_result1): void = 
    case+ r of 
    | ~http_result_string s => (print_strptr (s); print_newline (); strptr_free (s))
    | ~http_result_error code => printf("Code: %d", @(code))

  val () = print_result (download ("http://www.ats-lang.org/"))
  val () = print_result (download ("http://www.bluishcoder.co.nz/"))
}

fun event_loop_task (events_queued: bool): void = let
  prval vbox pf = pf_the_base
  val () = $effmask_ref task_yield ()
in
  (* If no events are queued and if no tasks are also queued we can exit *)
  if (not events_queued && task_queue_count () + task_paused_count () = 0) then ()

  (* We're the only active task left, safe to block *)
  else if task_queue_count () = 0 then $effmask_ref event_loop_task ($effmask_ref event_base_loop (the_base, EVLOOP_ONCE) = 0)

  (* Other tasks are waiting, we can't block *)
  else $effmask_ref event_loop_task ($effmask_ref event_base_loop (the_base, EVLOOP_NONBLOCK) = 0)
end

implement main(argc, argv) = {
  var sch = scheduler_new ()
  val () = set_global_scheduler (sch)

  val () = task_spawn (16384, lam () => do_main ())
  val () = task_spawn (16384, lam () => event_loop_task (true))
  
  val () = run_global_scheduler ()

  val () = unset_global_scheduler (sch)
  val () = scheduler_free (sch)

  prval vbox pf = pf_the_base
  val () = $effmask_ref event_base_free (the_base) 
  prval () = pf := __fixup (pf) where { extern prfun __fixup {l,l2:agz} (l: event_base l? @ l2): event_base l @ l2 }
}


