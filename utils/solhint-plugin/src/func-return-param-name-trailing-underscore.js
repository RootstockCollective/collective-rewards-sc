const Base = require("./base");
const utils = require("./utils");
const constants = require("./constants");

class FuncReturnParamNameLeadingUnderscore extends Base {
  static ruleId = "func-return-param-name-trailing-underscore";

  FunctionDefinition(node) {
    this._validateParameters(node);
  }

  _validateParameters(node) {
    node.returnParameters.forEach((parameter) => {
      const { name } = parameter;
      if (!name) {
        return;
      }

      if (!utils.hasTrailingUnderscore(name)) {
        this.error(parameter, `'${name}' should end with ${constants.UNDERSCORE} `);
      }

      if (utils.hasLeadingUnderscore(name)) {
        this.error(parameter, `'${name}' should not start with ${constants.UNDERSCORE} `);
      }
    });
  }
}

module.exports = FuncReturnParamNameLeadingUnderscore;
