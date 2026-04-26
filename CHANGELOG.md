# Changelog

## 1.0.0 (2026-04-26)


### Features

* add Gemini Flash session summarizer ([680b3ad](https://github.com/Atlas-X-AI/claude-resume-guard/commit/680b3ad7efabffbb4683bcc00d1ea89f329936c5))
* add session resume guard with size + recency checking ([95f45b1](https://github.com/Atlas-X-AI/claude-resume-guard/commit/95f45b1adce8e6b9c6ea6740ce04d83636f32ad8))
* add SessionStart hook for bypass warning ([d31e6ca](https://github.com/Atlas-X-AI/claude-resume-guard/commit/d31e6ca4a76e334890198870604ef5f1f2771188))
* add shell integration to hook guard into aw alias ([763762c](https://github.com/Atlas-X-AI/claude-resume-guard/commit/763762c3dc34930daf406ebdf2f60c0f817fd95a))
* complete install script with hook registration and shell integration ([53a32ea](https://github.com/Atlas-X-AI/claude-resume-guard/commit/53a32eaaf5041125d7efc5b15b5f9caf3395cc31))
* package for npm distribution ([b0b8dd8](https://github.com/Atlas-X-AI/claude-resume-guard/commit/b0b8dd815b129f98e67a884c6ae57a682f67d283))


### Bug Fixes

* add kick-off prompt so Claude acts on the injected summary ([edf3399](https://github.com/Atlas-X-AI/claude-resume-guard/commit/edf3399135c0272b6bd31eac3cd9ff1f5dc4aeeb))
* find correct session for --continue (skip tiny -p sessions) ([2a6a8a9](https://github.com/Atlas-X-AI/claude-resume-guard/commit/2a6a8a9fae023d4a10c6ad9085b43eff721391b6))
* recalibrate token estimation — was 5x too high ([bb30bbf](https://github.com/Atlas-X-AI/claude-resume-guard/commit/bb30bbfa0971b152c356974b52d2a3c8815e88ad))
* use --append-system-prompt-file for fresh session spawn ([5318e5e](https://github.com/Atlas-X-AI/claude-resume-guard/commit/5318e5e5b619f914d0a4f28deb2e57b6a9890a47))
* use /start as kick-off prompt for fresh sessions ([141b1c9](https://github.com/Atlas-X-AI/claude-resume-guard/commit/141b1c9f876e454d9f02652ed7a8f676b7c68664))
* use JSONL message timestamp for recency, not file mtime ([cb5291c](https://github.com/Atlas-X-AI/claude-resume-guard/commit/cb5291c600623c8f2216435e7aff2f0cec3f889e))
* use launcher script for tmux split to avoid nested quoting ([1a2ab20](https://github.com/Atlas-X-AI/claude-resume-guard/commit/1a2ab206dd2299e2bc66cd7b7c43ee0ad2d15ba5))
* write a temp launcher script and run that in the split pane. ([1a2ab20](https://github.com/Atlas-X-AI/claude-resume-guard/commit/1a2ab206dd2299e2bc66cd7b7c43ee0ad2d15ba5))
