---
name: my-skill
description: Short description of what this skill does and when to use it.
license: Apache
compatibility: new
metadata: new
disable-model-invocation: false
---

# Deploy App

Deploy the application using the provided scripts.

## Usage

Run the deployment script: `scripts/deploy.sh <environment>`
Where `<environment>` is either `staging` or `production`.

## Pre-deployment Validation

Before deploying, run the validation script: `python scripts/validate.py`
