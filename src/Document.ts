import * as OT from "./index";

class Document {
  text: string;
  operations: OT.TextOperation[] = [];
  _refRevisionId: number;

  constructor(text = "", revisionId = 0) {
    this.text = text;
    this._refRevisionId = revisionId;
  }

  apply(newOperation: OT.TextOperation, revision: number) {
    revision -=  this._refRevisionId;

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

  getRevisionId() { return this.operations.length + this._refRevisionId; }
}

export = Document;
