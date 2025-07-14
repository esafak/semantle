import osproc
import os
import strutils
import ../types

type
  GitBackend* = ref object of VCSBackend

proc exec(cmd: string): string =
  let (output, exitCode) = execCmdEx(cmd)
  if exitCode != 0:
    raise newException(Exception, "Command failed: " & cmd & "\n" & output)
  return output

method getDiff*(backend: GitBackend, range: string): seq[Hunk] =
  let diffOutput = exec("git diff --unified=0 " & range)
  result = @[]
  var currentFile = ""
  var currentHunk: Hunk = Hunk(content: "", file: "")
  var inHunk = false
  for line in diffOutput.splitLines:
    if line.startsWith("diff --git"):
      if inHunk:
        result.add(currentHunk)
      inHunk = false
      let parts = line.split(" ")
      currentFile = parts[3][2..^1]
    elif line.startsWith("@@"):
      if inHunk:
        result.add(currentHunk)
      inHunk = true
      currentHunk = Hunk(content: line & "\n", file: currentFile)
    elif inHunk:
      currentHunk.content &= line & "\n"
  if inHunk:
    result.add(currentHunk)

method applyHunk*(backend: GitBackend, hunk: Hunk) =
  let patchFile = "semantle.patch"
  let patchContent = "--- a/" & hunk.file & "\n+++ b/" & hunk.file & "\n" & hunk.content
  writeFile(patchFile, patchContent)
  discard exec("git apply " & patchFile)
  removeFile(patchFile)

method commit*(backend: GitBackend, message: string, commitTemplate: string) =
  let msgFile = "semantle.msg"
  writeFile(msgFile, message)
  discard exec("git commit -F " & msgFile)
  removeFile(msgFile)

method branchExists*(backend: GitBackend, name: string): bool =
  let output = exec("git branch --list " & name)
  return output.strip.len > 0

method createBranch*(backend: GitBackend, name: string) =
  discard exec("git checkout -b " & name)
