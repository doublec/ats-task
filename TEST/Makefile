######

ATSHOMEQ="$(ATSHOME)"
ATSCC=$(ATSHOMEQ)/bin/atscc
ATSCCLIB=$(shell pwd)/../..
ATSCTRB=\
  $(ATSCCLIB)/task/atsctrb_task.o
######

checkall: compall cleanall

######

compall: \
  test1 \
  test2

######

test1: test1.dats
	$(ATSCC) -I$(ATSCCLIB) -IATS$(ATSCCLIB) $(CFLAGS) -o $@ $< $(ATSCTRB) $(LIBS)

test2: test2.dats
	$(ATSCC) -I$(ATSCCLIB) -IATS$(ATSCCLIB) $(CFLAGS) `pkg-config libevent --cflags` -o $@ $< $(ATSCTRB) $(LIBS) `pkg-config libevent --libs`

######

clean:
	rm -f *_?ats.c *.o *~

cleanall: clean
	rm -f test1
	rm -f test2

###### end of [Makefile] ######
