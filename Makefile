.POSIX:
.SUFFIXES: .el .elc

EMACS = emacs
RM = rm -f

compile: README kixtart-mode.elc

check: kixtart-mode-tests.elc
	$(EMACS) --batch --quick \
	    --directory . \
	    --load kixtart-mode-tests.elc \
	    --funcall ert-run-tests-batch

kixtart-mode-tests.elc: kixtart-mode.elc kixtart-mode-tests.el

.el.elc:
	$(EMACS) --batch --quick \
	    --directory . \
	    --funcall batch-byte-compile $<

README: kixtart-mode.el
	$(EMACS) --batch --quick \
	    --load lisp-mnt \
	    --eval "(with-temp-file \"$@\" \
	              (insert (lm-commentary \"kixtart-mode.el\")) \
	              (insert \"\\n\"))"

clean:
	$(RM) README kixtart-mode-tests.elc kixtart-mode.elc
