const Base = require("./base");
const utils = require("./utils");

class PrivateVarsLeadingUnderscoreLib extends Base {
  static ruleId = "private-vars-leading-underscore-lib";

  ContractDefinition(node) {
    if (node.kind === "library") {
      this.inLibrary = true;
    }
  }

  "ContractDefinition:exit"() {
    this.inLibrary = false;
  }

  FunctionDefinition(node) {
    if (this.inLibrary) {
      const isPrivate = node.visibility === "private";
      const isInternal = node.visibility === "internal" || node.visibility === "default";
      const shouldHaveLeadingUnderscore = isPrivate || isInternal;
      this.validateName(node, shouldHaveLeadingUnderscore);
    }
  }

  VariableDeclaration(node) {
    if (this.inLibrary) {
      const isPrivate = node.visibility === "private";
      const isInternal = node.visibility === "internal" || node.visibility === "default";
      const shouldHaveLeadingUnderscore = isPrivate || isInternal;
      this.validateName(node, shouldHaveLeadingUnderscore);
    }
  }

  validateName(node, shouldHaveLeadingUnderscore) {
    if (!node.name) {
      return;
    }

    if (utils.hasLeadingUnderscore(node.name) !== shouldHaveLeadingUnderscore) {
      this._error(node, node.name, shouldHaveLeadingUnderscore);
    }
  }

  _error(node, name, shouldHaveLeadingUnderscore) {
    this.error(node, `'${name}' ${shouldHaveLeadingUnderscore ? "should" : "should not"} start with _`);
  }
}

module.exports = PrivateVarsLeadingUnderscoreLib;
