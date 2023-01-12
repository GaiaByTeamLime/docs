watch:
	ls *.md *.bibtex Makefile | entr make build

build:
	for file in *.md; do pandoc --citeproc --lua-filter filter.lua --filter pandoc-plantuml -o $$file.pdf $$file; done
