OT = require './'

module.exports = class Document
  constructor: ->
    @text = ""
    
    @operations = []
    
  apply: (newOperation, revision) ->
    # Should't happened
    throw new Error "The operation base revision is greater than the document revision" if revision > @operations.length
      
    if revision < @operations.length
      # Conflict !
      missedOperations = new OT.TextOperation
      missedOperations.targetLength = @operations[revision].baseLength
      
      for index in [revision ... @operations.length]
        missedOperations = missedOperations.compose @operations[index]
      
      [missedOperationsPrime, newOperationPrime] = missedOperations.transform newOperation
      newOperation = newOperationPrime
      
    @text = newOperation.apply @text
    @operations.push newOperation.clone()
    
    return
    
  
