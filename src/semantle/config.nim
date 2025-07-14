import os
import json

const configDir = getHomeDir() & "/.config/semantle"
const configFile = configDir & "/config.json"

type
  Context* = enum
    hunks, files

  Config* = object
    commitTemplate*: string
    context*: Context

proc defaultConfig*(): Config =
  result.commitTemplate = """
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
"""
  result.context = hunks

proc createDefaultConfig*() =
  if not dirExists(configDir):
    createDir(configDir)

  let config = defaultConfig()
  let json = %*config
  writeFile(configFile, $json)

proc readConfig*(): Config =
  if not fileExists(configFile):
    createDefaultConfig()

  try:
    let json = parseFile(configFile)
    return to(json, Config)
  except JsonParsingError:
    echo "Error: Corrupt configuration file at " & configFile
    echo "Do you want to delete it and create a new one? (y/n)"
    let answer = readLine(stdin)
    if answer == "y":
      removeFile(configFile)
      createDefaultConfig()
      return defaultConfig()
    else:
      quit(1)
