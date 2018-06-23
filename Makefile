#
# use gmake in FreeBSD

UNAME_S := $(shell uname -s)

ifeq ($(UNAME_S), FreeBSD)
	CC=cc
else
	CC=gcc
endif

all:
	$(CC) -Wall -O2 busy_app_demo.c -o busy_app.out

clean:
	rm -rf *.out *.dSYM
