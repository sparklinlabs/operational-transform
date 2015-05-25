import * as OT from "./index";

class Document {
  text = "";
  operations: OT.TextOperation[] = [];

  apply(newOperation: OT.TextOperation, revision: number) {
    // Should't happen
    if (revision > this.operations.length) throw new Error("The operation base revision is greater than the document revision");

    if (revision < this.operations.length) {
      // Conflict!
      let missedOperations = new OT.TextOperation(this.operations[revision].userId);
      missedOperations.targetLength = this.operations[revision].baseLength;

      for (let index = revision; index < this.operations.length; index++)
        missedOperations = missedOperations.compose(this.operations[index]);

      newOperation = missedOperations.transform(newOperation)[1];
    }

    this.text = newOperation.apply(this.text);
    this.operations.push(newOperation.clone());

    return newOperation;
  }
}

export = Document;
