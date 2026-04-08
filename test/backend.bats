#!/usr/bin/env bats

load test_helper

@test "default backend is claude when -b flag is not set" {
    "$RALPH" init
    run "$RALPH" build --dry-run -n 1
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Backend: claude"* ]]
}

@test "-b codex selects codex backend" {
    "$RALPH" init
    run "$RALPH" build --dry-run -n 1 -b codex
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Backend: codex"* ]]
    [[ "$output" == *"[dry-run] Would run: codex exec"* ]]
}

@test "unknown backend produces error listing supported backends" {
    "$RALPH" init
    run "$RALPH" build --dry-run -n 1 -b unknown
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"unknown backend 'unknown'"* ]]
    [[ "$output" == *"Supported backends:"* ]]
}

@test "dry-run with codex shows default model gpt-5.2-codex" {
    "$RALPH" init
    run "$RALPH" build --dry-run -n 1 -b codex
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Model:   gpt-5.2-codex"* ]]
    [[ "$output" == *"gpt-5.2-codex"* ]]
}

@test "dry-run with claude shows default model opus" {
    "$RALPH" init
    run "$RALPH" build --dry-run -n 1
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Model:   opus"* ]]
}

@test "-m flag overrides default model for any backend" {
    "$RALPH" init
    run "$RALPH" build --dry-run -n 1 -b codex -m custom-model
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Model:   custom-model"* ]]
    [[ "$output" == *"custom-model"* ]]
}

@test "codex plan mode defaults to reasoning effort high" {
    "$RALPH" init
    run "$RALPH" plan --dry-run -n 1 -b codex
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"--config model_reasoning_effort=high"* ]]
    [[ "$output" == *"Reasoning: high"* ]]
}

@test "--reasoning-effort overrides default for codex plan" {
    "$RALPH" init
    run "$RALPH" plan --dry-run -n 1 -b codex --reasoning-effort xhigh
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"--config model_reasoning_effort=xhigh"* ]]
    [[ "$output" == *"Reasoning: xhigh"* ]]
}

@test "codex build mode does not add reasoning effort by default" {
    "$RALPH" init
    run "$RALPH" build --dry-run -n 1 -b codex
    [[ "$status" -eq 0 ]]
    [[ "$output" != *"model_reasoning_effort"* ]]
    [[ "$output" != *"Reasoning:"* ]]
}

@test "--reasoning-effort works in codex build mode when explicit" {
    "$RALPH" init
    run "$RALPH" build --dry-run -n 1 -b codex --reasoning-effort medium
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"--config model_reasoning_effort=medium"* ]]
}

@test "--reasoning-effort rejects invalid values" {
    "$RALPH" init
    run "$RALPH" plan --dry-run -n 1 -b codex --reasoning-effort turbo
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"must be one of"* ]]
}

@test "--reasoning-effort warns and is ignored for non-codex backends" {
    "$RALPH" init
    run "$RALPH" plan --dry-run -n 1 --reasoning-effort high
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"only supported by the codex backend"* ]]
    [[ "$output" != *"model_reasoning_effort"* ]]
}

@test "claude plan mode does not include reasoning effort" {
    "$RALPH" init
    run "$RALPH" plan --dry-run -n 1
    [[ "$status" -eq 0 ]]
    [[ "$output" != *"model_reasoning_effort"* ]]
    [[ "$output" != *"Reasoning:"* ]]
}
