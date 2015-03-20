OT = require './'

module.exports = class TextOperation
  constructor: (@userId) ->
    @ops = []
    # An operation's baseLength is the length of every string the operation
    # can be applied to.
    @baseLength = 0
    # The targetLength is the length of every string that results from applying
    # the operation on a valid input string.
    @targetLength = 0

  serialize: ->
    ops = []
    for op in @ops
      ops.push { type: op.type, attributes: op.attributes }

    { ops, userId: @userId }

  deserialize: (data) ->
    return false if ! data?

    @userId = data.userId
    for op in data.ops
      switch op.type
        when 'retain'
          @retain op.attributes.amount
        when 'insert'
          @insert op.attributes.text
        when 'delete'
          @delete op.attributes.text
        else
          return false

    true

  retain: (amount) ->
    return if typeof(amount) != 'number' or amount <= 0
    @baseLength += amount
    @targetLength += amount

    prevOp = @ops[@ops.length - 1]
    if prevOp?.type == 'retain'
      prevOp.attributes.amount += amount
    else
      @ops.push new OT.TextOp 'retain', { amount }
    return

  insert: (text) ->
    return if typeof(text) != 'string' or text == ''
    @targetLength += text.length

    prevOp = @ops[@ops.length - 1]
    if prevOp?.type == 'insert'
      prevOp.attributes.text += text
    else
      @ops.push new OT.TextOp 'insert', { text }
    return

  delete: (text) ->
    return if typeof(text) != 'string' or text == ''
    @baseLength += text.length

    prevOp = @ops[@ops.length - 1]
    if prevOp?.type == 'delete'
      prevOp.attributes.text += text
    else
      @ops.push new OT.TextOp 'delete', { text }
    return

  apply: (text) ->
    throw new Error "The operation's base length must be equal to the string's length." if text.length != @baseLength
    index = 0

    for op in @ops
      switch op.type
        when 'retain'
          index += op.attributes.amount

        when 'insert'
          text = text.substring(0, index) + op.attributes.text + text.substring(index, text.length)
          index += op.attributes.text.length

        when 'delete'
          text = text.substring(0, index) + text.substring(index + op.attributes.text.length, text.length)

    return text

  invert: ->
    invertedOperation = new TextOperation @userId
    for op in @ops
      switch op.type
        when 'retain'
          invertedOperation.retain op.attributes.amount

        when 'insert'
          invertedOperation.delete op.attributes.text

        when 'delete'
          invertedOperation.insert op.attributes.text

    return invertedOperation

  clone: ->
    operation = new TextOperation @userId
    for op in @ops
      switch op.type
        when 'retain'
          operation.retain op.attributes.amount

        when 'insert'
          operation.insert op.attributes.text

        when 'delete'
          operation.delete op.attributes.text

    return operation

  equal: (otherOperation) ->
    #return false if otherOperation.insertedLength != @insertedLength
    return false if otherOperation.ops.length != @ops.length

    for op, opIndex in @ops
      otherOp = otherOperation.ops[opIndex]
      return false if otherOp.type != op.type
      for key, attribute of op.attributes
        return false if attribute != otherOp.attributes[key]

    return true

  ###
  Largely inspired from Firepad
  Compose merges two consecutive operations into one operation, that
  preserves the changes of both. Or, in other words, for each input string S
  and a pair of consecutive operations A and B,
  apply(apply(S, A), B) = apply(S, compose(A, B)) must hold.
  ###

  compose: (operation2) ->
    throw new Error 'The base length of the second operation has to be the target length of the first operation' if @targetLength != operation2.baseLength

    # the combined operation
    composedOperation = new TextOperation @userId

    ops1 = @clone().ops
    ops2 = operation2.clone().ops
    i1 = 0 # current index into ops1 respectively ops2
    i2 = 0
    op1 = ops1[i1++] # current ops
    op2 = ops2[i2++]

    loop
      # Dispatch on the type of op1 and op2

      # end condition: both ops1 and ops2 have been processed
      break if ! op1? and ! op2?

      if ! op2?

        switch op1.type
          when 'retain'
            composedOperation.retain op1.attributes.amount

          when 'insert'
            composedOperation.insert op1.attributes.text

          when 'delete'
            composedOperation.delete op1.attributes.text

        op1 = ops1[i1++]
        continue

      if ! op1?
        switch op2.type
          when 'retain'
            composedOperation.retain op2.attributes.amount

          when 'insert'
            composedOperation.insert op2.attributes.text

          when 'delete'
            composedOperation.delete op2.attributes.text

        op2 = ops2[i2++]
        continue

      if op1?.type == 'delete'
        composedOperation.delete op1.attributes.text
        op1 = ops1[i1++]
        continue
      if op2?.type == 'insert'
        composedOperation.insert op2.attributes.text
        op2 = ops2[i2++]
        continue

      throw new Error 'Cannot transform operations: first operation is too short.'  if ! op1?
      throw new Error 'Cannot transform operations: first operation is too long.'  if ! op2?

      if op1.type == 'retain' and op2.type == 'retain'
        if op1.attributes.amount == op2.attributes.amount
          composedOperation.retain op1.attributes.amount
          op1 = ops1[i1++]
          op2 = ops2[i2++]
        else if op1.attributes.amount > op2.attributes.amount
          composedOperation.retain op2.attributes.amount
          op1.attributes.amount -= op2.attributes.amount
          op2 = ops2[i2++]
        else
          composedOperation.retain op1.attributes.amount
          op2.attributes.amount -= op1.attributes.amount
          op1 = ops1[i1++]

      else if op1.type == 'insert' and op2.type == 'delete'
        if op1.attributes.text.length == op2.attributes.text
          op1 = ops1[i1++]
          op2 = ops2[i2++]
        else if op1.attributes.text.length > op2.attributes.text.length
          op1.attributes.text = op1.attributes.text.slice(op2.attributes.text.length)
          op2 = ops2[i2++]
        else
          op2.attributes.text= op2.attributes.text.slice(op1.attributes.text.length)
          op1 = ops1[i1++]

      else if op1.type == 'insert' and op2.type == 'retain'
        if op1.attributes.text.length > op2.attributes.amount
          composedOperation.insert op1.attributes.text.slice(0, op2.attributes.amount)
          op1.attributes.text = op1.attributes.text.slice(op2.attributes.amount)
          op2 = ops2[i2++]
        else if op1.attributes.text.length is op2.attributes.amount
          composedOperation.insert op1.attributes.text
          op1 = ops1[i1++]
          op2 = ops2[i2++]
        else
          composedOperation.insert op1.attributes.text
          op2.attributes.amount -= op1.attributes.text.length
          op1 = ops1[i1++]

      else if op1.type == 'retain' and op2.type == 'delete'
        if op1.attributes.amount == op2.attributes.text.length
          composedOperation.delete op2.attributes.text
          op1 = ops1[i1++]
          op2 = ops2[i2++]
        else if op1.attributes.amount > op2.attributes.text.length
          composedOperation.delete op2.attributes.text
          op1.attributes.amount -= op2.attributes.text.length
          op2 = ops2[i2++]
        else
          composedOperation.delete op2.attributes.text.slice(0, op1.attributes.amount)
          op2.attributes.text = op2.attributes.text.slice(op1.attributes.amount)
          op1 = ops1[i1++]

      else
        throw new Error "This shouldn't happen: op1: " + JSON.stringify(op1) + ", op2: " + JSON.stringify(op2)

    return composedOperation

  ###
  Largely inspired from Firepad
  Transform takes two operations A (this) and B (other) that happened concurrently and
  produces two operations A' and B' (in an array) such that
  `apply(apply(S, A), B') = apply(apply(S, B), A')`.
  This function is the heart of OT.
  ###
  transform: (operation2) ->
    # Give priority with the user id
    if @gotPriority operation2.userId
      operation1prime = new TextOperation @userId
      operation2prime = new TextOperation operation2.userId

      ops1 = @clone().ops
      ops2 = operation2.clone().ops
    else
      operation1prime = new TextOperation operation2.userId
      operation2prime = new TextOperation @userId

      ops1 = operation2.clone().ops
      ops2 = @clone().ops

    i1 = 0
    i2 = 0
    op1 = ops1[i1++]
    op2 = ops2[i2++]
    loop

      # At every iteration of the loop, the imaginary cursor that both
      # operation1 and operation2 have that operates on the input string must
      # have the same position in the input string.

      # end condition: both ops1 and ops2 have been processed
      break  if ! op1? and ! op2?

      # next two cases: one or both ops are insert ops
      # => insert the string in the corresponding prime operation, skip it in
      # the other one. If both op1 and op2 are insert ops, prefer op1.
      if op1?.type == 'insert'
        operation1prime.insert op1.attributes.text
        operation2prime.retain op1.attributes.text.length
        op1 = ops1[i1++]
        continue
      if op2?.type == 'insert'
        operation1prime.retain op2.attributes.text.length
        operation2prime.insert op2.attributes.text
        op2 = ops2[i2++]
        continue

      throw new Error("Cannot transform operations: first operation is too short.")  if typeof op1 is "undefined"
      throw new Error("Cannot transform operations: first operation is too long.")  if typeof op2 is "undefined"

      if op1.type == 'retain' and op2.type == 'retain'
        # Simple case: retain/retain
        if op1.attributes.amount is op2.attributes.amount
          minl = op2.attributes.amount
          op1 = ops1[i1++]
          op2 = ops2[i2++]
        else if op1.attributes.amount > op2.attributes.amount
          minl = op2.attributes.amount
          op1.attributes.amount -= op2.attributes.amount
          op2 = ops2[i2++]
        else
          minl = op1.attributes.amount
          op2.attributes.amount -= op1.attributes.amount
          op1 = ops1[i1++]

        operation1prime.retain minl
        operation2prime.retain minl

      else if op1.type == 'delete' and op2.type == 'delete'

        # Both operations delete the same string at the same position. We don't
        # need to produce any operations, we just skip over the delete ops and
        # handle the case that one operation deletes more than the other.
        if op1.attributes.text.length == op2.attributes.text.length
          op1 = ops1[i1++]
          op2 = ops2[i2++]
        else if op1.attributes.text.length > op2.attributes.text.length
          op1.attributes.text = op1.attributes.text.slice op2.attributes.text.length
          op2 = ops2[i2++]
        else
          op2.attributes.text = op1.attributes.text.slice op1.attributes.text.length
          op1 = ops1[i1++]

      # next two cases: delete/retain and retain/delete
      else if op1.type == 'delete' and op2.type == 'retain'
        if op1.attributes.text.length == op2.attributes.amount
          text = op1.attributes.text
          op1 = ops1[i1++]
          op2 = ops2[i2++]
        else if op1.attributes.text.length > op2.attributes.amount
          text = op1.attributes.text.slice 0, op2.attributes.amount
          op1.attributes.text = op1.attributes.text.slice op2.attributes.amount
          op2 = ops2[i2++]
        else
          text = op1.attributes.text
          op2.attributes.amount -= op1.attributes.text.length
          op1 = ops1[i1++]

        operation1prime.delete text

      else if op1.type == 'retain' and op2.type == 'delete'
        if op1.attributes.amount == op2.attributes.text.length
          text = op2.attributes.text
          op1 = ops1[i1++]
          op2 = ops2[i2++]
        else if op1.attributes.amount > op2.attributes.text.length
          text = op2.attributes.text
          op1.attributes.amount -= op2.attributes.text.length
          op2 = ops2[i2++]
        else
          text = op2.attributes.text.slice 0, op1.attributes.amount
          op2.attributes.text = op2.attributes.text.slice op1.attributes.amount
          op1 = ops1[i1++]

        operation2prime.delete text
      else
        throw new Error("The two operations aren't compatible")

    if @gotPriority operation2.userId
      return [operation1prime, operation2prime]
    else
      return [operation2prime, operation1prime]

  gotPriority: (id2) ->
    if typeof(@userId) == 'number'
      if @userId < id2 then return true
      else return false

    else
      id1 = @userId.split '/'
      id2 = id2.split '/'

      if id1[0] < id2[0] or ( id1[0] == id2[0] and id1[1] <= id2[1] ) then return true
      else return false
