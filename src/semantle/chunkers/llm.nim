import ../types

import json
import os
import osproc
import options
import strutils
import tables

import seance
import seance/providers
import seance/session

type
  LLMContextBuilder* = ref object of RootObj

proc editGroups(groups: seq[string]): seq[string] =
  let tmpFile = "semantle_groups.txt"
  var content = ""
  for group in groups:
    content &= group & "\n"
  writeFile(tmpFile, content)
  let editor = getEnv("EDITOR", "nano")
  discard execCmd(editor & " " & tmpFile)
  return readFile(tmpFile).splitLines()

method build*(builder: LLMContextBuilder, input: ChunkingInput, options: ChunkingOptions, context: ContextKind): seq[ChunkedCommit] {.base} =
  var sess = newChatSession()

  var prompt = "You are a helpful assistant that groups git diff hunks into semantic commits.\n"
  if options.steeringPrompt.isSome and options.steeringPrompt.get().len > 0:
    prompt &= "Steering prompt: " & options.steeringPrompt.get() & "\n"

  case context
  of hunks:
    prompt &= "Here are the hunks:\n"
    for i, hunk in input.hunks:
      prompt &= "Hunk " & $i & ":\n" & hunk.content & "\n"
  of files:
    prompt &= "Here are the files:\n"
    for file in input.files:
      prompt &= "File: " & file.path & "\n"
      prompt &= "```\n" & file.content & "\n```\n"

  prompt &= "Please group the hunks into commits. For each hunk, assign it to a group. Output a JSON array of objects, where each object has a 'hunk_index' and a 'group' key.\n"

  let provider = getProvider()
  let response = sess.chat(prompt, provider)

  var proposedGroups: seq[string]
  let jsonOutput = parseJson(response.content)
  for item in jsonOutput:
    proposedGroups.add(item["group"].getStr())

  let editedGroups = editGroups(proposedGroups)

  var commits = newTable[string, ChunkedCommit]()
  for i, hunk in input.hunks:
    let group = editedGroups[i]
    if not commits.hasKey(group):
      commits[group] = ChunkedCommit(
        subject: "Semantic commit: " & group,
        body: "",
        hunks: @[]
      )
    var commit = commits[group]
    commit.hunks.add(hunk)
    commits[group] = commit

  for _, commit in commits:
    result.add(commit)
