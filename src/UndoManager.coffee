###for operation in @undoStack
  if newOperation.offset <= operation.offset
    operation.offset += newOperation.insertedLength
    
for operation in @redoStack
  if newOperation.offset <= operation.offset
    operation.offset += newOperation.insertedLength###

undo: (operationToUndo) ->
  operationIndex = containsOperation operationToUndo, @undoStack
  return if operationIndex == -1
  
  operationToUndo = @undoStack[operationIndex]
  @undoStack.splice operationIndex, 1
  
  reverseOperation = operationToUndo.invert()
  
  @text = reverseOperation.apply @text
  
  ###for operation in @undoStack
    if reverseOperation.offset < operation.offset
      operation.offset += reverseOperation.insertedLength
      
  for operation in @redoStack
    if reverseOperation.offset < operation.offset
      operation.offset += reverseOperation.insertedLength###
  
  @redoStack.push operationToUndo.clone()
  return
  
redo: (operationToRedo) ->
  operationIndex = containsOperation operationToRedo, @redoStack
  return if operationIndex == -1
  
  operationToRedo = @redoStack[operationIndex]
  @redoStack.splice operationIndex, 1
  
  ###for operation in @redoStack
    if operationToRedo.offset < operation.offset
      operation.offset += operationToRedo.insertedLength###
  
  @add operationToRedo
  return
  
containsOperation = (operationToFind, list) ->
for operation, operationIndex in list
  return operationIndex if operation.equal operationToFind

return -1
