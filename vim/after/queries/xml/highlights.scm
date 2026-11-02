; extends

; Property list (plist) highlighting, tuned for launchd agents. Keys launchd
; reads stand apart from custom ones and env var names from other keys.

; <key></key> stand apart from value and container tags.
((STag
  (Name) @_tag) @tag.key.plist
  (#eq? @_tag "key")
  (#set! priority 101))

((ETag
  (Name) @_tag) @tag.key.plist
  (#eq? @_tag "key")
  (#set! priority 101))

; <true/> and <false/> are the value itself.
((EmptyElemTag
  (Name) @_tag) @boolean.true.plist
  (#eq? @_tag "true")
  (#set! priority 101))

((EmptyElemTag
  (Name) @_tag) @boolean.false.plist
  (#eq? @_tag "false")
  (#set! priority 101))

; Keys launchd does not read, such as the Hammerspoon menu's Name.
(element
  (STag
    (Name) @_tag)
  (content
    (CharData) @property.plist)
  (#eq? @_tag "key")
  (#set! priority 101))

; Keys documented in launchd.plist(5); a misspelt one keeps the color above.
(element
  (STag
    (Name) @_tag)
  (content
    (CharData) @keyword.launchd)
  (#eq? @_tag "key")
  (#any-of? @keyword.launchd
    "AbandonProcessGroup" "AssociatedBundleIdentifiers" "Bonjour"
    "BundleProgram" "CPU" "Core" "Crashed" "Data" "Day" "Debug" "Disabled"
    "EnableGlobbing" "EnablePressuredExit" "EnableTransactions"
    "EnvironmentVariables" "ExitTimeOut" "FileSize" "GroupName"
    "HardResourceLimits" "HideUntilCheckIn" "HopefullyExitsFirst"
    "HopefullyExitsLast" "Hour" "InitGroups" "KeepAlive" "Label"
    "LaunchEvents" "LaunchOnlyOnce" "LegacyTimers" "LimitLoadFromHardware"
    "LimitLoadFromHosts" "LimitLoadToHardware" "LimitLoadToHosts"
    "LimitLoadToSessionType" "LowPriorityBackgroundIO" "LowPriorityIO"
    "MachServices" "MaterializeDatalessFiles" "MemoryLock" "Minute" "Month"
    "MulticastGroup" "NetworkState" "Nice" "NumberOfFiles"
    "NumberOfProcesses" "OnDemand" "OtherJobEnabled" "PathState"
    "ProcessType" "Program" "ProgramArguments" "QueueDirectories"
    "ResetAtClose" "ResidentSetSize" "RootDirectory" "RunAtLoad"
    "SecureSocketWithKey" "ServiceIPC" "SessionCreate" "SockFamily"
    "SockNodeName" "SockPassive" "SockPathGroup" "SockPathMode"
    "SockPathName" "SockPathOwner" "SockProtocol" "SockServiceName"
    "SockType" "Sockets" "SoftResourceLimits" "Stack" "StandardErrorPath"
    "StandardInPath" "StandardOutPath" "StartCalendarInterval"
    "StartInterval" "StartOnMount" "SuccessfulExit" "ThrottleInterval"
    "TimeOut" "Umask" "UserName" "Wait" "WaitForDebugger" "WatchPaths"
    "Weekday" "WorkingDirectory" "inetdCompatibility")
  (#set! priority 102))

; Names inside EnvironmentVariables read as constants, not as plist keys.
(content
  (element
    (STag
      (Name) @_key_tag)
    (content
      (CharData) @_key))
  .
  (CharData)
  .
  (element
    (STag
      (Name) @_dict_tag)
    (content
      (element
        (STag
          (Name) @_name_tag)
        (content
          (CharData) @constant.plist))))
  (#eq? @_key_tag "key")
  (#eq? @_key "EnvironmentVariables")
  (#eq? @_dict_tag "dict")
  (#eq? @_name_tag "key")
  (#set! priority 103))

(element
  (STag
    (Name) @_tag)
  (content
    (CharData) @string)
  (#eq? @_tag "string")
  (#set! priority 101))

; Absolute and home-relative paths: program, log and working directories.
(element
  (STag
    (Name) @_tag)
  (content
    (CharData) @string.special.path.plist)
  (#eq? @_tag "string")
  (#lua-match? @string.special.path.plist "^[/~]")
  (#set! priority 102))

(element
  (STag
    (Name) @_tag)
  (content
    (CharData) @number)
  (#any-of? @_tag "integer" "real")
  (#set! priority 101))

(element
  (STag
    (Name) @_tag)
  (content
    (CharData) @string.special)
  (#any-of? @_tag "date" "data")
  (#set! priority 101))
