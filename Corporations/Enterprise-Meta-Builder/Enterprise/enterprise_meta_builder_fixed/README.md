# Enterprise Meta-Builder (Fixed)
Version alignment:
- Enterprise-Meta-Builder.sh: **v1.0.6**
- phase_2_generator.sh: **v1.1.3**

This package contains a corrected, ready-to-run version of the Enterprise Meta-Builder system.

## Contents

- `Enterprise-Meta-Builder.sh` – Core meta-builder engine. Loads a project plugin (`*.conf`) and dispatches commands such as `--bootstrap`, `--compile`, `--audit`, and `--ai-assist`.
- `phase_2_generator.sh` – Generator that creates the 8 project-specific configuration plugins:
  - `chimera.conf`  (Google – Project Chimera)
  - `sentry.conf`   (Amazon – Project Sentry)
  - `aegis.conf`    (Microsoft – Project Aegis)
  - `veritas.conf`  (Oracle – Project Veritas)
  - `synergy.conf`  (IBM – Project Synergy)
  - `clarity.conf`  (OpenAI – Project Clarity)
  - `orchard.conf`  (Apple – Project Orchard)
  - `connect.conf`  (Meta – Project Connect)

## Quick Start

From this directory:

```bash
# 1. Ensure scripts are executable
chmod +x ./Enterprise-Meta-Builder.sh ./phase_2_generator.sh

# 2. Generate all 8 .conf plugin files
./phase_2_generator.sh

# 3. Run a bootstrap for a specific project
./Enterprise-Meta-Builder.sh --project chimera --bootstrap

# 4. Example audits / compiles
./Enterprise-Meta-Builder.sh --project sentry  --audit risk-score
./Enterprise-Meta-Builder.sh --project aegis   --audit mbom
./Enterprise-Meta-Builder.sh --project clarity --ai-assist ip-detect
```

## Logging

- Logs are written to: `~/.logs/meta_builder/meta_builder_YYYYMMDD.log`
- The log file is automatically created and appended to on each run.
- If you previously executed a broken version with `sudo`, ensure that you fix ownership:

```bash
sudo chown -R "$(whoami)" ~/.logs
```

## Error Handling & Self-Healing

- A global `ERR` trap captures failures and routes them through a centralized `fn_handle_error`.
- Each project plugin defines `fn_project_self_heal` which is invoked after failures (if implemented).
- Package installs are wrapped so that failures are logged but do **not** crash the entire meta-builder.

## Requirements

- macOS or Linux
- Optional tools (simulated if absent):
  - `brew`, `apt-get`, or `yum`
  - `bazel`, `ant`, `make`, `jenkins`, `hhvm`, etc.

If these tools are missing, the system will log warnings and continue, treating those actions as simulations.

## License & Copyright

All files are copyright © 2025 Devin B. Royal. All Rights Reserved.

The scripts are tagged with `SPDX-License-Identifier: Apache-2.0`, but you remain the sole copyright holder and IP owner. You may adjust the licensing model at any time.
