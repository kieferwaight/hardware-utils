# Makefile for managing scripts in ./scripts directory

.PHONY: all backup clean install setup update update-grub update-intramfs

all: help

help:
	@echo "Available targets:"
	@echo "  backup         Run backup-system-install.sh"
	@echo "  clean          Run clean.sh"
	@echo "  install        Run install.sh"
	@echo "  setup          Run setup.sh"
	@echo "  update         Run update.sh"
	@echo "  update-grub    Run update-grub.sh"
	@echo "  update-intramfs Run update-intramfs.sh"

backup:
	bash ./scripts/backup-system-install.sh

clean:
	bash ./scripts/clean.sh

install:
	bash ./scripts/install.sh

setup:
	bash ./scripts/setup.sh

update:
	bash ./scripts/update.sh

update-grub:
	bash ./scripts/update-grub.sh

update-intramfs:
	bash ./scripts/update-intramfs.sh
