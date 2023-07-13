# Need to specify bash in order for conda activate to work.
SHELL=/bin/bash

PYTHON ?= python3

ENV ?= super_hydro
CONDA_EXE ?= conda
#CONDA_EXE = mamba

# Note that the extra activate is needed to ensure that the activate floats env to the front of PATH
CONDA_ACTIVATE=source $$(conda info --base)/etc/profile.d/conda.sh ; conda activate base; conda activate

CONDA_ENVS = ./envs
CONDA_FLAGS = --prefix $(CONDA_ENVS)/$(ENV)

#RUN = $(CONDA_EXE) run $(CONDA_FLAGS)
RUN = $(ANACONDA_PROJECT) run
REFRESH = 
REFRESH ?= --refresh

ACTIVATE ?= eval "$$(conda shell.bash hook)" && conda activate
AP_PRE ?= CONDA_EXE=$(CONDA_EXE)

ENV_PATH ?= $(abspath envs/$(ENV))
ACTIVATE_PROJECT ?= $(ACTIVATE) $(ENV_PATH)
ANACONDA_PROJECT ?= anaconda-project

# We have some build issues on the ARM environment, use Rosetta to emulate the osc-64 platform.
USE_ARM ?= true

ifneq ($(USE_ARM), true)
ifeq ($(shell uname -p),arm)
  CONDA_SUBDIR=osx-64
endif
endif

ifdef CONDA_SUBDIR
  AP_PRE += CONDA_SUBDIR=$(CONDA_SUBDIR)
endif

USE_CONDA = true
######################################################################
# Default target runs init and then echos commands to activate
go: init-user
	echo "conda deactivate"

dev: init-dev
init: init-dev
shell: init-dev
	$(AP_PRE) $(ANACONDA_PROJECT) run shell

######################################################################
# Installation
init-user: Docs/sphinx-source/_static/mathjax
ifeq ($(USE_CONDA), true)
	$(AP_PRE) $(ANACONDA_PROJECT) prepare --env-spec $(ENV)
ifdef CONDA_SUBDIR
	$(ACTIVATE_PROJECT) && conda config --env --set subdir $(CONDA_SUBDIR)
endif
	$(AP_PRE) $(ANACONDA_PROJECT) run init-user
	$(ACTIVATE_PROJECT) && poetry install -E docs -E tests -E fftw
else
	$(PYTHON) -m venv .venv
	poetry install -E fftw
endif

init-dev: Docs/sphinx-source/_static/mathjax
ifeq ($(USE_CONDA), true)
	$(AP_PRE) $(ANACONDA_PROJECT) prepare $(REFRESH) --env-spec $(ENV)
ifdef CONDA_SUBDIR
	$(ACTIVATE_PROJECT) && conda config --env --set subdir $(CONDA_SUBDIR)
endif
	$(AP_PRE) $(ANACONDA_PROJECT) run init
	$(ACTIVATE_PROJECT) && poetry install -E docs -E tests -E fftw
else
	$(PYTHON) -m venv .venv
	poetry install -E docs -E tests -E fftw
endif

conda-env: environment-cpu.yaml
	$(CONDA_EXE) env create $(CONDA_FLAGS) -f $<
	$(RUN) python3 -m pip install .
	$(CONDA_EXE) config --append envs_dirs $(CONDA_ENVS)

conda-env-gpu: environment-gpu.yaml
	$(CONDA_EXE) env create $(CONDA_FLAGS) -f $<
	$(RUN) python3 -m pip install .[gpu]
	$(CONDA_EXE) config --append envs_dirs $(CONDA_ENVS)

environment-cpu.yaml: pyproject.toml
	poetry2conda -E docs -E tests $< $@

environment-gpu.yaml: pyproject.toml
	poetry2conda -E gpu -E docs -E tests $< $@

Docs/sphinx-source/_static/mathjax:
	git clone https://github.com/mathjax/MathJax.git mj-tmp
	mv mj-tmp/es5 $@
	rm -rf mj-tmp

install: Jupyter_Canvas_Widget jupyter-canvas-widget

clean:
	-find . -name "__pycache__" -exec $(RM) -r {} +
	-rm -rf .nox
	-conda clean -y --all

real-clean: clean
	cd Docs && make clean 
	rm -rf .conda
	-conda config --remove env_dirs $(CONDA_ENVS)
	find . -type d -name "__pycache__" -exec rm -rf "{}" +

.PHONY: go dev shell init-user init-dev real-clean clean install uninstall conda-env conda-env-gpu

######################################################################
# Documentation

doc-server:
	$(RUN) sphinx-autobuild --open-browser \
      --ignore '*/Docs/_build/*'         \
      --watch src                        \
      Docs/sphinx-source/ Docs/_build/html 

.PHONY: doc-server

######################################################################
# Jupytext
pair:
	find . -name ".ipynb_checkpoints" -prune -o \
	       -name "_ext" -prune -o \
	       -name "envs" -prune -o \
	       -name "*.ipynb" \
	       -exec jupytext --set-formats ipynb,myst {} + 

sync:
	find . -name ".ipynb_checkpoints" -prune -o \
	       -name "_ext" -prune -o \
	       -name "envs" -prune -o \
	       -name "*.ipynb" -o -name "*.md" \
	       -exec jupytext --sync {} + 2> >(grep -v "is not a paired notebook" 1>&2)
# See https://stackoverflow.com/a/15936384/1088938 for details

.PHONY: pair sync

# Old stuff
jupyter-canvas-widget:
	. /data/apps/conda/etc/profile.d/conda.sh                          && \
	conda activate jupyter                                             && \
	pip install -e _ext/jupyter-canvas-widget                          && \
	jupyter nbextension install --py --symlink --sys-prefix fastcanvas && \
	jupyter nbextension enable --py --sys-prefix fastcanvas            && \
	pip uninstall fastcanvas                                           && \
	conda deactivate
	. /data/apps/conda/etc/profile.d/conda.sh                          && \
	conda activate $(ENV)                                              && \
	pip install -e _ext/jupyter-canvas-widget                          && \
	conda deactivate

Jupyter_Canvas_Widget:
	. /data/apps/conda/etc/profile.d/conda.sh                          && \
	conda activate jupyter                                             && \
	pip install -e _ext/Jupyter_Canvas_Widget                          && \
	jupyter nbextension install --py --symlink --sys-prefix jpy_canvas && \
	jupyter nbextension enable --py --sys-prefix jpy_canvas            && \
	pip uninstall jpy_canvas                                           && \
	conda deactivate
	. /data/apps/conda/etc/profile.d/conda.sh                          && \
	conda activate $(ENV)                                              && \
	pip install -e _ext/Jupyter_Canvas_Widget                          && \
	conda deactivate

uninstall:
	. /data/apps/conda/etc/profile.d/conda.sh                          && \
	conda activate jupyter                                             && \
	jupyter nbextension uninstall --sys-prefix fastcanvas              && \
	jupyter nbextension uninstall --sys-prefix jpy_canvas              && \
	conda deactivate
	. /data/apps/conda/etc/profile.d/conda.sh                          && \
	conda activate $(ENV)                                              && \
	pip uninstall fastcanvas jpy_canvas                                && \
	conda deactivate


.PHONY: sync real-clean clean install uninstall jupyter-canvas-widget Jupyter_Canvas_Widget conda-env

# Default prints a help message
help:
	@make usage


usage:
	@echo "$$HELP_MESSAGE"

.PHONY: help, usage
# ----- Usage -----

define HELP_MESSAGE

This Makefile provides several tools to help initialize the project.  It is primarly designed
to help get a CoCalc project up an runnning, but should work on other platforms.

Variables:
   ANACONDA2020: (= "$(ANACONDA2020)")
                     If defined, then we assume we are on CoCalc and use this to activate
                     the conda base envrionment. Otherwise, you must make sure that the ACTIVATE
                     command works properly.
   ACTIVATE: (= "$(ACTIVATE)")
                     Command to activate a conda environment as `$$(ACTIVATE) <env name>`
                     Defaults to `conda activate`.
   ANACONDA_PROJECT: (= "$(ANACONDA_PROJECT)")
                     Command to run the `anaconda-project` command.  If you need to first
                     activate an environment (as on CoCalc), then this should do that.
                     Defaults to `anaconda-project`.
   ENV: (= "$(ENV)")
                     Name of the conda environment user by the project.
                     (Customizations have not been tested.)
                     Defaults to `phys-581-2021`.
   ENV_PATH: (= "$(ENV_PATH)")
                     Path to the conda environment user by the project.
                     (Customizations have not been tested.)
                     Defaults to `envs/$$(ENV)`.
   ACTIVATE_PROJECT: (= "$(ACTIVATE_PROJECT)")
                     Command to activate the project environment in the shell.
                     Defaults to `$$(ACTIVATE)  $$(ENV)`.
   USE_ARM: (= "$(USE_ARM)")
                     If on an ARM processor, like the Mac M1 or M2, then use this environment.
                     Otherwise, we set CONDA_SUBDIR=osx-64 so that we install the x64 binaries
                     and use rosetta.  This overcomes some limitations with libraries that are
                     not yet ready for the ARM platform.

Initialization:
   make [go]         Initialize the environments needed to run the applications.  Does not
                     install the development tools needed for testing, building documentation
                     etc.
   make init-user    Initialize the environment and kernel for users.
   make init-dev     Initialize the environment and kernel.  On CoCalc we do specific things
                     like install mmf-setup, and activate the environment in ~/.bash_aliases.
                     This is done by `make init` if ANACONDA2020 is defined.

Testing:
   make test         Runs the general tests.

Maintenance:
   make clean        Call conda clean --all: saves disk space.
   make real-clean   delete the environments and kernel as well.

Documentation:
   make doc-server   Build the html documentation server on http://localhost:8000
                     Uses Sphinx autobuild
   make pair         Find all notebooks, and pair them with MyST .md files.
   make sync         Sync all paird notebooks.
endef
export HELP_MESSAGE
