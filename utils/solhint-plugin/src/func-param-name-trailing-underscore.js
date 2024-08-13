const Base = require("./base");
const utils = require("./utils");
const constants = require("./constants");

class FuncParamNameTrailingUnderscore extends Base {
  constructor(reporter) {
    super(reporter, "func-param-name-trailing-underscore");
  }

  ModifierDefinition(node) {
    this._validateParameters(node);
  }

  CustomErrorDefinition(node) {
    this._validateParameters(node);
  }

  EventDefinition(node) {
    this._validateParameters(node);
  }

  FunctionDefinition(node) {
    this._validateParameters(node);
  }

  _validateParameters(node) {
    node.parameters.forEach((parameter) => {
      const { name } = parameter;
      if (!name) {
        return;
      }

      if (!utils.endsWithUnderscore(name)) {
        this.error(parameter, `'${name}' should end with ${constants.UNDERSCORE} `);
      }

      if (utils.startsWithUnderscore(name)) {
        this.error(parameter, `'${name}' should not start with ${constants.UNDERSCORE} `);
      }
    });
  }
}

module.exports = FuncParamNameTrailingUnderscore;
