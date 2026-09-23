#!/usr/bin/env bash
# UserPromptSubmit hook: if the prompt looks like a design decision, remind Claude to record it.
# ponytail: keyword regex, extend when a real decision slips through.
PROMPT=$(cat | python3 -c 'import sys,json; print(json.load(sys.stdin).get("prompt",""))' 2>/dev/null)
if printf '%s' "$PROMPT" | grep -qiE "let.?s (go with|use|do)|we.?ll (use|go with)|(i|we) (decided|chose|prefer|want to use)|instead of .* use|switch(ing)? to|from now on|going forward"; then
  N=$(ls "$CLAUDE_PROJECT_DIR"/docs/decision/*.md 2>/dev/null | wc -l)
  printf '[decision-detector] This looks like a design decision. If it changes how the project is built, record it:\n  docs/decision/%04d-<slug>.md  with sections: Context / Decision / Why / Consequences.\n' $((N+1))
fi
exit 0
