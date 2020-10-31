# =====================================================================================
# =====================================================================================
# Prerequisites
# =====================================================================================
# =====================================================================================

# The following are "special targets", see:
# https://www.gnu.org/software/make/manual/html_node/Special-Targets.html#Special-Targets
# A phony target: not a file, just some routine.
.PHONY: clean mostlyclean preflight

# =====================================================================================
# Set variables, executables and their flags
# =====================================================================================

# Configure latexmk tool using '.latexmkrc' in project root, not in here.
LATEXMK = latexmk
LATEXMK_FLAGS =

PANDOC = pandoc
# For pandoc, provide dynamic metadata for the date. Git short SHA works both in CI and
# locally. All other settings are in the `defaults` file.
PANDOC_FLAGS = \
		--defaults=pandoc/defaults.yaml \
		--metadata=date:"$(shell date --iso-8601) ($(shell git rev-parse --short HEAD))"

# GitLab CI defines variables that we can check for. This allows us to detect if we're
# in a CI scenario.
# See also:
# https://www.gnu.org/software/make/manual/html_node/Conditional-Syntax.html#Conditional-Syntax
# https://docs.gitlab.com/ee/ci/variables/predefined_variables.html
ifdef CI
	# pandoc is quiet by default
	PANDOC_FLAGS += --verbose
	# After the run, display the relevant rules (for debugging)
	LATEXMK_FLAGS += --rules
else
	# latexmk is verbose by default
	LATEXMK_FLAGS += --quiet
endif

# =====================================================================================
# =====================================================================================
# Files to build
# =====================================================================================
# =====================================================================================

# Produce all found tex files, but only the README.md (not CHANGELOG.md etc.):
SRC := $(wildcard *.tex) README.md

# First rule is what is run by default if just using `make` with no arguments.
# It is the 'goal': https://www.gnu.org/software/make/manual/html_node/Goals.html.
# The name `all` is just a convention.
# Change suffix of multiple different extensions (.tex, .md), to the same suffix (.pdf).
# See also: https://stackoverflow.com/a/33926814
all: preflight $(addsuffix .pdf, $(basename $(SRC)))

# =====================================================================================
# Rules for file building
# =====================================================================================

# This Makefile uses implicit rules, see:
# https://www.gnu.org/software/make/manual/html_node/Implicit-Rules.html#Implicit-Rules
# For those, Automatic Variables are important:
# https://www.gnu.org/software/make/manual/html_node/Automatic-Variables.html
# $*: "The stem with which an implicit rule matches"
# $<: "The name of the first prerequisite"
# $@: "The file name of the target of the rule"
# $^: "The names of all the prerequisites, with spaces between them"

# Pattern rule, see:
# https://www.gnu.org/software/make/manual/html_node/Pattern-Rules.html,
# Just sets up an implicit rule to specify how to get from prerequisite to target,
# called whever `make` detects it needs to do so. No need to specify things manually.
%.pdf: %.tex
	$(info Running $(LATEXMK)...)
	@$(LATEXMK) $(LATEXMK_FLAGS) $<

PANDOC_TEMPLATE = $(strip $(shell grep "^template:" pandoc/defaults.yaml | cut --delimiter=":" --field=2))
PANDOC_TEMPLATE_DIR = /usr/share/pandoc/data/templates

%.pdf: %.md $(PANDOC_TEMPLATE_DIR)/$(PANDOC_TEMPLATE).latex
	$(info Running $(PANDOC)...)
	@$(PANDOC) $(PANDOC_FLAGS) --output=$@ $<

EISVOGEL_ARCHIVE = Eisvogel.tar.gz

# The `$(info ...)` function gives out-of-order logging, while `echo` works with the
# `wget` progress display.
$(PANDOC_TEMPLATE_DIR)/$(PANDOC_TEMPLATE).latex:
	@echo "Template not found at $@, downloading..."
	@wget --quiet --show-progress --no-clobber \
		"https://github.com/Wandmalfarbe/pandoc-latex-template/releases/latest/download/${EISVOGEL_ARCHIVE}"
	@echo "Extracting $(EISVOGEL_ARCHIVE)..."
	@tar --extract --file=${EISVOGEL_ARCHIVE} eisvogel.tex
	@echo "Moving template to $@. This is required for make to work reliably but \
		requires sudo privileges."
	@sudo mv eisvogel.tex $@

# =====================================================================================
# Help users install programs required for compilation and help debug.
# =====================================================================================
preflight:
	@echo "Checking presence of required libraries..."
	@ldconfig --print-cache | grep --silent "librsvg" || \
		(echo "librsvg missing: required by pandoc to convert files containing SVGs."; exit 69)
	@echo "Libraries OK."
# Output looks like: https://tex.stackexchange.com/a/311753/120853
	@$(LATEXMK) --commands

# For target name, see: https://www.gnu.org/prep/standards/html_node/Standard-Targets.html
mostlyclean:
	@echo "Removing generated and auxiliary files of all found TeX files..."
	@$(LATEXMK) -C $(LATEXMK_FLAGS)
	@echo "Remaining PDF files are (e.g. those generated by pandoc):"
	@ls *.pdf 2>/dev/null || echo "None."
	@echo "Removing all remaining PDF files..."
	@$(RM) *.pdf
	@echo "Removing downloaded pandoc archive, if any..."
	@$(RM) $(EISVOGEL_ARCHIVE)

clean: mostlyclean
	@echo "Removing all files ignored by git (.gitignore)..."
	@git clean --force -xd
