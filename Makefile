KVER   ?= $(shell uname -r)
KDIR   ?= /lib/modules/$(KVER)/build/
DEPMOD  = /sbin/depmod -a
CC     ?= gcc
obj-m   = xt_ratelimit.o
CFLAGS_xt_ratelimit.o := -DDEBUG

all: xt_ratelimit.ko libxt_ratelimit.so

xt_ratelimit.ko: xt_ratelimit.c xt_ratelimit.h
	make -C $(KDIR) M=$(CURDIR) modules CONFIG_DEBUG_INFO=y
	-sync

%_sh.o: libxt_ratelimit.c xt_ratelimit.h
	gcc -O2 -Wall -Wunused -fPIC -o $@ -c $<$

%.so: %_sh.o
	gcc -shared -o $@ $<

clean:
	make -C $(KDIR) M=$(CURDIR) clean
	-rm -f *.so *_sh.o *.o modules.order

install: | minstall linstall

minstall: | xt_ratelimit.ko
	make -C $(KDIR) M=$(CURDIR) modules_install INSTALL_MOD_PATH=$(DESTDIR)

linstall: libxt_ratelimit.so
	install -D $< $(DESTDIR)$(shell pkg-config --variable xtlibdir xtables)/$<

uninstall:
	-rm -f $(DESTDIR)$(shell pkg-config --variable xtlibdir xtables)/libxt_ratelimit.so
	-rm -f $(KDIR)/extra/xt_ratelimit.ko

load: all
	-sync
	-modprobe x_tables
	-insmod xt_ratelimit.ko
	-iptables -I INPUT -m ratelimit --ratelimit-set test --ratelimit-mode src -j DROP
	-echo +127.0.0.1 1000000 > /proc/net/ipt_ratelimit/test
unload:
	-echo / > /proc/net/ipt_ratelimit/test
	-iptables -D INPUT -m ratelimit --ratelimit-set test --ratelimit-mode src -j DROP
	-rmmod xt_ratelimit.ko
del:
	-sync
	-echo -127.0.0.1 1000000 > /proc/net/ipt_ratelimit/test
reload: unload load

.PHONY: all minstall linstall install uninstall clean