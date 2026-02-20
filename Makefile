.PHONY: test test-structure test-scenarios validate lint

SKILLS := $(wildcard skills/*)

test: test-structure test-scenarios

test-structure:
	@bash scripts/test-skills.sh

test-scenarios:
	@python3 tests/run-scenarios.py

validate:
	@echo "validating skill definitions..."
	@command -v skills-ref > /dev/null 2>&1 || { echo "error: skills-ref not installed. run: npm install -g skills-ref"; exit 1; }
	@for s in $(SKILLS); do \
		echo "  $$s"; \
		skills-ref validate "$$s"; \
	done
	@echo "all skills valid"

lint:
	@echo "checking skill files..."
	@for f in skills/*/SKILL.md; do \
		echo "  $$f"; \
		head -1 "$$f" | grep -q '^---$$' || { echo "error: $$f missing frontmatter"; exit 1; }; \
	done
	@echo "lint passed"
