
#SWUDIRS = $(shell find swu -maxdepth 1 -mindepth 1 -type d)
SWUFILES = $(shell find swu -maxdepth 1 -mindepth 1 -type d -printf %f.swu\\n)

SRC  = index.html
SRC += js/swupdate.js
SRC += images/logo.png
SRC += images/favicon.png
SRC += scss/bootstrap.scss
SRC += gulpfile.js

WEBAPP = webapp.tar.gz

.PHONY: all install

all: $(WEBAPP)

install: $(WEBAPP)
	@install -d $(DESTDIR)
	@install $(WEBAPP) $(DESTDIR)

# use cpio with dereference and set root:root as owner
%.swu: swu/%
	@(  cd $^; \
	   (echo sw-description; find -L . -type f ! -name sw-description ! -path "./.gen/*" )\
	   | cpio -ov -H crc -L -R 0:0 \
	) > $@ || (rm $@ && false)

js_gen.sh: script_gen.sh  $(SWUFILES)
	@bash script_gen.sh > $@ && chmod +x $@

$(WEBAPP): $(SRC) $(SWUFILES) js_gen.sh
	@mkdir -p dist
	@npm install
	@sed -i "s/maxFilesize: 256/maxFilesize: 768/" node_modules/dropzone/dist/dropzone.js
	@npm run build
	@cp $(SWUFILES) dist
	@cp js_gen.sh dist
	@npm run package -- --output webapp


clean:
	-@rm -f *.swu
	-@rm -rf dist
	-@rm -f $(WEBAPP)
	-@rm -f script_gen.sh

