const ScopedVarsLeadingUnderscore = require("./src/scoped-vars-leading-underscore");
const FuncParamNameStrictMixedCase = require("./src/func-param-name-trailing-underscore");
const PrivateVarsLeadingUnderscoreLib = require("./src/private-vars-leading-underscore-lib");
const FuncReturnParamNameTrailingUnderscore = require("./src/func-return-param-name-trailing-underscore");

module.exports = [
  ScopedVarsLeadingUnderscore,
  FuncParamNameStrictMixedCase,
  PrivateVarsLeadingUnderscoreLib,
  FuncReturnParamNameTrailingUnderscore,
];
