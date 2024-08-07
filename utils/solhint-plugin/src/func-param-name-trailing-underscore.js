const Base = require("./base");
const utils = require("./utils");

class FuncParamNameTrailingUnderscore extends Base {
  static ruleId = "func-param-name-trailing-underscore";

  CustomErrorDefinition(node) {
    this.FunctionDefinition(node);
  }

  EventDefinition(node) {
    this.FunctionDefinition(node);
  }

  FunctionDefinition(node) {
    node.parameters.forEach((parameter) => {
      if (!utils.hasTrailingUnderscore(parameter.name)) {
        this.error(parameter, `'${parameter.name}' should end with _ `);
      }
    });
  }
}

module.exports = FuncParamNameTrailingUnderscore;
