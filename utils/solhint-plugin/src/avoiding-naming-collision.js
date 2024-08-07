const Base = require("./base");
const utils = require("./utils");

class AvoidingNamingCollision extends Base {
  static ruleId = "avoiding-naming-collision";

  FunctionDefinition(node) {
    node.body.statements.forEach((statement) => {
      const { type, variables } = statement;
      if (type === "VariableDeclarationStatement") {
        variables.forEach((variable) => {
          if (!utils.hasLeadingUnderscore(variable.name)) {
            this.error(node, `'${variable.name}' should start with _ `);
          }
        });
      }
    });
  }
}

module.exports = AvoidingNamingCollision;
