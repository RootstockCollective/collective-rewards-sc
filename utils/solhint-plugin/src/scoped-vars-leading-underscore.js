const Base = require("./base");
const utils = require("./utils");
const constants = require("./constants");

class ScopedVarsLeadingUnderscore extends Base {
  static ruleId = "scoped-vars-leading-underscore";

  ForStatement(node) {
    this._validateVariables(node);
  }

  DoWhileStatement(node) {
    this._validateVariables(node);
  }

  WhileStatement(node) {
    this._validateVariables(node);
  }

  FunctionDefinition(node) {
    this._validateVariables(node);
  }

  _validateVariables(node) {
    node.body.statements.forEach((statement) => {
      const { type, variables } = statement;
      if (type === "VariableDeclarationStatement") {
        variables.forEach((variable) => {
          const { name } = variable;

          if (!utils.hasLeadingUnderscore(name)) {
            this.error(node, `'${name}' should start with ${constants.UNDERSCORE} `);
          }

          if (utils.hasTrailingUnderscore(name)) {
            this.error(variable, `'${name}' should not end with ${constants.UNDERSCORE} `);
          }
        });
      }
    });
  }
}

module.exports = ScopedVarsLeadingUnderscore;
