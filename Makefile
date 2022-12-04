 # ---------------------------------------------INFORMATION--------------------------------------------
 # 	Project Name: AnimeRSSforTSDM
 #	Author: Kelvin Lee 李冠霖
 #	Version: 1.0
 #	Environment: Linux
 # 	Date: 2022/06/02  12:02
 # ===================================================================================================*/
SHELL := /bin/bash
CFLAGS := -g
CC = gcc
SRC = $(wildcard *.c)
OBJ = $(SRC:.c=.o)
EXE = anime
NORMAL = \033[0m
RED = \033[1;31m
YELLOW = \033[1;33m
WHITE = \033[1;37m

.PHONY: clean test dep main check debug _debug memchk

all: clean dep main install

dep:
	@touch .depend
	@echo creating dependency file...
	@for n in $(SRC); do \
		$(CC) $(CFLAGS) -E -MM $$n >> .depend; \
	done
-include .depend

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

main: $(OBJ)
	$(CC) $(CFLAGS) $(OBJ) -o $(EXE)

install: install_c clean
	
install_c: $(EXE)
	mv -fv $(EXE) /usr/local/bin/

clean:
	@rm -fv $(OBJ) $(EXE) .depend

#============================================= Optional =============================================
debug: CFLAGS += -DDEBUG_MODE
debug: all

memchk:
	valgrind --leak-check=full ./$(EXE) > /dev/null 2> res2
	valgrind -v --track-origins=yes --leak-check=full ./$(EXE) > /dev/null 2> res3
