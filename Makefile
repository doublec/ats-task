#
# Lightweight Tasks API
#
# Author: Chris Double (chris DOT double AT double DOT co DOT nz)
# Time: July, 2012
#

######
ATSHOMEQ="$(ATSHOME)"
ATSCC=$(ATSHOMEQ)/bin/atscc -Wall
ATSCCLIB=$(shell pwd)/..

######

all: atsctrb_task.o clean

######

atsctrb_task.o: task_dats.o
	ld -r -o $@ $<

######

task_dats.o: DATS/task.dats
	$(ATSCC) -I$(ATSCCLIB) -IATS$(ATSCCLIB) $(CFLAGS) -o $@ -c $<

######

clean::
	rm -f *_?ats.c *_?ats.o

cleanall: clean
	rm -f atsctrb_task.o

###### end of [Makefile] ######
