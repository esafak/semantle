import semantle
import semantle/types
import semantle/config
import semantle/backends/git

import unittest
import osproc
import strutils
import os
import yaml
import std/paths
import std/dirs
import std/private/oscommon
import system/nimscript

proc setupGitRepo(): string =
  let repoPath = "test_repo"
  if os.dirExists(repoPath):
    dirs.removeDir(Path(repoPath))
  os.createDir(repoPath)
  withDir repoPath:
    discard execCmd("git init")
    discard execCmd("git config user.name \"Test User\"")
    discard execCmd("git config user.email \"test@example.com\"")
    writeFile("file1.txt", "hello")
    discard execCmd("git add file1.txt")
    discard execCmd("git commit -m \"Initial commit\"")
    writeFile("file1.txt", "hello\nworld")
    discard execCmd("git add file1.txt")
    discard execCmd("git commit -m \"Add world\"")
    writeFile("file2.txt", "foo")
    discard execCmd("git add file2.txt")
    discard execCmd("git commit -m \"Add file2\"")
  return repoPath

proc cleanupGitRepo(repoPath: string) =
  dirs.removeDir(Path(repoPath))

template withTestRepo(body: untyped) =
  let originalDir = os.getCurrentDir()
  let repoPath = setupGitRepo()
  os.setCurrentDir(repoPath)
  try:
    body
  finally:
    os.setCurrentDir(originalDir)
    cleanupGitRepo(repoPath)

suite "Semantle tests":
  test "Plan and exec":
    withTestRepo:
      let plan = """
- subject: "feat: Add world"
  body: "This commit adds the word 'world' to file1.txt."
  hunks:
  - "--- a/file1.txt\n+++ b/file1.txt\n@@ -1,1 +1,2 @@\n hello\n+world"
- subject: "feat: Add file2"
  body: "This commit adds file2.txt with the content 'foo'."
  hunks:
  - "--- a/file2.txt\n+++ b/file2.txt\n@@ -0,0 +1,1 @@\n+foo"
"""
      writeFile("plan.yml", plan)
      discard execCmd("plan.yml")
      let (log, _) = execCmdEx("git log --pretty=format:%s")
      check(log.contains("feat: Add world"))
      check(log.contains("feat: Add file2"))

  test "Context parameter":
    withTestRepo:
      var config = readConfig()
      config.context = files
      semantle.plan(range = "HEAD~2..HEAD", backend_str = "git", prompt = "", input_kind = "files", output = "plan.yaml")
      let planStr = readFile("plan.yaml")
      check(planStr.contains("file1.txt"))
      check(planStr.contains("file2.txt"))

suite "Git Backend":
  var repoPath: string
  setup:
    repoPath = setupGitRepo()

  teardown:
    cleanupGitRepo(repoPath)

  test "getDiff":
    withDir repoPath:
      let backend = GitBackend()
      let hunks = backend.getDiff("HEAD~1..HEAD")
      check hunks.len == 2
      check hunks[0].file == "file1.txt"
      check hunks[1].file == "file2.txt"

suite "CLI":
  var repoPath: string
  setup:
    repoPath = setupGitRepo()

  teardown:
    cleanupGitRepo(repoPath)

  test "plan and exec":
    withDir repoPath:
      semantle.plan(range = "HEAD~1..HEAD")
      check os.fileExists("plan.yaml")

      # Reset the repo to the initial state
      discard execShellCmd("git reset --hard HEAD~1")

      semantle.exec()

      let (status, _) = execCmdEx("git status -s")
      check status.len == 0

      let (log, _) = execCmdEx("git log --oneline --no-merges")
      check log.splitLines.len == 3 # initial, plus two from the plan

  test "user override":
    withDir repoPath:
      # Mock the LLM output
      let llmOutput = """[{"hunk_index": 0, "group": "group1"}, {"hunk_index": 1, "group": "group2"}]"""
      let llmOutputFile = "llm_output.json"
      writeFile(llmOutputFile, llmOutput)

      # Mock the user's edits
      let editedGroups = "group2\ngroup1"
      let editedGroupsFile = "semantle_groups.txt"
      writeFile(editedGroupsFile, editedGroups)

      # Set the EDITOR to a command that does nothing
      os.putEnv("EDITOR", "true")

      semantle.plan(range = "HEAD~1..HEAD")

      var plan: YamlNode
      yaml.load(readFile("plan.yaml"), plan)
      check plan["commits"].len == 2
      check $plan["commits"][0]["subject"] == "Semantic commit: group2"
      check $plan["commits"][1]["subject"] == "Semantic commit: group1"
