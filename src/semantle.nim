import semantle/types
import semantle/backends/git
import semantle/chunkers/llm

import options
import strutils
import tables
import os

import cligen
import yaml

proc plan*(range: string = "HEAD~1..HEAD", backend_str: string = "git", prompt: string = "", input_kind: string = "hunks", output: string = "plan.yaml") {.used.} =
  var backend: VCSBackend
  case backend_str
  of "git":
    backend = GitBackend()
  else:
    echo "Unknown backend: " & backend_str
    quit(1)

  let contextBuilder = LLMContextBuilder()

  let hunks = backend.getDiff(range)
  var files: seq[FileDiff]
  if input_kind == "files":
    # This is a simplification. In a real implementation, you would
    # get the full file content for each file in the diff.
    for hunk in hunks:
      files.add(FileDiff(path: hunk.file, content: ""))

  let input = ChunkingInput(
    kind: parseEnum[ChunkingInputKind](input_kind),
    hunks: hunks,
    files: files
  )

  let options = ChunkingOptions(
    steeringPrompt: some(prompt),
    extraParams: initTable[string, string]()
  )

  let context = parseEnum[ContextKind](input_kind)

  let plannedCommits = contextBuilder.build(input, options, context)

  var yamlPlan = "commits:\n"
  for commit in plannedCommits:
    yamlPlan &= "  - subject: \"" & commit.subject & "\"\n"
    yamlPlan &= "    body: \"" & commit.body & "\"\n"
    yamlPlan &= "    hunks:\n"
    for hunk in commit.hunks:
      yamlPlan &= "      - content: |\n"
      for line in hunk.content.splitLines:
        yamlPlan &= "          " & line & "\n"
      yamlPlan &= "        file: \"" & hunk.file & "\"\n"

  writeFile(output, yamlPlan)
  echo "Plan written to " & output

proc exec*(input: string = "plan.yaml", backend_str: string = "git") {.used.} =
  var backend: VCSBackend
  case backend_str
  of "git":
    backend = GitBackend()
  else:
    echo "Unknown backend: " & backend_str
    quit(1)

  var plan: YamlNode
  yaml.load(readFile(input), plan)

  for i, commitNode in plan["commits"]:
    let subject = $commitNode["subject"]
    let body = $commitNode["body"]
    let patchFile = "semantle_patch_" & $i & ".patch"
    var patchContent = ""
    for hunkNode in commitNode["hunks"]:
      let hunk = Hunk(
        content: $hunkNode["content"],
        file: $hunkNode["file"]
      )
      patchContent &= "--- a/" & hunk.file & "\n+++ b/" & hunk.file & "\n" & hunk.content
    writeFile(patchFile, patchContent)
    backend.applyHunk(Hunk(content: patchContent, file: ""))
    backend.commit(subject & "\n\n" & body, "")
    removeFile(patchFile)

proc run*(cmd: string, range: string = "HEAD~1..HEAD", backend_str: string = "git", prompt: string = "", input_kind: string = "hunks", output: string = "plan.yaml", input: string = "plan.yaml") =
  case cmd
  of "plan":
    plan(range, backend_str, prompt, input_kind, output)
  of "exec":
    exec(input, backend_str)
  else:
    echo "Unknown command: " & cmd

when isMainModule:
  dispatch(run)
