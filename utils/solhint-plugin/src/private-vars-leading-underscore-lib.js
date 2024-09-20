const Base = require("./base");
const utils = require("./utils");
const constants = require("./constants");

class PrivateVarsLeadingUnderscoreLib extends Base {
  constructor(reporter) {
    super(reporter, "private-vars-leading-underscore-lib");
  }

  ContractDefinition(node) {
    if (node.kind === constants.LIBRARY) {
      this.inLibrary = true;
    }
  }

  "ContractDefinition:exit"() {
    this.inLibrary = false;
  }

  FunctionDefinition(node) {
    this._validateName(node);
  }

  VariableDeclaration(node) {
    this._validateName(node);
  }

  VariableDeclarationStatement() {
    this.inVariableDeclarationStatement = true;
  }

  "VariableDeclarationStatement:exit"() {
    this.inVariableDeclarationStatement = false;
  }

  _validateName(node) {
    if (this.inLibrary) {
      const inVariableDeclarationStatement = this.inVariableDeclarationStatement ? true : false;
      const isPrivate = node.visibility === constants.PRIVATE;
      const isInternal = node.visibility === constants.INTERNAL || node.visibility === constants.DEFAULT;
      const shouldHaveLeadingUnderscore = isPrivate || isInternal || inVariableDeclarationStatement;

      const { name } = node;
      if (!name) {
        return;
      }

      if (utils.hasLeadingUnderscore(name) !== shouldHaveLeadingUnderscore) {
        this.error(
          node,
          `'${name}' should  ${!shouldHaveLeadingUnderscore && "not"} start with ${constants.UNDERSCORE}`,
        );
      }
    }
  }
}

module.exports = PrivateVarsLeadingUnderscoreLib;
