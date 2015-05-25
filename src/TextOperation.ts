import * as OT from "./index";

class TextOperation {

  userId: number;
  ops: OT.TextOp[] = [];

  // An operation's baseLength is the length of every string the operation
  // can be applied to.
  baseLength = 0;

  // The targetLength is the length of every string that results from applying
  // the operation on a valid input string.
  targetLength = 0;

  constructor(userId: number) {
    this.userId = userId;
  }

  serialize() {
    let ops: OT.TextOp[] = [];
    for (let op of this.ops) {
      ops.push({ type: op.type, attributes: op.attributes });
    }

    return { ops, userId: this.userId };
  }

  deserialize(data: { userId: number; ops: OT.TextOp[] }) {
    if (data == null) return false;

    this.userId = data.userId;

    for (let op of data.ops) {
      switch (op.type) {
        case "retain": this.retain(op.attributes.amount); break;
        case "insert": this.insert(op.attributes.text); break;
        case "delete": this.delete(op.attributes.text); break;
        default: return false;
      }
    }

    return true;
  }

  retain(amount: number) {
    if (typeof(amount) !== "number" || amount <= 0) return;
    this.baseLength += amount;
    this.targetLength += amount;

    let prevOp = this.ops[this.ops.length - 1];
    if (prevOp != null && prevOp.type === "retain") {
      prevOp.attributes.amount += amount;
    } else {
      this.ops.push(new OT.TextOp("retain", { amount }));
    }
  }

  insert(text: string) {
    if (typeof(text) !== "string" || text === "") return;
    this.targetLength += text.length;

    let prevOp = this.ops[this.ops.length - 1];
    if (prevOp != null && prevOp.type === "insert") {
      prevOp.attributes.text += text;
    } else {
      this.ops.push(new OT.TextOp("insert", { text }));
    }
  }

  delete(text: string) {
    if (typeof(text) !== "string" || text === "") return;
    this.baseLength += text.length;

    let prevOp = this.ops[this.ops.length - 1];
    if (prevOp != null && prevOp.type === "delete") {
      prevOp.attributes.text += text;
    } else {
      this.ops.push(new OT.TextOp("delete", { text }));
    }
  }

  apply(text: string) {
    if (text.length !== this.baseLength) throw new Error("The operation's base length must be equal to the string's length.");
    let index = 0;

    for (let op of this.ops) {
      switch (op.type) {
        case "retain":
          index += op.attributes.amount;
          break;

        case "insert":
          text = text.substring(0, index) + op.attributes.text + text.substring(index, text.length);
          index += op.attributes.text.length;
          break;

        case "delete":
          text = text.substring(0, index) + text.substring(index + op.attributes.text.length, text.length);
          break;
      }
    }

    return text;
  }

  invert() {
    let invertedOperation = new TextOperation(this.userId);
    for (let op of this.ops) {
      switch (op.type) {
        case "retain": invertedOperation.retain(op.attributes.amount); break;
        case "insert": invertedOperation.delete(op.attributes.text); break;
        case "delete": invertedOperation.insert(op.attributes.text); break;
      }
    }

    return invertedOperation;
  }

  clone() {
    let operation = new TextOperation(this.userId);
    for (let op of this.ops) {
      switch (op.type) {
        case "retain": operation.retain(op.attributes.amount); break;
        case "insert": operation.insert(op.attributes.text); break;
        case "delete": operation.delete(op.attributes.text); break;
      }
    }

    return operation;
  }

  equal(otherOperation: TextOperation) {
    // if (otherOperation.insertedLength !== this.insertedLength) return false;
    if (otherOperation.ops.length !== this.ops.length) return false;

    for (let opIndex = 0; opIndex < this.ops.length; opIndex++) {
      let op = this.ops[opIndex];
      let otherOp = otherOperation.ops[opIndex];
      if (otherOp.type !== op.type) return false;

      for (let key in op.attributes) {
        let attribute = op.attributes[key];
        if (attribute !== otherOp.attributes[key]) return false;
      }
    }

    return true;
  }

  /*
  Largely inspired from Firepad
  Compose merges two consecutive operations into one operation, that
  preserves the changes of both. Or, in other words, for each input string S
  and a pair of consecutive operations A and B,
  apply(apply(S, A), B) = apply(S, compose(A, B)) must hold.
  */

  compose(operation2: TextOperation) {
    if (this.targetLength !== operation2.baseLength) throw new Error("The base length of the second operation has to be the target length of the first operation");

    // the combined operation
    let composedOperation = new TextOperation(this.userId);

    let ops1 = this.clone().ops;
    let ops2 = operation2.clone().ops;
    let i1 = 0; // current index into ops1 respectively ops2
    let i2 = 0;
    let op1 = ops1[i1++]; // current ops
    let op2 = ops2[i2++];

    while(true) {
      // Dispatch on the type of op1 and op2

      // end condition: both ops1 and ops2 have been processed
      if (op1 == null && op2 == null) break;

      if (op2 == null) {

        switch (op1.type) {
          case "retain": composedOperation.retain(op1.attributes.amount); break;
          case "insert": composedOperation.insert(op1.attributes.text); break;
          case "delete": composedOperation.delete(op1.attributes.text); break;
        }

        op1 = ops1[i1++];
        continue;
      }

      if (op1 == null) {
        switch (op2.type) {
          case "retain": composedOperation.retain(op2.attributes.amount); break;
          case "insert": composedOperation.insert(op2.attributes.text); break;
          case "delete": composedOperation.delete(op2.attributes.text); break;
       }

        op2 = ops2[i2++];
        continue;
      }

      if (op1 != null && op1.type === "delete") {
        composedOperation.delete(op1.attributes.text);
        op1 = ops1[i1++];
        continue;
      }
      if (op2 != null && op2.type === "insert") {
        composedOperation.insert(op2.attributes.text);
        op2 = ops2[i2++];
        continue;
      }

      if (op1 == null) throw new Error("Cannot transform operations: first operation is too short.");
      if (op2 == null) throw new Error("Cannot transform operations: first operation is too long.");

      if (op1.type === "retain" && op2.type === "retain") {
        if (op1.attributes.amount === op2.attributes.amount) {
          composedOperation.retain(op1.attributes.amount);
          op1 = ops1[i1++];
          op2 = ops2[i2++];
        } else if (op1.attributes.amount > op2.attributes.amount) {
          composedOperation.retain(op2.attributes.amount);
          op1.attributes.amount -= op2.attributes.amount;
          op2 = ops2[i2++];
        } else {
          composedOperation.retain(op1.attributes.amount);
          op2.attributes.amount -= op1.attributes.amount;
          op1 = ops1[i1++];
        }
      }

      else if (op1.type === "insert" && op2.type === "delete") {
        if (op1.attributes.text.length === op2.attributes.text) {
          op1 = ops1[i1++];
          op2 = ops2[i2++];
        } else if (op1.attributes.text.length > op2.attributes.text.length) {
          op1.attributes.text = op1.attributes.text.slice(op2.attributes.text.length);
          op2 = ops2[i2++];
        } else {
          op2.attributes.text= op2.attributes.text.slice(op1.attributes.text.length);
          op1 = ops1[i1++];
        }
      }

      else if (op1.type === "insert" && op2.type === "retain") {
        if (op1.attributes.text.length > op2.attributes.amount) {
          composedOperation.insert(op1.attributes.text.slice(0, op2.attributes.amount));
          op1.attributes.text = op1.attributes.text.slice(op2.attributes.amount);
          op2 = ops2[i2++];
        } else if (op1.attributes.text.length === op2.attributes.amount) {
          composedOperation.insert(op1.attributes.text);
          op1 = ops1[i1++];
          op2 = ops2[i2++];
        } else {
          composedOperation.insert(op1.attributes.text);
          op2.attributes.amount -= op1.attributes.text.length;
          op1 = ops1[i1++];
        }
      }

      else if (op1.type === "retain" && op2.type === "delete") {
        if (op1.attributes.amount === op2.attributes.text.length) {
          composedOperation.delete(op2.attributes.text);
          op1 = ops1[i1++];
          op2 = ops2[i2++];
        } else if (op1.attributes.amount > op2.attributes.text.length) {
          composedOperation.delete(op2.attributes.text);
          op1.attributes.amount -= op2.attributes.text.length;
          op2 = ops2[i2++];
        } else {
          composedOperation.delete(op2.attributes.text.slice(0, op1.attributes.amount));
          op2.attributes.text = op2.attributes.text.slice(op1.attributes.amount);
          op1 = ops1[i1++];
        }
      }

      else {
        throw new Error(`This shouldn't happen: op1: ${JSON.stringify(op1)}, op2: ${JSON.stringify(op2)}`);
      }
    }

    return composedOperation;
  }

  /*
  Largely inspired from Firepad
  Transform takes two operations A (this) and B (other) that happened concurrently and
  produces two operations A' and B' (in an array) such that
  `apply(apply(S, A), B') = apply(apply(S, B), A')`.
  This function is the heart of OT.
  */
  transform(operation2: TextOperation) {
    let operation1prime: TextOperation, operation2prime: TextOperation;
    let ops1: OT.TextOp[], ops2: OT.TextOp[];

    // Give priority with the user id
    if (this.gotPriority(operation2.userId)) {
      operation1prime = new TextOperation(this.userId);
      operation2prime = new TextOperation(operation2.userId);

      ops1 = this.clone().ops;
      ops2 = operation2.clone().ops;
    } else {
      operation1prime = new TextOperation(operation2.userId);
      operation2prime = new TextOperation(this.userId);

      ops1 = operation2.clone().ops;
      ops2 = this.clone().ops;
    }

    let i1 = 0;
    let i2 = 0;
    let op1 = ops1[i1++];
    let op2 = ops2[i2++];

    while(true) {

      // At every iteration of the loop, the imaginary cursor that both
      // operation1 and operation2 have that operates on the input string must
      // have the same position in the input string.

      // end condition: both ops1 and ops2 have been processed
       if (op1 == null && op2 == null) break;

      // next two cases: one or both ops are insert ops
      // => insert the string in the corresponding prime operation, skip it in
      // the other one. If both op1 and op2 are insert ops, prefer op1.
      if (op1 != null && op1.type === "insert") {
        operation1prime.insert(op1.attributes.text);
        operation2prime.retain(op1.attributes.text.length);
        op1 = ops1[i1++];
        continue;
      }
      if (op2 != null && op2.type === "insert") {
        operation1prime.retain(op2.attributes.text.length);
        operation2prime.insert(op2.attributes.text);
        op2 = ops2[i2++];
        continue;
      }

      if (op1 == null) throw new Error("Cannot transform operations: first operation is too short.");
      if (op2 == null) throw new Error("Cannot transform operations: first operation is too long.");

      if (op1.type === "retain" && op2.type === "retain") {
        // Simple case: retain/retain
        let minl: number;
        if (op1.attributes.amount === op2.attributes.amount) {
          minl = op2.attributes.amount;
          op1 = ops1[i1++];
          op2 = ops2[i2++];
        } else if (op1.attributes.amount > op2.attributes.amount) {
          minl = op2.attributes.amount;
          op1.attributes.amount -= op2.attributes.amount;
          op2 = ops2[i2++];
        } else {
          minl = op1.attributes.amount;
          op2.attributes.amount -= op1.attributes.amount;
          op1 = ops1[i1++];
        }

        operation1prime.retain(minl);
        operation2prime.retain(minl);
      }

      else if (op1.type === "delete" && op2.type === "delete") {

        // Both operations delete the same string at the same position. We don't
        // need to produce any operations, we just skip over the delete ops and
        // handle the case that one operation deletes more than the other.
        if (op1.attributes.text.length === op2.attributes.text.length) {
          op1 = ops1[i1++];
          op2 = ops2[i2++];
        } else if (op1.attributes.text.length > op2.attributes.text.length) {
          op1.attributes.text = op1.attributes.text.slice(op2.attributes.text.length);
          op2 = ops2[i2++];
        } else {
          op2.attributes.text = op1.attributes.text.slice(op1.attributes.text.length);
          op1 = ops1[i1++];
        }
      }

      // next two cases: delete/retain and retain/delete
      else if (op1.type === "delete" && op2.type === "retain") {
        let text: string;
        if (op1.attributes.text.length === op2.attributes.amount) {
          text = op1.attributes.text;
          op1 = ops1[i1++];
          op2 = ops2[i2++];
        } else if (op1.attributes.text.length > op2.attributes.amount) {
          text = op1.attributes.text.slice(0, op2.attributes.amount);
          op1.attributes.text = op1.attributes.text.slice(op2.attributes.amount);
          op2 = ops2[i2++];
        } else {
          text = op1.attributes.text;
          op2.attributes.amount -= op1.attributes.text.length;
          op1 = ops1[i1++];
        }

        operation1prime.delete(text);
      }

      else if (op1.type === "retain" && op2.type === "delete") {
        let text: string;
        if (op1.attributes.amount === op2.attributes.text.length) {
          text = op2.attributes.text;
          op1 = ops1[i1++];
          op2 = ops2[i2++];
        } else if (op1.attributes.amount > op2.attributes.text.length) {
          text = op2.attributes.text;
          op1.attributes.amount -= op2.attributes.text.length;
          op2 = ops2[i2++];
        } else {
          text = op2.attributes.text.slice(0, op1.attributes.amount);
          op2.attributes.text = op2.attributes.text.slice(op1.attributes.amount);
          op1 = ops1[i1++];
        }

        operation2prime.delete(text);
      } else {
        throw new Error("The two operations aren't compatible");
      }
    }

    if (this.gotPriority(operation2.userId)) return [ operation1prime, operation2prime ];
    else return [ operation2prime, operation1prime ];
  }

  gotPriority(id2: number) { return (this.userId <= id2); }
}

export = TextOperation;
