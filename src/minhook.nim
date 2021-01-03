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
macro mHook*(x: untyped, procPtr: proc | pointer | ptr | int | uint, body: untyped) =
  var params = nnkFormalParams.newNimNode().add(x[2])
  for child in x[1][1..^1]:
    params.add(nnkIdentDefs.newTree(
      child[0],
      child[1],
      newEmptyNode(),
    ))

  let procType = nnkProcTy.newTree(
    params,
    nnkPragma.newTree(x[1][0])
  )
  
  let symHkProc = genSym(nskProc)

  var bodyStatements = newNimNode(nnkStmtList).add(body)
  result = nnkStmtList.newTree()
  result.add(nnkVarSection.newTree(nnkIdentDefs.newTree(
    nnkPragmaExpr.newTree(
      newIdentNode("ogProcCall"),
      nnkPragma.newTree("global".ident)
    ),
    procType,
    newNilLit()
  )))
  result.add(nnkProcDef.newTree(
    symHkProc,
    newEmptyNode(),
    newEmptyNode(),
    procType[0].copy,
    procType[1].copy,
    newEmptyNode(),
    bodyStatements
  ))

  template doHooks(symOgProc, symHkProc, procPtr: untyped): untyped = 
    symOgProc = hook(procPtr, symHkProc)
    enableHook(procPtr)

  result.add(getAst(doHooks(newIdentNode("ogProcCall"), symHkProc, procPtr)))
  
proc enableHook*[T: ptr | proc | pointer](target: T) =
  let status = raw.MH_EnableHook(cast[LPVOID](target))
  if status != raw.MH_OK: raise newException(LibraryError,
      fmt"Enabling hook ({cast[uint](target)}) failed with {status}")

proc disableHook*[T: ptr | proc | pointer](target: T) =
  let status = raw.MH_DisableHook(cast[LPVOID](target))
  if status != raw.MH_OK: raise newException(LibraryError,
      fmt"Disabling hook ({cast[uint](target)}) failed with {status}")
