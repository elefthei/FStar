---
safe-outputs:
  create-pull-request:
    expires: 2d
    title-prefix: "[q] "
    labels: [automation, workflow-optimization]
    draft: false
    if-no-changes: "ignore"
    protected-files: request-review # Q edits .github/workflows/*.md
    excluded-files:
      - ".github/workflows/*.lock.yml"
    max-patch-files: 500
---
