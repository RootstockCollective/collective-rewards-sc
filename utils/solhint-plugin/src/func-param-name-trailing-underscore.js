const Base = require("./base");
const utils = require("./utils");

class FuncParamNameTrailingUnderscore extends Base {
  static ruleId = "func-param-name-trailing-underscore";

  FunctionDefinition(node) {
    node.parameters.forEach((parameter) => {
      if (!utils.hasTrailingUnderscore(parameter.name)) {
        this.error(parameter, `'${parameter.name}' should end with _ `);
      }
    });
  }
}

module.exports = FuncParamNameTrailingUnderscore;
