######

ATSHOMEQ="$(ATSHOME)"
ATSCC=$(ATSHOMEQ)/bin/atscc
ATSCTRB=\
  $(ATSHOMEQ)/contrib/task/atsctrb_task.o
######

checkall: compall cleanall

######

compall: \
  test1 \
  test2

######

test1: test1.dats
	$(ATSCC) $(CFLAGS) -o $@ $< $(ATSCTRB) $(LIBS)

test2: test2.dats
	$(ATSCC) $(CFLAGS) `pkg-config libevent --cflags` -o $@ $< $(ATSCTRB) $(LIBS) `pkg-config libevent --libs`

######

clean:
	rm -f *_?ats.c *.o *~

cleanall: clean
	rm -f test1
	rm -f test2

###### end of [Makefile] ######
