import ../types

type
  DefaultContextBuilder* = ref object of RootObj

method build*(builder: DefaultContextBuilder, input: ChunkingInput): seq[ChunkedCommit] =
  result = @[]
  for hunk in input.hunks:
    result.add(ChunkedCommit(
      subject: "Commit for hunk in " & hunk.file,
      body: "This commit contains a single hunk.",
      hunks: @[hunk]
    ))
