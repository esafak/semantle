# Semantle

A Nim-based CLI tool to semantically reconstitute a range of git commits.

## Overview

This tool is a Nim-based CLI extension for semantically splitting a range of commits into atomic commits. It is designed to be **testable**, **extensible** (to other VCS backends), and now includes a **pluggable LLM interface** responsible for chunking and semantic grouping.

## Key Components

1.  **Core Engine:** Orchestrates planning and execution.
2.  **Backend Abstraction:** Supports Git and is extensible to other CVS.
3.  **LLM Interface:** Responsible for semantic chunking of hunks, files, or arbitrary code regions.
4.  **CLI Frontend:** Exposes planning and execution modes.
5.  **Testing Layer:** Ensures all logic is testable with mocks and fixtures.

## LLM Interface Specification

### Purpose

-   **Semantic Chunking:** The LLM interface analyzes code changes and partitions them into atomic, meaningful commits.
-   **Flexible Input:** Accepts hunks, full files, or custom code regions.
-   **Steering Prompt:** Accepts an optional prompt to guide chunking behavior (e.g., "group by feature", "split by function", etc.).
-   **Extensible:** Default implementation is rule-based; can be swapped for LLM-powered or custom chunkers.

### Interface Design

```nim
type
  Context = enum
    hunks, files

  ChunkingInput = object
    kind: ChunkingInputKind
    hunks: seq[Hunk]
    files: seq[FileDiff]
    customData: Option[string]

  ChunkingOptions = object
    steeringPrompt: Option[string]
    extraParams: Table[string, string]

  ChunkedCommit = object
    subject: string
    body: string
    hunks: seq[Hunk]

  LLMChunker = ref object of RootObj
    proc chunk(input: ChunkingInput, options: ChunkingOptions, context: Context): seq[ChunkedCommit]
```

### CLI Integration

-   **Planning Mode:**
    ```
    semantle plan --range <start>..<end> [--backend git] [--prompt "steering prompt"] [--context hunks|files]
    ```
    -   `--prompt`: Passes a steering prompt to the chunker.
    -   `--context`: Specifies the granularity of input (hunks or files).

## Planning Mode (with LLM Interface)

-   **Extracts** hunks/files from the commit range.
-   **Invokes** the selected chunker with the input and options.
-   **Outputs** a structured plan (YAML) with subject, body, and hunks for each planned commit.

## Execution Mode

-   **Reads** the plan from stdin or file.
-   **Applies** hunks and commits as specified, using the backend.

## Extensibility & Testability

-   **LLM Interface:** New chunkers can be added by implementing the `LLMChunker` interface.
-   **Mock Implementations:** For testing, mock chunkers can simulate LLM or rule-based behavior.
-   **Backend Plugins:** Support for other CVS by implementing the backend interface.

## Example Workflow

1.  **Planning with LLM Chunker:**
    ```
    semantle plan --range abc123..def456 --backend git --prompt "Split by logical feature" --context files > plan.yml
    ```
2.  **Review/Edit Plan:** User reviews or edits `plan.yml`.
3.  **Execution:**
    ```
    semantle exec plan.yml --backend git
    ```
