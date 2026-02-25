---
description: Auto-push all changes to GitHub
---

// turbo-all

1. Stage, commit, and push all changes
```bash
cd "/Users/Samar/Desktop/Operating System Project 2" && git add -A && git diff --cached --quiet && echo "No changes to push" || (git commit -m "Update: $(date '+%Y-%m-%d %H:%M')" && git push origin main)
```
