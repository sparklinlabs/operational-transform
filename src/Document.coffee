OT = require './'

module.exports = class Document
  constructor: ->
    @text = ""
    
    @revision = 0
    @operations = []
    
  apply: (newOperation, revision) ->
    # Should't happened
    throw new Error "The operation base revision is greater than the document revision" if revision > @revision
      
    if revision < @revision
      # Conflict !
      missedOperations = new OT.TextOperation
      missedOperations.targetLength = @operations[revision].baseLength
      
      for index in [revision ... @operations.length]
        missedOperations = missedOperations.compose @operations[index]
      
      [missedOperationsPrime, newOperationPrime] = missedOperations.transform newOperation
      operationToPush = newOperationPrime
    else  
      operationToPush = newOperation.clone()
      
    @text = operationToPush.apply @text
    
    @revision++
    @operations.push operationToPush
    return
    
  
