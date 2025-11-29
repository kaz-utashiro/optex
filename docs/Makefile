.DELETE_ON_ERROR:

LANGS    := JA KO ZH
RM_LANGS ?= $(LANGS)
ENGINES  := deepl
XLANGS   := JA
XENGINES := gpt5

GET_README  := perl -MTOML -0777E 'say from_toml(<>)->{readme_from}'
README_FROM := $(shell $(GET_README) ../minil.toml)
ifneq ($(README_FROM),)
  MOD_PATH := ../$(README_FROM)
  MOD_NAME := $(notdir $(MOD_PATH))
  ORIGIN   := $(MOD_PATH)
  POD      := $(MOD_NAME).pod
else
  MOD_NAME := $(shell perl -MJSON -0777E 'say decode_json(<>)->{name}' ../META.json)
  MOD_PATH := ../lib/$(subst -,/,$(MOD_NAME)).pm
  MOD_FILE := $(notdir $(MOD_PATH))
  MOD_DIR  := $(dir $(MOD_PATH))
  MOD_NAME := $(MOD_FILE:.pm=)
  ORIGIN   := $(MOD_PATH)
  PM       := $(notdir $(ORIGIN))
  POD      := $(PM:.pm=.pod)
endif

SRC_DIR  :=
SRC      := $(POD:%=$(if $(SRC_DIR),$(SRC_DIR)/,)%)
NAMES    := $(POD:%=$(notdir %))
PODS     := $(foreach engin,$(ENGINES),$(foreach lang,$(LANGS),$(SRC:.pod=.$(engin)-$(lang).pod)))
MDS      := $(foreach engin,$(ENGINES),$(foreach lang,$(LANGS),$(NAMES:.pod=.$(engin)-$(lang).md)))
READMES  := $(foreach engin,$(ENGINES),$(RM_LANGS:%=../README.$(engin)-%.md))
###########
# Translate only JA by gpt-5
#----------
PODS     += $(foreach engin,$(XENGINES),$(foreach lang,$(XLANGS),$(SRC:.pod=.$(engin)-$(lang).pod)))
MDS      += $(foreach engin,$(XENGINES),$(foreach lang,$(XLANGS),$(NAMES:.pod=.$(engin)-$(lang).md)))
READMES  += $(foreach engin,$(XENGINES),$(XLANGS:%=../README.$(engin)-%.md))
###########
ALL      := $(PODS) $(MDS) README.md $(READMES)

all: $(ALL)

ifdef SRC_DIR
  $(SRC_DIR):
	mkdir -p $(SRC_DIR)
endif
SRCPATH := $(if $(SRC_DIR),$(SRC_DIR)/,)

GREPLE := perl -I../lib -S greple

PODIFY := $(GREPLE) -Mperl --nocolor --le :pod
$(foreach mod,$(ORIGIN),$(eval \
  $(if $(filter .pm,$(suffix $(mod))),\
    $(SRCPATH)$(subst .pm,.pod,$(notdir $(mod))): $(mod) Makefile; $(PODIFY) $$< > $$@,\
    $(SRCPATH)$(notdir $(mod)).pod: $(mod) Makefile; $(PODIFY) $$< > $$@ \
  )\
))

XLATE := xlate
XLATE += $(if $(XLATE_LABOR),,-a)
XLATE += $(if $(XLATE_INIT),-r)

deepl_JA_FORM   ?= desumasu
deepl_JA_DICT   := $(wildcard *.dict)
deepl_JA_FILTER := $(GREPLE) -Mperl -Msubst::desumasu \
	$(if $(findstring $(deepl_JA_FORM).dict,$(deepl_JA_DICT)),--dict $(deepl_JA_FORM).dict) \
	--pod --subst --all --no-color --need=0 \
	--$(deepl_JA_FORM) 

define LANG_POD
  $(SRCPATH)%.$2-$1.pod: $(SRCPATH)%.pod Makefile
  ifdef $2_$1_FILTER
	$$(XLATE) -e $2 -t $1 $$< | $$($2_$1_FILTER) > $$@
  else
	$$(XLATE) -e $2 -t $1 $$< > $$@
  endif
endef

ENGINES+=$(XENGINES)
$(foreach engin,$(ENGINES),$(foreach lang,$(LANGS),$(eval $(call LANG_POD,$(lang),$(engin)))))

%.md: $(SRCPATH)%.pod
	pod2markdown $< > $@

define LANG_README
  ../README.$2-$1.md: $(MOD_NAME).$2-$1.md
	cp $$< $$@
endef

$(foreach engin,$(ENGINES),$(foreach lang,$(RM_LANGS),$(eval $(call LANG_README,$(lang),$(engin)))))

README.md: Makefile
	exec > $@ && \
	printf '## Languages\n\n' && \
	for md in $(MDS) ; \
	do \
	    echo "- [$$md]($$md)" ; \
	done

clean:
	rm -f $(SRC) $(ALL)
