ACLOCAL_AMFLAGS = -I m4 ${ACLOCAL_FLAGS}
AM_MAKEFLAGS = --no-print-directory

dist_doc_DATA = AUTHORS README.md COPYING

AM_CPPFLAGS = \
    -include $(top_builddir)/config.h

AM_CFLAGS = ${my_CFLAGS}

bin_PROGRAMS = cpio-builder

cpio_builder_SOURCES = cpio-builder.c

#cpio_builder_LDADD = -lmodbus

CLEANFILES = *~
