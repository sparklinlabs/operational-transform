assert = require 'cassert'

OT = require '../src'

describe 'insert', ->
  it 'should apply 1 operation', (done) ->
    ope0 = new OT.TextOperation "0/0"
    ope0.insert 'hello'
    
    document = new OT.Document
    document.apply ope0, 0
    
    assert document.text == 'hello'
    done()
  
  it 'should add 2 operations', (done) ->
    ope0 = new OT.TextOperation "0/0"
    ope0.insert 'hello world'

    ope1 = new OT.TextOperation "0/0"
    ope1.retain 5
    ope1.insert ' lovely'
    ope1.retain 6
    
    document = new OT.Document
    document.apply ope0, 0
    document.apply ope1, 1
    
    assert document.text == 'hello lovely world'
    done()

describe 'delete', ->
  it 'should add 2 operations : 1 insert and 1 delete', (done) ->
    ope0 = new OT.TextOperation "0/0"
    ope0.insert 'hello lovely world'

    ope1 = new OT.TextOperation "0/0"
    ope1.retain 5
    ope1.delete ' lovely'
    ope1.retain 6
    
    document = new OT.Document
    document.apply ope0, 0
    document.apply ope1, 1
    
    assert document.text == 'hello world'
    done()
    
  it 'should handle several insert/delete operations', (done) ->
    ope0 = new OT.TextOperation "0/0"
    ope0.insert 'hello lovely world. today is pretty nice!'

    ope1 = new OT.TextOperation "0/0"
    ope1.retain 6
    ope1.delete 'lovely'
    ope1.insert 'sweet'
    ope1.retain 29
    
    ope2 = new OT.TextOperation "0/0"
    ope2.retain 28
    ope2.insert 'cool'
    ope2.delete 'pretty nice'
    ope2.retain 1
    
    document = new OT.Document
    document.apply ope0, 0
    document.apply ope1, 1
    document.apply ope2, 2
    
    assert document.text == 'hello sweet world. today is cool!'
    
    done()
    
describe 'compose', ->
  it 'should compose two operations', (done) ->
    ope0 = new OT.TextOperation "0/0"
    ope0.insert 'hello lovely world. today is pretty nice!'

    ope1 = new OT.TextOperation "0/0"
    ope1.retain 6
    ope1.delete 'lovely'
    ope1.insert 'sweet'
    ope1.retain 29
    
    ope2 = new OT.TextOperation "0/0"
    ope2.retain 28
    ope2.insert 'cool'
    ope2.delete 'pretty nice'
    ope2.retain 1
    
    document = new OT.Document
    document.apply ope0, 0
    document.apply( ope1.compose ope2, 1 )
    
    assert document.text == 'hello sweet world. today is cool!'
    done()
  
describe 'transform', ->
  it 'should transform two operations in conflict', (done) ->
    ope0 = new OT.TextOperation "0/0"
    ope0.insert 'Hello world!'

    ope1 = new OT.TextOperation "0/0"
    ope1.retain 5
    ope1.insert ' lovely'
    ope1.retain 7

    ope2 = new OT.TextOperation "1/0"
    ope2.retain 6
    ope2.delete 'world'
    ope2.insert 'people'
    ope2.retain 1

    [ope1prime, ope2prime] = ope1.transform ope2

    document1 = new OT.Document()
    document1.apply ope0, 0
    document1.apply ope1, 1
    document1.apply ope2prime, 2

    document2 = new OT.Document()
    document2.apply ope0, 0
    document2.apply ope2, 1
    document2.apply ope1prime, 2
    
    assert document1.text == document2.text
    done()
    
  it 'should automatically transform the last operation in conflict with previous ones and give correct priority', (done) ->
    ope0 = new OT.TextOperation "0/1"
    ope0.insert 'Hello world!'

    ope1 = new OT.TextOperation "0/1"
    ope1.retain 5
    ope1.insert ' lovely'
    ope1.retain 7
    
    ope1bis = new OT.TextOperation "0/0"
    ope1bis.retain 5
    ope1bis.insert ' sweet'
    ope1bis.retain 7

    ope2 = new OT.TextOperation "0/1"
    ope2.retain 13
    ope2.delete 'world'
    ope2.insert 'people'
    ope2.retain 1
    
    ope3 = new OT.TextOperation "0/1"
    ope3.retain 20
    ope3.insert ' Today will be a nice day!'
    
    document = new OT.Document
    document.apply ope0, 0
    document.apply ope1, 1
    document.apply ope2, 2
    document.apply ope3, 3
    document.apply ope1bis, 1
    
    assert document.text == 'Hello sweet lovely people! Today will be a nice day!'
    done()
    
