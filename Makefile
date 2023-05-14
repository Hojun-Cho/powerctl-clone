.POSIX:
.PREFIXES:
HARE=hare
SCDOC=scdoc

PREFIX=/usr/local
BINDIR=$(PREFIX)/bin
MANDIR=$(PREFIX)/share/man
DESTDIR=

all: powerctl docs

powerctl: *.ha
	hare build -o powerctl

powerctl.8: powerctl.8.scd
	scdoc < powerctl.8.scd > powerctl.8

docs: powerctl.8

clean:
	$(RM) powerctl.8
	$(RM) powerctl

install: powerctl.8 powerctl
	mkdir -p $(DESTDIR)/$(BINDIR)
	mkdir -p $(DESTDIR)/$(MANDIR)/man8
	install -Dm644 powerctl.8 $(DESTDIR)/$(MANDIR)/man8/powerctl.8
	install -Dm755 powerctl $(DESTDIR)/$(BINDIR)/powerctl
	chmod u+s $(DESTDIR)/$(BINDIR)/powerctl

uninstall:
	$(RM) $(DESTDIR)/$(MANDIR)/man8/powerctl.8
	$(RM) $(DESTDIR)/$(BINDIR)/powerctl

.PHONY: all docs clean install uninstall
