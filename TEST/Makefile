######

ATSHOMEQ="$(ATSHOME)"
ATSCC=$(ATSHOMEQ)/bin/atscc
ATSCTRB=\
  $(ATSHOMEQ)/contrib/task/atsctrb_task.o
######

checkall: compall cleanall

######

compall: \
  test1

######

test1: test1.dats
	$(ATSCC) $(CFLAGS) -o $@ $< $(ATSCTRB) $(LIBS)

######

clean:
	rm -f *_?ats.c *.o *~

cleanall: clean
	rm -f test1

###### end of [Makefile] ######
