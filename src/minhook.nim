import winim/inc/windef
from minhook/raw import nil
import strformat, macros, sequtils


proc init*() =
  let status = raw.MH_Initialize()
  if status != raw.MH_OK: raise newException(LibraryError,
      fmt"Initialization failed with {status}")
proc uninit*() =
  let status = raw.MH_Uninitialize()
  if status != raw.MH_OK: raise newException(LibraryError,
      fmt"Uninitialization failed with {status}")

proc hook*[T: ptr | proc | pointer](target: T, detour: T): T =
  var originalFunction: T = nil
  let status = raw.MH_CreateHook(cast[LPVOID](target), cast[LPVOID](detour),
      cast[ptr LPVOID](addr originalFunction))
  if status != raw.MH_OK: raise newException(LibraryError,
      fmt"Hooking ({cast[uint](target)}) to (({cast[uint](detour)})) failed with {status}")
  originalFunction

proc hook*[T: proc](target: ptr | pointer, detour: T): T = hook(cast[T](target), detour)
proc hook*[T: proc](target: T, detour: ptr | pointer): T = hook(target, cast[T](detour))


## The macro declares a procedure of the same signature, and name `ogProcCall`, for calling the original procedure.
## Macro body is the same as hooked procedure's body, i.e., all the rules of a normal procedure apply to the macro body.
macro hook*(procType: untyped, procPtr: proc | pointer | ptr | int | uint, body: untyped) =
  let symOgProc = newIdentNode("ogProcCall")
  let symHkProc = genSym(nskProc)
  let formalParams = procType[0]
  var bodyStatements = newNimNode(nnkStmtList).add(body)
  result = nnkStmtList.newTree()
  result.add(nnkVarSection.newTree(nnkIdentDefs.newTree(
    symOgProc,
    procType,
    newNilLit()
  )))
  result.add(nnkProcDef.newTree(
    symHkProc,
    newEmptyNode(),
    newEmptyNode(),
    formalParams,
    procType[1],
    newEmptyNode(),
    bodyStatements
  ))

  template doHooks(symOgProc, symHkProc, procPtr: untyped): untyped = 
    symOgProc = hook(procPtr, symHkProc)
    enableHook(procPtr)

  result.add(getAst(doHooks(symOgProc, symHkProc, procPtr)))

proc enableHook*[T: ptr | proc | pointer](target: T) =
  let status = raw.MH_EnableHook(cast[LPVOID](target))
  if status != raw.MH_OK: raise newException(LibraryError,
      fmt"Enabling hook ({cast[uint](target)}) failed with {status}")

proc disableHook*[T: ptr | proc | pointer](target: T) =
  let status = raw.MH_DisableHook(cast[LPVOID](target))
  if status != raw.MH_OK: raise newException(LibraryError,
      fmt"Disabling hook ({cast[uint](target)}) failed with {status}")
