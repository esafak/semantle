import tables
import options

type
  Hunk* = object
    content*: string
    file*: string

  FileDiff* = object
    path*: string
    content*: string

  ChunkingInputKind* = enum
    hunksOnly, fullFiles, custom

  ChunkingInput* = object
    kind*: ChunkingInputKind
    hunks*: seq[Hunk]
    files*: seq[FileDiff]
    customData*: Option[string]

  ChunkingOptions* = object
    steeringPrompt*: Option[string]
    extraParams*: Table[string, string]

  ChunkedCommit* = object
    subject*: string
    body*: string
    hunks*: seq[Hunk]

  VCSBackend* = ref object of RootObj

  ContextKind* = enum
    hunks, files

method getDiff*(backend: VCSBackend, range: string): seq[Hunk] {.base.} =
  newSeq[Hunk]()

method applyHunk*(backend: VCSBackend, hunk: Hunk) {.base.} =
  discard

method commit*(backend: VCSBackend, message: string, commitTemplate: string) {.base.} =
  discard

method branchExists*(backend: VCSBackend, name: string): bool {.base.} =
  return false

method createBranch*(backend: VCSBackend, name: string) {.base.} =
  discard
