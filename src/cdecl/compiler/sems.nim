import compiler/[
  astalgo, modules, passes, condsyms,
  options, llstream, lineinfos, vm,
  modulegraphs, idents, 
  passaux, scriptconfig, 
]

import compiler/[
  ast, modules, idents, passes, condsyms,
  options, sem, llstream, vm, vmdef, commands,
  wordrecg, modulegraphs,
  pathutils
]

import compiler/semdata
# import compiler/sem
# import compiler/semmagic
import intsets

export PContext

proc newContext*(graph: ModuleGraph; module: PSym): PContext =
  new(result)
  result.optionStack = @[newOptionEntry(graph.config)]
  result.libs = @[]
  result.module = module
  result.friendModules = @[module]
  result.converters = @[]
  result.patterns = @[]
  result.includedFiles = initIntSet()
  initStrTable(result.pureEnumFields)
  initStrTable(result.userPragmas)
  result.generics = @[]
  result.unknownIdents = initIntSet()
  result.cache = graph.cache
  result.graph = graph
  initStrTable(result.signatures)
  result.features = graph.config.features
  if graph.config.symbolFiles != disabledSf:
    let id = module.position
    # assert graph.packed[id].status in {undefined, outdated}
    # graph.packed[id].status = storing
    graph.packed[id].module = module
    initEncoder graph, module

proc semBindSym*(c: PContext, n: PNode): PNode =
  result = copyNode(n)
  result.add(n[0])
